import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:tests/meter_data_service_complete.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late DateTime currentDate;
  late Timer _timer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Quick stats
  double _todayUsage = 0.0;
  double _todayCost = 0.0;
  double _weeklyUsage = 0.0;
  double _monthlyEstimate = 0.0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    currentDate = DateTime.now();
    
    // Animation setup
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();

    // Load stats
    _loadQuickStats();

    // Update date daily
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final newDate = DateTime.now();
      if (newDate.day != currentDate.day) {
        setState(() => currentDate = newDate);
      }
    });
  }

  Future<void> _loadQuickStats() async {
    try {
      final todayStats = await MeterDataService.getTodayStats();
      final weeklyStats = await MeterDataService.getWeeklyStats();
      final monthlyStats = await MeterDataService.getMonthlyStats();
      
      if (mounted) {
        setState(() {
          _todayUsage = todayStats['usage']!;
          _todayCost = todayStats['cost']!;
          _weeklyUsage = weeklyStats['usage']!;
          _monthlyEstimate = monthlyStats['projectedCost'];
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<User?> _getCurrentUser() async {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (e) {
      debugPrint('Error fetching user: $e');
      return null;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = days[date.weekday - 1];
    return '$dayName, ${months[date.month - 1]} ${date.day}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F7),
      body: FutureBuilder<User?>(
        future: _getCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;
          final displayName = user?.displayName?.split(' ')[0] ?? "User";

          return FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  expandedHeight: 180,
                  floating: false,
                  pinned: true,
                  backgroundColor: const Color(0xFF1565C0),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _getGreeting(),
                                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        displayName,
                                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pushNamed(context, '/account'),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person_outline, color: Colors.white, size: 24),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatDate(currentDate),
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Today's Usage Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: _isLoadingStats
                              ? const Center(child: CircularProgressIndicator(color: Colors.white))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Today\'s Usage', style: TextStyle(color: Colors.white70, fontSize: 16)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Row(
                                            children: [
                                              Icon(Icons.bolt, color: Colors.white, size: 14),
                                              SizedBox(width: 4),
                                              Text('Live', style: TextStyle(color: Colors.white, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _todayUsage.toStringAsFixed(1),
                                          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        const Padding(
                                          padding: EdgeInsets.only(bottom: 10),
                                          child: Text('kWh', style: TextStyle(color: Colors.white70, fontSize: 20)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Cost: ₹${_todayCost.toStringAsFixed(0)}',
                                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                        ),

                        const SizedBox(height: 20),

                        // Quick Stats Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard('This Week', '${_weeklyUsage.toStringAsFixed(1)} kWh', Icons.calendar_today, const Color(0xFF4CAF50)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard('Monthly Bill', '₹${_monthlyEstimate.toStringAsFixed(0)}', Icons.account_balance_wallet, const Color(0xFFFF9800)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Section Header
                        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 16),

                        // Quick Action Cards
                        _buildActionCard(
                          context: context,
                          icon: Icons.flash_on,
                          title: 'Track Usage',
                          subtitle: 'View daily and weekly usage',
                          color: const Color(0xFF2196F3),
                          route: '/track',
                        ),
                        const SizedBox(height: 12),
                        _buildActionCard(
                          context: context,
                          icon: Icons.dashboard,
                          title: 'Dashboard',
                          subtitle: 'Analytics and insights',
                          color: const Color(0xFF1976D2),
                          route: '/dashboard',
                        ),
                        const SizedBox(height: 12),
                        _buildActionCard(
                          context: context,
                          icon: Icons.archive,
                          title: 'Archive',
                          subtitle: 'Historical data',
                          color: const Color(0xFF4CAF50),
                          route: '/archive',
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String route,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.pushNamed(context, route),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}