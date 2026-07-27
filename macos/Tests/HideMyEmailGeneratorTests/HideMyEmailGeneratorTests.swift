import Foundation
import XCTest

@testable import HideMyEmailGenerator

final class HideMyEmailGeneratorTests: XCTestCase {
  func testDecodesManagementBridgeModels() throws {
    let cloud = try JSONDecoder().decode(
      CloudAddressesResult.self,
      from: Data(
        """
        {"ok":true,"addresses":[{"email":"cloud@icloud.com","label":"Cloud","created_at":"2026-07-26T12:00:00+00:00","is_active":true}],"error":null}
        """.utf8
      )
    )
    XCTAssertEqual(cloud.addresses.first?.email, "cloud@icloud.com")

    let local = try JSONDecoder().decode(
      LocalAddressesResult.self,
      from: Data(
        """
        {"ok":true,"addresses":[{"email":"local@icloud.com","label":"Local","state":"used","source":"generated","updated_at":"2026-07-26T12:00:00+00:00"}],"error":null}
        """.utf8
      )
    )
    XCTAssertEqual(local.addresses.first?.state, .used)

    let inbox = try JSONDecoder().decode(
      InboxMessagesResult.self,
      from: Data(
        """
        {"ok":true,"messages":[{"received_at":"2026-07-26T12:00:00+00:00","hme_address":"local@icloud.com","sender":"sender@example.com","subject":"Verify","code":"123456","body_preview":"Your code is 123456"}],"error":null}
        """.utf8
      )
    )
    XCTAssertEqual(inbox.messages.first?.code, "123456")
  }

  func testOlderAccountResultWithoutDSIDStillDecodes() throws {
    let result = try JSONDecoder().decode(
      AccountResult.self,
      from: Data(
        """
        {"ok":true,"account":{"apple_id":"user@example.com","name":"Example User","user_partition":68,"maildomain_host":"p68-maildomainws.icloud.com","hide_my_email_available":true},"error":null}
        """.utf8
      )
    )
    XCTAssertNil(result.account?.dsid)
  }

  @MainActor
  func testInboxDraftRequiresExplicitSave() {
    let model = AppModel(
      historyURL: URL(fileURLWithPath: "/dev/null"),
      inboxSettings: InboxSettings(),
      inboxPassword: ""
    )

    model.inboxSettings = InboxSettings(
      host: "imap.example.com",
      port: 993,
      username: "user@example.com",
      folder: "INBOX",
      useSSL: true
    )
    model.inboxPassword = "draft-password"

    XCTAssertFalse(model.hasInboxConfiguration)
  }

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

  func testInboxBridgeUsesPrivateTemporaryConfigAndCleansItUp() async throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let support = directory.appendingPathComponent("support", isDirectory: true)
    let helper = directory.appendingPathComponent("helper.sh")
    try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let script = """
      #!/bin/sh
      result=""
      config=""
      : > '\(support.appendingPathComponent("args.txt").path)'
      while [ "$#" -gt 0 ]; do
        printf '%s\\n' "$1" >> '\(support.appendingPathComponent("args.txt").path)'
        if [ "$1" = "--result-json" ]; then
          shift
          result="$1"
          printf '%s\\n' "$1" >> '\(support.appendingPathComponent("args.txt").path)'
        elif [ "$1" = "--config-file" ]; then
          shift
          config="$1"
          printf '%s\\n' "$1" >> '\(support.appendingPathComponent("args.txt").path)'
        fi
        shift
      done
      stat -f '%Lp' "$config" > '\(support.appendingPathComponent("mode.txt").path)'
      printf '%s' "$config" > '\(support.appendingPathComponent("config-path.txt").path)'
      printf '{"ok":true,"config":{"host":"imap.example.com","port":993,"username":"us***r@example.com","folder":"INBOX","use_ssl":true},"counts":{"addresses":0,"messages":0,"codes":0,"states":{"unused":0,"used":0,"trash":0}},"error":null}' > "$result"
      """
    try script.write(to: helper, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)

    let client = try CLIClient(helperURL: helper, supportDirectory: support)
    let result = try await client.inboxStatus(
      settings: InboxSettings(
        host: "imap.example.com",
        port: 993,
        username: "user@example.com",
        folder: "INBOX",
        useSSL: true
      ),
      password: "super-secret"
    )

    XCTAssertTrue(result.ok)
    XCTAssertEqual(
      try String(contentsOf: support.appendingPathComponent("mode.txt"), encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines),
      "600"
    )
    let arguments = try String(
      contentsOf: support.appendingPathComponent("args.txt"),
      encoding: .utf8
    )
    XCTAssertFalse(arguments.contains("super-secret"))
    let configPath = try String(
      contentsOf: support.appendingPathComponent("config-path.txt"),
      encoding: .utf8
    )
    XCTAssertFalse(FileManager.default.fileExists(atPath: configPath))
  }

  func testProcessWithLargeOutputCompletes() async throws {
    let runner = ProcessRunner()
    let status = try await runner.run(
      executable: URL(fileURLWithPath: "/bin/sh"),
      arguments: ["-c", "head -c 1000000 /dev/zero"]
    )
    XCTAssertEqual(status, 0)
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
