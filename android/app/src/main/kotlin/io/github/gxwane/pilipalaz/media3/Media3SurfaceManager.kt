package io.github.gxwane.pilipalaz.media3

import android.view.Surface
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.view.TextureRegistry

/**
 * 负责 Flutter TextureRegistry 与 ExoPlayer 的渲染表面生命周期绑定
 * 严格遵循 Google 官方 video_player_android (TextureVideoPlayer) 规范与 Flutter 3.38+ SurfaceProducer 规约
 * 禁绝外部调用 producer.setSize() 以避免 ImageReader 动态重建引发 CCodec queueBuffer failed: -32 管道破裂
 */
@OptIn(UnstableApi::class)
class Media3SurfaceManager(
    flutterEngine: FlutterEngine,
    private val player: ExoPlayer,
) : TextureRegistry.SurfaceProducer.Callback {

    private val producer: TextureRegistry.SurfaceProducer =
        flutterEngine.renderer.createSurfaceProducer()

    private var needsSurface = true

    val textureId: Long
        get() = producer.id()

    init {
        producer.setCallback(this)
        val initialSurface: Surface? = producer.surface
        if (initialSurface != null && initialSurface.isValid) {
            player.setVideoSurface(initialSurface)
            needsSurface = false
        }
    }

    override fun onSurfaceAvailable() {
        // 当应用从后台返回、旋转或从 PiP 恢复时，Flutter 提供新 Surface
        if (needsSurface) {
            val surface: Surface? = producer.surface
            if (surface != null && surface.isValid) {
                player.setVideoSurface(surface)
                needsSurface = false
            }
        }
    }

    override fun onSurfaceCleanup() {
        // 在 Flutter 释放底层图形缓冲前立即解绑，防止 MediaCodec 写入脏缓冲崩溃
        player.setVideoSurface(null)
        needsSurface = true
    }

    fun release() {
        // 遵循规约：先清空回调并解绑 Player 表面，再释放底层 producer
        producer.setCallback(null)
        player.setVideoSurface(null)
        producer.release()
    }
}
