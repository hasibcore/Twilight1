class Artist {
  final String id; // Channel ID
  final String name;
  final String thumbnailUrl;
  final String subscriberCountFormatted;
  final String description;

  const Artist({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    this.subscriberCountFormatted = '',
    this.description = '',
  });
}
