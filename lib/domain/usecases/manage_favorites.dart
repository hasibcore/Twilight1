import '../entities/song.dart';
import '../repositories/music_repository.dart';

class ManageFavoritesUseCase {
  final MusicRepository repository;

  ManageFavoritesUseCase(this.repository);

  Future<List<Song>> getFavorites() => repository.getFavorites();
  Future<void> toggle(Song song) => repository.toggleFavorite(song);
  Future<bool> isFavorite(String songId) => repository.isFavorite(songId);
}
