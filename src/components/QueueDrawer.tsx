import React from 'react';
import { X, Play, Music, Trash2 } from 'lucide-react';
import { useMusic } from '../context/MusicContext';

interface QueueDrawerProps {
  isOpen: boolean;
  onClose: () => void;
}

export const QueueDrawer: React.FC<QueueDrawerProps> = ({ isOpen, onClose }) => {
  const { queue, currentIndex, currentSong, playSong } = useMusic();

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-black/70 backdrop-blur-md flex justify-end">
      <div className="bg-slate-900 border-l border-white/10 w-full max-w-md h-full flex flex-col p-6 shadow-2xl animate-in slide-in-from-right duration-250">
        <div className="flex items-center justify-between pb-4 border-b border-white/10">
          <div>
            <h2 className="text-lg font-bold text-white">Up Next & Queue</h2>
            <p className="text-xs text-slate-400">{queue.length} songs in queue</p>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-full hover:bg-white/10 text-slate-400 hover:text-white"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Current Playing Song Card */}
        {currentSong && (
          <div className="my-4 p-3 rounded-2xl bg-indigo-950/40 border border-indigo-500/30 flex items-center gap-3">
            <div className="w-12 h-12 rounded-xl overflow-hidden relative shrink-0">
              <img src={currentSong.thumbnailUrl} alt={currentSong.title} className="w-full h-full object-cover" />
              <div className="absolute inset-0 bg-black/40 flex items-center justify-center">
                <Music className="w-5 h-5 text-indigo-400 animate-bounce" />
              </div>
            </div>
            <div className="min-w-0 flex-1">
              <span className="text-[10px] uppercase font-bold text-indigo-400 tracking-wider">Now Playing</span>
              <h4 className="text-sm font-bold text-white truncate">{currentSong.title}</h4>
              <p className="text-xs text-slate-400 truncate">{currentSong.artist}</p>
            </div>
          </div>
        )}

        {/* Queue List */}
        <div className="flex-1 overflow-y-auto space-y-2 pr-1">
          <span className="text-xs font-semibold text-slate-400 tracking-wider uppercase block my-2">Next in Queue</span>
          {queue.map((song, idx) => {
            const isCurrent = idx === currentIndex;
            return (
              <div
                key={`${song.id}_${idx}`}
                onClick={() => playSong(song, queue)}
                className={`group flex items-center gap-3 p-2.5 rounded-xl cursor-pointer transition-all ${
                  isCurrent ? 'bg-white/10 border border-indigo-500/30' : 'hover:bg-white/5'
                }`}
              >
                <div className="w-10 h-10 rounded-lg overflow-hidden shrink-0 relative bg-slate-800">
                  <img src={song.thumbnailUrl} alt={song.title} className="w-full h-full object-cover" />
                  <div className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                    <Play className="w-4 h-4 text-white fill-white" />
                  </div>
                </div>

                <div className="min-w-0 flex-1">
                  <h4 className={`text-xs font-semibold truncate ${isCurrent ? 'text-indigo-400' : 'text-slate-200'}`}>
                    {song.title}
                  </h4>
                  <p className="text-[11px] text-slate-400 truncate">{song.artist}</p>
                </div>

                <span className="text-[11px] text-slate-500 font-mono shrink-0">
                  {song.durationFormatted || '03:30'}
                </span>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
