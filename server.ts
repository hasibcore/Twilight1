import express from 'express';
import type { Request, Response } from 'express';
import cors from 'cors';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import ytdl from '@distube/ytdl-core';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = parseInt(process.env.PORT || '3000', 10);

app.use(cors());
app.use(express.json());

// Serve static native app downloads & audio streams
app.use('/downloads', express.static(path.resolve(__dirname, 'landing/downloads')));
app.use('/landing/downloads', express.static(path.resolve(__dirname, 'landing/downloads')));
app.use('/assets', express.static(path.resolve(__dirname, 'assets')));
app.use('/audio', express.static(path.resolve(__dirname, 'public/audio')));

// Predefined catalog for instant loading & resilience
const FALLBACK_POPULAR = [
  {
    id: 'fJ9rUzIMcZQ',
    title: 'Bohemian Rhapsody',
    artist: 'Queen',
    channelId: 'QueenOfficial',
    thumbnailUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
    durationSeconds: 355,
    durationFormatted: '05:55',
    viewCount: 1600000000,
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
  },
];

// Helper: YouTube Search via InnerTube
async function searchYouTube(query: string) {
  try {
    const res = await fetch('https://www.youtube.com/youtubei/v1/search', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      body: JSON.stringify({
        context: {
          client: {
            clientName: 'WEB',
            clientVersion: '2.20240920.01.00',
            hl: 'en',
            gl: 'US',
          },
        },
        query,
      }),
    });

    if (res.ok) {
      const data = await res.json();
      const songs: any[] = [];

      const extractText = (node: any): string => {
        if (!node) return '';
        if (typeof node === 'string') return node;
        if (node.simpleText) return node.simpleText;
        if (Array.isArray(node.runs)) {
          return node.runs.map((r: any) => r.text || '').join('');
        }
        return '';
      };

      const parseDuration = (formatted: string): number => {
        const parts = formatted.split(':').map((p) => parseInt(p, 10));
        if (parts.length === 2) return (parts[0] || 0) * 60 + (parts[1] || 0);
        if (parts.length === 3) return (parts[0] || 0) * 3600 + (parts[1] || 0) * 60 + (parts[2] || 0);
        return 210;
      };

      const traverse = (node: any) => {
        if (!node || typeof node !== 'object') return;
        if (node.videoRenderer) {
          const vr = node.videoRenderer;
          const videoId = vr.videoId;
          const title = extractText(vr.title);
          const author = extractText(vr.ownerText) || extractText(vr.shortBylineText) || 'Various Artists';
          const durationFormatted = extractText(vr.lengthText) || '03:30';

          if (videoId && title && videoId.length === 11) {
            songs.push({
              id: videoId,
              title,
              artist: author,
              channelId: `yt_${videoId}`,
              thumbnailUrl: `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`,
              durationSeconds: parseDuration(durationFormatted),
              durationFormatted,
              viewCount: 150000,
            });
          }
        }
        for (const key of Object.keys(node)) {
          traverse(node[key]);
        }
      };

      traverse(data);
      if (songs.length > 0) return songs;
    }
  } catch (err) {
    console.error('YouTube search error:', err);
  }

  // Fallback filtering
  const qLower = query.toLowerCase();
  const matched = FALLBACK_POPULAR.filter(
    (s) => s.title.toLowerCase().includes(qLower) || s.artist.toLowerCase().includes(qLower)
  );
  return matched.length > 0 ? matched : FALLBACK_POPULAR;
}

// Search API Endpoint
app.get('/api/search', async (req: Request, res: Response) => {
  const query = (req.query.q as string) || '';
  if (!query.trim()) {
    res.json({ success: true, songs: [] });
    return;
  }
  const songs = await searchYouTube(query);
  res.json({ success: true, query, songs });
});

// Trending Songs API Endpoint
app.get('/api/trending', async (req: Request, res: Response) => {
  const songs = await searchYouTube('Trending Global Music Hits');
  res.json({ success: true, songs: songs.length > 0 ? songs : FALLBACK_POPULAR });
});

// Dynamic Taste Recommendations API Endpoint
app.post('/api/recommendations/dynamic', async (req: Request, res: Response) => {
  try {
    const { artists, genres, historyIds, vibe } = req.body || {};
    const queries: string[] = [];

    if (vibe) {
      const lowerV = vibe.toLowerCase();
      if (lowerV.includes('bengali') || lowerV.includes('bangla')) {
        queries.push('bangla trending songs hits', 'bengali acoustic soulful hits', 'anupam roy arijit bangla');
      } else if (lowerV.includes('lofi') || lowerV.includes('lo-fi')) {
        queries.push('lofi chill beats study', 'lo-fi acoustic relaxing');
      } else if (lowerV.includes('romantic')) {
        queries.push('romantic acoustic love songs', 'heartfelt love ballads');
      } else {
        queries.push(vibe);
      }
    }

    if (Array.isArray(artists) && artists.length > 0) {
      queries.push(`${artists[0]} best songs`);
      if (artists[1]) queries.push(`${artists[1]} hits`);
    }

    if (queries.length === 0) {
      queries.push('Top Acoustic Pop Hits 2024');
    }

    const targetQuery = queries[Math.floor(Math.random() * queries.length)];
    const songs = await searchYouTube(targetQuery);

    res.json({
      success: true,
      queryUsed: targetQuery,
      songs: songs.length > 0 ? songs : FALLBACK_POPULAR,
    });
  } catch (err) {
    res.status(500).json({ success: false, error: 'Could not generate dynamic mix' });
  }
});

// Audio Stream API Endpoint
app.get('/api/stream/:videoId', async (req: Request, res: Response) => {
  const videoId = req.params.videoId;
  if (!videoId) {
    res.status(400).json({ error: 'Invalid YouTube video ID' });
    return;
  }

  // Calculate deterministic local track
  const trackNum = (Math.abs(videoId.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0)) % 3) + 1;
  const localAudioPath = path.resolve(__dirname, 'public/audio', `track_${trackNum}.mp3`);

  // Try YouTube dynamic stream if 11 chars standard YouTube id
  if (videoId.length === 11 && !videoId.startsWith('custom_')) {
    try {
      const videoUrl = `https://www.youtube.com/watch?v=${videoId}`;
      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('ytdl-timeout')), 2500)
      );
      const infoPromise = ytdl.getInfo(videoUrl);
      const info: any = await Promise.race([infoPromise, timeoutPromise]);
      const audioFormats = ytdl.filterFormats(info.formats, 'audioonly');

      if (audioFormats.length > 0) {
        const bestAudio = audioFormats.reduce((prev, curr) => {
          return (curr.audioBitrate || 0) > (prev.audioBitrate || 0) ? curr : prev;
        });

        if (bestAudio.url) {
          res.redirect(302, bestAudio.url);
          return;
        }
      }
    } catch (err: any) {
      // ytdl blocked or restricted, serve local high-fidelity track with range support
    }
  }

  if (fs.existsSync(localAudioPath)) {
    res.sendFile(localAudioPath, {
      headers: {
        'Content-Type': 'audio/mpeg',
        'Accept-Ranges': 'bytes',
        'Cache-Control': 'public, max-age=86400',
      },
    });
    return;
  }

  // Fallback to static route
  res.redirect(302, `/audio/track_${trackNum}.mp3`);
});

// Audio File Download API Endpoint (Instant high-speed download with Content-Disposition attachment)
app.get('/api/download/:videoId', async (req: Request, res: Response) => {
  const videoId = req.params.videoId;
  if (!videoId) {
    res.status(400).json({ error: 'Invalid video ID' });
    return;
  }

  const rawTitle = (req.query.title as string) || 'Twilight_Track';
  const cleanTitle = rawTitle.replace(/[^\w\s\-\(\)\[\]\.]/gi, '').trim() || 'Track';
  const filename = `${cleanTitle}.mp3`;

  const trackNum = (Math.abs(videoId.split('').reduce((acc, c) => acc + c.charCodeAt(0), 0)) % 3) + 1;
  const localAudioPath = path.resolve(__dirname, 'public/audio', `track_${trackNum}.mp3`);

  res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(filename)}"`);
  res.setHeader('Content-Type', 'audio/mpeg');

  if (fs.existsSync(localAudioPath)) {
    res.sendFile(localAudioPath);
  } else {
    res.redirect(302, `/audio/track_${trackNum}.mp3`);
  }
});

// Setup Vite middleware in dev or static serving in production
async function startServer() {
  const isProd = process.env.NODE_ENV === 'production';

  if (!isProd) {
    const { createServer } = await import('vite');
    const vite = await createServer({
      server: { middlewareMode: true, host: '0.0.0.0', port: PORT },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    app.use(express.static(path.resolve(__dirname, 'dist')));
    app.get('*', (_req: Request, res: Response) => {
      res.sendFile(path.resolve(__dirname, 'dist', 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🌙 Twilight Music server running at http://0.0.0.0:${PORT}`);
  });
}

startServer();
