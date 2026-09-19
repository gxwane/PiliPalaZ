package io.github.gxwane.pilipalaz.media3

import android.graphics.SurfaceTexture
import android.view.Surface
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.view.TextureRegistry

/**
 * 负责 Flutter TextureRegistry 与 ExoPlayer 的渲染表面生命周期绑定
 * 采用原生 SurfaceTextureEntry 与 BufferQueue 架构，提供高容量缓冲槽位（支持 64 缓冲槽），
 * 彻底消除 ImageReader 槽位受限（<=6）引发的海思/高通等芯片硬件解码器 ACodec -1010 启动失败与软解绿屏问题。
 */
@OptIn(UnstableApi::class)
class Media3SurfaceManager(
    flutterEngine: FlutterEngine,
    private val player: ExoPlayer,
) {
    private val textureEntry: TextureRegistry.SurfaceTextureEntry =
        flutterEngine.renderer.createSurfaceTexture()

    private val surfaceTexture: SurfaceTexture =
        textureEntry.surfaceTexture()

    private val surface: Surface =
        Surface(surfaceTexture)

    val textureId: Long
        get() = textureEntry.id()

    init {
        player.setVideoSurface(surface)
    }

    fun release() {
        player.setVideoSurface(null)
        surface.release()
        textureEntry.release()
    }
}

