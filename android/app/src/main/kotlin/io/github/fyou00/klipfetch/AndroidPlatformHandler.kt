package io.github.fyou00.klipfetch

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.webkit.CookieManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineExceptionHandler
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
        private const val TAG = "KlipFetchPlatform"
        const val METHOD_CHANNEL = "io.github.fyou00.klipfetch/platform"
        const val EVENT_CHANNEL = "io.github.fyou00.klipfetch/platform_events"
        private const val REQUEST_POST_NOTIFICATIONS = 4201
        private const val REQUEST_AUTH_BROWSER = 4202
    }

    private val appContext = activity.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val exceptionHandler = CoroutineExceptionHandler { _, throwable ->
        Log.e(TAG, "Unhandled platform coroutine error: ${throwable.javaClass.simpleName}", throwable)
    }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO + exceptionHandler)

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    @Volatile
    private var pendingSharedText: String? = null

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingAuthResult: MethodChannel.Result? = null

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
        pendingAuthResult = null
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

    fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        if (requestCode != REQUEST_AUTH_BROWSER) return false
        val result = pendingAuthResult
        pendingAuthResult = null
        if (result == null) return true

        if (resultCode == Activity.RESULT_OK && data != null) {
            val netscapeCookies = data.getStringExtra(AuthWebViewActivity.RESULT_NETSCAPE_COOKIES) ?: ""
            val cookieCount = data.getIntExtra(AuthWebViewActivity.RESULT_COOKIE_COUNT, 0)
            val hasAuthCookie = data.getBooleanExtra(AuthWebViewActivity.RESULT_HAS_AUTH_COOKIE, false)
            mainHandler.post {
                result.success(
                    mapOf(
                        "cancelled" to false,
                        "netscapeCookies" to netscapeCookies,
                        "cookieCount" to cookieCount,
                        "hasAuthCookie" to hasAuthCookie,
                    )
                )
            }
        } else {
            mainHandler.post {
                result.success(
                    mapOf(
                        "cancelled" to true,
                        "netscapeCookies" to "",
                        "cookieCount" to 0,
                        "hasAuthCookie" to false,
                    )
                )
            }
        }
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
            "exportStagingDirectory" -> handleExportStagingDirectory(call, result)
            "openAuthBrowser" -> handleOpenAuthBrowser(call, result)
            "clearWebViewCookies" -> handleClearWebViewCookies(call, result)
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

        try {
            DownloadForegroundService.startOrUpdate(
                context = appContext,
                taskId = taskId,
                title = title,
                progress = progress,
                activeCount = activeCount,
                statusText = statusText,
            )
            result.success(true)
        } catch (t: Throwable) {
            Log.w(TAG, "Foreground service start/update rejected: ${t.javaClass.simpleName}")
            result.success(false)
        }
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
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                mainHandler.post {
                    result.error(
                        "MEDIASTORE_EXPORT_ERROR",
                        t.message ?: "Failed to export file to Downloads",
                        null,
                    )
                }
            }
        }
    }

    private fun handleExportStagingDirectory(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val stagingDirPath = call.argument<String>("stagingDirPath")
        val platform = call.argument<String>("platform")
        if (stagingDirPath.isNullOrBlank() || platform.isNullOrBlank()) {
            result.error("INVALID_ARGS", "stagingDirPath and platform are required", null)
            return
        }

        scope.launch {
            try {
                val exported = MediaStoreExporter.exportDirectory(
                    context = appContext,
                    stagingDirPath = stagingDirPath,
                    platform = platform,
                )
                mainHandler.post {
                    result.success(
                        mapOf(
                            "primaryUri" to exported.primaryUri,
                            "primaryDisplayPath" to exported.primaryDisplayPath,
                            "fileName" to exported.fileName,
                            "totalSizeBytes" to exported.totalSizeBytes,
                            "exportedCount" to exported.exportedCount,
                            "displayPaths" to exported.displayPaths,
                        )
                    )
                }
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                mainHandler.post {
                    result.error(
                        "MEDIASTORE_BATCH_EXPORT_ERROR",
                        t.message ?: "Failed to export staging directory to Downloads",
                        null,
                    )
                }
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun handleOpenAuthBrowser(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val platform = call.argument<String>("platform")
        val loginUrl = call.argument<String>("loginUrl")
        if (platform.isNullOrBlank() || loginUrl.isNullOrBlank()) {
            result.error("INVALID_ARGS", "platform and loginUrl are required", null)
            return
        }
        if (pendingAuthResult != null) {
            result.error("AUTH_IN_PROGRESS", "Another auth browser session is already active", null)
            return
        }

        val cookieUrls = ArrayList(call.argument<List<String>>("cookieUrls") ?: emptyList())
        val authCookieNames = ArrayList(call.argument<List<String>>("authCookieNames") ?: emptyList())

        val intent = Intent(activity, AuthWebViewActivity::class.java).apply {
            putExtra(AuthWebViewActivity.EXTRA_PLATFORM, platform)
            putExtra(AuthWebViewActivity.EXTRA_LOGIN_URL, loginUrl)
            putStringArrayListExtra(AuthWebViewActivity.EXTRA_COOKIE_URLS, cookieUrls)
            putStringArrayListExtra(AuthWebViewActivity.EXTRA_AUTH_COOKIE_NAMES, authCookieNames)
        }

        pendingAuthResult = result
        try {
            activity.startActivityForResult(intent, REQUEST_AUTH_BROWSER)
        } catch (e: Exception) {
            pendingAuthResult = null
            result.error("AUTH_LAUNCH_ERROR", e.message ?: "Failed to open auth browser", null)
        }
    }

    private fun handleClearWebViewCookies(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val clearAll = call.argument<Boolean>("clearAll") ?: false
        val cookieUrls = call.argument<List<String>>("cookieUrls") ?: emptyList()

        mainHandler.post {
            try {
                val cookieManager = CookieManager.getInstance()
                if (clearAll) {
                    cookieManager.removeAllCookies { _ ->
                        cookieManager.flush()
                        result.success(true)
                    }
                    return@post
                }

                for (rawUrl in cookieUrls) {
                    val existing = cookieManager.getCookie(rawUrl) ?: continue
                    val host = Uri.parse(rawUrl).host?.lowercase() ?: continue
                    val rootDomain = host.removePrefix("www.").removePrefix("m.")
                    for (pair in existing.split(';')) {
                        val eq = pair.indexOf('=')
                        if (eq <= 0) continue
                        val name = pair.substring(0, eq).trim()
                        if (name.isEmpty()) continue
                        cookieManager.setCookie(rawUrl, "$name=; Max-Age=0; Path=/")
                        cookieManager.setCookie(rawUrl, "$name=; Domain=$host; Max-Age=0; Path=/")
                        cookieManager.setCookie(rawUrl, "$name=; Domain=.$rootDomain; Max-Age=0; Path=/")
                    }
                }
                cookieManager.flush()
                result.success(true)
            } catch (e: Exception) {
                result.error("CLEAR_COOKIES_ERROR", e.message ?: "Failed to clear WebView cookies", null)
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
