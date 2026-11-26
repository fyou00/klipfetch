package io.github.fyou00.klipfetch

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File

class AndroidPlatformHandler(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "io.github.fyou00.klipfetch/platform"
        const val EVENT_CHANNEL = "io.github.fyou00.klipfetch/platform_events"
        private const val REQUEST_POST_NOTIFICATIONS = 4201
    }

    private val appContext = activity.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    @Volatile
    private var pendingSharedText: String? = null

    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        DownloadForegroundService.onCancelRequested = { taskId ->
            emitEvent(
                mapOf(
                    "type" to "notification_cancel",
                    "taskId" to taskId,
                )
            )
        }
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        if (DownloadForegroundService.onCancelRequested != null) {
            DownloadForegroundService.onCancelRequested = null
        }
        eventSink = null
        pendingPermissionResult = null
        scope.cancel()
    }

    fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.action != Intent.ACTION_SEND) return
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)
            ?: return
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return

        if (eventSink != null) {
            emitEvent(
                mapOf(
                    "type" to "shared_text",
                    "text" to trimmed,
                )
            )
        } else {
            pendingSharedText = trimmed
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_POST_NOTIFICATIONS) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.let { result ->
            mainHandler.post { result.success(granted) }
        }
        pendingPermissionResult = null
        return true
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInitialSharedText" -> {
                val text = pendingSharedText
                pendingSharedText = null
                result.success(text)
            }

            "startForegroundDownload" -> handleStartOrUpdateForeground(call, result)
            "updateForegroundDownload" -> handleStartOrUpdateForeground(call, result)
            "stopForegroundDownload" -> {
                DownloadForegroundService.stop(appContext)
                result.success(true)
            }

            "exportToMediaStore" -> handleExportToMediaStore(call, result)
            "openFile" -> handleOpenFile(call, result)
            "shareFile" -> handleShareFile(call, result)
            "requestNotificationPermission" -> handleRequestNotificationPermission(result)
            "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)
            else -> result.notImplemented()
        }
    }

    private fun handleStartOrUpdateForeground(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val taskId = call.argument<String>("taskId").orEmpty()
        val title = call.argument<String>("title") ?: "Downloading media"
        val progress = call.argument<Int>("progress") ?: -1
        val activeCount = call.argument<Int>("activeCount") ?: 1
        val statusText = call.argument<String>("statusText")

        DownloadForegroundService.startOrUpdate(
            context = appContext,
            taskId = taskId,
            title = title,
            progress = progress,
            activeCount = activeCount,
            statusText = statusText,
        )
        result.success(true)
    }

    private fun handleExportToMediaStore(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val stagedFilePath = call.argument<String>("stagedFilePath")
        val platform = call.argument<String>("platform")
        if (stagedFilePath.isNullOrBlank() || platform.isNullOrBlank()) {
            result.error("INVALID_ARGS", "stagedFilePath and platform are required", null)
            return
        }

        scope.launch {
            try {
                val exported = MediaStoreExporter.export(
                    context = appContext,
                    stagedFilePath = stagedFilePath,
                    platform = platform,
                )
                mainHandler.post {
                    result.success(
                        mapOf(
                            "uri" to exported.uri,
                            "displayPath" to exported.displayPath,
                            "fileName" to exported.fileName,
                            "sizeBytes" to exported.sizeBytes,
                        )
                    )
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error(
                        "MEDIASTORE_EXPORT_ERROR",
                        e.message ?: "Failed to export file to Downloads",
                        null,
                    )
                }
            }
        }
    }

    private fun handleOpenFile(call: MethodCall, result: MethodChannel.Result) {
        val uriOrPath = call.argument<String>("uriOrPath")
        if (uriOrPath.isNullOrBlank()) {
            result.error("INVALID_ARGS", "uriOrPath is required", null)
            return
        }
        val mimeType = call.argument<String>("mimeType") ?: inferMimeFromPath(uriOrPath)

        try {
            val uri = resolveShareableUri(uriOrPath)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            appContext.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OPEN_FILE_ERROR", e.message ?: "No app found to open file", null)
        }
    }

    private fun handleShareFile(call: MethodCall, result: MethodChannel.Result) {
        val uriOrPath = call.argument<String>("uriOrPath")
        if (uriOrPath.isNullOrBlank()) {
            result.error("INVALID_ARGS", "uriOrPath is required", null)
            return
        }
        val mimeType = call.argument<String>("mimeType") ?: inferMimeFromPath(uriOrPath)

        try {
            val uri = resolveShareableUri(uriOrPath)
            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = mimeType
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            val chooser = Intent.createChooser(shareIntent, "Share media").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            appContext.startActivity(chooser)
            result.success(true)
        } catch (e: Exception) {
            result.error("SHARE_FILE_ERROR", e.message ?: "Failed to share file", null)
        }
    }

    private fun handleRequestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        val current = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.POST_NOTIFICATIONS,
        )
        if (current == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("PERMISSION_IN_PROGRESS", "Notification permission request already active", null)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_POST_NOTIFICATIONS,
        )
    }

    private fun resolveShareableUri(uriOrPath: String): Uri {
        val parsed = Uri.parse(uriOrPath)
        if (parsed.scheme == "content") {
            return parsed
        }
        val file = if (parsed.scheme == "file" && parsed.path != null) {
            File(parsed.path!!)
        } else {
            File(uriOrPath)
        }
        return FileProvider.getUriForFile(
            appContext,
            "${appContext.packageName}.fileprovider",
            file,
        )
    }

    private fun inferMimeFromPath(uriOrPath: String): String {
        val name = uriOrPath.substringAfterLast('/', uriOrPath)
        return MediaStoreExporter.inferMimeType(name)
    }

    private fun emitEvent(payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }
}
