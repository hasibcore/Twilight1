import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/player_provider.dart';
import '../../core/constants/app_colors.dart';
import '../screens/player/full_player_screen.dart';

class MiniPlayerWidget extends StatelessWidget {
  const MiniPlayerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final currentSong = player.currentSong;

    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    // Calculate progress ratio
    double progress = 0.0;
    if (player.totalDuration.inSeconds > 0) {
      progress = (player.currentPosition.inSeconds / player.totalDuration.inSeconds).clamp(0.0, 1.0);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.surfaceVariantDark.withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.96);
    final primaryTextColor = AppColors.textPrimary(context);
    final secondaryTextColor = AppColors.textSecondary(context);
    final iconColor = isDark ? Colors.white : AppColors.primary;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, anim, secAnim) => const FullPlayerScreen(),
            transitionsBuilder: (context, anim, secAnim, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOutCubic));
              return SlideTransition(position: anim.drive(tween), child: child);
            },
          ),
        );
      },
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -300) {
            // Swipe up opens full player
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FullPlayerScreen()),
            );
          } else if (details.primaryVelocity! > 300) {
            // Swipe down stops playback
            player.stop();
          }
        }
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < -300) {
            player.next();
          } else if (details.primaryVelocity! > 300) {
            player.previous();
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress Bar Line at top of mini player
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
                minHeight: 2.5,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: currentSong.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: currentSong.thumbnailUrl,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                              child: Icon(Icons.music_note, color: secondaryTextColor),
                            ),
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                            child: Icon(Icons.music_note, color: secondaryTextColor),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Title & Artist
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentSong.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentSong.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Play / Pause Button
                  IconButton(
                    icon: player.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryAccent,
                            ),
                          )
                        : player.errorMessage != null
                            ? const Icon(
                                Icons.refresh_rounded,
                                color: Colors.redAccent,
                                size: 30,
                              )
                            : Icon(
                                player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: iconColor,
                                size: 32,
                              ),
                    onPressed: () {
                      if (player.errorMessage != null) {
                        player.retryCurrentSong();
                      } else {
                        player.togglePlayPause();
                      }
                    },
                  ),
                  // Next Track Button
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded, color: iconColor, size: 28),
                    onPressed: () => player.next(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
