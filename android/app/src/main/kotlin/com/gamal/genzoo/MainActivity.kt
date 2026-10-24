package com.gamal.genzoo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNewsChannel()
    }

    // High-importance channel used by news notifications (heads-up + sound).
    // Its id must match `channel_id` in the server script and
    // `default_notification_channel_id` in AndroidManifest.xml.
    private fun createNewsChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "genzoo_news",
            "أخبار GenZoo",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "إشعارات الأخبار والإعلانات الجديدة"
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }
}
