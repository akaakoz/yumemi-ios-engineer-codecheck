//
//  RepositoryDetailView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

struct RepositoryDetailView: View {

    let repository: Repository
    /// ボタンを押したときに呼ぶ。引数は登録するなら true、削除するなら false
    let setBookmarked: @MainActor (Bool) -> Void

    /// 画面を開いた時点の登録状態。`@State` にすることで、その後の状態変化でボタン表示が変わらないようにしている
    // TODO: - 既存の動きを担保するために設定してるので、修正時にStateを外す
    @State private var isShownAsBookmarked: Bool

    init(
        repository: Repository,
        isShownAsBookmarked: Bool,
        setBookmarked: @escaping @MainActor (Bool) -> Void
    ) {
        self.repository = repository
        self.setBookmarked = setBookmarked
        _isShownAsBookmarked = State(initialValue: isShownAsBookmarked)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                avatarView

                Text(repository.fullName)
                    .font(.title)
                    .multilineTextAlignment(.center)

                summaryView

                bookmarkButton
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var avatarView: some View {
        AsyncImage(url: repository.owner.avatarURL) { phase in
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

    private var summaryView: some View {
        HStack(alignment: .top) {
            languageView

            Spacer(minLength: 24)

            VStack(alignment: .trailing, spacing: 16) {
                Text("\(repository.stargazersCount) stars")
                Text("\(repository.watchersCount) watchers")
                Text("\(repository.forksCount) forks")
                Text("\(repository.openIssuesCount) open issues")
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private var languageView: some View {
        if let language = repository.language {
            Text("Written in \(language)")
                .font(.headline)
        }
    }

    @ViewBuilder
    private var bookmarkButton: some View {
        if isShownAsBookmarked {
            Button("Remove from Bookmark") {
                setBookmarked(false)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        } else {
            Button("Add to Bookmark") {
                setBookmarked(true)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
    }

}
