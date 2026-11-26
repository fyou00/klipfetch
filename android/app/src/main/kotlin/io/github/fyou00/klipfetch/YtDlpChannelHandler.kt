package io.github.fyou00.klipfetch

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.yausername.aria2c.Aria2c
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
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

class YtDlpChannelHandler(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val TAG = "KlipFetchYtDlp"
        const val METHOD_CHANNEL = "io.github.fyou00.klipfetch/ytdlp"
        const val PROGRESS_CHANNEL = "io.github.fyou00.klipfetch/ytdlp_progress"
    }

    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val exceptionHandler = CoroutineExceptionHandler { _, throwable ->
        Log.e(TAG, "Unhandled yt-dlp coroutine error: ${throwable.javaClass.simpleName}", throwable)
    }
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO + exceptionHandler)

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
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                postError(result, "YTDLP_INIT_ERROR", t.message ?: "Failed to initialize yt-dlp", null)
            }
        }
    }

    private fun handleGetVersion(result: MethodChannel.Result) {
        scope.launch {
            try {
                ensureInitialized()
                postSuccess(result, YoutubeDL.getInstance().version(appContext))
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                postError(result, "YTDLP_VERSION_ERROR", t.message ?: "Failed to read yt-dlp version", null)
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
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                postError(result, "YTDLP_UPDATE_ERROR", t.message ?: "Failed to update yt-dlp", null)
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
        val allowPlaylist = call.argument<Boolean>("allowPlaylist") ?: false

        scope.launch {
            try {
                ensureInitialized()
                val request = YoutubeDLRequest(url).apply {
                    addOption("--dump-single-json")
                    if (allowPlaylist) {
                        addOption("--flat-playlist")
                    } else {
                        addOption("--no-playlist")
                    }
                    addOption("--no-warnings")
                }
                applyCookiesAndJsRuntime(request, cookiesPath)
                val response = YoutubeDL.getInstance().execute(request, null, null)
                postSuccess(result, response.out)
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                postError(result, "YTDLP_INFO_ERROR", t.message ?: "Failed to extract media info", null)
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
        val allowPlaylist = call.argument<Boolean>("allowPlaylist") ?: false
        val playlistItems = call.argument<String>("playlistItems")
        val mergeOutputFormat = call.argument<String>("mergeOutputFormat") ?: "mp4"
        val downloadSubtitles = call.argument<Boolean>("downloadSubtitles") ?: false
        val embedSubtitles = call.argument<Boolean>("embedSubtitles") ?: true
        val subtitleLangs = call.argument<String>("subtitleLangs") ?: "en,id"
        val sponsorBlockCategories = call.argument<List<String>>("sponsorBlockCategories") ?: emptyList()
        val extraArgs = call.argument<List<String>>("extraArgs") ?: emptyList()

        val safeContainer = if (mergeOutputFormat.lowercase() == "mkv") "mkv" else "mp4"

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
                    if (allowPlaylist) {
                        addOption("--yes-playlist")
                        if (!playlistItems.isNullOrBlank()) {
                            addOption("--playlist-items", playlistItems)
                        }
                    } else {
                        addOption("--no-playlist")
                    }
                    addOption("--no-simulate")
                    addOption("--print", "after_move:filepath")
                    if (audioOnly) {
                        addOption("-x")
                        addOption("--audio-format", audioFormat)
                    } else if (!formatSelector.isNullOrBlank()) {
                        addOption("-f", formatSelector)
                        addOption("--merge-output-format", safeContainer)
                    } else {
                        addOption("-f", "bv*+ba/b")
                        addOption("--merge-output-format", safeContainer)
                    }
                    if (downloadSubtitles && !audioOnly) {
                        addOption("--write-subs")
                        addOption("--write-auto-subs")
                        addOption("--sub-langs", if (subtitleLangs.isBlank()) "en,id" else subtitleLangs)
                        addOption("--sub-format", "srt/vtt/best")
                        if (embedSubtitles) {
                            addOption("--embed-subs")
                        }
                    }
                    if (sponsorBlockCategories.isNotEmpty()) {
                        addOption("--sponsorblock-remove", sponsorBlockCategories.joinToString(","))
                    }
                    if (extraArgs.isNotEmpty()) {
                        addCommands(extraArgs)
                    }
                }
                applyCookiesAndJsRuntime(request, cookiesPath)

                val response = YoutubeDL.getInstance().execute(request, taskId) { progress, etaInSeconds, line ->
                    val lineText: String? = line
                    val phase = if (
                        lineText != null && (
                            lineText.contains("[Merger]") ||
                                lineText.contains("[ExtractAudio]") ||
                                lineText.contains("[EmbedSubtitle]") ||
                                lineText.contains("[SponsorBlock]") ||
                                lineText.contains("[Fixup")
                            )
                    ) {
                        "muxing"
                    } else {
                        "downloading"
                    }
                    emitProgress(
                        mapOf(
                            "taskId" to taskId,
                            "percent" to progress.toDouble(),
                            "etaSeconds" to if (etaInSeconds >= 0) etaInSeconds else null,
                            "phase" to phase,
                            "logLine" to line,
                        )
                    )
                }

                val resolvedOutputPath = resolveDownloadedFilePath(response.out, outputTemplate)
                val resolvedOutputPaths = resolveAllDownloadedFilePaths(response.out, outputTemplate)

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
                        "outputPath" to resolvedOutputPath,
                        "outputPaths" to resolvedOutputPaths,
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
            } catch (e: CancellationException) {
                throw e
            } catch (t: Throwable) {
                emitProgress(
                    mapOf(
                        "taskId" to taskId,
                        "percent" to 0.0,
                        "phase" to "failed",
                        "logLine" to (t.message ?: "Download failed"),
                    )
                )
                postError(result, "YTDLP_DOWNLOAD_ERROR", t.message ?: "Download failed", null)
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
        try {
            Aria2c.getInstance().init(appContext)
        } catch (t: Throwable) {
            Log.w(TAG, "Optional aria2c init failed: ${t.javaClass.simpleName}")
        }
        initialized = true
    }

    private fun resolveDownloadedFilePath(stdout: String, outputTemplate: String): String? {
        val printedPath = stdout
            .lineSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .toList()
            .asReversed()
            .firstOrNull { candidate -> File(candidate).isFile }
        if (printedPath != null) return printedPath

        val parentDir = File(outputTemplate).parentFile ?: return null
        return parentDir
            .listFiles()
            ?.filter { file ->
                file.isFile &&
                    !file.name.endsWith(".part") &&
                    !file.name.endsWith(".ytdl") &&
                    !file.name.endsWith(".temp")
            }
            ?.maxByOrNull { it.lastModified() }
            ?.absolutePath
    }

    private fun resolveAllDownloadedFilePaths(stdout: String, outputTemplate: String): List<String> {
        val resolved = LinkedHashSet<String>()
        for (line in stdout.lineSequence()) {
            val trimmed = line.trim()
            if (trimmed.isNotEmpty() && File(trimmed).isFile) {
                resolved.add(File(trimmed).absolutePath)
            }
        }
        val parentDir = File(outputTemplate).parentFile
        parentDir
            ?.listFiles()
            ?.filter { file ->
                file.isFile &&
                    !file.name.endsWith(".part") &&
                    !file.name.endsWith(".ytdl") &&
                    !file.name.endsWith(".temp")
            }
            ?.sortedBy { it.name.lowercase() }
            ?.forEach { file -> resolved.add(file.absolutePath) }
        return resolved.toList()
    }

    private fun applyCookiesAndJsRuntime(request: YoutubeDLRequest, cookiesPath: String?) {
        if (!cookiesPath.isNullOrBlank() && File(cookiesPath).exists()) {
            request.addOption("--cookies", cookiesPath)
        }
        val nativeDir = appContext.applicationInfo.nativeLibraryDir
        val quickJs = File(nativeDir, "libqjs.so").takeIf { it.exists() }
            ?: File(nativeDir, "libquickjs.so").takeIf { it.exists() }
        if (quickJs != null) {
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
