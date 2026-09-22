import SwiftUI
import UIKit
import WebKit
import GoogleMobileAds
import UserMessagingPlatform

@main
struct VayasaAgelessHealthApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var ads = VayasaAdsManager()

    var body: some View {
        ZStack(alignment: .bottom) {
            VayasaWebView()

            if ads.canRequestAds {
                AdBannerView()
                    .frame(height: 60)
                    .background(Color(.systemBackground))
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .task {
            await ads.prepareAds()
        }
    }
}

@MainActor
final class VayasaAdsManager: ObservableObject {
    @Published private(set) var canRequestAds = false
    private var started = false

    func prepareAds() async {
        guard !started else { return }
        started = true

        let parameters = RequestParameters()

        do {
            try await requestConsentUpdate(parameters: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // If consent loading fails, the UMP SDK may still have a usable
            // consent state from the previous session. We still check it below.
        }

        guard ConsentInformation.shared.canRequestAds else {
            canRequestAds = false
            return
        }

        MobileAds.shared.start()
        canRequestAds = true
    }

    private func requestConsentUpdate(parameters: RequestParameters) async throws {
        try await withCheckedThrowingContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

struct VayasaWebView: UIViewRepresentable {
    // V59's web app already contains the real Clerk authentication gate.
    // Opening the sign-in route prevents the iOS wrapper from starting on the
    // public landing page. Clerk itself preserves a valid existing session.
    private let startURL = URL(
        string: "https://vayasa-ageless-health-8550.pages.dev/sign-in"
    )!

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptEnabled = true

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false

        webView.load(
            URLRequest(
                url: startURL,
                cachePolicy: .reloadRevalidatingCacheData
            )
        )

        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context: Context
    ) {
        // Intentionally empty. Navigation and Clerk session state are owned by
        // the web application; SwiftUI must not reload the page on every update.
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Keep Vayasa and Clerk authentication navigation inside the app.
            // Other links are also allowed so existing Vayasa web behavior is
            // not broken by the wrapper.
            decisionHandler(.allow)
        }
    }
}

struct AdBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)

        // Official Google iOS test banner ID. Keep this during testing.
        // The production iOS Banner Ad Unit ID must only be used for release
        // after AdMob/consent/App Store checks are complete.
        banner.adUnitID = "ca-app-pub-3940256099942544/2435281174"

        banner.rootViewController = topViewController()
        banner.load(Request())

        return banner
    }

    func updateUIView(
        _ banner: BannerView,
        context: Context
    ) {
        // Banner configuration is intentionally stable for the lifetime of the
        // SwiftUI representable. Avoid duplicate ad requests on view updates.
    }

    private func topViewController(
        from root: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    ) -> UIViewController? {
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        if let navigation = root as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        return root
    }
}
