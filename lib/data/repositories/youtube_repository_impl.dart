import '../../domain/entities/song.dart';
import '../../domain/entities/artist.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/youtube_repository.dart';
import '../datasources/youtube_remote_datasource.dart';

class YouTubeRepositoryImpl implements YouTubeRepository {
  final YouTubeRemoteDatasource remoteDatasource;

  YouTubeRepositoryImpl({required this.remoteDatasource});

  @override
  Future<SearchResult> searchAll(String query) async {
    final model = await remoteDatasource.searchAll(query);
    return model.toEntity();
  }

  @override
  Future<List<Song>> searchSongs(String query, {int maxResults = 20}) async {
    final res = await remoteDatasource.searchAll(query);
    return res.songs.map((s) => s.toEntity()).toList();
  }

  @override
  Future<List<Artist>> searchArtists(String query, {int maxResults = 10}) async {
    final res = await remoteDatasource.searchAll(query);
    return res.artists.map((a) => a.toEntity()).toList();
  }

  @override
  Future<List<Playlist>> searchPlaylists(String query, {int maxResults = 10}) async {
    final res = await remoteDatasource.searchAll(query);
    return res.playlists.map((p) => p.toEntity()).toList();
  }

  @override
  Future<List<Song>> getTrendingMusic({String regionCode = 'US'}) async {
    final list = await remoteDatasource.getTrendingMusic(regionCode: regionCode);
    return list.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Song>> getQuickPicks() async {
    final list = await searchSongs('popular top songs music');
    return list.take(8).toList();
  }

  @override
  Future<List<Song>> getRecommendedMusic() async {
    final list = await searchSongs('relaxing acoustic songs');
    return list.take(8).toList();
  }

  @override
  Future<List<Song>> getMusicByGenre(String genre) async {
    final list = await remoteDatasource.getMusicByGenre(genre);
    return list.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Artist>> getPopularArtists() async {
    final res = await remoteDatasource.searchAll('popular music artists');
    return res.artists.map((a) => a.toEntity()).toList();
  }

  @override
  Future<Song?> getVideoDetails(String videoId) async {
    final model = await remoteDatasource.getVideoDetails(videoId);
    if (model != null) {
      return model.toEntity();
    }
    final res = await remoteDatasource.searchAll(videoId);
    if (res.songs.isNotEmpty) {
      return res.songs.first.toEntity();
    }
    return null;
  }
}
