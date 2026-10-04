import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/download_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/song_card.dart';
import '../playlist/create_playlist_dialog.dart';
import '../playlist/playlist_detail_screen.dart';
import '../../widgets/import_playlist_dialog.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playlistProv = context.watch<PlaylistProvider>();
    final downloadProv = context.watch<DownloadProvider>();
    final hasCurrentSong =
        context.select<PlayerProvider, bool>((p) => p.currentSong != null);
    final bottomPadding = hasCurrentSong ? 100.0 : 40.0;

    final currentSongId =
        context.select<PlayerProvider, String?>((p) => p.currentSong?.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_rounded),
            tooltip: 'Import Web Playlist',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const ImportPlaylistDialog(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: AppStrings.createPlaylist,
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const CreatePlaylistDialog(),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primaryAccent,
          labelColor: AppColors.textPrimary(context),
          unselectedLabelColor: AppColors.textSecondary(context),
          tabs: [
            const Tab(text: 'Playlists'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Downloads'),
                  if (downloadProv.count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${downloadProv.count}',
                        style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Liked Songs'),
            const Tab(text: 'History'),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: TabBarView(
          controller: _tabController,
          children: [
            // Playlists Tab
            _buildPlaylistsTab(playlistProv),
            // Downloads Tab
            _buildDownloadsTab(downloadProv, currentSongId),
            // Liked Songs Tab
            _buildLikedSongsTab(playlistProv),
            // History Tab
            _buildHistoryTab(playlistProv),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadsTab(
      DownloadProvider downloadProv, String? currentSongId) {
    final downloads = downloadProv.downloads;

    if (downloads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.download_for_offline_outlined,
                  size: 64, color: AppColors.textTertiary(context)),
              const SizedBox(height: 16),
              Text(
                'No downloaded songs',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the download icon on any song to save it for offline playback without internet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 13,
                    height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Action header (Track count & Play All button)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${downloads.length} Offline Tracks',
                style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Play All'),
                onPressed: () {
                  final downloadedSongs = downloadProv.downloadedSongs;
                  if (downloadedSongs.isNotEmpty) {
                    context.read<PlayerProvider>().playSong(
                        downloadedSongs.first,
                        newQueue: downloadedSongs);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final item = downloads[index];
              final isCurrent = currentSongId == item.song.id;
              final sizeMb = (item.fileSize / (1024 * 1024)).toStringAsFixed(1);

              return ListTile(
                leading: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.localThumbnailPath != null &&
                              File(item.localThumbnailPath!).existsSync()
                          ? Image.file(
                              File(item.localThumbnailPath!),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            )
                          : (item.song.thumbnailUrl.isNotEmpty
                              ? Image.network(
                                  item.song.thumbnailUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 48,
                                    height: 48,
                                    color: AppColors.surfaceVariantDark,
                                    child: const Icon(Icons.music_note,
                                        color: Colors.white38),
                                  ),
                                )
                              : Container(
                                  width: 48,
                                  height: 48,
                                  color: AppColors.surfaceVariantDark,
                                  child: const Icon(Icons.music_note,
                                      color: Colors.white38),
                                )),
                    ),
                    if (isCurrent)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.equalizer,
                              color: AppColors.primaryAccent, size: 24),
                        ),
                      ),
                  ],
                ),
                title: Text(
                  item.song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCurrent
                        ? AppColors.primaryAccent
                        : AppColors.textPrimary(context),
                  ),
                ),
                subtitle: Text(
                  '${item.song.artist} • $sizeMb MB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.textSecondary(context), fontSize: 12),
                ),
                trailing: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppColors.icon(context)),
                  color: AppColors.surface(context),
                  onSelected: (val) {
                    if (val == 'play') {
                      context.read<PlayerProvider>().playSong(item.song,
                          newQueue: downloadProv.downloadedSongs);
                    } else if (val == 'delete') {
                      downloadProv.deleteDownload(item.song.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Download removed')),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'play',
                      child: Row(
                        children: [
                          Icon(Icons.play_arrow,
                              color: AppColors.icon(context)),
                          const SizedBox(width: 8),
                          Text('Play offline',
                              style: TextStyle(
                                  color: AppColors.textPrimary(context))),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Delete download',
                              style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  context.read<PlayerProvider>().playSong(item.song,
                      newQueue: downloadProv.downloadedSongs);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsTab(PlaylistProvider prov) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // Create Playlist Action Tile
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.add, color: AppColors.primaryAccent, size: 28),
          ),
          title: Text(
            AppStrings.createPlaylist,
            style: TextStyle(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            'Create a new music collection',
            style: TextStyle(
                color: AppColors.textSecondary(context), fontSize: 12),
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => const CreatePlaylistDialog(),
            );
          },
        ),
        Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),

        // User Playlists List
        ...prov.playlists.map((playlist) {
          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: playlist.thumbnailUrl.isNotEmpty
                  ? Image.network(
                      playlist.thumbnailUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: AppColors.surfaceVariant(context),
                        child: Icon(Icons.queue_music,
                            color: AppColors.iconMuted(context)),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: AppColors.surfaceVariant(context),
                      child: Icon(Icons.queue_music,
                          color: AppColors.iconMuted(context)),
                    ),
            ),
            title: Text(
              playlist.title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context)),
            ),
            subtitle: Text(
              '${playlist.songCount} songs • ${playlist.description}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.textSecondary(context), fontSize: 12),
            ),
            trailing:
                Icon(Icons.chevron_right, color: AppColors.iconMuted(context)),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PlaylistDetailScreen(playlist: playlist),
                ),
              );
            },
          );
        }),

        if (prov.playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.queue_music,
                      size: 48,
                      color: AppColors.textTertiary(context)
                          .withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('No playlists yet',
                      style: TextStyle(
                          color: AppColors.textPrimary(context),
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Tap "+ New Playlist" above to create one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 13)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLikedSongsTab(PlaylistProvider prov) {
    if (prov.favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite_border,
                  size: 64, color: AppColors.textTertiary(context)),
              const SizedBox(height: 16),
              Text(
                'No liked songs yet',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the heart icon while playing any song to save it here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: prov.favorites.length,
      itemBuilder: (_, index) {
        final song = prov.favorites[index];
        return SongCard(
          song: song,
          queueContext: prov.favorites,
          variant: SongCardVariant.listTile,
        );
      },
    );
  }

  Widget _buildHistoryTab(PlaylistProvider prov) {
    if (prov.recentlyPlayed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history,
                  size: 64, color: AppColors.textTertiary(context)),
              const SizedBox(height: 16),
              Text(
                'No listening history',
                style: TextStyle(
                    color: AppColors.textPrimary(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Songs you listen to will automatically appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${prov.recentlyPlayed.length} Tracks',
                style: TextStyle(
                    color: AppColors.textSecondary(context), fontSize: 13),
              ),
              TextButton(
                onPressed: () => prov.clearRecentlyPlayed(),
                child: const Text('Clear History',
                    style: TextStyle(color: AppColors.primaryAccent)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: prov.recentlyPlayed.length,
            itemBuilder: (_, index) {
              final song = prov.recentlyPlayed[index];
              return SongCard(
                song: song,
                queueContext: prov.recentlyPlayed,
                variant: SongCardVariant.listTile,
              );
            },
          ),
        ),
      ],
    );
  }
}
