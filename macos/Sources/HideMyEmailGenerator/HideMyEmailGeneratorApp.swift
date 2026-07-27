import AppKit
@preconcurrency import Sparkle
import SwiftUI

enum UpdateStatus {
  case checking
  case current
  case available
  case unavailable

  var systemImage: String {
    self == .available ? "arrow.down.circle.fill" : "arrow.down.circle"
  }

  var help: String {
    switch self {
    case .checking:
      "Checking for updates…"
    case .current:
      "Check for Updates…"
    case .available:
      "An update is available. Click to review it."
    case .unavailable:
      "Unable to check for updates. Click to try again."
    }
  }
}

@MainActor
final class UpdateController: NSObject, ObservableObject, SPUUpdaterDelegate,
  SPUStandardUserDriverDelegate
{
  @Published private(set) var status = UpdateStatus.checking

  private lazy var controller = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: self,
    userDriverDelegate: self
  )

  override init() {
    super.init()
    controller.updater.checkForUpdatesInBackground()
  }

  func checkForUpdates() {
    status = .checking
    controller.checkForUpdates(nil)
  }

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    status = .available
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
    status = .current
  }

  func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
    status = .unavailable
  }

  nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

  nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
    _ update: SUAppcastItem,
    andInImmediateFocus immediateFocus: Bool
  ) -> Bool {
    false
  }

  nonisolated func standardUserDriverWillHandleShowingUpdate(
    _ handleShowingUpdate: Bool,
    forUpdate update: SUAppcastItem,
    state: SPUUserUpdateState
  ) {
    if !handleShowingUpdate {
      Task { @MainActor [weak self] in
        self?.status = .available
      }
    }
  }
}

@main
struct HideMyEmailGeneratorApp: App {
  @StateObject private var model = AppModel()
  @StateObject private var updater = UpdateController()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(model)
        .environmentObject(updater)
        .frame(minWidth: 640, minHeight: 420)
    }
    .defaultSize(width: 850, height: 540)
    .windowToolbarStyle(.unified)
  }
}

enum AppSection: String, CaseIterable, Identifiable {
  case generate
  case addresses
  case inbox
  case scheduler

  var id: Self { self }
  var title: String {
    switch self {
    case .generate: "Generate"
    case .addresses: "Addresses"
    case .inbox: "Inbox"
    case .scheduler: "Scheduler"
    }
  }
  var icon: String {
    switch self {
    case .generate: "plus.circle"
    case .addresses: "at"
    case .inbox: "tray"
    case .scheduler: "clock"
    }
  }
}

struct ContentView: View {
  @EnvironmentObject private var model: AppModel
  @EnvironmentObject private var updater: UpdateController
  @State private var selection = AppSection.generate
  @State private var showingAccount = false

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        List(AppSection.allCases, selection: $selection) { section in
          Label(section.title, systemImage: section.icon)
            .tag(section)
        }
        .listStyle(.sidebar)

        Divider()
        HStack(spacing: 8) {
          Text("No telemetry collected")
            .foregroundStyle(.secondary)

          Spacer(minLength: 4)

          Button { updater.checkForUpdates() } label: {
            Image(systemName: updater.status.systemImage)
              .foregroundStyle(updater.status == .available ? .green : .secondary)
          }
          .buttonStyle(.plain)
          .help(updater.status.help)
          .accessibilityLabel(updater.status.help)
        }
        .font(.caption)
        .padding(12)
      }
      .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
    } detail: {
      Group {
        if let helperError = model.helperError {
          VStack(spacing: 16) {
            MessageBanner(helperError, color: .red)
            Spacer()
          }
          .padding(24)
        } else {
          switch selection {
          case .generate:
            GenerateView()
          case .addresses:
            AddressesView()
          case .inbox:
            InboxView()
          case .scheduler:
            SchedulerView()
          }
        }
      }
      .navigationTitle(selection.title)
      .toolbar { accountToolbar }
    }
    .sheet(isPresented: $model.showingSignIn) {
      SignInSheet()
        .environmentObject(model)
    }
  }

  @ToolbarContentBuilder
  private var accountToolbar: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      if let session = model.session {
        Button {
          showingAccount = true
        } label: {
          Image(systemName: "checkmark.icloud.fill")
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Color(nsColor: .systemBlue))
            .imageScale(.large)
        }
        .buttonStyle(.plain)
        .help("Connected as \(session.account.name).")
        .accessibilityLabel("iCloud connected")
        .popover(isPresented: $showingAccount, arrowEdge: .bottom) {
          AccountPopover()
            .environmentObject(model)
        }
      } else {
        Button { model.reconnect() } label: {
          Text("Connect iCloud")
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.blue, in: Capsule())
        }
        .buttonStyle(.plain)
      }
    }
  }
}

struct GenerateView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        DetailHeader(
          title: "Generate addresses",
          subtitle: "Create Hide My Email addresses immediately.",
          systemImage: nil
        )

        VStack(alignment: .leading, spacing: 14) {
          Text("EMAIL DETAILS")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)

          LabeledContent("Label") {
            TextField("generated", text: $model.onDemandLabel)
              .textFieldStyle(.roundedBorder)
              .disabled(model.isBusy)
              .frame(maxWidth: 420)
          }
          Divider()
          LabeledContent("Quantity") {
            Stepper(value: $model.onDemandQuantity, in: 1...100) {
              Text("\(model.onDemandQuantity) emails")
                .monospacedDigit()
            }
          }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modernPanel()

        HStack {
          Button { model.generateOnDemand() } label: {
            if model.runKind == .onDemand, model.isBusy {
              ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Generating email")
            } else {
              Text(model.onDemandQuantity == 1 ? "Generate Email" : "Generate Emails")
            }
          }
            .modernPrimaryButton()
            .tint(.blue)
            .controlSize(.large)
            .disabled(!model.canGenerateOnDemand)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .frame(maxWidth: .infinity)

        if model.runKind == .onDemand {
          RunStatusView()
          CurrentRunResults()
        } else if model.isBusy {
          MessageBanner("The scheduler is currently running.", color: .blue)
        }
      }
      .frame(maxWidth: 620, alignment: .leading)
      .padding(24)
    }
  }
}

struct SchedulerView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        DetailHeader(
          title: "Scheduled generation",
          subtitle: "Generate continuously, then wait for the interval when Apple’s limit is reached.",
          systemImage: "calendar.badge.clock"
        )

        VStack(alignment: .leading, spacing: 14) {
          Text("SCHEDULE DETAILS")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)

          LabeledContent("Label") {
            TextField("generated", text: $model.schedulerLabel)
              .textFieldStyle(.roundedBorder)
              .frame(maxWidth: 420)
          }
          Divider()
          LabeledContent("Quantity") {
            Stepper(value: $model.schedulerTargetCount, in: 1...100) {
              Text("\(model.schedulerTargetCount) emails")
                .monospacedDigit()
            }
          }
          Divider()
          LabeledContent("Interval") {
            Stepper(
              value: $model.schedulerIntervalMinutes,
              in: SchedulerPolicy.allowedMinutes
            ) {
              Text("\(model.schedulerIntervalMinutes) minutes")
                .monospacedDigit()
            }
          }
        }
        .disabled(model.isBusy)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modernPanel()

        VStack(spacing: 10) {
          Text("Keep the app open while the schedule runs.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

          HStack {
            if model.runKind == .scheduler, model.isBusy {
              Button("Stop Scheduler", role: .destructive) { model.stopGeneration() }
                .modernButton()
                .controlSize(.large)
            } else {
              Button("Start Scheduler") { model.startScheduler() }
                .modernPrimaryButton()
                .tint(.blue)
                .controlSize(.large)
                .disabled(!model.canStartScheduler)
            }
          }
          .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, -4)

        if model.runKind == .scheduler {
          RunStatusView()
          CurrentRunResults()
        } else if model.isBusy {
          MessageBanner("An on-demand email is currently being generated.", color: .blue)
        }
      }
      .frame(maxWidth: 620, alignment: .leading)
      .padding(24)
    }
  }
}

enum AddressScope: String, CaseIterable, Identifiable {
  case local
  case icloud
  case history

  var id: Self { self }
  var title: String {
    switch self {
    case .local: "Local"
    case .icloud: "iCloud"
    case .history: "History"
    }
  }
}

enum LocalAddressFilter: String, CaseIterable, Identifiable {
  case all
  case unused
  case used
  case trash

  var id: Self { self }
  var title: String { rawValue.capitalized }
  var state: AddressState? { AddressState(rawValue: rawValue) }
}

struct AddressesView: View {
  @EnvironmentObject private var model: AppModel
  @State private var scope = AddressScope.local
  @State private var localFilter = LocalAddressFilter.all
  @State private var cloudActive = true
  @State private var search = ""

  private var filteredLocal: [LocalAddress] {
    model.localAddresses.filter { address in
      (localFilter.state == nil || address.state == localFilter.state)
        && matchesSearch(address.email, address.label)
    }
  }

  private var filteredCloud: [CloudAddress] {
    model.cloudAddresses.filter { matchesSearch($0.email, $0.label) }
  }

  private var filteredHistory: [GeneratedEmailRecord] {
    model.history.filter { matchesSearch($0.email, $0.label) }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Picker("Address source", selection: $scope) {
          ForEach(AddressScope.allCases) { item in
            Text(item.title).tag(item)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 270)

        Spacer()

        if model.isManaging {
          ProgressView()
            .controlSize(.small)
        }

        switch scope {
        case .local:
          Button("Sync iCloud") { model.syncICloudAddresses() }
            .disabled(model.session == nil || model.isManaging)
          Button("Export CSV…") { model.exportCSV() }
            .disabled(model.isManaging)
          Button { model.refreshLocalAddresses() } label: {
            Image(systemName: "arrow.clockwise")
          }
          .disabled(model.isManaging)
          .help("Refresh local addresses")
        case .icloud:
          Button("Sync to Local") { model.syncICloudAddresses() }
            .disabled(model.session == nil || model.isManaging)
          Button { model.refreshCloudAddresses(active: cloudActive) } label: {
            Image(systemName: "arrow.clockwise")
          }
          .disabled(model.session == nil || model.isManaging)
          .help("Refresh iCloud addresses")
        case .history:
          Button("Copy All") { model.copyHistory() }
            .disabled(model.history.isEmpty)
          Button("Export…") { model.exportHistory() }
            .disabled(model.history.isEmpty)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      Divider()

      VStack(spacing: 0) {
        if let error = model.managementError {
          MessageBanner(error, color: .red)
            .padding(12)
        } else if let notice = model.managementNotice {
          MessageBanner(notice, color: .green)
            .padding(12)
        }

        switch scope {
        case .local:
          localAddresses
        case .icloud:
          cloudAddresses
        case .history:
          historyAddresses
        }
      }
      .searchable(text: $search, placement: .toolbar, prompt: "Search addresses or labels")
    }
    .task {
      model.refreshLocalAddresses()
    }
    .onChange(of: scope) { newScope in
      if newScope == .local {
        model.refreshLocalAddresses()
      } else if newScope == .icloud {
        model.refreshCloudAddresses(active: cloudActive)
      }
    }
    .onChange(of: cloudActive) { active in
      if scope == .icloud {
        model.refreshCloudAddresses(active: active)
      }
    }
  }

  private var localAddresses: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        CountBadge(title: "All", count: model.localAddresses.count, color: .blue)
        ForEach(AddressState.allCases) { state in
          CountBadge(
            title: state.title,
            count: model.localAddresses.filter { $0.state == state }.count,
            color: stateColor(state)
          )
        }
        Spacer()
        Picker("State", selection: $localFilter) {
          ForEach(LocalAddressFilter.allCases) { filter in
            Text(filter.title).tag(filter)
          }
        }
        .labelsHidden()
        .frame(width: 120)
      }
      .padding(12)

      Divider()

      Table(filteredLocal) {
        TableColumn("Email") { address in
          CopyableAddress(address.email)
        }
        TableColumn("Label", value: \.label)
          .width(min: 90, ideal: 140)
        TableColumn("State") { address in
          Menu {
            ForEach(AddressState.allCases) { state in
              Button(state.title) {
                model.markAddress(address.email, state: state)
              }
            }
          } label: {
            StatusPill(
              title: address.state.title,
              color: stateColor(address.state)
            )
          }
          .menuStyle(.borderlessButton)
          .disabled(model.isManaging)
        }
        .width(min: 80, ideal: 90)
        TableColumn("Updated") { address in
          Text(compactTimestamp(address.updatedAt))
            .foregroundStyle(.secondary)
        }
        .width(min: 130, ideal: 160)
      }
      .overlay {
        if filteredLocal.isEmpty {
          EmptyState(
            icon: "at.badge.plus",
            title: "No local addresses",
            message: "Generate an address or sync your iCloud inventory."
          )
        }
      }
    }
  }

  private var cloudAddresses: some View {
    VStack(spacing: 0) {
      HStack {
        Picker("iCloud status", selection: $cloudActive) {
          Text("Active").tag(true)
          Text("Inactive").tag(false)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 180)
        Spacer()
        Text("\(filteredCloud.count) \(cloudActive ? "active" : "inactive")")
          .foregroundStyle(.secondary)
      }
      .padding(12)

      Divider()

      Table(filteredCloud) {
        TableColumn("Email") { address in
          CopyableAddress(address.email)
        }
        TableColumn("Label", value: \.label)
          .width(min: 100, ideal: 180)
        TableColumn("Created") { address in
          Text(compactTimestamp(address.createdAt))
            .foregroundStyle(.secondary)
        }
        .width(min: 130, ideal: 160)
      }
      .overlay {
        if filteredCloud.isEmpty {
          EmptyState(
            icon: cloudActive ? "icloud" : "icloud.slash",
            title: cloudActive ? "No active addresses" : "No inactive addresses",
            message: model.session == nil
              ? "Connect iCloud to load your inventory."
              : "Refresh to check your current iCloud inventory."
          )
        }
      }
    }
  }

  private var historyAddresses: some View {
    Table(filteredHistory) {
      TableColumn("Email") { record in
        CopyableAddress(record.email)
      }
      TableColumn("Label", value: \.label)
        .width(min: 90, ideal: 130)
      TableColumn("Generated") { record in
        Text(record.generatedAt.formatted(date: .abbreviated, time: .shortened))
      }
      .width(min: 130, ideal: 160)
    }
    .overlay {
      if filteredHistory.isEmpty {
        EmptyState(
          icon: "clock.arrow.circlepath",
          title: "No generated history",
          message: "Newly generated addresses will appear here."
        )
      }
    }
  }

  private func matchesSearch(_ email: String, _ label: String) -> Bool {
    let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return query.isEmpty || email.lowercased().contains(query) || label.lowercased().contains(query)
  }
}

enum InboxScope: String, CaseIterable, Identifiable {
  case messages
  case codes

  var id: Self { self }
  var title: String { rawValue.capitalized }
}

struct InboxView: View {
  @EnvironmentObject private var model: AppModel
  @State private var scope = InboxScope.messages
  @State private var selectedMessageID: String?
  @State private var showingSettings = false

  private var rows: [InboxMessage] {
    scope == .codes ? model.verificationCodes : model.inboxMessages
  }

  private var selectedMessage: InboxMessage? {
    rows.first { $0.id == selectedMessageID }
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        if let summary = model.inboxStatus?.config {
          VStack(alignment: .leading, spacing: 2) {
            Text(summary.username)
              .font(.headline)
            Text("\(summary.host):\(summary.port) · \(summary.folder)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } else {
          VStack(alignment: .leading, spacing: 2) {
            Text("Local inbox")
              .font(.headline)
            Text("Mail and verification codes stay on this Mac.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        if model.isManaging {
          ProgressView()
            .controlSize(.small)
        }
        Button(model.hasInboxConfiguration ? "Settings…" : "Configure…") {
          showingSettings = true
        }
        Button("Sync") { model.syncInbox() }
          .disabled(!model.hasInboxConfiguration || model.isManaging)
        Button("Export CSV…") { model.exportCSV() }
          .disabled(model.isManaging)
        Button { model.refreshInbox() } label: {
          Image(systemName: "arrow.clockwise")
        }
        .disabled(model.isManaging)
        .help("Refresh local inbox")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      Divider()

      if !model.hasInboxConfiguration && model.inboxMessages.isEmpty {
        ScrollView {
          InboxSettingsPanel()
            .environmentObject(model)
            .frame(maxWidth: 560)
            .padding(24)
        }
      } else {
        inboxContent
      }
    }
    .task {
      model.refreshInbox()
    }
    .sheet(isPresented: $showingSettings) {
      VStack(spacing: 0) {
        HStack {
          Text("Inbox Settings")
            .font(.headline)
          Spacer()
          Button("Done") { showingSettings = false }
        }
        .padding(16)
        Divider()
        InboxSettingsPanel()
          .environmentObject(model)
          .padding(20)
      }
      .frame(width: 560)
    }
  }

  private var inboxContent: some View {
    VStack(spacing: 0) {
      if let error = model.managementError {
        MessageBanner(error, color: .red)
          .padding(12)
      } else if let notice = model.managementNotice {
        MessageBanner(notice, color: .green)
          .padding(12)
      }

      HStack(spacing: 8) {
        CountBadge(
          title: "Addresses",
          count: model.inboxStatus?.counts?.addresses ?? model.localAddresses.count,
          color: .blue
        )
        CountBadge(
          title: "Messages",
          count: model.inboxStatus?.counts?.messages ?? model.inboxMessages.count,
          color: .indigo
        )
        CountBadge(
          title: "Codes",
          count: model.inboxStatus?.counts?.codes ?? model.verificationCodes.count,
          color: .green
        )
        Spacer()
        Picker("Inbox view", selection: $scope) {
          ForEach(InboxScope.allCases) { item in
            Text(item.title).tag(item)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 190)
      }
      .padding(12)

      Divider()

      Table(rows, selection: $selectedMessageID) {
        TableColumn("Received") { message in
          Text(compactTimestamp(message.receivedAt ?? ""))
            .foregroundStyle(.secondary)
        }
        .width(min: 120, ideal: 145)
        TableColumn("Hide My Email") { message in
          Text(message.hmeAddress ?? "—")
            .font(.system(.body, design: .monospaced))
            .lineLimit(1)
        }
        .width(min: 150, ideal: 210)
        TableColumn("Sender") { message in
          Text(message.sender ?? "—")
            .lineLimit(1)
        }
        .width(min: 120, ideal: 180)
        TableColumn("Subject") { message in
          Text(message.subject ?? "—")
            .lineLimit(1)
        }
        TableColumn("Code") { message in
          if let code = message.code, !code.isEmpty {
            HStack {
              Text(code)
                .font(.system(.body, design: .monospaced).weight(.semibold))
              Button { model.copy(code) } label: {
                Image(systemName: "doc.on.doc")
              }
              .buttonStyle(.borderless)
              .accessibilityLabel("Copy code \(code)")
            }
          } else {
            Text("—")
              .foregroundStyle(.tertiary)
          }
        }
        .width(min: 90, ideal: 120)
      }
      .overlay {
        if rows.isEmpty {
          EmptyState(
            icon: scope == .codes ? "number.square" : "tray",
            title: scope == .codes ? "No verification codes" : "No inbox messages",
            message: "Sync the receiving mailbox to fetch recent mail."
          )
        }
      }

      if let message = selectedMessage {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text(message.subject ?? "Message")
              .font(.headline)
            Spacer()
            if let code = message.code, !code.isEmpty {
              Button("Copy \(code)") { model.copy(code) }
            }
          }
          Text(message.bodyPreview ?? "No message preview available.")
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .lineLimit(5)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 105, alignment: .topLeading)
        .background(.quaternary.opacity(0.2))
      }
    }
  }
}

struct InboxSettingsPanel: View {
  @EnvironmentObject private var model: AppModel

  private var canSave: Bool {
    model.inboxSettings.isComplete && !model.inboxPassword.isEmpty && !model.isManaging
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      DetailHeader(
        title: "Connect a receiving mailbox",
        subtitle: "Use an app password when your mail provider supports one.",
        systemImage: "lock.shield"
      )

      VStack(alignment: .leading, spacing: 12) {
        LabeledContent("IMAP host") {
          TextField("imap.example.com", text: $model.inboxSettings.host)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 320)
        }
        LabeledContent("Port") {
          TextField("993", value: $model.inboxSettings.port, format: .number)
            .textFieldStyle(.roundedBorder)
            .frame(width: 100)
        }
        LabeledContent("Username") {
          TextField("you@example.com", text: $model.inboxSettings.username)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 320)
        }
        LabeledContent("Password") {
          SecureField("App password", text: $model.inboxPassword)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 320)
        }
        LabeledContent("Folder") {
          TextField("INBOX", text: $model.inboxSettings.folder)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 180)
        }
        Toggle("Use SSL", isOn: $model.inboxSettings.useSSL)
      }
      .padding(18)
      .modernPanel()

      if let error = model.managementError {
        MessageBanner(error, color: .red)
      }

      HStack {
        Spacer()
        Button { model.saveInboxConfiguration() } label: {
          Text("Save Settings")
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.blue, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.45)
        Spacer()
      }
      .frame(maxWidth: .infinity)
      .overlay(alignment: .leading) {
        if model.hasInboxConfiguration {
          Button("Remove Credentials", role: .destructive) {
            model.clearInboxConfiguration()
          }
        }
      }
    }
  }
}

struct DetailHeader: View {
  let title: String
  let subtitle: String
  let systemImage: String?

  var body: some View {
    HStack(spacing: 12) {
      if let systemImage {
        Image(systemName: systemImage)
          .font(.title2.weight(.semibold))
          .foregroundStyle(.tint)
          .frame(width: 40, height: 40)
          .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
      } else {
        Image(nsImage: NSApplication.shared.applicationIconImage)
          .resizable()
          .scaledToFit()
          .frame(width: 40, height: 40)
      }

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.title2.bold())
        Text(subtitle)
          .foregroundStyle(.secondary)
      }
    }
  }
}

extension View {
  @ViewBuilder
  func modernPanel() -> some View {
#if compiler(>=6.2)
    if #available(macOS 26.0, *) {
      glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    } else {
      background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
          RoundedRectangle(cornerRadius: 18)
            .stroke(.separator.opacity(0.5))
        }
    }
#else
    background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .stroke(.separator.opacity(0.5))
      }
#endif
  }

  @ViewBuilder
  func modernPrimaryButton() -> some View {
#if compiler(>=6.2)
    if #available(macOS 26.0, *) {
      buttonStyle(.glass(.regular.tint(.blue)))
    } else {
      buttonStyle(.borderedProminent)
    }
#else
    buttonStyle(.borderedProminent)
#endif
  }

  @ViewBuilder
  func modernButton() -> some View {
#if compiler(>=6.2)
    if #available(macOS 26.0, *) {
      buttonStyle(.glass)
    } else {
      buttonStyle(.bordered)
    }
#else
    buttonStyle(.bordered)
#endif
  }
}

struct RunStatusView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    switch model.runState {
    case .idle:
      EmptyView()
    case .running:
      progressBox(
        title: model.runKind == .scheduler ? "Generating scheduled email…" : "Generating…",
        detail: "Connecting to iCloud Hide My Email."
      )
    case .coolingDown(let until):
      TimelineView(.periodic(from: .now, by: 1)) { context in
        progressBox(
          title: "Apple’s limit was reached",
          detail: "Trying again in \(remaining(until: until, now: context.date))."
        )
      }
    case .needsAuthentication:
      HStack {
        MessageBanner("Your iCloud session needs to be reconnected.", color: .orange)
        Button("Reconnect") { model.reconnect() }
      }
    case .failed(let message):
      MessageBanner(message, color: .red)
    case .complete:
      Text(
        "Complete — generated \(model.generatedEmails.count) address\(model.generatedEmails.count == 1 ? "" : "es")."
      )
      .textSelection(.enabled)
      .frame(maxWidth: .infinity, alignment: .center)
      .padding(11)
      .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
  }

  private func progressBox(title: String, detail: String) -> some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 9) {
        HStack {
          Text(title).font(.headline)
          Spacer()
          Text("\(model.generatedEmails.count) of \(model.currentTarget)")
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        ProgressView(value: model.progress)
        Text(detail)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .padding(6)
    }
  }

  private func remaining(until: Date, now: Date) -> String {
    let seconds = max(0, Int(until.timeIntervalSince(now)))
    return String(format: "%02d:%02d", seconds / 60, seconds % 60)
  }
}

struct CurrentRunResults: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    if !model.generatedEmails.isEmpty {
      GroupBox {
        VStack(spacing: 0) {
          ForEach(model.generatedEmails, id: \.self) { email in
            HStack {
              Text(email)
                .textSelection(.enabled)
                .font(.system(.body, design: .monospaced))
              Spacer()
              Button {
                model.copy(email)
              } label: {
                Image(systemName: "doc.on.doc")
              }
              .buttonStyle(.borderless)
              .accessibilityLabel("Copy \(email)")
            }
            .padding(.vertical, 6)
            if email != model.generatedEmails.last {
              Divider()
            }
          }
          HStack {
            Spacer()
            Button("Copy All") { model.copyAll() }
            Button("Export…") { model.exportResults() }
          }
          .padding(.top, 8)
        }
        .padding(6)
      }
    }
  }
}

struct CopyableAddress: View {
  @EnvironmentObject private var model: AppModel
  let email: String

  init(_ email: String) {
    self.email = email
  }

  var body: some View {
    HStack {
      Text(email)
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
        .lineLimit(1)
      Spacer()
      Button { model.copy(email) } label: {
        Image(systemName: "doc.on.doc")
      }
      .buttonStyle(.borderless)
      .help("Copy address")
      .accessibilityLabel("Copy \(email)")
    }
  }
}

struct CountBadge: View {
  let title: String
  let count: Int
  let color: Color

  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 7, height: 7)
      Text(title)
        .foregroundStyle(.secondary)
      Text("\(count)")
        .fontWeight(.semibold)
        .monospacedDigit()
    }
    .font(.caption)
    .padding(.horizontal, 9)
    .padding(.vertical, 5)
    .background(color.opacity(0.08), in: Capsule())
  }
}

struct StatusPill: View {
  let title: String
  let color: Color

  var body: some View {
    Text(title)
      .font(.caption.weight(.semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(color.opacity(0.1), in: Capsule())
  }
}

struct EmptyState: View {
  let icon: String
  let title: String
  let message: String

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 30))
        .foregroundStyle(.secondary)
      Text(title)
        .font(.headline)
      Text(message)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(24)
  }
}

struct AccountPopover: View {
  @EnvironmentObject private var model: AppModel
  @State private var confirmingSignOut = false

  var body: some View {
    if let session = model.session {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 10) {
          Image(systemName: "checkmark.icloud.fill")
            .font(.title2)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, .blue)
          VStack(alignment: .leading, spacing: 2) {
            Text(session.account.name)
              .font(.headline)
            Text(session.account.appleID)
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
          Spacer()
          if model.isManaging {
            ProgressView()
              .controlSize(.small)
          }
        }

        Divider()

        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
          accountRow("Region", session.region.title)
          accountRow(
            "Hide My Email",
            session.account.hideMyEmailAvailable ? "Available" : "Unavailable"
          )
          accountRow(
            "Partition",
            session.account.userPartition.map(String.init) ?? "Unknown"
          )
          accountRow("Maildomain", session.account.maildomainHost)
          if let dsid = session.account.dsid, !dsid.isEmpty {
            accountRow("DSID", "••••\(dsid.suffix(4))")
          }
        }
        .font(.subheadline)

        if let error = model.managementError {
          Text(error)
            .font(.caption)
            .foregroundStyle(.red)
        }

        Divider()

        HStack {
          Button("Refresh") { model.refreshAccount() }
            .disabled(model.isManaging)
          Button("Reconnect") { model.reconnect() }
          Spacer()
          Button("Sign Out", role: .destructive) {
            confirmingSignOut = true
          }
        }
      }
      .padding(16)
      .frame(width: 350)
      .confirmationDialog(
        "Would you like to sign out?",
        isPresented: $confirmingSignOut,
        titleVisibility: .visible
      ) {
        Button("Sign Out", role: .destructive) { model.signOut() }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text("This removes the saved iCloud session cookie from this Mac.")
      }
    }
  }

  @ViewBuilder
  private func accountRow(_ title: String, _ value: String) -> some View {
    GridRow {
      Text(title)
        .foregroundStyle(.secondary)
      Text(value)
        .textSelection(.enabled)
    }
  }
}

struct MessageBanner: View {
  let message: String
  let color: Color

  init(_ message: String, color: Color) {
    self.message = message
    self.color = color
  }

  var body: some View {
    HStack(spacing: 9) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)
      Text(message)
        .textSelection(.enabled)
      Spacer()
    }
    .padding(11)
    .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}

func stateColor(_ state: AddressState) -> Color {
  switch state {
  case .unused: .blue
  case .used: .green
  case .trash: .secondary
  }
}

func compactTimestamp(_ value: String) -> String {
  guard !value.isEmpty else { return "—" }
  let formatter = ISO8601DateFormatter()
  guard let date = formatter.date(from: value) else {
    return value.replacingOccurrences(of: "T", with: " ").prefix(16).description
  }
  return date.formatted(date: .abbreviated, time: .shortened)
}

struct SignInSheet: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var stage = ICloudSignInStage.opening
  @State private var signInAttempt = UUID()

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Connect iCloud")
            .font(.headline)
          Text("Complete Apple’s authentication prompt.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Picker("Region", selection: $model.signInRegion) {
          ForEach(ICloudRegion.allCases) { region in
            Text(region.title).tag(region)
          }
        }
        .labelsHidden()
        .frame(width: 110)
        .disabled(model.isConnecting)
        Button("Cancel") { dismiss() }
      }
      .padding(16)

      Divider()

      ZStack {
        ICloudWebView(
          region: model.signInRegion,
          onStageChange: { newStage in
            withAnimation(.easeOut(duration: 0.15)) {
              stage = newStage
            }
          },
          onCookieHeader: { cookieHeader in
            model.connect(cookieHeader: cookieHeader, region: model.signInRegion)
          }
        )
        .id("\(model.signInRegion.rawValue)-\(signInAttempt)")

        if stage != .authentication {
          ZStack {
            Color(nsColor: .windowBackgroundColor)
            if stage == .failed || model.connectionError != nil {
              VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .font(.title)
                  .foregroundStyle(.orange)
                Text("Couldn’t capture the iCloud session.")
                  .font(.headline)
                Text("Try Apple’s sign-in again or import a cookie file below.")
                  .foregroundStyle(.secondary)
                Button("Try Again") {
                  model.reconnect()
                  stage = .opening
                  signInAttempt = UUID()
                }
                .buttonStyle(.borderedProminent)
              }
            } else {
              VStack(spacing: 12) {
                ProgressView()
                  .controlSize(.large)
                Text(
                  stage == .capturing
                    ? "Finishing iCloud connection…" : "Opening Apple Account…"
                )
                .font(.headline)
                Text("The iCloud website runs only in the background.")
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }

      Divider()

      HStack {
        if model.isConnecting {
          ProgressView()
            .controlSize(.small)
          Text("Validating the local iCloud session…")
            .foregroundStyle(.secondary)
        } else if let error = model.connectionError {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
          Text(error)
            .lineLimit(2)
            .foregroundStyle(.secondary)
        } else {
          Label("Credentials stay with Apple.", systemImage: "lock")
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Import Cookie File…") {
          let panel = NSOpenPanel()
          panel.canChooseDirectories = false
          panel.allowsMultipleSelection = false
          if panel.runModal() == .OK, let url = panel.url {
            model.importCookie(from: url, region: model.signInRegion)
          }
        }
        .disabled(model.isConnecting)
      }
      .font(.subheadline)
      .padding(12)
    }
    .frame(width: 700, height: 520)
  }
}
