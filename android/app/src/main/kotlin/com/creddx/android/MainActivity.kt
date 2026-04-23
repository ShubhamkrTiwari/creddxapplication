package com.creddx.android

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_icon_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "changeAppIcon" -> {
                    val iconName = call.argument<String>("iconName") ?: "classic"
                    changeAppIcon(iconName)
                    result.success(true)
                }
                "getCurrentIcon" -> {
                    result.success(getCurrentIcon())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun changeAppIcon(iconName: String) {
        val pkgName = this.packageName
        val pm = this.packageManager

        val aliases = mapOf(
            "classic" to "$pkgName.ClassicAlias",
            "neon" to "$pkgName.NeonAlias",
            "gradient" to "$pkgName.GradientAlias",
            "glass" to "$pkgName.GlassAlias"
        )

        val targetAlias = aliases[iconName] ?: aliases["classic"] ?: return

        // Disable all aliases first
        aliases.forEach { (_, alias) ->
            pm.setComponentEnabledSetting(
                ComponentName(pkgName, alias),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        // Enable the target alias
        pm.setComponentEnabledSetting(
            ComponentName(pkgName, targetAlias),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    private fun getCurrentIcon(): String {
        val pkgName = this.packageName
        val pm = this.packageManager

        val aliases = mapOf(
            "classic" to "$pkgName.ClassicAlias",
            "neon" to "$pkgName.NeonAlias",
            "gradient" to "$pkgName.GradientAlias",
            "glass" to "$pkgName.GlassAlias"
        )

        aliases.forEach { (name, alias) ->
            val state = pm.getComponentEnabledSetting(ComponentName(pkgName, alias))
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) {
                return name
            }
        }

        return "classic"
    }
}
