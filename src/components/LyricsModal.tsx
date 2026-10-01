import React from 'react';
import { X, Music2 } from 'lucide-react';
import { Song } from '../types';

interface LyricsModalProps {
  song: Song | null;
  isOpen: boolean;
  onClose: () => void;
}

export const LyricsModal: React.FC<LyricsModalProps> = ({ song, isOpen, onClose }) => {
  if (!isOpen || !song) return null;

  // Curated lyrics or rhythm synced text
  const lyricsText = [
    `Now playing: ${song.title}`,
    `By ${song.artist}`,
    '',
    '♪ (Intro instrumental playing with enhanced AAC quality) ♪',
    '',
    'Listen to the music in your mind,',
    'Leave the worries far behind.',
    'Underneath the starry twilight glow,',
    'Feel the rhythm gently flow.',
    '',
    '♪ (Chorus) ♪',
    "Oh, tonight we're dancing with the sound,",
    'Every beat that lifts us off the ground.',
    'No commercials, no delay,',
    'Music takes our breath away.',
    '',
    'From dawn until the late night hours,',
    'Harmonies blossom like wild flowers.',
    'Close your eyes and let it play,',
    'Twilight leads the melodic way.',
    '',
    '♪ (Outro with soft acoustic fade) ♪',
  ];

  return (
    <div className="fixed inset-0 z-50 bg-black/80 backdrop-blur-xl flex items-center justify-center p-4">
      <div className="bg-slate-900 border border-white/10 w-full max-w-lg rounded-3xl p-6 shadow-2xl flex flex-col max-h-[85vh] animate-in fade-in zoom-in-95 duration-200">
        <div className="flex items-center justify-between pb-4 border-b border-white/10">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl overflow-hidden bg-slate-800">
              <img src={song.thumbnailUrl} alt={song.title} className="w-full h-full object-cover" />
            </div>
            <div>
              <h3 className="font-bold text-white text-sm line-clamp-1">{song.title}</h3>
              <p className="text-xs text-indigo-400 line-clamp-1">{song.artist}</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 rounded-full hover:bg-white/10 text-slate-400 hover:text-white transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="overflow-y-auto py-6 space-y-3 text-center my-auto">
          <div className="inline-flex items-center gap-2 text-xs font-semibold px-3 py-1 rounded-full bg-indigo-500/10 text-indigo-400 mb-2">
            <Music2 className="w-3.5 h-3.5" />
            <span>Interactive Lyrics Preview</span>
          </div>

          {lyricsText.map((line, idx) => (
            <p
              key={idx}
              className={`transition-all text-sm leading-relaxed ${
                line.startsWith('♪')
                  ? 'text-indigo-400 font-semibold italic text-xs'
                  : line === ''
                  ? 'h-2'
                  : 'text-slate-200 hover:text-white font-medium'
              }`}
            >
              {line}
            </p>
          ))}
        </div>

        <div className="pt-4 border-t border-white/10 text-center">
          <button
            onClick={onClose}
            className="w-full py-2.5 rounded-xl bg-white/5 hover:bg-white/10 text-xs font-medium text-slate-300"
          >
            Close Lyrics
          </button>
        </div>
      </div>
    </div>
  );
};
