import 'package:flutter/material.dart';
import '../services/vendor_market_items_service.dart';
import '../../shared/services/user_profile_service.dart';

class VendorMarketItemsEditScreen extends StatefulWidget {
  final String marketId;
  final String marketName;
  final List<String> currentItems;
  final String vendorId;

  const VendorMarketItemsEditScreen({
    super.key,
    required this.marketId,
    required this.marketName,
    required this.currentItems,
    required this.vendorId,
  });

  @override
  State<VendorMarketItemsEditScreen> createState() => _VendorMarketItemsEditScreenState();
}

class _VendorMarketItemsEditScreenState extends State<VendorMarketItemsEditScreen> {
  final TextEditingController _itemController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<String> _items = [];
  bool _isLoading = false;
  bool _isPremium = false;
  int _maxItems = 3; // Default for free users

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.currentItems);
    _checkPremiumStatus();
  }

  @override
  void dispose() {
    _itemController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final userProfile = await UserProfileService().getUserProfile(widget.vendorId);
      setState(() {
        _isPremium = userProfile?.isPremium ?? false;
        _maxItems = _isPremium ? -1 : 3; // -1 = unlimited
      });
    } catch (e) {
      debugPrint('Error checking premium status: $e');
    }
  }

  bool get _canAddMoreItems {
    if (_isPremium) return true;
    return _items.length < _maxItems;
  }

  String get _limitText {
    if (_isPremium) return 'Unlimited items (Vendor Pro)';
    return 'Free: ${_items.length}/$_maxItems items';
  }

  void _addItem() {
    final text = _itemController.text.trim();
    if (text.isEmpty) return;

    if (!_canAddMoreItems) {
      _showUpgradeDialog();
      return;
    }

    if (_items.contains(text)) {
      _showErrorSnackBar('Item already exists');
      return;
    }

    setState(() {
      _items.add(text);
      _itemController.clear();
    });

    // Scroll to bottom to show new item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _showUpgradeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.diamond, color: Colors.amber),
            SizedBox(width: 8),
            Text('Upgrade to Vendor Premium'),
          ],
        ),
        content: const Text(
          'Free vendors can only add up to 3 items per market.\n\nUpgrade to Vendor Premium (\$29/month) for unlimited items, plus analytics and market discovery features!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await VendorMarketItemsService.updateVendorMarketItems(
        widget.vendorId,
        widget.marketId,
        _items,
      );

      if (mounted) {
        if (success) {
          _showSuccessSnackBar('Items updated successfully!');
          Navigator.pop(context, _items); // Return updated items
        } else {
          _showErrorSnackBar('Failed to update items. Please try again.');
        }
      }
    } catch (e) {
      debugPrint('Error saving items: $e');
      if (mounted) {
        _showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Market Items'),
            Text(
              widget.marketName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveItems,
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header with limits info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isPremium ? Colors.amber.shade50 : Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(
                  color: _isPremium ? Colors.amber.shade200 : Colors.grey.shade300,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isPremium ? Icons.diamond : Icons.info_outline,
                      color: _isPremium ? Colors.amber.shade700 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _limitText,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _isPremium ? Colors.amber.shade700 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!_isPremium) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Upgrade to Vendor Premium for unlimited items per market',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Add new item section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New Item',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _itemController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Fresh Tomatoes, Honey, Apple Pie',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Icon(Icons.add_box_outlined),
                          enabled: !_isLoading,
                        ),
                        textCapitalization: TextCapitalization.words,
                        onSubmitted: (_) => _addItem(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _addItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Current items list
          Expanded(
            child: _items.isEmpty ? _buildEmptyState() : _buildItemsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No Items Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items that you want to feature at ${widget.marketName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Shoppers will see these items when browsing this market',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 20,
              ),
            ),
            title: Text(
              item,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: IconButton(
              onPressed: _isLoading ? null : () => _removeItem(index),
              icon: Icon(
                Icons.delete_outline,
                color: Colors.red.shade600,
              ),
              tooltip: 'Remove item',
            ),
          ),
        );
      },
    );
  }
}