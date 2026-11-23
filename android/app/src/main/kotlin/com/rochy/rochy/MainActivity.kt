package com.rochy.rochy

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.media.MediaMuxer
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val MEDIA_CHANNEL = "com.rochy.rochy/media_processor"
    }

    private val mediaExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "cropAndCompressImage" -> handleCropAndCompressImage(call, result)
                    "extractVideoInfoAndThumbnails" -> handleExtractVideoInfo(call, result)
                    "trimAndOptimizeVideo" -> handleTrimVideo(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleCropAndCompressImage(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val outputPath = call.argument<String>("outputPath")
        if (sourcePath.isNullOrBlank() || outputPath.isNullOrBlank()) {
            result.error("INVALID_ARGS", "Faltan rutas de imagen.", null)
            return
        }
        val cropLeft = (call.argument<Number>("cropLeft")?.toDouble() ?: 0.0).coerceIn(0.0, 0.99)
        val cropTop = (call.argument<Number>("cropTop")?.toDouble() ?: 0.0).coerceIn(0.0, 0.99)
        val cropWidth = (call.argument<Number>("cropWidth")?.toDouble() ?: 1.0).coerceIn(0.02, 1.0)
        val cropHeight = (call.argument<Number>("cropHeight")?.toDouble() ?: 1.0).coerceIn(0.02, 1.0)
        val rotationDegrees = call.argument<Number>("rotationDegrees")?.toInt() ?: 0
        val maxDimension = (call.argument<Number>("maxDimension")?.toInt() ?: 1280).coerceIn(240, 2560)
        val quality = (call.argument<Number>("quality")?.toInt() ?: 78).coerceIn(40, 95)

        mediaExecutor.execute {
            try {
                val srcFile = File(sourcePath)
                if (!srcFile.exists()) {
                    runOnUiThread { result.error("NOT_FOUND", "No existe la imagen.", null) }
                    return@execute
                }

                val exifRotation = readExifRotationDegrees(sourcePath)
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(sourcePath, bounds)

                var sampleSize = 1
                val maxRaw = max(bounds.outWidth, bounds.outHeight)
                while (maxRaw / sampleSize > 2560) {
                    sampleSize *= 2
                }

                val decodeOpts = BitmapFactory.Options().apply {
                    inSampleSize = sampleSize
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                }
                var decoded = BitmapFactory.decodeFile(sourcePath, decodeOpts)
                if (decoded == null) {
                    runOnUiThread { result.error("DECODE_ERR", "No se pudo leer la imagen.", null) }
                    return@execute
                }

                val totalRotation = ((exifRotation + rotationDegrees) % 360 + 360) % 360
                if (totalRotation != 0) {
                    val matrix = Matrix().apply { postRotate(totalRotation.toFloat()) }
                    val rotated = Bitmap.createBitmap(
                        decoded,
                        0,
                        0,
                        decoded.width,
                        decoded.height,
                        matrix,
                        true
                    )
                    if (rotated != decoded) {
                        decoded.recycle()
                        decoded = rotated
                    }
                }

                val imgW = decoded.width
                val imgH = decoded.height
                val x = (cropLeft * imgW).roundToInt().coerceIn(0, max(0, imgW - 2))
                val y = (cropTop * imgH).roundToInt().coerceIn(0, max(0, imgH - 2))
                val w = (cropWidth * imgW).roundToInt().coerceIn(2, imgW - x)
                val h = (cropHeight * imgH).roundToInt().coerceIn(2, imgH - y)

                var cropped = if (x == 0 && y == 0 && w == imgW && h == imgH) {
                    decoded
                } else {
                    val sub = Bitmap.createBitmap(decoded, x, y, w, h)
                    if (sub != decoded) decoded.recycle()
                    sub
                }

                val curMax = max(cropped.width, cropped.height)
                if (curMax > maxDimension) {
                    val scale = maxDimension.toDouble() / curMax.toDouble()
                    val targetW = max(1, (cropped.width * scale).roundToInt())
                    val targetH = max(1, (cropped.height * scale).roundToInt())
                    val scaled = Bitmap.createScaledBitmap(cropped, targetW, targetH, true)
                    if (scaled != cropped) cropped.recycle()
                    cropped = scaled
                }

                val outFile = File(outputPath)
                outFile.parentFile?.mkdirs()
                FileOutputStream(outFile).use { out ->
                    cropped.compress(Bitmap.CompressFormat.JPEG, quality, out)
                    out.flush()
                }

                val finalW = cropped.width
                val finalH = cropped.height
                cropped.recycle()

                val payload = hashMapOf<String, Any>(
                    "path" to outFile.absolutePath,
                    "width" to finalW,
                    "height" to finalH,
                    "sizeBytes" to outFile.length()
                )
                runOnUiThread { result.success(payload) }
            } catch (e: Exception) {
                runOnUiThread { result.error("IMG_ERR", e.message, null) }
            }
        }
    }

    private fun readExifRotationDegrees(path: String): Int {
        return try {
            val exif = ExifInterface(path)
            when (exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL
            )) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90
                ExifInterface.ORIENTATION_ROTATE_180 -> 180
                ExifInterface.ORIENTATION_ROTATE_270 -> 270
                else -> 0
            }
        } catch (_: Exception) {
            0
        }
    }

    private fun handleExtractVideoInfo(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val outputDir = call.argument<String>("outputDir")
        val frameCount = (call.argument<Number>("frameCount")?.toInt() ?: 8).coerceIn(2, 16)
        if (sourcePath.isNullOrBlank() || outputDir.isNullOrBlank()) {
            result.error("INVALID_ARGS", "Faltan argumentos de video.", null)
            return
        }

        mediaExecutor.execute {
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(sourcePath)
                val durationMs = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_DURATION
                )?.toLongOrNull() ?: 0L
                val rawW = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH
                )?.toIntOrNull() ?: 0
                val rawH = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT
                )?.toIntOrNull() ?: 0
                val rot = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION
                )?.toIntOrNull() ?: 0

                val effW = if (rot == 90 || rot == 270) rawH else rawW
                val effH = if (rot == 90 || rot == 270) rawW else rawH

                val outDirFile = File(outputDir)
                outDirFile.mkdirs()
                val stamp = System.currentTimeMillis()
                val thumbs = ArrayList<String>()

                if (durationMs > 0) {
                    for (i in 0 until frameCount) {
                        val ratio = if (frameCount == 1) 0.0 else i.toDouble() / (frameCount - 1)
                        val timeUs = (durationMs * 1000L * ratio).toLong()
                            .coerceIn(0L, max(0L, (durationMs - 40L) * 1000L))
                        val frame = retriever.getFrameAtTime(
                            timeUs,
                            MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                        ) ?: continue
                        val thumbFile = File(outDirFile, "vthumb_${stamp}_$i.jpg")
                        saveScaledBitmap(frame, 130, 72, thumbFile)
                        frame.recycle()
                        thumbs.add(thumbFile.absolutePath)
                    }
                }

                val payload = hashMapOf<String, Any>(
                    "durationMs" to durationMs,
                    "width" to effW,
                    "height" to effH,
                    "thumbnails" to thumbs
                )
                runOnUiThread { result.success(payload) }
            } catch (e: Exception) {
                runOnUiThread { result.error("VID_INFO_ERR", e.message, null) }
            } finally {
                try {
                    retriever.release()
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun handleTrimVideo(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        val outputPath = call.argument<String>("outputPath")
        val thumbnailOutputPath = call.argument<String>("thumbnailOutputPath")
        val rawStartMs = (call.argument<Number>("startMs")?.toLong() ?: 0L).coerceAtLeast(0L)
        val rawEndMs = (call.argument<Number>("endMs")?.toLong() ?: 30000L)

        if (sourcePath.isNullOrBlank() || outputPath.isNullOrBlank()) {
            result.error("INVALID_ARGS", "Faltan rutas de recorte.", null)
            return
        }

        mediaExecutor.execute {
            val retriever = MediaMetadataRetriever()
            var muxer: MediaMuxer? = null
            var muxerStarted = false
            val extractor = MediaExtractor()
            try {
                retriever.setDataSource(sourcePath)
                val totalMs = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_DURATION
                )?.toLongOrNull() ?: rawEndMs
                val rotation = retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION
                )?.toIntOrNull() ?: 0

                val safeStartMs = rawStartMs.coerceIn(0L, max(0L, totalMs - 500L))
                val maxEndMs = min(totalMs, safeStartMs + 30000L)
                val safeEndMs = rawEndMs.coerceIn(safeStartMs + 500L, max(safeStartMs + 500L, maxEndMs))

                if (!thumbnailOutputPath.isNullOrBlank()) {
                    val frame = retriever.getFrameAtTime(
                        safeStartMs * 1000L,
                        MediaMetadataRetriever.OPTION_CLOSEST_SYNC
                    ) ?: retriever.getFrameAtTime(0L)
                    if (frame != null) {
                        val thumbFile = File(thumbnailOutputPath)
                        thumbFile.parentFile?.mkdirs()
                        saveScaledBitmap(frame, 720, 80, thumbFile)
                        frame.recycle()
                    }
                }

                val outFile = File(outputPath)
                outFile.parentFile?.mkdirs()
                if (outFile.exists()) outFile.delete()

                extractor.setDataSource(sourcePath)
                val trackCount = extractor.trackCount
                muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                if (rotation != 0) {
                    muxer.setOrientationHint(rotation)
                }

                val indexMap = LinkedHashMap<Int, Int>()
                var videoSrcTrack = -1
                var maxBufferSize = 1024 * 1024
                for (i in 0 until trackCount) {
                    val format = extractor.getTrackFormat(i)
                    val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                    if (mime.startsWith("video/") || mime.startsWith("audio/")) {
                        val dstIndex = muxer.addTrack(format)
                        indexMap[i] = dstIndex
                        if (mime.startsWith("video/") && videoSrcTrack < 0) {
                            videoSrcTrack = i
                        }
                        if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                            maxBufferSize = max(
                                maxBufferSize,
                                format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                            )
                        }
                    }
                }

                if (indexMap.isEmpty()) {
                    throw IllegalStateException("No se encontraron pistas compatibles.")
                }

                muxer.start()
                muxerStarted = true

                val buffer = ByteBuffer.allocate(maxBufferSize)
                val bufferInfo = MediaCodec.BufferInfo()
                val startUs = safeStartMs * 1000L
                val endUs = safeEndMs * 1000L
                var sharedAnchorUs = -1L

                val orderedTracks = ArrayList<Pair<Int, Int>>()
                if (videoSrcTrack >= 0 && indexMap.containsKey(videoSrcTrack)) {
                    orderedTracks.add(videoSrcTrack to indexMap[videoSrcTrack]!!)
                }
                for ((srcTrack, dstTrack) in indexMap) {
                    if (srcTrack != videoSrcTrack) {
                        orderedTracks.add(srcTrack to dstTrack)
                    }
                }

                for ((srcTrack, dstTrack) in orderedTracks) {
                    extractor.selectTrack(srcTrack)
                    val seekTarget = if (sharedAnchorUs >= 0L) sharedAnchorUs else startUs
                    extractor.seekTo(seekTarget, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

                    while (true) {
                        bufferInfo.offset = 0
                        bufferInfo.size = extractor.readSampleData(buffer, 0)
                        if (bufferInfo.size < 0) {
                            bufferInfo.size = 0
                            break
                        }
                        val sampleTimeUs = extractor.sampleTime
                        if (sampleTimeUs < 0L || sampleTimeUs > endUs) {
                            break
                        }
                        if (sharedAnchorUs < 0L) {
                            sharedAnchorUs = sampleTimeUs
                        }
                        if (sampleTimeUs < sharedAnchorUs) {
                            if (!extractor.advance()) break
                            continue
                        }
                        bufferInfo.presentationTimeUs = max(0L, sampleTimeUs - sharedAnchorUs)
                        bufferInfo.flags = extractor.sampleFlags
                        muxer.writeSampleData(dstTrack, buffer, bufferInfo)
                        if (!extractor.advance()) {
                            break
                        }
                    }
                    extractor.unselectTrack(srcTrack)
                }

                muxer.stop()
                muxer.release()
                muxer = null
                muxerStarted = false

                val durationSec = max(1, ((safeEndMs - safeStartMs) / 1000.0).roundToInt())
                val payload = hashMapOf<String, Any>(
                    "videoPath" to outFile.absolutePath,
                    "thumbnailPath" to (thumbnailOutputPath ?: ""),
                    "durationSeconds" to durationSec,
                    "sizeBytes" to outFile.length()
                )
                runOnUiThread { result.success(payload) }
            } catch (e: Exception) {
                try {
                    if (muxerStarted) muxer?.stop()
                } catch (_: Exception) {
                }
                try {
                    muxer?.release()
                } catch (_: Exception) {
                }
                runOnUiThread { result.error("TRIM_ERR", e.message, null) }
            } finally {
                try {
                    extractor.release()
                } catch (_: Exception) {
                }
                try {
                    retriever.release()
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun saveScaledBitmap(
        src: Bitmap,
        maxDimension: Int,
        quality: Int,
        outFile: File
    ) {
        val curMax = max(src.width, src.height)
        val toSave = if (curMax > maxDimension && curMax > 0) {
            val scale = maxDimension.toDouble() / curMax.toDouble()
            val w = max(1, (src.width * scale).roundToInt())
            val h = max(1, (src.height * scale).roundToInt())
            Bitmap.createScaledBitmap(src, w, h, true)
        } else {
            src
        }
        try {
            FileOutputStream(outFile).use { out ->
                toSave.compress(Bitmap.CompressFormat.JPEG, quality, out)
                out.flush()
            }
        } finally {
            if (toSave != src) {
                toSave.recycle()
            }
        }
    }
}
