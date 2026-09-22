import SwiftUI
import UIKit
import WebKit
import GoogleMobileAds
import UserMessagingPlatform

@main
struct VayasaAgelessHealthApp: App {
    init() {
        VayasaAdsManager.start()
    }

    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            VayasaWebView()
            AdBannerView()
                .frame(height: 50)
                .background(Color(.systemBackground))
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

enum VayasaAdsManager {
    private static var started = false

    static func start() {
        guard !started else { return }
        started = true

        let parameters = RequestParameters()

        ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
            if let error = error {
                print("Vayasa UMP consent update error: \(error.localizedDescription)")
            }
            presentConsentIfNeeded()
        }
    }

    private static func presentConsentIfNeeded() {
        ConsentForm.loadAndPresentIfRequired(from: nil) { error in
            if let error = error {
                print("Vayasa UMP consent form error: \(error.localizedDescription)")
            }

            if ConsentInformation.shared.canRequestAds {
                MobileAds.shared.start()
            }
        }
    }
}

struct VayasaWebView: UIViewRepresentable {
    private let startURL = URL(
        string: "https://vayasa-ageless-health-8550.pages.dev/sign-in"
    )!

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default
        configuration.preferences.javaScriptEnabled = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false

        webView.load(URLRequest(
            url: startURL,
            cachePolicy: .reloadRevalidatingCacheData
        ))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }
    }
}

struct AdBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = "ca-app-pub-3940256099942544/2435281174"
        banner.rootViewController = topViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {}

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
