import { Song, TasteProfile, VibeCategory } from '../types';

export const VIBE_CATEGORIES: VibeCategory[] = [
  { id: 'lofi', label: '☕ Lo-Fi & Focus', icon: 'Coffee', query: 'Lo-Fi Focus Study Beats' },
  { id: 'romantic', label: '💖 Romantic Melodies', icon: 'Heart', query: 'Romantic Acoustic Love Songs' },
  { id: 'bengali', label: '🇧🇩 Bengali Melodies', icon: 'Music', query: 'Best Bengali Soulful Acoustic Melodies' },
  { id: 'energy', label: '⚡ Energy & Pop', icon: 'Zap', query: 'Top Pop Dance Hits' },
  { id: 'chill', label: '🌙 Late Night Chill', icon: 'Moon', query: 'Midnight Chill Ambient Acoustic' },
  { id: 'acoustic', label: '🎸 Acoustic & Soulful', icon: 'Guitar', query: 'Acoustic Guitar Unplugged Hits' },
  { id: 'workout', label: '🔥 Workout & Drive', icon: 'Flame', query: 'High Energy Workout EDM' },
  { id: 'rock', label: '🤘 Rock & Alternative', icon: 'Disc', query: 'Modern Alternative Rock Hits' },
];

export const getTimeBasedVibe = (): { label: string; id: string; query: string } => {
  const hour = new Date().getHours();
  if (hour >= 5 && hour < 12) {
    return { label: '☀️ Morning Boost', id: 'morning', query: 'Morning Energy Acoustic Pop' };
  }
  if (hour >= 12 && hour < 17) {
    return { label: '🔥 Afternoon Focus', id: 'afternoon', query: 'Upbeat Focus Lo-Fi Pop Hits' };
  }
  if (hour >= 17 && hour < 22) {
    return { label: '🌆 Sunset Groove', id: 'evening', query: 'Evening Chill Melodies' };
  }
  return { label: '🌙 Midnight Serenade', id: 'night', query: 'Late Night Acoustic Chill Ambient' };
};

export class TasteEngine {
  static analyzeTaste(history: Song[], favorites: Song[]): TasteProfile {
    const artistCounts: Record<string, number> = {};
    const playCounts: Record<string, number> = {};

    // Combine history and favorites (weight favorites double)
    [...history, ...favorites, ...favorites].forEach((song) => {
      if (song.artist) {
        artistCounts[song.artist] = (artistCounts[song.artist] || 0) + 1;
      }
      playCounts[song.id] = (playCounts[song.id] || 0) + 1;
    });

    const topArtists = Object.entries(artistCounts)
      .sort((a, b) => b[1] - a[1])
      .map(([artist]) => artist)
      .slice(0, 5);

    const summaryLabel = topArtists.length > 0
      ? `Inspired by ${topArtists.slice(0, 2).join(' & ')}`
      : 'Your Personalized Mix';

    return {
      topArtists,
      favoriteGenres: ['Pop', 'Acoustic', 'Lo-Fi', 'Melodic'],
      topVibes: ['Chill', 'Soulful', 'Acoustic'],
      recentPlays: history.slice(0, 10),
      playCounts,
      summaryLabel,
    };
  }

  static getDynamicQueries(profile: TasteProfile, selectedVibeId?: string): string[] {
    const queries: string[] = [];

    if (selectedVibeId && selectedVibeId !== 'for_you') {
      const match = VIBE_CATEGORIES.find((v) => v.id === selectedVibeId);
      if (match) {
        queries.push(match.query);
      }
    }

    if (profile.topArtists.length > 0) {
      queries.push(`${profile.topArtists[0]} top hits`);
      if (profile.topArtists[1]) {
        queries.push(`${profile.topArtists[1]} best songs`);
      }
      queries.push(`${profile.topArtists.slice(0, 2).join(' ')} radio`);
    }

    const timeVibe = getTimeBasedVibe();
    queries.push(timeVibe.query);

    return queries;
  }
}
