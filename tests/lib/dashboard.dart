import 'package:flutter/material.dart';
import 'package:tests/meter_data_service_complete.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  String? _errorMessage;
  
  // Monthly stats
  double _projectedMonthlyCost = 0.0;
  double _monthUsageSoFar = 0.0;
  int _daysElapsed = 0;
  int _totalDays = 30;
  double _avgDaily = 0.0;
  
  // Weekly comparison
  double _currentWeekUsage = 0.0;
  double _previousWeekUsage = 0.0;
  double _weeklyChange = 0.0;
  bool _isIncrease = false;
  
  // Weekly readings for graph
  List<DailyReading> _currentWeekReadings = [];
  List<DailyReading> _previousWeekReadings = [];

  // ML Predictions
  Map<String, dynamic>? _forecastData;
  Map<String, dynamic>? _patternsData;
  List<Map<String, dynamic>>? _anomalies;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get monthly stats
      final monthlyStats = await MeterDataService.getMonthlyStats();
      
      // Get ALL readings for weekly comparison
      final allReadings = await MeterDataService.getAllReadings();
      
      // Current week
      if (allReadings.length >= 7) {
        _currentWeekReadings = allReadings.sublist(allReadings.length - 7);
        final first = _currentWeekReadings.first.reading;
        final last = _currentWeekReadings.last.reading;
        _currentWeekUsage = (last - first).toDouble();
      }
      
      // Previous week
      if (allReadings.length >= 14) {
        _previousWeekReadings = allReadings.sublist(allReadings.length - 14, allReadings.length - 7);
        final first = _previousWeekReadings.first.reading;
        final last = _previousWeekReadings.last.reading;
        _previousWeekUsage = (last - first).toDouble();
      }
      
      _weeklyChange = _previousWeekUsage > 0 
          ? ((_currentWeekUsage - _previousWeekUsage) / _previousWeekUsage) * 100 
          : 0;
      _isIncrease = _currentWeekUsage > _previousWeekUsage;

      // NEW: Load ML predictions
      _forecastData = await MeterDataService.get7DayForecast();
      _patternsData = await MeterDataService.getUsagePatterns();
      _anomalies = await MeterDataService.detectAnomalies();
      
      setState(() {
        _projectedMonthlyCost = monthlyStats['projectedCost'];
        _monthUsageSoFar = monthlyStats['usage'];
        _daysElapsed = monthlyStats['daysElapsed'];
        _totalDays = monthlyStats['totalDays'];
        _avgDaily = monthlyStats['avgDaily'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F7),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(_errorMessage!, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              MeterDataService.clearCache();
              _loadData();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: () async {
        MeterDataService.clearCache();
        await _loadData();
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: const Color(0xFF1565C0),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Dashboard'),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)]),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  MeterDataService.clearCache();
                  _loadData();
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
  children: [
    // Monthly Bill Card (existing)
    _buildMonthlyBillCard(),
    const SizedBox(height: 20),
    
    // Weekly Comparison Card (existing)
    _buildWeeklyComparisonCard(),
    const SizedBox(height: 20),

    // Weekly Graph (existing) - MOVED UP
    _buildWeeklyGraphCard(),
    const SizedBox(height: 20),

    // NEW: ML FORECAST CARD - MOVED DOWN
    if (_forecastData != null) _buildMLForecastCard(),
    const SizedBox(height: 20),

    // NEW: SMART INSIGHTS CARD - MOVED DOWN
    if (_patternsData != null) _buildSmartInsightsCard(),
    const SizedBox(height: 20),

    // Monthly Progress (existing)
    _buildMonthlyProgressCard(),
    const SizedBox(height: 20),

    // Quick Actions (existing)
    _buildQuickActionsCard(),
  ],
),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBillCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF1976D2)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estimated Monthly Bill', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('₹', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              Text(_projectedMonthlyCost.toStringAsFixed(0), 
                style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Based on $_daysElapsed days of usage', style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildWeeklyComparisonCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isIncrease ? [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)] : [const Color(0xFF4CAF50), const Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: (_isIncrease ? Colors.orange : Colors.green).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Weekly Comparison', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Icon(_isIncrease ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 28),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_weeklyChange.abs().toStringAsFixed(1)}%', 
                style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_isIncrease ? 'increase' : 'decrease', style: const TextStyle(color: Colors.white70, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('vs previous week', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

Widget _buildMLForecastCard() {
  final predictions = _forecastData!['predictions'] as List<double>;
  final totalPredicted = _forecastData!['totalPredicted'] as double;
  final estimatedCost = _forecastData!['estimatedCost'] as double;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.insights, color: const Color(0xFF2196F3), size: 24),
            const SizedBox(width: 12),
            const Text('7-Day Forecast', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
          ],
        ),
        const SizedBox(height: 16),
        
        Container(
  height: 200,
  padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12)
          ),
          child: _buildPredictionGraph(predictions),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Expected Usage', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('${totalPredicted.toStringAsFixed(1)} kWh', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                ],
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey[300],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Estimated Cost', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('₹${estimatedCost.toStringAsFixed(0)}', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


Widget _buildSmartInsightsCard() {
  final weekdayAvg = _patternsData!['weekdayAvg'] as double;
  final weekendAvg = _patternsData!['weekendAvg'] as double;
  final percentDiff = _patternsData!['percentDifference'] as double;
  final peakDay = _patternsData!['peakDay'] as String;
  final hasPattern = percentDiff.abs() > 10;
  final weekendHigher = percentDiff > 0;

  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.analytics_outlined, color: const Color(0xFF2196F3), size: 24),
            const SizedBox(width: 12),
            const Text('Usage Insights', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
          ],
        ),
        const SizedBox(height: 16),
        
        // Pattern section
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(10)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Usage Pattern', 
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Weekdays', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text('${weekdayAvg.toStringAsFixed(1)} kWh', 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Weekends', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text('${weekendAvg.toStringAsFixed(1)} kWh', 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasPattern) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(weekendHigher ? Icons.arrow_upward : Icons.arrow_downward, 
                        color: weekendHigher ? Colors.orange[700] : Colors.green[700], size: 16),
                      const SizedBox(width: 6),
                      Text(
                        weekendHigher 
                          ? 'Weekend usage ${percentDiff.toStringAsFixed(0)}% higher'
                          : 'Weekday usage ${percentDiff.abs().toStringAsFixed(0)}% higher',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, 
                          color: weekendHigher ? Colors.orange[800] : Colors.green[800]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Peak day
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10)
          ),
          child: Row(
            children: [
              Icon(Icons.star_border, color: const Color(0xFF2196F3), size: 20),
              const SizedBox(width: 8),
              Text('Peak Day: ', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              Text(peakDay, 
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2196F3))),
            ],
          ),
        ),
        
        // Anomalies (if any)
        if (_anomalies != null && _anomalies!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.orange[700], size: 18),
                    const SizedBox(width: 8),
                    Text('Unusual Activity', 
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange[800])),
                  ],
                ),
                const SizedBox(height: 6),
                ..._anomalies!.take(2).map((a) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${a['date']}: ${(a['usage'] as double).toStringAsFixed(1)} kWh (${(a['deviation'] as double).toStringAsFixed(0)}% ${a['type']})',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                )),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}


Widget _buildPredictionGraph(List<double> predictions) {
  if (predictions.isEmpty) return const Center(child: Text('No data', style: TextStyle(color: Colors.grey)));
  
  final maxVal = predictions.reduce((a, b) => a > b ? a : b);
  final minVal = predictions.reduce((a, b) => a < b ? a : b);
  final range = maxVal - minVal;
  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  return Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: List.generate(predictions.length, (i) {
      final val = predictions[i];
      
      double height;
      if (range > 0 && range < 2.0) {

        height = 70 + ((val - minVal) / range * 40);
      } else if (range >= 2.0) {

        height = 50 + ((val - minVal) / range * 80);
      } else {

        height = 90.0;
      }
      
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(val.toStringAsFixed(1), 
                style: const TextStyle(fontSize: 9, color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [const Color(0xFF2196F3), const Color(0xFF64B5F6)],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
              const SizedBox(height: 3),
              Text(i < days.length ? days[i] : '', 
                style: TextStyle(fontSize: 9, color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }),
  );
}

  Widget _buildWeeklyGraphCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Usage Comparison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
          const SizedBox(height: 8),
          Text('Current vs Previous Week', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 20),
          _buildWeeklyComparisonGraph(),
        ],
      ),
    );
  }

  Widget _buildMonthlyProgressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Day $_daysElapsed of $_totalDays', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              Text('${((_daysElapsed / _totalDays) * 100).toStringAsFixed(0)}%', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2196F3))),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _daysElapsed / _totalDays,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
          const SizedBox(height: 16),
          _buildActionButton('View Detailed Usage', Icons.flash_on, () => Navigator.pushNamed(context, '/track')),
          const SizedBox(height: 12),
          _buildActionButton('Usage Archive', Icons.archive, () => Navigator.pushNamed(context, '/archive')),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2196F3)),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyComparisonGraph() {
    List<double> currentWeekDaily = [];
    List<double> previousWeekDaily = [];
    
    if (_currentWeekReadings.length >= 2) {
      for (int i = 1; i < _currentWeekReadings.length; i++) {
        currentWeekDaily.add((_currentWeekReadings[i].reading - _currentWeekReadings[i - 1].reading).abs());
      }
    }
    
    if (_previousWeekReadings.length >= 2) {
      for (int i = 1; i < _previousWeekReadings.length; i++) {
        previousWeekDaily.add((_previousWeekReadings[i].reading - _previousWeekReadings[i - 1].reading).abs());
      }
    }
    
    if (currentWeekDaily.isEmpty) currentWeekDaily = [10.0, 11.5, 9.8, 12.3, 11.0, 10.5];
    if (previousWeekDaily.isEmpty) previousWeekDaily = [9.5, 10.0, 11.2, 10.5, 9.8, 11.0];
    
    final minLength = currentWeekDaily.length < previousWeekDaily.length ? currentWeekDaily.length : previousWeekDaily.length;
    currentWeekDaily = currentWeekDaily.sublist(0, minLength);
    previousWeekDaily = previousWeekDaily.sublist(0, minLength);
    
    final maxValue = [...currentWeekDaily, ...previousWeekDaily].reduce((a, b) => a > b ? a : b);
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(currentWeekDaily.length, (i) {
          final currentValue = currentWeekDaily[i];
          final previousValue = i < previousWeekDaily.length ? previousWeekDaily[i] : 0.0;
          final currentHeight = (maxValue > 0 ? (currentValue / maxValue) * 130 : 0.0).clamp(0.0, 130.0);
          final previousHeight = (maxValue > 0 ? (previousValue / maxValue) * 130 : 0.0).clamp(0.0, 130.0);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(currentValue.toStringAsFixed(1), 
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, 
                      color: _isIncrease ? const Color(0xFFFF6B6B) : const Color(0xFF4CAF50))),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 130,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        if (previousHeight > 0)
                          Positioned(
                            bottom: 0,
                            child: Container(
                              width: 28, height: previousHeight,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            ),
                        if (currentHeight > 0)
                          Positioned(
                            bottom: 0,
                            left: 6,
                            child: Container(
                              width: 28,
                              height: currentHeight,
                              decoration: BoxDecoration(
                                color: _isIncrease 
                                    ? const Color(0xFFFF6B6B).withOpacity(0.9)
                                    : const Color(0xFF4CAF50).withOpacity(0.9),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 2,
                                    offset: const Offset(1, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i < dayNames.length ? dayNames[i] : '',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}