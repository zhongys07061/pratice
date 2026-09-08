package com.yourname.zicebao

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.OpenableColumns
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.yourname.zicebao/native"
    private var channel: MethodChannel? = null
    private var pendingIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedFile" -> result.success(readSharedFile())
                "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                "requestAllFilesAccess" -> {
                    requestAllFilesAccess()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingIntent = intent
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        pendingIntent = intent
        channel?.invokeMethod("onSharedFile", readSharedFile())
    }

    private fun hasAllFilesAccess(): Boolean =
        Build.VERSION.SDK_INT < 30 || Environment.isExternalStorageManager()

    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT < 30 || Environment.isExternalStorageManager()) return
        try {
            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
        } catch (_: Exception) {
            try {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            } catch (_: Exception) {
            }
        }
    }

    private fun readSharedFile(): Map<String, Any?>? {
        val intent = pendingIntent ?: return null
        pendingIntent = null
        if (intent.action != Intent.ACTION_VIEW && intent.action != Intent.ACTION_SEND) return null
        val uri: Uri? = intent.data ?: extractStream(intent)
        if (uri == null) return null
        return try {
            val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return null
            mapOf("name" to queryName(uri), "bytes" to bytes)
        } catch (_: Exception) {
            null
        }
    }

    @Suppress("DEPRECATION")
    private fun extractStream(intent: Intent): Uri? =
        intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri

    private fun queryName(uri: Uri): String {
        return try {
            var name: String? = null
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && cursor.moveToFirst()) name = cursor.getString(idx)
            }
            name ?: "shared_file"
        } catch (_: Exception) {
            "shared_file"
        }
    }
}
