package com.personalvault.myvault

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Seals and unseals a secret with an AES-256-GCM key that lives in the Android Keystore and
 * can only be used after a successful STRONG biometric authentication (BiometricPrompt with a
 * CryptoObject). The key is invalidated when fingerprints are added or removed, so a newly
 * enrolled finger can never unlock the vault.
 *
 * Error codes returned to Dart: NOT_AVAILABLE, CANCELLED, KEY_INVALIDATED, LOCKED_OUT, ERROR.
 */
class BiometricKeyChannel(
    private val activity: FragmentActivity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "myvault/biometric_key"
        private const val KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "myvault_biometric_vek_key"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val TAG_BITS = 128
    }

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(isAvailable())
            "seal" -> seal(call, result)
            "unseal" -> unseal(call, result)
            "deleteKey" -> {
                deleteKey()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun isAvailable(): Boolean =
        BiometricManager.from(activity).canAuthenticate(BIOMETRIC_STRONG) ==
            BiometricManager.BIOMETRIC_SUCCESS

    /** Creates a fresh key (replacing any old one) and encrypts the secret after authentication. */
    private fun seal(call: MethodCall, result: MethodChannel.Result) {
        if (!isAvailable()) return result.error("NOT_AVAILABLE", "Strong biometrics unavailable", null)
        val secret = call.argument<ByteArray>("secret")
            ?: return result.error("ERROR", "Missing secret", null)

        val cipher = try {
            deleteKey()
            Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, createKey()) }
        } catch (e: Exception) {
            return result.error("ERROR", e.message, null)
        }

        authenticate(call, cipher, result) { authed ->
            val ciphertext = authed.doFinal(secret)
            mapOf("iv" to authed.iv, "ciphertext" to ciphertext)
        }
    }

    /** Decrypts a previously sealed secret after authentication. */
    private fun unseal(call: MethodCall, result: MethodChannel.Result) {
        if (!isAvailable()) return result.error("NOT_AVAILABLE", "Strong biometrics unavailable", null)
        val iv = call.argument<ByteArray>("iv")
        val ciphertext = call.argument<ByteArray>("ciphertext")
        if (iv == null || ciphertext == null) return result.error("ERROR", "Missing sealed data", null)

        val cipher = try {
            val key = loadKey() ?: return result.error("KEY_INVALIDATED", "Biometric key missing", null)
            Cipher.getInstance(TRANSFORMATION).apply {
                init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_BITS, iv))
            }
        } catch (e: KeyPermanentlyInvalidatedException) {
            deleteKey()
            return result.error("KEY_INVALIDATED", "Biometric enrollment changed", null)
        } catch (e: Exception) {
            return result.error("ERROR", e.message, null)
        }

        authenticate(call, cipher, result) { authed -> authed.doFinal(ciphertext) }
    }

    private fun authenticate(
        call: MethodCall,
        cipher: Cipher,
        result: MethodChannel.Result,
        onAuthenticated: (Cipher) -> Any,
    ) {
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(call.argument<String>("title") ?: "Unlock MyVault")
            .setSubtitle(call.argument<String>("subtitle") ?: "Confirm your fingerprint")
            .setNegativeButtonText(call.argument<String>("cancel") ?: "Use master password")
            .setAllowedAuthenticators(BIOMETRIC_STRONG)
            .setConfirmationRequired(false)
            .build()

        var replied = false
        fun reply(block: () -> Unit) {
            if (!replied) {
                replied = true
                block()
            }
        }

        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(res: BiometricPrompt.AuthenticationResult) {
                    val authed = res.cryptoObject?.cipher
                        ?: return reply { result.error("ERROR", "No cipher after authentication", null) }
                    try {
                        val value = onAuthenticated(authed)
                        reply { result.success(value) }
                    } catch (e: Exception) {
                        reply { result.error("ERROR", e.message, null) }
                    }
                }

                override fun onAuthenticationError(code: Int, message: CharSequence) {
                    val mapped = when (code) {
                        BiometricPrompt.ERROR_LOCKOUT,
                        BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> "LOCKED_OUT"
                        BiometricPrompt.ERROR_NO_BIOMETRICS,
                        BiometricPrompt.ERROR_HW_NOT_PRESENT,
                        BiometricPrompt.ERROR_HW_UNAVAILABLE -> "NOT_AVAILABLE"
                        else -> "CANCELLED"
                    }
                    reply { result.error(mapped, message.toString(), null) }
                }
                // onAuthenticationFailed (unrecognised finger) is non-terminal: the prompt stays open.
            },
        )
        prompt.authenticate(promptInfo, BiometricPrompt.CryptoObject(cipher))
    }

    private fun createKey(): SecretKey {
        val builder = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Every use needs a fresh strong-biometric authentication.
            builder.setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
        }

        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).run {
            init(builder.build())
            generateKey()
        }
    }

    private fun loadKey(): SecretKey? {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        return keyStore.getKey(KEY_ALIAS, null) as SecretKey?
    }

    private fun deleteKey() {
        try {
            val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
            if (keyStore.containsAlias(KEY_ALIAS)) keyStore.deleteEntry(KEY_ALIAS)
        } catch (_: Exception) {
        }
    }
}
