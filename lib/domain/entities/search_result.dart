import 'song.dart';
import 'artist.dart';
import 'playlist.dart';

class SearchResult {
  final List<Song> songs;
  final List<Song> videos;
  final List<Artist> artists;
  final List<Playlist> playlists;

  const SearchResult({
    this.songs = const [],
    this.videos = const [],
    this.artists = const [],
    this.playlists = const [],
  });

  bool get isEmpty =>
      songs.isEmpty && videos.isEmpty && artists.isEmpty && playlists.isEmpty;
}
