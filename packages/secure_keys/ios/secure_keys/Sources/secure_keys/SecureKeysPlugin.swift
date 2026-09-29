import CryptoKit
import Flutter
import LocalAuthentication
import Security
import UIKit

private let suite = "P256-HKDF-SHA256-AES256GCM"

private enum HardwareKeyError: Error {
  case unavailable
  case invalidArguments
  case invalidRecipient
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
      case "openRecipientKey":
        let arguments = try dictionary(call.arguments)
        guard let handle = (arguments["keyHandle"] as? FlutterStandardTypedData)?.data
        else { throw HardwareKeyError.invalidArguments }
        let key = try openKey(handle: handle)
        result(publicDocument(key.publicKey))
      case "sharedSecret":
        let arguments = try dictionary(call.arguments)
        guard
          let handle = (arguments["keyHandle"] as? FlutterStandardTypedData)?.data,
          let peer = (arguments["peerPublicKey"] as? FlutterStandardTypedData)?.data
        else { throw HardwareKeyError.invalidArguments }
        result(FlutterStandardTypedData(bytes: try sharedSecret(handle: handle, peerPublicKey: peer)))
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

private func openKey(handle: Data) throws -> SecureEnclave.P256.KeyAgreement.PrivateKey {
  guard SecureEnclave.isAvailable else { throw HardwareKeyError.unavailable }
  return try SecureEnclave.P256.KeyAgreement.PrivateKey(
    dataRepresentation: handle,
    authenticationContext: LAContext()
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

private func sharedSecret(handle: Data, peerPublicKey: Data) throws -> Data {
  guard SecureEnclave.isAvailable else { throw HardwareKeyError.unavailable }
  let key = try openKey(handle: handle)
  guard let peer = try? P256.KeyAgreement.PublicKey(x963Representation: peerPublicKey)
  else { throw HardwareKeyError.invalidRecipient }
  let shared = try key.sharedSecretFromKeyAgreement(with: peer)
  return shared.withUnsafeBytes { Data($0) }
}

private func keyID(_ publicKey: Data) -> String {
  Data(SHA256.hash(data: publicKey)).map { String(format: "%02x", $0) }.joined()
}
