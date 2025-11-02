//
//  YouTubePlayerView.swift
//  SwiftShelf
//
//  Created by michaeldvinci on 10/21/25.
//

#if canImport(WebKit)
import SwiftUI
import WebKit

struct YouTubePlayerView: View {
    let videoID: String
    var body: some View {
        WebView(url: URL(string: "https://www.youtube.com/embed/" + videoID + "?autoplay=1")!)
            .edgesIgnoringSafeArea(.all)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    func updateUIView(_ webView: WKWebView, context: Context) {}
}
#else
import SwiftUI

struct YouTubePlayerView: View {
    let videoID: String
    var body: some View {
        Text("YouTube playback is not supported on this platform.")
            .multilineTextAlignment(.center)
            .padding()
    }
}

#endif
