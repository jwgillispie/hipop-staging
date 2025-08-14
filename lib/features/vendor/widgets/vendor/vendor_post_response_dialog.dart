import 'package:flutter/material.dart';
import '../../../organizer/models/organizer_vendor_post.dart';
import '../../../organizer/models/vendor_post_response.dart';
import '../../../market/models/market.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/widgets/common/hipop_text_field.dart';

class VendorPostResponseDialog extends StatefulWidget {
  final OrganizerVendorPost post;
  final Market market;
  final UserProfile vendorProfile;
  final Function(VendorPostResponse) onSubmit;

  const VendorPostResponseDialog({
    super.key,
    required this.post,
    required this.market,
    required this.vendorProfile,
    required this.onSubmit,
  });

  @override
  State<VendorPostResponseDialog> createState() => _VendorPostResponseDialogState();
}

class _VendorPostResponseDialogState extends State<VendorPostResponseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  
  ResponseType _selectedResponseType = ResponseType.inquiry;
  bool _isSubmitting = false;
  
  final List<ResponseType> _responseTypes = [
    ResponseType.inquiry,
    ResponseType.application,
    ResponseType.interest,
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.campaign,
                        color: Colors.deepPurple.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Respond to Vendor Post',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple.shade800,
                              ),
                            ),
                            Text(
                              widget.post.title,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.deepPurple.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.market.name} • ${widget.market.city}, ${widget.market.state}',
                      style: TextStyle(
                        color: Colors.deepPurple.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Form content
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Response type selection
                      Text(
                        'Response Type',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(_responseTypes.map((type) => RadioListTile<ResponseType>(
                        title: Text(_getResponseTypeLabel(type)),
                        subtitle: Text(_getResponseTypeDescription(type)),
                        value: type,
                        groupValue: _selectedResponseType,
                        onChanged: (value) {
                          setState(() => _selectedResponseType = value!);
                        },
                        activeColor: Colors.deepPurple,
                        contentPadding: EdgeInsets.zero,
                      )).toList()),
                      
                      const SizedBox(height: 24),
                      
                      // Message field
                      Text(
                        'Your Message',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      HiPopTextField(
                        controller: _messageController,
                        labelText: 'Message to organizer',
                        hintText: _getMessageHint(),
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a message';
                          }
                          if (value.trim().length < 20) {
                            return 'Message should be at least 20 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Vendor profile summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Your Profile Summary',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Display Name: ${widget.vendorProfile.displayName}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Categories: ${widget.vendorProfile.categories.map(_formatCategoryName).join(', ')}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (widget.vendorProfile.email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Email: ${widget.vendorProfile.email}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'This information will be shared with the organizer',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text('Send ${_getResponseTypeLabel(_selectedResponseType)}'),
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

  String _getResponseTypeLabel(ResponseType type) {
    switch (type) {
      case ResponseType.inquiry:
        return 'Inquiry';
      case ResponseType.application:
        return 'Application';
      case ResponseType.interest:
        return 'Interest';
    }
  }

  String _getResponseTypeDescription(ResponseType type) {
    switch (type) {
      case ResponseType.inquiry:
        return 'Ask questions about the opportunity';
      case ResponseType.application:
        return 'Submit a formal application';
      case ResponseType.interest:
        return 'Express interest in the opportunity';
    }
  }

  String _getMessageHint() {
    switch (_selectedResponseType) {
      case ResponseType.inquiry:
        return 'What would you like to know about this opportunity? Ask about requirements, fees, dates, etc.';
      case ResponseType.application:
        return 'Tell the organizer why you\'d be a great fit for their market. Include your experience, products, and what you can offer.';
      case ResponseType.interest:
        return 'Let the organizer know you\'re interested and would like to learn more about this opportunity.';
    }
  }

  String _formatCategoryName(String category) {
    return category.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSubmitting = true);
    
    try {
      final response = VendorPostResponse(
        id: '', // Will be set by Firestore
        postId: widget.post.id,
        vendorId: widget.vendorProfile.userId,
        organizerId: widget.post.organizerId,
        marketId: widget.post.marketId,
        type: _selectedResponseType,
        message: _messageController.text.trim(),
        vendorProfile: VendorProfileSummary(
          displayName: widget.vendorProfile.displayName ?? 'Vendor',
          categories: widget.vendorProfile.categories,
          experience: 'Intermediate', // Default for now
          contactInfo: {
            'email': widget.vendorProfile.email,
            'phone': widget.vendorProfile.phoneNumber ?? '',
          },
        ),
        status: ResponseStatus.newResponse,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await widget.onSubmit(response);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}