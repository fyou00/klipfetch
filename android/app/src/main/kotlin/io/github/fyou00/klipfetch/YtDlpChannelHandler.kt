package io.github.fyou00.klipfetch

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.yausername.aria2c.Aria2c
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
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

class YtDlpChannelHandler(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "io.github.fyou00.klipfetch/ytdlp"
        const val PROGRESS_CHANNEL = "io.github.fyou00.klipfetch/ytdlp_progress"
    }

    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val progressChannel = EventChannel(messenger, PROGRESS_CHANNEL)

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    @Volatile
    private var initialized = false

    init {
        methodChannel.setMethodCallHandler(this)
        progressChannel.setStreamHandler(this)
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        progressChannel.setStreamHandler(null)
        eventSink = null
        scope.cancel()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> handleInit(result)
            "getVersion" -> handleGetVersion(result)
            "updateYtDlp" -> handleUpdate(call, result)
            "extractInfo" -> handleExtractInfo(call, result)
            "download" -> handleDownload(call, result)
            "cancel" -> handleCancel(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleInit(result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                val version = YoutubeDL.getInstance().version(appContext)
                postSuccess(result, version)
            } catch (e: Exception) {
                postError(result, "YTDLP_INIT_ERROR", e.message ?: "Failed to initialize yt-dlp", null)
            }
        }
    }

    private fun handleGetVersion(result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                postSuccess(result, YoutubeDL.getInstance().version(appContext))
            } catch (e: Exception) {
                postError(result, "YTDLP_VERSION_ERROR", e.message ?: "Failed to read yt-dlp version", null)
            }
        }
    }

    private fun handleUpdate(call: MethodCall, result: MethodChannel.Result) {
        val channelName = call.argument<String>("channel") ?: "stable"
        val channel = when (channelName.lowercase()) {
            "nightly" -> YoutubeDL.UpdateChannel.NIGHTLY
            "master" -> YoutubeDL.UpdateChannel.MASTER
            else -> YoutubeDL.UpdateChannel.STABLE
        }
        scope.launch {
            try {
                ensureInitialized()
                val status = YoutubeDL.getInstance().updateYoutubeDL(appContext, channel)
                postSuccess(result, status?.name ?: "UNKNOWN")
            } catch (e: Exception) {
                postError(result, "YTDLP_UPDATE_ERROR", e.message ?: "Failed to update yt-dlp", null)
            }
        }
    }

    private fun handleExtractInfo(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.error("INVALID_ARGS", "url is required", null)
            return
        }
        val cookiesPath = call.argument<String>("cookiesPath")

        scope.launch {
            try {
                ensureInitialized()
                val request = YoutubeDLRequest(url).apply {
                    addOption("--dump-single-json")
                    addOption("--no-playlist")
                    addOption("--no-warnings")
                }
                applyCookiesAndJsRuntime(request, cookiesPath)
                val response = YoutubeDL.getInstance().execute(request, null, null)
                postSuccess(result, response.out)
            } catch (e: Exception) {
                postError(result, "YTDLP_INFO_ERROR", e.message ?: "Failed to extract media info", null)
            }
        }
    }

    private fun handleDownload(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId")
        val url = call.argument<String>("url")
        val outputTemplate = call.argument<String>("outputTemplate")
        if (taskId.isNullOrBlank() || url.isNullOrBlank() || outputTemplate.isNullOrBlank()) {
            result.error("INVALID_ARGS", "taskId, url, and outputTemplate are required", null)
            return
        }

        val formatSelector = call.argument<String>("formatSelector")
        val audioOnly = call.argument<Boolean>("audioOnly") ?: false
        val audioFormat = call.argument<String>("audioFormat") ?: "m4a"
        val cookiesPath = call.argument<String>("cookiesPath")
        val extraArgs = call.argument<List<String>>("extraArgs") ?: emptyList()

        scope.launch {
            try {
                ensureInitialized()
                val outFileParent = File(outputTemplate).parentFile
                if (outFileParent != null && !outFileParent.exists()) {
                    outFileParent.mkdirs()
                }

                val request = YoutubeDLRequest(url).apply {
                    addOption("-o", outputTemplate)
                    addOption("--newline")
                    addOption("--no-playlist")
                    if (audioOnly) {
                        addOption("-x")
                        addOption("--audio-format", audioFormat)
                    } else if (!formatSelector.isNullOrBlank()) {
                        addOption("-f", formatSelector)
                        addOption("--merge-output-format", "mp4")
                    } else {
                        addOption("-f", "bv*+ba/b")
                        addOption("--merge-output-format", "mp4")
                    }
                    if (extraArgs.isNotEmpty()) {
                        addCommands(extraArgs)
                    }
                }
                applyCookiesAndJsRuntime(request, cookiesPath)

                val response = YoutubeDL.getInstance().execute(request, taskId) { progress, etaInSeconds, line ->
                    emitProgress(
                        mapOf(
                            "taskId" to taskId,
                            "percent" to progress.toDouble(),
                            "etaSeconds" to if (etaInSeconds >= 0) etaInSeconds else null,
                            "phase" to "downloading",
                            "logLine" to line,
                        )
                    )
                }

                emitProgress(
                    mapOf(
                        "taskId" to taskId,
                        "percent" to 100.0,
                        "etaSeconds" to 0L,
                        "phase" to "completed",
                        "logLine" to "",
                    )
                )

                postSuccess(
                    result,
                    mapOf(
                        "exitCode" to response.exitCode,
                        "stdout" to response.out,
                        "stderr" to response.err,
                    )
                )
            } catch (_: YoutubeDL.CanceledException) {
                emitProgress(
                    mapOf(
                        "taskId" to taskId,
                        "percent" to 0.0,
                        "phase" to "cancelled",
                        "logLine" to "Cancelled",
                    )
                )
                postError(result, "CANCELLED", "Download cancelled", null)
            } catch (e: Exception) {
                emitProgress(
                    mapOf(
                        "taskId" to taskId,
                        "percent" to 0.0,
                        "phase" to "failed",
                        "logLine" to (e.message ?: "Download failed"),
                    )
                )
                postError(result, "YTDLP_DOWNLOAD_ERROR", e.message ?: "Download failed", null)
            }
        }
    }

    private fun handleCancel(call: MethodCall, result: MethodChannel.Result) {
        val taskId = call.argument<String>("taskId")
        if (taskId.isNullOrBlank()) {
            result.error("INVALID_ARGS", "taskId is required", null)
            return
        }
        val cancelled = YoutubeDL.getInstance().destroyProcessById(taskId)
        result.success(cancelled)
    }

    @Synchronized
    private fun ensureInitialized() {
        if (initialized) return
        YoutubeDL.getInstance().init(appContext)
        FFmpeg.getInstance().init(appContext)
        Aria2c.getInstance().init(appContext)
        initialized = true
    }

    private fun applyCookiesAndJsRuntime(request: YoutubeDLRequest, cookiesPath: String?) {
        if (!cookiesPath.isNullOrBlank() && File(cookiesPath).exists()) {
            request.addOption("--cookies", cookiesPath)
        }
        val quickJs = File(appContext.applicationInfo.nativeLibraryDir, "libquickjs.so")
        if (quickJs.exists()) {
            request.addOption("--js-runtimes", "quickjs:${quickJs.absolutePath}")
        }
    }

    private fun emitProgress(payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(payload)
        }
    }

    private fun postSuccess(result: MethodChannel.Result, value: Any?) {
        mainHandler.post {
            result.success(value)
        }
    }

    private fun postError(
        result: MethodChannel.Result,
        code: String,
        message: String?,
        details: Any?,
    ) {
        mainHandler.post {
            result.error(code, message, details)
        }
    }
}
