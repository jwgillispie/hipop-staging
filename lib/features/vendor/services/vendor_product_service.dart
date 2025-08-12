import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/vendor_product.dart';
import '../models/vendor_market_product_assignment.dart';
import '../models/vendor_product_list.dart';
import '../../premium/services/subscription_service.dart';

/// Service for managing vendor's global product catalog and market assignments
class VendorProductService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _productsCollection = 'vendor_products';
  static const String _assignmentsCollection = 'vendor_market_product_assignments';
  static const String _listsCollection = 'vendor_product_lists';

  // =============================================================================
  // GLOBAL PRODUCT CATALOG METHODS
  // =============================================================================

  /// Create a new product in vendor's global catalog
  static Future<VendorProduct> createProduct({
    required String vendorId,
    required String name,
    required String category,
    String? description,
    double? basePrice,
    String? imageUrl,
    List<String>? tags,
  }) async {
    try {
      // Check if vendor can create more products (premium limit check)
      final canCreate = await _canCreateProduct(vendorId);
      if (!canCreate) {
        throw Exception('Product limit reached. Upgrade to premium for unlimited products.');
      }

      final now = DateTime.now();
      final productData = {
        'vendorId': vendorId,
        'name': name.trim(),
        'category': category,
        'description': description?.trim(),
        'basePrice': basePrice,
        'imageUrl': imageUrl,
        'tags': tags ?? [],
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'isActive': true,
      };

      final docRef = await _firestore.collection(_productsCollection).add(productData);
      
      return VendorProduct(
        id: docRef.id,
        vendorId: vendorId,
        name: name.trim(),
        category: category,
        description: description?.trim(),
        basePrice: basePrice,
        imageUrl: imageUrl,
        tags: tags ?? [],
        createdAt: now,
        updatedAt: now,
        isActive: true,
      );
    } catch (e) {
      debugPrint('Error creating product: $e');
      rethrow;
    }
  }

  /// Get all products for a vendor
  static Future<List<VendorProduct>> getVendorProducts(String vendorId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_productsCollection)
          .where('vendorId', isEqualTo: vendorId)
          .where('isActive', isEqualTo: true)
          .orderBy('updatedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => VendorProduct.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching vendor products: $e');
      return [];
    }
  }

  /// Update an existing product
  static Future<VendorProduct> updateProduct({
    required String productId,
    String? name,
    String? category,
    String? description,
    double? basePrice,
    String? imageUrl,
    List<String>? tags,
    bool? isActive,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (name != null) updateData['name'] = name.trim();
      if (category != null) updateData['category'] = category;
      if (description != null) updateData['description'] = description.trim();
      if (basePrice != null) updateData['basePrice'] = basePrice;
      if (imageUrl != null) updateData['imageUrl'] = imageUrl;
      if (tags != null) updateData['tags'] = tags;
      if (isActive != null) updateData['isActive'] = isActive;

      await _firestore.collection(_productsCollection).doc(productId).update(updateData);

      // Return updated product
      final doc = await _firestore.collection(_productsCollection).doc(productId).get();
      return VendorProduct.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error updating product: $e');
      rethrow;
    }
  }

  /// Soft delete a product (mark as inactive)
  static Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection(_productsCollection).doc(productId).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Also remove all market assignments for this product
      await _removeAllProductAssignments(productId);
    } catch (e) {
      debugPrint('Error deleting product: $e');
      rethrow;
    }
  }

  /// Get a single product by ID
  static Future<VendorProduct?> getProduct(String productId) async {
    try {
      final doc = await _firestore.collection(_productsCollection).doc(productId).get();
      if (!doc.exists) return null;
      return VendorProduct.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error fetching product: $e');
      return null;
    }
  }

  // =============================================================================
  // MARKET ASSIGNMENT METHODS
  // =============================================================================

  /// Assign a product to a specific market
  static Future<VendorMarketProductAssignment> assignProductToMarket({
    required String vendorId,
    required String marketId,
    required String productId,
    double? marketSpecificPrice,
    bool isAvailable = true,
    int? inventory,
    String? marketSpecificNotes,
  }) async {
    try {
      // Check if assignment already exists
      final existing = await getProductAssignment(vendorId, marketId, productId);
      if (existing != null) {
        throw Exception('Product is already assigned to this market');
      }

      final now = DateTime.now();
      final assignmentData = {
        'vendorId': vendorId,
        'marketId': marketId,
        'productId': productId,
        'marketSpecificPrice': marketSpecificPrice,
        'isAvailable': isAvailable,
        'inventory': inventory,
        'marketSpecificNotes': marketSpecificNotes?.trim(),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final docRef = await _firestore.collection(_assignmentsCollection).add(assignmentData);
      
      return VendorMarketProductAssignment(
        id: docRef.id,
        vendorId: vendorId,
        marketId: marketId,
        productId: productId,
        marketSpecificPrice: marketSpecificPrice,
        isAvailable: isAvailable,
        inventory: inventory,
        marketSpecificNotes: marketSpecificNotes?.trim(),
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      debugPrint('Error assigning product to market: $e');
      rethrow;
    }
  }

  /// Get all product assignments for a vendor at a specific market
  static Future<List<VendorMarketProductAssignment>> getMarketAssignments(
    String vendorId, 
    String marketId
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_assignmentsCollection)
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', isEqualTo: marketId)
          .orderBy('updatedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => VendorMarketProductAssignment.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching market assignments: $e');
      return [];
    }
  }

  /// Get all assignments for a specific product
  static Future<List<VendorMarketProductAssignment>> getProductAssignments(String productId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_assignmentsCollection)
          .where('productId', isEqualTo: productId)
          .get();

      return querySnapshot.docs
          .map((doc) => VendorMarketProductAssignment.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching product assignments: $e');
      return [];
    }
  }

  /// Get a specific product assignment
  static Future<VendorMarketProductAssignment?> getProductAssignment(
    String vendorId, 
    String marketId, 
    String productId
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_assignmentsCollection)
          .where('vendorId', isEqualTo: vendorId)
          .where('marketId', isEqualTo: marketId)
          .where('productId', isEqualTo: productId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;
      return VendorMarketProductAssignment.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      debugPrint('Error fetching product assignment: $e');
      return null;
    }
  }

  /// Update a market assignment
  static Future<VendorMarketProductAssignment> updateAssignment({
    required String assignmentId,
    double? marketSpecificPrice,
    bool? isAvailable,
    int? inventory,
    String? marketSpecificNotes,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      if (marketSpecificPrice != null) updateData['marketSpecificPrice'] = marketSpecificPrice;
      if (isAvailable != null) updateData['isAvailable'] = isAvailable;
      if (inventory != null) updateData['inventory'] = inventory;
      if (marketSpecificNotes != null) updateData['marketSpecificNotes'] = marketSpecificNotes.trim();

      await _firestore.collection(_assignmentsCollection).doc(assignmentId).update(updateData);

      // Return updated assignment
      final doc = await _firestore.collection(_assignmentsCollection).doc(assignmentId).get();
      return VendorMarketProductAssignment.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error updating assignment: $e');
      rethrow;
    }
  }

  /// Remove a product from a market
  static Future<void> removeProductFromMarket(String assignmentId) async {
    try {
      await _firestore.collection(_assignmentsCollection).doc(assignmentId).delete();
    } catch (e) {
      debugPrint('Error removing product from market: $e');
      rethrow;
    }
  }

  // =============================================================================
  // UTILITY METHODS
  // =============================================================================

  /// Check if vendor can create more products based on their subscription
  static Future<bool> _canCreateProduct(String vendorId) async {
    try {
      final currentProducts = await getVendorProducts(vendorId);
      final productCount = currentProducts.length;
      
      // Check subscription limits
      return await SubscriptionService.isWithinLimit(vendorId, 'global_products', productCount);
    } catch (e) {
      debugPrint('Error checking product limit: $e');
      return false; // Err on the side of caution
    }
  }

  /// Remove all assignments for a product when it's deleted
  static Future<void> _removeAllProductAssignments(String productId) async {
    try {
      final assignments = await getProductAssignments(productId);
      for (final assignment in assignments) {
        await removeProductFromMarket(assignment.id);
      }
    } catch (e) {
      debugPrint('Error removing product assignments: $e');
    }
  }

  /// Get product statistics for a vendor
  static Future<Map<String, dynamic>> getProductStats(String vendorId) async {
    try {
      final products = await getVendorProducts(vendorId);
      final totalProducts = products.length;
      
      // Get all assignments for this vendor
      final allAssignments = <VendorMarketProductAssignment>[];
      for (final product in products) {
        final assignments = await getProductAssignments(product.id);
        allAssignments.addAll(assignments);
      }
      
      final totalAssignments = allAssignments.length;
      final activeAssignments = allAssignments.where((a) => a.isAvailable).length;
      
      // Get unique markets
      final uniqueMarkets = allAssignments.map((a) => a.marketId).toSet().length;
      
      return {
        'totalProducts': totalProducts,
        'totalAssignments': totalAssignments,
        'activeAssignments': activeAssignments,
        'marketsWithProducts': uniqueMarkets,
        'averageProductsPerMarket': uniqueMarkets > 0 ? (totalAssignments / uniqueMarkets).toStringAsFixed(1) : '0',
      };
    } catch (e) {
      debugPrint('Error getting product stats: $e');
      return {
        'totalProducts': 0,
        'totalAssignments': 0,
        'activeAssignments': 0,
        'marketsWithProducts': 0,
        'averageProductsPerMarket': '0',
      };
    }
  }

  // =============================================================================
  // PRODUCT LIST MANAGEMENT METHODS
  // =============================================================================

  /// Create a new product list
  static Future<VendorProductList> createProductList({
    required String vendorId,
    required String name,
    String? description,
    List<String>? productIds,
    String? color,
  }) async {
    try {
      final list = VendorProductList.create(
        vendorId: vendorId,
        name: name,
        description: description,
        productIds: productIds,
        color: color,
      );

      // Validate the list
      final validationError = list.validate();
      if (validationError != null) {
        throw Exception('Invalid product list: $validationError');
      }

      // Save to Firestore
      final docRef = await _firestore
          .collection(_listsCollection)
          .add(list.toFirestore());

      debugPrint('✅ Product list created: ${list.name}');
      return list.copyWith(id: docRef.id);
    } catch (e) {
      debugPrint('Error creating product list: $e');
      rethrow;
    }
  }

  /// Update an existing product list
  static Future<VendorProductList> updateProductList(VendorProductList list) async {
    try {
      if (list.id.isEmpty) {
        throw Exception('Cannot update list without ID');
      }

      // Validate the list
      final validationError = list.validate();
      if (validationError != null) {
        throw Exception('Invalid product list: $validationError');
      }

      final updatedList = list.copyWith(updatedAt: DateTime.now());
      
      await _firestore
          .collection(_listsCollection)
          .doc(list.id)
          .update(updatedList.toFirestore());

      debugPrint('✅ Product list updated: ${list.name}');
      return updatedList;
    } catch (e) {
      debugPrint('Error updating product list: $e');
      rethrow;
    }
  }

  /// Delete a product list
  static Future<void> deleteProductList(String listId) async {
    try {
      await _firestore
          .collection(_listsCollection)
          .doc(listId)
          .delete();

      debugPrint('✅ Product list deleted: $listId');
    } catch (e) {
      debugPrint('Error deleting product list: $e');
      rethrow;
    }
  }

  /// Get all product lists for a vendor
  static Future<List<VendorProductList>> getProductLists(String vendorId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_listsCollection)
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('updatedAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => VendorProductList.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching product lists: $e');
      return [];
    }
  }

  /// Get a specific product list
  static Future<VendorProductList?> getProductList(String listId) async {
    try {
      final docSnapshot = await _firestore
          .collection(_listsCollection)
          .doc(listId)
          .get();

      if (docSnapshot.exists) {
        return VendorProductList.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching product list: $e');
      return null;
    }
  }

  /// Add product to a list
  static Future<VendorProductList> addProductToList(
    String listId, 
    String productId
  ) async {
    try {
      final list = await getProductList(listId);
      if (list == null) {
        throw Exception('Product list not found');
      }

      final updatedList = list.addProduct(productId);
      return await updateProductList(updatedList);
    } catch (e) {
      debugPrint('Error adding product to list: $e');
      rethrow;
    }
  }

  /// Remove product from a list
  static Future<VendorProductList> removeProductFromList(
    String listId, 
    String productId
  ) async {
    try {
      final list = await getProductList(listId);
      if (list == null) {
        throw Exception('Product list not found');
      }

      final updatedList = list.removeProduct(productId);
      return await updateProductList(updatedList);
    } catch (e) {
      debugPrint('Error removing product from list: $e');
      rethrow;
    }
  }

  /// Assign entire product list to a market
  static Future<List<VendorMarketProductAssignment>> assignProductListToMarket({
    required String vendorId,
    required String marketId,
    required String listId,
    double? marketSpecificPrice,
    bool isAvailable = true,
  }) async {
    try {
      final list = await getProductList(listId);
      if (list == null) {
        throw Exception('Product list not found');
      }

      if (list.vendorId != vendorId) {
        throw Exception('Cannot assign another vendor\'s product list');
      }

      final assignments = <VendorMarketProductAssignment>[];
      
      // Create assignments for each product in the list
      for (final productId in list.productIds) {
        try {
          final assignment = await assignProductToMarket(
            vendorId: vendorId,
            marketId: marketId,
            productId: productId,
            marketSpecificPrice: marketSpecificPrice,
            isAvailable: isAvailable,
          );
          assignments.add(assignment);
        } catch (e) {
          debugPrint('Warning: Failed to assign product $productId: $e');
          // Continue with other products
        }
      }

      debugPrint('✅ Assigned ${assignments.length}/${list.productIds.length} products from list "${list.name}" to market');
      return assignments;
    } catch (e) {
      debugPrint('Error assigning product list to market: $e');
      rethrow;
    }
  }

  /// Get products that belong to a specific list
  static Future<List<VendorProduct>> getProductsInList(String listId) async {
    try {
      final list = await getProductList(listId);
      if (list == null) return [];

      if (list.productIds.isEmpty) return [];

      // Get all products that are in this list
      final products = <VendorProduct>[];
      for (final productId in list.productIds) {
        try {
          final product = await getProduct(productId);
          if (product != null) {
            products.add(product);
          }
        } catch (e) {
          debugPrint('Warning: Failed to fetch product $productId: $e');
        }
      }

      return products;
    } catch (e) {
      debugPrint('Error fetching products in list: $e');
      return [];
    }
  }

  /// Get lists that contain a specific product
  static Future<List<VendorProductList>> getListsContainingProduct(
    String vendorId, 
    String productId
  ) async {
    try {
      final allLists = await getProductLists(vendorId);
      return allLists
          .where((list) => list.containsProduct(productId))
          .toList();
    } catch (e) {
      debugPrint('Error fetching lists containing product: $e');
      return [];
    }
  }
}