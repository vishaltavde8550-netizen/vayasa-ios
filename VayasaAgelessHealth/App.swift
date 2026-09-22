import SwiftUI
import UIKit
import WebKit
import GoogleMobileAds

@main
struct VayasaAgelessHealthApp: App {

    init() {
        MobileAds.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            VayasaWebView()

            AdBannerView()
                .frame(height: 60)
                .background(Color(.systemBackground))
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

struct VayasaWebView: UIViewRepresentable {

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        webView.allowsBackForwardNavigationGestures = true

        if let url = URL(
            string: "https://vayasa-ageless-health-8550.pages.dev"
        ) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context: Context
    ) {
    }
}

struct AdBannerView: UIViewRepresentable {

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(
            adSize: largeAnchoredAdaptiveBanner(width: 375)
        )

        // Google official iOS test banner ID.
        // Production ID will be added only after testing.
        banner.adUnitID =
            "ca-app-pub-3940256099942544/2435281174"

        banner.rootViewController =
            UIApplication.shared.connectedScenes
                .compactMap {
                    $0 as? UIWindowScene
                }
                .flatMap {
                    $0.windows
                }
                .first {
                    $0.isKeyWindow
                }?
                .rootViewController

        banner.load(Request())

        return banner
    }

    func updateUIView(
        _ banner: BannerView,
        context: Context
    ) {
    }
}
