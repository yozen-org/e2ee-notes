import Flutter
import UIKit
import XCTest

@testable import secure_keys

class RunnerTests: XCTestCase {

  func testGetPlatformVersion() {
    let plugin = SecureKeysPlugin()

    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: [])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertEqual(result as! String, "iOS " + UIDevice.current.systemVersion)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}
