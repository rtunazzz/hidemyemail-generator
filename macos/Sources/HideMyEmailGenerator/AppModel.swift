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
  let dsid: String?
  let userPartition: Int?
  let maildomainHost: String
  let hideMyEmailAvailable: Bool

  enum CodingKeys: String, CodingKey {
    case name, dsid
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

enum AddressState: String, Codable, CaseIterable, Identifiable {
  case unused
  case used
  case trash

  var id: Self { self }
  var title: String { rawValue.capitalized }
}

struct CloudAddress: Codable, Equatable, Identifiable {
  let email: String
  let label: String
  let createdAt: String
  let isActive: Bool

  var id: String { email }

  enum CodingKeys: String, CodingKey {
    case email, label
    case createdAt = "created_at"
    case isActive = "is_active"
  }
}

struct LocalAddress: Codable, Equatable, Identifiable {
  let email: String
  let label: String
  let state: AddressState
  let source: String
  let updatedAt: String

  var id: String { email }

  enum CodingKeys: String, CodingKey {
    case email, label, state, source
    case updatedAt = "updated_at"
  }
}

struct InboxMessage: Codable, Equatable, Identifiable {
  let receivedAt: String?
  let hmeAddress: String?
  let sender: String?
  let subject: String?
  let code: String?
  let bodyPreview: String?

  var id: String {
    [receivedAt, sender, subject, hmeAddress].compactMap { $0 }.joined(separator: "|")
  }

  enum CodingKeys: String, CodingKey {
    case sender, subject, code
    case receivedAt = "received_at"
    case hmeAddress = "hme_address"
    case bodyPreview = "body_preview"
  }
}

struct CloudAddressesResult: Codable, Equatable {
  let ok: Bool
  let addresses: [CloudAddress]
  let error: BridgeError?
}

struct LocalAddressesResult: Codable, Equatable {
  let ok: Bool
  let addresses: [LocalAddress]
  let error: BridgeError?
}

struct InboxMessagesResult: Codable, Equatable {
  let ok: Bool
  let messages: [InboxMessage]
  let error: BridgeError?
}

struct AddressStateCounts: Codable, Equatable {
  let unused: Int
  let used: Int
  let trash: Int
}

struct InboxCounts: Codable, Equatable {
  let addresses: Int
  let messages: Int
  let codes: Int
  let states: AddressStateCounts
}

struct InboxConfigSummary: Codable, Equatable {
  let host: String
  let port: Int
  let username: String
  let folder: String
  let useSSL: Bool

  enum CodingKeys: String, CodingKey {
    case host, port, username, folder
    case useSSL = "use_ssl"
  }
}

struct InboxStatusResult: Codable, Equatable {
  let ok: Bool
  let config: InboxConfigSummary?
  let counts: InboxCounts?
  let error: BridgeError?
}

struct CountResult: Codable, Equatable {
  let ok: Bool
  let count: Int
  let error: BridgeError?
}

struct InboxSyncResult: Codable, Equatable {
  let ok: Bool
  let count: Int
  let messages: [InboxMessage]
  let error: BridgeError?
}

struct MarkResult: Codable, Equatable {
  let ok: Bool
  let email: String
  let state: AddressState
  let error: BridgeError?
}

struct ExportResult: Codable, Equatable {
  let ok: Bool
  let outputs: [String: String]
  let error: BridgeError?
}

struct InboxSettings: Codable, Equatable {
  var host = ""
  var port = 993
  var username = ""
  var folder = "INBOX"
  var useSSL = true

  var isComplete: Bool {
    !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !folder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && (1...65_535).contains(port)
  }

  enum CodingKeys: String, CodingKey {
    case host, port, username, folder
    case useSSL = "use_ssl"
  }
}

private struct InboxConfiguration: Codable {
  let host: String
  let port: Int
  let username: String
  let password: String
  let folder: String
  let useSSL: Bool

  enum CodingKeys: String, CodingKey {
    case host, port, username, password, folder
    case useSSL = "use_ssl"
  }
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

enum InboxSettingsStore {
  private static let key = "inbox-settings"

  static func load(defaults: UserDefaults = .standard) -> InboxSettings {
    guard
      let data = defaults.data(forKey: key),
      let settings = try? JSONDecoder().decode(InboxSettings.self, from: data)
    else {
      return InboxSettings()
    }
    return settings
  }

  static func save(_ settings: InboxSettings, defaults: UserDefaults = .standard) throws {
    defaults.set(try JSONEncoder().encode(settings), forKey: key)
  }

  static func delete(defaults: UserDefaults = .standard) {
    defaults.removeObject(forKey: key)
  }
}

enum InboxPasswordStore {
  private static let service = "com.rtunazzz.HideMyEmailGenerator"
  private static let account = "inbox-password"

  static func load() throws -> String? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard
      status == errSecSuccess,
      let data = item as? Data,
      let password = String(data: data, encoding: .utf8)
    else {
      throw CocoaError(.fileReadUnknown)
    }
    return password
  }

  static func save(_ password: String) throws {
    let data = Data(password.utf8)
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
    // Undrained pipes deadlock the helper once output exceeds the pipe buffer;
    // helper output is unused — results arrive via --result-json.
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

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
      arguments: { cookieFile, resultFile, _ in
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
      arguments: { cookieFile, resultFile, _ in
        [
          "generate",
          "--label", label,
          "--count", "1",
          "--cookie-file", cookieFile.path,
          "--output", output.path,
          "--db-file", databaseURL.path,
          "--region", session.region.rawValue,
          "--result-json", resultFile.path,
        ]
      }
    )
    return try JSONDecoder().decode(GenerationResult.self, from: data)
  }

  func cloudAddresses(
    session: StoredSession,
    active: Bool
  ) async throws -> CloudAddressesResult {
    let data = try await invoke(
      cookieContext: session.cookieContext,
      arguments: { cookieFile, resultFile, _ in
        [
          "list",
          active ? "--active" : "--inactive",
          "--cookie-file", cookieFile.path,
          "--region", session.region.rawValue,
          "--result-json", resultFile.path,
        ]
      }
    )
    return try JSONDecoder().decode(CloudAddressesResult.self, from: data)
  }

  func localAddresses() async throws -> LocalAddressesResult {
    let data = try await invoke { _, resultFile, _ in
      [
        "inbox", "addresses",
        "--db-file", self.databaseURL.path,
        "--limit", "1000",
        "--result-json", resultFile.path,
      ]
    }
    return try JSONDecoder().decode(LocalAddressesResult.self, from: data)
  }

  func inboxStatus(settings: InboxSettings, password: String) async throws
    -> InboxStatusResult
  {
    let data = try await invoke(
      inboxConfiguration: configuration(settings: settings, password: password),
      arguments: { _, resultFile, configFile in
        [
          "inbox", "status",
          "--config-file", configFile.path,
          "--db-file", self.databaseURL.path,
          "--result-json", resultFile.path,
        ]
      }
    )
    return try JSONDecoder().decode(InboxStatusResult.self, from: data)
  }

  func inboxMessages() async throws -> InboxMessagesResult {
    let data = try await invoke { _, resultFile, _ in
      [
        "inbox", "messages",
        "--db-file", self.databaseURL.path,
        "--limit", "200",
        "--result-json", resultFile.path,
      ]
    }
    return try JSONDecoder().decode(InboxMessagesResult.self, from: data)
  }

  func syncInbox(settings: InboxSettings, password: String) async throws -> InboxSyncResult {
    let data = try await invoke(
      inboxConfiguration: configuration(settings: settings, password: password),
      arguments: { _, resultFile, configFile in
        [
          "inbox", "sync",
          "--config-file", configFile.path,
          "--db-file", self.databaseURL.path,
          "--limit", "100",
          "--result-json", resultFile.path,
        ]
      }
    )
    return try JSONDecoder().decode(InboxSyncResult.self, from: data)
  }

  func markAddress(_ email: String, state: AddressState) async throws -> MarkResult {
    let data = try await invoke { _, resultFile, _ in
      [
        "inbox", "mark", email, state.rawValue,
        "--db-file", self.databaseURL.path,
        "--result-json", resultFile.path,
      ]
    }
    return try JSONDecoder().decode(MarkResult.self, from: data)
  }

  func syncICloudAddresses(session: StoredSession) async throws -> CountResult {
    let data = try await invoke(
      cookieContext: session.cookieContext,
      arguments: { cookieFile, resultFile, _ in
        [
          "inbox", "sync-hme",
          "--cookie-file", cookieFile.path,
          "--region", session.region.rawValue,
          "--db-file", self.databaseURL.path,
          "--result-json", resultFile.path,
        ]
      }
    )
    return try JSONDecoder().decode(CountResult.self, from: data)
  }

  func exportCSV(to directory: URL) async throws -> ExportResult {
    let data = try await invoke { _, resultFile, _ in
      [
        "inbox", "export",
        "--db-file", self.databaseURL.path,
        "--export-dir", directory.path,
        "--result-json", resultFile.path,
      ]
    }
    return try JSONDecoder().decode(ExportResult.self, from: data)
  }

  func cancel() {
    runner.cancel()
  }

  private var databaseURL: URL {
    supportDirectory.appendingPathComponent("hidemyemail.db")
  }

  private func configuration(settings: InboxSettings, password: String) -> InboxConfiguration {
    InboxConfiguration(
      host: settings.host,
      port: settings.port,
      username: settings.username,
      password: password,
      folder: settings.folder,
      useSSL: settings.useSSL
    )
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
    cookieContext: String = "",
    inboxConfiguration: InboxConfiguration? = nil,
    arguments: (URL, URL, URL) -> [String]
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
    let configFile = temporary.appendingPathComponent("inbox_config.json")
    try Self.writePrivateFile(Data(cookieContext.utf8), to: cookieFile)
    if let inboxConfiguration {
      try Self.writePrivateFile(try JSONEncoder().encode(inboxConfiguration), to: configFile)
    }

    _ = try await runner.run(
      executable: helperURL,
      arguments: arguments(cookieFile, resultFile, configFile),
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
  @Published private(set) var localAddresses: [LocalAddress] = []
  @Published private(set) var cloudAddresses: [CloudAddress] = []
  @Published private(set) var inboxMessages: [InboxMessage] = []
  @Published private(set) var inboxStatus: InboxStatusResult?
  @Published private(set) var isManaging = false
  @Published private(set) var managementError: String?
  @Published private(set) var managementNotice: String?
  @Published var inboxSettings: InboxSettings
  @Published var inboxPassword: String

  private var client: CLIClient?
  private var managementClient: CLIClient?
  private var savedInboxSettings: InboxSettings
  private var savedInboxPassword: String
  private let historyURL: URL?
  private var generationTask: Task<Void, Never>?
  private var runTarget = 0
  private var runLabel = ""
  private var runInterval: TimeInterval?
  private var resumeAfterAuthentication = false

  init(
    client: CLIClient? = nil,
    managementClient: CLIClient? = nil,
    historyURL: URL? = nil,
    inboxSettings: InboxSettings = InboxSettingsStore.load(),
    inboxPassword: String = (try? InboxPasswordStore.load()) ?? ""
  ) {
    self.inboxSettings = inboxSettings
    self.inboxPassword = inboxPassword
    savedInboxSettings = inboxSettings
    savedInboxPassword = inboxPassword
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
    if let managementClient {
      self.managementClient = managementClient
    } else {
      self.managementClient = try? CLIClient()
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

  var hasInboxConfiguration: Bool {
    savedInboxSettings.isComplete && !savedInboxPassword.isEmpty
  }

  var verificationCodes: [InboxMessage] {
    inboxMessages.filter { !($0.code ?? "").isEmpty }
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

  func refreshAccount() {
    guard let session else { return }
    manage { [weak self] client in
      let result = try await client.validate(
        cookieContext: session.cookieContext,
        region: session.region
      )
      guard result.ok, let account = result.account else {
        throw result.error ?? Self.managementFailure("Could not refresh the iCloud account.")
      }
      let updated = StoredSession(
        cookieContext: session.cookieContext,
        region: session.region,
        account: account
      )
      try KeychainSessionStore.save(updated)
      self?.session = updated
      self?.managementNotice = "iCloud account refreshed."
    }
  }

  func refreshLocalAddresses() {
    manage { [weak self] client in
      try await self?.loadLocalAddresses(using: client)
    }
  }

  func refreshCloudAddresses(active: Bool) {
    guard let session else {
      reconnect()
      return
    }
    manage { [weak self] client in
      let result = try await client.cloudAddresses(session: session, active: active)
      guard result.ok else {
        throw result.error ?? Self.managementFailure("Could not load iCloud addresses.")
      }
      self?.cloudAddresses = result.addresses
    }
  }

  func syncICloudAddresses() {
    guard let session else {
      reconnect()
      return
    }
    manage { [weak self] client in
      let result = try await client.syncICloudAddresses(session: session)
      guard result.ok else {
        throw result.error ?? Self.managementFailure("Could not sync iCloud addresses.")
      }
      try await self?.loadLocalAddresses(using: client)
      self?.managementNotice = "Synced \(result.count) iCloud addresses."
    }
  }

  func saveInboxConfiguration() {
    guard inboxSettings.isComplete, !inboxPassword.isEmpty else {
      managementError = "Enter a valid host, port, username, password, and folder."
      return
    }
    do {
      try InboxSettingsStore.save(inboxSettings)
      try InboxPasswordStore.save(inboxPassword)
      savedInboxSettings = inboxSettings
      savedInboxPassword = inboxPassword
      managementNotice = "Inbox settings saved securely."
      managementError = nil
      refreshInbox()
    } catch {
      managementError = "Could not save the inbox credentials."
    }
  }

  func clearInboxConfiguration() {
    try? InboxPasswordStore.delete()
    InboxSettingsStore.delete()
    inboxSettings = InboxSettings()
    inboxPassword = ""
    savedInboxSettings = inboxSettings
    savedInboxPassword = inboxPassword
    inboxStatus = nil
    managementNotice = "Inbox credentials removed. Local messages were kept."
    managementError = nil
  }

  func refreshInbox() {
    let settings = savedInboxSettings
    let password = savedInboxPassword
    manage { [weak self] client in
      let messages = try await client.inboxMessages()
      guard messages.ok else {
        throw messages.error ?? Self.managementFailure("Could not load inbox messages.")
      }
      self?.inboxMessages = messages.messages

      if settings.isComplete, !password.isEmpty {
        let status = try await client.inboxStatus(settings: settings, password: password)
        guard status.ok else {
          throw status.error ?? Self.managementFailure("Could not load inbox status.")
        }
        self?.inboxStatus = status
      }
    }
  }

  func syncInbox() {
    guard hasInboxConfiguration else {
      managementError = "Configure the inbox before syncing."
      return
    }
    let settings = savedInboxSettings
    let password = savedInboxPassword
    manage { [weak self] client in
      let result = try await client.syncInbox(settings: settings, password: password)
      guard result.ok else {
        throw result.error ?? Self.managementFailure("Inbox sync failed.")
      }
      let messages = try await client.inboxMessages()
      guard messages.ok else {
        throw messages.error ?? Self.managementFailure("Could not refresh inbox messages.")
      }
      self?.inboxMessages = messages.messages
      self?.managementNotice =
        result.count == 1 ? "Synced 1 new message." : "Synced \(result.count) new messages."

      let status = try await client.inboxStatus(settings: settings, password: password)
      if status.ok {
        self?.inboxStatus = status
      }
    }
  }

  func markAddress(_ email: String, state: AddressState) {
    manage { [weak self] client in
      let result = try await client.markAddress(email, state: state)
      guard result.ok else {
        throw result.error ?? Self.managementFailure("Could not update the address.")
      }
      try await self?.loadLocalAddresses(using: client)
      self?.managementNotice = "Marked \(email) as \(state.rawValue)."
    }
  }

  func exportCSV() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.allowsMultipleSelection = false
    panel.prompt = "Export"
    guard panel.runModal() == .OK, let directory = panel.url else { return }

    manage { [weak self] client in
      let result = try await client.exportCSV(to: directory)
      guard result.ok else {
        throw result.error ?? Self.managementFailure("Could not export CSV files.")
      }
      self?.managementNotice = "Exported addresses.csv and messages.csv."
    }
  }

  private func export(_ lines: [String], suggestedName: String) {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = suggestedName
    panel.allowedContentTypes = [.plainText]
    guard panel.runModal() == .OK, let url = panel.url else { return }
    try? (lines.joined(separator: "\n") + "\n")
      .write(to: url, atomically: true, encoding: .utf8)
  }

  private func manage(_ operation: @escaping (CLIClient) async throws -> Void) {
    guard !isManaging, let managementClient else { return }
    isManaging = true
    managementError = nil
    managementNotice = nil
    Task {
      do {
        try await operation(managementClient)
      } catch {
        managementError = error.localizedDescription
      }
      isManaging = false
    }
  }

  private func loadLocalAddresses(using client: CLIClient) async throws {
    let result = try await client.localAddresses()
    guard result.ok else {
      throw result.error ?? Self.managementFailure("Could not load local addresses.")
    }
    localAddresses = result.addresses
  }

  private static func managementFailure(_ message: String) -> BridgeError {
    BridgeError(code: nil, message: message, retryAfter: nil)
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

    if let managementClient {
      try? await loadLocalAddresses(using: managementClient)
    }
    runState = .complete
    generationTask = nil
  }
}
