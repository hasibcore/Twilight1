import '../../domain/entities/search_result.dart';
import 'song_model.dart';
import 'artist_model.dart';
import 'playlist_model.dart';

class SearchResultModel {
  final List<SongModel> songs;
  final List<SongModel> videos;
  final List<ArtistModel> artists;
  final List<PlaylistModel> playlists;

  const SearchResultModel({
    this.songs = const [],
    this.videos = const [],
    this.artists = const [],
    this.playlists = const [],
  });

  SearchResult toEntity() {
    return SearchResult(
      songs: songs.map((e) => e.toEntity()).toList(),
      videos: videos.map((e) => e.toEntity()).toList(),
      artists: artists.map((e) => e.toEntity()).toList(),
      playlists: playlists.map((e) => e.toEntity()).toList(),
    );
  }
}
