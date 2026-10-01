export interface Song {
  id: string;
  title: string;
  artist: string;
  channelId?: string;
  thumbnailUrl: string;
  durationSeconds: number;
  durationFormatted: string;
  viewCount?: number;
  isFavorite?: boolean;
  playCount?: number;
  lastPlayedAt?: number;
  audioUrl?: string;
}

export interface Playlist {
  id: string;
  title: string;
  description: string;
  thumbnailUrl?: string;
  songs: Song[];
  updatedAt: number;
  isCustom?: boolean;
}

export interface Artist {
  id: string;
  name: string;
  thumbnailUrl: string;
  subscribers?: string;
}

export interface TasteProfile {
  topArtists: string[];
  favoriteGenres: string[];
  topVibes: string[];
  recentPlays: Song[];
  playCounts: Record<string, number>;
  summaryLabel: string;
}

export interface UserProfile {
  uid: string;
  email: string | null;
  displayName: string | null;
  photoURL: string | null;
  isGuest: boolean;
}

export interface VibeCategory {
  id: string;
  label: string;
  icon: string;
  query: string;
}
