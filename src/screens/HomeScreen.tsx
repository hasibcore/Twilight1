import React, { useState, useEffect } from 'react';
import {
  Play,
  Pause,
  Flame,
  Sparkles,
  RefreshCw,
  TrendingUp,
  Radio,
  ArrowRight,
  Loader2,
  Download,
  Check,
  GitBranch,
} from 'lucide-react';
import { useMusic } from '../context/MusicContext';
import { Song } from '../types';
import { MusicApi, FEATURED_ARTISTS, POPULAR_FEATURED_SONGS } from '../services/musicApi';
import { VIBE_CATEGORIES, getTimeBasedVibe, TasteEngine } from '../services/tasteEngine';

interface HomeScreenProps {
  onOpenSearch: () => void;
  onOpenPlaylistModal: (song: Song) => void;
  onSelectArtist: (artistName: string) => void;
  onOpenLanding: () => void;
}

const ensureYtThumb = (s: Song): Song =>
  s.id && s.id.length === 11 && !s.id.startsWith('sp_')
    ? { ...s, thumbnailUrl: `https://i.ytimg.com/vi/${s.id}/hqdefault.jpg` }
    : s;

export const HomeScreen: React.FC<HomeScreenProps> = ({
  onOpenSearch,
  onSelectArtist,
  onOpenLanding,
}) => {
  const {
    history,
    favorites,
    downloads,
    selectAndPlaySong,
    frequentTracks,
    currentSong,
    isPlaying,
    isLoading,
    downloadSong,
    isDownloaded,
    isDownloading,
  } = useMusic();

  const [selectedVibeId, setSelectedVibeId] = useState<string>('for_you');
  const [dynamicSongs, setDynamicSongs] = useState<Song[]>(() => {
    try {
      const cached = localStorage.getItem('twilight_home_dynamic_v1');
      if (cached) {
        const parsed = JSON.parse(cached);
        if (Array.isArray(parsed) && parsed.length > 0) return parsed.map(ensureYtThumb);
      }
    } catch {}
    return POPULAR_FEATURED_SONGS;
  });
  const [trendingSongs, setTrendingSongs] = useState<Song[]>(() => {
    try {
      const cached = localStorage.getItem('twilight_home_trending_v1');
      if (cached) {
        const parsed = JSON.parse(cached);
        if (Array.isArray(parsed) && parsed.length > 0) return parsed.map(ensureYtThumb);
      }
    } catch {}
    return POPULAR_FEATURED_SONGS;
  });
  const [isRefreshingMix, setIsRefreshingMix] = useState<boolean>(false);

  // Time based greeting
  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 22) return 'Good evening';
    return 'Good night';
  };

  const refreshDynamicMix = async (vibeId: string = selectedVibeId) => {
    setSelectedVibeId(vibeId);
    setIsRefreshingMix(true);
    try {
      const profile = TasteEngine.analyzeTaste(history, favorites);
      const vibeObj = VIBE_CATEGORIES.find((v) => v.id === vibeId);
      const vibeQuery = vibeObj ? vibeObj.query : getTimeBasedVibe().query;

      const songs = await MusicApi.getDynamicMix({
        artists: profile.topArtists,
        genres: profile.favoriteGenres,
        historyIds: history.map((s) => s.id),
        vibe: vibeQuery,
      });

      const resolved = songs.length > 0 ? songs : POPULAR_FEATURED_SONGS;
      setDynamicSongs(resolved);
      try {
        localStorage.setItem('twilight_home_dynamic_v1', JSON.stringify(resolved));
      } catch {}
    } catch {
      setDynamicSongs((prev) => (prev.length > 0 ? prev : POPULAR_FEATURED_SONGS));
    } finally {
      setIsRefreshingMix(false);
    }
  };

  useEffect(() => {
    // Defer live background refresh slightly so first paint is instantaneous
    const timer = setTimeout(() => {
      refreshDynamicMix('for_you');
      MusicApi.getTrendingSongs().then((songs) => {
        if (songs && songs.length > 0) {
          setTrendingSongs(songs);
          try {
            localStorage.setItem('twilight_home_trending_v1', JSON.stringify(songs));
          } catch {}
        }
      });
    }, 60);
    return () => clearTimeout(timer);
  }, []);

  const timeVibe = getTimeBasedVibe();

  return (
    <div className="space-y-8 pb-12">
      {/* Top Header / Greeting Bar */}
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <span className="text-xs uppercase font-extrabold tracking-widest text-indigo-400">
            {timeVibe.label}
          </span>
          <h1 className="text-2xl sm:text-4xl font-black text-white tracking-tight mt-0.5">
            {getGreeting()}
          </h1>
        </div>

        <button
          onClick={onOpenLanding}
          className="px-4 py-2.5 rounded-2xl bg-emerald-500/15 hover:bg-emerald-500/25 border border-emerald-500/30 text-emerald-300 text-xs font-bold flex items-center gap-2 transition-all shadow-lg shadow-emerald-950/30 cursor-pointer"
        >
          <GitBranch className="w-4 h-4 text-emerald-400" />
          <span>GitHub Push &amp; Release (v2.4.0)</span>
        </button>
      </div>

      {/* Vibe Categories Filter Chips */}
      <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-none">
        <button
          onClick={() => refreshDynamicMix('for_you')}
          className={`px-4 py-2 rounded-2xl text-xs font-bold whitespace-nowrap transition-all flex items-center gap-2 ${
            selectedVibeId === 'for_you'
              ? 'bg-white text-slate-950 shadow-lg shadow-white/20'
              : 'bg-white/5 hover:bg-white/10 text-slate-300'
          }`}
        >
          <Sparkles className="w-3.5 h-3.5" />
          <span>For You</span>
        </button>

        {VIBE_CATEGORIES.map((vibe) => {
          const isActive = selectedVibeId === vibe.id;
          return (
            <button
              key={vibe.id}
              onClick={() => refreshDynamicMix(vibe.id)}
              className={`px-4 py-2 rounded-2xl text-xs font-semibold whitespace-nowrap transition-all ${
                isActive
                  ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/25'
                  : 'bg-white/5 hover:bg-white/10 text-slate-300'
              }`}
            >
              {vibe.label}
            </button>
          );
        })}
      </div>

      {/* Frequently Played / ON HEAVY REPEAT (MOST PLAYED) */}
      {frequentTracks && frequentTracks.length > 0 && (
        <section className="space-y-3.5 bg-gradient-to-r from-orange-950/20 via-rose-950/20 to-black/40 p-4 sm:p-5 rounded-3xl border border-orange-500/20 shadow-xl relative overflow-hidden">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <span className="w-8 h-8 rounded-xl bg-orange-500/20 border border-orange-500/40 flex items-center justify-center text-orange-400">
                <Flame className="w-4 h-4 fill-orange-400" />
              </span>
              <div>
                <h3 className="text-base sm:text-lg font-black text-white tracking-tight">
                  ON HEAVY REPEAT (MOST PLAYED)
                </h3>
                <p className="text-xs text-orange-300/80">Songs you listen to the most</p>
              </div>
            </div>

            <button
              onClick={() => selectAndPlaySong(frequentTracks[0], frequentTracks)}
              className="px-3.5 py-1.5 rounded-xl bg-orange-500 hover:bg-orange-400 text-slate-950 text-xs font-extrabold flex items-center gap-1.5 shadow-md shadow-orange-500/30 transition-transform active:scale-95"
            >
              <Play className="w-3.5 h-3.5 fill-slate-950" />
              <span>Play All</span>
            </button>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3 pt-2">
            {frequentTracks.slice(0, 5).map((song) => {
              const isCurrent = currentSong?.id === song.id;
              return (
                <div
                  key={`freq_${song.id}`}
                  onClick={() => selectAndPlaySong(song, frequentTracks)}
                  className={`group relative rounded-2xl p-2.5 transition-all cursor-pointer flex flex-col justify-between border ${
                    isCurrent
                      ? 'bg-orange-500/15 border-orange-500/50 shadow-lg shadow-orange-500/10'
                      : 'bg-slate-900/60 hover:bg-slate-800/80 border-white/5 hover:border-orange-500/30'
                  }`}
                >
                  <div className="relative aspect-square rounded-xl overflow-hidden mb-2 bg-slate-800">
                    <img
                      src={song.thumbnailUrl}
                      alt={song.title}
                      className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                    />
                    <div className="absolute top-1.5 right-1.5 bg-black/70 backdrop-blur-md px-2 py-0.5 rounded-full text-[10px] font-bold text-orange-400 border border-orange-500/30">
                      {song.playCount} plays
                    </div>
                    <div
                      className={`absolute inset-0 bg-black/40 flex items-center justify-center transition-opacity ${
                        isCurrent ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'
                      }`}
                    >
                      <div className="w-10 h-10 rounded-full bg-orange-500 text-slate-950 flex items-center justify-center shadow-lg">
                        {isCurrent && isLoading ? (
                          <Loader2 className="w-5 h-5 text-slate-950 animate-spin" />
                        ) : isCurrent && isPlaying ? (
                          <Pause className="w-5 h-5 fill-slate-950" />
                        ) : (
                          <Play className="w-5 h-5 fill-slate-950 translate-x-0.5" />
                        )}
                      </div>
                    </div>
                  </div>

                  <div>
                    <h4
                      className={`text-xs font-bold truncate ${
                        isCurrent ? 'text-orange-300' : 'text-white group-hover:text-orange-300'
                      }`}
                    >
                      {song.title}
                    </h4>
                    <p className="text-[11px] text-slate-400 truncate">{song.artist}</p>
                  </div>
                </div>
              );
            })}
          </div>
        </section>
      )}

      {/* Dynamic Taste Match Mix */}
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <span className="text-xs font-bold text-indigo-400 uppercase tracking-wider">Dynamic Taste Engine</span>
            <h3 className="text-xl font-extrabold text-white tracking-tight mt-0.5">
              {selectedVibeId === 'for_you'
                ? timeVibe.label
                : VIBE_CATEGORIES.find((v) => v.id === selectedVibeId)?.label || 'Personalized Mix'}
            </h3>
          </div>

          <button
            onClick={() => refreshDynamicMix()}
            disabled={isRefreshingMix}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/5 hover:bg-white/10 text-xs text-slate-300 hover:text-white transition-colors"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${isRefreshingMix ? 'animate-spin' : ''}`} />
            <span>Refresh Mix</span>
          </button>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 gap-3.5">
          {dynamicSongs.slice(0, 6).map((song) => {
            const isCurrent = currentSong?.id === song.id;
            const isDown = isDownloaded(song.id);
            const isDownLoading = isDownloading(song.id);
            return (
              <div
                key={`dyn_${song.id}`}
                onClick={() => selectAndPlaySong(song, dynamicSongs)}
                className={`group rounded-2xl p-2.5 transition-all cursor-pointer flex flex-col justify-between border ${
                  isCurrent
                    ? 'bg-indigo-600/20 border-indigo-500/50 shadow-lg shadow-indigo-500/10'
                    : 'bg-slate-900/60 hover:bg-slate-800/80 border-white/5 hover:border-indigo-500/30'
                }`}
              >
                <div className="relative aspect-square rounded-xl overflow-hidden mb-2 bg-slate-800">
                  <img
                    src={song.thumbnailUrl}
                    alt={song.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                  />
                  <button
                    type="button"
                    onClick={(e) => {
                      e.stopPropagation();
                      downloadSong(song);
                    }}
                    disabled={isDownLoading}
                    className={`absolute top-1.5 right-1.5 z-10 p-1.5 rounded-xl backdrop-blur-md border transition-all ${
                      isDown
                        ? 'bg-emerald-500/30 border-emerald-400/50 text-emerald-300'
                        : isDownLoading
                        ? 'bg-indigo-500/30 border-indigo-400/50 text-indigo-200'
                        : 'bg-black/60 hover:bg-black/80 border-white/15 text-white'
                    }`}
                    title={
                      isDown
                        ? 'Saved for Offline Playback (Tap to save audio file)'
                        : isDownLoading
                        ? 'Downloading audio...'
                        : 'Download Song for Offline Playback'
                    }
                  >
                    {isDownLoading ? (
                      <Loader2 className="w-3.5 h-3.5 animate-spin" />
                    ) : isDown ? (
                      <Check className="w-3.5 h-3.5" />
                    ) : (
                      <Download className="w-3.5 h-3.5" />
                    )}
                  </button>
                  <div
                    className={`absolute inset-0 bg-black/40 flex items-center justify-center transition-opacity ${
                      isCurrent ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'
                    }`}
                  >
                    <div className="w-10 h-10 rounded-full bg-indigo-600 text-white flex items-center justify-center shadow-lg">
                      {isCurrent && isLoading ? (
                        <Loader2 className="w-5 h-5 text-white animate-spin" />
                      ) : isCurrent && isPlaying ? (
                        <Pause className="w-5 h-5 fill-white" />
                      ) : (
                        <Play className="w-5 h-5 fill-white translate-x-0.5" />
                      )}
                    </div>
                  </div>
                </div>

                <div>
                  <h4
                    className={`text-xs font-bold truncate ${
                      isCurrent ? 'text-indigo-300' : 'text-white group-hover:text-indigo-400'
                    }`}
                  >
                    {song.title}
                  </h4>
                  <p className="text-[11px] text-slate-400 truncate">{song.artist}</p>
                </div>
              </div>
            );
          })}
        </div>
      </section>

      {/* Featured Artists Row */}
      <section className="space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Radio className="w-4 h-4 text-rose-500" />
            <h3 className="text-lg font-bold text-white tracking-tight">Artist Radio Stations</h3>
          </div>
          <button
            onClick={onOpenSearch}
            className="text-xs font-semibold text-indigo-400 hover:text-indigo-300 flex items-center gap-1"
          >
            <span>Explore All</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="flex items-center gap-4 overflow-x-auto pb-2 scrollbar-none">
          {FEATURED_ARTISTS.map((artist) => (
            <div
              key={artist.id}
              onClick={() => onSelectArtist(artist.name)}
              className="group flex flex-col items-center shrink-0 cursor-pointer w-24 sm:w-28 text-center"
            >
              <div className="w-20 h-20 sm:w-24 sm:h-24 rounded-full overflow-hidden bg-slate-800 border-2 border-transparent group-hover:border-indigo-500 group-hover:scale-105 transition-all shadow-lg mb-2 relative">
                <img src={artist.thumbnailUrl} alt={artist.name} className="w-full h-full object-cover" />
                <div className="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                  <Play className="w-6 h-6 text-white fill-white" />
                </div>
              </div>
              <span className="text-xs font-bold text-slate-200 group-hover:text-white truncate w-full">
                {artist.name}
              </span>
              <span className="text-[10px] text-slate-500">{artist.subscribers} listeners</span>
            </div>
          ))}
        </div>
      </section>

      {/* Global Trending Hits */}
      <section className="space-y-4">
        <div className="flex items-center gap-2">
          <TrendingUp className="w-4 h-4 text-emerald-400" />
          <h3 className="text-lg font-bold text-white tracking-tight">Trending Across YouTube</h3>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
          {(trendingSongs.length > 0 ? trendingSongs : POPULAR_FEATURED_SONGS).slice(0, 6).map((song, idx) => {
            const isCurrent = currentSong?.id === song.id;
            const isDown = isDownloaded(song.id);
            const isDownLoading = isDownloading(song.id);
            return (
              <div
                key={`trend_${song.id}_${idx}`}
                onClick={() => selectAndPlaySong(song, trendingSongs.length > 0 ? trendingSongs : POPULAR_FEATURED_SONGS)}
                className={`group flex items-center gap-3.5 p-3 rounded-2xl border transition-all cursor-pointer ${
                  isCurrent
                    ? 'bg-indigo-600/20 border-indigo-500/40'
                    : 'bg-white/5 hover:bg-white/10 border-white/5 hover:border-white/10'
                }`}
              >
                <span
                  className={`font-mono text-xs font-bold w-5 text-center ${
                    isCurrent ? 'text-indigo-400' : 'text-slate-500 group-hover:text-indigo-400'
                  }`}
                >
                  {idx + 1}
                </span>

                <div className="w-12 h-12 rounded-xl overflow-hidden relative shrink-0 bg-slate-800">
                  <img src={song.thumbnailUrl} alt={song.title} className="w-full h-full object-cover" />
                  <div
                    className={`absolute inset-0 bg-black/40 flex items-center justify-center transition-opacity ${
                      isCurrent ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'
                    }`}
                  >
                    {isCurrent && isLoading ? (
                      <Loader2 className="w-4 h-4 text-white animate-spin" />
                    ) : isCurrent && isPlaying ? (
                      <Pause className="w-4 h-4 text-white fill-white" />
                    ) : (
                      <Play className="w-4 h-4 text-white fill-white" />
                    )}
                  </div>
                </div>

                <div className="min-w-0 flex-1">
                  <h4
                    className={`text-sm font-bold truncate ${
                      isCurrent ? 'text-indigo-300' : 'text-white group-hover:text-indigo-300'
                    }`}
                  >
                    {song.title}
                  </h4>
                  <p className="text-xs text-slate-400 truncate">{song.artist}</p>
                </div>

                <span className="text-xs text-slate-500 font-mono shrink-0">
                  {song.durationFormatted || '03:30'}
                </span>

                <button
                  type="button"
                  onClick={(e) => {
                    e.stopPropagation();
                    downloadSong(song);
                  }}
                  disabled={isDownLoading}
                  className={`p-2 rounded-xl border transition-colors shrink-0 ${
                    isDown
                      ? 'text-emerald-400 bg-emerald-500/15 border-emerald-500/30 hover:bg-emerald-500/25'
                      : isDownLoading
                      ? 'text-indigo-400 bg-indigo-500/15 border-indigo-500/30'
                      : 'text-slate-400 hover:text-white bg-white/5 hover:bg-white/10 border-white/10'
                  }`}
                  title={
                    isDown
                      ? 'Saved for Offline Playback (Tap to save audio file)'
                      : isDownLoading
                      ? 'Downloading audio...'
                      : 'Download Song for Offline Playback'
                  }
                >
                  {isDownLoading ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : isDown ? (
                    <Check className="w-4 h-4" />
                  ) : (
                    <Download className="w-4 h-4" />
                  )}
                </button>
              </div>
            );
          })}
        </div>
      </section>
    </div>
  );
};
