import FlutterMacOS
import Foundation

import secure_keys

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  SecureKeysPlugin.register(with: registry.registrar(forPlugin: "SecureKeysPlugin"))
}
