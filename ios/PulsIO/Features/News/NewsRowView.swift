import SwiftUI

/// One feed row: category dot · headline · "source · category · 2h ago".
struct NewsRowView: View {
    let article: NewsArticle

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.Space.sm + 2) {
            Circle()
                .fill(article.category.tint)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: Metrics.Space.xs) {
                Text(article.headline)
                    .font(Typography.body(14))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 0) {
                    Text(article.source)
                        .foregroundStyle(Palette.muted)
                    Text(verbatim: " · ")
                        .foregroundStyle(Palette.muted2)
                    Text(article.category.label)
                        .foregroundStyle(article.category.tint)
                    if let publishedAt = article.publishedAt {
                        Text(verbatim: " · ")
                            .foregroundStyle(Palette.muted2)
                        Text(publishedAt, format: .relative(presentation: .named))
                            .foregroundStyle(Palette.muted2)
                    }
                }
                .font(Typography.mono(10))
                .lineLimit(1)
            }
        }
    }
}
