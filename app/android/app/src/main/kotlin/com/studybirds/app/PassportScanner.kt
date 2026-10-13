package com.studybirds.app

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.math.max

object PassportScanner {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    fun register(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        MethodChannel(messenger, "studybirds/passport_scan").setMethodCallHandler { call, result ->
            if (call.method != "recognize") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val bytes = call.argument<ByteArray>("bytes")
            if (bytes == null || bytes.isEmpty() || bytes.size > 10 * 1024 * 1024) {
                result.error("invalid_file", "Invalid file size", null)
                return@setMethodCallHandler
            }
            worker.execute {
                try {
                    val text = recognize(app, bytes)
                    main.post { result.success(text) }
                } catch (_: Exception) {
                    // Never log passport contents or identifiers.
                    main.post { result.error("scan_failed", "Unable to read document", null) }
                }
            }
        }
    }

    private fun recognize(context: Context, bytes: ByteArray): List<String> {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        val output = mutableListOf<String>()
        fun scan(bitmap: Bitmap) {
            try {
                // Handle sideways/upside-down images, including EXIF orientation.
                for (rotation in listOf(0, 90, 180, 270)) {
                    val text = Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, rotation)), 20, TimeUnit.SECONDS)
                    output.add(text.textBlocks.flatMap { it.lines }.joinToString("\n") { it.text })
                }
            } finally {
                bitmap.recycle()
            }
        }
        try {
            val pdf = bytes.size >= 5 && String(bytes, 0, 5, Charsets.US_ASCII) == "%PDF-"
            if (pdf) {
                val file = File.createTempFile("passport_scan_", ".pdf", context.cacheDir)
                try {
                    file.writeBytes(bytes)
                    ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
                        PdfRenderer(descriptor).use { renderer ->
                            for (index in 0 until minOf(renderer.pageCount, 3)) {
                                renderer.openPage(index).use { page ->
                                    val scale = 2200.0 / max(page.width, page.height)
                                    val bitmap = Bitmap.createBitmap(max(1, (page.width * scale).toInt()), max(1, (page.height * scale).toInt()), Bitmap.Config.ARGB_8888)
                                    bitmap.eraseColor(Color.WHITE)
                                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                                    scan(bitmap)
                                }
                            }
                        }
                    }
                } finally { file.delete() }
            } else {
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                require(bounds.outWidth > 0 && bounds.outHeight > 0)
                var sample = 1
                while (max(bounds.outWidth, bounds.outHeight) / sample > 3000) sample *= 2
                val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size,
                    BitmapFactory.Options().apply { inSampleSize = sample }) ?: error("Invalid image")
                scan(bitmap)
            }
            return output
        } finally { recognizer.close() }
    }
}
