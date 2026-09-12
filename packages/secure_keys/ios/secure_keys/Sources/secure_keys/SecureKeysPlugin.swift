import CryptoKit
import Flutter
import LocalAuthentication
import Security
import UIKit

private let suite = "P256-HKDF-SHA256-AES256GCM"
private let domain = Data("yozen.e2ee-notes.key-wrap.v1".utf8)

private enum HardwareKeyError: Error {
  case unavailable
  case invalidArguments
  case invalidKeyLength
  case invalidRecipient
  case recipientMismatch
  case accessControl
}

public class SecureKeysPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "secure_keys", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SecureKeysPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      switch call.method {
      case "capabilities":
        result([
          "available": SecureEnclave.isAvailable,
          "hardwareBacked": SecureEnclave.isAvailable,
          "provider": "Apple Secure Enclave",
        ])
      case "createRecipientKey":
        let arguments = try dictionary(call.arguments)
        let requireUserPresence = arguments["requireUserPresence"] as? Bool ?? false
        let key = try createKey(requireUserPresence: requireUserPresence)
        result([
          "keyHandle": FlutterStandardTypedData(bytes: key.dataRepresentation),
          "publicKey": publicDocument(key.publicKey),
        ])
      case "wrapVaultKey":
        let arguments = try dictionary(call.arguments)
        guard
          let secret = (arguments["vaultKey"] as? FlutterStandardTypedData)?.data,
          let recipient = arguments["recipient"] as? [String: Any]
        else { throw HardwareKeyError.invalidArguments }
        result(try wrap(secret: secret, recipient: recipient))
      case "unwrapVaultKey":
        let arguments = try dictionary(call.arguments)
        guard
          let handle = (arguments["keyHandle"] as? FlutterStandardTypedData)?.data,
          let envelope = arguments["envelope"] as? [String: Any]
        else { throw HardwareKeyError.invalidArguments }
        result(FlutterStandardTypedData(bytes: try unwrap(handle: handle, envelope: envelope)))
      default:
        result(FlutterMethodNotImplemented)
      }
    } catch {
      result(FlutterError(code: "hardware_key_error", message: String(describing: error), details: nil))
    }
  }
}

private func dictionary(_ value: Any?) throws -> [String: Any] {
  guard let result = value as? [String: Any] else { throw HardwareKeyError.invalidArguments }
  return result
}

private func createKey(requireUserPresence: Bool) throws -> SecureEnclave.P256.KeyAgreement.PrivateKey {
  guard SecureEnclave.isAvailable else { throw HardwareKeyError.unavailable }
  var flags: SecAccessControlCreateFlags = [.privateKeyUsage]
  if requireUserPresence { flags.insert(.userPresence) }
  guard let accessControl = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    flags,
    nil
  ) else { throw HardwareKeyError.accessControl }
  return try SecureEnclave.P256.KeyAgreement.PrivateKey(
    compactRepresentable: false,
    accessControl: accessControl,
    authenticationContext: nil
  )
}

private func publicDocument(_ key: P256.KeyAgreement.PublicKey) -> [String: Any] {
  let bytes = key.x963Representation
  return [
    "version": 1,
    "suite": suite,
    "keyID": keyID(bytes),
    "publicKey": bytes.base64EncodedString(),
  ]
}

private func wrap(secret: Data, recipient: [String: Any]) throws -> [String: Any] {
  guard secret.count == 32 else { throw HardwareKeyError.invalidKeyLength }
  guard
    recipient["version"] as? Int == 1,
    recipient["suite"] as? String == suite,
    let claimedID = recipient["keyID"] as? String,
    let encoded = recipient["publicKey"] as? String,
    let publicBytes = Data(base64Encoded: encoded)
  else { throw HardwareKeyError.invalidRecipient }
  let recipientKey = try P256.KeyAgreement.PublicKey(x963Representation: publicBytes)
  guard keyID(publicBytes) == claimedID else { throw HardwareKeyError.recipientMismatch }

  let ephemeral = P256.KeyAgreement.PrivateKey()
  let shared = try ephemeral.sharedSecretFromKeyAgreement(with: recipientKey)
  let wrappingKey = deriveKey(shared, recipientKeyID: claimedID)
  let sealed = try AES.GCM.seal(
    secret,
    using: wrappingKey,
    authenticating: associatedData(claimedID)
  )
  return [
    "version": 1,
    "suite": suite,
    "recipientKeyID": claimedID,
    "ephemeralPublicKey": ephemeral.publicKey.x963Representation.base64EncodedString(),
    "sealedKey": sealed.combined!.base64EncodedString(),
  ]
}

private func unwrap(handle: Data, envelope: [String: Any]) throws -> Data {
  guard SecureEnclave.isAvailable else { throw HardwareKeyError.unavailable }
  let key = try SecureEnclave.P256.KeyAgreement.PrivateKey(
    dataRepresentation: handle,
    authenticationContext: LAContext()
  )
  guard
    envelope["version"] as? Int == 1,
    envelope["suite"] as? String == suite,
    let recipientID = envelope["recipientKeyID"] as? String,
    recipientID == keyID(key.publicKey.x963Representation),
    let encodedEphemeral = envelope["ephemeralPublicKey"] as? String,
    let ephemeralBytes = Data(base64Encoded: encodedEphemeral),
    let encodedSealed = envelope["sealedKey"] as? String,
    let sealedBytes = Data(base64Encoded: encodedSealed)
  else { throw HardwareKeyError.invalidRecipient }

  let ephemeral = try P256.KeyAgreement.PublicKey(x963Representation: ephemeralBytes)
  let shared = try key.sharedSecretFromKeyAgreement(with: ephemeral)
  let sealed = try AES.GCM.SealedBox(combined: sealedBytes)
  let secret = try AES.GCM.open(
    sealed,
    using: deriveKey(shared, recipientKeyID: recipientID),
    authenticating: associatedData(recipientID)
  )
  guard secret.count == 32 else { throw HardwareKeyError.invalidKeyLength }
  return secret
}

private func deriveKey(_ shared: SharedSecret, recipientKeyID: String) -> SymmetricKey {
  shared.hkdfDerivedSymmetricKey(
    using: SHA256.self,
    salt: Data(recipientKeyID.utf8),
    sharedInfo: domain,
    outputByteCount: 32
  )
}

private func associatedData(_ recipientKeyID: String) -> Data {
  Data("\(suite):\(recipientKeyID)".utf8)
}

private func keyID(_ publicKey: Data) -> String {
  Data(SHA256.hash(data: publicKey)).map { String(format: "%02x", $0) }.joined()
}
