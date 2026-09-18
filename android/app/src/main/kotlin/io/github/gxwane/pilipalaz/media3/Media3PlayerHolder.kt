package io.github.gxwane.pilipalaz.media3

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.VideoSize
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.MergingMediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import io.flutter.plugin.common.EventChannel

/**
 * 封装 AndroidX Media3 (ExoPlayer) 的核心调度、DASH 双流编排与 100ms 离散限频推流
 */
@OptIn(UnstableApi::class)
class Media3PlayerHolder(
    private val context: Context,
    private val onVideoSizeChangedListener: (width: Int, height: Int) -> Unit,
) : Player.Listener {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    val exoPlayer: ExoPlayer

    private var isDisposed = false

    private val positionRunnable = object : Runnable {
        override fun run() {
            if (!isDisposed && exoPlayer.isPlaying) {
                emitPlaybackUpdate()
                mainHandler.postDelayed(this, 100L)
            }
        }
    }

    init {
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                /* minBufferMs = */ 15_000,
                /* maxBufferMs = */ 25_000, // 审计规约：限制在 25s 以规避 4K 内存溢出 (OOM)
                /* bufferForPlaybackMs = */ 1_500,
                /* bufferForPlaybackAfterRebufferMs = */ 2_500
            )
            .setTargetBufferBytes(32 * 1024 * 1024)
            .setPrioritizeTimeOverSizeThresholds(false)
            .build()

        exoPlayer = ExoPlayer.Builder(context)
            .setLoadControl(loadControl)
            .build()

        // 审计规约：严禁由 Media3 抢占 AudioFocus，统一由 Dart 层的 AudioSessionHandler 调度
        val audioAttributes = AudioAttributes.Builder()
            .setContentType(C.AUDIO_CONTENT_TYPE_MOVIE)
            .setUsage(C.USAGE_MEDIA)
            .build()
        exoPlayer.setAudioAttributes(audioAttributes, /* handleAudioFocus = */ false)
        exoPlayer.addListener(this)
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        emitPlaybackUpdate()
    }

    fun open(
        videoUrl: String,
        audioUrl: String?,
        headers: Map<String, String>?,
        startPositionMs: Long?,
        autoPlay: Boolean,
    ) {
        if (isDisposed) return

        val dataSourceFactory = buildDataSourceFactory(context, headers)
        val videoSource = ProgressiveMediaSource.Factory(dataSourceFactory)
            .createMediaSource(MediaItem.fromUri(Uri.parse(videoUrl)))

        val finalMediaSource = if (audioUrl != null && audioUrl.isNotEmpty()) {
            val audioSource = ProgressiveMediaSource.Factory(dataSourceFactory)
                .createMediaSource(MediaItem.fromUri(Uri.parse(audioUrl)))
            // DASH 原生双流融合，adjustPeriodTimeOffsets 与 clipDurations 守卫时间戳微同步
            MergingMediaSource(
                /* adjustPeriodTimeOffsets = */ true,
                /* clipDurations = */ true,
                videoSource,
                audioSource
            )
        } else {
            videoSource
        }

        exoPlayer.setMediaSource(finalMediaSource)
        if (startPositionMs != null && startPositionMs > 0) {
            exoPlayer.seekTo(startPositionMs)
        }
        exoPlayer.prepare()
        exoPlayer.playWhenReady = autoPlay
    }

    fun play() {
        if (isDisposed) return
        exoPlayer.play()
    }

    fun pause() {
        if (isDisposed) return
        exoPlayer.pause()
    }

    fun stop() {
        if (isDisposed) return
        exoPlayer.stop()
        mainHandler.removeCallbacks(positionRunnable)
        emitPlaybackUpdate()
    }

    fun seekTo(positionMs: Long) {
        if (isDisposed) return
        exoPlayer.seekTo(positionMs)
        emitPlaybackUpdate()
    }

    fun setPlaybackSpeed(speed: Float) {
        if (isDisposed) return
        exoPlayer.setPlaybackSpeed(speed)
    }

    fun setVolume(volume: Float) {
        if (isDisposed) return
        exoPlayer.volume = volume
    }

    fun setLooping(isLooping: Boolean) {
        if (isDisposed) return
        exoPlayer.repeatMode = if (isLooping) Player.REPEAT_MODE_ONE else Player.REPEAT_MODE_OFF
    }

    private fun buildDataSourceFactory(
        context: Context,
        headers: Map<String, String>?,
    ): DataSource.Factory {
        val httpFactory = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(true)
            .setConnectTimeoutMs(15_000)
            .setReadTimeoutMs(15_000)

        if (headers != null) {
            httpFactory.setDefaultRequestProperties(headers)
        }

        return DefaultDataSource.Factory(context, httpFactory)
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        mainHandler.removeCallbacks(positionRunnable)
        if (isPlaying) {
            emitPlaybackUpdate()
            mainHandler.postDelayed(positionRunnable, 100L)
        } else {
            emitPlaybackUpdate()
        }
    }

    override fun onPlaybackStateChanged(playbackState: Int) {
        emitPlaybackUpdate()
        val stateString = when (playbackState) {
            Player.STATE_IDLE -> "idle"
            Player.STATE_BUFFERING -> "buffering"
            Player.STATE_READY -> if (exoPlayer.isPlaying) "playing" else "ready"
            Player.STATE_ENDED -> "completed"
            else -> "unknown"
        }
        eventSink?.success(
            mapOf(
                "event" to "stateChanged",
                "state" to stateString,
            )
        )
    }

    override fun onVideoSizeChanged(videoSize: VideoSize) {
        onVideoSizeChangedListener(videoSize.width, videoSize.height)
        eventSink?.success(
            mapOf(
                "event" to "videoSizeChanged",
                "width" to videoSize.width,
                "height" to videoSize.height,
            )
        )
    }

    override fun onPlayerError(error: PlaybackException) {
        val errorMessage = error.message ?: "PlaybackException"
        val errorCode = if (errorMessage.contains("403")) {
            "tokenExpiredOrForbidden"
        } else {
            "unknown"
        }
        eventSink?.success(
            mapOf(
                "event" to "error",
                "errorCode" to errorCode,
                "errorMessage" to errorMessage,
            )
        )
    }

    private fun emitPlaybackUpdate() {
        if (isDisposed) return
        eventSink?.success(
            mapOf(
                "event" to "playbackUpdate",
                "position" to exoPlayer.currentPosition,
                "buffered" to exoPlayer.bufferedPosition,
                "duration" to if (exoPlayer.duration == C.TIME_UNSET) 0L else exoPlayer.duration,
                "isPlaying" to exoPlayer.isPlaying,
            )
        )
    }

    fun release() {
        if (isDisposed) return
        isDisposed = true
        mainHandler.removeCallbacks(positionRunnable)
        exoPlayer.removeListener(this)
        exoPlayer.release()
        eventSink = null
    }
}
