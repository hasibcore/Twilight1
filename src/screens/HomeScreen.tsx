import React, { useState, useEffect } from 'react';
import {
  Play,
  Flame,
  Sparkles,
  RefreshCw,
  TrendingUp,
  Radio,
  ArrowRight,
  Download,
  Headphones,
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

export const HomeScreen: React.FC<HomeScreenProps> = ({
  onOpenSearch,
  onOpenPlaylistModal,
  onSelectArtist,
  onOpenLanding,
}) => {
  const { history, favorites, playSong, frequentTracks } = useMusic();

  const [selectedVibeId, setSelectedVibeId] = useState<string>('for_you');
  const [dynamicSongs, setDynamicSongs] = useState<Song[]>([]);
  const [trendingSongs, setTrendingSongs] = useState<Song[]>([]);
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

      setDynamicSongs(songs.length > 0 ? songs : POPULAR_FEATURED_SONGS);
    } catch {
      setDynamicSongs(POPULAR_FEATURED_SONGS);
    } finally {
      setIsRefreshingMix(false);
    }
  };

  useEffect(() => {
    refreshDynamicMix('for_you');
    MusicApi.getTrendingSongs().then((songs) => setTrendingSongs(songs));
  }, []);

  const timeVibe = getTimeBasedVibe();

  return (
    <div className="space-y-8 pb-12">
      {/* Top Header / Greeting Bar */}
      <div className="flex items-center justify-between gap-4">
        <div>
          <span className="text-xs uppercase font-extrabold tracking-widest text-indigo-400">
            {timeVibe.label}
          </span>
          <h1 className="text-2xl sm:text-4xl font-black text-white tracking-tight mt-0.5">
            {getGreeting()}
          </h1>
        </div>
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
              onClick={() => playSong(frequentTracks[0], frequentTracks)}
              className="px-3.5 py-1.5 rounded-xl bg-orange-500 hover:bg-orange-400 text-slate-950 text-xs font-extrabold flex items-center gap-1.5 shadow-md shadow-orange-500/30 transition-transform active:scale-95"
            >
              <Play className="w-3.5 h-3.5 fill-slate-950" />
              <span>Play All</span>
            </button>
          </div>

          <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-3 pt-2">
            {frequentTracks.slice(0, 5).map((song) => (
              <div
                key={`freq_${song.id}`}
                onClick={() => playSong(song, frequentTracks)}
                className="group relative bg-slate-900/60 hover:bg-slate-800/80 border border-white/5 hover:border-orange-500/30 rounded-2xl p-2.5 transition-all cursor-pointer flex flex-col justify-between"
              >
                <div className="relative aspect-square rounded-xl overflow-hidden mb-2 bg-slate-800">
                  <img src={song.thumbnailUrl} alt={song.title} className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
                  <div className="absolute top-1.5 right-1.5 bg-black/70 backdrop-blur-md px-2 py-0.5 rounded-full text-[10px] font-bold text-orange-400 border border-orange-500/30">
                    {song.playCount} plays
                  </div>
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                    <div className="w-10 h-10 rounded-full bg-orange-500 text-slate-950 flex items-center justify-center shadow-lg">
                      <Play className="w-5 h-5 fill-slate-950 translate-x-0.5" />
                    </div>
                  </div>
                </div>

                <div>
                  <h4 className="text-xs font-bold text-white truncate group-hover:text-orange-300">{song.title}</h4>
                  <p className="text-[11px] text-slate-400 truncate">{song.artist}</p>
                </div>
              </div>
            ))}
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
          {dynamicSongs.slice(0, 6).map((song) => (
            <div
              key={`dyn_${song.id}`}
              onClick={() => playSong(song, dynamicSongs)}
              className="group bg-slate-900/60 hover:bg-slate-800/80 border border-white/5 hover:border-indigo-500/30 rounded-2xl p-2.5 transition-all cursor-pointer flex flex-col justify-between"
            >
              <div className="relative aspect-square rounded-xl overflow-hidden mb-2 bg-slate-800">
                <img
                  src={song.thumbnailUrl}
                  alt={song.title}
                  className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                />
                <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                  <div className="w-10 h-10 rounded-full bg-indigo-600 text-white flex items-center justify-center shadow-lg">
                    <Play className="w-5 h-5 fill-white translate-x-0.5" />
                  </div>
                </div>
              </div>

              <div>
                <h4 className="text-xs font-bold text-white truncate group-hover:text-indigo-400">{song.title}</h4>
                <p className="text-[11px] text-slate-400 truncate">{song.artist}</p>
              </div>
            </div>
          ))}
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
          {(trendingSongs.length > 0 ? trendingSongs : POPULAR_FEATURED_SONGS).slice(0, 6).map((song, idx) => (
            <div
              key={`trend_${song.id}_${idx}`}
              onClick={() => playSong(song, trendingSongs)}
              className="group flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 hover:border-white/10 transition-all cursor-pointer"
            >
              <span className="font-mono text-xs font-bold text-slate-500 w-5 text-center group-hover:text-indigo-400">
                {idx + 1}
              </span>

              <div className="w-12 h-12 rounded-xl overflow-hidden relative shrink-0 bg-slate-800">
                <img src={song.thumbnailUrl} alt={song.title} className="w-full h-full object-cover" />
                <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                  <Play className="w-4 h-4 text-white fill-white" />
                </div>
              </div>

              <div className="min-w-0 flex-1">
                <h4 className="text-sm font-bold text-white truncate group-hover:text-indigo-300">
                  {song.title}
                </h4>
                <p className="text-xs text-slate-400 truncate">{song.artist}</p>
              </div>

              <span className="text-xs text-slate-500 font-mono shrink-0">
                {song.durationFormatted || '03:30'}
              </span>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
};
