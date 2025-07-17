import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class VendorApplicationLinkShareWidget extends StatelessWidget {
  final String marketId;
  final String marketName;

  const VendorApplicationLinkShareWidget({
    super.key,
    required this.marketId,
    required this.marketName,
  });

  String get productionUrl => 'https://hipop-markets-website.web.app/apply/$marketId';
  String get developmentUrl => 'hipop://apply/$marketId';

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.9; // Use 90% of screen height
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: maxHeight,
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.share,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Share Application Link',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'For $marketName',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[100],
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // QR Code Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QrImageView(
                      data: productionUrl,
                      version: QrVersions.auto,
                      size: 150,
                      gapless: false,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                      errorStateBuilder: (cxt, err) {
                        return const Center(
                          child: Text(
                            'QR Code Error',
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vendors can scan this QR code to apply instantly',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // URL Section
            const Text(
              'Application Link',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          productionUrl,
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copyToClipboard(context, productionUrl, 'Link'),
                        icon: const Icon(Icons.copy, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue[100],
                          minimumSize: const Size(32, 32),
                        ),
                        tooltip: 'Copy Link',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Text(
                        'How to Share',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Share the QR code for instant scanning\n'
                    '• Copy and paste the link via email/text\n'
                    '• Vendors don\'t need an account to apply\n'
                    '• Applications are automatically linked to your market',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[800],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareLink(context),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _copyToClipboard(context, productionUrl, 'Application link'),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            
            // Development URL (Debug mode only)
            if (const bool.fromEnvironment('dart.vm.product') == false) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Development Test URL',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        developmentUrl,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copyToClipboard(context, developmentUrl, 'Test URL'),
                      icon: const Icon(Icons.copy, size: 14),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        minimumSize: const Size(24, 24),
                      ),
                      tooltip: 'Copy Test URL',
                    ),
                  ],
                ),
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => scaffoldMessenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _shareLink(BuildContext context) {
    // For now, just copy to clipboard
    // In production, you might want to integrate with share_plus package
    _copyToClipboard(context, productionUrl, 'Application link');
    
    // Optional: Show additional sharing options
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Options'),
        content: const Text(
          'The link has been copied to your clipboard. You can now:\n\n'
          '• Paste it into an email\n'
          '• Send it via text message\n'
          '• Share it on social media\n'
          '• Print the QR code for physical posting',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}