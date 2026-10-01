import '../entities/song.dart';
import '../entities/artist.dart';
import '../entities/playlist.dart';
import '../entities/search_result.dart';

abstract class YouTubeRepository {
  Future<SearchResult> searchAll(String query);
  Future<List<Song>> searchSongs(String query, {int maxResults = 20});
  Future<List<Artist>> searchArtists(String query, {int maxResults = 10});
  Future<List<Playlist>> searchPlaylists(String query, {int maxResults = 10});
  Future<List<Song>> getTrendingMusic({String regionCode = 'US'});
  Future<List<Song>> getQuickPicks();
  Future<List<Song>> getRecommendedMusic();
  Future<List<Song>> getMusicByGenre(String genre);
  Future<List<Artist>> getPopularArtists();
  Future<Song?> getVideoDetails(String videoId);
}
