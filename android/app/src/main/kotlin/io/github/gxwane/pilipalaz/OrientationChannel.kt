package io.github.gxwane.pilipalaz

import android.app.Activity
import android.content.pm.ActivityInfo
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class OrientationChannel(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CHANNEL_NAME,
    )

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setLandscapeSensor" -> {
                activity.requestedOrientation =
                    ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                result.success(null)
            }
            "setFullSensor" -> {
                activity.requestedOrientation =
                    ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val CHANNEL_NAME =
            "io.github.gxwane.pilipalaz/orientation"
    }
}
