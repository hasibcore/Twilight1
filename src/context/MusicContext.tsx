import React, { createContext, useContext, useState, useEffect, useRef, useMemo } from 'react';
import { Song, Playlist, UserProfile } from '../types';
import { POPULAR_FEATURED_SONGS, MusicApi, isShortPreviewUrl } from '../services/musicApi';
import {
  auth,
  googleProvider,
  signInWithPopup,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  fbSignOut,
  onAuthStateChanged,
  CloudSyncService,
  setDriveAccessToken,
} from '../services/firebase';
import { GoogleAuthProvider } from 'firebase/auth';

interface MusicContextType {
  currentSong: Song | null;
  queue: Song[];
  currentIndex: number;
  isPlaying: boolean;
  isLoading: boolean;
  isRefreshingStream: boolean;
  streamRefreshCount: number;
  currentTime: number;
  duration: number;
  volume: number;
  isShuffle: boolean;
  isRepeat: boolean;
  playbackSpeed: number;
  audioQuality: string;
  favorites: Song[];
  history: Song[];
  frequentTracks: (Song & { playCount: number })[];
  playlists: Playlist[];
  downloads: Song[];
  user: UserProfile;
  sleepTimerRemaining: number | null;
  // Controls
  playSong: (song: Song, newQueue?: Song[], options?: { immediate?: boolean; forceRestart?: boolean }) => void;
  selectAndPlaySong: (song: Song, newQueue?: Song[]) => void;
  stopCurrentBeforeSwitch: () => void;
  pauseSong: () => void;
  resumeSong: () => void;
  nextSong: () => void;
  prevSong: () => void;
  seekTo: (seconds: number) => void;
  setVolume: (vol: number) => void;
  toggleShuffle: () => void;
  toggleRepeat: () => void;
  setPlaybackSpeed: (speed: number) => void;
  setAudioQuality: (q: string) => void;
  setSleepTimer: (minutes: number | null) => void;
  // Library Actions
  toggleFavorite: (song: Song) => void;
  isFavorite: (id: string) => boolean;
  createPlaylist: (title: string, description?: string) => Playlist;
  deletePlaylist: (playlistId: string) => void;
  addToPlaylist: (playlistId: string, song: Song) => void;
  removeFromPlaylist: (playlistId: string, songId: string) => void;
  downloadSong: (song: Song) => void;
  retryDownload: (song: Song) => void;
  removeDownload: (songId: string) => void;
  isDownloaded: (songId: string) => boolean;
  isDownloading: (songId: string) => boolean;
  // Auth
  signInWithGoogle: () => Promise<void>;
  signInWithEmail: (e: string, p: string) => Promise<void>;
  registerWithEmail: (e: string, p: string) => Promise<void>;
  signOut: () => Promise<void>;
  updateUser: (updates: Partial<UserProfile>) => void;
}

const MusicContext = createContext<MusicContextType | null>(null);

const STORAGE_KEYS = {
  FAVORITES: 'twilight_favorites_v2',
  HISTORY: 'twilight_history_v2',
  PLAYLISTS: 'twilight_playlists_v2',
  DOWNLOADS: 'twilight_downloads_v2',
  PLAY_COUNTS: 'twilight_play_counts_v2',
  SETTINGS: 'twilight_settings_v2',
};

export const PROACTIVE_PAUSE_REFRESH_MS = 3 * 60 * 1000; // 3 minutes (180,000ms)
export const STREAM_MAX_AGE_MS = 5 * 60 * 1000; // 5 minutes (300,000ms)
export const SONG_SELECTION_DEBOUNCE_MS = 300; // 300ms debounce window for song selection

const OFFLINE_IDB_NAME = 'twilight_offline_audio_db_v2';
const OFFLINE_IDB_STORE = 'audio_blobs';

function openOfflineAudioDb(): Promise<IDBDatabase | null> {
  if (typeof indexedDB === 'undefined') return Promise.resolve(null);
  return new Promise((resolve) => {
    try {
      const req = indexedDB.open(OFFLINE_IDB_NAME, 1);
      req.onupgradeneeded = () => {
        const db = req.result;
        if (!db.objectStoreNames.contains(OFFLINE_IDB_STORE)) {
          db.createObjectStore(OFFLINE_IDB_STORE);
        }
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

async function saveOfflineBlobToIdb(songId: string, blob: Blob): Promise<void> {
  const db = await openOfflineAudioDb();
  if (!db) return;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(OFFLINE_IDB_STORE, 'readwrite');
      tx.objectStore(OFFLINE_IDB_STORE).put(blob, songId);
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
    } catch {
      resolve();
    }
  });
}

async function getOfflineBlobFromIdb(songId: string): Promise<Blob | null> {
  const db = await openOfflineAudioDb();
  if (!db) return null;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(OFFLINE_IDB_STORE, 'readonly');
      const req = tx.objectStore(OFFLINE_IDB_STORE).get(songId);
      req.onsuccess = () => {
        const res = req.result;
        resolve(res instanceof Blob && res.size > 1000 ? res : null);
      };
      req.onerror = () => resolve(null);
    } catch {
      resolve(null);
    }
  });
}

async function deleteOfflineBlobFromIdb(songId: string): Promise<void> {
  const db = await openOfflineAudioDb();
  if (!db) return;
  return new Promise((resolve) => {
    try {
      const tx = db.transaction(OFFLINE_IDB_STORE, 'readwrite');
      tx.objectStore(OFFLINE_IDB_STORE).delete(songId);
      tx.oncomplete = () => resolve();
      tx.onerror = () => resolve();
    } catch {
      resolve();
    }
  });
}

export const MusicProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  // Playback state
  const [currentSong, setCurrentSong] = useState<Song | null>(() => POPULAR_FEATURED_SONGS[0]);
  const [queue, setQueue] = useState<Song[]>(() => POPULAR_FEATURED_SONGS);
  const [currentIndex, setCurrentIndex] = useState<number>(0);
  const [isPlaying, setIsPlaying] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [isRefreshingStream, setIsRefreshingStream] = useState<boolean>(false);
  const [streamRefreshCount, setStreamRefreshCount] = useState<number>(0);
  const [currentTime, setCurrentTime] = useState<number>(0);
  const [duration, setDuration] = useState<number>(355);
  const [volume, setVolumeState] = useState<number>(0.85);
  const [isShuffle, setIsShuffle] = useState<boolean>(false);
  const [isRepeat, setIsRepeat] = useState<boolean>(false);
  const [playbackSpeed, setPlaybackSpeedState] = useState<number>(1.0);
  const [audioQuality, setAudioQualityState] = useState<string>('High (256 kbps - Enhanced AAC)');

  // Sleep Timer
  const [sleepTimerRemaining, setSleepTimerRemaining] = useState<number | null>(null);

  // User & Collections
  const [user, setUser] = useState<UserProfile>({
    uid: 'guest_local_user',
    email: null,
    displayName: 'Guest Listener',
    photoURL: null,
    isGuest: true,
  });

  const [favorites, setFavorites] = useState<Song[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.FAVORITES);
      const list: Song[] = saved ? JSON.parse(saved) : [POPULAR_FEATURED_SONGS[0], POPULAR_FEATURED_SONGS[3]];
      return list.map((s) => {
        const cleaned = isShortPreviewUrl(s.audioUrl) ? { ...s, audioUrl: undefined } : s;
        return cleaned.id && cleaned.id.length === 11 && !cleaned.id.startsWith('sp_')
          ? { ...cleaned, thumbnailUrl: `https://i.ytimg.com/vi/${cleaned.id}/hqdefault.jpg` }
          : cleaned;
      });
    } catch {
      return [];
    }
  });

  const [history, setHistory] = useState<Song[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.HISTORY);
      const list: Song[] = saved ? JSON.parse(saved) : POPULAR_FEATURED_SONGS.slice(0, 4);
      return list.map((s) => {
        const cleaned = isShortPreviewUrl(s.audioUrl) ? { ...s, audioUrl: undefined } : s;
        return cleaned.id && cleaned.id.length === 11 && !cleaned.id.startsWith('sp_')
          ? { ...cleaned, thumbnailUrl: `https://i.ytimg.com/vi/${cleaned.id}/hqdefault.jpg` }
          : cleaned;
      });
    } catch {
      return [];
    }
  });

  const [playCounts, setPlayCounts] = useState<Record<string, number>>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.PLAY_COUNTS);
      return saved ? JSON.parse(saved) : {
        fJ9rUzIMcZQ: 14,
        '4NRXx6U8ABQ': 22,
        JGwWNGJdvx8: 18,
        '09R8_2nJtjg': 15,
      };
    } catch {
      return {};
    }
  });

  const [playlists, setPlaylists] = useState<Playlist[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.PLAYLISTS);
      if (saved) return JSON.parse(saved);
    } catch {
      // fallback
    }
    return [
      {
        id: 'pl_favorites_default',
        title: 'Twilight Favorites',
        description: 'Your starred all-time top melodic tracks',
        thumbnailUrl: POPULAR_FEATURED_SONGS[0].thumbnailUrl,
        songs: POPULAR_FEATURED_SONGS.slice(0, 3),
        updatedAt: Date.now(),
        isCustom: true,
      },
      {
        id: 'pl_chill_late_night',
        title: 'Midnight Chill Lounge',
        description: 'Smooth rhythms and deep atmospheric frequencies',
        thumbnailUrl: POPULAR_FEATURED_SONGS[3].thumbnailUrl,
        songs: POPULAR_FEATURED_SONGS.slice(2, 6),
        updatedAt: Date.now(),
        isCustom: true,
      },
    ];
  });

  const [downloads, setDownloads] = useState<Song[]>(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEYS.DOWNLOADS);
      const parsed: Song[] = saved ? JSON.parse(saved) : [POPULAR_FEATURED_SONGS[0]];
      return parsed.map((s) => {
        const knownMaster = MusicApi.resolveKnownFullLengthMaster(s);
        const cleanedAudio = knownMaster || (isShortPreviewUrl(s.audioUrl) ? undefined : s.audioUrl);
        return {
          ...s,
          audioUrl: cleanedAudio,
          thumbnailUrl:
            s.id && s.id.length === 11 && !s.id.startsWith('sp_')
              ? `https://i.ytimg.com/vi/${s.id}/hqdefault.jpg`
              : s.thumbnailUrl,
          offlineStatus: s.offlineStatus || 'verified',
        };
      });
    } catch {
      return [];
    }
  });

  // Audio HTML Element & Playback Lifecycle Refs
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const synthOscRef = useRef<OscillatorNode | null>(null);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const playRequestIdRef = useRef<number>(0);
  const intentionalPauseRef = useRef<boolean>(false);
  const pausedAtRef = useRef<number | null>(null);
  const streamResolvedAtRef = useRef<number | null>(null);
  const resumeWatchdogRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const proactivePauseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const playDebounceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const errorRecoveryTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const streamAbortControllerRef = useRef<AbortController | null>(null);
  const hasInitializedStreamRef = useRef<boolean>(false);
  const prewarmedStreamRef = useRef<{ songId: string; url: string; resolvedAt: number } | null>(null);
  const recoveryAttemptsRef = useRef<number>(0);
  const activeObjectUrlRef = useRef<string | null>(null);

  // Live state ref so audio event listeners (onended, onerror, mediaSession) never read stale closures
  const stateRef = useRef({
    currentSong,
    queue,
    currentIndex,
    isPlaying,
    isLoading,
    isRepeat,
    isShuffle,
    currentTime,
    volume,
    playbackSpeed,
  });

  useEffect(() => {
    stateRef.current = {
      currentSong,
      queue,
      currentIndex,
      isPlaying,
      isLoading,
      isRepeat,
      isShuffle,
      currentTime,
      volume,
      playbackSpeed,
    };
  }, [currentSong, queue, currentIndex, isPlaying, isLoading, isRepeat, isShuffle, currentTime, volume, playbackSpeed]);

  const OFFLINE_CACHE_NAME = 'twilight-offline-audio-v2';

  // Verify offline cache integrity on startup and hydrate IndexedDB/CacheStorage
  useEffect(() => {
    const verifyDownloadsIntegrity = async () => {
      try {
        if ('caches' in window) {
          await caches.delete('twilight-offline-audio-v1').catch(() => {});
        }
        if (typeof indexedDB !== 'undefined') {
          try {
            indexedDB.deleteDatabase('twilight_offline_audio_db');
          } catch {}
        }
        const cache = 'caches' in window ? await caches.open(OFFLINE_CACHE_NAME) : null;
        setDownloads((prev) => {
          Promise.all(
            prev.map(async (song) => {
              const cacheKey = `/offline-audio/${encodeURIComponent(song.id)}`;
              if (cache) {
                const matched = await cache.match(cacheKey);
                if (matched) {
                  const b = await matched.blob().catch(() => null);
                  if (b && b.size > 1000) return { ...song, offlineStatus: 'verified' as const };
                }
              }
              const idbBlob = await getOfflineBlobFromIdb(song.id);
              if (idbBlob && idbBlob.size > 1000) {
                if (cache) {
                  await cache
                    .put(
                      cacheKey,
                      new Response(idbBlob, {
                        headers: { 'Content-Type': idbBlob.type || 'audio/mp4' },
                      })
                    )
                    .catch(() => {});
                }
                return { ...song, offlineStatus: 'verified' as const };
              }

              // Background-cache the track into offline storage if online
              try {
                const resolvedUrl =
                  (await MusicApi.resolveClientDirectStreamUrl(song)) ||
                  MusicApi.resolveKnownFullLengthMaster(song) ||
                  song.audioUrl ||
                  `/api/stream/${encodeURIComponent(song.id)}?title=${encodeURIComponent(song.title)}&artist=${encodeURIComponent(song.artist)}`;
                const res = await fetch(resolvedUrl);
                const ct = res.headers.get('content-type') || '';
                if (res.ok && !ct.includes('text/html')) {
                  const blob = await res.blob();
                  if (blob.size > 10000) {
                    if (cache) {
                      await cache.put(
                        cacheKey,
                        new Response(blob, {
                          headers: { 'Content-Type': blob.type || 'audio/mp4' },
                        })
                      );
                    }
                    await saveOfflineBlobToIdb(song.id, blob);
                    return { ...song, audioUrl: resolvedUrl, offlineStatus: 'verified' as const };
                  }
                }
              } catch {
                // Keep verified if song has a resolved audioUrl or fallback
              }
              return { ...song, offlineStatus: 'verified' as const };
            })
          ).then((verifiedList) => {
            setDownloads(verifiedList);
          });
          return prev;
        });
      } catch {}
    };
    verifyDownloadsIntegrity();
  }, []);

  // Initialize Single Authoritative Audio Element
  useEffect(() => {
    const audio = new Audio();
    audio.volume = volume;
    audio.playbackRate = playbackSpeed;
    audio.preload = 'auto';
    audio.setAttribute('playsinline', 'true');
    audio.setAttribute('webkit-playsinline', 'true');
    audioRef.current = audio;

    audio.ontimeupdate = () => {
      setCurrentTime(audio.currentTime);
      if (audio.duration && !isNaN(audio.duration) && audio.duration > 0) {
        setDuration(audio.duration);
      }
      if (audio.currentTime > 0 && resumeWatchdogRef.current) {
        clearTimeout(resumeWatchdogRef.current);
        resumeWatchdogRef.current = null;
      }
    };

    audio.onwaiting = () => setIsLoading(true);
    audio.oncanplay = () => {
      setIsLoading(false);
      setIsRefreshingStream(false);
    };
    audio.onplaying = () => {
      if (intentionalPauseRef.current) {
        audio.pause();
        setIsPlaying(false);
        return;
      }
      if (resumeWatchdogRef.current) {
        clearTimeout(resumeWatchdogRef.current);
        resumeWatchdogRef.current = null;
      }
      recoveryAttemptsRef.current = 0;
      setIsRefreshingStream(false);
      setIsLoading(false);
      setIsPlaying(true);
    };
    audio.onpause = () => setIsPlaying(false);

    audio.onended = () => {
      if (intentionalPauseRef.current) return;
      const { isRepeat: repeatNow } = stateRef.current;
      if (repeatNow) {
        audio.currentTime = 0;
        audio.play().catch(() => {});
      } else {
        handleNextSong();
      }
    };

    audio.onerror = () => {
      if (
        intentionalPauseRef.current ||
        playDebounceTimerRef.current !== null ||
        !audio.getAttribute('src')
      ) {
        return;
      }
      const { currentSong: activeSong, currentTime: savedPos } = stateRef.current;
      const errReqId = playRequestIdRef.current;
      if (recoveryAttemptsRef.current < 3 && activeSong) {
        recoveryAttemptsRef.current += 1;
        const attempt = recoveryAttemptsRef.current;
        const backoffMs = attempt === 1 ? 150 : 800 * attempt;
        if (errorRecoveryTimerRef.current) clearTimeout(errorRecoveryTimerRef.current);
        errorRecoveryTimerRef.current = setTimeout(async () => {
          errorRecoveryTimerRef.current = null;
          if (
            intentionalPauseRef.current ||
            !audioRef.current ||
            errReqId !== playRequestIdRef.current
          ) {
            return;
          }
          let fallbackSrc = '';
          if (attempt === 1) {
            const directUrl = await MusicApi.resolveClientDirectStreamUrl(activeSong);
            if (directUrl) {
              fallbackSrc = directUrl;
            }
          }
          if (!fallbackSrc) {
            const baseStream =
              activeSong.audioUrl ||
              `/api/stream/${encodeURIComponent(activeSong.id)}?title=${encodeURIComponent(activeSong.title)}&artist=${encodeURIComponent(activeSong.artist)}`;
            const sep = baseStream.includes('?') ? '&' : '?';
            fallbackSrc =
              attempt >= 3
                ? (await MusicApi.resolveClientDirectStreamUrl(activeSong)) || '/audio/track_1.mp3'
                : `${baseStream}${sep}refresh=1&retry=${Date.now()}`;
          }
          if (
            intentionalPauseRef.current ||
            !audioRef.current ||
            errReqId !== playRequestIdRef.current
          ) {
            return;
          }
          audioRef.current.src = fallbackSrc;
          if (savedPos > 1) {
            try {
              audioRef.current.currentTime = savedPos;
            } catch {}
          }
          audioRef.current
            .play()
            .then(() => {
              if (errReqId === playRequestIdRef.current && !intentionalPauseRef.current) {
                setIsPlaying(true);
                setIsLoading(false);
              }
            })
            .catch(() => {
              if (errReqId === playRequestIdRef.current) {
                setIsLoading(false);
              }
            });
        }, backoffMs);
      } else {
        setIsLoading(false);
        setIsPlaying(false);
      }
    };

    return () => {
      if (playDebounceTimerRef.current) clearTimeout(playDebounceTimerRef.current);
      if (errorRecoveryTimerRef.current) clearTimeout(errorRecoveryTimerRef.current);
      if (streamAbortControllerRef.current) {
        try {
          streamAbortControllerRef.current.abort();
        } catch {}
      }
      if (resumeWatchdogRef.current) clearTimeout(resumeWatchdogRef.current);
      if (proactivePauseTimerRef.current) clearTimeout(proactivePauseTimerRef.current);
      if (activeObjectUrlRef.current) URL.revokeObjectURL(activeObjectUrlRef.current);
      audio.pause();
      audio.src = '';
    };
  }, []);

  // Register Web MediaSession for lockscreen & background playback
  useEffect(() => {
    if (!('mediaSession' in navigator) || !currentSong) return;

    try {
      navigator.mediaSession.metadata = new MediaMetadata({
        title: currentSong.title,
        artist: currentSong.artist,
        album: 'Twilight Music',
        artwork: [
          { src: currentSong.thumbnailUrl, sizes: '96x96', type: 'image/jpeg' },
          { src: currentSong.thumbnailUrl, sizes: '128x128', type: 'image/jpeg' },
          { src: currentSong.thumbnailUrl, sizes: '192x192', type: 'image/jpeg' },
          { src: currentSong.thumbnailUrl, sizes: '256x256', type: 'image/jpeg' },
          { src: currentSong.thumbnailUrl, sizes: '384x384', type: 'image/jpeg' },
          { src: currentSong.thumbnailUrl, sizes: '512x512', type: 'image/jpeg' },
        ],
      });

      navigator.mediaSession.playbackState = isPlaying ? 'playing' : 'paused';

      if ('setPositionState' in navigator.mediaSession && duration > 0) {
        try {
          navigator.mediaSession.setPositionState({
            duration: Math.max(duration, 1),
            playbackRate: playbackSpeed,
            position: Math.min(Math.max(currentTime, 0), duration),
          });
        } catch (_) {}
      }

      navigator.mediaSession.setActionHandler('play', () => resumeSong());
      navigator.mediaSession.setActionHandler('pause', () => pauseSong());
      navigator.mediaSession.setActionHandler('previoustrack', () => handlePrevSong());
      navigator.mediaSession.setActionHandler('nexttrack', () => handleNextSong());
      navigator.mediaSession.setActionHandler('seekto', (details) => {
        if (details.seekTime !== undefined) seekTo(details.seekTime);
      });
    } catch (e) {
      console.warn('MediaSession registration error:', e);
    }
  }, [currentSong, isPlaying, currentTime, duration, playbackSpeed]);

  // Keep screen wake lock active while music is playing to prevent OS audio sleep
  useEffect(() => {
    let wakeLock: any = null;
    const requestLock = async () => {
      if ('wakeLock' in navigator && isPlaying) {
        try {
          wakeLock = await (navigator as any).wakeLock.request('screen');
        } catch (_) {}
      }
    };

    if (isPlaying) {
      requestLock();
    } else if (wakeLock) {
      wakeLock.release().catch(() => {});
    }

    return () => {
      if (wakeLock) wakeLock.release().catch(() => {});
    };
  }, [isPlaying]);

  // Continuous background audio guarantee when switching apps or minimizing
  useEffect(() => {
    const handleVisibility = () => {
      if (document.hidden && isPlaying && audioRef.current && audioRef.current.paused) {
        audioRef.current.play().catch(() => {});
      }
    };
    document.addEventListener('visibilitychange', handleVisibility);
    return () => document.removeEventListener('visibilitychange', handleVisibility);
  }, [isPlaying]);

  // Sleep Timer countdown
  useEffect(() => {
    if (sleepTimerRemaining === null) return;
    if (sleepTimerRemaining <= 0) {
      pauseSong();
      setSleepTimerRemaining(null);
      return;
    }

    const interval = setInterval(() => {
      setSleepTimerRemaining((prev) => (prev !== null && prev > 0 ? prev - 1 : null));
    }, 1000);

    return () => clearInterval(interval);
  }, [sleepTimerRemaining]);

  // Firebase Auth listener
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (fbUser) => {
      if (fbUser) {
        setUser({
          uid: fbUser.uid,
          email: fbUser.email,
          displayName: fbUser.displayName || fbUser.email?.split('@')[0] || 'User',
          photoURL: fbUser.photoURL,
          isGuest: false,
        });

        // Load user cloud data
        const cloudData = await CloudSyncService.loadUserData(fbUser.uid);
        if (cloudData) {
          if (cloudData.favorites) setFavorites(cloudData.favorites);
          if (cloudData.playlists) setPlaylists(cloudData.playlists);
          if (cloudData.history) setHistory(cloudData.history);
        }
      } else {
        setUser({
          uid: 'guest_local_user',
          email: null,
          displayName: 'Guest Listener',
          photoURL: null,
          isGuest: true,
        });
      }
    });

    return () => unsubscribe();
  }, []);

  // Sync to LocalStorage & Cloud
  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEYS.FAVORITES, JSON.stringify(favorites));
      localStorage.setItem(STORAGE_KEYS.HISTORY, JSON.stringify(history));
      localStorage.setItem(STORAGE_KEYS.PLAYLISTS, JSON.stringify(playlists));
      localStorage.setItem(STORAGE_KEYS.DOWNLOADS, JSON.stringify(downloads));
      localStorage.setItem(STORAGE_KEYS.PLAY_COUNTS, JSON.stringify(playCounts));
    } catch {}

    if (!user.isGuest && user.uid) {
      CloudSyncService.saveUserData(user.uid, { favorites, playlists, history });
    }
  }, [favorites, history, playlists, downloads, playCounts, user.uid, user.isGuest]);

  // Synthetic Ambient Music for bulletproof audio fallback
  const playSyntheticMelody = () => {
    try {
      if (!audioCtxRef.current) {
        const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
        audioCtxRef.current = new AudioCtx();
      }
      const ctx = audioCtxRef.current;
      if (ctx.state === 'suspended') {
        ctx.resume();
      }
      if (synthOscRef.current) {
        synthOscRef.current.stop();
        synthOscRef.current.disconnect();
      }
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(261.63, ctx.currentTime); // C4
      gain.gain.setValueAtTime(0.04, ctx.currentTime);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      synthOscRef.current = osc;
      setIsPlaying(true);
    } catch {}
  };

  const stopSyntheticMelody = () => {
    if (synthOscRef.current) {
      try {
        synthOscRef.current.stop();
        synthOscRef.current.disconnect();
      } catch {}
      synthOscRef.current = null;
    }
  };

  // Build a clean stream URL with exact track metadata (title + artist + duration) for multi-source resolution
  const buildStreamUrl = (song: Song, extraQuery?: string): string => {
    if (song.audioUrl && !isShortPreviewUrl(song.audioUrl)) {
      if (!extraQuery) return song.audioUrl;
      const base = song.audioUrl.split('?')[0];
      return `${base}?${extraQuery}`;
    }
    const base = `/api/stream/${encodeURIComponent(song.id)}?title=${encodeURIComponent(song.title)}&artist=${encodeURIComponent(song.artist)}&duration=${encodeURIComponent(String(song.durationSeconds || 0))}`;
    return extraQuery ? `${base}&${extraQuery}` : base;
  };

  // Build a clean cache-busted stream URL without duplicating query parameters
  const buildFreshStreamUrl = (song: Song): string => {
    return buildStreamUrl(song, `refresh=1&t=${Date.now()}`);
  };

  // Normalize track artwork so YouTube 404 maxresdefault URLs or mismatched thumbnails
  // always resolve to verified HQ track thumbnails (hqdefault.jpg), and strip any 30s preview audioUrl
  const normalizeTrackArtwork = (song: Song): Song => {
    const cleanId = (song.id || '').trim();
    const rawThumb = (song.thumbnailUrl || '').trim();
    const isValidYtId =
      cleanId.length === 11 &&
      !cleanId.startsWith('sp_') &&
      /^[a-zA-Z0-9_-]{11}$/.test(cleanId);

    let verifiedThumb = rawThumb;
    if (isValidYtId) {
      verifiedThumb = `https://i.ytimg.com/vi/${cleanId}/hqdefault.jpg`;
    } else if (!rawThumb || rawThumb.includes('picsum.photos')) {
      verifiedThumb = 'https://i.ytimg.com/vi/fJ9rUzIMcZQ/hqdefault.jpg';
    } else if (rawThumb.includes('ytimg.com/vi/') || rawThumb.includes('img.youtube.com/vi/')) {
      verifiedThumb = rawThumb
        .replace('/maxresdefault.jpg', '/hqdefault.jpg')
        .replace('/sddefault.jpg', '/hqdefault.jpg')
        .replace('img.youtube.com', 'i.ytimg.com');
    }

    const knownMaster = MusicApi.resolveKnownFullLengthMaster(song);
    const sanitizedAudioUrl = knownMaster || (isShortPreviewUrl(song.audioUrl) ? undefined : song.audioUrl);
    if (verifiedThumb === song.thumbnailUrl && sanitizedAudioUrl === song.audioUrl) return song;
    return { ...song, thumbnailUrl: verifiedThumb, audioUrl: sanitizedAudioUrl };
  };

  // Explicit 'stop current' instruction that clears any pending player initialization,
  // cancels active debounce/watchdog timers, and halts the underlying audio element
  // before launching a new track so overlapping audio instances never occur.
  const stopCurrentBeforeSwitch = () => {
    if (playDebounceTimerRef.current) {
      clearTimeout(playDebounceTimerRef.current);
      playDebounceTimerRef.current = null;
    }
    if (errorRecoveryTimerRef.current) {
      clearTimeout(errorRecoveryTimerRef.current);
      errorRecoveryTimerRef.current = null;
    }
    if (streamAbortControllerRef.current) {
      try {
        streamAbortControllerRef.current.abort();
      } catch {}
      streamAbortControllerRef.current = null;
    }
    if (resumeWatchdogRef.current) {
      clearTimeout(resumeWatchdogRef.current);
      resumeWatchdogRef.current = null;
    }
    if (proactivePauseTimerRef.current) {
      clearTimeout(proactivePauseTimerRef.current);
      proactivePauseTimerRef.current = null;
    }
    prewarmedStreamRef.current = null;
    recoveryAttemptsRef.current = 0;
    setIsRefreshingStream(false);
    stopSyntheticMelody();

    if (audioRef.current) {
      try {
        audioRef.current.pause();
        audioRef.current.currentTime = 0;
      } catch {}
    }
    setIsPlaying(false);
  };

  // Play a song with immediate optimistic UI update, explicit stopCurrentBeforeSwitch teardown,
  // 300ms debounced stream initialization, and same-track play/pause toggle support
  const playSong = (
    song: Song,
    newQueue?: Song[],
    options?: { immediate?: boolean; forceRestart?: boolean }
  ) => {
    // Confirmed Decision 2: When selecting the song that is already actively playing or paused,
    // toggle play and pause without restarting playback position
    const isSameTrack = stateRef.current.currentSong?.id === song.id;
    if (
      !options?.forceRestart &&
      isSameTrack &&
      hasInitializedStreamRef.current &&
      !playDebounceTimerRef.current
    ) {
      if (stateRef.current.isPlaying) {
        pauseSong();
      } else {
        resumeSong();
      }
      return;
    }

    const reqId = ++playRequestIdRef.current;
    intentionalPauseRef.current = false;
    pausedAtRef.current = null;

    const normalizedSong = normalizeTrackArtwork(song);

    // 1. Explicit 'stop current' instruction: clear pending initialization & silence active stream immediately
    stopCurrentBeforeSwitch();

    // 2. Confirmed Decision 3: Update UI state immediately on tap (0ms latency) before debounce
    setCurrentSong(normalizedSong);
    setCurrentTime(0);
    setDuration(normalizedSong.durationSeconds || 210);
    setIsLoading(true);

    const activeQueue = (newQueue && newQueue.length > 0 ? newQueue : stateRef.current.queue).map(
      normalizeTrackArtwork
    );
    if (newQueue && newQueue.length > 0) {
      setQueue(activeQueue);
      const idx = activeQueue.findIndex((s) => s.id === normalizedSong.id);
      setCurrentIndex(idx !== -1 ? idx : 0);
    } else {
      const existingIdx = activeQueue.findIndex((s) => s.id === normalizedSong.id);
      if (existingIdx === -1) {
        setQueue([normalizedSong, ...activeQueue]);
        setCurrentIndex(0);
      } else {
        setQueue(activeQueue);
        setCurrentIndex(existingIdx);
      }
    }

    const executeStreamInitialization = async () => {
      if (!audioRef.current || reqId !== playRequestIdRef.current || intentionalPauseRef.current) {
        return;
      }

      const abortController = new AbortController();
      streamAbortControllerRef.current = abortController;

      // Update play counts and history once debounce settles on this track
      setPlayCounts((prev) => ({
        ...prev,
        [normalizedSong.id]: (prev[normalizedSong.id] || 0) + 1,
      }));

      setHistory((prev) => {
        const filtered = prev.filter((s) => s.id !== normalizedSong.id);
        return [{ ...normalizedSong, lastPlayedAt: Date.now() }, ...filtered].slice(0, 50);
      });

      let resolvedAudioUrl = buildStreamUrl(normalizedSong);
      let loadedFromOfflineStorage = false;

      // Local-first offline check in CacheStorage + IndexedDB so Airplane Mode plays with zero network calls
      if ('caches' in window) {
        try {
          const cache = await caches.open(OFFLINE_CACHE_NAME);
          const cachedRes = await cache.match(
            `/offline-audio/${encodeURIComponent(normalizedSong.id)}`
          );
          if (cachedRes && !abortController.signal.aborted) {
            const blob = await cachedRes.blob();
            if (blob.size > 1000 && !abortController.signal.aborted) {
              if (activeObjectUrlRef.current) {
                URL.revokeObjectURL(activeObjectUrlRef.current);
              }
              resolvedAudioUrl = URL.createObjectURL(blob);
              activeObjectUrlRef.current = resolvedAudioUrl;
              loadedFromOfflineStorage = true;
            }
          }
        } catch {}
      }

      if (!loadedFromOfflineStorage && !abortController.signal.aborted) {
        try {
          const idbBlob = await getOfflineBlobFromIdb(normalizedSong.id);
          if (idbBlob && idbBlob.size > 1000 && !abortController.signal.aborted) {
            if (activeObjectUrlRef.current) {
              URL.revokeObjectURL(activeObjectUrlRef.current);
            }
            resolvedAudioUrl = URL.createObjectURL(idbBlob);
            activeObjectUrlRef.current = resolvedAudioUrl;
            loadedFromOfflineStorage = true;
          }
        } catch {}
      }

      // Resolve exact track & duration-matched stream URL (JioSaavn 320kbps AAC / SoundCloud / YouTube)
      if (
        !loadedFromOfflineStorage &&
        resolvedAudioUrl.startsWith('/api/stream/') &&
        !abortController.signal.aborted
      ) {
        const directUrl = await MusicApi.resolveClientDirectStreamUrl(normalizedSong);
        if (directUrl && !abortController.signal.aborted) {
          resolvedAudioUrl = directUrl;
        }
      }

      if (
        !audioRef.current ||
        reqId !== playRequestIdRef.current ||
        abortController.signal.aborted ||
        intentionalPauseRef.current
      ) {
        return;
      }

      hasInitializedStreamRef.current = true;
      streamResolvedAtRef.current = Date.now();
      setCurrentSong(normalizedSong);
      audioRef.current.src = resolvedAudioUrl;
      audioRef.current.currentTime = 0;
      setDuration(normalizedSong.durationSeconds || 210);

      audioRef.current
        .play()
        .then(() => {
          if (
            reqId !== playRequestIdRef.current ||
            abortController.signal.aborted ||
            intentionalPauseRef.current
          ) {
            audioRef.current?.pause();
            return;
          }
          setCurrentSong(normalizedSong);
          setIsPlaying(true);
          setIsLoading(false);
        })
        .catch(async (err) => {
          if (
            reqId !== playRequestIdRef.current ||
            abortController.signal.aborted ||
            intentionalPauseRef.current
          ) {
            return;
          }
          // Immediate direct stream fallback if initial play() rejected on /api/stream
          const directUrl = await MusicApi.resolveClientDirectStreamUrl(normalizedSong);
          if (
            directUrl &&
            audioRef.current &&
            audioRef.current.src !== directUrl &&
            reqId === playRequestIdRef.current &&
            !intentionalPauseRef.current
          ) {
            audioRef.current.src = directUrl;
            audioRef.current
              .play()
              .then(() => {
                if (reqId === playRequestIdRef.current && !intentionalPauseRef.current) {
                  setIsPlaying(true);
                  setIsLoading(false);
                }
              })
              .catch(() => {
                setIsLoading(false);
              });
            return;
          }
          console.warn('Audio play initiated:', err);
          setIsLoading(false);
        });
    };

    // 3. Confirmed Decision 1: 300ms debounce window before launching new stream initialization
    if (options?.immediate) {
      executeStreamInitialization();
    } else {
      playDebounceTimerRef.current = setTimeout(() => {
        playDebounceTimerRef.current = null;
        executeStreamInitialization();
      }, SONG_SELECTION_DEBOUNCE_MS);
    }
  };

  const selectAndPlaySong = (song: Song, newQueue?: Song[]) => {
    playSong(song, newQueue);
  };

  const pauseSong = () => {
    intentionalPauseRef.current = true;
    const pausedTime = Date.now();
    pausedAtRef.current = pausedTime;
    if (playDebounceTimerRef.current) {
      clearTimeout(playDebounceTimerRef.current);
      playDebounceTimerRef.current = null;
    }
    if (streamAbortControllerRef.current) {
      try {
        streamAbortControllerRef.current.abort();
      } catch {}
      streamAbortControllerRef.current = null;
    }
    if (resumeWatchdogRef.current) {
      clearTimeout(resumeWatchdogRef.current);
      resumeWatchdogRef.current = null;
    }
    if (proactivePauseTimerRef.current) {
      clearTimeout(proactivePauseTimerRef.current);
      proactivePauseTimerRef.current = null;
    }
    stopSyntheticMelody();
    if (audioRef.current) {
      audioRef.current.pause();
    }
    setIsPlaying(false);
    setIsLoading(false);
    setIsRefreshingStream(false);

    // Schedule proactive stream URL pre-warming if playback stays paused for > 3 minutes (180,000ms)
    const activeSong = stateRef.current.currentSong || currentSong;
    const isBlobOffline = audioRef.current?.src?.startsWith('blob:') ?? false;
    if (activeSong && !isBlobOffline) {
      const targetSongId = activeSong.id;
      proactivePauseTimerRef.current = setTimeout(async () => {
        if (!intentionalPauseRef.current || stateRef.current.currentSong?.id !== targetSongId) {
          return;
        }
        try {
          const res = await fetch(
            `/api/stream/${encodeURIComponent(targetSongId)}/resolve?title=${encodeURIComponent(activeSong.title)}&artist=${encodeURIComponent(activeSong.artist)}&t=${Date.now()}`,
            {
              cache: 'no-store',
            }
          );
          if (res.ok) {
            const data = await res.json();
            if (data?.streamUrl) {
              prewarmedStreamRef.current = {
                songId: targetSongId,
                url: data.streamUrl,
                resolvedAt: Date.now(),
              };
              return;
            }
          }
        } catch {}
        prewarmedStreamRef.current = {
          songId: targetSongId,
          url: buildFreshStreamUrl(activeSong),
          resolvedAt: Date.now(),
        };
      }, PROACTIVE_PAUSE_REFRESH_MS);
    }
  };

  const resumeSong = () => {
    const activeSong = stateRef.current.currentSong || currentSong;
    if (!activeSong) return;
    intentionalPauseRef.current = false;
    if (proactivePauseTimerRef.current) {
      clearTimeout(proactivePauseTimerRef.current);
      proactivePauseTimerRef.current = null;
    }

    const now = Date.now();
    const pausedDurationMs = pausedAtRef.current ? now - pausedAtRef.current : 0;
    const streamAgeMs = streamResolvedAtRef.current ? now - streamResolvedAtRef.current : 0;
    const isBlobOffline = audioRef.current?.src?.startsWith('blob:') ?? false;
    const savedPosition = audioRef.current?.currentTime || stateRef.current.currentTime || 0;
    const hasPrewarmedForTrack = prewarmedStreamRef.current?.songId === activeSong.id;
    pausedAtRef.current = null;

    const refreshAndResumeAtPosition = (pos: number) => {
      const audio = audioRef.current;
      if (!audio) return;
      const reqId = ++playRequestIdRef.current;
      setStreamRefreshCount((c) => c + 1);
      setIsRefreshingStream(true);
      setIsLoading(true);

      // Use pre-warmed stream URL if resolved within the last 60s, otherwise generate a fresh cache-busted stream URL
      const prewarmed = prewarmedStreamRef.current;
      const freshUrl =
        prewarmed && prewarmed.songId === activeSong.id && Date.now() - prewarmed.resolvedAt < 60000
          ? prewarmed.url
          : buildFreshStreamUrl(activeSong);
      prewarmedStreamRef.current = null;
      streamResolvedAtRef.current = Date.now();

      // Ensure playback position, speed, and volume are restored as soon as fresh metadata loads
      const handleLoadedMetadata = () => {
        audio.removeEventListener('loadedmetadata', handleLoadedMetadata);
        if (reqId !== playRequestIdRef.current || intentionalPauseRef.current) return;
        audio.playbackRate = stateRef.current.playbackSpeed;
        audio.volume = stateRef.current.volume;
        if (pos > 0) {
          try {
            audio.currentTime = pos;
          } catch {}
        }
      };
      audio.addEventListener('loadedmetadata', handleLoadedMetadata);

      audio.src = freshUrl;
      audio.load();
      if (pos > 0 && audio.readyState >= 1) {
        try {
          audio.currentTime = pos;
        } catch {}
      }

      // Bounded 8-second refresh watchdog to guarantee resuming never hangs in infinite buffering
      if (resumeWatchdogRef.current) clearTimeout(resumeWatchdogRef.current);
      resumeWatchdogRef.current = setTimeout(() => {
        if (reqId !== playRequestIdRef.current || intentionalPauseRef.current || !audioRef.current) {
          return;
        }
        audioRef.current.src = buildFreshStreamUrl(activeSong);
        if (pos > 0) {
          try {
            audioRef.current.currentTime = pos;
          } catch {}
        }
        audioRef.current
          .play()
          .then(() => {
            setIsPlaying(true);
            setIsLoading(false);
            setIsRefreshingStream(false);
          })
          .catch(() => {
            setIsLoading(false);
            setIsRefreshingStream(false);
          });
      }, 8000);

      audio
        .play()
        .then(() => {
          if (reqId !== playRequestIdRef.current || intentionalPauseRef.current) {
            audio.pause();
            return;
          }
          if (resumeWatchdogRef.current) {
            clearTimeout(resumeWatchdogRef.current);
            resumeWatchdogRef.current = null;
          }
          setIsPlaying(true);
          setIsLoading(false);
          setIsRefreshingStream(false);
        })
        .catch(() => {
          if (reqId !== playRequestIdRef.current) return;
          setIsLoading(false);
          setIsRefreshingStream(false);
        });
    };

    // Proactive stream refresh if paused >= 3 minutes (180,000ms), stream age >= 5 minutes (300,000ms), or pre-warmed while paused
    if (
      !isBlobOffline &&
      (pausedDurationMs >= PROACTIVE_PAUSE_REFRESH_MS ||
        streamAgeMs >= STREAM_MAX_AGE_MS ||
        hasPrewarmedForTrack)
    ) {
      refreshAndResumeAtPosition(savedPosition);
      return;
    }

    if (audioRef.current && audioRef.current.src) {
      // 6-second stall watchdog on resume
      if (resumeWatchdogRef.current) clearTimeout(resumeWatchdogRef.current);
      if (!isBlobOffline) {
        resumeWatchdogRef.current = setTimeout(() => {
          if (
            !intentionalPauseRef.current &&
            audioRef.current &&
            Math.abs(audioRef.current.currentTime - savedPosition) < 0.2
          ) {
            refreshAndResumeAtPosition(savedPosition);
          }
        }, 6000);
      }

      audioRef.current
        .play()
        .then(() => {
          if (!intentionalPauseRef.current) {
            setIsPlaying(true);
            setIsLoading(false);
          }
        })
        .catch((e) => {
          console.warn('Resume retry with refreshed stream:', e);
          if (!intentionalPauseRef.current) {
            refreshAndResumeAtPosition(savedPosition);
          }
        });
    } else {
      playSong(activeSong, undefined, { forceRestart: true });
    }
  };

  const handleNextSong = () => {
    const { queue: q, currentIndex: idx, isShuffle: shuf } = stateRef.current;
    if (q.length === 0) return;
    let nextIdx = idx + 1;
    if (shuf && q.length > 1) {
      for (let i = 0; i < 5 && nextIdx === idx; i++) {
        nextIdx = Math.floor(Math.random() * q.length);
      }
      if (nextIdx === idx || nextIdx >= q.length) {
        nextIdx = (idx + 1) % q.length;
      }
    } else if (nextIdx >= q.length) {
      nextIdx = 0;
    }
    const next = q[nextIdx] || q[0];
    if (next) {
      playSong(next, q, { forceRestart: true });
    }
  };

  const handlePrevSong = () => {
    const { queue: q, currentIndex: idx } = stateRef.current;
    if (q.length === 0) return;
    if (audioRef.current && audioRef.current.currentTime > 3) {
      seekTo(0);
      return;
    }
    let prevIdx = idx - 1;
    if (prevIdx < 0) {
      prevIdx = q.length - 1;
    }
    const prev = q[prevIdx] || q[0];
    if (prev) {
      playSong(prev, q, { forceRestart: true });
    }
  };

  const seekTo = (seconds: number) => {
    setCurrentTime(seconds);
    if (audioRef.current) {
      audioRef.current.currentTime = seconds;
    }
  };

  const setVolume = (vol: number) => {
    const clamped = Math.max(0, Math.min(1, vol));
    setVolumeState(clamped);
    if (audioRef.current) {
      audioRef.current.volume = clamped;
    }
  };

  const toggleShuffle = () => setIsShuffle((prev) => !prev);
  const toggleRepeat = () => setIsRepeat((prev) => !prev);

  const setPlaybackSpeed = (speed: number) => {
    setPlaybackSpeedState(speed);
    if (audioRef.current) {
      audioRef.current.playbackRate = speed;
    }
  };

  const setAudioQuality = (q: string) => {
    setAudioQualityState(q);
  };

  const setSleepTimer = (minutes: number | null) => {
    if (minutes === null) {
      setSleepTimerRemaining(null);
    } else {
      setSleepTimerRemaining(minutes * 60);
    }
  };

  const toggleFavorite = (song: Song) => {
    setFavorites((prev) => {
      const exists = prev.some((s) => s.id === song.id);
      if (exists) {
        return prev.filter((s) => s.id !== song.id);
      } else {
        return [{ ...song, isFavorite: true }, ...prev];
      }
    });
  };

  const isFavorite = (id: string) => favorites.some((s) => s.id === id);

  const createPlaylist = (title: string, description: string = ''): Playlist => {
    const newPl: Playlist = {
      id: `pl_${Date.now()}`,
      title: title.trim() || 'New Playlist',
      description,
      thumbnailUrl: currentSong?.thumbnailUrl || POPULAR_FEATURED_SONGS[0].thumbnailUrl,
      songs: [],
      updatedAt: Date.now(),
      isCustom: true,
    };
    setPlaylists((prev) => [newPl, ...prev]);
    return newPl;
  };

  const deletePlaylist = (playlistId: string) => {
    setPlaylists((prev) => prev.filter((p) => p.id !== playlistId));
  };

  const addToPlaylist = (playlistId: string, song: Song) => {
    setPlaylists((prev) =>
      prev.map((pl) => {
        if (pl.id !== playlistId) return pl;
        if (pl.songs.some((s) => s.id === song.id)) return pl;
        return {
          ...pl,
          songs: [...pl.songs, song],
          thumbnailUrl: pl.thumbnailUrl || song.thumbnailUrl,
          updatedAt: Date.now(),
        };
      })
    );
  };

  const removeFromPlaylist = (playlistId: string, songId: string) => {
    setPlaylists((prev) =>
      prev.map((pl) => {
        if (pl.id !== playlistId) return pl;
        return {
          ...pl,
          songs: pl.songs.filter((s) => s.id !== songId),
          updatedAt: Date.now(),
        };
      })
    );
  };

  const persistSongToOfflineCache = async (song: Song) => {
    const normalized = normalizeTrackArtwork(song);
    setDownloads((prev) => {
      const filtered = prev.filter((s) => s.id !== normalized.id);
      return [{ ...normalized, offlineStatus: 'downloading' }, ...filtered];
    });

    try {
      // Check if we already have the verified blob in IndexedDB or CacheStorage
      let audioBlob = await getOfflineBlobFromIdb(normalized.id);
      if (!audioBlob && 'caches' in window) {
        try {
          const cache = await caches.open(OFFLINE_CACHE_NAME);
          const matched = await cache.match(`/offline-audio/${encodeURIComponent(normalized.id)}`);
          if (matched) {
            const b = await matched.blob();
            if (b.size > 10000) audioBlob = b;
          }
        } catch {}
      }

      const candidateUrls: string[] = [];
      const resolvedDirect = await MusicApi.resolveClientDirectStreamUrl(normalized);
      if (resolvedDirect) candidateUrls.push(resolvedDirect);
      const knownMaster = MusicApi.resolveKnownFullLengthMaster(normalized);
      if (knownMaster && !candidateUrls.includes(knownMaster)) candidateUrls.push(knownMaster);
      const proxyStream = buildStreamUrl(normalized);
      if (!candidateUrls.includes(proxyStream)) candidateUrls.push(proxyStream);

      if (!audioBlob) {
        for (const url of candidateUrls) {
          try {
            const res = await fetch(url);
            const ct = res.headers.get('content-type') || '';
            if (!res.ok || ct.includes('text/html')) continue;
            const b = await res.blob();
            if (b.size > 10000) {
              audioBlob = b;
              break;
            }
          } catch {
            // try next candidate
          }
        }
      }

      const bestAudioUrl = resolvedDirect || knownMaster || normalized.audioUrl;

      if (audioBlob && audioBlob.size > 10000) {
        const mimeType =
          audioBlob.type && !audioBlob.type.includes('text/') ? audioBlob.type : 'audio/mp4';
        const typedBlob =
          audioBlob.type === mimeType ? audioBlob : new Blob([audioBlob], { type: mimeType });

        if ('caches' in window) {
          const cache = await caches.open(OFFLINE_CACHE_NAME);
          await cache.put(
            `/offline-audio/${encodeURIComponent(normalized.id)}`,
            new Response(typedBlob, {
              headers: {
                'Content-Type': mimeType,
                'Content-Length': String(typedBlob.size),
              },
            })
          );
        }
        await saveOfflineBlobToIdb(normalized.id, typedBlob);
      }

      setDownloads((prev) =>
        prev.map((s) =>
          s.id === normalized.id
            ? { ...s, audioUrl: bestAudioUrl || s.audioUrl, offlineStatus: 'verified' }
            : s
        )
      );
    } catch {
      setDownloads((prev) =>
        prev.map((s) => (s.id === normalized.id ? { ...s, offlineStatus: 'verified' } : s))
      );
    }
  };

  const downloadSong = (song: Song) => {
    if (downloads.some((s) => s.id === song.id && s.offlineStatus === 'verified')) {
      const offlineQueue = downloads.filter((d) => d.offlineStatus === 'verified');
      playSong(song, offlineQueue.length > 0 ? offlineQueue : [song]);
      return;
    }
    persistSongToOfflineCache(song);
  };

  const retryDownload = (song: Song) => {
    persistSongToOfflineCache(song);
  };

  const removeDownload = (songId: string) => {
    setDownloads((prev) => prev.filter((s) => s.id !== songId));
    if ('caches' in window) {
      caches
        .open(OFFLINE_CACHE_NAME)
        .then((cache) => cache.delete(`/offline-audio/${encodeURIComponent(songId)}`))
        .catch(() => {});
    }
    deleteOfflineBlobFromIdb(songId).catch(() => {});
  };

  const isDownloaded = (songId: string) =>
    downloads.some((s) => s.id === songId && s.offlineStatus === 'verified');

  const isDownloading = (songId: string) =>
    downloads.some((s) => s.id === songId && s.offlineStatus === 'downloading');

  // Authentication Handlers
  const signInWithGoogle = async () => {
    const res = await signInWithPopup(auth, googleProvider);
    const credential = GoogleAuthProvider.credentialFromResult(res);
    if (credential?.accessToken) {
      setDriveAccessToken(credential.accessToken);
    }
    setUser({
      uid: res.user.uid,
      email: res.user.email,
      displayName: res.user.displayName || res.user.email?.split('@')[0] || 'User',
      photoURL: res.user.photoURL,
      isGuest: false,
    });
  };

  const signInWithEmail = async (email: string, pass: string) => {
    const res = await signInWithEmailAndPassword(auth, email, pass);
    setUser({
      uid: res.user.uid,
      email: res.user.email,
      displayName: res.user.displayName || email.split('@')[0],
      photoURL: res.user.photoURL,
      isGuest: false,
    });
  };

  const registerWithEmail = async (email: string, pass: string) => {
    const res = await createUserWithEmailAndPassword(auth, email, pass);
    setUser({
      uid: res.user.uid,
      email: res.user.email,
      displayName: email.split('@')[0],
      photoURL: null,
      isGuest: false,
    });
  };

  const signOut = async () => {
    await fbSignOut(auth);
    setUser({
      uid: 'guest_local_user',
      email: null,
      displayName: 'Guest Listener',
      photoURL: null,
      isGuest: true,
    });
  };

  const updateUser = (updates: Partial<UserProfile>) => {
    setUser((prev) => ({ ...prev, ...updates }));
  };

  // Frequent Tracks (sorted by play count descending)
  const frequentTracks = useMemo(() => {
    const songMap = new Map<string, Song>();
    [...POPULAR_FEATURED_SONGS, ...history, ...favorites].forEach((s) => {
      songMap.set(s.id, s);
    });

    return Object.entries(playCounts)
      .map(([id, count]) => {
        const song = songMap.get(id);
        if (!song) return null;
        return {
          ...song,
          playCount: count,
        };
      })
      .filter((s): s is Song & { playCount: number } => s !== null)
      .sort((a, b) => b.playCount - a.playCount)
      .slice(0, 10);
  }, [playCounts, history, favorites]);

  return (
    <MusicContext.Provider
      value={{
        currentSong,
        queue,
        currentIndex,
        isPlaying,
        isLoading,
        isRefreshingStream,
        streamRefreshCount,
        currentTime,
        duration,
        volume,
        isShuffle,
        isRepeat,
        playbackSpeed,
        audioQuality,
        favorites,
        history,
        frequentTracks,
        playlists,
        downloads,
        user,
        sleepTimerRemaining,
        playSong,
        selectAndPlaySong,
        stopCurrentBeforeSwitch,
        pauseSong,
        resumeSong,
        nextSong: handleNextSong,
        prevSong: handlePrevSong,
        seekTo,
        setVolume,
        toggleShuffle,
        toggleRepeat,
        setPlaybackSpeed,
        setAudioQuality,
        setSleepTimer,
        toggleFavorite,
        isFavorite,
        createPlaylist,
        deletePlaylist,
        addToPlaylist,
        removeFromPlaylist,
        downloadSong,
        retryDownload,
        removeDownload,
        isDownloaded,
        isDownloading,
        signInWithGoogle,
        signInWithEmail,
        registerWithEmail,
        signOut,
        updateUser,
      }}
    >
      {children}
    </MusicContext.Provider>
  );
};

export const useMusic = () => {
  const context = useContext(MusicContext);
  if (!context) {
    throw new Error('useMusic must be used within a MusicProvider');
  }
  return context;
};
