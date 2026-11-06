import '../entities/search_result.dart';
import '../entities/song.dart';
import '../repositories/youtube_repository.dart';

class SearchMusicUseCase {
  final YouTubeRepository repository;

  SearchMusicUseCase(this.repository);

  Future<SearchResult> executeAll(String query) async {
    return await repository.searchAll(query);
  }

  Future<List<Song>> executeSongs(String query) async {
    return await repository.searchSongs(query);
  }
}
