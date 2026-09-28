package org.yozen.secure_keys

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec

private const val TAG = "secure_keys"

class SecureKeysPlugin :
    FlutterPlugin,
    MethodCallHandler {

    private lateinit var channel: MethodChannel
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    @Volatile
    private var hardwareBacked: Boolean? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "secure_keys")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            "keystoreIsAvailable" -> result.success(isHardwareBacked())
            "keystoreProtect" -> {
                try {
                    result.success(protect(call.arguments as ByteArray))
                } catch (error: Exception) {
                    Log.e(TAG, "keystoreProtect failed", error)
                    result.error("keystore_error", error.message, null)
                }
            }
            "keystoreUnprotect" -> {
                try {
                    @Suppress("UNCHECKED_CAST")
                    result.success(unprotect(call.arguments as Map<String, Any>))
                } catch (error: Exception) {
                    Log.e(TAG, "keystoreUnprotect failed", error)
                    result.error("keystore_error", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun protect(vaultKey: ByteArray): Map<String, Any> {
        val alias = "vault-${UUID.randomUUID()}"
        val key = generateAesKey(alias)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key)
        val ciphertext = cipher.doFinal(vaultKey)
        return mapOf(
            "alias" to alias,
            "iv" to cipher.iv,
            "ciphertext" to ciphertext,
        )
    }

    private fun unprotect(record: Map<String, Any>): ByteArray {
        val alias = record["alias"] as String
        val iv = record["iv"] as ByteArray
        val ciphertext = record["ciphertext"] as ByteArray
        val key = keyStore.getKey(alias, null) as? SecretKey
            ?: throw IllegalStateException("Vault key not found in Android Keystore")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, iv))
        return cipher.doFinal(ciphertext)
    }

    private fun isHardwareBacked(): Boolean {
        hardwareBacked?.let { return it }
        val value = try {
            val alias = "probe-${UUID.randomUUID()}"
            val key = generateAesKey(alias)
            val factory = SecretKeyFactory.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                "AndroidKeyStore"
            )
            val keyInfo = factory.getKeySpec(key, KeyInfo::class.java) as KeyInfo
            val backed = keyInfo.isInsideSecureHardware
            keyStore.deleteEntry(alias)
            backed
        } catch (error: Exception) {
            Log.e(TAG, "hardware probe failed", error)
            false
        }
        hardwareBacked = value
        return value
    }

    private fun generateAesKey(alias: String): SecretKey {
        val generator =
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                generator.init(newAesSpec(alias, strongBox = true))
                return generator.generateKey()
            } catch (_: Exception) {
                // StrongBox unavailable; fall back to the TEE-backed Keystore.
            }
        }
        generator.init(newAesSpec(alias, strongBox = false))
        return generator.generateKey()
    }

    private fun newAesSpec(alias: String, strongBox: Boolean): KeyGenParameterSpec {
        val builder = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
        if (strongBox) {
            builder.setIsStrongBoxBacked(true)
        }
        return builder.build()
    }
}
