package com.example.chronologe

import android.app.ActivityManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val backgroundHealthChannel = "chronologe/background_health"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            backgroundHealthChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(backgroundHealthStatus())
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun backgroundHealthStatus(): Map<String, Any> {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val bucket = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            standbyBucketName(usageStatsManager.appStandbyBucket)
        } else {
            "unavailable"
        }
        val restricted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            activityManager.isBackgroundRestricted
        } else {
            false
        }

        return mapOf(
            "ignoresBatteryOptimizations" to
                powerManager.isIgnoringBatteryOptimizations(packageName),
            "isBackgroundRestricted" to restricted,
            "standbyBucket" to bucket,
            "deviceLabel" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    private fun standbyBucketName(bucket: Int): String {
        return when (bucket) {
            UsageStatsManager.STANDBY_BUCKET_ACTIVE -> "active"
            UsageStatsManager.STANDBY_BUCKET_WORKING_SET -> "working_set"
            UsageStatsManager.STANDBY_BUCKET_FREQUENT -> "frequent"
            UsageStatsManager.STANDBY_BUCKET_RARE -> "rare"
            UsageStatsManager.STANDBY_BUCKET_RESTRICTED -> "restricted"
            else -> "unknown"
        }
    }

    private fun openAppSettings() {
        val intent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:$packageName"),
        )
        startActivity(intent)
    }
}
