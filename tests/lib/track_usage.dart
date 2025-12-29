import 'package:flutter/material.dart';
import 'package:tests/meter_data_service_complete.dart';


class TrackUsagePage extends StatefulWidget {
  const TrackUsagePage({super.key});

  @override
  State<TrackUsagePage> createState() => _TrackUsagePageState();
}

class _TrackUsagePageState extends State<TrackUsagePage> {
  bool _isLoading = true;
  String? _errorMessage;
  
  // Stats
  double _todayUsage = 0.0;
  double _todayCost = 0.0;
  double _weeklyUsage = 0.0;
  double _weeklyCost = 0.0;
  double _avgDaily = 0.0;
  
  // Data for display
  List<Map<String, dynamic>> _weeklyData = [];

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
      // Get stats from service
      final todayStats = await MeterDataService.getTodayStats();
      final weeklyStats = await MeterDataService.getWeeklyStats();
      final last7 = await MeterDataService.getLast7Readings();
      
      // Calculate daily breakdown
      final weeklyData = <Map<String, dynamic>>[];
      for (int i = 1; i < last7.length; i++) {
        final usage = (last7[i].reading - last7[i-1].reading).toDouble();
        weeklyData.add({
          'day': last7[i].getDayName(),
          'usage': usage,
          'cost': usage * ApiConfig.ratePerUnit,
        });
      }
      
      setState(() {
        _todayUsage = todayStats['usage']!;
        _todayCost = todayStats['cost']!;
        _weeklyUsage = weeklyStats['usage']!;
        _weeklyCost = weeklyStats['cost']!;
        _avgDaily = weeklyStats['avgDaily']!;
        _weeklyData = weeklyData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data';
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
          Text(_errorMessage!),
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
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: const Color(0xFF1565C0),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Usage Tracking'),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 50),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildQuickStat('Today', '${_todayUsage.toStringAsFixed(1)} kWh'),
                        _buildQuickStat('This Week', '${_weeklyUsage.toStringAsFixed(1)} kWh'),
                        _buildQuickStat('Avg Daily', '${_avgDaily.toStringAsFixed(1)} kWh'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Cost cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildCostCard(
                          'Today\'s Cost',
                          '₹${_todayCost.toStringAsFixed(0)}',
                          Icons.today,
                          const Color(0xFF2196F3),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCostCard(
                          'Weekly Cost',
                          '₹${_weeklyCost.toStringAsFixed(0)}',
                          Icons.calendar_view_week,
                          const Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Graph
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent Usage',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'This Week',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2196F3),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildGraph(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Recent readings
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent Readings',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                            Text(
                              '${_weeklyData.length} days',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._weeklyData.reversed.map((day) => _buildReadingItem(day)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCostCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildGraph() {
    if (_weeklyData.isEmpty) return const Text('No data');

    final maxUsage = _weeklyData.map((e) => e['usage'] as double).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 180,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weeklyData.map((day) {
                final usage = day['usage'] as double;
                final heightPercent = maxUsage > 0 ? usage / maxUsage : 0;
                
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          usage.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: (130.0 * heightPercent).clamp(8.0, 130.0),
                          decoration: const BoxDecoration(
                            color: Color(0xFF64B5F6),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _weeklyData.map((day) {
              return Expanded(
                child: Text(
                  day['day'],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingItem(Map<String, dynamic> day) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                day['day'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2196F3)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(day['usage'] as double).toStringAsFixed(1)} kWh',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${(day['cost'] as double).toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Icon(Icons.bolt, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }
}