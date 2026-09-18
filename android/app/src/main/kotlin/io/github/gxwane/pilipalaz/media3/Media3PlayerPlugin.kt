package io.github.gxwane.pilipalaz.media3

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Android 原生 Media3 Flutter 平台通道插件
 */
class Media3PlayerPlugin(
    private val context: Context,
    private val flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var playerHolder: Media3PlayerHolder? = null
    private var surfaceManager: Media3SurfaceManager? = null

    private val methodChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        METHOD_CHANNEL_NAME,
    )
    private val eventChannel = EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        EVENT_CHANNEL_NAME,
    )

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "create" -> {
                    disposePlayer()
                    val holder = Media3PlayerHolder(context) { width, height ->
                        surfaceManager?.onVideoSizeChanged(width, height)
                    }
                    val surface = Media3SurfaceManager(flutterEngine, holder.exoPlayer)
                    playerHolder = holder
                    surfaceManager = surface
                    result.success(surface.textureId)
                }
                "open" -> {
                    val holder = playerHolder
                    if (holder == null) {
                        result.error("NO_PLAYER", "Media3 player is not initialized", null)
                        return
                    }
                    val videoUrl = call.argument<String>("videoUrl") ?: ""
                    val audioUrl = call.argument<String>("audioUrl")
                    val headers = call.argument<Map<String, String>>("headers")
                    val startPositionMs = call.argument<Number>("startPositionMs")?.toLong()
                    val autoPlay = call.argument<Boolean>("autoPlay") ?: true

                    holder.open(videoUrl, audioUrl, headers, startPositionMs, autoPlay)
                    result.success(null)
                }
                "play" -> {
                    playerHolder?.play()
                    result.success(null)
                }
                "pause" -> {
                    playerHolder?.pause()
                    result.success(null)
                }
                "stop" -> {
                    playerHolder?.stop()
                    result.success(null)
                }
                "seekTo" -> {
                    val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                    playerHolder?.seekTo(positionMs)
                    result.success(null)
                }
                "setPlaybackSpeed" -> {
                    val speed = call.argument<Number>("speed")?.toFloat() ?: 1.0f
                    playerHolder?.setPlaybackSpeed(speed)
                    result.success(null)
                }
                "setVolume" -> {
                    val volume = call.argument<Number>("volume")?.toFloat() ?: 1.0f
                    playerHolder?.setVolume(volume)
                    result.success(null)
                }
                "setLooping" -> {
                    val looping = call.argument<Boolean>("looping") ?: false
                    playerHolder?.setLooping(looping)
                    result.success(null)
                }
                "dispose" -> {
                    disposePlayer()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("MEDIA3_ERROR", e.message, null)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        playerHolder?.setEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        playerHolder?.setEventSink(null)
    }

    private fun disposePlayer() {
        surfaceManager?.release()
        surfaceManager = null
        playerHolder?.release()
        playerHolder = null
    }

    companion object {
        private const val METHOD_CHANNEL_NAME = "io.github.gxwane.pilipalaz/media3"
        private const val EVENT_CHANNEL_NAME = "io.github.gxwane.pilipalaz/media3_events"

        fun registerWith(flutterEngine: FlutterEngine, context: Context): Media3PlayerPlugin {
            return Media3PlayerPlugin(context, flutterEngine)
        }
    }
}
