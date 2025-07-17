import 'package:flutter/material.dart';
import '../services/url_launcher_service.dart';

class LegalDocumentsScreen extends StatelessWidget {
  const LegalDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Legal Documents'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Header
                const Text(
                  'Legal Information',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please review our legal documents and policies',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Legal Document Cards
                Expanded(
                  child: Column(
                    children: [
                      _buildDocumentCard(
                        context: context,
                        title: 'Terms of Service',
                        description: 'Our terms and conditions for using HiPop Markets',
                        icon: Icons.description,
                        color: Colors.orange,
                        url: 'https://hipop-markets-website.web.app/terms',
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDocumentCard(
                        context: context,
                        title: 'Privacy Policy',
                        description: 'How we collect, use, and protect your information',
                        icon: Icons.privacy_tip,
                        color: Colors.blue,
                        url: 'https://hipop-markets-website.web.app/privacy',
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDocumentCard(
                        context: context,
                        title: 'User Agreement',
                        description: 'Guidelines for using our platform responsibly',
                        icon: Icons.handshake,
                        color: Colors.green,
                        url: 'https://hipop-markets-website.web.app/user-agreement',
                      ),
                    ],
                  ),
                ),

                // Contact Information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.support_agent,
                        color: Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Questions or Concerns?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Contact us for any legal document questions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _launchEmail(context),
                        icon: const Icon(Icons.email, size: 18),
                        label: const Text('support@hipopmarkets.com'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String url,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: () => _launchDocument(context, title, url),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                color.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchDocument(BuildContext context, String title, String url) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await UrlLauncherService.launchWebsite(url);
      
      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Close loading indicator
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open $title. Please try again.'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _launchDocument(context, title, url),
            ),
          ),
        );
      }
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    try {
      await UrlLauncherService.launchEmail('support@hipopmarkets.com');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open email app. Please contact support@hipopmarkets.com'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
}