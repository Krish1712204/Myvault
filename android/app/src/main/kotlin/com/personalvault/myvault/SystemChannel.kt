package com.personalvault.myvault

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import android.os.SystemClock
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Small platform helpers Flutter does not expose:
 *  - copySensitive: puts text on the clipboard flagged as sensitive, so Android 13+ hides it
 *    in the "copied" preview and keyboards (e.g. Gboard) keep it out of clipboard history.
 *  - clearClipboard: empties the clipboard (clearPrimaryClip on Android 9+).
 *  - monotonicClock: time since boot plus the boot count, which, unlike the wall clock,
 *    cannot be changed from Settings (used for wrong-password delays).
 */
class SystemChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "myvault/system"
        // ClipDescription.EXTRA_IS_SENSITIVE is API 33; this key is what it resolves to and what
        // keyboards look for on older versions too.
        private const val EXTRA_IS_SENSITIVE = "android.content.extra.IS_SENSITIVE"
    }

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    private val clipboard: ClipboardManager
        get() = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "copySensitive" -> {
                    val text = call.argument<String>("text") ?: return result.error("ERROR", "Missing text", null)
                    val clip = ClipData.newPlainText(call.argument<String>("label") ?: "MyVault", text)
                    clip.description.extras = PersistableBundle().apply {
                        putBoolean(
                            if (Build.VERSION.SDK_INT >= 33) ClipDescription.EXTRA_IS_SENSITIVE else EXTRA_IS_SENSITIVE,
                            true,
                        )
                    }
                    clipboard.setPrimaryClip(clip)
                    result.success(null)
                }
                "clearClipboard" -> {
                    if (Build.VERSION.SDK_INT >= 28) {
                        clipboard.clearPrimaryClip()
                    } else {
                        clipboard.setPrimaryClip(ClipData.newPlainText("", ""))
                    }
                    result.success(null)
                }
                "monotonicClock" -> result.success(
                    mapOf(
                        "elapsedMs" to SystemClock.elapsedRealtime(),
                        "bootCount" to Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1),
                    ),
                )
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }
}
