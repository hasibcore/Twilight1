import React from 'react';
import { Compass, Music2, Sparkles, Play, Disc } from 'lucide-react';
import { useMusic } from '../context/MusicContext';
import { POPULAR_FEATURED_SONGS, FEATURED_ARTISTS } from '../services/musicApi';

interface ExploreScreenProps {
  onSearchGenre: (genre: string) => void;
  onSelectArtist: (artist: string) => void;
}

export const ExploreScreen: React.FC<ExploreScreenProps> = ({ onSearchGenre, onSelectArtist }) => {
  const { playSong } = useMusic();

  const genres = [
    { name: 'Pop Hits', color: 'from-pink-500 to-rose-600', query: 'Top Pop Global Hits' },
    { name: 'Hip-Hop & R&B', color: 'from-amber-500 to-orange-600', query: 'Hip Hop Beats Hits' },
    { name: 'Rock & Alternative', color: 'from-red-600 to-rose-800', query: 'Rock Classics and Modern' },
    { name: 'Acoustic & Unplugged', color: 'from-emerald-500 to-teal-700', query: 'Acoustic Guitar Unplugged' },
    { name: 'Lo-Fi Chill Beats', color: 'from-indigo-500 to-purple-700', query: 'Lo-Fi Study Beats' },
    { name: 'EDM & Festival', color: 'from-cyan-500 to-blue-600', query: 'Electronic Dance EDM' },
    { name: 'Bengali Melodies', color: 'from-teal-600 to-emerald-800', query: 'Soulful Bengali Acoustic Hits' },
    { name: 'Ambient & Sleep', color: 'from-purple-600 to-indigo-900', query: 'Ambient Deep Sleep Meditation' },
  ];

  return (
    <div className="space-y-8 pb-12">
      <div>
        <span className="text-xs uppercase font-extrabold tracking-widest text-indigo-400">
          DISCOVER & EXPLORE
        </span>
        <h1 className="text-2xl sm:text-4xl font-black text-white tracking-tight mt-0.5">
          Genres, Moods & Charts
        </h1>
      </div>

      {/* Featured Genres Grid */}
      <section className="space-y-4">
        <h3 className="text-lg font-bold text-white tracking-tight">Browse by Genre</h3>
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-4">
          {genres.map((g) => (
            <div
              key={g.name}
              onClick={() => onSearchGenre(g.query)}
              className={`h-28 rounded-3xl bg-gradient-to-br ${g.color} p-4 flex flex-col justify-between cursor-pointer hover:scale-102 transition-transform shadow-lg shadow-black/40 group relative overflow-hidden`}
            >
              <span className="text-sm sm:text-base font-extrabold text-white leading-tight">
                {g.name}
              </span>
              <div className="self-end p-2 rounded-full bg-white/20 backdrop-blur-md opacity-80 group-hover:opacity-100 transition-opacity">
                <Music2 className="w-4 h-4 text-white" />
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Top Global Selections */}
      <section className="space-y-4">
        <div className="flex items-center gap-2">
          <Sparkles className="w-4 h-4 text-amber-400" />
          <h3 className="text-lg font-bold text-white tracking-tight">International Master Hits</h3>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {POPULAR_FEATURED_SONGS.map((song) => (
            <div
              key={`explore_${song.id}`}
              onClick={() => playSong(song, POPULAR_FEATURED_SONGS)}
              className="group flex items-center gap-3 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 transition-all cursor-pointer"
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
                {song.durationFormatted}
              </span>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
};
