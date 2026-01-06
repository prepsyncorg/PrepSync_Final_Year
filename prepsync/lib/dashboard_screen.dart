import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:prepsync/login_screen.dart';
import 'package:prepsync/api_config.dart';
import 'package:prepsync/chat_screen.dart';
import 'package:prepsync/resume_analyzer_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int userId;
  const DashboardScreen({required this.userId, super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = 'User';
  Map<String, double> _performanceData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/profile/${widget.userId}')),
        http.get(Uri.parse('$baseUrl/performance/${widget.userId}')),
      ]);

      if (!mounted) return;

      if (responses[0].statusCode == 200) {
        final profileData = json.decode(responses[0].body);
        setState(() => _userName = profileData['name']);
      }

      if (responses[1].statusCode == 200) {
        final perfData = json.decode(responses[1].body);
        setState(() {
          _performanceData = {
            // Using REAL stored data for Resume
            "Resume": (perfData['resume_score'] as num).toDouble(),
            // Mock data for other modules (until we build them)
            "Aptitude": (perfData['aptitude_avg'] as num).toDouble() / 10.0,
            "Interview": (perfData['interview_avg'] as num).toDouble(),
            "Communication": (perfData['communication_avg'] as num).toDouble() / 10.0,
          };
        });
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final bool? shouldLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout')),
        ],
      ),
    );

    if (shouldLogout == true) {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentDate = DateFormat('MMMM d, yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2540),
        foregroundColor: Colors.white,
        elevation: 3,
        title: Text('PrepSync', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0A2540)))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildWelcomeCard()),
                    SliverToBoxAdapter(child: _buildModuleList()),
                    SliverToBoxAdapter(child: _buildPerformanceSection()),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChatScreen()),
                    );
                  },
                  backgroundColor: const Color(0xFF4A90E2),
                  child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
                  heroTag: 'chatbot',
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: Text(currentDate, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF0A2540)),
            child: Text('Menu', style: GoogleFonts.poppins(color: Colors.white, fontSize: 24)),
          ),
          ListTile(leading: const Icon(Icons.person_outline), title: const Text('My Profile'), onTap: () {}),
          ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Settings'), onTap: () {}),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: _logout),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF50E3C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back,\n$_userName!',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('7/10 Assessments Completed',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          CircularPercentIndicator(
            radius: 45.0,
            lineWidth: 10.0,
            animation: true,
            percent: 0.75,
            center: const Text("75%",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0, color: Colors.white)),
            circularStrokeCap: CircularStrokeCap.round,
            progressColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleList() {
    // 1. DYNAMIC SCORE LOGIC
    int resumeScore = (_performanceData['Resume'] ?? 0).toInt();
    String scoreText = resumeScore > 0 ? 'Score: $resumeScore/100' : 'No Resume Uploaded';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 2. RESUME CARD (Uses dynamic score & refreshes on return)
          _buildModuleCard(
            'AI Resume Analyzer', 
            scoreText, 
            const Color(0xFF4A90E2), 
            Icons.description,
            onTap: () async {
              // Wait for user to return
              await Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => ResumeAnalyzerScreen(userId: widget.userId))
              );
              // Refresh dashboard when they come back
              _fetchDashboardData();
            }
          ),
          
          _buildModuleCard('Aptitude Test Generator', 'Next Test: Math & Logic', const Color(0xFF7B61FF), Icons.lightbulb_outline),
          _buildModuleCard('Mock Interview Simulator', 'Last Session: Technical Interview', const Color(0xFFF5A623), Icons.mic_none),
          _buildModuleCard('Workplace Communication', 'Master Tricky Scenarios', const Color(0xFF50E3C2), Icons.people_outline),
        ],
      ),
    );
  }

  Widget _buildModuleCard(String title, String subtitle, Color color, IconData icon, {VoidCallback? onTap}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap ?? () {}, 
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 8, offset: const Offset(2, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Performance Overview',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _performanceData.isEmpty
              ? const Center(child: Text('No performance data yet.'))
              : Column(
                  children: [
                    SizedBox(height: 150, child: _buildBarChart()),
                    const SizedBox(height: 25),
                    SizedBox(height: 150, child: _buildLineChart()),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100, 
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, getTitlesWidget: _bottomTitles, reservedSize: 30),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _performanceData.entries.map((entry) {
          int index = _performanceData.keys.toList().indexOf(entry.key);
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: entry.value,
                color: Colors.tealAccent.shade700,
                width: 22,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = _performanceData.entries
        .toList()
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            isCurved: true,
            color: const Color(0xFF4A90E2),
            barWidth: 3,
            isStrokeCapRound: true,
            belowBarData: BarAreaData(show: true, color: const Color(0xFF4A90E2).withOpacity(0.3)),
            spots: spots,
          ),
        ],
      ),
    );
  }

  Widget _bottomTitles(double value, TitleMeta meta) {
    final titles = _performanceData.keys.toList();
    final String shortTitle =
        titles.length > value.toInt() ? titles[value.toInt()].substring(0, 3) : '';
    final text = Text(shortTitle,
        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 14));
    return SideTitleWidget(axisSide: meta.axisSide, space: 16, child: text);
  }
}