import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/entities/song.dart';
import '../../../domain/entities/artist.dart';
import '../../../domain/repositories/youtube_repository.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/song_card.dart';
import '../../widgets/artist_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../search/search_screen.dart';
import '../playlist/create_playlist_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _isMoodLoading = false;
  List<Song> _quickPicks = [];
  List<Song> _trending = [];
  List<Song> _recommended = [];
  List<Artist> _popularArtists = [];
  String _selectedMood = 'All';

  final List<String> _moodTags = ['All', 'Energize', 'Workout', 'Relax', 'Focus', 'Commute'];
  final Map<String, List<Song>> _moodCache = {};
  List<Song> _moodSongs = [];

  final Map<String, IconData> _moodIcons = {
    'Energize': Icons.bolt,
    'Workout': Icons.fitness_center,
    'Relax': Icons.spa,
    'Focus': Icons.psychology,
    'Commute': Icons.directions_car,
  };

  final Map<String, String> _moodSubtitles = {
    'Energize': 'High-BPM upbeat party & dance hits to power your day',
    'Workout': 'Cardio, gym motivation, & high-intensity workout tracks',
    'Relax': 'Acoustic, peaceful chill, & calm ambient melodies',
    'Focus': 'Lofi beats & deep study instrumental tracks for productivity',
    'Commute': 'Road trip & driving anthems for your daily journey',
  };

  // Dynamic Taste Match Section State
  String _selectedTaste = '🌙 Late Night Chill';
  bool _isTasteLoading = false;
  List<Song> _tasteSongs = [];
  final Map<String, List<Song>> _tasteCache = {};

  final List<String> _tasteTags = [
    '✨ For You (Taste Match)',
    '🔥 Heavy Repeat',
    '🌙 Late Night Chill',
    '🎧 Lo-Fi & Focus',
    '💖 Romantic Melodies',
    '🇧🇩 Bengali Mix',
  ];

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);
    final ytRepo = context.read<YouTubeRepository>();

    try {
      final results = await Future.wait([
        ytRepo.getQuickPicks(),
        ytRepo.getTrendingMusic(),
        ytRepo.getRecommendedMusic(),
        ytRepo.getPopularArtists(),
      ]);

      if (mounted) {
        setState(() {
          _quickPicks = results[0] as List<Song>;
          _trending = results[1] as List<Song>;
          _recommended = results[2] as List<Song>;
          _popularArtists = results[3] as List<Artist>;
          _isLoading = false;
        });

        // Pre-load default taste mix
        _loadTasteSongs(_selectedTaste);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectMood(String tag) async {
    if (_selectedMood == tag) return;
    setState(() {
      _selectedMood = tag;
      if (tag != 'All') {
        _isMoodLoading = !_moodCache.containsKey(tag);
        if (_moodCache.containsKey(tag)) {
          _moodSongs = _moodCache[tag]!;
        }
      }
    });

    if (tag == 'All' || _moodCache.containsKey(tag)) return;

    final queryMap = {
      'Energize': 'high energy upbeat pop EDM songs 2026',
      'Workout': 'gym workout motivation workout music hits',
      'Relax': 'relaxing acoustic chill calm peaceful songs',
      'Focus': 'lofi study music deep focus instrumental beats',
      'Commute': 'road trip car driving commute travel songs',
    };

    final query = queryMap[tag] ?? '$tag music';
    final ytRepo = context.read<YouTubeRepository>();

    try {
      final songs = await ytRepo.searchSongs(query);
      if (mounted && _selectedMood == tag) {
        setState(() {
          _moodCache[tag] = songs;
          _moodSongs = songs;
          _isMoodLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isMoodLoading = false);
      }
    }
  }

  Future<void> _selectTaste(String tag) async {
    if (_selectedTaste == tag) return;
    setState(() {
      _selectedTaste = tag;
      if (_tasteCache.containsKey(tag)) {
        _tasteSongs = _tasteCache[tag]!;
      } else {
        _isTasteLoading = true;
      }
    });

    if (_tasteCache.containsKey(tag)) return;
    await _loadTasteSongs(tag);
  }

  Future<void> _loadTasteSongs(String tag) async {
    setState(() => _isTasteLoading = true);
    final queryMap = {
      '✨ For You (Taste Match)': 'top viral hits popular songs 2026',
      '🔥 Heavy Repeat': 'most played trending hit songs',
      '🌙 Late Night Chill': 'late night chill aesthetic songs Billie Eilish The Weeknd',
      '🎧 Lo-Fi & Focus': 'lofi beats study chill chillhop',
      '💖 Romantic Melodies': 'romantic love songs acoustic playlist',
      '🇧🇩 Bengali Mix': 'top bengali hit songs bangla playlist',
    };

    final query = queryMap[tag] ?? '$tag music';
    final ytRepo = context.read<YouTubeRepository>();

    try {
      final songs = await ytRepo.searchSongs(query);
      if (mounted && _selectedTaste == tag) {
        setState(() {
          _tasteCache[tag] = songs;
          _tasteSongs = songs;
          _isTasteLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isTasteLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlistProv = context.watch<PlaylistProvider>();
    final playerProv = context.watch<PlayerProvider>();
    final hasCurrentSong = playerProv.currentSong != null;
    final bottomPadding = hasCurrentSong ? 100.0 : 40.0;

    final featuredSong = _trending.isNotEmpty
        ? _trending.first
        : const Song(
            id: 'mG4PvhXkKq8',
            title: 'Best 50 Trending TikTok Songs 2026 🎧 || Hot Hits Music Spotify',
            artist: 'JsVibes Music · Trending Top Track',
            channelId: 'jsvibes',
            thumbnailUrl: 'https://i.ytimg.com/vi/mG4PvhXkKq8/hqdefault.jpg',
            durationSeconds: 210,
            durationFormatted: '3:30',
          );

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(size: 32, showText: true),
        actions: [
          IconButton(
            icon: Icon(Icons.search, size: 26, color: AppColors.icon(context)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.notifications_none, size: 26, color: AppColors.icon(context)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No new notifications')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _moodCache.clear();
          _tasteCache.clear();
          if (_selectedMood != 'All') {
            await _selectMood(_selectedMood);
          } else {
            await _loadHomeData();
          }
        },
        color: AppColors.primaryAccent,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mood Filter Chips
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  itemCount: _moodTags.length,
                  itemBuilder: (_, index) {
                    final tag = _moodTags[index];
                    final isSelected = _selectedMood == tag;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: tag != 'All'
                            ? Icon(
                                _moodIcons[tag] ?? Icons.music_note,
                                size: 16,
                                color: isSelected ? Colors.white : AppColors.primaryAccent,
                              )
                            : null,
                        label: Text(tag),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceVariant(context),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary(context),
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            _selectMood(tag);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // If a specific mood is selected, display the functional Mood Radio Section
              if (_selectedMood != 'All') ...[
                _buildMoodContent(playerProv),
              ] else if (_isLoading) ...[
                const SectionSkeleton(),
                const SectionSkeleton(),
                const SectionSkeleton(),
              ] else ...[
                // FEATURED SPOTLIGHT Banner (Matching Screenshot)
                _buildFeaturedSpotlight(featuredSong, playerProv),

                const SizedBox(height: 12),

                // DYNAMIC TASTE MATCH Card (Matching Screenshot)
                _buildDynamicTasteMatch(playerProv),

                const SizedBox(height: 16),

                // Quick Picks
                if (_quickPicks.isNotEmpty) ...[
                  _buildSectionHeader(AppStrings.quickPicks, 'Listen again'),
                  _buildSongHorizontalList(_quickPicks),
                ],

                // Recently Played (if any recorded in local storage)
                if (playlistProv.recentlyPlayed.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader(AppStrings.recentlyPlayed, 'History'),
                  _buildSongHorizontalList(playlistProv.recentlyPlayed),
                ],

                // Trending Music
                if (_trending.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader(AppStrings.trendingMusic, 'Global Charts'),
                  _buildSongHorizontalList(_trending),
                ],

                // Recommended For You
                if (_recommended.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader(AppStrings.recommended, 'Based on your taste'),
                  _buildSongHorizontalList(_recommended),
                ],

                // Popular Artists
                if (_popularArtists.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader(AppStrings.popularArtists, 'Top creators'),
                  _buildArtistHorizontalList(_popularArtists),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedSpotlight(Song featuredSong, PlayerProvider playerProv) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF221029), Color(0xFF140818)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF4081).withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 500;
          final imageWidget = Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: featuredSong.thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: featuredSong.thumbnailUrl,
                      width: isWide ? 170 : 130,
                      height: isWide ? 170 : 130,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: isWide ? 170 : 130,
                        height: isWide ? 170 : 130,
                        color: Colors.white10,
                        child: const Icon(Icons.music_note, color: Colors.white38, size: 48),
                      ),
                    )
                  : Container(
                      width: isWide ? 170 : 130,
                      height: isWide ? 170 : 130,
                      color: Colors.white10,
                      child: const Icon(Icons.music_note, color: Colors.white38, size: 48),
                    ),
            ),
          );

          final textAndButtons = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'FEATURED SPOTLIGHT',
                style: TextStyle(
                  color: Color(0xFFFF4081),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                featuredSong.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isWide ? 22 : 17,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${featuredSong.artist} · Trending Top Track',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text(
                      'Play Now',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      playerProv.playSong(featuredSong, newQueue: _trending);
                    },
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () => _showAddToPlaylistDialog(context, featuredSong),
                    child: const Text(
                      'Add to Playlist',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: textAndButtons),
                const SizedBox(width: 20),
                imageWidget,
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: imageWidget),
                const SizedBox(height: 16),
                textAndButtons,
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildDynamicTasteMatch(PlayerProvider playerProv) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF180C1B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white12,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges & Refresh Mix Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4081).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFF4081).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFFFF4081), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'DYNAMIC TASTE MATCH',
                          style: TextStyle(
                            color: Color(0xFFFF4081),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Global Pop',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Refresh Mix', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  _tasteCache.remove(_selectedTaste);
                  _loadTasteSongs(_selectedTaste);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Mix Heading
          Text(
            _selectedTaste,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Matching songs with Billie Eilish, The Weeknd & your listening vibe',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),

          // Taste Filter Chips
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tasteTags.length,
              itemBuilder: (_, index) {
                final tag = _tasteTags[index];
                final isSelected = _selectedTaste == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: const Color(0xFFFF4081),
                    backgroundColor: Colors.white10,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      if (val) {
                        _selectTaste(tag);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Taste Song List / Grid
          if (_isTasteLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primaryAccent),
              ),
            )
          else if (_tasteSongs.isNotEmpty)
            _buildSongHorizontalList(_tasteSongs)
          else
            _buildSongHorizontalList(_recommended),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Consumer<PlaylistProvider>(
          builder: (modalCtx, playlistProv, _) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Add to Playlist',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => const CreatePlaylistDialog(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  if (playlistProv.playlists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      child: Text('No playlists created yet', style: TextStyle(color: Colors.white54)),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: playlistProv.playlists.length,
                        itemBuilder: (_, index) {
                          final pl = playlistProv.playlists[index];
                          return ListTile(
                            leading: const Icon(Icons.queue_music, color: AppColors.primaryAccent),
                            title: Text(pl.title, style: const TextStyle(color: Colors.white)),
                            onTap: () {
                              playlistProv.addSongToPlaylist(pl.id, song);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Added to ${pl.title}')),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMoodContent(PlayerProvider playerProv) {
    if (_isMoodLoading) {
      return const Column(
        children: [
          SizedBox(height: 40),
          Center(child: CircularProgressIndicator(color: AppColors.primaryAccent)),
          SizedBox(height: 40),
        ],
      );
    }

    if (_moodSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Text(
                'No tracks found for $_selectedMood.',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  _moodCache.remove(_selectedMood);
                  _selectMood(_selectedMood);
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mood Station Hero Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.8),
                AppColors.surfaceVariant(context),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_moodIcons[_selectedMood] ?? Icons.music_note, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_selectedMood Mix',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _moodSubtitles[_selectedMood] ?? 'Curated for you',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: () {
                  if (_moodSongs.isNotEmpty) {
                    playerProv.playSong(_moodSongs[0], newQueue: _moodSongs);
                  }
                },
                child: const Icon(Icons.play_arrow, size: 28),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        _buildSectionHeader('$_selectedMood Tracks', 'Hand-picked Selection'),
        _buildSongHorizontalList(_moodSongs),

        const SizedBox(height: 16),
        _buildSectionHeader('More for $_selectedMood', 'Up Next In Queue'),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: _moodSongs.length > 5 ? _moodSongs.length - 5 : _moodSongs.length,
          itemBuilder: (_, index) {
            final song = _moodSongs.length > 5 ? _moodSongs[index + 5] : _moodSongs[index];
            return SongCard(
              song: song,
              queueContext: _moodSongs,
              variant: SongCardVariant.listTile,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle.toUpperCase(),
            style: TextStyle(
              color: AppColors.textTertiary(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongHorizontalList(List<Song> songs) {
    return SizedBox(
      height: 215,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: songs.length,
        itemBuilder: (_, index) {
          return SongCard(
            song: songs[index],
            queueContext: songs,
            variant: SongCardVariant.horizontalCard,
          );
        },
      ),
    );
  }

  Widget _buildArtistHorizontalList(List<Artist> artists) {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: artists.length,
        itemBuilder: (_, index) {
          return ArtistCard(
            artist: artists[index],
          );
        },
      ),
    );
  }
}
