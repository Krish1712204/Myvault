package com.personalvault.myvault

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Renders the first page of a PDF to a small JPEG for the document grid, using Android's
 * built-in PdfRenderer. PdfRenderer needs a seekable file, so the decrypted bytes are written
 * to a private temp file that is deleted as soon as the page is rendered. Work runs off the
 * main thread. Returns null for anything that cannot be rendered (e.g. password-protected PDFs).
 */
class PdfThumbnailChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "myvault/pdf_thumbnail"
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "renderFirstPage") return result.notImplemented()
        val bytes = call.argument<ByteArray>("bytes")
            ?: return result.error("ERROR", "Missing bytes", null)
        val width = call.argument<Int>("width") ?: 360

        Thread {
            val image = try {
                render(bytes, width)
            } catch (_: Throwable) {
                null
            }
            mainHandler.post { result.success(image) }
        }.start()
    }

    private fun render(bytes: ByteArray, width: Int): ByteArray? {
        val tmp = File.createTempFile("thumb", ".pdf", context.cacheDir)
        try {
            tmp.writeBytes(bytes)
            ParcelFileDescriptor.open(tmp, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                PdfRenderer(fd).use { renderer ->
                    if (renderer.pageCount == 0) return null
                    renderer.openPage(0).use { page ->
                        val height = (width.toFloat() * page.height / page.width).toInt().coerceIn(1, width * 2)
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        val out = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
                        bitmap.recycle()
                        return out.toByteArray()
                    }
                }
            }
        } finally {
            tmp.delete()
        }
    }
}
