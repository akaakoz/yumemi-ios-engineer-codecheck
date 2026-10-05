//
//  RepositoryDetailView.swift
//  iOSEngineerCodeCheck
//

import SwiftUI

struct RepositoryDetailView: View {

    let repository: Repository
    /// 登録状態。呼び出し側の ViewModel の状態を読み書きし、ボタンを押すと追加・削除を依頼する。
    /// 保存に失敗した場合など、状態が変わらなければボタンの表示も変わらない。
    @Binding var isBookmarked: Bool

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
        if isBookmarked {
            Button("Remove from Bookmark") {
                isBookmarked = false
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        } else {
            Button("Add to Bookmark") {
                isBookmarked = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
    }

}
