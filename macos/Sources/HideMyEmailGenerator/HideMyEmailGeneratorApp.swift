import AppKit
import SwiftUI

@main
struct HideMyEmailGeneratorApp: App {
  @StateObject private var model = AppModel()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(model)
        .frame(minWidth: 640, minHeight: 420)
    }
    .defaultSize(width: 760, height: 520)
    .windowToolbarStyle(.unified)
  }
}

enum AppSection: String, CaseIterable, Identifiable {
  case generate
  case emails
  case scheduler

  var id: Self { self }
  var title: String {
    switch self {
    case .generate: "Generate"
    case .emails: "Emails"
    case .scheduler: "Scheduler"
    }
  }
  var icon: String {
    switch self {
    case .generate: "plus.circle"
    case .emails: "envelope"
    case .scheduler: "clock"
    }
  }
}

struct ContentView: View {
  @EnvironmentObject private var model: AppModel
  @State private var selection = AppSection.generate

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        List(AppSection.allCases, selection: $selection) { section in
          Label(section.title, systemImage: section.icon)
            .tag(section)
        }
        .listStyle(.sidebar)

        Divider()
        Label("Local only · No telemetry", systemImage: "lock.shield")
          .font(.caption)
          .foregroundStyle(.secondary)
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
          case .emails:
            EmailHistoryView()
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
        Menu {
          Button("Reconnect…") { model.reconnect() }
          Divider()
          Button("Sign Out", role: .destructive) { model.signOut() }
        } label: {
          Label(session.account.name, systemImage: "person.crop.circle.fill")
        }
      } else {
        Button("Connect iCloud") { model.reconnect() }
          .buttonStyle(.borderedProminent)
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
          title: "Generate one address",
          subtitle: "Create a Hide My Email address immediately."
        )

        GroupBox {
          Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
            GridRow {
              Text("Label")
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
              TextField("generated", text: $model.onDemandLabel)
                .textFieldStyle(.roundedBorder)
                .disabled(model.isBusy)
                .frame(maxWidth: 420)
            }
          }
          .padding(8)
        }

        HStack {
          Button("Generate Email") { model.generateOnDemand() }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.canGenerateOnDemand)
            .keyboardShortcut(.return, modifiers: .command)
          if model.runKind == .onDemand, model.isBusy {
            Button("Stop", role: .destructive) { model.stopGeneration() }
          }
        }

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
          subtitle: "Create one address per interval until the target is complete."
        )

        GroupBox {
          Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 14) {
            GridRow {
              Text("Label")
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
              TextField("generated", text: $model.schedulerLabel)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)
            }
            GridRow {
              Text("Target")
                .foregroundStyle(.secondary)
              Stepper(value: $model.schedulerTargetCount, in: 1...100) {
                Text("\(model.schedulerTargetCount) emails")
                  .monospacedDigit()
              }
            }
            GridRow {
              Text("Interval")
                .foregroundStyle(.secondary)
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
          .padding(8)
        }

        HStack {
          if model.runKind == .scheduler, model.isBusy {
            Button("Stop Scheduler", role: .destructive) { model.stopGeneration() }
          } else {
            Button("Start Scheduler") { model.startScheduler() }
              .buttonStyle(.borderedProminent)
              .controlSize(.large)
              .disabled(!model.canStartScheduler)
          }
          Text("Keep the app open while the schedule runs.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

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

struct EmailHistoryView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("\(model.history.count) generated")
          .foregroundStyle(.secondary)
        Spacer()
        Button("Copy All") { model.copyHistory() }
          .disabled(model.history.isEmpty)
        Button("Export…") { model.exportHistory() }
          .disabled(model.history.isEmpty)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)

      Divider()

      Table(model.history) {
        TableColumn("Email") { record in
          HStack {
            Text(record.email)
              .font(.system(.body, design: .monospaced))
              .textSelection(.enabled)
            Spacer()
            Button {
              model.copy(record.email)
            } label: {
              Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy address")
            .accessibilityLabel("Copy \(record.email)")
          }
        }
        TableColumn("Label", value: \.label)
          .width(min: 90, ideal: 130)
        TableColumn("Generated") { record in
          Text(
            record.generatedAt.formatted(
              date: .abbreviated,
              time: .shortened
            )
          )
        }
        .width(min: 130, ideal: 160)
      }
      .overlay {
        if model.history.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "envelope.open")
              .font(.system(size: 32))
              .foregroundStyle(.secondary)
            Text("No generated emails")
              .font(.headline)
            Text("New addresses will appear here.")
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}

struct DetailHeader: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.title2.bold())
      Text(subtitle)
        .foregroundStyle(.secondary)
    }
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
    case .waiting(let until):
      TimelineView(.periodic(from: .now, by: 1)) { context in
        progressBox(
          title: "Waiting for the next scheduled email",
          detail: "Next attempt in \(remaining(until: until, now: context.date))."
        )
      }
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
      MessageBanner(
        "Complete — generated \(model.generatedEmails.count) address\(model.generatedEmails.count == 1 ? "" : "es").",
        color: .green
      )
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
      GroupBox("Current run") {
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

struct SignInSheet: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var stage = ICloudSignInStage.opening

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
        .id(model.signInRegion)

        if stage != .authentication {
          ZStack {
            Color(nsColor: .windowBackgroundColor)
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
