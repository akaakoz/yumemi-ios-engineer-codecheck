//
//  RepositoryDetailView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

struct RepositoryDetailView: View {
    /// 保存に失敗した場合など、状態が変わらなければボタンの表示も変わらない。
    let isBookmarked: @MainActor () -> Bool
    let addBookmark: @MainActor (RepositoryDetail) -> Void
    let removeBookmark: @MainActor () -> Void

    @State private var viewModel: RepositoryDetailViewModel

    init(
        source: RepositoryDetailViewModel.Source,
        isBookmarked: @escaping @MainActor () -> Bool,
        addBookmark: @escaping @MainActor (RepositoryDetail) -> Void,
        removeBookmark: @escaping @MainActor () -> Void,
        apiService: RepositoryDetailAPIServiceProtocol = RepositoryDetailAPIService()
    ) {
        self.isBookmarked = isBookmarked
        self.addBookmark = addBookmark
        self.removeBookmark = removeBookmark
        _viewModel = State(initialValue: RepositoryDetailViewModel(source: source, apiService: apiService))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                detailContent

                bookmarkButton
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadRepositoryDetail()
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch viewModel.phase {
        case .loading:
            titleView(viewModel.fullName)
            ProgressView()
        case .loaded(let detail):
            avatarView(detail.owner.avatarURL)
            titleView(detail.fullName)
            summaryView(detail)
        case .failed(let error):
            titleView(viewModel.fullName)
            failureView(error)
        }
    }

    private func titleView(_ fullName: String) -> some View {
        Text(fullName)
            .font(.title)
            .multilineTextAlignment(.center)
    }

    private func avatarView(_ url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .failure:
                Image(systemName: "person.crop.square")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
                    .padding(48)
            default:
                ProgressView()
            }
        }
        .frame(maxWidth: 360, maxHeight: 360)
        .frame(maxWidth: .infinity)
    }

    private func summaryView(_ detail: RepositoryDetail) -> some View {
        HStack(alignment: .top) {
            if let language = detail.language {
                Text("Written in \(language)")
                    .font(.headline)
            }

            Spacer(minLength: 24)

            VStack(alignment: .trailing, spacing: 16) {
                Text("\(detail.stargazersCount) stars")
                watchersCountView(detail.subscribersCount)
                Text("\(detail.forksCount) forks")
                Text("\(detail.openIssuesCount) open issues")
            }
            .font(.subheadline)
        }
    }

    /// Watch 数を保存していなかった以前の形式のブックマークでは `nil` になり、その場合は行ごと表示しない
    @ViewBuilder
    private func watchersCountView(_ subscribersCount: Int?) -> some View {
        if let subscribersCount {
            Text("\(subscribersCount) watchers")
        }
    }

    private func failureView(_ error: APIError) -> some View {
        VStack(spacing: 12) {
            Text(RepositoryDetailViewModel.failureMessage(for: error))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            reloadButton
        }
    }

    private var reloadButton: some View {
        Button("再読み込み") {
            Task {
                await viewModel.loadRepositoryDetail()
            }
        }
    }

    @ViewBuilder
    private var bookmarkButton: some View {
        if isBookmarked() {
            Button("Remove from Bookmark") {
                removeBookmark()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        } else {
            Button("Add to Bookmark") {
                if let detail = viewModel.loadedDetail {
                    addBookmark(detail)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(viewModel.loadedDetail == nil)
        }
    }
}
