import React, { useState, useEffect } from 'react';
import { Search as SearchIcon, X, Play, Music, Sparkles } from 'lucide-react';
import { useMusic } from '../context/MusicContext';
import { Song } from '../types';
import { MusicApi, POPULAR_FEATURED_SONGS } from '../services/musicApi';

interface SearchScreenProps {
  initialQuery?: string;
  onOpenPlaylistModal: (song: Song) => void;
}

export const SearchScreen: React.FC<SearchScreenProps> = ({ initialQuery = '' }) => {
  const { playSong } = useMusic();
  const [query, setQuery] = useState(initialQuery);
  const [results, setResults] = useState<Song[]>([]);
  const [isSearching, setIsSearching] = useState(false);

  const trendingTags = [
    'Acoustic Pop',
    'Ed Sheeran',
    'The Weeknd',
    'Lo-Fi Study',
    'Bengali Soulful',
    'Midnight Chill',
    'Adele',
    'Queen Rock',
  ];

  const handleSearch = async (searchTerm: string) => {
    const term = searchTerm.trim();
    if (!term) {
      setResults([]);
      return;
    }

    setIsSearching(true);
    try {
      const songs = await MusicApi.searchSongs(term);
      setResults(songs);
    } catch {
      setResults(POPULAR_FEATURED_SONGS);
    } finally {
      setIsSearching(false);
    }
  };

  useEffect(() => {
    if (initialQuery) {
      setQuery(initialQuery);
      handleSearch(initialQuery);
    }
  }, [initialQuery]);

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    handleSearch(query);
  };

  return (
    <div className="space-y-6 pb-12">
      {/* Search Input Bar */}
      <form onSubmit={onSubmit} className="relative">
        <div className="relative flex items-center">
          <SearchIcon className="absolute left-4 w-5 h-5 text-slate-400" />
          <input
            type="text"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              if (e.target.value.length > 2) {
                handleSearch(e.target.value);
              }
            }}
            placeholder="Search songs, artists, channels or genres..."
            autoFocus
            className="w-full pl-12 pr-10 py-3.5 rounded-2xl bg-white/5 border border-white/10 text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 text-sm shadow-xl"
          />
          {query && (
            <button
              type="button"
              onClick={() => {
                setQuery('');
                setResults([]);
              }}
              className="absolute right-3.5 p-1 rounded-full text-slate-400 hover:text-white hover:bg-white/10"
            >
              <X className="w-4 h-4" />
            </button>
          )}
        </div>
      </form>

      {/* Trending Search Chips */}
      <div className="space-y-2">
        <span className="text-xs font-semibold text-slate-400 tracking-wider uppercase">
          Trending Searches
        </span>
        <div className="flex flex-wrap gap-2">
          {trendingTags.map((tag) => (
            <button
              key={tag}
              onClick={() => {
                setQuery(tag);
                handleSearch(tag);
              }}
              className="px-3 py-1.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/5 text-xs text-slate-300 hover:text-white transition-all"
            >
              {tag}
            </button>
          ))}
        </div>
      </div>

      {/* Search Results */}
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="text-lg font-bold text-white tracking-tight">
            {isSearching
              ? 'Searching YouTube...'
              : results.length > 0
              ? `Results for "${query}"`
              : 'Explore Songs'}
          </h3>
          {results.length > 0 && (
            <span className="text-xs text-slate-400">{results.length} songs found</span>
          )}
        </div>

        {isSearching ? (
          <div className="py-12 flex flex-col items-center justify-center gap-3">
            <div className="w-8 h-8 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin" />
            <span className="text-xs text-slate-400">Loading audio streams from YouTube...</span>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
            {(results.length > 0 ? results : POPULAR_FEATURED_SONGS).map((song) => (
              <div
                key={`search_${song.id}`}
                onClick={() => playSong(song, results.length > 0 ? results : POPULAR_FEATURED_SONGS)}
                className="group flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 hover:border-indigo-500/30 transition-all cursor-pointer"
              >
                <div className="w-12 h-12 rounded-xl overflow-hidden relative shrink-0 bg-slate-800">
                  <img src={song.thumbnailUrl} alt={song.title} className="w-full h-full object-cover" />
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                    <Play className="w-4 h-4 text-white fill-white" />
                  </div>
                </div>

                <div className="min-w-0 flex-1">
                  <h4 className="text-xs font-bold text-white truncate group-hover:text-indigo-400">
                    {song.title}
                  </h4>
                  <p className="text-[11px] text-slate-400 truncate">{song.artist}</p>
                </div>

                <span className="text-xs text-slate-500 font-mono shrink-0">
                  {song.durationFormatted || '03:30'}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
