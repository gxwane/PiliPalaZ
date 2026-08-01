package io.github.gxwane.pilipalaz

import android.app.Activity
import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

class AppUpdateChannel(
    private val activity: Activity,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler {
    private val downloadManager =
        activity.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    private val digestExecutor = Executors.newSingleThreadExecutor()
    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CHANNEL_NAME,
    )

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "enqueue" -> enqueue(call, result)
                "query" -> query(call, result)
                "cancel" -> cancel(call, result)
                "sha256" -> sha256(call, result)
                "canInstallPackages" -> result.success(canInstallPackages())
                "openInstallSettings" -> openInstallSettings(result)
                "install" -> install(call, result)
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error(
                "APP_UPDATE_ERROR",
                error.message ?: "Android update operation failed",
                null,
            )
        }
    }

    private fun enqueue(call: MethodCall, result: MethodChannel.Result) {
        val url = requireNotNull(call.argument<String>("url")) {
            "Missing download URL"
        }
        val fileName = requireSafeFileName(call.argument("fileName"))
        val title = call.argument<String>("title") ?: "PiliPalaZ update"
        val uri = Uri.parse(url)
        require(uri.scheme == "https" && !uri.host.isNullOrBlank()) {
            "Only HTTPS update URLs are accepted"
        }

        val updateDirectory = updateDirectory()
        check(updateDirectory.exists() || updateDirectory.mkdirs()) {
            "Cannot create the update directory"
        }
        val destination = File(updateDirectory, fileName)
        if (destination.exists()) {
            check(destination.delete()) {
                "Cannot replace the previous update file"
            }
        }

        val request = DownloadManager.Request(uri)
            .setTitle(title)
            .setDescription(fileName)
            .setMimeType(APK_MIME_TYPE)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)
            .setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED,
            )
            .setDestinationInExternalFilesDir(
                activity,
                Environment.DIRECTORY_DOWNLOADS,
                "$UPDATE_DIRECTORY/$fileName",
            )
        result.success(downloadManager.enqueue(request))
    }

    private fun query(call: MethodCall, result: MethodChannel.Result) {
        val downloadId = requireDownloadId(call)
        val cursor = downloadManager.query(
            DownloadManager.Query().setFilterById(downloadId),
        )
        cursor.use {
            if (!it.moveToFirst()) {
                result.success(
                    mapOf(
                        "status" to "missing",
                        "downloadedBytes" to 0L,
                        "totalBytes" to 0L,
                    ),
                )
                return
            }
            val rawStatus = it.getInt(
                it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS),
            )
            val rawReason = it.getInt(
                it.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON),
            )
            result.success(
                mapOf(
                    "status" to statusName(rawStatus),
                    "downloadedBytes" to it.getLong(
                        it.getColumnIndexOrThrow(
                            DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR,
                        ),
                    ),
                    "totalBytes" to it.getLong(
                        it.getColumnIndexOrThrow(
                            DownloadManager.COLUMN_TOTAL_SIZE_BYTES,
                        ),
                    ),
                    "reason" to reasonText(rawStatus, rawReason),
                ),
            )
        }
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        downloadManager.remove(requireDownloadId(call))
        result.success(null)
    }

    private fun sha256(call: MethodCall, result: MethodChannel.Result) {
        val downloadId = requireDownloadId(call)
        digestExecutor.execute {
            try {
                val digest = MessageDigest.getInstance("SHA-256")
                val descriptor = downloadManager.openDownloadedFile(downloadId)
                ParcelFileDescriptor.AutoCloseInputStream(descriptor).use { input ->
                    val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) {
                            break
                        }
                        digest.update(buffer, 0, count)
                    }
                }
                val value = digest.digest().joinToString("") {
                    (it.toInt() and 0xff).toString(16).padStart(2, '0')
                }
                activity.runOnUiThread { result.success(value) }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    result.error(
                        "SHA256_FAILED",
                        error.message ?: "Cannot verify the downloaded APK",
                        null,
                    )
                }
            }
        }
    }

    private fun canInstallPackages(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            activity.packageManager.canRequestPackageInstalls()
    }

    private fun openInstallSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${activity.packageName}"),
            )
            activity.startActivity(intent)
        }
        result.success(null)
    }

    private fun install(call: MethodCall, result: MethodChannel.Result) {
        val fileName = requireSafeFileName(call.argument("fileName"))
        requireDownloadId(call)
        val apk = File(updateDirectory(), fileName)
        check(apk.isFile) { "The downloaded APK no longer exists" }
        val uri = FileProvider.getUriForFile(
            activity,
            "${activity.packageName}.fileprovider",
            apk,
        )
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, APK_MIME_TYPE)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        check(intent.resolveActivity(activity.packageManager) != null) {
            "No system package installer is available"
        }
        activity.startActivity(intent)
        result.success(null)
    }

    private fun requireDownloadId(call: MethodCall): Long {
        return requireNotNull(call.argument<Number>("downloadId")) {
            "Missing download ID"
        }.toLong()
    }

    private fun updateDirectory(): File {
        val downloadsDirectory = requireNotNull(
            activity.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),
        ) {
            "External app storage is unavailable"
        }
        return File(downloadsDirectory, UPDATE_DIRECTORY)
    }

    private fun requireSafeFileName(value: String?): String {
        val fileName = requireNotNull(value) { "Missing APK filename" }
        require(SAFE_APK_NAME.matches(fileName)) { "Unsafe APK filename" }
        return fileName
    }

    private fun statusName(status: Int): String {
        return when (status) {
            DownloadManager.STATUS_PENDING -> "pending"
            DownloadManager.STATUS_RUNNING -> "running"
            DownloadManager.STATUS_PAUSED -> "paused"
            DownloadManager.STATUS_SUCCESSFUL -> "successful"
            DownloadManager.STATUS_FAILED -> "failed"
            else -> "missing"
        }
    }

    private fun reasonText(status: Int, reason: Int): String? {
        if (status == DownloadManager.STATUS_PAUSED) {
            return when (reason) {
                DownloadManager.PAUSED_WAITING_TO_RETRY -> "等待系统重试"
                DownloadManager.PAUSED_WAITING_FOR_NETWORK -> "等待网络连接"
                DownloadManager.PAUSED_QUEUED_FOR_WIFI -> "等待 Wi-Fi"
                else -> "系统已暂停下载"
            }
        }
        if (status != DownloadManager.STATUS_FAILED) {
            return null
        }
        return when (reason) {
            DownloadManager.ERROR_INSUFFICIENT_SPACE -> "存储空间不足"
            DownloadManager.ERROR_DEVICE_NOT_FOUND -> "找不到存储设备"
            DownloadManager.ERROR_CANNOT_RESUME -> "无法继续下载"
            DownloadManager.ERROR_FILE_ALREADY_EXISTS -> "目标文件已存在"
            DownloadManager.ERROR_HTTP_DATA_ERROR -> "网络传输错误"
            DownloadManager.ERROR_TOO_MANY_REDIRECTS -> "下载重定向过多"
            DownloadManager.ERROR_UNHANDLED_HTTP_CODE -> "服务器拒绝下载"
            DownloadManager.ERROR_FILE_ERROR -> "无法写入安装包"
            else -> "系统下载失败（$reason）"
        }
    }

    companion object {
        private const val CHANNEL_NAME =
            "io.github.gxwane.pilipalaz/app_update"
        private const val APK_MIME_TYPE =
            "application/vnd.android.package-archive"
        private const val UPDATE_DIRECTORY = "updates"
        private val SAFE_APK_NAME =
            Regex("^[A-Za-z0-9][A-Za-z0-9._-]*\\.apk$")
    }
}
