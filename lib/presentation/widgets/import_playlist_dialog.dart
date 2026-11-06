import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/music_import_service.dart';
import '../providers/player_provider.dart';
import '../providers/playlist_provider.dart';

class ImportPlaylistDialog extends StatefulWidget {
  const ImportPlaylistDialog({super.key});

  @override
  State<ImportPlaylistDialog> createState() => _ImportPlaylistDialogState();
}

class _ImportPlaylistDialogState extends State<ImportPlaylistDialog> {
  final TextEditingController _urlController = TextEditingController();
  final MusicImportService _importService = MusicImportService();
  bool _isLoading = false;
  String? _statusMessage;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _urlController.text = data.text!.trim();
      });
    }
  }

  Future<void> _processImport(String url, {bool playImmediately = true}) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching playlist metadata...';
    });

    try {
      final songs = await _importService.importFromUrl(trimmed);

      if (!mounted) return;

      if (songs.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Could not find tracks at this link. Please verify the URL.';
        });
        return;
      }

      setState(() {
        _statusMessage = 'Found ${songs.length} tracks!';
      });

      final player = context.read<PlayerProvider>();
      final playlistProv = context.read<PlaylistProvider>();

      if (playImmediately) {
        player.playSong(songs.first, newQueue: songs);
      }

      // Automatically create a playlist in user's library
      final playlistTitle = trimmed.contains('spotify') ? 'Spotify Import' : 'Web Playlist';
      final newPlaylist = await playlistProv.createPlaylist(
        '$playlistTitle (${DateTime.now().month}/${DateTime.now().day})',
        description: 'Imported from $trimmed',
      );
      for (final s in songs.take(30)) {
        await playlistProv.addSongToPlaylist(newPlaylist.id, s);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${songs.length} tracks!'),
            backgroundColor: const Color(0xFF00C853),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error during import: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.link_rounded, color: AppColors.primaryAccent, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Web Playlist',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Supports public Spotify & YouTube music links',
                        style: TextStyle(
                          color: AppColors.textSecondaryDark,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              enabled: !_isLoading,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Paste track, album or playlist URL...',
                hintStyle: const TextStyle(color: AppColors.textTertiaryDark, fontSize: 12),
                prefixIcon: const Icon(Icons.music_note, color: AppColors.textSecondaryDark, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded, color: AppColors.primaryAccent, size: 20),
                  tooltip: 'Paste from clipboard',
                  onPressed: _pasteFromClipboard,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Quick Preset Suggestions
            const Text(
              'OR SELECT POPULAR CHARTS:',
              style: TextStyle(
                color: AppColors.textTertiaryDark,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildPresetChip('Top 50 Global', 'https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M'),
                _buildPresetChip('Viral Hits', 'https://open.spotify.com/playlist/37i9dQZF1DX2L0iB23Enbq'),
                _buildPresetChip('Chill Acoustic', 'https://open.spotify.com/playlist/37i9dQZF1DXatOAcAub419'),
              ],
            ),

            if (_statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _statusMessage!.contains('Error') || _statusMessage!.contains('Could not')
                      ? Colors.redAccent
                      : const Color(0xFF00E676),
                  fontSize: 12,
                ),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(_isLoading ? 'Importing...' : 'Import & Play'),
                  onPressed: _isLoading ? null : () => _processImport(_urlController.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, String url) {
    return ActionChip(
      backgroundColor: AppColors.surfaceVariantDark,
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      avatar: const Icon(Icons.flash_on_rounded, color: AppColors.primaryAccent, size: 14),
      onPressed: _isLoading
          ? null
          : () {
              setState(() => _urlController.text = url);
              _processImport(url);
            },
    );
  }
}
