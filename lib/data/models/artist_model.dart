import '../../domain/entities/artist.dart';

class ArtistModel {
  final String id;
  final String name;
  final String thumbnailUrl;
  final String subscriberCountFormatted;
  final String description;

  const ArtistModel({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    this.subscriberCountFormatted = '',
    this.description = '',
  });

  Artist toEntity() {
    return Artist(
      id: id,
      name: name,
      thumbnailUrl: thumbnailUrl,
      subscriberCountFormatted: subscriberCountFormatted,
      description: description,
    );
  }

  factory ArtistModel.fromJson(Map<String, dynamic> json) {
    return ArtistModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown Artist',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      subscriberCountFormatted:
          json['subscriberCountFormatted'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'thumbnailUrl': thumbnailUrl,
      'subscriberCountFormatted': subscriberCountFormatted,
      'description': description,
    };
  }
}
