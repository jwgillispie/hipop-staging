import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/premium_error_handler.dart';
import '../services/premium_network_service.dart';

/// 🔒 SECURE: User-friendly error recovery widgets for premium operations
/// 
/// This file provides:
/// - Error display widgets with recovery actions
/// - Network status indicators
/// - Retry mechanisms with smart delays
/// - User guidance for different error types
/// - Accessibility support for error messages
class PremiumErrorRecoveryWidgets {
  /// Display comprehensive error with recovery options
  static Widget buildErrorCard({
    required BuildContext context,
    required PremiumError error,
    VoidCallback? onRetry,
    VoidCallback? onCancel,
    VoidCallback? onContactSupport,
    bool showTechnicalDetails = false,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    return Card(
      color: _getErrorCardColor(context, error.type),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error header with icon
            Row(
              children: [
                Icon(
                  _getErrorIcon(error.type),
                  color: _getErrorColor(error.type),
                  size: 24,
                  semanticLabel: 'Error: ${error.type.name}',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getErrorTitle(error.type),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getErrorColor(error.type),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // User-friendly message
            Text(
              error.userMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            // Recovery action if available
            if (error.recoveryAction != null) ...[
              const SizedBox(height: 8),
              Text(
                error.recoveryAction!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            // Technical details (optional)
            if (showTechnicalDetails) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: Text(
                  'Technical Details',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Error Code', error.code),
                        _buildDetailRow('Error Type', error.type.name),
                        _buildDetailRow('Timestamp', error.timestamp.toLocal().toString()),
                        _buildDetailRow('Retryable', error.isRetryable ? 'Yes' : 'No'),
                        if (error.context != null)
                          _buildDetailRow('Context', error.context.toString()),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onCancel != null)
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                
                if (onContactSupport != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onContactSupport,
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Contact Support'),
                  ),
                ],
                
                if (onRetry != null && error.isRetryable) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// Build a simple error snackbar with recovery action
  static SnackBar buildErrorSnackBar({
    required BuildContext context,
    required PremiumError error,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 6),
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(
            _getErrorIcon(error.type),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error.userMessage,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: _getErrorColor(error.type),
      duration: duration,
      behavior: SnackBarBehavior.floating,
      action: error.isRetryable && onRetry != null
          ? SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
    );
  }
  
  /// Build network status indicator
  static Widget buildNetworkStatusIndicator() {
    return StreamBuilder<NetworkStatus>(
      stream: PremiumNetworkService.instance.statusStream,
      builder: (context, snapshot) {
        final status = snapshot.data ?? NetworkStatus.unknown;
        
        if (status == NetworkStatus.connected) {
          return const SizedBox.shrink(); // Hide when connected
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: _getNetworkStatusColor(status),
          child: Row(
            children: [
              Icon(
                _getNetworkStatusIcon(status),
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                _getNetworkStatusMessage(status),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  /// Build retry button with smart delay indication
  static Widget buildSmartRetryButton({
    required BuildContext context,
    required VoidCallback onRetry,
    required bool isRetrying,
    int? retryCount,
    Duration? nextRetryDelay,
    String label = 'Retry',
  }) {
    if (isRetrying) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
        label: const Text('Retrying...'),
      );
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
        
        if (retryCount != null && retryCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Attempt ${retryCount + 1}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
        
        if (nextRetryDelay != null) ...[
          const SizedBox(height: 4),
          Text(
            'Next retry in ${nextRetryDelay.inSeconds}s',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
  
  /// Build error dialog with comprehensive recovery options
  static Future<void> showErrorDialog({
    required BuildContext context,
    required PremiumError error,
    VoidCallback? onRetry,
    VoidCallback? onContactSupport,
    bool showTechnicalDetails = false,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _getErrorIcon(error.type),
                color: _getErrorColor(error.type),
              ),
              const SizedBox(width: 12),
              Text(_getErrorTitle(error.type)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error.userMessage),
                
                if (error.recoveryAction != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error.recoveryAction!,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                if (showTechnicalDetails) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Technical Information',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow('Code', error.code),
                        _buildDetailRow('Type', error.type.name),
                        _buildDetailRow('Time', error.timestamp.toLocal().toString().split('.')[0]),
                      ],
                    ),
                  ),
                  
                  // Copy technical details button
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _copyTechnicalDetails(context, error),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Details'),
                    style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            
            if (onContactSupport != null)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onContactSupport();
                },
                icon: const Icon(Icons.support_agent),
                label: const Text('Support'),
              ),
            
            if (onRetry != null && error.isRetryable)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetry();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
          ],
        );
      },
    );
  }
  
  /// Build loading state with cancel option
  static Widget buildLoadingWithCancel({
    required BuildContext context,
    String message = 'Processing...',
    VoidCallback? onCancel,
    double? progress,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress != null)
              LinearProgressIndicator(value: progress)
            else
              const LinearProgressIndicator(),
            
            const SizedBox(height: 16),
            
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            
            if (onCancel != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  // Helper methods
  static Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  static void _copyTechnicalDetails(BuildContext context, PremiumError error) {
    final details = '''
Error Code: ${error.code}
Error Type: ${error.type.name}
Message: ${error.message}
Timestamp: ${error.timestamp.toIso8601String()}
Retryable: ${error.isRetryable}
Context: ${error.context ?? 'None'}
''';
    
    Clipboard.setData(ClipboardData(text: details));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Technical details copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
  
  static IconData _getErrorIcon(PremiumErrorType type) {
    switch (type) {
      case PremiumErrorType.authentication:
        return Icons.lock_outline;
      case PremiumErrorType.authorization:
        return Icons.security;
      case PremiumErrorType.validation:
        return Icons.warning_amber;
      case PremiumErrorType.network:
        return Icons.wifi_off;
      case PremiumErrorType.timeout:
        return Icons.timer_off;
      case PremiumErrorType.rateLimit:
        return Icons.speed;
      case PremiumErrorType.service:
        return Icons.cloud_off;
      case PremiumErrorType.database:
        return Icons.storage;
      case PremiumErrorType.conflict:
        return Icons.merge_type;
      case PremiumErrorType.notFound:
        return Icons.search_off;
      case PremiumErrorType.payment:
        return Icons.payment;
      case PremiumErrorType.subscription:
        return Icons.card_membership;
      case PremiumErrorType.unknown:
        return Icons.error_outline;
    }
  }
  
  static Color _getErrorColor(PremiumErrorType type) {
    switch (type) {
      case PremiumErrorType.authentication:
      case PremiumErrorType.authorization:
        return Colors.red[700]!;
      case PremiumErrorType.validation:
        return Colors.orange[700]!;
      case PremiumErrorType.network:
      case PremiumErrorType.timeout:
        return Colors.blue[700]!;
      case PremiumErrorType.rateLimit:
        return Colors.purple[700]!;
      case PremiumErrorType.service:
      case PremiumErrorType.database:
        return Colors.grey[700]!;
      case PremiumErrorType.conflict:
        return Colors.amber[700]!;
      case PremiumErrorType.notFound:
        return Colors.brown[700]!;
      case PremiumErrorType.payment:
      case PremiumErrorType.subscription:
        return Colors.red[600]!;
      case PremiumErrorType.unknown:
        return Colors.red[800]!;
    }
  }
  
  static Color _getErrorCardColor(BuildContext context, PremiumErrorType type) {
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    
    switch (type) {
      case PremiumErrorType.authentication:
      case PremiumErrorType.authorization:
        return isLight ? Colors.red[50]! : Colors.red[900]!;
      case PremiumErrorType.validation:
        return isLight ? Colors.orange[50]! : Colors.orange[900]!;
      case PremiumErrorType.network:
      case PremiumErrorType.timeout:
        return isLight ? Colors.blue[50]! : Colors.blue[900]!;
      default:
        return isLight ? Colors.grey[50]! : Colors.grey[800]!;
    }
  }
  
  static String _getErrorTitle(PremiumErrorType type) {
    switch (type) {
      case PremiumErrorType.authentication:
        return 'Authentication Required';
      case PremiumErrorType.authorization:
        return 'Access Denied';
      case PremiumErrorType.validation:
        return 'Invalid Information';
      case PremiumErrorType.network:
        return 'Connection Error';
      case PremiumErrorType.timeout:
        return 'Request Timeout';
      case PremiumErrorType.rateLimit:
        return 'Too Many Requests';
      case PremiumErrorType.service:
        return 'Service Unavailable';
      case PremiumErrorType.database:
        return 'Data Service Error';
      case PremiumErrorType.conflict:
        return 'Conflict Detected';
      case PremiumErrorType.notFound:
        return 'Not Found';
      case PremiumErrorType.payment:
        return 'Payment Error';
      case PremiumErrorType.subscription:
        return 'Subscription Error';
      case PremiumErrorType.unknown:
        return 'Unexpected Error';
    }
  }
  
  static IconData _getNetworkStatusIcon(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.connected:
        return Icons.wifi;
      case NetworkStatus.disconnected:
        return Icons.wifi_off;
      case NetworkStatus.unknown:
        return Icons.help_outline;
    }
  }
  
  static Color _getNetworkStatusColor(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.connected:
        return Colors.green;
      case NetworkStatus.disconnected:
        return Colors.red;
      case NetworkStatus.unknown:
        return Colors.grey;
    }
  }
  
  static String _getNetworkStatusMessage(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.connected:
        return 'Connected';
      case NetworkStatus.disconnected:
        return 'No internet connection - Some features may not work';
      case NetworkStatus.unknown:
        return 'Checking connection...';
    }
  }
}