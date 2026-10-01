import '../entities/song.dart';
import '../entities/artist.dart';
import '../repositories/youtube_repository.dart';

class HomeSectionsData {
  final List<Song> quickPicks;
  final List<Song> trending;
  final List<Song> recommended;
  final List<Artist> popularArtists;

  const HomeSectionsData({
    required this.quickPicks,
    required this.trending,
    required this.recommended,
    required this.popularArtists,
  });
}

class GetHomeSectionsUseCase {
  final YouTubeRepository repository;

  GetHomeSectionsUseCase(this.repository);

  Future<HomeSectionsData> execute() async {
    final results = await Future.wait([
      repository.getQuickPicks(),
      repository.getTrendingMusic(),
      repository.getRecommendedMusic(),
      repository.getPopularArtists(),
    ]);

    return HomeSectionsData(
      quickPicks: results[0] as List<Song>,
      trending: results[1] as List<Song>,
      recommended: results[2] as List<Song>,
      popularArtists: results[3] as List<Artist>,
    );
  }
}
