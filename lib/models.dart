class AppDetails {
  final String packageName;
  final String appName;
  final int targetSdkVersion;
  final int minSdkVersion;
  final String installer;
  final bool isSideloaded;
  final List<String> grantedPermissions;
  final List<String> dangerousPermissions;
  final int foregroundTimeMs;

  AppDetails({
    required this.packageName,
    required this.appName,
    required this.targetSdkVersion,
    required this.minSdkVersion,
    required this.installer,
    required this.isSideloaded,
    required this.grantedPermissions,
    required this.dangerousPermissions,
    required this.foregroundTimeMs,
  });

  factory AppDetails.fromMap(Map<dynamic, dynamic> map) {
    return AppDetails(
      packageName: map['packageName'] as String? ?? '',
      appName: map['appName'] as String? ?? 'Unknown App',
      targetSdkVersion: map['targetSdkVersion'] as int? ?? 0,
      minSdkVersion: map['minSdkVersion'] as int? ?? 0,
      installer: map['installer'] as String? ?? 'Unknown',
      isSideloaded: map['isSideloaded'] as bool? ?? false,
      grantedPermissions: List<String>.from(map['grantedPermissions'] ?? []),
      dangerousPermissions: List<String>.from(map['dangerousPermissions'] ?? []),
      foregroundTimeMs: map['foregroundTimeMs'] as int? ?? 0,
    );
  }
}

class SystemSecurity {
  final bool developerOptionsEnabled;
  final bool adbEnabled;
  final bool isDeviceSecure;
  final bool isRooted;
  final int sdkInt;
  final String patchLevel;

  SystemSecurity({
    required this.developerOptionsEnabled,
    required this.adbEnabled,
    required this.isDeviceSecure,
    required this.isRooted,
    required this.sdkInt,
    required this.patchLevel,
  });

  factory SystemSecurity.fromMap(Map<dynamic, dynamic> map) {
    return SystemSecurity(
      developerOptionsEnabled: map['developerOptionsEnabled'] as bool? ?? false,
      adbEnabled: map['adbEnabled'] as bool? ?? false,
      isDeviceSecure: map['isDeviceSecure'] as bool? ?? false,
      isRooted: map['isRooted'] as bool? ?? false,
      sdkInt: map['sdkInt'] as int? ?? 0,
      patchLevel: map['patchLevel'] as String? ?? 'Unknown',
    );
  }
}

class NetworkSecurity {
  final bool isVpnActive;
  final bool isWifiConnected;
  final bool isCellularConnected;
  final bool isNetworkSecure;

  NetworkSecurity({
    required this.isVpnActive,
    required this.isWifiConnected,
    required this.isCellularConnected,
    required this.isNetworkSecure,
  });

  factory NetworkSecurity.fromMap(Map<dynamic, dynamic> map) {
    return NetworkSecurity(
      isVpnActive: map['isVpnActive'] as bool? ?? false,
      isWifiConnected: map['isWifiConnected'] as bool? ?? false,
      isCellularConnected: map['isCellularConnected'] as bool? ?? false,
      isNetworkSecure: map['isNetworkSecure'] as bool? ?? false,
    );
  }
}
