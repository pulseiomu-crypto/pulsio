import SwiftUI

/// Headline, source, time, excerpt, "Read at source ↗" (FRONTEND §F).
struct NewsDetailView: View {
    let article: NewsArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Space.lg) {
                HStack(spacing: Metrics.Space.sm) {
                    Circle().fill(article.category.tint).frame(width: 6, height: 6)
                    Text(article.category.label)
                        .font(Typography.mono(10, weight: .semibold))
                        .tracking(Typography.eyebrowTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(article.category.tint)
                }

                Text(article.headline)
                    .font(Typography.display(24))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 0) {
                    Text(article.source).foregroundStyle(Palette.muted)
                    if let publishedAt = article.publishedAt {
                        Text(verbatim: " · ").foregroundStyle(Palette.muted2)
                        Text(publishedAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                            .foregroundStyle(Palette.muted2)
                        Text(verbatim: " · ").foregroundStyle(Palette.muted2)
                        Text(publishedAt, format: .relative(presentation: .named))
                            .foregroundStyle(Palette.muted2)
                    }
                }
                .font(Typography.mono(10))

                Rectangle()
                    .fill(Palette.hair)
                    .frame(height: Metrics.hairline)

                if let summary = article.summary, !summary.isEmpty {
                    Text(summary)
                        .font(Typography.body(15))
                        .foregroundStyle(Palette.ink.opacity(0.88))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let url = article.sourceURL {
                    Link(destination: url) {
                        HStack(spacing: Metrics.Space.xs) {
                            Text("news.readAtSource")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(Typography.mono(11, weight: .semibold))
                        .tracking(Typography.eyebrowTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(Palette.teal)
                        .padding(.horizontal, Metrics.Space.lg)
                        .padding(.vertical, Metrics.Space.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Metrics.Radius.sm, style: .continuous)
                                .stroke(Palette.hairActive, lineWidth: Metrics.hairline)
                        )
                    }
                    .padding(.top, Metrics.Space.sm)
                }
            }
            .padding(Metrics.Space.lg)
            .frame(maxWidth: 680, alignment: .leading)   // readable measure on iPad
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.abyss.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
