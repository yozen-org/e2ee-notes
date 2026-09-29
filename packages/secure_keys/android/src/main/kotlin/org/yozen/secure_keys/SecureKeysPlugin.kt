package org.yozen.secure_keys

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.math.BigInteger
import java.security.AlgorithmParameters
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.ECParameterSpec
import java.security.spec.ECPoint
import java.security.spec.ECPublicKeySpec
import java.util.UUID
import javax.crypto.KeyAgreement
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory

private const val TAG = "secure_keys"
private const val suite = "P256-HKDF-SHA256-AES256GCM"

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
            "capabilities" -> result.success(
                mapOf(
                    "available" to true,
                    "hardwareBacked" to isHardwareBacked(),
                    "provider" to "Android Keystore",
                )
            )
            "createRecipientKey" -> result.success(createRecipientKey())
            "openRecipientKey" -> {
                try {
                    result.success(openRecipientKey(call.arguments as ByteArray))
                } catch (error: Exception) {
                    Log.e(TAG, "openRecipientKey failed", error)
                    result.error("keystore_error", error.message, null)
                }
            }
            "sharedSecret" -> {
                try {
                    @Suppress("UNCHECKED_CAST")
                    result.success(sharedSecret(call.arguments as Map<String, Any>))
                } catch (error: Exception) {
                    Log.e(TAG, "sharedSecret failed", error)
                    result.error("keystore_error", error.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun createRecipientKey(): Map<String, Any> {
        val alias = "recipient-${UUID.randomUUID()}"
        val keyPair = generateP256KeyPair(alias)
        return mapOf(
            "keyHandle" to alias.toByteArray(Charsets.UTF_8),
            "publicKey" to publicDocument(x963Encode(keyPair.public as ECPublicKey)),
        )
    }

    private fun openRecipientKey(handle: ByteArray): Map<String, Any> {
        val alias = String(handle, Charsets.UTF_8)
        val publicKey = keyStore.getCertificate(alias)?.publicKey as? ECPublicKey
            ?: throw IllegalStateException("Recipient key not found in Android Keystore")
        return publicDocument(x963Encode(publicKey))
    }

    private fun sharedSecret(record: Map<String, Any>): ByteArray {
        val alias = String(record["keyHandle"] as ByteArray, Charsets.UTF_8)
        val peerPublicKey = record["peerPublicKey"] as ByteArray
        val privateKey = keyStore.getKey(alias, null) as? PrivateKey
            ?: throw IllegalStateException("Recipient key not found in Android Keystore")
        val agreement = KeyAgreement.getInstance("ECDH")
        agreement.init(privateKey)
        agreement.doPhase(decodeX963(peerPublicKey), true)
        return agreement.generateSecret().toFixedLength(32)
    }

    private fun generateP256KeyPair(alias: String): KeyPair {
        val generator =
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                generator.initialize(p256Spec(alias, strongBox = true))
                return generator.generateKeyPair()
            } catch (_: Exception) {
                // StrongBox unavailable; fall back to the TEE-backed Keystore.
            }
        }
        generator.initialize(p256Spec(alias, strongBox = false))
        return generator.generateKeyPair()
    }

    private fun p256Spec(alias: String, strongBox: Boolean): KeyGenParameterSpec {
        val builder = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_AGREE_KEY)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
        if (strongBox) {
            builder.setIsStrongBoxBacked(true)
        }
        return builder.build()
    }

    private fun publicDocument(encoded: ByteArray): Map<String, Any> = mapOf(
        "version" to 1,
        "suite" to suite,
        "keyID" to keyID(encoded),
        "publicKey" to Base64.encodeToString(encoded, Base64.NO_WRAP),
    )

    private fun x963Encode(publicKey: ECPublicKey): ByteArray {
        val w = publicKey.w
        return byteArrayOf(0x04) +
            w.affineX.toByteArray().toFixedLength(32) +
            w.affineY.toByteArray().toFixedLength(32)
    }

    private fun decodeX963(encoded: ByteArray): ECPublicKey {
        require(encoded.size == 65 && encoded[0] == 0x04.toByte()) {
            "Invalid X9.63 public key"
        }
        val x = BigInteger(1, encoded.copyOfRange(1, 33))
        val y = BigInteger(1, encoded.copyOfRange(33, 65))
        val params = AlgorithmParameters.getInstance("EC")
        params.init(ECGenParameterSpec("secp256r1"))
        val spec = params.getParameterSpec(ECParameterSpec::class.java)
        val factory = KeyFactory.getInstance("EC")
        return factory.generatePublic(ECPublicKeySpec(ECPoint(x, y), spec)) as ECPublicKey
    }

    private fun keyID(publicKey: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(publicKey)
            .joinToString("") { "%02x".format(it) }

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

    private fun ByteArray.toFixedLength(length: Int): ByteArray {
        if (size >= length) return copyOfRange(size - length, size)
        val padded = ByteArray(length)
        copyInto(padded, length - size)
        return padded
    }
}
