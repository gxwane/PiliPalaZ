package io.github.gxwane.pilipalaz.media3

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.view.PixelCopy
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Android 原生 Media3 Flutter 平台通道插件
 */
class Media3PlayerPlugin(
    private val context: Context,
    private val flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private var playerHolder: Media3PlayerHolder? = null
    private var surfaceManager: Media3SurfaceManager? = null
    private var screenshotThread: HandlerThread? = null
    private var screenshotHandler: Handler? = null

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

    @Synchronized
    private fun getScreenshotHandler(): Handler {
        if (screenshotThread == null) {
            screenshotThread = HandlerThread("media3-screenshot").apply { start() }
            screenshotHandler = Handler(screenshotThread!!.looper)
        }
        return screenshotHandler!!
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "create" -> {
                    disposePlayer()
                    val holder = Media3PlayerHolder(context)
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
                "screenshot" -> {
                    handleScreenshot(call, result)
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

    private fun handleScreenshot(call: MethodCall, result: MethodChannel.Result) {
        val holder = playerHolder
        val surface = surfaceManager?.surface
        if (holder == null || surface == null || !surface.isValid) {
            result.error("NOT_READY", "Player or Surface is not ready", null)
            return
        }

        val videoSize = holder.exoPlayer.videoSize
        if (videoSize.width <= 0 || videoSize.height <= 0) {
            result.error(
                "NO_FRAME",
                "Video dimensions invalid (${videoSize.width}x${videoSize.height})",
                null,
            )
            return
        }

        val width = videoSize.width
        val height = videoSize.height
        val rotation = videoSize.unappliedRotationDegrees
        val format = call.argument<String>("format") ?: "image/png"

        val bitmap = try {
            Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        } catch (oom: OutOfMemoryError) {
            result.error("OOM", "Out of memory allocating screenshot bitmap", null)
            return
        } catch (t: Throwable) {
            result.error("ALLOC_FAILED", t.message, null)
            return
        }

        val replied = AtomicBoolean(false)
        val mainHandler = Handler(Looper.getMainLooper())
        val bgHandler = getScreenshotHandler()

        fun replySuccess(data: Any?) {
            if (replied.compareAndSet(false, true)) {
                mainHandler.post { result.success(data) }
            }
        }

        fun replyError(code: String, msg: String?) {
            if (replied.compareAndSet(false, true)) {
                mainHandler.post { result.error(code, msg, null) }
            }
        }

        try {
            PixelCopy.request(surface, bitmap, { copyResult ->
                var finalBitmap = bitmap
                try {
                    if (copyResult == PixelCopy.SUCCESS) {
                        if (rotation != 0) {
                            val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
                            finalBitmap = Bitmap.createBitmap(
                                bitmap,
                                0,
                                0,
                                width,
                                height,
                                matrix,
                                true,
                            )
                            if (finalBitmap != bitmap) {
                                bitmap.recycle()
                            }
                        }
                        val compressFormat = if (format.contains("jpeg") || format.contains("jpg")) {
                            Bitmap.CompressFormat.JPEG
                        } else {
                            Bitmap.CompressFormat.PNG
                        }
                        val quality = if (compressFormat == Bitmap.CompressFormat.JPEG) 90 else 100
                        val stream = ByteArrayOutputStream()
                        stream.use {
                            finalBitmap.compress(compressFormat, quality, it)
                            replySuccess(it.toByteArray())
                        }
                    } else {
                        replyError("PIXELCOPY_FAILED", "PixelCopy failed with code: $copyResult")
                    }
                } catch (t: Throwable) {
                    replyError("COMPRESS_FAILED", t.message)
                } finally {
                    finalBitmap.recycle()
                }
            }, bgHandler)
        } catch (e: Throwable) {
            bitmap.recycle()
            replyError("REQUEST_FAILED", e.message)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        playerHolder?.setEventSink(events)
    }

    override fun onCancel(arguments: Any?) {
        playerHolder?.setEventSink(null)
    }

    private fun disposePlayer() {
        playerHolder?.release()
        playerHolder = null
        surfaceManager?.release()
        surfaceManager = null
        screenshotThread?.quitSafely()
        screenshotThread = null
        screenshotHandler = null
    }

    companion object {
        private const val METHOD_CHANNEL_NAME = "io.github.gxwane.pilipalaz/media3"
        private const val EVENT_CHANNEL_NAME = "io.github.gxwane.pilipalaz/media3_events"

        fun registerWith(flutterEngine: FlutterEngine, context: Context): Media3PlayerPlugin {
            return Media3PlayerPlugin(context, flutterEngine)
        }
    }
}
