import Foundation
import XCTest

@testable import HideMyEmailGenerator

final class HideMyEmailGeneratorTests: XCTestCase {
  func testDecodesRateLimitResult() throws {
    let data = Data(
      """
      {"ok":false,"emails":[],"error":{"code":"-41015","message":"Limited","retry_after":2}}
      """.utf8
    )
    let result = try JSONDecoder().decode(GenerationResult.self, from: data)
    XCTAssertTrue(result.error?.isRateLimit == true)
    XCTAssertEqual(result.error?.retryAfter, 2)
  }

  func testCooldownNeverUsesLessThanThirtyMinutes() {
    XCTAssertEqual(CooldownPolicy.seconds(retryAfter: 2), 1_800)
    XCTAssertEqual(CooldownPolicy.seconds(retryAfter: 3_600), 3_600)
  }

  func testSchedulerIntervalStartsAtAppleLimit() {
    XCTAssertEqual(CooldownPolicy.seconds(retryAfter: 2, interval: 1_920), 1_920)
    XCTAssertEqual(CooldownPolicy.seconds(retryAfter: 3_600, interval: 1_920), 3_600)
  }

  func testSchedulerDefaultsToThirtyTwoMinutes() {
    XCTAssertEqual(SchedulerPolicy.defaultIntervalMinutes, 32)
    XCTAssertEqual(SchedulerPolicy.seconds(minutes: 32), 1_920)
  }

  func testEmailHistoryRoundTripsWithOwnerOnlyPermissions() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let file = directory.appendingPathComponent("history.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    let record = GeneratedEmailRecord(
      id: UUID(),
      email: "example@icloud.com",
      label: "test",
      generatedAt: Date(timeIntervalSince1970: 123)
    )

    try EmailHistoryStore.save([record], to: file)

    XCTAssertEqual(try EmailHistoryStore.load(from: file), [record])
    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    XCTAssertEqual(attributes[.posixPermissions] as? NSNumber, NSNumber(value: 0o600))
  }

  func testCookieCaptureRequiresAppleUserCookieOnExactDomain() throws {
    let user = try XCTUnwrap(
      HTTPCookie(properties: [
        .domain: ".icloud.com",
        .path: "/",
        .name: "X-APPLE-WEBAUTH-USER",
        .value: "user",
      ])
    )
    let decoy = try XCTUnwrap(
      HTTPCookie(properties: [
        .domain: ".evilicloud.com",
        .path: "/",
        .name: "decoy",
        .value: "ignore",
      ])
    )

    let header = try XCTUnwrap(ICloudCookieHeader.make(from: [user, decoy], region: .global))

    XCTAssertEqual(header, "X-APPLE-WEBAUTH-USER=user")
    XCTAssertNil(ICloudCookieHeader.make(from: [decoy], region: .global))
  }

  func testCookieCaptureAcceptsExactHideMyEmailRequests() throws {
    for (region, url) in [
      (ICloudRegion.global, "https://www.icloud.com/applications/hidemyemail/current/?rootDomain=www"),
      (ICloudRegion.china, "https://www.icloud.com.cn/applications/hidemyemail/current/?rootDomain=www"),
    ] {
      var request = URLRequest(url: try XCTUnwrap(URL(string: url)))
      request.setValue(
        "other=value; X-APPLE-WEBAUTH-USER=user",
        forHTTPHeaderField: "Cookie"
      )

      XCTAssertEqual(
        ICloudCookieHeader.make(from: request, region: region),
        "other=value; X-APPLE-WEBAUTH-USER=user"
      )
    }
  }

  func testCookieCaptureRejectsWrongHideMyEmailRequest() throws {
    for url in [
      "https://evilicloud.com/applications/hidemyemail/current/?rootDomain=www",
      "https://www.icloud.com/icloudplus/?rootDomain=www",
      "https://www.icloud.com/applications/hidemyemail/current/",
      "https://www.icloud.com/applications/hidemyemail/current/?rootDomain=other",
    ] {
      var request = URLRequest(url: try XCTUnwrap(URL(string: url)))
      request.setValue("X-APPLE-WEBAUTH-USER=user", forHTTPHeaderField: "Cookie")

      XCTAssertNil(ICloudCookieHeader.make(from: request, region: .global))
    }
  }

  func testCookieCaptureRejectsRequestWithoutAppleUserCookie() throws {
    var request = URLRequest(
      url: try XCTUnwrap(
        URL(
          string: "https://www.icloud.com/applications/hidemyemail/current/?rootDomain=www"
        )
      )
    )
    request.setValue("other=value", forHTTPHeaderField: "Cookie")

    XCTAssertNil(ICloudCookieHeader.make(from: request, region: .global))
  }

  func testPrivateCookieFileUsesOwnerOnlyPermissions() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("cookies.txt")

    try CLIClient.writePrivateFile(Data("secret".utf8), to: file)

    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    XCTAssertEqual(attributes[.posixPermissions] as? NSNumber, NSNumber(value: 0o600))
  }

  func testProcessCancellationTerminatesHelper() async throws {
    let runner = ProcessRunner()
    let task = Task {
      try await runner.run(
        executable: URL(fileURLWithPath: "/bin/sleep"),
        arguments: ["30"]
      )
    }
    try await Task<Never, Never>.sleep(nanoseconds: 100_000_000)
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected cancellation")
    } catch is CancellationError {
      // Expected.
    }
  }
}
