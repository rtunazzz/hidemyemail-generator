import AppKit
import Foundation
import Security

enum ICloudRegion: String, Codable, CaseIterable, Identifiable {
  case global
  case china

  var id: Self { self }
  var title: String { self == .global ? "Global" : "China" }
  var signInURL: URL {
    URL(
      string: self == .global
        ? "https://www.icloud.com/icloudplus/"
        : "https://www.icloud.com.cn/icloudplus/")!
  }
  var hideMyEmailURL: URL {
    URL(
      string: self == .global
        ? "https://www.icloud.com/applications/hidemyemail/current/?rootDomain=www"
        : "https://www.icloud.com.cn/applications/hidemyemail/current/?rootDomain=www")!
  }
  var cookieDomainSuffix: String {
    self == .global ? "icloud.com" : "icloud.com.cn"
  }
}

struct BridgeError: Codable, LocalizedError, Equatable {
  let code: String?
  let message: String
  let retryAfter: Double?

  enum CodingKeys: String, CodingKey {
    case code, message
    case retryAfter = "retry_after"
  }

  var errorDescription: String? { message }
  var isRateLimit: Bool { code == "-41015" }
  var requiresAuthentication: Bool {
    let value = message.lowercased()
    return value.contains("invalid global session")
      || value.contains("invalid session")
      || value.contains("x-apple-webauth-user")
      || value.contains("cookie")
  }
}

struct GenerationResult: Codable, Equatable {
  let ok: Bool
  let emails: [String]
  let error: BridgeError?
}

struct AccountInfo: Codable, Equatable {
  let appleID: String
  let name: String
  let userPartition: Int?
  let maildomainHost: String
  let hideMyEmailAvailable: Bool

  enum CodingKeys: String, CodingKey {
    case name
    case appleID = "apple_id"
    case userPartition = "user_partition"
    case maildomainHost = "maildomain_host"
    case hideMyEmailAvailable = "hide_my_email_available"
  }
}

struct AccountResult: Codable, Equatable {
  let ok: Bool
  let account: AccountInfo?
  let error: BridgeError?
}

struct StoredSession: Codable, Equatable {
  let cookieContext: String
  let region: ICloudRegion
  let account: AccountInfo
}

struct GeneratedEmailRecord: Codable, Equatable, Identifiable {
  let id: UUID
  let email: String
  let label: String
  let generatedAt: Date
}

enum EmailHistoryStore {
  static func defaultURL() throws -> URL {
    try FileManager.default
      .url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      .appendingPathComponent("HideMyEmail Generator", isDirectory: true)
      .appendingPathComponent("history.json")
  }

  static func load(from url: URL) throws -> [GeneratedEmailRecord] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    return try JSONDecoder().decode([GeneratedEmailRecord].self, from: Data(contentsOf: url))
  }

  static func save(_ records: [GeneratedEmailRecord], to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try JSONEncoder().encode(records).write(to: url, options: .atomic)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
  }
}

enum CooldownPolicy {
  static let minimumSeconds: TimeInterval = 30 * 60

  static func seconds(
    retryAfter: Double?,
    interval: TimeInterval? = nil
  ) -> TimeInterval {
    max(interval ?? minimumSeconds, retryAfter ?? 0)
  }
}

enum SchedulerPolicy {
  static let defaultIntervalMinutes = 32
  static let allowedMinutes = 30...120

  static func seconds(minutes: Int) -> TimeInterval {
    TimeInterval(minutes * 60)
  }
}

enum RunState: Equatable {
  case idle
  case running
  case coolingDown(until: Date)
  case needsAuthentication
  case failed(String)
  case complete
}

enum RunKind: Equatable {
  case onDemand
  case scheduler
}

enum KeychainSessionStore {
  private static let service = "com.rtunazzz.HideMyEmailGenerator"
  private static let account = "icloud-session"

  static func load() throws -> StoredSession? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = item as? Data else {
      throw CocoaError(.fileReadUnknown)
    }
    return try JSONDecoder().decode(StoredSession.self, from: data)
  }

  static func save(_ session: StoredSession) throws {
    let data = try JSONEncoder().encode(session)
    let update = [kSecValueData as String: data]
    let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
    if status == errSecSuccess { return }
    guard status == errSecItemNotFound else { throw CocoaError(.fileWriteUnknown) }

    var item = baseQuery
    item[kSecValueData as String] = data
    item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
      throw CocoaError(.fileWriteUnknown)
    }
  }

  static func delete() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw CocoaError(.fileWriteUnknown)
    }
  }

  private static var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}

final class ProcessRunner: @unchecked Sendable {
  private let lock = NSLock()
  private var activeProcess: Process?

  func run(
    executable: URL,
    arguments: [String],
    currentDirectory: URL? = nil
  ) async throws -> Int32 {
    try Task.checkCancellation()

    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectory
    process.standardOutput = Pipe()
    process.standardError = Pipe()

    setActive(process)
    let status: Int32 = try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        process.terminationHandler = { [weak self] process in
          self?.clearActive(process)
          continuation.resume(returning: process.terminationStatus)
        }
        do {
          try process.run()
          if Task<Never, Never>.isCancelled {
            process.terminate()
          }
        } catch {
          clearActive(process)
          continuation.resume(throwing: error)
        }
      }
    } onCancel: {
      if process.isRunning {
        process.terminate()
      }
    }

    try Task.checkCancellation()
    return status
  }

  func cancel() {
    lock.lock()
    let process = activeProcess
    lock.unlock()
    if process?.isRunning == true {
      process?.terminate()
    }
  }

  private func setActive(_ process: Process) {
    lock.lock()
    activeProcess = process
    lock.unlock()
  }

  private func clearActive(_ process: Process) {
    lock.lock()
    if activeProcess === process {
      activeProcess = nil
    }
    lock.unlock()
  }
}

final class CLIClient: @unchecked Sendable {
  private let helperURL: URL
  private let supportDirectory: URL
  private let runner: ProcessRunner

  init(
    helperURL: URL? = nil,
    supportDirectory: URL? = nil,
    runner: ProcessRunner = ProcessRunner()
  ) throws {
    if let helperURL {
      self.helperURL = helperURL
    } else if let override = ProcessInfo.processInfo.environment["HIDEMYEMAIL_HELPER_PATH"] {
      self.helperURL = URL(fileURLWithPath: override)
    } else if let bundled = Bundle.main.url(forResource: "hidemyemail", withExtension: nil) {
      self.helperURL = bundled
    } else {
      throw CocoaError(.fileNoSuchFile)
    }

    self.supportDirectory =
      try supportDirectory
      ?? FileManager.default
      .url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true
      )
      .appendingPathComponent("HideMyEmail Generator", isDirectory: true)
    self.runner = runner
    try FileManager.default.createDirectory(
      at: self.supportDirectory,
      withIntermediateDirectories: true
    )
  }

  func validate(cookieContext: String, region: ICloudRegion) async throws -> AccountResult {
    let data = try await invoke(
      cookieContext: cookieContext,
      arguments: { cookieFile, resultFile in
        [
          "whoami",
          "--cookie-file", cookieFile.path,
          "--region", region.rawValue,
          "--result-json", resultFile.path,
        ]
      }
    )
    return try JSONDecoder().decode(AccountResult.self, from: data)
  }

  func generate(
    session: StoredSession,
    label: String
  ) async throws -> GenerationResult {
    let output = supportDirectory.appendingPathComponent("emails.txt")
    let data = try await invoke(
      cookieContext: session.cookieContext,
      arguments: { cookieFile, resultFile in
        [
          "generate",
          "--label", label,
          "--count", "1",
          "--cookie-file", cookieFile.path,
          "--output", output.path,
          "--no-db",
          "--region", session.region.rawValue,
          "--result-json", resultFile.path,
        ]
      }
    )
    return try JSONDecoder().decode(GenerationResult.self, from: data)
  }

  func cancel() {
    runner.cancel()
  }

  static func cookieContext(
    header: String,
    region: ICloudRegion,
    maildomainHost: String = ""
  ) -> String {
    [
      "# Generated by HideMyEmail Generator for macOS.",
      "HIDEMYEMAIL_REGION=\(region.rawValue)",
      "HIDEMYEMAIL_MAILDOMAIN_HOST=\(maildomainHost)",
      "HIDEMYEMAIL_COOKIE_BASE64=\(Data(header.utf8).base64EncodedString())",
      "",
    ].joined(separator: "\n")
  }

  static func finalizedContext(_ context: String, maildomainHost: String) -> String {
    let lines = context.split(separator: "\n", omittingEmptySubsequences: false)
      .filter { !$0.hasPrefix("HIDEMYEMAIL_MAILDOMAIN_HOST=") }
    return (lines + ["HIDEMYEMAIL_MAILDOMAIN_HOST=\(maildomainHost)", ""])
      .joined(separator: "\n")
  }

  static func writePrivateFile(_ data: Data, to url: URL) throws {
    guard
      FileManager.default.createFile(
        atPath: url.path,
        contents: data,
        attributes: [.posixPermissions: 0o600]
      )
    else {
      throw CocoaError(.fileWriteUnknown)
    }
  }

  private func invoke(
    cookieContext: String,
    arguments: (URL, URL) -> [String]
  ) async throws -> Data {
    let temporary = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
      at: temporary,
      withIntermediateDirectories: false
    )
    defer { try? FileManager.default.removeItem(at: temporary) }

    let cookieFile = temporary.appendingPathComponent("cookies.txt")
    let resultFile = temporary.appendingPathComponent("result.json")
    try Self.writePrivateFile(Data(cookieContext.utf8), to: cookieFile)

    _ = try await runner.run(
      executable: helperURL,
      arguments: arguments(cookieFile, resultFile),
      currentDirectory: supportDirectory
    )
    try Task.checkCancellation()
    guard FileManager.default.fileExists(atPath: resultFile.path) else {
      throw CocoaError(.fileReadNoSuchFile)
    }
    return try Data(contentsOf: resultFile)
  }
}

@MainActor
final class AppModel: ObservableObject {
  @Published private(set) var session: StoredSession?
  @Published var onDemandLabel = "generated"
  @Published var onDemandQuantity = 1
  @Published var schedulerLabel = "generated"
  @Published var schedulerTargetCount = 100
  @Published var schedulerIntervalMinutes = SchedulerPolicy.defaultIntervalMinutes
  @Published private(set) var history: [GeneratedEmailRecord] = []
  @Published private(set) var generatedEmails: [String] = []
  @Published private(set) var runState: RunState = .idle
  @Published private(set) var runKind: RunKind?
  @Published var showingSignIn = false
  @Published var signInRegion: ICloudRegion = .global
  @Published private(set) var isConnecting = false
  @Published private(set) var connectionError: String?
  @Published private(set) var helperError: String?

  private var client: CLIClient?
  private let historyURL: URL?
  private var generationTask: Task<Void, Never>?
  private var runTarget = 0
  private var runLabel = ""
  private var runInterval: TimeInterval?
  private var resumeAfterAuthentication = false

  init(client: CLIClient? = nil, historyURL: URL? = nil) {
    self.historyURL = historyURL ?? (try? EmailHistoryStore.defaultURL())
    session = try? KeychainSessionStore.load()
    signInRegion = session?.region ?? .global
    if let resolvedHistoryURL = self.historyURL {
      history = (try? EmailHistoryStore.load(from: resolvedHistoryURL)) ?? []
    }
    if let client {
      self.client = client
    } else {
      do {
        self.client = try CLIClient()
      } catch {
        helperError = "The bundled CLI helper is missing. Reinstall the app."
      }
    }
  }

  var progress: Double {
    guard runTarget > 0 else { return 0 }
    return min(1, Double(generatedEmails.count) / Double(runTarget))
  }

  var currentTarget: Int { runTarget }

  var isBusy: Bool {
    switch runState {
    case .running, .coolingDown:
      return true
    default:
      return false
    }
  }

  var canGenerateOnDemand: Bool {
    session != nil
      && client != nil
      && !isBusy
      && !onDemandLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var canStartScheduler: Bool {
    session != nil
      && client != nil
      && !isBusy
      && !schedulerLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  func generateOnDemand() {
    guard canGenerateOnDemand else { return }
    generatedEmails = []
    runTarget = onDemandQuantity
    runLabel = onDemandLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    runInterval = nil
    runKind = .onDemand
    resumeAfterAuthentication = false
    startQueue()
  }

  func startScheduler() {
    guard canStartScheduler else { return }
    generatedEmails = []
    runTarget = schedulerTargetCount
    runLabel = schedulerLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    runInterval = SchedulerPolicy.seconds(minutes: schedulerIntervalMinutes)
    runKind = .scheduler
    resumeAfterAuthentication = false
    startQueue()
  }

  func stopGeneration() {
    generationTask?.cancel()
    client?.cancel()
    generationTask = nil
    runState = .idle
  }

  func connect(cookieHeader: String, region: ICloudRegion) {
    iCloudSignInLog.notice("App model received captured session")
    let context = CLIClient.cookieContext(header: cookieHeader, region: region)
    validateAndSave(context: context, region: region)
  }

  func importCookie(from url: URL, region: ICloudRegion) {
    do {
      validateAndSave(context: try String(contentsOf: url), region: region)
    } catch {
      connectionError = "Could not read that cookie file."
    }
  }

  func reconnect() {
    signInRegion = session?.region ?? .global
    connectionError = nil
    showingSignIn = true
  }

  func signOut() {
    stopGeneration()
    try? KeychainSessionStore.delete()
    session = nil
    generatedEmails = []
    runKind = nil
    runState = .idle
  }

  func copy(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
  }

  func copyAll() {
    copy(generatedEmails.joined(separator: "\n"))
  }

  func copyHistory() {
    copy(history.map(\.email).joined(separator: "\n"))
  }

  func exportResults() {
    guard !generatedEmails.isEmpty else { return }
    export(generatedEmails, suggestedName: "hide-my-email-addresses.txt")
  }

  func exportHistory() {
    guard !history.isEmpty else { return }
    export(
      history.map {
        "\($0.email)\t\($0.label)\t\($0.generatedAt.formatted(.iso8601))"
      },
      suggestedName: "hide-my-email-history.txt"
    )
  }

  private func export(_ lines: [String], suggestedName: String) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = suggestedName
    panel.allowedContentTypes = [.plainText]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    try? (lines.joined(separator: "\n") + "\n")
      .write(to: url, atomically: true, encoding: .utf8)
  }

  private func validateAndSave(context: String, region: ICloudRegion) {
    guard !isConnecting, let client else { return }
    iCloudSignInLog.notice("Starting local CLI session validation")
    isConnecting = true
    connectionError = nil

    Task {
      do {
        let result = try await client.validate(
          cookieContext: context,
          region: region
        )
        iCloudSignInLog.notice(
          "Local CLI validation completed; accepted: \(result.ok)"
        )
        guard result.ok, let account = result.account else {
          throw result.error
            ?? BridgeError(
              code: nil,
              message: "Apple did not accept this session.",
              retryAfter: nil
            )
        }
        let stored = StoredSession(
          cookieContext: CLIClient.finalizedContext(
            context,
            maildomainHost: account.maildomainHost
          ),
          region: region,
          account: account
        )
        try KeychainSessionStore.save(stored)
        session = stored
        showingSignIn = false
        iCloudSignInLog.notice("Session saved; sign-in sheet dismissed")
        isConnecting = false
        connectionError = nil
        if resumeAfterAuthentication {
          resumeAfterAuthentication = false
          startQueue()
        }
      } catch {
        iCloudSignInLog.error("Local CLI session validation failed")
        isConnecting = false
        connectionError = error.localizedDescription
      }
    }
  }

  private func startQueue() {
    generationTask?.cancel()
    generationTask = Task { [weak self] in
      await self?.generateLoop()
    }
  }

  private func generateLoop() async {
    guard let client else { return }
    runState = .running

    while generatedEmails.count < runTarget {
      guard !Task.isCancelled else { return }
      guard let session else {
        resumeAfterAuthentication = true
        runState = .needsAuthentication
        showingSignIn = true
        return
      }

      do {
        let result = try await client.generate(session: session, label: runLabel)
        if result.ok, let email = result.emails.first {
          generatedEmails.append(email)
          let record = GeneratedEmailRecord(
            id: UUID(),
            email: email,
            label: runLabel,
            generatedAt: Date()
          )
          history.insert(record, at: 0)
          if let historyURL {
            try EmailHistoryStore.save(history, to: historyURL)
          }
          continue
        }

        let error =
          result.error
          ?? BridgeError(
            code: nil,
            message: "Generation failed.",
            retryAfter: nil
          )
        if error.isRateLimit {
          let seconds = CooldownPolicy.seconds(
            retryAfter: error.retryAfter,
            interval: runInterval
          )
          runState = .coolingDown(until: Date().addingTimeInterval(seconds))
          try await Task<Never, Never>.sleep(
            nanoseconds: UInt64(seconds * 1_000_000_000)
          )
          runState = .running
        } else if error.requiresAuthentication {
          resumeAfterAuthentication = true
          runState = .needsAuthentication
          showingSignIn = true
          return
        } else {
          runState = .failed(error.message)
          return
        }
      } catch is CancellationError {
        return
      } catch {
        runState = .failed(error.localizedDescription)
        return
      }
    }

    runState = .complete
    generationTask = nil
  }
}
