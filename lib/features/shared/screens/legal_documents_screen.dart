import 'package:flutter/foundation.dart';
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
                        description: 'Comprehensive terms for the HiPop three-sided marketplace platform',
                        icon: Icons.description,
                        color: Colors.orange,
                        onTap: () => _showTermsDialog(context),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDocumentCard(
                        context: context,
                        title: 'Privacy Policy',
                        description: 'Data collection, analytics usage, and privacy protection details',
                        icon: Icons.privacy_tip,
                        color: Colors.blue,
                        onTap: () => _showPrivacyDialog(context),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildDocumentCard(
                        context: context,
                        title: 'Payment Terms',
                        description: 'Vendor and organizer subscriptions, Stripe integration, and payment security',
                        icon: Icons.payment,
                        color: Colors.green,
                        onTap: () => _showPaymentTermsDialog(context),
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
                        label: const Text('hipopmarkets@gmail.com'),
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
    VoidCallback? onTap,
    String? url,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap ?? (url != null ? () => _launchDocument(context, title, url) : null),
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
      await UrlLauncherService.launchEmail('hipopmarkets@gmail.com');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open email app. Please contact hipopmarkets@gmail.com'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showTermsDialog(BuildContext context) {
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: SingleChildScrollView(
          child: Text(
'''HiPop Markets Terms of Service

ABOUT HIPOP MARKETS
HiPop is a comprehensive three-sided marketplace platform that connects vendors, shoppers, and market organizers in the local pop-up market ecosystem. Our app facilitates discovery, booking, payment processing, and analytics across all user types.

USER TYPES AND FEATURES:

1. SHOPPERS (Free)
   • Discover local pop-up markets and vendors
   • Browse vendor products and services
   • Save favorite vendors and events
   • Access enhanced search and filtering
   • All features are free for shoppers

2. VENDORS (\$29/month premium tier)
   • Create and manage vendor profiles
   • Post products and services
   • Apply to participate in markets
   • Track sales and analytics
   • Premium: Advanced analytics, priority market placement, bulk messaging

3. MARKET ORGANIZERS (\$69/month premium tier)
   • Create and manage market events
   • Recruit and approve vendors
   • Manage market logistics
   • Access comprehensive analytics
   • Premium: Advanced reporting, vendor directory access, bulk communications

PAYMENT PROCESSING:
• All payments are processed securely through Stripe
• Subscription billing is automated and recurring
• Payment methods include cards, Apple Pay, and Google Pay
• All transactions are encrypted and PCI compliant
• Refunds are processed according to our refund policy

ANALYTICS AND DATA USAGE:
• We collect usage data to improve platform performance
• Analytics help vendors understand customer engagement
• Market organizers receive attendance and vendor performance metrics
• All data collection complies with privacy regulations
• Users can request data deletion per GDPR/CCPA requirements

MARKETPLACE RULES:
• All content must be accurate and appropriate
• Vendors must honor posted prices and availability
• Market organizers must provide accurate event information
• Users are responsible for their own transactions and agreements
• HiPop facilitates connections but does not guarantee outcomes

PLATFORM RESPONSIBILITIES:
• Maintain secure, reliable platform access
• Process payments and subscriptions accurately
• Provide customer support and dispute resolution
• Protect user data and privacy
• Ensure platform compliance with applicable laws

By using HiPop, you agree to these terms, our Privacy Policy, and Payment Terms.

Last updated: 2024''',
            style: TextStyle(fontSize: 14),
          ),
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

  void _showPrivacyDialog(BuildContext context) {
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Text(
'''HiPop Markets Privacy Policy

DATA COLLECTION:
We collect information you provide directly, including:
• Account registration data (name, email, user type)
• Profile information and preferences
• Payment and subscription information
• Content you create (vendor posts, market listings)
• Communication and support interactions

ANALYTICS AND USAGE DATA:
• App usage patterns and feature interactions
• Device information and technical specifications
• Location data (when permitted) for market discovery
• Performance metrics and error reporting
• User engagement and session analytics

THIRD-PARTY INTEGRATIONS:
• Stripe for payment processing and subscription management
• Google Cloud Platform for data storage and analytics
• Firebase for user authentication and real-time features
• Google Maps for location services

HOW WE USE YOUR DATA:
• Provide and improve platform services
• Process payments and manage subscriptions
• Generate analytics and insights for all user types
• Send relevant notifications and updates
• Ensure platform security and prevent fraud
• Comply with legal and regulatory requirements

DATA SHARING:
• We do not sell personal information to third parties
• Aggregate analytics may be shared with market organizers
• Payment processing requires sharing data with Stripe
• We may share data to comply with legal requirements

YOUR RIGHTS:
• Access and update your profile information
• Request data deletion (subject to legal requirements)
• Opt out of non-essential communications
• Control location sharing permissions
• Review and manage subscription settings

SECURITY MEASURES:
• End-to-end encryption for sensitive data
• Regular security audits and penetration testing
• Secure cloud infrastructure with access controls
• PCI DSS compliance for payment processing
• Employee data access is strictly limited and monitored

RETENTION:
• Account data retained while account is active
• Payment records retained per legal requirements
• Analytics data may be retained in aggregate form
• Deleted account data purged within 30 days

For questions about privacy, contact: hipopmarkets@gmail.com

Last updated: 2024''',
            style: TextStyle(fontSize: 14),
          ),
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

  void _showPaymentTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Terms'),
        content: SingleChildScrollView(
          child: Text(
            '''HiPop Markets Payment Terms

SUBSCRIPTION TIERS:

Vendor Premium - \$29.00/month
• Advanced analytics dashboard
• Priority placement in market search results
• Bulk messaging capabilities
• Enhanced vendor profile features
• Sales tracking and performance metrics

Market Organizer Premium - \$69.00/month
• Comprehensive vendor management tools
• Advanced reporting and analytics
• Vendor directory access and recruitment tools
• Bulk communication features
• Priority support and consultation

PAYMENT PROCESSING:
• All payments processed through Stripe, Inc.
• Stripe handles payment security and PCI compliance
• Automatic recurring billing on subscription date
• Payment methods: Credit/debit cards, Apple Pay, Google Pay
• Secure tokenization prevents storage of payment details

BILLING POLICIES:
• Subscriptions billed monthly in advance
• Payment due on signup date each month
• Failed payments result in immediate service suspension
• Grace period of 3 days for payment resolution
• Account closure after 7 days of non-payment

PROMO CODES AND DISCOUNTS:
• Promotional codes may be available for new subscribers
• Discounts apply to first billing cycle unless specified
• Cannot be combined with other promotional offers
• Expires if not used within specified timeframe
• Subject to verification and fraud prevention

REFUND POLICY:
• No refunds for partial month usage
• Technical issues may warrant prorated refunds
• Refund requests must be made within 30 days
• Processing time: 5-10 business days
• Refunds issued to original payment method

PAYMENT SECURITY:
• End-to-end encryption for all transactions
• Tokenization prevents storage of card numbers
• Regular security audits and compliance checks
• Fraud detection and prevention systems
• Immediate notification of suspicious activity

SUBSCRIPTION MANAGEMENT:
• Cancel anytime through app settings
• Cancellation effective at end of billing period
• Automatic renewal unless cancelled
• Upgrade/downgrade processed immediately
• Prorated charges for mid-cycle changes

TAXES:
• Prices do not include applicable taxes
• Tax calculation based on billing address
• Compliance with state and federal tax laws
• Tax receipts available upon request

For payment support, contact: hipopmarkets@gmail.com

Last updated: 2024''',
            style: TextStyle(fontSize: 14),
          ),
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