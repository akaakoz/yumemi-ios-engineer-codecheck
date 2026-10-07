//
//  RepositoryWebPageView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI
import WebKit

struct RepositoryWebPageView: View {

    /// 読み込む対象
    private enum LoadTarget {
        /// 最初に開いたリポジトリのページ
        case repositoryPage
        /// 履歴の前後のページ
        case historyItem(WebPage.BackForwardList.Item)
    }

    let url: URL
    let title: String

    @State private var page = WebPage()
    @State private var loadError: (any Error)?
    @State private var loadTarget = LoadTarget.repositoryPage
    /// 読み込みを要求するたびに増やし、`.task(id:)` で読み込みをやり直す。同じページを続けて要求した場合も読み込み直す
    @State private var loadRequestCount = 0
    @State private var backItem: WebPage.BackForwardList.Item?
    @State private var forwardItem: WebPage.BackForwardList.Item?

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
            .safeAreaInset(edge: .bottom) {
                historyNavigationBar
            }
            .onChange(of: page.url) {
                updateHistory()
            }
            .onChange(of: page.isLoading) {
                updateHistory()
            }
            .task(id: loadRequestCount) {
                await load(loadTarget)
            }
    }

    /// タブバーの上に置く、前後のページへの移動ボタン
    private var historyNavigationBar: some View {
        HStack {
            Button {
                if let backItem {
                    requestLoad(.historyItem(backItem))
                }
            } label: {
                Image(systemName: "chevron.backward")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("前のページ")
            .disabled(backItem == nil)

            Spacer()

            Button {
                if let forwardItem {
                    requestLoad(.historyItem(forwardItem))
                }
            } label: {
                Image(systemName: "chevron.forward")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("次のページ")
            .disabled(forwardItem == nil)
        }
        .font(.title3)
        .padding(.horizontal, 16)
        .background(.bar)
    }

    private var failureView: some View {
        VStack(spacing: 12) {
            Text("ページを読み込めませんでした。通信環境を確認してから再度お試しください。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("再読み込み") {
                requestLoad(loadTarget)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private func updateHistory() {
        backItem = page.backForwardList.backList.last
        forwardItem = page.backForwardList.forwardList.first
    }

    private func requestLoad(_ target: LoadTarget) {
        loadTarget = target
        loadRequestCount += 1
    }

    private func load(_ target: LoadTarget) async {
        loadError = nil
        do {
            switch target {
            case .repositoryPage:
                for try await _ in page.load(url) {}
            case .historyItem(let item):
                for try await _ in page.load(item) {}
            }
        } catch {
            // 別の読み込みを始めたり画面を閉じたりして止めた場合は、失敗として扱わない
            guard !Task.isCancelled else { return }
            loadError = error
        }
    }
}
