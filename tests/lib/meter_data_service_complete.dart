// ============================================================================
// Shared service for all pages - consistent data and calculations
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// ============================================================================
// API CONFIGURATION
// ============================================================================
class ApiConfig {
  static const String baseUrl = 'https://indisputable-star-blowiest.ngrok-free.dev';
  static const String meterId = '1';
  static const double ratePerUnit = 6.5;
  
  static String getReadingsUrl({int count = 30}) {
    return '$baseUrl/userApp?id=$meterId&count=$count';
  }
  
  static String getArchiveUrl() {
    return '$baseUrl/archive?id=$meterId';
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================
class DailyReading {
  final double reading;
  final String date;
  
  DailyReading({required this.reading, required this.date});
  
  factory DailyReading.fromIndex(double reading, int daysAgo) {
    final date = DateTime.now().subtract(Duration(days: daysAgo));
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return DailyReading(reading: reading, date: dateStr);
  }
  
  String getDayName() {
    final date = DateTime.parse(this.date);
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return dayNames[date.weekday - 1];
  }
}

class MonthlyArchive {
  final String month;
  final double startReading;
  final double endReading;
  final double totalUsage;
  final double totalCost;
  final int daysInMonth;
  final double avgDaily;
  
  MonthlyArchive({
    required this.month,
    required this.startReading,
    required this.endReading,
    required this.totalUsage,
    required this.totalCost,
    required this.daysInMonth,
    required this.avgDaily,
  });
  
  // Factory constructor to parse from JSON
  factory MonthlyArchive.fromJson(Map<String, dynamic> json) {
    return MonthlyArchive(
      month: json['month'] ?? '',
      startReading: (json['startReading'] ?? 0).toDouble(),
      endReading: (json['endReading'] ?? 0).toDouble(),
      totalUsage: (json['totalUsage'] ?? 0).toDouble(),
      totalCost: (json['totalCost'] ?? 0).toDouble(),
      daysInMonth: json['daysInMonth'] ?? 30,
      avgDaily: (json['avgDaily'] ?? 0).toDouble(),
    );
  }
}

// ============================================================================
// METER DATA SERVICE - Used by all pages
// ============================================================================
class MeterDataService {
  // Cache
  static List<DailyReading>? _cachedReadings;
  static DateTime? _lastFetch;
  static const _cacheTimeout = Duration(minutes: 5);
  
  // ============================================================================
  // FETCH ALL READINGS (30 days for calculations)
  // ============================================================================
  static Future<List<DailyReading>> getAllReadings({bool forceRefresh = false}) async {
    if (!forceRefresh && 
        _cachedReadings != null && 
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheTimeout) {
      debugPrint('📦 Returning cached readings (${_cachedReadings!.length} readings)');
      return _cachedReadings!;
    }
    
    try {
      debugPrint('🔄 Fetching all readings from API...');
      
      final url = ApiConfig.getReadingsUrl(count: 30);
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 15));
      
      debugPrint('📥 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final readingsRaw = data['readings'] as List;
        
        if (readingsRaw.isEmpty) {
          throw Exception('No readings available');
        }
        
        _cachedReadings = readingsRaw.asMap().entries.map((entry) {
          final daysAgo = readingsRaw.length - 1 - entry.key;
          return DailyReading.fromIndex(
            double.parse(entry.value.toString()),
            daysAgo,
          );
        }).toList();
        
        _lastFetch = DateTime.now();
        
        debugPrint('✅ Loaded ${_cachedReadings!.length} readings');
        debugPrint('📊 First: ${_cachedReadings!.first.reading} | Last: ${_cachedReadings!.last.reading}');
        
        return _cachedReadings!;
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      
      if (_cachedReadings != null) {
        debugPrint('⚠️ Returning stale cache due to error');
        return _cachedReadings!;
      }
      
      rethrow;
    }
  }
  
  // ============================================================================
  // GET LAST 7 READINGS (for Track Usage page)
  // ============================================================================
  static Future<List<DailyReading>> getLast7Readings({bool forceRefresh = false}) async {
    final allReadings = await getAllReadings(forceRefresh: forceRefresh);
    
    if (allReadings.length < 7) {
      return allReadings;
    }
    
    return allReadings.sublist(allReadings.length - 7);
  }
  
  // ============================================================================
  // CALCULATE TODAY'S USAGE
  // ============================================================================
  static Future<Map<String, double>> getTodayStats({bool forceRefresh = false}) async {
    final readings = await getAllReadings(forceRefresh: forceRefresh);
    
    if (readings.length < 2) {
      return {'usage': 0.0, 'cost': 0.0};
    }
    
    final todayUsage = (readings.last.reading - readings[readings.length - 2].reading).toDouble();
    final todayCost = todayUsage * ApiConfig.ratePerUnit;
    
    return {
      'usage': todayUsage,
      'cost': todayCost,
    };
  }
  
  // ============================================================================
  // CALCULATE WEEKLY STATS (last 7 readings)
  // ============================================================================
  static Future<Map<String, double>> getWeeklyStats({bool forceRefresh = false}) async {
    final readings = await getLast7Readings(forceRefresh: forceRefresh);
    
    if (readings.length < 2) {
      return {'usage': 0.0, 'cost': 0.0, 'avgDaily': 0.0};
    }
    
    final weeklyUsage = (readings.last.reading - readings.first.reading).toDouble();
    final weeklyCost = weeklyUsage * ApiConfig.ratePerUnit;
    final avgDaily = weeklyUsage / (readings.length - 1);
    
    return {
      'usage': weeklyUsage,
      'cost': weeklyCost,
      'avgDaily': avgDaily,
    };
  }
  
  // ============================================================================
  // CALCULATE MONTHLY STATS (from all readings)
  // ============================================================================
  static Future<Map<String, dynamic>> getMonthlyStats({bool forceRefresh = false}) async {
    final readings = await getAllReadings(forceRefresh: forceRefresh);
    
    if (readings.length < 2) {
      return {
        'usage': 0.0,
        'cost': 0.0,
        'daysElapsed': 0,
        'totalDays': 30,
        'avgDaily': 0.0,
        'projectedUsage': 0.0,
        'projectedCost': 0.0,
      };
    }
    
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day;
    
    final monthStartIndex = readings.length > daysElapsed 
        ? readings.length - daysElapsed 
        : 0;
    
    final monthStartReading = readings[monthStartIndex].reading;
    final currentReading = readings.last.reading;
    
    final monthUsageSoFar = (currentReading - monthStartReading).toDouble();
    final avgDaily = monthUsageSoFar / daysElapsed;
    final projectedMonthlyUsage = avgDaily * daysInMonth;
    final projectedMonthlyCost = projectedMonthlyUsage * ApiConfig.ratePerUnit;
    
    debugPrint('📊 MONTHLY CALCULATION:');
    debugPrint('   Days elapsed: $daysElapsed of $daysInMonth');
    debugPrint('   Month start reading: $monthStartReading');
    debugPrint('   Current reading: $currentReading');
    debugPrint('   Usage so far: ${monthUsageSoFar.toStringAsFixed(1)} kWh');
    debugPrint('   Projected monthly: ${projectedMonthlyUsage.toStringAsFixed(1)} kWh');
    debugPrint('   Projected cost: ₹${projectedMonthlyCost.toStringAsFixed(0)}');
    
    return {
      'usage': monthUsageSoFar,
      'cost': monthUsageSoFar * ApiConfig.ratePerUnit,
      'daysElapsed': daysElapsed,
      'totalDays': daysInMonth,
      'avgDaily': avgDaily,
      'projectedUsage': projectedMonthlyUsage,
      'projectedCost': projectedMonthlyCost,
    };
  }
  
  // ============================================================================
  // GET ARCHIVE DATA (for Archive page) 
  // ============================================================================
  static Future<Map<String, dynamic>> getArchiveData() async {
    try {
      debugPrint('🔄 Fetching archive data...');
      
      // Get current month stats from readings
      final monthlyStats = await getMonthlyStats();
      
      // Get past months from archive endpoint
      final url = '${ApiConfig.baseUrl}/archive?id=${ApiConfig.meterId}';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('📥 Archive response: ${response.statusCode}');
      debugPrint('📥 Archive body: ${response.body}');
      
      List<MonthlyArchive> pastMonths = [];
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        debugPrint('📦 Archive data keys: ${data.keys}');
        debugPrint('📦 Total months: ${data['totalMonths']}');
        
        if (data['archive'] != null && data['archive'] is List) {
          final archiveList = data['archive'] as List;
          
          debugPrint('📦 Archive list length: ${archiveList.length}');
          
          for (var i = 0; i < archiveList.length; i++) {
            try {
              final item = archiveList[i];
              debugPrint('📦 Processing archive item $i: $item');
              
              final archive = MonthlyArchive.fromJson(item);
              pastMonths.add(archive);
              
              debugPrint('✅ Added: ${archive.month} - ${archive.totalUsage} kWh');
            } catch (e) {
              debugPrint('❌ Error parsing archive item $i: $e');
            }
          }
          
          debugPrint('✅ Loaded ${pastMonths.length} archived months');
        } else {
          debugPrint('⚠️ No archive array found or not a list');
        }
      } else {
        debugPrint('⚠️ Archive endpoint returned ${response.statusCode}');
      }
      
      return {
        'currentMonth': monthlyStats,
        'pastMonths': pastMonths,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading archive: $e');
      debugPrint('Stack trace: $stackTrace');
      
      final monthlyStats = await getMonthlyStats();
      return {
        'currentMonth': monthlyStats,
        'pastMonths': <MonthlyArchive>[],
      };
    }
  }
  
  // ============================================================================
  // CLEAR CACHE
  // ============================================================================
  static void clearCache() {
    _cachedReadings = null;
    _lastFetch = null;
    debugPrint('🗑️ Cache cleared');
  }
  // ============================================================================
// PREDICTIVE ANALYSIS METHODS
// ============================================================================

// ============================================================================
// LINEAR REGRESSION - Predicts future values based on trend
// ============================================================================
static List<double> _linearRegression(List<double> values, int futureDays) {
  if (values.length < 3) return List.filled(futureDays, values.last);
  
  final n = values.length;
  double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
  
  for (int i = 0; i < n; i++) {
    sumX += i;
    sumY += values[i];
    sumXY += i * values[i];
    sumX2 += i * i;
  }
  
  final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
  final intercept = (sumY - slope * sumX) / n;
  
  return List.generate(futureDays, (i) {
    final prediction = slope * (n + i) + intercept;
    return prediction > 0 ? prediction : values.last;
  });
}

// ============================================================================
// MOVING AVERAGE 
// ============================================================================
static List<double> _movingAverage(List<double> values, int futureDays, int window) {
  if (values.length < window) return List.filled(futureDays, values.last);
  
  final recentValues = values.sublist(values.length - window);
  final avg = recentValues.reduce((a, b) => a + b) / window;
  
  return List.filled(futureDays, avg);
}

// ============================================================================
// EXPONENTIAL SMOOTHING 
// ============================================================================
static List<double> _exponentialSmoothing(List<double> values, int futureDays, double alpha) {
  if (values.isEmpty) return List.filled(futureDays, 0);
  
  double smoothed = values.first;
  for (var value in values) {
    smoothed = alpha * value + (1 - alpha) * smoothed;
  }
  
  return List.filled(futureDays, smoothed);
}

// ============================================================================
// CALCULATE R² SCORE (Model accuracy metric)
// ============================================================================
static double _calculateRSquared(List<double> actual, List<double> predicted) {
  if (actual.length != predicted.length || actual.isEmpty) return 0;
  
  final mean = actual.reduce((a, b) => a + b) / actual.length;
  
  double ssTotal = 0, ssResidual = 0;
  for (int i = 0; i < actual.length; i++) {
    ssTotal += (actual[i] - mean) * (actual[i] - mean);
    ssResidual += (actual[i] - predicted[i]) * (actual[i] - predicted[i]);
  }
  
  return ssTotal > 0 ? (1 - ssResidual / ssTotal).clamp(0, 1) : 0;
}

// ============================================================================
// GET 7-DAY FORECAST WITH MULTIPLE MODELS
// ============================================================================

static Future<Map<String, dynamic>> get7DayForecast({bool forceRefresh = false}) async {
  final readings = await getAllReadings(forceRefresh: forceRefresh);
  
  if (readings.length < 7) {
    return {
      'predictions': <double>[],
      'models': {},
      'bestModel': 'insufficient_data',
      'confidence': 0.0,
      'totalPredicted': 0.0,
      'estimatedCost': 0.0,
    };
  }
  
  // Calculate daily usage from readings
  List<double> dailyUsage = [];
  for (int i = 1; i < readings.length; i++) {
    final usage = (readings[i].reading - readings[i - 1].reading).abs();
    dailyUsage.add(usage);
  }
  
  // Use last 21 days for training (more data = better patterns)
  final trainingData = dailyUsage.length > 21 
      ? dailyUsage.sublist(dailyUsage.length - 21) 
      : dailyUsage;
  
  // Get weekday/weekend patterns for smarter predictions
  final patterns = await getUsagePatterns(forceRefresh: false);
  final weekdayAvg = patterns['weekdayAvg'] as double;
  final weekendAvg = patterns['weekendAvg'] as double;
  
  // Generate day-aware predictions (next 7 days)
  List<double> patternBasedPred = [];
  final today = DateTime.now();
  for (int i = 1; i <= 7; i++) {
    final futureDate = today.add(Duration(days: i));
    final isWeekend = futureDate.weekday == 6 || futureDate.weekday == 7;
    // Use actual patterns instead of pure math models
    patternBasedPred.add(isWeekend ? weekendAvg : weekdayAvg);
  }
  
  // Generate predictions with 3 models
  final linearPred = _linearRegression(trainingData, 7);
  final movingAvgPred = _movingAverage(trainingData, 7, 7);
  final expSmoothPred = _exponentialSmoothing(trainingData, 7, 0.3);
  
  // Calculate accuracy on last 5 days
  final testSize = trainingData.length >= 5 ? 5 : 3;
  final linearFit = _linearRegression(
    trainingData.sublist(0, trainingData.length - testSize), 
    testSize
  );
  final movingFit = _movingAverage(
    trainingData.sublist(0, trainingData.length - testSize), 
    testSize, 
    7
  );
  final expFit = _exponentialSmoothing(
    trainingData.sublist(0, trainingData.length - testSize), 
    testSize, 
    0.3
  );
  
  final actualLastN = trainingData.sublist(trainingData.length - testSize);
  final linearR2 = _calculateRSquared(actualLastN, linearFit);
  final movingR2 = _calculateRSquared(actualLastN, movingFit);
  final expR2 = _calculateRSquared(actualLastN, expFit);
  
  // Pattern-based model accuracy (compare against recent data)
  final patternR2 = _calculateRSquared(actualLastN, patternBasedPred.take(testSize).toList());
  
  // Find best model
  final models = {
    'linear': {'r2': linearR2, 'predictions': linearPred},
    'moving': {'r2': movingR2, 'predictions': movingAvgPred},
    'exponential': {'r2': expR2, 'predictions': expSmoothPred},
    'pattern': {'r2': patternR2, 'predictions': patternBasedPred},
  };
  
  String bestModel = 'pattern'; // Default to pattern-based
  double bestR2 = patternR2;
  
  models.forEach((key, value) {
    final r2 = value['r2'] as double;
    if (r2 > bestR2) {
      bestModel = key;
      bestR2 = r2;
    }
  });
  
  // Use best model's predictions, but cap extreme values
  final rawPredictions = models[bestModel]!['predictions'] as List<double>;
  
  // Cap predictions to reasonable range (prevent crazy spikes)
  final recentAvg = trainingData.length >= 7
      ? trainingData.sublist(trainingData.length - 7).reduce((a, b) => a + b) / 7
      : trainingData.reduce((a, b) => a + b) / trainingData.length;
  
  final bestPredictions = rawPredictions.map((p) {
    // Don't allow predictions to exceed 150% of recent average
    final maxAllowed = recentAvg * 1.5;
    final minAllowed = recentAvg * 0.5;
    return p.clamp(minAllowed, maxAllowed);
  }).toList();
  
  final totalPredicted = bestPredictions.reduce((a, b) => a + b);
  
  debugPrint('🤖 ML FORECAST (IMPROVED):');
  debugPrint('   Recent 7-day avg: ${recentAvg.toStringAsFixed(1)} kWh/day');
  debugPrint('   Linear R²: ${(linearR2 * 100).toStringAsFixed(1)}%');
  debugPrint('   Moving Avg R²: ${(movingR2 * 100).toStringAsFixed(1)}%');
  debugPrint('   Exp Smooth R²: ${(expR2 * 100).toStringAsFixed(1)}%');
  debugPrint('   Pattern-Based R²: ${(patternR2 * 100).toStringAsFixed(1)}%');
  debugPrint('   Best Model: $bestModel (${(bestR2 * 100).toStringAsFixed(1)}%)');
  debugPrint('   7-day prediction: ${totalPredicted.toStringAsFixed(1)} kWh');
  debugPrint('   Predictions: ${bestPredictions.map((p) => p.toStringAsFixed(1)).join(", ")}');
  
  return {
    'predictions': bestPredictions,
    'models': {
      'linear': {'accuracy': linearR2, 'name': 'Linear Regression'},
      'moving': {'accuracy': movingR2, 'name': 'Moving Average'},
      'exponential': {'accuracy': expR2, 'name': 'Exp. Smoothing'},
    },
    'bestModel': bestModel,
    'confidence': bestR2,
    'totalPredicted': totalPredicted,
    'estimatedCost': totalPredicted * ApiConfig.ratePerUnit,
    'dailyUsageHistory': dailyUsage,
  };
}

// ============================================================================
// DETECT USAGE PATTERNS (Weekday vs Weekend)
// ============================================================================
static Future<Map<String, dynamic>> getUsagePatterns({bool forceRefresh = false}) async {
  final readings = await getAllReadings(forceRefresh: forceRefresh);
  
  if (readings.length < 7) {
    return {
      'weekdayAvg': 0.0,
      'weekendAvg': 0.0,
      'percentDifference': 0.0,
      'peakDay': 'Unknown',
    };
  }
  
  // Calculate daily usage with day of week
  List<double> weekdayUsage = [];
  List<double> weekendUsage = [];
  Map<String, List<double>> dayUsage = {
    'Monday': [], 'Tuesday': [], 'Wednesday': [], 'Thursday': [],
    'Friday': [], 'Saturday': [], 'Sunday': [],
  };
  
  for (int i = 1; i < readings.length; i++) {
    final usage = (readings[i].reading - readings[i - 1].reading).abs();
    final date = DateTime.parse(readings[i].date);
    final dayName = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][date.weekday - 1];
    
    dayUsage[dayName]!.add(usage);
    
    if (date.weekday <= 5) {
      weekdayUsage.add(usage);
    } else {
      weekendUsage.add(usage);
    }
  }
  
  final weekdayAvg = weekdayUsage.isNotEmpty 
      ? weekdayUsage.reduce((a, b) => a + b) / weekdayUsage.length 
      : 0.0;
  final weekendAvg = weekendUsage.isNotEmpty 
      ? weekendUsage.reduce((a, b) => a + b) / weekendUsage.length 
      : 0.0;
  
  final percentDiff = weekdayAvg > 0 
      ? ((weekendAvg - weekdayAvg) / weekdayAvg) * 100 
      : 0.0;
  
  // Find peak day
  String peakDay = 'Saturday';
  double maxAvg = 0;
  dayUsage.forEach((day, usages) {
    if (usages.isNotEmpty) {
      final avg = usages.reduce((a, b) => a + b) / usages.length;
      if (avg > maxAvg) {
        maxAvg = avg;
        peakDay = day;
      }
    }
  });
  
  debugPrint('📊 PATTERN ANALYSIS:');
  debugPrint('   Weekday avg: ${weekdayAvg.toStringAsFixed(1)} kWh');
  debugPrint('   Weekend avg: ${weekendAvg.toStringAsFixed(1)} kWh');
  debugPrint('   Difference: ${percentDiff.toStringAsFixed(1)}%');
  debugPrint('   Peak day: $peakDay');
  
  return {
    'weekdayAvg': weekdayAvg,
    'weekendAvg': weekendAvg,
    'percentDifference': percentDiff,
    'peakDay': peakDay,
    'dayBreakdown': dayUsage,
  };
}

// ============================================================================
// DETECT ANOMALIES (Unusual spikes or drops)
// ============================================================================
static Future<List<Map<String, dynamic>>> detectAnomalies({bool forceRefresh = false}) async {
  final readings = await getAllReadings(forceRefresh: forceRefresh);
  
  if (readings.length < 7) return [];
  
  // Calculate daily usage
  List<Map<String, dynamic>> dailyData = [];
  for (int i = 1; i < readings.length; i++) {
    final usage = (readings[i].reading - readings[i - 1].reading).abs();
    dailyData.add({
      'date': readings[i].date,
      'usage': usage,
    });
  }
  
  // Calculate mean and standard deviation
  final usages = dailyData.map((d) => d['usage'] as double).toList();
  final mean = usages.reduce((a, b) => a + b) / usages.length;
  final variance = usages.map((u) => (u - mean) * (u - mean)).reduce((a, b) => a + b) / usages.length;
  final stdDev = variance > 0 ? variance : 0.1; // Avoid division by zero
  
  // Find anomalies (Z-score > 1.5)
  List<Map<String, dynamic>> anomalies = [];
  for (var data in dailyData) {
    final usage = data['usage'] as double;
    final zScore = (usage - mean) / stdDev;
    
    if (zScore.abs() > 1.5) {
      anomalies.add({
        'date': data['date'],
        'usage': usage,
        'deviation': ((usage - mean) / mean * 100).abs(),
        'type': zScore > 0 ? 'spike' : 'drop',
      });
    }
  }
  
  debugPrint('⚠️ ANOMALY DETECTION:');
  debugPrint('   Mean usage: ${mean.toStringAsFixed(1)} kWh');
  debugPrint('   Found ${anomalies.length} anomalies');
  
  return anomalies.take(5).toList(); // Return max 5 most recent
}
}