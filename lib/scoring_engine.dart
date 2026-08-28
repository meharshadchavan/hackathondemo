import 'models.dart';

class VulnerabilityIssue {
  final String title;
  final String description;
  final String remediation;
  final String severity; // 'CRITICAL', 'WARNING', 'INFO'

  VulnerabilityIssue({
    required this.title,
    required this.description,
    required this.remediation,
    required this.severity,
  });
}

class ScoreResult {
  final int score;
  final List<VulnerabilityIssue> issues;

  ScoreResult({
    required this.score,
    required this.issues,
  });
}

class ScoringEngine {
  static ScoreResult calculateScore({
    required SystemSecurity system,
    required NetworkSecurity network,
    required List<AppDetails> apps,
  }) {
    int score = 100;
    List<VulnerabilityIssue> issues = [];

    // 1. Root Check (OWASP Platform Integrity)
    if (system.isRooted) {
      score -= 50;
      issues.add(VulnerabilityIssue(
        title: "Device is Rooted",
        description: "Rooting neutralizes Android's application sandbox, allowing malicious code to bypass permissions completely.",
        remediation: "Flash original stock firmware to restore standard operating system security.",
        severity: "CRITICAL",
      ));
    }

    // 2. Lock screen status
    if (!system.isDeviceSecure) {
      score -= 25;
      issues.add(VulnerabilityIssue(
        title: "No Screen Lock Configured",
        description: "Your device is missing a biometric or PIN verification structure, leaving it fully accessible to physical tampering.",
        remediation: "Go to Settings > Security and set up fingerprint, face verification, or a secure PIN.",
        severity: "CRITICAL",
      ));
    }

    // 3. USB Debugging and Developer options
    if (system.adbEnabled) {
      score -= 15;
      issues.add(VulnerabilityIssue(
        title: "USB Debugging Enabled",
        description: "Allows automated commands to execute over USB, creating juice-jacking and data exfiltration pathways.",
        remediation: "Disable Developer Options or turn off USB Debugging inside Settings.",
        severity: "WARNING",
      ));
    } else if (system.developerOptionsEnabled) {
      score -= 5;
      issues.add(VulnerabilityIssue(
        title: "Developer Options Active",
        description: "Leaves custom debugging interfaces and configurations accessible on the device.",
        remediation: "Go to Settings > System > Developer Options and turn the switch off.",
        severity: "INFO",
      ));
    }

    // 4. Outdated OS / patch level
    if (system.sdkInt < 29) {
      score -= 20;
      issues.add(VulnerabilityIssue(
        title: "Outdated Android Version",
        description: "This device is running an outdated operating system lacking modern security sandboxing features.",
        remediation: "Perform a system check to install the latest software updates available.",
        severity: "CRITICAL",
      ));
    }

    // 5. Network Auditing
    if (network.isWifiConnected && !network.isVpnActive && !network.isNetworkSecure) {
      score -= 15;
      issues.add(VulnerabilityIssue(
        title: "Unencrypted Wi-Fi Active",
        description: "Connected to a local Wi-Fi connection without VPN encapsulation, exposing data to packet sniffing.",
        remediation: "Activate a VPN connection immediately or switch to mobile cellular data.",
        severity: "WARNING",
      ));
    }

    // 6. App vulnerability checks & compounding risk multiplier
    int outdatedAppsCount = 0;
    int sideloadedAppsCount = 0;
    int zombieAppsCount = 0;

    for (var app in apps) {
      double compoundingWeight = 1.0;
      List<String> appThreats = [];

      // Sideloaded detection
      if (app.isSideloaded) {
        sideloadedAppsCount++;
        compoundingWeight += 0.5;
        appThreats.add("Sideloaded from unknown origin");
      }

      // Outdated SDK targeting
      if (app.targetSdkVersion < 30) {
        outdatedAppsCount++;
        compoundingWeight += 0.3;
        appThreats.add("Targets obsolete API permissions");
      }

      // Zombie apps: Dangerous permissions but zero foreground time (inactive usage)
      if (app.dangerousPermissions.isNotEmpty && app.foregroundTimeMs == 0) {
        zombieAppsCount++;
        compoundingWeight += 0.4;
        appThreats.add("Possesses dangerous permissions but is completely unused");
      }

      if (appThreats.isNotEmpty) {
        int penalty = (5 * compoundingWeight).round();
        score -= penalty;

        issues.add(VulnerabilityIssue(
          title: "Vulnerability in ${app.appName}",
          description: "${app.appName} (${app.packageName}) shows: ${appThreats.join(', ')}.",
          remediation: "Evaluate if you still need this application. Revoke unused permissions, or uninstall the app if unused.",
          severity: app.isSideloaded ? "WARNING" : "INFO",
        ));
      }
    }

    // Final clamps
    if (score < 0) score = 0;

    return ScoreResult(score: score, issues: issues);
  }
}
