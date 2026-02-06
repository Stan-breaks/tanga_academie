import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tanga_acadamie/data_fetcher.dart';
import 'package:tanga_acadamie/screens/shared/custom_appbar.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  Map<String, dynamic>? _chartData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchChartData();
  }

  Future<void> _fetchChartData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await getAdminChartData();
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
    return Scaffold(
      appBar: const CustomAppbar(isLoggedIn: true),
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        color: Colors.blueGrey,
        onRefresh: _fetchChartData,
        child: _isLoading
            ? _buildLoadingState()
            : _error != null
                ? _buildErrorState()
                : _buildAnalytics(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.blueGrey,
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Loading analytics...',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading analytics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchChartData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalytics() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Section
        _buildHeader(),
        const SizedBox(height: 24),

        // Enrollment Trends Chart
        _buildChartCard(
          title: 'Monthly Enrollment Trends',
          icon: Icons.trending_up,
          color: Colors.blueGrey,
          child: _buildEnrollmentChart(),
        ),
        const SizedBox(height: 20),

        // Course Distribution Chart
        _buildChartCard(
          title: 'Course Category Distribution',
          icon: Icons.pie_chart,
          color: Colors.purple,
          child: _buildDistributionChart(),
        ),
        const SizedBox(height: 20),

        // Revenue Chart
        _buildChartCard(
          title: 'Monthly Platform Revenue',
          icon: Icons.bar_chart,
          color: Colors.green,
          child: _buildRevenueChart(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueGrey.shade600, Colors.blueGrey.shade800],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withAlpha(60),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Platform Analytics',
                      style: TextStyle(
                        color: Colors.white.withAlpha(200),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Performance & Trends',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your platform growth and user engagement',
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.insights, color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chart
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentChart() {
    // Get enrollment data from API response
    // API returns: { labels: [...], datasets: [{ label, data, ... }] }
    final enrollmentData = _chartData?['enrollment'] as Map<String, dynamic>?;

    if (enrollmentData == null) {
      return _buildNoDataState('No enrollment data available');
    }

    final labels = (enrollmentData['labels'] as List<dynamic>?)?.cast<String>() ?? [];
    final datasets = enrollmentData['datasets'] as List<dynamic>?;
    final dataPoints = (datasets?.isNotEmpty == true) 
        ? (datasets![0]['data'] as List<dynamic>?)?.cast<num>() ?? []
        : <num>[];

    if (dataPoints.isEmpty) {
      return _buildNoDataState('No enrollment data available');
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i].toDouble()));
    }

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < labels.length) {
                    return Text(
                      labels[index].substring(0, labels[index].length > 3 ? 3 : labels[index].length),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blueGrey,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blueGrey.withAlpha(30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionChart() {
    // Get distribution data from API response
    // API returns: { labels: [...], datasets: [{ data, backgroundColor, ... }] }
    final distributionData = _chartData?['distribution'] as Map<String, dynamic>?;

    if (distributionData == null) {
      return _buildNoDataState('No distribution data available');
    }

    final labels = (distributionData['labels'] as List<dynamic>?)?.cast<String>() ?? [];
    final datasets = distributionData['datasets'] as List<dynamic>?;
    final dataPoints = (datasets?.isNotEmpty == true) 
        ? (datasets![0]['data'] as List<dynamic>?)?.cast<num>() ?? []
        : <num>[];

    if (dataPoints.isEmpty || labels.isEmpty) {
      return _buildNoDataState('No distribution data available');
    }

    final colors = [
      Colors.blueGrey,
      Colors.purple,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.pink,
    ];

    final sections = <PieChartSectionData>[];
    final legendItems = <Widget>[];

    for (int i = 0; i < dataPoints.length; i++) {
      final value = dataPoints[i].toDouble();
      final label = i < labels.length ? labels[i] : 'Category ${i + 1}';
      final color = colors[i % colors.length];

      sections.add(
        PieChartSectionData(
          value: value,
          color: color,
          title: '${value.toInt()}',
          radius: 70,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );

      legendItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        SizedBox(
          height: 180,
          width: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 35,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            children: legendItems,
          ),
        ),
      ],
    );
  }

  Widget _buildRevenueChart() {
    // Get revenue data from API response
    // API returns: { labels: [...], datasets: [{ label, data, ... }] }
    final revenueData = _chartData?['revenue'] as Map<String, dynamic>?;

    if (revenueData == null) {
      return _buildNoDataState('No revenue data available');
    }

    final labels = (revenueData['labels'] as List<dynamic>?)?.cast<String>() ?? [];
    final datasets = revenueData['datasets'] as List<dynamic>?;
    final dataPoints = (datasets?.isNotEmpty == true) 
        ? (datasets![0]['data'] as List<dynamic>?)?.cast<num>() ?? []
        : <num>[];

    if (dataPoints.isEmpty) {
      return _buildNoDataState('No revenue data available');
    }

    final groups = <BarChartGroupData>[];
    double maxValue = 0;

    for (int i = 0; i < dataPoints.length; i++) {
      final value = dataPoints[i].toDouble();
      if (value > maxValue) maxValue = value;
      
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: value,
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.green.shade400, Colors.green.shade600],
              ),
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue > 0 ? maxValue * 1.2 : 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxValue > 0 ? maxValue / 5 : 20,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) => Text(
                  '\$${value.toInt()}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < labels.length) {
                    return Text(
                      labels[index].substring(0, labels[index].length > 3 ? 3 : labels[index].length),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: groups,
        ),
      ),
    );
  }

  Widget _buildNoDataState(String message) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.show_chart, size: 40, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
