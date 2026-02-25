class NewsItem {
  const NewsItem({
    required this.title,
    required this.source,
    required this.url,
    required this.summary,
    required this.timePublished,
    required this.overallSentimentScore,
    required this.overallSentimentLabel,
  });

  final String title;
  final String source;
  final String url;
  final String summary;
  final DateTime? timePublished;
  final double? overallSentimentScore;
  final String overallSentimentLabel;

  factory NewsItem.fromAlphaVantage(Map<String, dynamic> json) {
    return NewsItem(
      title: (json['title'] as String?)?.trim() ?? '',
      source: (json['source'] as String?)?.trim() ?? '',
      url: (json['url'] as String?)?.trim() ?? '',
      summary: (json['summary'] as String?)?.trim() ?? '',
      timePublished: _parsePublishedAt(json['time_published'] as String?),
      overallSentimentScore: _parseDouble(json['overall_sentiment_score']),
      overallSentimentLabel:
          (json['overall_sentiment_label'] as String?)?.trim() ?? '',
    );
  }
}

DateTime? _parsePublishedAt(String? value) {
  if (value == null || value.isEmpty) return null;

  final normalized = value.length >= 15
      ? '${value.substring(0, 4)}-${value.substring(4, 6)}-${value.substring(6, 8)}'
            'T${value.substring(9, 11)}:${value.substring(11, 13)}:${value.substring(13, 15)}'
      : value;
  return DateTime.tryParse(normalized);
}

double? _parseDouble(Object? value) {
  if (value == null) return null;
  return double.tryParse(value.toString());
}
