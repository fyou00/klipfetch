package io.github.fyou00.klipfetch

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.IOException

object MediaStoreExporter {

    data class ExportResult(
        val uri: String,
        val displayPath: String,
        val fileName: String,
        val sizeBytes: Long,
    )

    data class BatchExportResult(
        val primaryUri: String,
        val primaryDisplayPath: String,
        val fileName: String,
        val totalSizeBytes: Long,
        val exportedCount: Int,
        val displayPaths: List<String>,
    )

    fun exportDirectory(
        context: Context,
        stagingDirPath: String,
        platform: String,
    ): BatchExportResult {
        val dir = File(stagingDirPath)
        if (!dir.exists() || !dir.isDirectory) {
            throw IOException("Staging directory does not exist: $stagingDirPath")
        }

        val candidates = dir
            .listFiles()
            ?.filter { file ->
                file.isFile &&
                    file.length() > 0 &&
                    !file.name.endsWith(".part") &&
                    !file.name.endsWith(".ytdl") &&
                    !file.name.endsWith(".temp")
            }
            ?.sortedBy { it.name.lowercase() }
            ?: emptyList()

        if (candidates.isEmpty()) {
            throw IOException("No completed media files found in $stagingDirPath")
        }

        val primaryCandidate = candidates.minByOrNull { mediaPriority(it.name) } ?: candidates.first()
        val displayPaths = mutableListOf<String>()
        var totalSize = 0L
        var primaryExport: ExportResult? = null

        for (file in candidates) {
            val exported = export(
                context = context,
                stagedFilePath = file.absolutePath,
                platform = platform,
            )
            displayPaths.add(exported.displayPath)
            totalSize += exported.sizeBytes
            if (file.absolutePath == primaryCandidate.absolutePath) {
                primaryExport = exported
            }
        }

        val resolvedPrimary = primaryExport ?: throw IOException("Failed to resolve exported media")
        return BatchExportResult(
            primaryUri = resolvedPrimary.uri,
            primaryDisplayPath = resolvedPrimary.displayPath,
            fileName = resolvedPrimary.fileName,
            totalSizeBytes = totalSize,
            exportedCount = candidates.size,
            displayPaths = displayPaths,
        )
    }

    private fun mediaPriority(fileName: String): Int {
        return when (fileName.substringAfterLast('.', "").lowercase()) {
            "mp4", "mkv", "webm", "mov" -> 0
            "jpg", "jpeg", "png", "webp" -> 1
            "m4a", "mp3", "opus", "ogg", "wav" -> 2
            else -> 3
        }
    }

    fun export(
        context: Context,
        stagedFilePath: String,
        platform: String,
    ): ExportResult {
        val sourceFile = File(stagedFilePath)
        if (!sourceFile.exists() || !sourceFile.isFile) {
            throw IOException("Staged file does not exist: $stagedFilePath")
        }

        val platformFolder = when (platform.lowercase()) {
            "tiktok" -> "TikTok"
            "instagram" -> "Instagram"
            "youtube" -> "YouTube"
            else -> throw IllegalArgumentException("Unsupported platform for export: $platform")
        }

        val fileName = sanitizeFileName(sourceFile.name)
        val mimeType = inferMimeType(fileName)
        val sizeBytes = sourceFile.length()

        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            exportWithMediaStore(
                context = context,
                sourceFile = sourceFile,
                platformFolder = platformFolder,
                fileName = fileName,
                mimeType = mimeType,
                sizeBytes = sizeBytes,
            )
        } else {
            exportLegacyDownloads(
                context = context,
                sourceFile = sourceFile,
                platformFolder = platformFolder,
                fileName = fileName,
                mimeType = mimeType,
                sizeBytes = sizeBytes,
            )
        }

        cleanupStagedFile(context, sourceFile)
        return result
    }

    private fun exportWithMediaStore(
        context: Context,
        sourceFile: File,
        platformFolder: String,
        fileName: String,
        mimeType: String,
        sizeBytes: Long,
    ): ExportResult {
        val resolver = context.contentResolver
        val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/KlipFetch/$platformFolder"
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Downloads.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Files.getContentUri("external")
        }

        val uri = resolver.insert(collection, values)
            ?: throw IOException("Failed to create MediaStore entry for $fileName")

        try {
            resolver.openOutputStream(uri)?.use { out ->
                sourceFile.inputStream().use { input ->
                    input.copyTo(out)
                }
            } ?: throw IOException("Unable to open output stream for $uri")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val ready = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(uri, ready, null, null)
            }
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }

        return ExportResult(
            uri = uri.toString(),
            displayPath = "Downloads/KlipFetch/$platformFolder/$fileName",
            fileName = fileName,
            sizeBytes = sizeBytes,
        )
    }

    @Suppress("DEPRECATION")
    private fun exportLegacyDownloads(
        context: Context,
        sourceFile: File,
        platformFolder: String,
        fileName: String,
        mimeType: String,
        sizeBytes: Long,
    ): ExportResult {
        val downloadsRoot = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        val targetDir = File(downloadsRoot, "KlipFetch/$platformFolder")
        if (!targetDir.exists() && !targetDir.mkdirs()) {
            throw IOException("Failed to create directory: ${targetDir.absolutePath}")
        }

        val targetFile = resolveUniqueFile(targetDir, fileName)
        sourceFile.inputStream().use { input ->
            targetFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        MediaScannerConnection.scanFile(
            context,
            arrayOf(targetFile.absolutePath),
            arrayOf(mimeType),
            null,
        )

        return ExportResult(
            uri = Uri.fromFile(targetFile).toString(),
            displayPath = "Downloads/KlipFetch/$platformFolder/${targetFile.name}",
            fileName = targetFile.name,
            sizeBytes = sizeBytes,
        )
    }

    private fun resolveUniqueFile(dir: File, fileName: String): File {
        var candidate = File(dir, fileName)
        if (!candidate.exists()) return candidate

        val dot = fileName.lastIndexOf('.')
        val stem = if (dot > 0) fileName.substring(0, dot) else fileName
        val ext = if (dot > 0) fileName.substring(dot) else ""

        var index = 1
        while (candidate.exists()) {
            candidate = File(dir, "$stem ($index)$ext")
            index++
        }
        return candidate
    }

    private fun cleanupStagedFile(context: Context, sourceFile: File) {
        val stagingRoot = File(context.cacheDir, "staging").canonicalPath
        val sourceParent = sourceFile.parentFile
        sourceFile.delete()
        if (sourceParent != null &&
            sourceParent.canonicalPath.startsWith(stagingRoot) &&
            sourceParent.canonicalPath != stagingRoot &&
            sourceParent.listFiles().isNullOrEmpty()
        ) {
            sourceParent.delete()
        }
    }

    private fun sanitizeFileName(raw: String): String {
        val cleaned = raw.replace(Regex("""[\\/:*?"<>|]"""), "_").trim()
        return cleaned.ifEmpty { "klipfetch_media.mp4" }
    }

    fun inferMimeType(fileName: String): String {
        val ext = fileName.substringAfterLast('.', "").lowercase()
        return when (ext) {
            "mp4" -> "video/mp4"
            "mkv" -> "video/x-matroska"
            "webm" -> "video/webm"
            "m4a" -> "audio/mp4"
            "mp3" -> "audio/mpeg"
            "opus" -> "audio/opus"
            "ogg" -> "audio/ogg"
            "wav" -> "audio/wav"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "webp" -> "image/webp"
            "srt" -> "application/x-subrip"
            "vtt" -> "text/vtt"
            else -> "application/octet-stream"
        }
    }
}
