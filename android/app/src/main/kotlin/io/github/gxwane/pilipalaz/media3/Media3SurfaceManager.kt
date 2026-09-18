package io.github.gxwane.pilipalaz.media3

import android.view.Surface
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.view.TextureRegistry

/**
 * 负责 Flutter TextureRegistry 与 ExoPlayer 的渲染表面生命周期绑定
 * 优先采用 Flutter 3.38+ 原生推荐的 SurfaceProducer 接口
 */
@OptIn(UnstableApi::class)
class Media3SurfaceManager(
    flutterEngine: FlutterEngine,
    private val player: ExoPlayer,
) : TextureRegistry.SurfaceProducer.Callback {

    private val producer: TextureRegistry.SurfaceProducer =
        flutterEngine.renderer.createSurfaceProducer()

    val textureId: Long
        get() = producer.id()

    init {
        producer.setCallback(this)
        val initialSurface: Surface? = producer.surface
        if (initialSurface != null) {
            player.setVideoSurface(initialSurface)
        }
    }

    override fun onSurfaceAvailable() {
        // 当应用返回前台、旋转或从 PiP 恢复时，Flutter 提供新 Surface
        val surface: Surface? = producer.surface
        if (surface != null) {
            player.setVideoSurface(surface)
        }
    }

    override fun onSurfaceCleanup() {
        // 在 Flutter 释放底层图形缓冲前立即解绑，防止 MediaCodec 写入脏缓冲崩溃
        player.clearVideoSurface()
    }

    fun onVideoSizeChanged(width: Int, height: Int) {
        if (width > 0 && height > 0) {
            producer.setSize(width, height)
        }
    }

    fun release() {
        producer.setCallback(null)
        player.clearVideoSurface()
        producer.release()
    }
}
