import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hipop/features/shared/services/analytics_service.dart';

class VendorRegistrationsChart extends StatefulWidget {
  final String marketId;
  final int monthsBack;

  const VendorRegistrationsChart({
    super.key,
    required this.marketId,
    this.monthsBack = 6,
  });

  @override
  State<VendorRegistrationsChart> createState() => _VendorRegistrationsChartState();
}

class _VendorRegistrationsChartState extends State<VendorRegistrationsChart> {
  List<Map<String, dynamic>> _chartData = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChartData();
  }

  Future<void> _loadChartData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final data = await AnalyticsService.getVendorRegistrationsByMonth(
        widget.marketId,
        widget.monthsBack,
      );

      setState(() {
        _chartData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error Loading Chart',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadChartData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_chartData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.bar_chart, color: Colors.grey, size: 48),
              const SizedBox(height: 16),
              Text(
                'No Data Available',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'No vendor registrations found for the selected time period.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Vendor Registrations by Month',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadChartData,
                  tooltip: 'Refresh Data',
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 1,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey[300]!,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < _chartData.length) {
                            final monthName = _chartData[index]['monthName'] as String;
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              child: Text(
                                monthName,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        },
                        reservedSize: 32,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  minX: 0,
                  maxX: (_chartData.length - 1).toDouble(),
                  minY: 0,
                  maxY: _getMaxY().toDouble(),
                  lineBarsData: [
                    // Total line
                    LineChartBarData(
                      spots: _createSpots('total'),
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.blue[400]!,
                          Colors.blue[600]!,
                        ],
                      ),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.blue[600]!,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue[400]!.withValues(alpha: 0.3),
                            Colors.blue[600]!.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    // Approved line
                    LineChartBarData(
                      spots: _createSpots('approved'),
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.green[400]!,
                          Colors.green[600]!,
                        ],
                      ),
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: Colors.green[600]!,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    ),
                    // Pending line
                    LineChartBarData(
                      spots: _createSpots('pending'),
                      isCurved: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange[400]!,
                          Colors.orange[600]!,
                        ],
                      ),
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 3,
                            color: Colors.orange[600]!,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => Colors.blueGrey.withValues(alpha: 0.8),
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final index = barSpot.x.toInt();
                          if (index >= 0 && index < _chartData.length) {
                            final monthName = _chartData[index]['monthName'] as String;
                            final lineIndex = barSpot.barIndex;
                            String lineLabel = '';
                            Color color = Colors.white;
                            
                            switch (lineIndex) {
                              case 0:
                                lineLabel = 'Total';
                                color = Colors.blue[600]!;
                                break;
                              case 1:
                                lineLabel = 'Approved';
                                color = Colors.green[600]!;
                                break;
                              case 2:
                                lineLabel = 'Pending';
                                color = Colors.orange[600]!;
                                break;
                            }
                            
                            return LineTooltipItem(
                              '$monthName\n$lineLabel: ${barSpot.y.toInt()}',
                              TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }
                          return null;
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Total', Colors.blue[600]!),
                const SizedBox(width: 20),
                _buildLegendItem('Approved', Colors.green[600]!),
                const SizedBox(width: 20),
                _buildLegendItem('Pending', Colors.orange[600]!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  List<FlSpot> _createSpots(String key) {
    return _chartData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final value = (data[key] as int?) ?? 0;
      return FlSpot(index.toDouble(), value.toDouble());
    }).toList();
  }

  int _getMaxY() {
    if (_chartData.isEmpty) return 10;
    
    int maxValue = 0;
    for (final data in _chartData) {
      final total = (data['total'] as int?) ?? 0;
      if (total > maxValue) maxValue = total;
    }
    
    // Add some padding to the max value
    return (maxValue * 1.2).ceil().clamp(5, double.infinity).toInt();
  }
}