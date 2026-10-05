import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/download_provider.dart';
import '../../../core/services/user_database_service.dart';
import 'settings_screen.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final nameController = TextEditingController(text: auth.user?.name ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.primaryAccent),
            const SizedBox(width: 8),
            Text(
              'Edit Profile',
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update your display name across Twilight Music:',
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: TextStyle(color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: TextStyle(color: AppColors.textSecondary(context)),
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryAccent),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && auth.user != null) {
                await UserDatabaseService.updateProfile(
                  uid: auth.user!.uid,
                  displayName: newName,
                );
                await auth.checkAuthStatus();
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully!')),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showDatabaseDetailsDialog(BuildContext context, AuthProvider auth) {
    final user = auth.user;
    final dbUser = user != null ? UserDatabaseService.findUserByEmail(user.email) : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.storage_rounded, color: AppColors.primaryAccent),
            const SizedBox(width: 8),
            Text(
              'Database Account Info',
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDbRow(context, 'Account UID', user?.uid ?? 'guest_uid'),
            _buildDbRow(context, 'Database Email', user?.email ?? 'Not registered'),
            _buildDbRow(context, 'Display Name', user?.name ?? 'Guest Listener'),
            _buildDbRow(context, 'Role', dbUser?['role']?.toString() ?? 'listener'),
            _buildDbRow(context, 'Auth Source', (user?.isGuest ?? true) ? 'Local Guest Session' : 'Firebase + Local Users Table'),
            _buildDbRow(context, 'Created Date', dbUser?['createdAt']?.toString().split('T').first ?? 'Today'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_outlined, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Typed login credentials match stored database table records.',
                      style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: AppColors.textPrimary(context))),
          ),
        ],
      ),
    );
  }

  Widget _buildDbRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final playlistProv = context.watch<PlaylistProvider>();
    final downloadProv = context.watch<DownloadProvider>();
    final user = auth.user;
    final isGuest = auth.isGuest || user == null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account & Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: AppColors.icon(context)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Profile Hero Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: AppColors.primary,
                      backgroundImage: user != null && user.avatarUrl.isNotEmpty
                          ? NetworkImage(user.avatarUrl)
                          : null,
                      child: user == null || user.avatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 38, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Guest Listener',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'guest@twilight.app',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isGuest
                                      ? Colors.grey.withValues(alpha: 0.2)
                                      : Colors.green.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isGuest
                                        ? Colors.grey.withValues(alpha: 0.4)
                                        : Colors.green.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isGuest ? Icons.person_outline : Icons.verified_user_rounded,
                                      size: 13,
                                      color: isGuest ? AppColors.textSecondary(context) : Colors.green,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      isGuest ? 'Guest Session' : 'Database Verified',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isGuest ? AppColors.textSecondary(context) : Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => _showDatabaseDetailsDialog(context, auth),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.info_outline, size: 13, color: AppColors.primaryAccent),
                                      SizedBox(width: 4),
                                      Text(
                                        'DB Info',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryAccent),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isGuest)
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: AppColors.icon(context)),
                        tooltip: 'Edit Profile',
                        onPressed: () => _showEditProfileDialog(context, auth),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 8),

                // Statistics Row: Liked, Playlists, Downloads
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(context, 'Favorites', '${playlistProv.favorites.length}', Icons.favorite, Colors.redAccent),
                    _buildStatItem(context, 'Playlists', '${playlistProv.playlists.length}', Icons.queue_music, AppColors.primaryAccent),
                    _buildStatItem(context, 'Downloads', '${downloadProv.count}', Icons.download_done, const Color(0xFF00E676)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sign In / Register Prompt if in Guest mode
          if (isGuest) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.surfaceVariant(context),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync_outlined, color: AppColors.primaryAccent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Save Your Music Library',
                              style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Create a verified database account to sync favorites & playlists across devices.',
                              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Sign In / Register Account', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AuthScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // App Settings & Details
          Text(
            'PREFERENCES & SYSTEM',
            style: TextStyle(
              color: AppColors.textTertiary(context),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),

          _buildMenuTile(
            context: context,
            icon: Icons.tune_rounded,
            title: 'Playback & Audio Settings',
            subtitle: 'Theme, Bitrate quality, Autoplay, Equalizer',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          _buildMenuTile(
            context: context,
            icon: Icons.history_rounded,
            title: 'Listening History',
            subtitle: '${playlistProv.recentlyPlayed.length} songs recorded',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Access and manage your history in the Library tab.')),
              );
            },
          ),
          _buildMenuTile(
            context: context,
            icon: Icons.storage_rounded,
            title: 'Database Account Details',
            subtitle: 'Inspect local & cloud database tables',
            onTap: () => _showDatabaseDetailsDialog(context, auth),
          ),
          _buildMenuTile(
            context: context,
            icon: Icons.info_outline_rounded,
            title: 'About Twilight Music',
            subtitle: 'Version 1.0.10 • High-Fidelity Audio',
            onTap: () => _showAboutDialog(context),
          ),

          if (!isGuest) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out From Account', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out successfully.')),
                  );
                }
              },
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.icon(context)),
      title: Text(
        title,
        style: TextStyle(color: AppColors.textPrimary(context), fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.iconMuted(context)),
      onTap: onTap,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.music_note_rounded, color: AppColors.primaryAccent),
            SizedBox(width: 8),
            Text('Twilight Music'),
          ],
        ),
        content: Text(
          'Version 1.0.10\n\nHigh-Performance music streaming & offline download platform with persistent database user authentication, background audio playback, and dynamic live autocomplete search.',
          style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.primaryAccent)),
          ),
        ],
      ),
    );
  }
}
