import Foundation
import OSLog
import SwiftUI
import WebKit

let iCloudSignInLog = Logger(
  subsystem: Bundle.main.bundleIdentifier ?? "HideMyEmailGenerator",
  category: "iCloudSignIn"
)

enum ICloudCookieHeader {
  private static let requiredCookieName = "X-APPLE-WEBAUTH-USER"

  static func make(from request: URLRequest, region: ICloudRegion) -> String? {
    guard isCaptureRequest(request, region: region),
      let header = request.value(forHTTPHeaderField: "Cookie"),
      containsRequiredCookie(header)
    else {
      return nil
    }
    return header
  }

  static func make(from cookies: [HTTPCookie], region: ICloudRegion) -> String? {
    let relevant = cookies.filter {
      let domain = $0.domain.lowercased().trimmingCharacters(
        in: CharacterSet(charactersIn: "."))
      return domain == region.cookieDomainSuffix
        || domain.hasSuffix(".\(region.cookieDomainSuffix)")
    }
    guard
      relevant.contains(where: {
        $0.name.caseInsensitiveCompare(requiredCookieName) == .orderedSame
      })
    else {
      return nil
    }

    var byName: [String: HTTPCookie] = [:]
    for cookie in relevant {
      if let existing = byName[cookie.name],
        existing.domain.count >= cookie.domain.count
      {
        continue
      }
      byName[cookie.name] = cookie
    }
    let header = byName.values
      .sorted { $0.name < $1.name }
      .map { "\($0.name)=\($0.value)" }
      .joined(separator: "; ")
    return header.isEmpty ? nil : header
  }

  static func isCaptureRequest(_ request: URLRequest, region: ICloudRegion) -> Bool {
    guard let url = request.url,
      url.scheme == "https",
      url.host?.caseInsensitiveCompare(region.hideMyEmailURL.host ?? "") == .orderedSame,
      url.path == region.hideMyEmailURL.path
    else {
      return false
    }
    return URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?
      .contains { $0.name == "rootDomain" && $0.value == "www" } == true
  }

  private static func containsRequiredCookie(_ header: String) -> Bool {
    header.split(separator: ";").contains {
      $0.split(separator: "=", maxSplits: 1).first?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .caseInsensitiveCompare(requiredCookieName) == .orderedSame
    }
  }
}

enum ICloudSignInStage: Equatable {
  case opening
  case authentication
  case capturing
  case failed
}

struct ICloudWebView: NSViewRepresentable {
  let region: ICloudRegion
  let onStageChange: (ICloudSignInStage) -> Void
  let onCookieHeader: (String) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(
      region: region,
      onStageChange: onStageChange,
      onCookieHeader: onCookieHeader
    )
  }

  func makeNSView(context: Context) -> WKWebView {
    iCloudSignInLog.notice("Creating fresh ephemeral web view for \(region.rawValue, privacy: .public)")
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

    let webView = WKWebView(frame: .zero, configuration: configuration)
    context.coordinator.webView = webView
    webView.navigationDelegate = context.coordinator
    webView.uiDelegate = context.coordinator
    configuration.websiteDataStore.httpCookieStore.add(context.coordinator)
    webView.load(URLRequest(url: region.signInURL))
    return webView
  }

  func updateNSView(_ webView: WKWebView, context: Context) {}

  static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
    iCloudSignInLog.notice("Dismantling ephemeral web view")
    webView.configuration.websiteDataStore.httpCookieStore.remove(coordinator)
    coordinator.stop()
    webView.stopLoading()
  }

  final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
    let region: ICloudRegion
    let onStageChange: (ICloudSignInStage) -> Void
    let onCookieHeader: (String) -> Void
    weak var webView: WKWebView?
    private var inspectionWorkItem: DispatchWorkItem?
    private var authenticationWorkItem: DispatchWorkItem?
    private var captureTimeoutWorkItem: DispatchWorkItem?
    private var authenticationTimer: Timer?
    private var hasOpenedHideMyEmail = false
    private var hasCapturedCookie = false

    init(
      region: ICloudRegion,
      onStageChange: @escaping (ICloudSignInStage) -> Void,
      onCookieHeader: @escaping (String) -> Void
    ) {
      self.region = region
      self.onStageChange = onStageChange
      self.onCookieHeader = onCookieHeader
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
      iCloudSignInLog.notice("Cookie store changed; scheduling fallback snapshot")
      scheduleInspection(cookieStore)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      if webView.url?.path.contains("/applications/hidemyemail/current/") == true {
        iCloudSignInLog.notice("Hide My Email navigation finished")
        authenticationWorkItem?.cancel()
        beginCapture()
        scheduleInspection(webView.configuration.websiteDataStore.httpCookieStore)
        return
      }

      webView.evaluateJavaScript(
        """
        (() => {
          const signIn = document.querySelector(".sign-in-button");
          if (signIn && !window.__hideMyEmailAutoSignIn) {
            window.__hideMyEmailAutoSignIn = true;
            signIn.click();
            return "sign-in";
          }
          return "waiting";
        })();
        """
      ) { [weak self] result, _ in
        guard let self, let result = result as? String else { return }
        iCloudSignInLog.notice("Sign-in page state: \(result, privacy: .public)")
        self.startAuthenticationPolling(webView)
        if result == "sign-in" {
          let item = DispatchWorkItem { [weak self] in
            self?.onStageChange(.authentication)
          }
          self.authenticationWorkItem = item
          DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: item)
        } else {
          self.onStageChange(.authentication)
        }
      }
      scheduleInspection(webView.configuration.websiteDataStore.httpCookieStore)
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
      guard ICloudCookieHeader.isCaptureRequest(navigationAction.request, region: region)
      else {
        decisionHandler(.allow)
        return
      }

      let hasRequestCookieHeader =
        navigationAction.request.value(forHTTPHeaderField: "Cookie") != nil
      iCloudSignInLog.notice(
        "Intercepted Hide My Email request; request cookie header present: \(hasRequestCookieHeader)"
      )
      beginCapture()
      if let header = ICloudCookieHeader.make(from: navigationAction.request, region: region) {
        iCloudSignInLog.notice("Request cookie header passed validation")
        capture(header)
        decisionHandler(.allow)
        return
      }

      webView.configuration.websiteDataStore.httpCookieStore.getAllCookies {
        [weak self] cookies in
        let hasValidCookie = self.map {
          ICloudCookieHeader.make(from: cookies, region: $0.region) != nil
        } ?? false
        iCloudSignInLog.notice(
          "Pre-navigation cookie snapshot count: \(cookies.count); valid session present: \(hasValidCookie)"
        )
        if let self,
          let header = ICloudCookieHeader.make(from: cookies, region: self.region)
        {
          self.capture(header)
        }
        decisionHandler(.allow)
      }
    }

    func webView(
      _ webView: WKWebView,
      createWebViewWith configuration: WKWebViewConfiguration,
      for navigationAction: WKNavigationAction,
      windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
      if navigationAction.targetFrame == nil {
        webView.load(navigationAction.request)
      }
      return nil
    }

    func stop() {
      inspectionWorkItem?.cancel()
      authenticationWorkItem?.cancel()
      captureTimeoutWorkItem?.cancel()
      authenticationTimer?.invalidate()
    }

    private func startAuthenticationPolling(_ webView: WKWebView) {
      authenticationTimer?.invalidate()
      authenticationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
        [weak self, weak webView] _ in
        guard let self, let webView else { return }
        webView.evaluateJavaScript(
          """
          Boolean(document.querySelector(
            '.cloudos-toolbar.page, a[href$="/plan"], a[href$="/storage"]'
          ))
          """
        ) { [weak self, weak webView] result, _ in
          guard result as? Bool == true, let self, let webView else { return }
          iCloudSignInLog.notice("Apple post-authentication page confirmed")
          self.openHideMyEmail(in: webView)
        }
      }
    }

    private func openHideMyEmail(in webView: WKWebView) {
      guard !hasOpenedHideMyEmail else { return }
      iCloudSignInLog.notice("Starting Hide My Email navigation")
      hasOpenedHideMyEmail = true
      authenticationTimer?.invalidate()
      authenticationWorkItem?.cancel()
      beginCapture()
      webView.load(URLRequest(url: region.hideMyEmailURL))
    }

    private func beginCapture() {
      guard !hasCapturedCookie else { return }
      authenticationWorkItem?.cancel()
      onStageChange(.capturing)
      guard captureTimeoutWorkItem == nil else { return }

      let item = DispatchWorkItem { [weak self] in
        guard let self, !self.hasCapturedCookie else { return }
        self.captureTimeoutWorkItem = nil
        iCloudSignInLog.error("Cookie capture timed out")
        self.onStageChange(.failed)
      }
      captureTimeoutWorkItem = item
      DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: item)
    }

    private func scheduleInspection(_ store: WKHTTPCookieStore) {
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.inspectionWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
          self?.inspect(store)
        }
        self.inspectionWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75, execute: item)
      }
    }

    private func inspect(_ store: WKHTTPCookieStore) {
      store.getAllCookies { [weak self] cookies in
        guard let self else { return }
        guard let header = ICloudCookieHeader.make(from: cookies, region: self.region) else {
          iCloudSignInLog.notice(
            "Fallback cookie snapshot count: \(cookies.count); valid session present: false"
          )
          return
        }
        iCloudSignInLog.notice(
          "Fallback cookie snapshot count: \(cookies.count); valid session present: true"
        )
        self.capture(header)
      }
    }

    private func capture(_ header: String) {
      DispatchQueue.main.async { [weak self] in
        guard let self, !self.hasCapturedCookie else { return }
        self.hasCapturedCookie = true
        self.captureTimeoutWorkItem?.cancel()
        self.captureTimeoutWorkItem = nil
        iCloudSignInLog.notice("Delivering captured session for local validation")
        self.onCookieHeader(header)
      }
    }
  }
}
