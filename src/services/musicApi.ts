import { Song, Artist, Playlist } from '../types';

export const POPULAR_FEATURED_SONGS: Song[] = [
  {
    id: 'fJ9rUzIMcZQ',
    title: 'Bohemian Rhapsody',
    artist: 'Queen',
    channelId: 'QueenOfficial',
    thumbnailUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
    durationSeconds: 355,
    durationFormatted: '05:55',
    viewCount: 1600000000,
    playCount: 14,
  },
  {
    id: 'kJQP7kiw5Fk',
    title: 'Despacito',
    artist: 'Luis Fonsi ft. Daddy Yankee',
    channelId: 'LuisFonsiVEVO',
    thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=80',
    durationSeconds: 282,
    durationFormatted: '04:42',
    viewCount: 8400000000,
    playCount: 9,
  },
  {
    id: 'JGwWNGJdvx8',
    title: 'Shape of You',
    artist: 'Ed Sheeran',
    channelId: 'EdSheeran',
    thumbnailUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=80',
    durationSeconds: 234,
    durationFormatted: '03:54',
    viewCount: 6200000000,
    playCount: 18,
  },
  {
    id: '4NRXx6U8ABQ',
    title: 'Blinding Lights',
    artist: 'The Weeknd',
    channelId: 'TheWeekndVEVO',
    thumbnailUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
    durationSeconds: 200,
    durationFormatted: '03:20',
    viewCount: 3000000000,
    playCount: 22,
  },
  {
    id: 'hT_nvWreIhg',
    title: 'Counting Stars',
    artist: 'OneRepublic',
    channelId: 'OneRepublicVEVO',
    thumbnailUrl: 'https://images.unsplash.com/photo-1445985543469-433ecdd6294c?w=500&auto=format&fit=crop&q=80',
    durationSeconds: 257,
    durationFormatted: '04:17',
    viewCount: 3900000000,
    playCount: 12,
  },
  {
    id: 'CevxZvSJLk8',
    title: 'Roar',
    artist: 'Katy Perry',
    channelId: 'KatyPerryVEVO',
    thumbnailUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=500&auto=format&fit=crop&q=80',
    durationSeconds: 223,
    durationFormatted: '03:43',
    viewCount: 3900000000,
    playCount: 8,
  },
  {
    id: '09R8_2nJtjg',
    title: 'Sugar',
    artist: 'Maroon 5',
    channelId: 'Maroon5VEVO',
    thumbnailUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=500&auto=format&fit=crop&q=80',
    durationSeconds: 235,
    durationFormatted: '03:55',
    viewCount: 3900000000,
    playCount: 15,
  },
  {
    id: 'YQHsXMglC9A',
    title: 'Hello',
    artist: 'Adele',
    channelId: 'AdeleVEVO',
    thumbnailUrl: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&auto=format&fit=crop&q=80',
    durationSeconds: 295,
    durationFormatted: '04:55',
    viewCount: 3100000000,
    playCount: 11,
  },
];

export const FEATURED_ARTISTS: Artist[] = [
  { id: 'art_edsheeran', name: 'Ed Sheeran', thumbnailUrl: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=300&auto=format&fit=crop&q=80', subscribers: '54M' },
  { id: 'art_theweeknd', name: 'The Weeknd', thumbnailUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=300&auto=format&fit=crop&q=80', subscribers: '35M' },
  { id: 'art_billie', name: 'Billie Eilish', thumbnailUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=300&auto=format&fit=crop&q=80', subscribers: '49M' },
  { id: 'art_queen', name: 'Queen', thumbnailUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=300&auto=format&fit=crop&q=80', subscribers: '18M' },
  { id: 'art_arijit', name: 'Arijit Singh', thumbnailUrl: 'https://images.unsplash.com/photo-1465847899084-d164df4dedc6?w=300&auto=format&fit=crop&q=80', subscribers: '42M' },
  { id: 'art_anupam', name: 'Anupam Roy', thumbnailUrl: 'https://images.unsplash.com/photo-1501386761578-eac5c94b800a?w=300&auto=format&fit=crop&q=80', subscribers: '3.2M' },
];

export class MusicApi {
  static async searchSongs(query: string): Promise<Song[]> {
    if (!query.trim()) return [];
    try {
      const res = await fetch(`/api/search?q=${encodeURIComponent(query)}`);
      if (res.ok) {
        const data = await res.json();
        if (Array.isArray(data.songs) && data.songs.length > 0) {
          return data.songs;
        }
      }
    } catch {
      // Fallback
    }

    // Client-side fallback matching
    const qLower = query.toLowerCase();
    const matched = POPULAR_FEATURED_SONGS.filter(
      (s) => s.title.toLowerCase().includes(qLower) || s.artist.toLowerCase().includes(qLower)
    );
    if (matched.length > 0) return matched;

    // Generated simulated search tracks for the query so user always gets instant results
    return [
      {
        id: `custom_${Date.now()}_1`,
        title: `${query} (Official Acoustic Mix)`,
        artist: query.split(' ')[0] || 'Twilight Music Artist',
        channelId: 'twilight_curated',
        thumbnailUrl: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=80',
        durationSeconds: 215,
        durationFormatted: '03:35',
        viewCount: 154000,
      },
      {
        id: `custom_${Date.now()}_2`,
        title: `${query} - Live Session & Vibes`,
        artist: 'Various Artists',
        channelId: 'twilight_sessions',
        thumbnailUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
        durationSeconds: 248,
        durationFormatted: '04:08',
        viewCount: 92000,
      },
      ...POPULAR_FEATURED_SONGS.slice(0, 4),
    ];
  }

  static async getTrendingSongs(): Promise<Song[]> {
    try {
      const res = await fetch('/api/trending');
      if (res.ok) {
        const data = await res.json();
        if (Array.isArray(data.songs) && data.songs.length > 0) {
          return data.songs;
        }
      }
    } catch {
      // fallback
    }
    return POPULAR_FEATURED_SONGS;
  }

  static async getDynamicMix(params: {
    artists: string[];
    genres: string[];
    historyIds: string[];
    vibe: string;
  }): Promise<Song[]> {
    try {
      const res = await fetch('/api/recommendations/dynamic', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(params),
      });
      if (res.ok) {
        const data = await res.json();
        if (Array.isArray(data.songs) && data.songs.length > 0) {
          return data.songs;
        }
      }
    } catch {
      // fallback
    }

    // Dynamic mix fallback
    return [...POPULAR_FEATURED_SONGS].sort(() => 0.5 - Math.random());
  }

  static getAudioStreamUrl(songId: string): string {
    return `/api/stream/${encodeURIComponent(songId)}`;
  }
}
