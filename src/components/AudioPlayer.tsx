import React, { useState } from 'react';
import {
  Play,
  Pause,
  SkipBack,
  SkipForward,
  Shuffle,
  Repeat,
  Volume2,
  VolumeX,
  Heart,
  ChevronDown,
  ListMusic,
  FileText,
  Clock,
  Sparkles,
  Download,
  Check,
  Plus,
} from 'lucide-react';
import { useMusic } from '../context/MusicContext';
import { LyricsModal } from './LyricsModal';
import { QueueDrawer } from './QueueDrawer';
import { PlaylistModal } from './PlaylistModal';

export const AudioPlayer: React.FC = () => {
  const {
    currentSong,
    isPlaying,
    isLoading,
    currentTime,
    duration,
    volume,
    isShuffle,
    isRepeat,
    playbackSpeed,
    audioQuality,
    sleepTimerRemaining,
    playSong,
    pauseSong,
    resumeSong,
    nextSong,
    prevSong,
    seekTo,
    setVolume,
    toggleShuffle,
    toggleRepeat,
    setPlaybackSpeed,
    setSleepTimer,
    toggleFavorite,
    isFavorite,
    downloadSong,
    isDownloaded,
  } = useMusic();

  const [isExpanded, setIsExpanded] = useState(false);
  const [showLyrics, setShowLyrics] = useState(false);
  const [showQueue, setShowQueue] = useState(false);
  const [showPlaylistModal, setShowPlaylistModal] = useState(false);
  const [showSpeedMenu, setShowSpeedMenu] = useState(false);
  const [showSleepMenu, setShowSleepMenu] = useState(false);

  if (!currentSong) return null;

  const isFav = isFavorite(currentSong.id);
  const isDown = isDownloaded(currentSong.id);

  const formatTime = (seconds: number) => {
    if (isNaN(seconds) || seconds < 0) return '00:00';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  const progressPercent = duration > 0 ? (currentTime / duration) * 100 : 0;

  return (
    <>
      {/* Mini Player Bar (Docked at bottom above navigation) */}
      <div className="fixed bottom-16 md:bottom-0 left-0 md:left-64 right-0 h-20 bg-slate-900/95 backdrop-blur-2xl border-t border-white/10 px-4 md:px-8 flex items-center justify-between z-30 select-none shadow-2xl">
        {/* Progress Bar (at top edge of mini player) */}
        <div
          onClick={(e) => {
            const rect = e.currentTarget.getBoundingClientRect();
            const pos = (e.clientX - rect.left) / rect.width;
            seekTo(pos * duration);
          }}
          className="absolute top-0 left-0 right-0 h-1 bg-white/10 cursor-pointer group hover:h-2 transition-all"
        >
          <div
            className="h-full bg-gradient-to-r from-indigo-500 via-purple-500 to-rose-500 relative transition-all"
            style={{ width: `${progressPercent}%` }}
          >
            <div className="absolute right-0 top-1/2 -translate-y-1/2 w-3 h-3 rounded-full bg-white opacity-0 group-hover:opacity-100 shadow-md transform translate-x-1/2 transition-opacity" />
          </div>
        </div>

        {/* Left: Song Info */}
        <div className="flex items-center gap-3.5 min-w-0 max-w-[45%] md:max-w-[30%]">
          <div
            onClick={() => setIsExpanded(true)}
            className="w-12 h-12 rounded-xl overflow-hidden relative cursor-pointer group shrink-0 bg-slate-800 shadow-md"
          >
            <img
              src={currentSong.thumbnailUrl}
              alt={currentSong.title}
              className={`w-full h-full object-cover group-hover:scale-105 transition-transform ${
                isPlaying ? 'animate-pulse' : ''
              }`}
            />
          </div>

          <div
            onClick={() => setIsExpanded(true)}
            className="min-w-0 cursor-pointer"
          >
            <h4 className="text-sm font-bold text-white truncate hover:underline">{currentSong.title}</h4>
            <p className="text-xs text-slate-400 truncate">{currentSong.artist}</p>
          </div>

          <button
            onClick={() => toggleFavorite(currentSong)}
            className={`p-1.5 rounded-full hover:bg-white/10 transition-colors shrink-0 ${
              isFav ? 'text-rose-500' : 'text-slate-400 hover:text-white'
            }`}
          >
            <Heart className={`w-4 h-4 ${isFav ? 'fill-rose-500' : ''}`} />
          </button>
        </div>

        {/* Center: Playback Controls */}
        <div className="flex flex-col items-center gap-1">
          <div className="flex items-center gap-2 md:gap-4">
            <button
              onClick={toggleShuffle}
              className={`p-2 rounded-full hidden sm:block transition-colors ${
                isShuffle ? 'text-indigo-400 bg-indigo-500/10' : 'text-slate-400 hover:text-white'
              }`}
            >
              <Shuffle className="w-4 h-4" />
            </button>

            <button
              onClick={prevSong}
              className="p-2 rounded-full text-slate-300 hover:text-white hover:bg-white/5 transition-colors"
            >
              <SkipBack className="w-5 h-5 fill-current" />
            </button>

            <button
              onClick={() => (isPlaying ? pauseSong() : resumeSong())}
              disabled={isLoading}
              className="w-11 h-11 rounded-full bg-white text-slate-950 flex items-center justify-center hover:scale-105 active:scale-95 transition-all shadow-lg shadow-white/10"
            >
              {isLoading ? (
                <div className="w-5 h-5 border-2 border-slate-900 border-t-transparent rounded-full animate-spin" />
              ) : isPlaying ? (
                <Pause className="w-5 h-5 fill-slate-950" />
              ) : (
                <Play className="w-5 h-5 fill-slate-950 translate-x-0.5" />
              )}
            </button>

            <button
              onClick={nextSong}
              className="p-2 rounded-full text-slate-300 hover:text-white hover:bg-white/5 transition-colors"
            >
              <SkipForward className="w-5 h-5 fill-current" />
            </button>

            <button
              onClick={toggleRepeat}
              className={`p-2 rounded-full hidden sm:block transition-colors ${
                isRepeat ? 'text-indigo-400 bg-indigo-500/10' : 'text-slate-400 hover:text-white'
              }`}
            >
              <Repeat className="w-4 h-4" />
            </button>
          </div>

          <div className="hidden sm:flex items-center gap-2 text-[10px] text-slate-400 font-mono">
            <span>{formatTime(currentTime)}</span>
            <span>/</span>
            <span>{formatTime(duration)}</span>
          </div>
        </div>

        {/* Right: Actions & Volume */}
        <div className="flex items-center gap-2">
          <button
            onClick={() => setShowLyrics(true)}
            className="p-2 rounded-full text-slate-400 hover:text-white hover:bg-white/5 transition-colors hidden lg:block"
            title="Lyrics"
          >
            <FileText className="w-4 h-4" />
          </button>

          <button
            onClick={() => setShowQueue(true)}
            className="p-2 rounded-full text-slate-400 hover:text-white hover:bg-white/5 transition-colors"
            title="Queue"
          >
            <ListMusic className="w-5 h-5" />
          </button>

          <div className="hidden md:flex items-center gap-2 pl-2">
            <button
              onClick={() => setVolume(volume === 0 ? 0.8 : 0)}
              className="text-slate-400 hover:text-white transition-colors"
            >
              {volume === 0 ? <VolumeX className="w-4 h-4" /> : <Volume2 className="w-4 h-4" />}
            </button>
            <input
              type="range"
              min="0"
              max="1"
              step="0.01"
              value={volume}
              onChange={(e) => setVolume(parseFloat(e.target.value))}
              className="w-20 h-1 bg-white/20 rounded-lg appearance-none cursor-pointer accent-indigo-500"
            />
          </div>

          <button
            onClick={() => setIsExpanded(true)}
            className="p-2 rounded-full text-slate-400 hover:text-white hover:bg-white/5 md:hidden"
          >
            <ChevronDown className="w-5 h-5 rotate-180" />
          </button>
        </div>
      </div>

      {/* Full Screen Immersive Player Modal */}
      {isExpanded && (
        <div className="fixed inset-0 z-50 bg-slate-950/98 backdrop-blur-3xl flex flex-col p-6 md:p-12 overflow-y-auto animate-in slide-in-from-bottom duration-300">
          {/* Header */}
          <div className="flex items-center justify-between pb-4 max-w-xl mx-auto w-full">
            <button
              onClick={() => setIsExpanded(false)}
              className="p-2 rounded-full hover:bg-white/10 text-slate-400 hover:text-white"
            >
              <ChevronDown className="w-6 h-6" />
            </button>

            <div className="text-center">
              <span className="text-[10px] uppercase font-bold tracking-widest text-indigo-400">Playing From Mix</span>
              <p className="text-xs font-semibold text-white">Twilight Studio Master</p>
            </div>

            <button
              onClick={() => setShowPlaylistModal(true)}
              className="p-2 rounded-full hover:bg-white/10 text-slate-400 hover:text-white"
              title="Add to Playlist"
            >
              <Plus className="w-6 h-6" />
            </button>
          </div>

          {/* Center Stage: Artwork & Details */}
          <div className="flex-1 flex flex-col items-center justify-center max-w-md mx-auto w-full py-6">
            <div className="w-64 h-64 sm:w-80 sm:h-80 rounded-3xl overflow-hidden shadow-2xl relative group bg-slate-900 border border-white/10 mb-8">
              <img
                src={currentSong.thumbnailUrl}
                alt={currentSong.title}
                className="w-full h-full object-cover"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/80 via-transparent to-transparent opacity-60" />
              <div className="absolute bottom-4 left-4 right-4 flex items-center justify-between">
                <span className="text-[11px] font-semibold px-2.5 py-1 rounded-full bg-black/60 backdrop-blur-md text-emerald-400 border border-emerald-500/20">
                  {audioQuality}
                </span>
                <span className="text-[11px] text-slate-300 font-mono bg-black/60 px-2 py-0.5 rounded-full">
                  YouTube Audio
                </span>
              </div>
            </div>

            {/* Song Meta & Favorite */}
            <div className="w-full flex items-center justify-between mb-6">
              <div className="min-w-0 pr-4">
                <h2 className="text-xl sm:text-2xl font-black text-white truncate">{currentSong.title}</h2>
                <p className="text-sm font-medium text-indigo-400 truncate mt-0.5">{currentSong.artist}</p>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => (isDown ? null : downloadSong(currentSong))}
                  className={`p-2.5 rounded-full hover:bg-white/10 transition-colors ${
                    isDown ? 'text-emerald-400 bg-emerald-500/10' : 'text-slate-400 hover:text-white'
                  }`}
                  title={isDown ? 'Downloaded Offline' : 'Save Offline'}
                >
                  {isDown ? <Check className="w-5 h-5" /> : <Download className="w-5 h-5" />}
                </button>

                <button
                  onClick={() => toggleFavorite(currentSong)}
                  className={`p-2.5 rounded-full hover:bg-white/10 transition-colors ${
                    isFav ? 'text-rose-500 bg-rose-500/10' : 'text-slate-400 hover:text-white'
                  }`}
                >
                  <Heart className={`w-6 h-6 ${isFav ? 'fill-rose-500' : ''}`} />
                </button>
              </div>
            </div>

            {/* Interactive Progress Bar */}
            <div className="w-full space-y-1.5 mb-6">
              <div
                onClick={(e) => {
                  const rect = e.currentTarget.getBoundingClientRect();
                  const pos = (e.clientX - rect.left) / rect.width;
                  seekTo(pos * duration);
                }}
                className="h-2 bg-white/10 rounded-full cursor-pointer relative overflow-hidden group hover:h-3 transition-all"
              >
                <div
                  className="h-full bg-gradient-to-r from-indigo-500 via-purple-500 to-rose-500"
                  style={{ width: `${progressPercent}%` }}
                />
              </div>
              <div className="flex justify-between text-xs text-slate-400 font-mono">
                <span>{formatTime(currentTime)}</span>
                <span>{formatTime(duration)}</span>
              </div>
            </div>

            {/* Main Controls */}
            <div className="w-full flex items-center justify-between mb-8">
              <button
                onClick={toggleShuffle}
                className={`p-3 rounded-full transition-colors ${
                  isShuffle ? 'text-indigo-400 bg-indigo-500/20' : 'text-slate-400 hover:text-white'
                }`}
              >
                <Shuffle className="w-5 h-5" />
              </button>

              <button
                onClick={prevSong}
                className="p-3 rounded-full text-slate-200 hover:text-white hover:bg-white/5 transition-transform active:scale-95"
              >
                <SkipBack className="w-7 h-7 fill-current" />
              </button>

              <button
                onClick={() => (isPlaying ? pauseSong() : resumeSong())}
                disabled={isLoading}
                className="w-16 h-16 rounded-full bg-white text-slate-950 flex items-center justify-center hover:scale-105 active:scale-95 transition-all shadow-xl shadow-white/20"
              >
                {isLoading ? (
                  <div className="w-7 h-7 border-3 border-slate-900 border-t-transparent rounded-full animate-spin" />
                ) : isPlaying ? (
                  <Pause className="w-7 h-7 fill-slate-950" />
                ) : (
                  <Play className="w-7 h-7 fill-slate-950 translate-x-1" />
                )}
              </button>

              <button
                onClick={nextSong}
                className="p-3 rounded-full text-slate-200 hover:text-white hover:bg-white/5 transition-transform active:scale-95"
              >
                <SkipForward className="w-7 h-7 fill-current" />
              </button>

              <button
                onClick={toggleRepeat}
                className={`p-3 rounded-full transition-colors ${
                  isRepeat ? 'text-indigo-400 bg-indigo-500/20' : 'text-slate-400 hover:text-white'
                }`}
              >
                <Repeat className="w-5 h-5" />
              </button>
            </div>

            {/* Bottom Sheet Action Bar (Speed, Sleep Timer, Lyrics, Queue) */}
            <div className="w-full flex items-center justify-around pt-4 border-t border-white/10 text-xs text-slate-400">
              <button
                onClick={() => setShowLyrics(true)}
                className="flex flex-col items-center gap-1 hover:text-white"
              >
                <FileText className="w-5 h-5" />
                <span>Lyrics</span>
              </button>

              <button
                onClick={() => setShowQueue(true)}
                className="flex flex-col items-center gap-1 hover:text-white"
              >
                <ListMusic className="w-5 h-5" />
                <span>Queue</span>
              </button>

              {/* Speed Controller */}
              <div className="relative">
                <button
                  onClick={() => setShowSpeedMenu(!showSpeedMenu)}
                  className="flex flex-col items-center gap-1 hover:text-white"
                >
                  <Sparkles className="w-5 h-5" />
                  <span>{playbackSpeed}x</span>
                </button>
                {showSpeedMenu && (
                  <div className="absolute bottom-12 left-1/2 -translate-x-1/2 bg-slate-900 border border-white/15 rounded-2xl p-2 shadow-2xl space-y-1 w-24 text-center z-50">
                    {[0.75, 1.0, 1.25, 1.5, 2.0].map((s) => (
                      <button
                        key={s}
                        onClick={() => {
                          setPlaybackSpeed(s);
                          setShowSpeedMenu(false);
                        }}
                        className={`w-full py-1 text-xs rounded-lg ${
                          playbackSpeed === s ? 'bg-indigo-600 text-white font-bold' : 'hover:bg-white/10'
                        }`}
                      >
                        {s}x
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {/* Sleep Timer */}
              <div className="relative">
                <button
                  onClick={() => setShowSleepMenu(!showSleepMenu)}
                  className={`flex flex-col items-center gap-1 hover:text-white ${
                    sleepTimerRemaining ? 'text-indigo-400 font-bold' : ''
                  }`}
                >
                  <Clock className="w-5 h-5" />
                  <span>
                    {sleepTimerRemaining ? `${Math.ceil(sleepTimerRemaining / 60)}m` : 'Timer'}
                  </span>
                </button>
                {showSleepMenu && (
                  <div className="absolute bottom-12 right-0 bg-slate-900 border border-white/15 rounded-2xl p-2 shadow-2xl space-y-1 w-32 text-center z-50">
                    <button
                      onClick={() => {
                        setSleepTimer(null);
                        setShowSleepMenu(false);
                      }}
                      className="w-full py-1 text-xs rounded-lg hover:bg-white/10 text-slate-400"
                    >
                      Turn Off
                    </button>
                    {[15, 30, 45, 60].map((mins) => (
                      <button
                        key={mins}
                        onClick={() => {
                          setSleepTimer(mins);
                          setShowSleepMenu(false);
                        }}
                        className="w-full py-1 text-xs rounded-lg hover:bg-indigo-600 hover:text-white"
                      >
                        {mins} minutes
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Modals & Drawers */}
      <LyricsModal song={currentSong} isOpen={showLyrics} onClose={() => setShowLyrics(false)} />
      <QueueDrawer isOpen={showQueue} onClose={() => setShowQueue(false)} />
      <PlaylistModal song={currentSong} isOpen={showPlaylistModal} onClose={() => setShowPlaylistModal(false)} />
    </>
  );
};
