package io.github.gxwane.pilipalaz

import android.content.Context
import android.os.Build
import android.os.StatFs
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class DiskSpaceChannel(
    private val context: Context,
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
            "getFreeDiskSpace" -> getFreeDiskSpace(call, result)
            else -> result.notImplemented()
        }
    }

    private fun getFreeDiskSpace(call: MethodCall, result: MethodChannel.Result) {
        try {
            val requestedPath = call.argument<String>("path")
            val targetDir = if (!requestedPath.isNullOrBlank()) {
                val dir = File(requestedPath)
                if (dir.exists()) dir else context.filesDir
            } else {
                context.filesDir
            }
            val stat = StatFs(targetDir.absolutePath)
            val availableBytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                stat.availableBytes
            } else {
                @Suppress("DEPRECATION")
                stat.availableBlocks.toLong() * stat.blockSize.toLong()
            }
            result.success(availableBytes)
        } catch (e: Exception) {
            result.success(-1L)
        }
    }

    companion object {
        const val CHANNEL_NAME = "io.github.gxwane.pilipalaz/disk_space"
    }
}
