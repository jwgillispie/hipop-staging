import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

import '../models/vendor_sales_data.dart';
import '../services/vendor_sales_service.dart';
import '../../shared/services/real_time_analytics_service.dart';

/// Vendor Sales Tracker Screen
/// 
/// Provides a mobile-optimized interface for vendors to:
/// - Enter daily/weekly sales data
/// - Track product performance  
/// - Monitor revenue, commissions, and fees
/// - Export data for business reporting
class VendorSalesTrackerScreen extends StatefulWidget {
  final String? marketId;
  final DateTime? selectedDate;

  const VendorSalesTrackerScreen({
    super.key,
    this.marketId,
    this.selectedDate,
  });

  @override
  State<VendorSalesTrackerScreen> createState() => _VendorSalesTrackerScreenState();
}

class _VendorSalesTrackerScreenState extends State<VendorSalesTrackerScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _salesService = VendorSalesService();
  
  late TabController _tabController;
  
  // Form controllers
  final _totalRevenueController = TextEditingController();
  final _transactionCountController = TextEditingController();
  final _marketFeeController = TextEditingController();
  final _commissionRateController = TextEditingController();
  final _notesController = TextEditingController();
  
  // State variables
  DateTime _selectedDate = DateTime.now();
  String? _selectedMarketId;
  List<ProductSaleData> _products = [];
  bool _isLoading = false;
  bool _isSaving = false;
  VendorSalesData? _existingSalesData;
  
  // Quick entry mode for busy vendors
  bool _quickEntryMode = false;
  
  // Pre-defined product categories for quick selection
  final List<String> _productCategories = [
    'Fresh Produce',
    'Prepared Foods',
    'Baked Goods',
    'Beverages',
    'Crafts & Art',
    'Clothing & Accessories',
    'Health & Beauty',
    'Home & Garden',
    'Other',
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = widget.selectedDate ?? DateTime.now();
    _selectedMarketId = widget.marketId;
    _commissionRateController.text = '5.0'; // Default 5% commission
    _loadExistingSalesData();
    
    // Track screen view
    RealTimeAnalyticsService.trackPageView(
      'vendor_sales_tracker',
      FirebaseAuth.instance.currentUser?.uid,
      metadata: {
        'marketId': _selectedMarketId,
        'date': _selectedDate.toIso8601String(),
      },
    );
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _totalRevenueController.dispose();
    _transactionCountController.dispose();
    _marketFeeController.dispose();
    _commissionRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _loadExistingSalesData() async {
    if (_selectedMarketId == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final salesData = await _salesService.getSalesDataForDate(
        vendorId: FirebaseAuth.instance.currentUser!.uid,
        marketId: _selectedMarketId!,
        date: _selectedDate,
      );
      
      if (salesData != null && mounted) {
        setState(() {
          _existingSalesData = salesData;
          _totalRevenueController.text = salesData.revenue.toStringAsFixed(2);
          _transactionCountController.text = salesData.transactions.toString();
          _marketFeeController.text = salesData.marketFee.toStringAsFixed(2);
          _commissionRateController.text = (salesData.commissionPaid / salesData.revenue * 100).toStringAsFixed(2);
          _notesController.text = salesData.notes ?? '';
          _products = List.from(salesData.products);
        });
      }
    } catch (e) {
      if (mounted) _showError('Error loading sales data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _saveSalesData() async {
    if (!_formKey.currentState!.validate() || _selectedMarketId == null) {
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final revenue = double.tryParse(_totalRevenueController.text) ?? 0.0;
      final transactions = int.tryParse(_transactionCountController.text) ?? 0;
      final marketFee = double.tryParse(_marketFeeController.text) ?? 0.0;
      final commissionRate = double.tryParse(_commissionRateController.text) ?? 5.0;
      final commissionPaid = revenue * (commissionRate / 100);
      
      final salesData = VendorSalesData(
        id: _existingSalesData?.id ?? '',
        vendorId: FirebaseAuth.instance.currentUser!.uid,
        marketId: _selectedMarketId!,
        date: _selectedDate,
        revenue: revenue,
        transactions: transactions,
        products: _products,
        commissionPaid: commissionPaid,
        marketFee: marketFee,
        photoUrls: [], // Empty for now since no image picker
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: _existingSalesData?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        status: VendorSalesStatus.submitted,
      );
      
      if (_existingSalesData != null) {
        await _salesService.updateSalesData(salesData);
      } else {
        await _salesService.createSalesData(salesData);
      }
      
      // Track sales entry completion
      await RealTimeAnalyticsService.trackEvent(
        'sales_data_saved',
        {
          'marketId': _selectedMarketId,
          'date': _selectedDate.toIso8601String(),
          'revenue': revenue,
          'transactions': transactions,
          'productsCount': _products.length,
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_existingSalesData != null ? 'Sales data updated!' : 'Sales data saved!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pop(salesData);
      }
      
    } catch (e) {
      if (mounted) _showError('Error saving sales data: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Tracker'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.attach_money), text: 'Revenue'),
            Tab(icon: Icon(Icons.inventory), text: 'Products'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_quickEntryMode ? Icons.edit : Icons.flash_on),
            onPressed: () {
              setState(() => _quickEntryMode = !_quickEntryMode);
            },
            tooltip: _quickEntryMode ? 'Detailed Entry' : 'Quick Entry',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRevenueTab(),
                  _buildProductsTab(),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _saveSalesData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              minimumSize: const Size.fromHeight(56),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    _existingSalesData != null ? 'UPDATE SALES DATA' : 'SAVE SALES DATA',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildRevenueTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector(),
          const SizedBox(height: 24),
          _buildMarketSelector(),
          const SizedBox(height: 24),
          if (_quickEntryMode) _buildQuickEntryCard() else _buildDetailedRevenueForm(),
        ],
      ),
    );
  }
  
  Widget _buildDateSelector() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.calendar_today, color: Colors.blue),
        title: const Text('Sales Date'),
        subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now(),
          );
          
          if (date != null) {
            setState(() => _selectedDate = date);
            _loadExistingSalesData();
          }
        },
      ),
    );
  }
  
  Widget _buildMarketSelector() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.green),
        title: const Text('Market'),
        subtitle: Text(_selectedMarketId ?? 'Select a market'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Implement market selection dialog
          _showError('Market selection coming soon!');
        },
      ),
    );
  }
  
  Widget _buildQuickEntryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Entry Mode',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _totalRevenueController,
              decoration: const InputDecoration(
                labelText: 'Total Revenue',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                if (double.tryParse(value!) == null) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _transactionCountController,
              decoration: const InputDecoration(
                labelText: 'Number of Transactions',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value?.isEmpty ?? true) return 'Required';
                if (int.tryParse(value!) == null) return 'Invalid number';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailedRevenueForm() {
    final revenue = double.tryParse(_totalRevenueController.text) ?? 0.0;
    final commissionRate = double.tryParse(_commissionRateController.text) ?? 5.0;
    final marketFee = double.tryParse(_marketFeeController.text) ?? 0.0;
    final commissionPaid = revenue * (commissionRate / 100);
    final netRevenue = revenue - commissionPaid - marketFee;
    
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Revenue Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _totalRevenueController,
                  decoration: const InputDecoration(
                    labelText: 'Total Revenue',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                    helperText: 'Gross sales before fees',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (double.tryParse(value!) == null) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _transactionCountController,
                  decoration: const InputDecoration(
                    labelText: 'Number of Transactions',
                    border: OutlineInputBorder(),
                    helperText: 'Total sales transactions',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (int.tryParse(value!) == null) return 'Invalid number';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fees & Commissions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _commissionRateController,
                  decoration: const InputDecoration(
                    labelText: 'Commission Rate',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    helperText: 'Market commission percentage',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    final rate = double.tryParse(value!);
                    if (rate == null || rate < 0 || rate > 50) {
                      return 'Rate must be between 0% and 50%';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _marketFeeController,
                  decoration: const InputDecoration(
                    labelText: 'Market Fee',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                    helperText: 'Fixed fees (booth, setup, etc.)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    if (value?.isNotEmpty == true && double.tryParse(value!) == null) {
                      return 'Invalid amount';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Revenue Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow('Gross Revenue', '\$${revenue.toStringAsFixed(2)}'),
                _buildSummaryRow('Commission (${commissionRate.toStringAsFixed(1)}%)', 
                    '-\$${commissionPaid.toStringAsFixed(2)}'),
                _buildSummaryRow('Market Fee', '-\$${marketFee.toStringAsFixed(2)}'),
                const Divider(),
                _buildSummaryRow('Net Revenue', '\$${netRevenue.toStringAsFixed(2)}', 
                    isTotal: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
                helperText: 'Additional notes about this sales day',
              ),
              maxLines: 3,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? Theme.of(context).primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProductsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Products (${_products.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addProduct,
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No products added yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track individual product performance\nfor better insights',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(_products[index], index);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildProductCard(ProductSaleData product, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Text(
            product.name.isNotEmpty ? product.name[0].toUpperCase() : 'P',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${product.category} • ${product.quantitySold} sold'),
            Text('\$${product.unitPrice.toStringAsFixed(2)} each • \$${product.totalRevenue.toStringAsFixed(2)} total'),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'edit') {
              _editProduct(index);
            } else if (value == 'delete') {
              _deleteProduct(index);
            }
          },
        ),
        onTap: () => _editProduct(index),
      ),
    );
  }
  
  void _addProduct() {
    _showProductDialog();
  }
  
  void _editProduct(int index) {
    _showProductDialog(existingProduct: _products[index], index: index);
  }
  
  void _deleteProduct(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Remove "${_products[index].name}" from sales data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _products.removeAt(index));
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
  
  void _showProductDialog({ProductSaleData? existingProduct, int? index}) {
    final isEditing = existingProduct != null;
    final nameController = TextEditingController(text: existingProduct?.name ?? '');
    String selectedCategory = existingProduct?.category ?? _productCategories.first;
    final quantityController = TextEditingController(
        text: existingProduct?.quantitySold.toString() ?? '');
    final unitPriceController = TextEditingController(
        text: existingProduct?.unitPrice.toStringAsFixed(2) ?? '');
    final costPriceController = TextEditingController(
        text: existingProduct?.costPrice.toStringAsFixed(2) ?? '');
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Product' : 'Add Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _productCategories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedCategory = value ?? _productCategories.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity Sold',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: unitPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Unit Price',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: costPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Cost Price (Optional)',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                    helperText: 'Your cost to calculate profit margin',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final quantity = int.tryParse(quantityController.text) ?? 0;
                final unitPrice = double.tryParse(unitPriceController.text) ?? 0.0;
                final costPrice = double.tryParse(costPriceController.text) ?? 0.0;
                
                if (name.isEmpty || quantity <= 0 || unitPrice <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                final product = ProductSaleData(
                  name: name,
                  category: selectedCategory,
                  quantitySold: quantity,
                  unitPrice: unitPrice,
                  totalRevenue: quantity * unitPrice,
                  costPrice: costPrice,
                );
                
                setState(() {
                  if (isEditing && index != null) {
                    _products[index] = product;
                  } else {
                    _products.add(product);
                  }
                });
                
                Navigator.of(context).pop();
              },
              child: Text(isEditing ? 'Update' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}