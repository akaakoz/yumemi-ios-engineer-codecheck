//
//  RepositoryWebPageView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI
import WebKit

/// GitHub 上のリポジトリのページを、アプリを離れずに表示する。
struct RepositoryWebPageView: View {

    let url: URL
    let title: String

    @State private var page = WebPage()
    @State private var loadError: (any Error)?
    /// 「再読み込み」で増やし、読み込みをやり直す
    @State private var loadAttempt = 0

    var body: some View {
        WebView(page)
            .overlay(alignment: .top) {
                if page.isLoading {
                    ProgressView(value: page.estimatedProgress)
                        .progressViewStyle(.linear)
                }
            }
            .overlay {
                if loadError != nil {
                    failureView
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: loadAttempt) {
                await load()
            }
    }

    private var failureView: some View {
        VStack(spacing: 12) {
            Text("ページを読み込めませんでした。通信環境を確認してから再度お試しください。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("再読み込み") {
                loadAttempt += 1
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private func load() async {
        loadError = nil
        do {
            for try await _ in page.load(url) {}
        } catch {
            loadError = error
        }
    }
}
