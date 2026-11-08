package io.github.juliusd.foxstreak

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Home-screen widget bridge (issue #115): the app pushes its state.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "io.github.juliusd.foxstreak/home_widget",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val args = call.arguments as? Map<*, *>
                    if (args == null) {
                        result.error("bad_args", "Expected a map", null)
                    } else {
                        try {
                            FoxStreakWidgetProvider.store(applicationContext, JSONObject(args).toString())
                            FoxStreakWidgetProvider.updateAll(applicationContext)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("widget_update_failed", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
