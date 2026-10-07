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
            VStack(alignment: .leading, spacing: 24) {
                detailContent
                webPageLink
                bookmarkButton
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
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
            headerView(avatarURL: nil)
            ProgressView()
                .frame(maxWidth: .infinity)
        case .loaded(let detail):
            headerView(avatarURL: detail.owner.avatarURL)
            summaryView(detail)
        case .failed(let error):
            headerView(avatarURL: nil)
            failureView(error)
        }
    }

    private func headerView(avatarURL: URL?) -> some View {
        HStack(spacing: 12) {
            avatarView(avatarURL)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
            Text(viewModel.fullName)
                .font(.title2.bold())
                .lineLimit(2)
        }
    }

    private func avatarView(_ url: URL?) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure, .empty:
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            @unknown default:
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryView(_ detail: RepositoryDetail) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if let description = detail.description, !description.isEmpty {
                Text(description)
            }

            statsView(detail)

            HStack(spacing: 16) {
                if let language = detail.language {
                    Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
                        .accessibilityIdentifier("repositoryDetail.language")
                }
                if let pushedAt = detail.pushedAt {
                    Label(pushedAt.formatted(.relative(presentation: .named)), systemImage: "clock")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    /// 主な数値を横一列に並べ、比べやすくする。
    /// Watch 数を保存していなかった以前の形式のブックマークでは `nil` になり、その場合は列ごと表示しない
    private func statsView(_ detail: RepositoryDetail) -> some View {
        HStack(alignment: .top, spacing: 8) {
            statView(count: detail.stargazersCount, title: "Stars", systemImage: "star", identifier: "stars")
            if let subscribersCount = detail.subscribersCount {
                statView(count: subscribersCount, title: "Watchers", systemImage: "eye", identifier: "watchers")
            }
            statView(count: detail.forksCount, title: "Forks", systemImage: "arrow.triangle.branch", identifier: "forks")
            statView(count: detail.openIssuesCount, title: "Issues", systemImage: "exclamationmark.circle", identifier: "issues")
        }
    }

    private func statView(count: Int, title: String, systemImage: String, identifier: String) -> some View {
        VStack(spacing: 4) {
            // 記号ごとに高さが違っても、数値の位置がそろうよう高さを固定する
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(height: 24)
            Text("\(count)")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("repositoryDetail.\(identifier)")
    }

    /// 取得に失敗したときは、検索やブックマークの案内と同じ見た目で、取れる操作（再読み込み）をボタンとして示す
    private func failureView(_ error: APIError) -> some View {
        ContentUnavailableView {
            Label("情報を取得できませんでした", systemImage: "exclamationmark.triangle")
        } description: {
            Text(RepositoryDetailViewModel.failureMessage(for: error))
        } actions: {
            Button {
                viewModel.reload()
            } label: {
                Label("再読み込み", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    /// 詳細を表示できたら、GitHub 上のページをアプリ内で開ける
    @ViewBuilder
    private var webPageLink: some View {
        if let detail = viewModel.loadedDetail, let url = detail.webPageURL {
            NavigationLink {
                RepositoryWebPageView(url: url, title: detail.fullName)
            } label: {
                Label("GitHub で詳細を見る", systemImage: "safari")
            }
            // ブックマークのボタンと区別できるよう、ボタンではなく文字列のリンクとして表示する
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.blue)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    /// 保存に失敗した場合など、登録状態が変わらなければボタンの表示も変わらない。
    @ViewBuilder
    private var bookmarkButton: some View {
        // ブックマークには取得した詳細を保存するため、詳細を表示できるまでは操作できるボタンとして見せない
        if viewModel.loadedDetail == nil {
            EmptyView()
        } else if viewModel.isBookmarked {
            Button {
                viewModel.removeBookmark()
            } label: {
                Text("Remove from Bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.red)
        } else {
            Button {
                viewModel.addBookmark()
            } label: {
                Text("Add to Bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.blue)
        }
    }
}
