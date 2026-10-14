package com.studybirds.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import androidx.exifinterface.media.ExifInterface
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.*

object PassportScanner {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val recognizer by lazy { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }
    private val cv by lazy { OpenCVLoader.initLocal() }

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        val channel = MethodChannel(messenger, "studybirds/passport_scan")
        channel.setMethodCallHandler { call, result ->
            if (call.method !in listOf("recognize", "inspect", "analyzeFrame")) {
                result.notImplemented(); return@setMethodCallHandler
            }
            worker.execute {
                try {
                    check(cv)
                    val limits = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val output: Any = if (call.method == "analyzeFrame") {
                        val frame = frameBitmap(call)
                        try { analyze(frame, live = true, limits = limits) } finally { frame.recycle() }
                    } else {
                        val bytes = call.argument<ByteArray>("bytes") ?: error("Missing image")
                        require(bytes.isNotEmpty() && bytes.size <= 5 * 1024 * 1024)
                        val scans = inspect(app, bytes, limits) { stage, state ->
                            call.argument<Int>("scanId")?.let { id -> main.post {
                                channel.invokeMethod("scanProgress", mapOf("id" to id, "stage" to stage, "state" to state))
                            } }
                        }
                        if (call.method == "recognize") scans.map { it["text"] as String }
                        else scans.firstOrNull { hasTd3Shape(it["text"] as String) } ?: scans.first()
                    }
                    main.post { result.success(output) }
                } catch (_: Exception) {
                    // No images, identifiers, OCR text or exception payloads in logs.
                    main.post { result.error("scan_failed", "Unable to process document", null) }
                }
            }
        }
    }

    private fun frameBitmap(call: MethodCall): Bitmap {
        val bytes = call.argument<ByteArray>("bytes") ?: error("Missing frame")
        val w = call.argument<Int>("width") ?: error("Missing width")
        val h = call.argument<Int>("height") ?: error("Missing height")
        val stride = call.argument<Int>("rowStride") ?: w
        val pixelStride = call.argument<Int>("pixelStride") ?: 1
        require(w in 1..4096 && h in 1..4096 && stride > 0)
        val step = max(1, ceil(max(w, h) / 1280.0).toInt())
        val ow = w / step; val oh = h / step
        val pixels = IntArray(ow * oh)
        for (y in 0 until oh) for (x in 0 until ow) {
            val index = y * step * stride + x * step * pixelStride
            require(index < bytes.size)
            val v = bytes[index].toInt() and 255
            pixels[y * ow + x] = Color.rgb(v, v, v)
        }
        val raw = Bitmap.createBitmap(pixels, ow, oh, Bitmap.Config.ARGB_8888)
        val rotation = call.argument<Int>("rotation") ?: 0
        if (rotation == 0) return raw
        val upright = Bitmap.createBitmap(raw, 0, 0, ow, oh, Matrix().apply { postRotate(rotation.toFloat()) }, true)
        if (upright !== raw) raw.recycle()
        return upright
    }

    private fun inspect(context: Context, bytes: ByteArray, limits: Map<*, *>, progress: (String, String) -> Unit): List<Map<String, Any?>> {
        val output = mutableListOf<Map<String, Any?>>()
        fun scan(bitmap: Bitmap) {
            try {
                for (rotation in listOf(0, 90, 180, 270)) {
                    val upright = if (rotation == 0) bitmap else Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height,
                        Matrix().apply { postRotate(rotation.toFloat()) }, true)
                    try {
                        val data = analyze(upright, live = false, limits = limits, progress = progress)
                        output.add(data)
                        if (hasTd3Shape(data["text"] as String)) break
                    } finally { if (upright !== bitmap) upright.recycle() }
                }
            } finally { bitmap.recycle() }
        }
        if (bytes.size >= 5 && String(bytes, 0, 5, Charsets.US_ASCII) == "%PDF-") {
            val file = File.createTempFile("passport_scan_", ".pdf", context.cacheDir)
            try {
                file.writeBytes(bytes)
                ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                    PdfRenderer(fd).use { renderer ->
                        for (i in 0 until minOf(renderer.pageCount, 3)) renderer.openPage(i).use { page ->
                            val scale = 2200.0 / max(page.width, page.height)
                            val bitmap = Bitmap.createBitmap(max(1, (page.width * scale).toInt()), max(1, (page.height * scale).toInt()), Bitmap.Config.ARGB_8888)
                            bitmap.eraseColor(Color.WHITE)
                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            scan(bitmap)
                        }
                    }
                }
            } finally { file.delete() }
        } else {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            require(bounds.outWidth > 0 && bounds.outHeight > 0)
            var sample = 1
            while (max(bounds.outWidth, bounds.outHeight) / sample > 2400) sample *= 2
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample }) ?: error("Invalid image")
            val exif = ExifInterface(ByteArrayInputStream(bytes))
            val matrix = Matrix().apply {
                when (exif.getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                    ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> postScale(-1f, 1f)
                    ExifInterface.ORIENTATION_ROTATE_180 -> postRotate(180f)
                    ExifInterface.ORIENTATION_FLIP_VERTICAL -> postScale(1f, -1f)
                    ExifInterface.ORIENTATION_TRANSPOSE -> { postRotate(90f); postScale(-1f, 1f) }
                    ExifInterface.ORIENTATION_ROTATE_90 -> postRotate(90f)
                    ExifInterface.ORIENTATION_TRANSVERSE -> { postRotate(270f); postScale(-1f, 1f) }
                    ExifInterface.ORIENTATION_ROTATE_270 -> postRotate(270f)
                }
            }
            val upright = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            if (upright !== bitmap) bitmap.recycle()
            scan(upright)
        }
        require(output.isNotEmpty())
        return output
    }

    private fun hasTd3Shape(text: String): Boolean {
        val lines = text.uppercase().lines().map { it.replace(" ", "") }
        return lines.zipWithNext().any { (a, b) -> a.length == 44 && a.startsWith("P") && b.length == 44 }
    }

    private fun analyze(bitmap: Bitmap, live: Boolean, limits: Map<*, *>, progress: (String, String) -> Unit = { _, _ -> }): Map<String, Any?> {
        val owned = mutableListOf<Mat>()
        fun mat() = Mat().also { owned.add(it) }
        try {
            progress("document", "processing")
            val rgba = mat(); Utils.bitmapToMat(bitmap, rgba)
            val gray = mat(); Imgproc.cvtColor(rgba, gray, Imgproc.COLOR_RGBA2GRAY)
            val scale = min(1.0, 1000.0 / max(gray.cols(), gray.rows()))
            val small = mat(); Imgproc.resize(gray, small, Size(), scale, scale, Imgproc.INTER_AREA)
            val smooth = mat(); Imgproc.GaussianBlur(small, smooth, Size(5.0, 5.0), 0.0)
            val edges = mat(); Imgproc.Canny(smooth, edges, 50.0, 150.0)
            val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(3.0, 3.0)).also { owned.add(it) }
            Imgproc.morphologyEx(edges, edges, Imgproc.MORPH_CLOSE, kernel)
            val contours = mutableListOf<MatOfPoint>()
            val hierarchy = mat()
            Imgproc.findContours(edges, contours, hierarchy, Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_SIMPLE)
            var points: Array<Point>? = null; var bestArea = 0.0
            try {
                for (contour in contours) {
                    val area = Imgproc.contourArea(contour)
                    if (area < small.total() * .18 || area > small.total() * .98 || area <= bestArea) continue
                    val curve = MatOfPoint2f(*contour.toArray()); val approx = MatOfPoint2f()
                    try {
                        Imgproc.approxPolyDP(curve, approx, .025 * Imgproc.arcLength(curve, true), true)
                        if (approx.total() != 4L) continue
                        val convex = MatOfPoint(*approx.toArray())
                        try { if (!Imgproc.isContourConvex(convex)) continue } finally { convex.release() }
                        val p = order(approx.toArray())
                        val width = (distance(p[0], p[1]) + distance(p[3], p[2])) / 2
                        val height = (distance(p[0], p[3]) + distance(p[1], p[2])) / 2
                        if (height <= 0 || width / height !in 1.12..1.85) continue
                        if (p.any { it.x < 3 || it.y < 3 || it.x > small.cols() - 3 || it.y > small.rows() - 3 }) continue
                        points = p.map { Point(it.x / scale, it.y / scale) }.toTypedArray(); bestArea = area
                    } finally { curve.release(); approx.release() }
                }
            } finally { contours.forEach { it.release() } }
            var document = rgba
            progress("document", if (points != null) "passed" else "retry")
            progress("quality", "processing")
            val corners = points?.flatMap { listOf(it.x / rgba.cols(), it.y / rgba.rows()) } ?: emptyList()
            if (points != null) {
                val src = MatOfPoint2f(*points); val dst = MatOfPoint2f(Point(0.0, 0.0), Point(1199.0, 0.0), Point(1199.0, 843.0), Point(0.0, 843.0))
                try {
                    val transform = Imgproc.getPerspectiveTransform(src, dst).also { owned.add(it) }
                    document = mat(); Imgproc.warpPerspective(rgba, document, transform, Size(1200.0, 844.0))
                } finally { src.release(); dst.release() }
            }
            val docGray = mat(); Imgproc.cvtColor(document, docGray, Imgproc.COLOR_RGBA2GRAY)
            // Quality measured at a consistent scale, inside the document when found.
            val quality = mat(); Imgproc.resize(docGray, quality, Size(800.0, max(1.0, 800.0 * docGray.rows() / docGray.cols())))
            val lap = mat(); Imgproc.Laplacian(quality, lap, CvType.CV_64F)
            val mean = MatOfDouble(); val deviation = MatOfDouble()
            val sharpness: Double
            try { Core.meanStdDev(lap, mean, deviation); sharpness = deviation.toArray()[0].pow(2) }
            finally { mean.release(); deviation.release() }
            val glareMask = mat(); Imgproc.threshold(quality, glareMask, 245.0, 255.0, Imgproc.THRESH_BINARY)
            val glare = Core.countNonZero(glareMask) / quality.total().toDouble()
            val brightness = Core.mean(quality).`val`[0]
            val qualityPassed = sharpness >= ((limits["minSharpness"] as? Number)?.toDouble() ?: 65.0) &&
                glare <= ((limits["maxGlare"] as? Number)?.toDouble() ?: .18) &&
                brightness >= ((limits["minBrightness"] as? Number)?.toDouble() ?: 45.0) &&
                brightness <= ((limits["maxBrightness"] as? Number)?.toDouble() ?: 225.0)
            progress("quality", if (qualityPassed) "passed" else "retry")
            val output = mutableMapOf<String, Any?>("documentDetected" to (points != null), "corners" to corners,
                "sharpness" to sharpness, "glare" to glare, "brightness" to brightness, "text" to "", "confidence" to null, "ocrAttempted" to false)
            if (live && (points == null || !qualityPassed)) return output
            val ocrBitmap = Bitmap.createBitmap(document.cols(), document.rows(), Bitmap.Config.ARGB_8888)
            Utils.matToBitmap(document, ocrBitmap)
            try {
                progress("passport", "processing")
                progress("mrz", "processing")
                output["ocrAttempted"] = true
                val text = Tasks.await(recognizer.process(InputImage.fromBitmap(ocrBitmap, 0)), 8, TimeUnit.SECONDS)
                val lines = text.textBlocks.flatMap { it.lines }
                var recognized = lines.joinToString("\n") { it.text }
                val mrzLines = lines.filter { it.text.replace(" ", "").length >= 40 && it.text.contains('<') }
                var mrzInLowerRegion = mrzLines.size >= 2 && mrzLines.all { (it.boundingBox?.centerY() ?: 0) >= ocrBitmap.height * .55 }
                var confidence = mrzLines.takeIf { it.size >= 2 }?.minOf { it.confidence.toDouble() }
                if (!hasTd3Shape(recognized)) {
                    // Retry only the lower MRZ region, using local contrast enhancement.
                    val start = (docGray.rows() * .6).toInt()
                    val roi = docGray.submat(start, docGray.rows(), 0, docGray.cols()).also { owned.add(it) }
                    val enhanced = mat(); val clahe = Imgproc.createCLAHE(2.0, Size(8.0, 8.0))
                    try { clahe.apply(roi, enhanced) } finally { clahe.collectGarbage() }
                    val roiBitmap = Bitmap.createBitmap(enhanced.cols(), enhanced.rows(), Bitmap.Config.ARGB_8888)
                    try {
                        Utils.matToBitmap(enhanced, roiBitmap)
                        val retry = Tasks.await(recognizer.process(InputImage.fromBitmap(roiBitmap, 0)), 8, TimeUnit.SECONDS)
                        val retryLines = retry.textBlocks.flatMap { it.lines }
                        recognized += "\n" + retryLines.joinToString("\n") { it.text }
                        val retryMrz = retryLines.filter { it.text.replace(" ", "").length >= 40 && it.text.contains('<') }
                        if (retryMrz.size >= 2) {
                            confidence = retryMrz.minOf { it.confidence.toDouble() }
                            mrzInLowerRegion = hasTd3Shape(retryLines.joinToString("\n") { it.text })
                        }
                    } finally { roiBitmap.recycle() }
                }
                output["text"] = recognized; output["confidence"] = confidence
                output["mrzInLowerRegion"] = mrzInLowerRegion
                if (!live && hasTd3Shape(recognized)) {
                    val factor = min(1.0, 1400.0 / max(bitmap.width, bitmap.height))
                    val preview = Bitmap.createScaledBitmap(bitmap, max(1, (bitmap.width * factor).toInt()), max(1, (bitmap.height * factor).toInt()), true)
                    try {
                        val stream = ByteArrayOutputStream(); preview.compress(Bitmap.CompressFormat.JPEG, 90, stream)
                        output["originalPreviewBytes"] = stream.toByteArray()
                    } finally { if (preview !== bitmap) preview.recycle() }
                }
                if (!live && points != null && hasTd3Shape(recognized)) {
                    val stream = ByteArrayOutputStream(); ocrBitmap.compress(Bitmap.CompressFormat.JPEG, 94, stream)
                    output["correctedBytes"] = stream.toByteArray()
                }
            } finally { ocrBitmap.recycle() }
            return output
        } finally { owned.asReversed().forEach { it.release() } }
    }

    private fun distance(a: Point, b: Point) = hypot(a.x - b.x, a.y - b.y)
    private fun order(points: Array<Point>): Array<Point> {
        val center = Point(points.map { it.x }.average(), points.map { it.y }.average())
        val sorted = points.sortedBy { atan2(it.y - center.y, it.x - center.x) }
        val start = sorted.indices.minBy { sorted[it].x + sorted[it].y }
        return Array(4) { sorted[(start + it) % 4] }
    }
}
