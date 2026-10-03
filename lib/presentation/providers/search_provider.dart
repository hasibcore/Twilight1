import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../domain/entities/search_result.dart';
import '../../domain/repositories/youtube_repository.dart';
import '../../domain/repositories/music_repository.dart';
import '../../core/utils/logger.dart';

import '../../core/services/music_import_service.dart';

enum SearchCategory { all, songs, videos, artists, playlists }

class SearchProvider extends ChangeNotifier {
  final YouTubeRepository youtubeRepository;
  final MusicRepository musicRepository;

  String _query = '';
  bool _isLoading = false;
  String? _errorMessage;
  SearchResult _searchResult = const SearchResult();
  SearchCategory _selectedCategory = SearchCategory.all;
  List<String> _searchHistory = [];
  List<String> _suggestions = [];
  int _suggestRequestId = 0;

  SearchProvider({
    required this.youtubeRepository,
    required this.musicRepository,
  }) {
    loadSearchHistory();
  }

  String get query => _query;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  SearchResult get searchResult => _searchResult;
  SearchCategory get selectedCategory => _selectedCategory;
  List<String> get searchHistory => _searchHistory;
  List<String> get suggestions => _suggestions;

  bool _isSuggesting = false;
  bool get isSuggesting => _isSuggesting;

  final Map<String, List<String>> _suggestCache = {};

  Future<void> fetchSuggestions(String text) async {
    final clean = text.trim();
    final lower = clean.toLowerCase();
    final reqId = ++_suggestRequestId;

    if (clean.isEmpty) {
      _isSuggesting = false;
      _suggestions = [];
      notifyListeners();
      return;
    }

    // Check in-memory cache for instant zero-latency keystroke rendering
    if (_suggestCache.containsKey(lower)) {
      _isSuggesting = false;
      _suggestions = _suggestCache[lower]!;
      notifyListeners();
      return;
    }

    // Match history items that start with or contain the query
    final matchingHistory = _searchHistory
        .where((h) => h.toLowerCase().contains(lower))
        .take(3)
        .toList();

    // Show matching history immediately (0ms latency for typed keystroke)
    _isSuggesting = true;
    if (matchingHistory.isNotEmpty) {
      _suggestions = matchingHistory;
      notifyListeners();
    }

    try {
      final uri = Uri.parse(
        'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${Uri.encodeComponent(clean)}',
      );
      final res = await http.get(
        uri,
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      ).timeout(const Duration(seconds: 3));

      if (reqId != _suggestRequestId) return;

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as List;
        if (decoded.length > 1 && decoded[1] is List) {
          final apiList = (decoded[1] as List).map((e) => e.toString()).toList();
          // Combine matching history + live suggestions without duplicates
          final combined = <String>[...matchingHistory];
          for (final s in apiList) {
            if (!combined.any((c) => c.toLowerCase() == s.toLowerCase())) {
              combined.add(s);
            }
          }
          _suggestions = combined;
          _suggestCache[lower] = combined;
          _isSuggesting = false;
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    // Fallback: If primary endpoint fails, still show matching history or cached items
    if (reqId == _suggestRequestId) {
      _isSuggesting = false;
      if (matchingHistory.isNotEmpty) {
        _suggestions = matchingHistory;
      }
      notifyListeners();
    }
  }

  void clearSuggestions() {
    _suggestRequestId++;
    _isSuggesting = false;
    _suggestions = [];
    notifyListeners();
  }

  Future<void> loadSearchHistory() async {
    _searchHistory = await musicRepository.getSearchHistory();
    notifyListeners();
  }

  void setCategory(SearchCategory category) {
    _selectedCategory = category;
    notifyListeners();
  }

  int _searchRequestId = 0;

  Future<void> search(String searchString) async {
    final trimmed = searchString.trim();
    final requestId = ++_searchRequestId;

    if (trimmed.isEmpty) {
      _query = '';
      _isLoading = false;
      _errorMessage = null;
      _searchResult = const SearchResult();
      notifyListeners();
      return;
    }

    _query = trimmed;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await musicRepository.addSearchHistory(trimmed);
      if (requestId != _searchRequestId) return;
      await loadSearchHistory();
      if (requestId != _searchRequestId) return;

      if (MusicImportService().isSupportedUrl(trimmed)) {
        final importedSongs = await MusicImportService().importFromUrl(trimmed);
        if (requestId != _searchRequestId) return;
        _searchResult = SearchResult(songs: importedSongs);
        _isLoading = false;
        notifyListeners();
        return;
      }

      final results = await youtubeRepository.searchAll(trimmed);
      if (requestId != _searchRequestId) return;
      _searchResult = results;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (requestId != _searchRequestId) return;
      _errorMessage = 'Search failed. Please try again.';
      _isLoading = false;
      AppLogger.error('Search error: $e');
      notifyListeners();
    }
  }

  Future<void> clearHistory() async {
    await musicRepository.clearSearchHistory();
    _searchHistory = [];
    notifyListeners();
  }
}
