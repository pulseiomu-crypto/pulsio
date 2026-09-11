import SwiftUI

/// The feed: 50 latest, category colour-coded, tap → detail (FRONTEND §F).
struct NewsFeedView: View {
    @Environment(\.newsRepository) private var repository
    @State private var model: NewsFeedViewModel?

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                Color.clear
            }
        }
        .background(Palette.abyss.ignoresSafeArea())
        .navigationTitle(Text("news.title"))
        .navigationBarTitleDisplayMode(.large)
        .task {
            if model == nil { model = NewsFeedViewModel(repository: repository) }
            await model?.load()
        }
    }

    @ViewBuilder
    private func content(_ model: NewsFeedViewModel) -> some View {
        switch model.phase {
        case .idle, .loading:
            StatusLine(text: Text("news.loading"), tint: Palette.muted)
        case .failed:
            VStack(spacing: Metrics.Space.md) {
                StatusLine(text: Text("news.error.load"), tint: Palette.coral)
                Button {
                    Task { await model.load() }
                } label: {
                    Text("common.retry")
                        .font(Typography.mono(11, weight: .semibold))
                        .tracking(Typography.eyebrowTracking)
                        .textCase(.uppercase)
                }
                .buttonStyle(.bordered)
                .tint(Palette.teal)
            }
        case .loaded where model.articles.isEmpty:
            StatusLine(text: Text("news.empty"), tint: Palette.muted)
        case .loaded:
            List {
                ForEach(model.articles) { article in
                    NavigationLink(value: article) {
                        NewsRowView(article: article)
                    }
                    .listRowBackground(Palette.abyss)
                    .listRowSeparatorTint(Palette.hair)
                    .listRowInsets(EdgeInsets(top: Metrics.Space.md, leading: Metrics.Space.lg, bottom: Metrics.Space.md, trailing: Metrics.Space.lg))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await model.load() }
            .navigationDestination(for: NewsArticle.self) { NewsDetailView(article: $0) }
        }
    }
}

/// Centred mono status line — the feed's loading / empty / error copy.
private struct StatusLine: View {
    let text: Text
    let tint: Color

    var body: some View {
        text
            .font(Typography.mono(11))
            .foregroundStyle(tint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(Metrics.Space.xl)
    }
}
