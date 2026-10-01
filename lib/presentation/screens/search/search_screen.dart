import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/search_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/song_card.dart';
import '../../widgets/artist_card.dart';
import '../../widgets/playlist_card.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/mini_player_widget.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({super.key, this.initialQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _controller.text = widget.initialQuery!.trim();
      _hasSubmitted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<SearchProvider>().search(widget.initialQuery!.trim());
        }
      });
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      final text = _controller.text;
      if (text.trim().isNotEmpty && !_hasSubmitted) {
        context.read<SearchProvider>().fetchSuggestions(text);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchProv = context.watch<SearchProvider>();
    final hasCurrentSong = context.select<PlayerProvider, bool>((p) => p.currentSong != null);
    final bottomPadding = hasCurrentSong ? 100.0 : 40.0;
    final isSuggestionMode = !_hasSubmitted && _controller.text.trim().isNotEmpty;

    return Scaffold(
      bottomNavigationBar: hasCurrentSong
          ? const SafeArea(top: false, child: MiniPlayerWidget())
          : null,
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 15),
            decoration: InputDecoration(
              hintText: AppStrings.searchHint,
              hintStyle: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary(context), size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: AppColors.icon(context), size: 20),
                      onPressed: () {
                        _debounceTimer?.cancel();
                        _hasSubmitted = false;
                        _controller.clear();
                        searchProv.clearSuggestions();
                        searchProv.search('');
                        if (mounted) setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (text) {
              _hasSubmitted = false;
              _debounceTimer?.cancel();
              if (text.trim().isNotEmpty) {
                _debounceTimer = Timer(const Duration(milliseconds: 180), () {
                  if (mounted && !_hasSubmitted) {
                    context.read<SearchProvider>().fetchSuggestions(text);
                  }
                });
              } else {
                context.read<SearchProvider>().clearSuggestions();
              }
              if (mounted) setState(() {});
            },
            onSubmitted: (val) {
              final query = val.trim();
              if (query.isEmpty) return;
              _hasSubmitted = true;
              _debounceTimer?.cancel();
              _focusNode.unfocus();
              searchProv.clearSuggestions();
              searchProv.search(query);
              if (mounted) setState(() {});
            },
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSuggestionMode) ...[
              if (searchProv.suggestions.isNotEmpty)
                _buildSuggestionsList(searchProv)
              else if (searchProv.isSuggesting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryAccent,
                      ),
                    ),
                  ),
                ),
            ] else if (_controller.text.isEmpty) ...[
              _buildSearchHistorySection(searchProv),
            ] else ...[
              // Submitted Search Results Mode
              if (!searchProv.isLoading)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      _buildFilterChip(searchProv, SearchCategory.all, 'All'),
                      _buildFilterChip(searchProv, SearchCategory.songs, 'Songs'),
                      _buildFilterChip(searchProv, SearchCategory.videos, 'Videos'),
                      _buildFilterChip(searchProv, SearchCategory.artists, 'Artists'),
                      _buildFilterChip(searchProv, SearchCategory.playlists, 'Playlists'),
                    ],
                  ),
                ),

              if (searchProv.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: AppColors.primaryAccent),
                  ),
                )
              else
                _buildSearchResults(searchProv),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList(SearchProvider prov) {
    final queryLower = _controller.text.trim().toLowerCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryAccent.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: prov.suggestions.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            indent: 52,
          ),
          itemBuilder: (context, index) {
            final suggestion = prov.suggestions[index];
            final isHistory = prov.searchHistory
                .any((h) => h.toLowerCase() == suggestion.toLowerCase());

            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Icon(
                isHistory ? Icons.history : Icons.search,
                color: isHistory ? AppColors.primaryAccent : AppColors.textSecondary(context),
                size: 20,
              ),
              title: _buildHighlightedText(suggestion, queryLower),
              trailing: IconButton(
                icon: Icon(Icons.north_west, color: AppColors.iconMuted(context), size: 16),
                tooltip: 'Insert',
                onPressed: () {
                  _hasSubmitted = false;
                  _controller.text = suggestion;
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: suggestion.length),
                  );
                  _focusNode.requestFocus();
                  prov.fetchSuggestions(suggestion);
                  if (mounted) setState(() {});
                },
              ),
              onTap: () {
                _hasSubmitted = true;
                _debounceTimer?.cancel();
                _controller.text = suggestion;
                _focusNode.unfocus();
                prov.clearSuggestions();
                prov.search(suggestion);
                if (mounted) setState(() {});
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String suggestion, String query) {
    if (query.isEmpty) {
      return Text(
        suggestion,
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    final lower = suggestion.toLowerCase();
    final index = lower.indexOf(query);

    if (index == -1) {
      return Text(
        suggestion,
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: AppColors.textPrimary(context),
          fontSize: 14,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        ),
        children: [
          if (index > 0)
            TextSpan(
              text: suggestion.substring(0, index),
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          TextSpan(
            text: suggestion.substring(index, index + query.length),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryAccent,
            ),
          ),
          if (index + query.length < suggestion.length)
            TextSpan(
              text: suggestion.substring(index + query.length),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(SearchProvider prov, SearchCategory cat, String label) {
    final isSelected = prov.selectedCategory == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surfaceVariant(context),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textSecondary(context),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (_) => prov.setCategory(cat),
      ),
    );
  }

  Widget _buildSearchHistorySection(SearchProvider prov) {
    if (prov.searchHistory.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.music_note_outlined,
        title: 'Search for music',
        message: 'Find your favorite songs, artists, or mixes from YouTube.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.searchHistory,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => prov.clearHistory(),
                child: const Text(AppStrings.clearHistory, style: TextStyle(color: AppColors.primaryAccent)),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: prov.searchHistory.length,
          itemBuilder: (_, index) {
            final query = prov.searchHistory[index];
            return ListTile(
              leading: Icon(Icons.history, color: AppColors.textTertiary(context)),
              title: Text(query, style: TextStyle(color: AppColors.textPrimary(context))),
              trailing: Icon(Icons.north_west, color: AppColors.textTertiary(context), size: 18),
              onTap: () {
                _hasSubmitted = true;
                _debounceTimer?.cancel();
                _controller.text = query;
                _focusNode.unfocus();
                prov.clearSuggestions();
                prov.search(query);
                if (mounted) setState(() {});
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchResults(SearchProvider prov) {
    final results = prov.searchResult;
    if (results.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.search_off,
        title: 'No results found',
        message: 'Try searching with a different song or artist name.',
      );
    }

    final cat = prov.selectedCategory;

    // Check category-specific empty conditions
    if (cat == SearchCategory.artists && results.artists.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.person_off_outlined,
        title: 'No artists found',
        message: 'No artists matched "${prov.query}". Try selecting "All" or "Songs".',
      );
    }

    if (cat == SearchCategory.playlists && results.playlists.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.playlist_remove_rounded,
        title: 'No playlists found',
        message: 'No playlists matched "${prov.query}". Try selecting "All" or "Songs".',
      );
    }

    if ((cat == SearchCategory.songs || cat == SearchCategory.videos) && results.songs.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.music_off_outlined,
        title: 'No tracks found',
        message: 'No tracks matched "${prov.query}".',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cat == SearchCategory.all || cat == SearchCategory.songs || cat == SearchCategory.videos) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Tracks & Videos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: results.songs.length,
            itemBuilder: (_, index) {
              return SongCard(
                song: results.songs[index],
                queueContext: results.songs,
                variant: SongCardVariant.listTile,
              );
            },
          ),
        ],
        if ((cat == SearchCategory.all || cat == SearchCategory.artists) && results.artists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Artists',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.artists.length,
              itemBuilder: (_, index) {
                return ArtistCard(artist: results.artists[index]);
              },
            ),
          ),
        ],
        if ((cat == SearchCategory.all || cat == SearchCategory.playlists) && results.playlists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Playlists',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.playlists.length,
              itemBuilder: (_, index) {
                return PlaylistCard(playlist: results.playlists[index]);
              },
            ),
          ),
        ],
      ],
    );
  }
}
