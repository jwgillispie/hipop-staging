import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hipop/features/vendor/models/vendor_product.dart';
import 'package:hipop/features/vendor/models/vendor_product_list.dart';
import 'package:hipop/features/vendor/services/vendor_product_service.dart';

// Events
abstract class VendorProductsEvent extends Equatable {
  const VendorProductsEvent();

  @override
  List<Object?> get props => [];
}

class LoadProducts extends VendorProductsEvent {
  final String vendorId;
  const LoadProducts(this.vendorId);
  
  @override
  List<Object?> get props => [vendorId];
}

class LoadMoreProducts extends VendorProductsEvent {
  final String vendorId;
  const LoadMoreProducts(this.vendorId);
  
  @override
  List<Object?> get props => [vendorId];
}

class RefreshProducts extends VendorProductsEvent {
  final String vendorId;
  const RefreshProducts(this.vendorId);
  
  @override
  List<Object?> get props => [vendorId];
}

class AddProduct extends VendorProductsEvent {
  final String vendorId;
  final String name;
  final String category;
  final String? description;
  final double? basePrice;
  final List<String> tags;
  
  const AddProduct({
    required this.vendorId,
    required this.name,
    required this.category,
    this.description,
    this.basePrice,
    this.tags = const [],
  });
  
  @override
  List<Object?> get props => [vendorId, name, category, description, basePrice, tags];
}

class UpdateProduct extends VendorProductsEvent {
  final String productId;
  final String name;
  final String category;
  final String? description;
  final double? basePrice;
  final List<String>? tags;
  
  const UpdateProduct({
    required this.productId,
    required this.name,
    required this.category,
    this.description,
    this.basePrice,
    this.tags,
  });
  
  @override
  List<Object?> get props => [productId, name, category, description, basePrice, tags];
}

class DeleteProduct extends VendorProductsEvent {
  final String productId;
  const DeleteProduct(this.productId);
  
  @override
  List<Object?> get props => [productId];
}

// States
abstract class VendorProductsState extends Equatable {
  const VendorProductsState();
  
  @override
  List<Object?> get props => [];
}

class ProductsInitial extends VendorProductsState {}

class ProductsLoading extends VendorProductsState {}

class ProductsLoaded extends VendorProductsState {
  final List<VendorProduct> products;
  final List<VendorProductList> productLists;
  final bool hasReachedEnd;
  final bool isLoadingMore;
  final DocumentSnapshot? lastDocument;
  final String vendorId;
  
  const ProductsLoaded({
    required this.products,
    required this.productLists,
    required this.hasReachedEnd,
    required this.vendorId,
    this.isLoadingMore = false,
    this.lastDocument,
  });
  
  ProductsLoaded copyWith({
    List<VendorProduct>? products,
    List<VendorProductList>? productLists,
    bool? hasReachedEnd,
    bool? isLoadingMore,
    DocumentSnapshot? lastDocument,
    String? vendorId,
  }) {
    return ProductsLoaded(
      products: products ?? this.products,
      productLists: productLists ?? this.productLists,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
      vendorId: vendorId ?? this.vendorId,
    );
  }
  
  @override
  List<Object?> get props => [
    products,
    productLists,
    hasReachedEnd,
    isLoadingMore,
    lastDocument,
    vendorId,
  ];
}

class ProductsError extends VendorProductsState {
  final String message;
  
  const ProductsError(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class VendorProductsBloc extends Bloc<VendorProductsEvent, VendorProductsState> {
  static const int _pageSize = 20;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  VendorProductsBloc() : super(ProductsInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<LoadMoreProducts>(_onLoadMoreProducts);
    on<RefreshProducts>(_onRefreshProducts);
    on<AddProduct>(_onAddProduct);
    on<UpdateProduct>(_onUpdateProduct);
    on<DeleteProduct>(_onDeleteProduct);
  }
  
  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<VendorProductsState> emit,
  ) async {
    emit(ProductsLoading());
    
    try {
      // Load first page of products
      final productsQuery = _firestore
          .collection('vendor_products')
          .where('vendorId', isEqualTo: event.vendorId)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);
      
      final productsSnapshot = await productsQuery.get();
      
      final products = productsSnapshot.docs
          .map((doc) => VendorProduct.fromFirestore(doc))
          .toList();
      
      // Load all product lists (usually not many)
      final productLists = await VendorProductService.getProductLists(event.vendorId);
      
      emit(ProductsLoaded(
        products: products,
        productLists: productLists,
        hasReachedEnd: productsSnapshot.docs.length < _pageSize,
        lastDocument: productsSnapshot.docs.isNotEmpty ? productsSnapshot.docs.last : null,
        vendorId: event.vendorId,
      ));
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }
  
  Future<void> _onLoadMoreProducts(
    LoadMoreProducts event,
    Emitter<VendorProductsState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ProductsLoaded || 
        currentState.hasReachedEnd || 
        currentState.isLoadingMore ||
        currentState.lastDocument == null) {
      return;
    }
    
    emit(currentState.copyWith(isLoadingMore: true));
    
    try {
      final query = _firestore
          .collection('vendor_products')
          .where('vendorId', isEqualTo: event.vendorId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(currentState.lastDocument!)
          .limit(_pageSize);
      
      final snapshot = await query.get();
      
      final newProducts = snapshot.docs
          .map((doc) => VendorProduct.fromFirestore(doc))
          .toList();
      
      emit(currentState.copyWith(
        products: [...currentState.products, ...newProducts],
        hasReachedEnd: snapshot.docs.length < _pageSize,
        isLoadingMore: false,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : currentState.lastDocument,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }
  
  Future<void> _onRefreshProducts(
    RefreshProducts event,
    Emitter<VendorProductsState> emit,
  ) async {
    emit(ProductsInitial());
    add(LoadProducts(event.vendorId));
  }
  
  Future<void> _onAddProduct(
    AddProduct event,
    Emitter<VendorProductsState> emit,
  ) async {
    try {
      await VendorProductService.createProduct(
        vendorId: event.vendorId,
        name: event.name,
        category: event.category,
        description: event.description,
        basePrice: event.basePrice,
        tags: event.tags,
      );
      
      // Refresh the products list
      add(RefreshProducts(event.vendorId));
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }
  
  Future<void> _onUpdateProduct(
    UpdateProduct event,
    Emitter<VendorProductsState> emit,
  ) async {
    try {
      await VendorProductService.updateProduct(
        productId: event.productId,
        name: event.name,
        category: event.category,
        description: event.description,
        basePrice: event.basePrice,
        tags: event.tags,
      );
      
      // Refresh the products list
      final currentState = state;
      if (currentState is ProductsLoaded) {
        add(RefreshProducts(currentState.vendorId));
      }
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }
  
  Future<void> _onDeleteProduct(
    DeleteProduct event,
    Emitter<VendorProductsState> emit,
  ) async {
    try {
      await VendorProductService.deleteProduct(event.productId);
      
      // Refresh the products list
      final currentState = state;
      if (currentState is ProductsLoaded) {
        add(RefreshProducts(currentState.vendorId));
      }
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }
}