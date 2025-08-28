import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/hipop_colors.dart';

/// Reusable Sales Metric Tile Widget
/// 
/// For sales tracking screen with input field and validation
/// Provides consistent styling for sales data entry
/// 
/// Usage:
/// ```dart
/// SalesMetricTile(
///   title: 'Total Revenue',
///   value: 1250.00,
///   icon: Icons.attach_money,
///   onChanged: (value) => setState(() => revenue = value),
///   inputType: MetricInputType.currency,
/// )
/// ```
class SalesMetricTile extends StatelessWidget {
  final String title;
  final double? value;
  final IconData icon;
  final ValueChanged<double?> onChanged;
  final MetricInputType inputType;
  final String? hint;
  final String? suffix;
  final String? prefix;
  final bool isEditable;
  final bool showTrend;
  final double? trendValue;
  final double? min;
  final double? max;
  final String? errorText;
  final Color? accentColor;

  const SalesMetricTile({
    super.key,
    required this.title,
    this.value,
    required this.icon,
    required this.onChanged,
    this.inputType = MetricInputType.number,
    this.hint,
    this.suffix,
    this.prefix,
    this.isEditable = true,
    this.showTrend = false,
    this.trendValue,
    this.min,
    this.max,
    this.errorText,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? HiPopColors.successGreen;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: errorText != null 
            ? HiPopColors.errorPlum 
            : HiPopColors.lightBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.lightShadow.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.lightTextPrimary,
                        ),
                      ),
                      if (showTrend && trendValue != null)
                        _buildTrendIndicator(context),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isEditable)
              _buildInputField(context)
            else
              _buildDisplayValue(context),
            if (errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: HiPopColors.errorPlum,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(BuildContext context) {
    final theme = Theme.of(context);
    
    return TextFormField(
      initialValue: value?.toString(),
      keyboardType: _getKeyboardType(),
      inputFormatters: _getInputFormatters(),
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: HiPopColors.lightTextPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint ?? 'Enter value',
        hintStyle: TextStyle(
          color: HiPopColors.lightTextTertiary,
          fontWeight: FontWeight.normal,
        ),
        prefixText: prefix,
        suffixText: suffix,
        prefixStyle: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: HiPopColors.lightTextPrimary,
        ),
        suffixStyle: theme.textTheme.bodyLarge?.copyWith(
          color: HiPopColors.lightTextSecondary,
        ),
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            color: HiPopColors.lightBorder,
          ),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: HiPopColors.lightBorder,
          ),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: accentColor ?? HiPopColors.successGreen,
            width: 2,
          ),
        ),
        errorBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: HiPopColors.errorPlum,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
      ),
      onChanged: (text) {
        final parsed = _parseValue(text);
        if (parsed != null) {
          if (min != null && parsed < min!) return;
          if (max != null && parsed > max!) return;
        }
        onChanged(parsed);
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return null; // Allow empty values
        }
        final parsed = _parseValue(value);
        if (parsed == null) {
          return 'Invalid ${inputType.name}';
        }
        if (min != null && parsed < min!) {
          return 'Minimum value is ${_formatValue(min!)}';
        }
        if (max != null && parsed > max!) {
          return 'Maximum value is ${_formatValue(max!)}';
        }
        return null;
      },
    );
  }

  Widget _buildDisplayValue(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = value != null ? _formatValue(value!) : '--';
    
    return Text(
      '$prefix$displayValue$suffix',
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: HiPopColors.lightTextPrimary,
      ),
    );
  }

  Widget _buildTrendIndicator(BuildContext context) {
    if (trendValue == null) return const SizedBox.shrink();
    
    final isPositive = trendValue! > 0;
    final trendColor = isPositive 
      ? HiPopColors.successGreen 
      : HiPopColors.errorPlum;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPositive ? Icons.trending_up : Icons.trending_down,
          size: 14,
          color: trendColor,
        ),
        const SizedBox(width: 2),
        Text(
          '${trendValue!.abs().toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 11,
            color: trendColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  TextInputType _getKeyboardType() {
    switch (inputType) {
      case MetricInputType.currency:
      case MetricInputType.number:
      case MetricInputType.decimal:
        return const TextInputType.numberWithOptions(decimal: true);
      case MetricInputType.integer:
      case MetricInputType.quantity:
        return const TextInputType.numberWithOptions(decimal: false);
      case MetricInputType.percentage:
        return const TextInputType.numberWithOptions(decimal: true);
    }
  }

  List<TextInputFormatter> _getInputFormatters() {
    switch (inputType) {
      case MetricInputType.currency:
      case MetricInputType.decimal:
      case MetricInputType.number:
        return [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ];
      case MetricInputType.integer:
      case MetricInputType.quantity:
        return [
          FilteringTextInputFormatter.digitsOnly,
        ];
      case MetricInputType.percentage:
        return [
          FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}\.?\d{0,2}')),
          _PercentageInputFormatter(),
        ];
    }
  }

  double? _parseValue(String text) {
    if (text.isEmpty) return null;
    try {
      return double.parse(text.replaceAll(',', ''));
    } catch (e) {
      return null;
    }
  }

  String _formatValue(double value) {
    switch (inputType) {
      case MetricInputType.currency:
        return value.toStringAsFixed(2);
      case MetricInputType.integer:
      case MetricInputType.quantity:
        return value.toInt().toString();
      case MetricInputType.percentage:
        return value.toStringAsFixed(1);
      case MetricInputType.decimal:
      case MetricInputType.number:
        return value.toString();
    }
  }
}

/// Quick entry sales metric tile for rapid data entry
class QuickSalesMetricTile extends StatelessWidget {
  final String title;
  final double? value;
  final IconData icon;
  final ValueChanged<double?> onChanged;
  final Color? accentColor;

  const QuickSalesMetricTile({
    super.key,
    required this.title,
    this.value,
    required this.icon,
    required this.onChanged,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? HiPopColors.successGreen;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: TextFormField(
              initialValue: value?.toString(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  color: HiPopColors.lightTextTertiary,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (text) {
                final parsed = double.tryParse(text);
                onChanged(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Percentage input formatter to limit values to 0-100
class _PercentageInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    
    final value = double.tryParse(newValue.text);
    if (value != null && value > 100) {
      return oldValue;
    }
    
    return newValue;
  }
}

/// Input types for metric tiles
enum MetricInputType {
  currency,
  number,
  decimal,
  integer,
  percentage,
  quantity,
}