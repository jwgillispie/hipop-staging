import 'package:flutter/material.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/shared/widgets/common/favorite_button.dart';

class VendorPostDetailScreen extends StatelessWidget {
  final VendorPost vendorPost;

  const VendorPostDetailScreen({
    super.key,
    required this.vendorPost,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(vendorPost.vendorName),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          FavoriteButton.post(
            postId: vendorPost.id,
            vendorId: vendorPost.vendorId,
            size: 24,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange,
                          radius: 30,
                          child: Text(
                            vendorPost.vendorName.isNotEmpty 
                                ? vendorPost.vendorName[0].toUpperCase() 
                                : 'V',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vendorPost.vendorName,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  'Independent Pop-up',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: vendorPost.isHappening 
                                ? Colors.green 
                                : vendorPost.isUpcoming 
                                    ? Colors.orange 
                                    : Colors.grey,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            vendorPost.isHappening 
                                ? 'LIVE NOW' 
                                : vendorPost.isUpcoming 
                                    ? 'UPCOMING' 
                                    : 'PAST EVENT',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Description
            Text(
              'About',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  vendorPost.description,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Event Details
            Text(
              'Event Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.access_time,
                      'Date & Time',
                      vendorPost.formattedDateTime,
                      vendorPost.formattedTimeRange,
                    ),
                    const Divider(),
                    _buildDetailRow(
                      Icons.location_on,
                      'Location',
                      vendorPost.location,
                      null,
                    ),
                    if (vendorPost.instagramHandle != null) ...[
                      const Divider(),
                      _buildDetailRow(
                        Icons.alternate_email,
                        'Instagram',
                        '@${vendorPost.instagramHandle!}',
                        null,
                        onTap: () => _showInstagramInfo(context, vendorPost.instagramHandle!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action Buttons
            if (vendorPost.isHappening || vendorPost.isUpcoming) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showLocationInfo(context, vendorPost.location),
                  icon: const Icon(Icons.directions),
                  label: Text(vendorPost.isHappening ? 'View Location' : 'Save Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            if (vendorPost.instagramHandle != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showInstagramInfo(context, vendorPost.instagramHandle!),
                  icon: const Icon(Icons.alternate_email),
                  label: const Text('Instagram Info'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String title,
    String value,
    String? subtitle, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.orange,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showLocationInfo(BuildContext context, String location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(location),
            const SizedBox(height: 16),
            const Text(
              'To get directions, copy this address and paste it into your preferred maps app.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Could implement clipboard copy here if needed
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Copy Address'),
          ),
        ],
      ),
    );
  }

  void _showInstagramInfo(BuildContext context, String handle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Follow on Instagram'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Instagram: @$handle'),
            const SizedBox(height: 16),
            const Text(
              'Search for this username on Instagram to follow this vendor.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}