package com.gamal.genzoo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.gamal.genzoo/installer"
    private val PDF_CHANNEL = "com.gamal.genzoo/pdf_intent"
    private var pdfChannel: MethodChannel? = null
    private var pendingPdf: Map<String, String>? = null

    /** Copies a PDF handed to us by another app (content:// or file://) into the app cache. */
    private fun extractPdf(intent: Intent?): Map<String, String>? {
        if (intent == null) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> if (Build.VERSION.SDK_INT >= 33)
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            else @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
        if (uri == null) return null
        return try {
            var name = "document.pdf"
            if (uri.scheme == "content") {
                contentResolver.query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                    if (c.moveToFirst()) c.getString(0)?.let { name = it }
                }
            } else {
                uri.lastPathSegment?.let { name = it }
            }
            val dir = File(cacheDir, "external_pdf").apply { mkdirs() }
            val out = File(dir, "${System.currentTimeMillis()}_" + name.replace(Regex("[\\\\/:*?\"<>|]"), "_"))
            contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { input.copyTo(it) }
            } ?: return null
            mapOf("path" to out.absolutePath, "name" to name)
        } catch (e: Exception) {
            null
        }
    }

    private fun deliverPdf(intent: Intent?) {
        val data = extractPdf(intent) ?: return
        val ch = pdfChannel
        if (ch != null) ch.invokeMethod("openPdf", data) else pendingPdf = data
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        deliverPdf(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
        pendingPdf = extractPdf(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pdfChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PDF_CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                if (call.method == "getInitialPdf") {
                    result.success(pendingPdf)
                    pendingPdf = null
                } else result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canRequestPackageInstalls" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        result.success(packageManager.canRequestPackageInstalls())
                    } else {
                        result.success(true)
                    }
                }
                "openInstallSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            } catch (e2: Exception) {
                                result.error("OPEN_SETTINGS_FAILED", e2.message, null)
                            }
                        }
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)

        // News channel (heads-up + sound)
        val newsChannel = NotificationChannel(
            "genzoo_news",
            "أخبار GenZoo",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "إشعارات الأخبار والإعلانات الجديدة"
        }
        manager.createNotificationChannel(newsChannel)

        // Download progress channel (silent progress updates)
        val downloadChannel = NotificationChannel(
            "genzoo_downloads",
            "تحميلات وتحديثات GenZoo",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "إشعارات تقدم تحميل التحديثات والملفات"
            setShowBadge(false)
        }
        manager.createNotificationChannel(downloadChannel)
    }
}
