//
//  RepositoryDetailView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

struct RepositoryDetailView: View {

    @State private var viewModel: RepositoryDetailViewModel

    init(source: RepositoryDetailViewModel.Source) {
        _viewModel = State(initialValue: RepositoryDetailViewModel(source: source))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                detailContent

                webPageLink

                bookmarkButton
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadIfNeeded()
            viewModel.loadBookmarkState()
        }
        .alert(
            "ブックマーク",
            isPresented: $viewModel.isShowingBookmarkStorageError,
            presenting: viewModel.bookmarkStorageError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { error in
            Text(error.message)
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
        VStack(spacing: 16) {
            if let description = detail.description, !description.isEmpty {
                Text(description)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let language = detail.language {
                Text("Written in \(language)")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let pushedAt = detail.pushedAt {
                Label(pushedAt.formatted(.relative(presentation: .named)), systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .trailing, spacing: 16) {
                Text("\(detail.stargazersCount) stars")
                watchersCountView(detail.subscribersCount)
                Text("\(detail.forksCount) forks")
                Text("\(detail.openIssuesCount) open issues")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .trailing)
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
            viewModel.reload()
        }
    }

    /// 詳細を表示できたら、GitHub 上のページをアプリ内で開ける
    @ViewBuilder
    private var webPageLink: some View {
        if let detail = viewModel.loadedDetail, let url = detail.webPageURL {
            NavigationLink {
                RepositoryWebPageView(url: url, title: detail.fullName)
            } label: {
                Label("GitHub で開く", systemImage: "safari")
            }
            // ブックマークのボタンと区別できるよう、ボタンではなく文字列のリンクとして表示する
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// 保存に失敗した場合など、登録状態が変わらなければボタンの表示も変わらない。
    @ViewBuilder
    private var bookmarkButton: some View {
        if viewModel.isBookmarked {
            Button("Remove from Bookmark") {
                viewModel.removeBookmark()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        } else {
            Button("Add to Bookmark") {
                viewModel.addBookmark()
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(viewModel.loadedDetail == nil)
        }
    }
}
