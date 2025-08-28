import 'package:flutter/material.dart';
import '../../../../core/theme/hipop_colors.dart';

/// Reusable Vendor Error Widget
/// 
/// Provides consistent error display across vendor screens
/// Includes retry functionality and user-friendly messages
/// 
/// Usage:
/// ```dart
/// VendorErrorWidget(
///   title: 'Failed to load products',
///   message: 'Please check your connection and try again',
///   onRetry: () => _loadProducts(),
/// )
/// ```
class VendorErrorWidget extends StatelessWidget {
  final String title;
  final String? message;
  final String? errorCode;
  final VoidCallback? onRetry;
  final IconData icon;
  final ErrorSeverity severity;
  final Widget? customAction;
  final bool showDetails;

  const VendorErrorWidget({
    super.key,
    required this.title,
    this.message,
    this.errorCode,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.severity = ErrorSeverity.error,
    this.customAction,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getErrorConfig(severity);
    
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: config.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: config.iconColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: HiPopColors.lightTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: HiPopColors.lightTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (showDetails && errorCode != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: HiPopColors.lightBorder.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error Code: $errorCode',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: HiPopColors.lightTextTertiary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            if (onRetry != null) ...[
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: config.buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
            if (customAction != null) ...[
              if (onRetry != null) const SizedBox(height: 12),
              customAction!,
            ],
          ],
        ),
      ),
    );
  }

  _ErrorConfig _getErrorConfig(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.warning:
        return _ErrorConfig(
          backgroundColor: HiPopColors.warningAmberLight.withValues(alpha: 0.2),
          iconColor: HiPopColors.warningAmber,
          buttonColor: HiPopColors.warningAmber,
        );
      case ErrorSeverity.info:
        return _ErrorConfig(
          backgroundColor: HiPopColors.infoBlueGrayLight.withValues(alpha: 0.2),
          iconColor: HiPopColors.infoBlueGray,
          buttonColor: HiPopColors.infoBlueGray,
        );
      case ErrorSeverity.error:
        return _ErrorConfig(
          backgroundColor: HiPopColors.errorPlumLight.withValues(alpha: 0.2),
          iconColor: HiPopColors.errorPlum,
          buttonColor: HiPopColors.errorPlum,
        );
      case ErrorSeverity.critical:
        return _ErrorConfig(
          backgroundColor: HiPopColors.errorPlumDark.withValues(alpha: 0.2),
          iconColor: HiPopColors.errorPlumDark,
          buttonColor: HiPopColors.errorPlumDark,
        );
    }
  }
}

/// Inline error message for form fields and smaller spaces
class VendorErrorMessage extends StatelessWidget {
  final String message;
  final ErrorSeverity severity;
  final VoidCallback? onDismiss;
  final bool showIcon;

  const VendorErrorMessage({
    super.key,
    required this.message,
    this.severity = ErrorSeverity.error,
    this.onDismiss,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getErrorConfig(severity);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: config.iconColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          if (showIcon) ...[
            Icon(
              _getIconForSeverity(severity),
              size: 20,
              color: config.iconColor,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: config.iconColor,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(
                Icons.close,
                size: 18,
                color: config.iconColor,
              ),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  IconData _getIconForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.warning:
        return Icons.warning_amber;
      case ErrorSeverity.info:
        return Icons.info_outline;
      case ErrorSeverity.error:
      case ErrorSeverity.critical:
        return Icons.error_outline;
    }
  }

  _ErrorConfig _getErrorConfig(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.warning:
        return _ErrorConfig(
          backgroundColor: HiPopColors.warningAmberLight.withValues(alpha: 0.2),
          iconColor: HiPopColors.warningAmber,
          buttonColor: HiPopColors.warningAmber,
        );
      case ErrorSeverity.info:
        return _ErrorConfig(
          backgroundColor: HiPopColors.infoBlueGrayLight.withValues(alpha: 0.2),
          iconColor: HiPopColors.infoBlueGray,
          buttonColor: HiPopColors.infoBlueGray,
        );
      case ErrorSeverity.error:
        return _ErrorConfig(
          backgroundColor: HiPopColors.errorPlumLight.withValues(alpha: 0.2),
          iconColor: HiPopColors.errorPlum,
          buttonColor: HiPopColors.errorPlum,
        );
      case ErrorSeverity.critical:
        return _ErrorConfig(
          backgroundColor: HiPopColors.errorPlumDark.withValues(alpha: 0.2),
          iconColor: HiPopColors.errorPlumDark,
          buttonColor: HiPopColors.errorPlumDark,
        );
    }
  }
}

/// Toast-style error notification
class VendorErrorToast extends StatefulWidget {
  final String message;
  final ErrorSeverity severity;
  final Duration duration;
  final VoidCallback? onDismiss;

  const VendorErrorToast({
    super.key,
    required this.message,
    this.severity = ErrorSeverity.error,
    this.duration = const Duration(seconds: 4),
    this.onDismiss,
  });

  @override
  State<VendorErrorToast> createState() => _VendorErrorToastState();
}

class _VendorErrorToastState extends State<VendorErrorToast> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _controller.forward();
    
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _getErrorConfig(widget.severity);
    
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: config.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: config.iconColor.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                _getIconForSeverity(widget.severity),
                color: config.iconColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: config.iconColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: config.iconColor,
                  size: 20,
                ),
                onPressed: () {
                  _controller.reverse().then((_) {
                    widget.onDismiss?.call();
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForSeverity(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.warning:
        return Icons.warning_amber;
      case ErrorSeverity.info:
        return Icons.info_outline;
      case ErrorSeverity.error:
      case ErrorSeverity.critical:
        return Icons.error_outline;
    }
  }

  _ErrorConfig _getErrorConfig(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.warning:
        return _ErrorConfig(
          backgroundColor: HiPopColors.warningAmberLight.withValues(alpha: 0.95),
          iconColor: HiPopColors.warningAmber,
          buttonColor: HiPopColors.warningAmber,
        );
      case ErrorSeverity.info:
        return _ErrorConfig(
          backgroundColor: HiPopColors.infoBlueGrayLight.withValues(alpha: 0.95),
          iconColor: HiPopColors.infoBlueGray,
          buttonColor: HiPopColors.infoBlueGray,
        );
      case ErrorSeverity.error:
        return _ErrorConfig(
          backgroundColor: HiPopColors.errorPlumLight.withValues(alpha: 0.95),
          iconColor: HiPopColors.errorPlum,
          buttonColor: HiPopColors.errorPlum,
        );
      case ErrorSeverity.critical:
        return _ErrorConfig(
          backgroundColor: HiPopColors.errorPlumDark.withValues(alpha: 0.95),
          iconColor: Colors.white,
          buttonColor: HiPopColors.errorPlumDark,
        );
    }
  }
}

/// Configuration for error appearance
class _ErrorConfig {
  final Color backgroundColor;
  final Color iconColor;
  final Color buttonColor;

  const _ErrorConfig({
    required this.backgroundColor,
    required this.iconColor,
    required this.buttonColor,
  });
}

/// Error severity levels
enum ErrorSeverity {
  warning,
  info,
  error,
  critical,
}

/// Common error messages for vendor screens
class VendorErrorMessages {
  static const String networkError = 'Unable to connect to the server. Please check your internet connection.';
  static const String authError = 'Authentication failed. Please sign in again.';
  static const String permissionError = 'You don\'t have permission to perform this action.';
  static const String loadError = 'Failed to load data. Please try again.';
  static const String saveError = 'Failed to save changes. Please try again.';
  static const String deleteError = 'Failed to delete item. Please try again.';
  static const String uploadError = 'Failed to upload file. Please check your connection and try again.';
  static const String validationError = 'Please check your input and try again.';
  static const String serverError = 'Server error occurred. Please try again later.';
  static const String unknownError = 'An unexpected error occurred. Please try again.';
  static const String premiumRequired = 'This feature requires a premium subscription.';
  static const String quotaExceeded = 'You have reached your limit. Upgrade to premium for unlimited access.';
}