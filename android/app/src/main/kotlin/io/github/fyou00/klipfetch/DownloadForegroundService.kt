package io.github.fyou00.klipfetch

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.yausername.youtubedl_android.YoutubeDL

class DownloadForegroundService : Service() {

    companion object {
        const val CHANNEL_ID_PROGRESS = "klipfetch_downloads"
        const val CHANNEL_ID_STATUS = "klipfetch_status"
        const val PROGRESS_NOTIFICATION_ID = 4101

        const val ACTION_START_OR_UPDATE = "io.github.fyou00.klipfetch.action.START_OR_UPDATE"
        const val ACTION_STOP = "io.github.fyou00.klipfetch.action.STOP"
        const val ACTION_CANCEL_TASK = "io.github.fyou00.klipfetch.action.CANCEL_TASK"

        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_ACTIVE_COUNT = "active_count"
        const val EXTRA_STATUS_TEXT = "status_text"

        @Volatile
        var onCancelRequested: ((String) -> Unit)? = null

        fun startOrUpdate(
            context: Context,
            taskId: String,
            title: String,
            progress: Int,
            activeCount: Int,
            statusText: String?,
        ) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_START_OR_UPDATE
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_PROGRESS, progress)
                putExtra(EXTRA_ACTIVE_COUNT, activeCount)
                putExtra(EXTRA_STATUS_TEXT, statusText)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, DownloadForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForegroundAndRelease()
                return START_NOT_STICKY
            }

            ACTION_CANCEL_TASK -> {
                val taskId = intent.getStringExtra(EXTRA_TASK_ID)
                if (!taskId.isNullOrBlank()) {
                    YoutubeDL.getInstance().destroyProcessById(taskId)
                    onCancelRequested?.invoke(taskId)
                }
                return START_NOT_STICKY
            }

            ACTION_START_OR_UPDATE, null -> {
                val taskId = intent?.getStringExtra(EXTRA_TASK_ID).orEmpty()
                val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Downloading media"
                val progress = (intent?.getIntExtra(EXTRA_PROGRESS, -1) ?: -1).coerceIn(-1, 100)
                val activeCount = (intent?.getIntExtra(EXTRA_ACTIVE_COUNT, 1) ?: 1).coerceAtLeast(1)
                val statusText = intent?.getStringExtra(EXTRA_STATUS_TEXT)

                acquireWakeLock()
                val notification = buildProgressNotification(
                    taskId = taskId,
                    title = title,
                    progress = progress,
                    activeCount = activeCount,
                    statusText = statusText,
                )
                val serviceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                } else {
                    0
                }
                ServiceCompat.startForeground(
                    this,
                    PROGRESS_NOTIFICATION_ID,
                    notification,
                    serviceType,
                )
                return START_NOT_STICKY
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        releaseWakeLock()
        super.onDestroy()
    }

    private fun stopForegroundAndRelease() {
        releaseWakeLock()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "klipfetch:download_wakelock").apply {
            setReferenceCounted(false)
            acquire(30 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) {
                wakeLock?.release()
            }
        } catch (_: RuntimeException) {
            // Ignore already-released wake lock edge cases.
        } finally {
            wakeLock = null
        }
    }

    private fun ensureNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        val progressChannel = NotificationChannel(
            CHANNEL_ID_PROGRESS,
            "Active Downloads",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shows live download progress for TikTok, Instagram, and YouTube"
            setShowBadge(false)
        }

        val statusChannel = NotificationChannel(
            CHANNEL_ID_STATUS,
            "Download Alerts",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Notifies when downloads finish or fail"
        }

        manager.createNotificationChannel(progressChannel)
        manager.createNotificationChannel(statusChannel)
    }

    private fun buildProgressNotification(
        taskId: String,
        title: String,
        progress: Int,
        activeCount: Int,
        statusText: String?,
    ): Notification {
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        openAppIntent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP

        val openPendingIntent = PendingIntent.getActivity(
            this,
            100,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val contentTitle = if (activeCount > 1) {
            "Downloading $activeCount items"
        } else {
            title
        }
        val contentText = when {
            !statusText.isNullOrBlank() -> statusText
            progress in 0..100 -> "$progress%"
            else -> "Preparing transfer..."
        }

        val builder = NotificationCompat.Builder(this, CHANNEL_ID_PROGRESS)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(contentTitle)
            .setContentText(contentText)
            .setContentIntent(openPendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)

        if (progress in 0..100) {
            builder.setProgress(100, progress, false)
        } else {
            builder.setProgress(0, 0, true)
        }

        if (taskId.isNotBlank()) {
            val cancelIntent = Intent(this, DownloadForegroundService::class.java).apply {
                action = ACTION_CANCEL_TASK
                putExtra(EXTRA_TASK_ID, taskId)
            }
            val cancelPendingIntent = PendingIntent.getService(
                this,
                taskId.hashCode(),
                cancelIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            builder.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Cancel",
                cancelPendingIntent,
            )
        }

        return builder.build()
    }
}
