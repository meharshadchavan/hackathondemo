package com.example.hygiene.mobile_hygiene_guardian

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.hygiene/scan"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkUsageStatsPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(true)
                }
                "checkSystemSecurity" -> {
                    result.success(getSystemSecurityDetails())
                }
                "scanApps" -> {
                    result.success(scanInstalledApps())
                }
                "scanNetwork" -> {
                    result.success(scanNetworkState())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getSystemSecurityDetails(): Map<String, Any> {
        val details = mutableMapOf<String, Any>()
        
        // Developer options
        val devSettings = Settings.Global.getInt(
            contentResolver,
            Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0
        )
        details["developerOptionsEnabled"] = devSettings != 0

        // USB Debugging/ADB status
        val adbEnabled = Settings.Global.getInt(
            contentResolver,
            Settings.Global.ADB_ENABLED, 0
        )
        details["adbEnabled"] = adbEnabled != 0

        // Biometric / Keyguard settings
        val km = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
        details["isDeviceSecure"] = km.isDeviceSecure

        // Root detection
        details["isRooted"] = checkRootPaths()

        // Host version info
        details["sdkInt"] = Build.VERSION.SDK_INT
        details["patchLevel"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Build.VERSION.SECURITY_PATCH
        } else {
            "Unknown"
        }
        
        return details
    }

    private fun checkRootPaths(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su"
        )
        for (path in paths) {
            if (File(path).exists()) return true
        }
        
        // Exec check fallback
        var process: java.lang.Process? = null
        return try {
            process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            val reader = java.io.BufferedReader(java.io.InputStreamReader(process.inputStream))
            reader.readLine() != null
        } catch (t: Throwable) {
            false
        } finally {
            process?.destroy()
        }
    }

    private fun scanInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val apps = pm.getInstalledPackages(PackageManager.GET_PERMISSIONS)
        val list = mutableListOf<Map<String, Any>>()

        // Retrieve usage statistics if permission is active
        val usageMap = mutableMapOf<String, Long>()
        if (hasUsageStatsPermission()) {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val calendar = Calendar.getInstance()
            calendar.add(Calendar.DAY_OF_YEAR, -30)
            val stats = usm.queryAndAggregateUsageStats(calendar.timeInMillis, System.currentTimeMillis())
            for ((pkg, stat) in stats) {
                usageMap[pkg] = stat.totalTimeInForeground
            }
        }

        for (pkg in apps) {
            val appInfo = pkg.applicationInfo ?: continue
            // Ignore system applications for app vulnerability details
            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            if (isSystemApp) continue

            val appDetails = mutableMapOf<String, Any>()
            
            appDetails["packageName"] = pkg.packageName
            appDetails["appName"] = pm.getApplicationLabel(appInfo).toString()
            appDetails["targetSdkVersion"] = appInfo.targetSdkVersion
            appDetails["minSdkVersion"] = appInfo.minSdkVersion

            // Sideload verification
            val installSource = getInstallerPackage(pkg.packageName)
            appDetails["installer"] = installSource ?: "Unknown"
            appDetails["isSideloaded"] = installSource == null || 
                installSource == "com.android.packageinstaller" || 
                installSource == "com.google.android.packageinstaller" ||
                installSource == "Unknown"

            // Permissions
            val requestedPermissions = pkg.requestedPermissions
            val flags = pkg.requestedPermissionsFlags
            val grantedPermissions = mutableListOf<String>()
            val dangerousPermissions = mutableListOf<String>()

            val riskyPermissionsList = setOf(
                "android.permission.CAMERA",
                "android.permission.RECORD_AUDIO",
                "android.permission.ACCESS_FINE_LOCATION",
                "android.permission.ACCESS_COARSE_LOCATION",
                "android.permission.READ_CONTACTS",
                "android.permission.READ_SMS",
                "android.permission.RECEIVE_SMS",
                "android.permission.READ_EXTERNAL_STORAGE",
                "android.permission.WRITE_EXTERNAL_STORAGE"
            )

            if (requestedPermissions != null && flags != null) {
                for (i in requestedPermissions.indices) {
                    if (i < flags.size) {
                        val perm = requestedPermissions[i]
                        val isGranted = (flags[i] and android.content.pm.PackageInfo.REQUESTED_PERMISSION_GRANTED) != 0
                        if (isGranted) {
                            grantedPermissions.add(perm)
                            if (riskyPermissionsList.contains(perm)) {
                                dangerousPermissions.add(perm)
                            }
                        }
                    }
                }
            }

            appDetails["grantedPermissions"] = grantedPermissions
            appDetails["dangerousPermissions"] = dangerousPermissions
            appDetails["foregroundTimeMs"] = usageMap[pkg.packageName] ?: 0L

            list.add(appDetails)
        }
        return list
    }

    private fun getInstallerPackage(packageName: String): String? {
        return try {
            val pm = packageManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val info = pm.getInstallSourceInfo(packageName)
                info.installingPackageName
            } else {
                @Suppress("DEPRECATION")
                pm.getInstallerPackageName(packageName)
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun scanNetworkState(): Map<String, Any> {
        val details = mutableMapOf<String, Any>()
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = cm.activeNetwork
        val caps = cm.getNetworkCapabilities(activeNetwork)

        var isVpn = false
        var isWifi = false
        var isCellular = false

        if (caps != null) {
            isVpn = caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            isWifi = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
            isCellular = caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
        }

        details["isVpnActive"] = isVpn
        details["isWifiConnected"] = isWifi
        details["isCellularConnected"] = isCellular
        
        // Open Wi-Fi heuristics detection fallback
        details["isNetworkSecure"] = !isWifi || isVpn // Simulating secure connectivity if using VPN on Wi-Fi

        return details
    }
}
