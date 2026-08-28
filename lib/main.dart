import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'scoring_engine.dart';

void main() {
  runApp(const MobileHygieneGuardianApp());
}

class MobileHygieneGuardianApp extends StatelessWidget {
  const MobileHygieneGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile Hygiene Guardian',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6200EE),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFBB86FC),
          secondary: Color(0xFF03DAC6),
          background: Color(0xFF121212),
          surface: Color(0xFF1E1E1E),
          error: Color(0xFFCF6679),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontFamily: 'Inter'),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const platform = MethodChannel('com.example.hygiene/scan');

  bool _isLoading = false;
  bool _hasUsageStats = false;
  String _scanStatusText = "Device Not Scanned";
  
  SystemSecurity? _systemSecurity;
  NetworkSecurity? _networkSecurity;
  List<AppDetails> _apps = [];
  ScoreResult? _scoreResult;

  @override
  void initState() {
    super.initState();
    _checkPermissionState();
  }

  Future<void> _checkPermissionState() async {
    try {
      final bool hasPerm = await platform.invokeMethod('checkUsageStatsPermission');
      setState(() {
        _hasUsageStats = hasPerm;
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to check permission: ${e.message}");
    }
  }

  Future<void> _requestPermission() async {
    try {
      await platform.invokeMethod('requestUsageStatsPermission');
      // Wait briefly for settings view switch lifecycle to resume
      Future.delayed(const Duration(seconds: 2), () {
        _checkPermissionState();
      });
    } on PlatformException catch (e) {
      debugPrint("Failed to request permission: ${e.message}");
    }
  }

  Future<void> _runHygieneAssessment() async {
    setState(() {
      _isLoading = true;
      _scanStatusText = "Scanning environment integrity...";
    });

    try {
      // 1. Audit System Security Settings
      final Map<dynamic, dynamic> sysMap = await platform.invokeMethod('checkSystemSecurity');
      final system = SystemSecurity.fromMap(sysMap);

      setState(() {
        _scanStatusText = "Auditing network configs...";
      });

      // 2. Audit Network configurations
      final Map<dynamic, dynamic> netMap = await platform.invokeMethod('scanNetwork');
      final network = NetworkSecurity.fromMap(netMap);

      setState(() {
        _scanStatusText = "Evaluating application permissions...";
      });

      // 3. Audit Applications
      final List<dynamic> appsList = await platform.invokeMethod('scanApps');
      final apps = appsList.map((e) => AppDetails.fromMap(e as Map<dynamic, dynamic>)).toList();

      // 4. Calculate Risk Scoring Model
      final scoreResult = ScoringEngine.calculateScore(
        system: system,
        network: network,
        apps: apps,
      );

      setState(() {
        _systemSecurity = system;
        _networkSecurity = network;
        _apps = apps;
        _scoreResult = scoreResult;
        _isLoading = false;
        _scanStatusText = "Scan Complete";
      });
    } on PlatformException catch (e) {
      setState(() {
        _isLoading = false;
        _scanStatusText = "Scan Failed: ${e.message}";
      });
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 75) return const Color(0xFF4CAF50); // Green
    if (score >= 45) return const Color(0xFFFF9800); // Orange
    return const Color(0xFFF44336); // Red
  }

  String _getScoreRating(int score) {
    if (score >= 75) return "Secure Posture";
    if (score >= 45) return "Moderate Risk";
    return "Critical Risk";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mobile Hygiene Guardian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Mobile Hygiene Framework"),
                  content: const Text(
                    "This application assesses mobile security posture locally by scanning device settings, root paths, network configurations, and permissions usage, conforming to OWASP MASVS principles.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Dismiss"),
                    )
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Permission check card
              if (!_hasUsageStats)
                Card(
                  color: Colors.amber.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.amber, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Usage Stats Access Needed",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "To track which apps request permissions but are rarely used, this app requires usage data authorization.",
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _requestPermission,
                          icon: const Icon(Icons.settings),
                          label: const Text("Grant Usage Permission"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Score overview
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      if (_isLoading) ...[
                        const SizedBox(
                          height: 100,
                          width: 100,
                          child: CircularProgressIndicator(strokeWidth: 8),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _scanStatusText,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ] else if (_scoreResult != null) ...[
                        Text(
                          "${_scoreResult!.score}",
                          style: TextStyle(
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                            color: _getScoreColor(_scoreResult!.score),
                          ),
                        ),
                        Text(
                          _getScoreRating(_scoreResult!.score),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Calculated based on compounding vulnerability models.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        const Icon(Icons.shield_outlined, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _scanStatusText,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _runHygieneAssessment,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: Text(_scoreResult == null ? "Start Diagnostics" : "Scan Again"),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Recommendations and findings section
              if (_scoreResult != null) ...[
                Row(
                  children: [
                    const Icon(Icons.list_alt_rounded, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      "Security Findings (${_scoreResult!.issues.length})",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_scoreResult!.issues.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "No issues found! Your device maintains a secure, clean hygiene posture.",
                        style: TextStyle(color: Colors.green),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _scoreResult!.issues.length,
                    itemBuilder: (context, index) {
                      final issue = _scoreResult!.issues[index];
                      Color badgeColor = Colors.green;
                      if (issue.severity == "CRITICAL") badgeColor = Colors.red;
                      if (issue.severity == "WARNING") badgeColor = Colors.orange;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ExpansionTile(
                          leading: Icon(
                            Icons.error_outline,
                            color: badgeColor,
                          ),
                          title: Text(
                            issue.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            issue.severity,
                            style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    issue.description,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "RECOMMENDED ACTION:",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.blueAccent,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(issue.remediation),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
