import Foundation
import SwiftUI
import WebKit

enum ICloudCookieHeader {
  static func make(from cookies: [HTTPCookie], region: ICloudRegion) -> String? {
    let relevant = cookies.filter {
      let domain = $0.domain.lowercased().trimmingCharacters(
        in: CharacterSet(charactersIn: "."))
      return domain == region.cookieDomainSuffix
        || domain.hasSuffix(".\(region.cookieDomainSuffix)")
    }
    guard
      relevant.contains(where: {
        $0.name.caseInsensitiveCompare("X-APPLE-WEBAUTH-USER") == .orderedSame
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
}

enum ICloudSignInStage: Equatable {
  case opening
  case authentication
  case capturing
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
    private var authenticationTimer: Timer?
    private var hasOpenedHideMyEmail = false

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
      scheduleInspection(cookieStore)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
      if webView.url?.path.contains("/applications/hidemyemail/current/") == true {
        authenticationWorkItem?.cancel()
        onStageChange(.capturing)
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
          return signIn ? "waiting" : "authenticated";
        })();
        """
      ) { [weak self] result, _ in
        guard let self, let result = result as? String else { return }
        if result == "sign-in" {
          self.startAuthenticationPolling(webView)
          let item = DispatchWorkItem { [weak self] in
            self?.onStageChange(.authentication)
          }
          self.authenticationWorkItem = item
          DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: item)
        } else if result == "authenticated" {
          self.openHideMyEmail(in: webView)
        }
      }
      scheduleInspection(webView.configuration.websiteDataStore.httpCookieStore)
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
      authenticationTimer?.invalidate()
    }

    private func startAuthenticationPolling(_ webView: WKWebView) {
      authenticationTimer?.invalidate()
      authenticationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
        [weak self, weak webView] _ in
        guard let self, let webView else { return }
        webView.evaluateJavaScript(
          """
          Boolean(document.querySelector('a[href$="/plan"], a[href$="/storage"]'))
          """
        ) { [weak self, weak webView] result, _ in
          guard result as? Bool == true, let self, let webView else { return }
          self.openHideMyEmail(in: webView)
        }
      }
    }

    private func openHideMyEmail(in webView: WKWebView) {
      guard !hasOpenedHideMyEmail else { return }
      hasOpenedHideMyEmail = true
      authenticationTimer?.invalidate()
      authenticationWorkItem?.cancel()
      onStageChange(.capturing)
      webView.load(URLRequest(url: region.hideMyEmailURL))
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
          return
        }
        DispatchQueue.main.async {
          self.onCookieHeader(header)
        }
      }
    }
  }
}
