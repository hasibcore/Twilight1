import React, { useState } from 'react';
import { Heart, ListMusic, History, Download, Play, Plus, Trash2, ArrowRight } from 'lucide-react';
import { useMusic } from '../context/MusicContext';
import { Playlist, Song } from '../types';

export const LibraryScreen: React.FC = () => {
  const {
    favorites,
    playlists,
    history,
    downloads,
    playSong,
    deletePlaylist,
    createPlaylist,
  } = useMusic();

  const [activeTab, setActiveTab] = useState<'favorites' | 'playlists' | 'history' | 'downloads'>('favorites');
  const [selectedPlaylist, setSelectedPlaylist] = useState<Playlist | null>(null);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [newTitle, setNewTitle] = useState('');
  const [newDesc, setNewDesc] = useState('');

  const handleCreate = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTitle.trim()) return;
    createPlaylist(newTitle.trim(), newDesc.trim());
    setNewTitle('');
    setNewDesc('');
    setShowCreateModal(false);
  };

  return (
    <div className="space-y-6 pb-12">
      <div>
        <span className="text-xs uppercase font-extrabold tracking-widest text-indigo-400">
          YOUR COLLECTION
        </span>
        <h1 className="text-2xl sm:text-4xl font-black text-white tracking-tight mt-0.5">
          Library & Playlists
        </h1>
      </div>

      {/* Tabs */}
      <div className="flex items-center gap-2 overflow-x-auto pb-2 scrollbar-none border-b border-white/10">
        <button
          onClick={() => {
            setActiveTab('favorites');
            setSelectedPlaylist(null);
          }}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-bold transition-all ${
            activeTab === 'favorites' && !selectedPlaylist
              ? 'bg-rose-500 text-white shadow-lg shadow-rose-500/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          <Heart className="w-4 h-4" />
          <span>Favorites ({favorites.length})</span>
        </button>

        <button
          onClick={() => {
            setActiveTab('playlists');
            setSelectedPlaylist(null);
          }}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-bold transition-all ${
            activeTab === 'playlists' || selectedPlaylist
              ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          <ListMusic className="w-4 h-4" />
          <span>Playlists ({playlists.length})</span>
        </button>

        <button
          onClick={() => {
            setActiveTab('history');
            setSelectedPlaylist(null);
          }}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-bold transition-all ${
            activeTab === 'history' && !selectedPlaylist
              ? 'bg-purple-600 text-white shadow-lg shadow-purple-600/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          <History className="w-4 h-4" />
          <span>History ({history.length})</span>
        </button>

        <button
          onClick={() => {
            setActiveTab('downloads');
            setSelectedPlaylist(null);
          }}
          className={`flex items-center gap-2 px-4 py-2.5 rounded-2xl text-xs font-bold transition-all ${
            activeTab === 'downloads' && !selectedPlaylist
              ? 'bg-emerald-600 text-white shadow-lg shadow-emerald-600/25'
              : 'text-slate-400 hover:text-white hover:bg-white/5'
          }`}
        >
          <Download className="w-4 h-4" />
          <span>Offline ({downloads.length})</span>
        </button>
      </div>

      {/* Selected Playlist Detailed View */}
      {selectedPlaylist ? (
        <div className="space-y-6">
          <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 p-6 rounded-3xl bg-gradient-to-r from-indigo-950/40 via-purple-950/40 to-slate-900 border border-indigo-500/20">
            <div className="flex items-center gap-4">
              <div className="w-20 h-20 rounded-2xl overflow-hidden bg-slate-800 shrink-0">
                <img
                  src={selectedPlaylist.thumbnailUrl}
                  alt={selectedPlaylist.title}
                  className="w-full h-full object-cover"
                />
              </div>
              <div>
                <span className="text-[10px] font-bold text-indigo-400 uppercase tracking-widest">
                  Playlist
                </span>
                <h2 className="text-xl sm:text-2xl font-black text-white">{selectedPlaylist.title}</h2>
                <p className="text-xs text-slate-400 mt-1">{selectedPlaylist.description || 'Custom collection'}</p>
                <span className="text-xs text-slate-500 mt-1 block">
                  {selectedPlaylist.songs.length} tracks
                </span>
              </div>
            </div>

            <div className="flex items-center gap-2">
              {selectedPlaylist.songs.length > 0 && (
                <button
                  onClick={() => playSong(selectedPlaylist.songs[0], selectedPlaylist.songs)}
                  className="px-5 py-2.5 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs flex items-center gap-2 shadow-lg shadow-indigo-600/30"
                >
                  <Play className="w-4 h-4 fill-white" />
                  <span>Play Playlist</span>
                </button>
              )}
              <button
                onClick={() => setSelectedPlaylist(null)}
                className="px-4 py-2.5 rounded-2xl bg-white/5 hover:bg-white/10 text-xs font-semibold text-slate-300"
              >
                Back to All
              </button>
            </div>
          </div>

          <div className="space-y-2">
            {selectedPlaylist.songs.length === 0 ? (
              <p className="text-sm text-slate-400 py-8 text-center">
                This playlist is currently empty. Use the '+' button while playing any track to add songs here!
              </p>
            ) : (
              selectedPlaylist.songs.map((song, idx) => (
                <div
                  key={`pl_song_${song.id}_${idx}`}
                  onClick={() => playSong(song, selectedPlaylist.songs)}
                  className="group flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 transition-all cursor-pointer"
                >
                  <span className="text-xs font-mono text-slate-500 w-5 text-center group-hover:text-indigo-400">
                    {idx + 1}
                  </span>
                  <img src={song.thumbnailUrl} alt={song.title} className="w-10 h-10 rounded-xl object-cover shrink-0" />
                  <div className="min-w-0 flex-1">
                    <h4 className="text-xs font-bold text-white truncate">{song.title}</h4>
                    <p className="text-[11px] text-slate-400 truncate">{song.artist}</p>
                  </div>
                  <span className="text-xs text-slate-500 font-mono shrink-0">
                    {song.durationFormatted || '03:30'}
                  </span>
                </div>
              ))
            )}
          </div>
        </div>
      ) : (
        <>
          {/* Favorites List */}
          {activeTab === 'favorites' && (
            <div className="space-y-3">
              {favorites.length === 0 ? (
                <p className="text-sm text-slate-400 py-8 text-center">
                  No favorite songs added yet. Heart any track to save it to your favorites!
                </p>
              ) : (
                favorites.map((song) => (
                  <div
                    key={`fav_${song.id}`}
                    onClick={() => playSong(song, favorites)}
                    className="group flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 transition-all cursor-pointer"
                  >
                    <img src={song.thumbnailUrl} alt={song.title} className="w-12 h-12 rounded-xl object-cover shrink-0" />
                    <div className="min-w-0 flex-1">
                      <h4 className="text-sm font-bold text-white truncate group-hover:text-rose-400">{song.title}</h4>
                      <p className="text-xs text-slate-400 truncate">{song.artist}</p>
                    </div>
                    <span className="text-xs text-slate-500 font-mono shrink-0">
                      {song.durationFormatted || '03:30'}
                    </span>
                  </div>
                ))
              )}
            </div>
          )}

          {/* Playlists Grid */}
          {activeTab === 'playlists' && (
            <div className="space-y-4">
              <div className="flex justify-end">
                <button
                  onClick={() => setShowCreateModal(true)}
                  className="flex items-center gap-2 px-4 py-2 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-md shadow-indigo-600/25"
                >
                  <Plus className="w-4 h-4" />
                  <span>Create Playlist</span>
                </button>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                {playlists.map((pl) => (
                  <div
                    key={pl.id}
                    onClick={() => setSelectedPlaylist(pl)}
                    className="group p-4 rounded-3xl bg-slate-900/60 hover:bg-slate-800/80 border border-white/5 hover:border-indigo-500/30 transition-all cursor-pointer flex flex-col justify-between"
                  >
                    <div className="flex items-center gap-3 mb-3">
                      <div className="w-14 h-14 rounded-2xl overflow-hidden bg-slate-800 shrink-0">
                        <img src={pl.thumbnailUrl} alt={pl.title} className="w-full h-full object-cover" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <h4 className="text-sm font-bold text-white truncate group-hover:text-indigo-400">{pl.title}</h4>
                        <p className="text-xs text-slate-400 line-clamp-1">{pl.description || 'Collection'}</p>
                        <span className="text-[11px] text-slate-500">{pl.songs.length} songs</span>
                      </div>
                    </div>

                    <div className="flex items-center justify-between pt-2 border-t border-white/5 text-xs">
                      <span className="text-indigo-400 font-semibold flex items-center gap-1 group-hover:translate-x-1 transition-transform">
                        <span>Open</span>
                        <ArrowRight className="w-3.5 h-3.5" />
                      </span>
                      {pl.isCustom && (
                        <button
                          onClick={(e) => {
                            e.stopPropagation();
                            deletePlaylist(pl.id);
                          }}
                          className="p-1 rounded-lg text-slate-500 hover:text-rose-400 hover:bg-rose-500/10"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* History List */}
          {activeTab === 'history' && (
            <div className="space-y-3">
              {history.length === 0 ? (
                <p className="text-sm text-slate-400 py-8 text-center">No listening history recorded yet.</p>
              ) : (
                history.map((song, idx) => (
                  <div
                    key={`hist_${song.id}_${idx}`}
                    onClick={() => playSong(song, history)}
                    className="group flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 transition-all cursor-pointer"
                  >
                    <img src={song.thumbnailUrl} alt={song.title} className="w-12 h-12 rounded-xl object-cover shrink-0" />
                    <div className="min-w-0 flex-1">
                      <h4 className="text-sm font-bold text-white truncate group-hover:text-purple-400">{song.title}</h4>
                      <p className="text-xs text-slate-400 truncate">{song.artist}</p>
                    </div>
                    <span className="text-xs text-slate-500 font-mono shrink-0">
                      {song.durationFormatted || '03:30'}
                    </span>
                  </div>
                ))
              )}
            </div>
          )}

          {/* Downloads / Offline List */}
          {activeTab === 'downloads' && (
            <div className="space-y-3">
              {downloads.length === 0 ? (
                <p className="text-sm text-slate-400 py-8 text-center">
                  No downloaded tracks yet. Click the download icon while playing any song to save it for offline playback!
                </p>
              ) : (
                downloads.map((song) => (
                  <div
                    key={`dl_${song.id}`}
                    onClick={() => playSong(song, downloads)}
                    className="group flex items-center gap-3.5 p-3 rounded-2xl bg-white/5 hover:bg-white/10 border border-white/5 transition-all cursor-pointer"
                  >
                    <img src={song.thumbnailUrl} alt={song.title} className="w-12 h-12 rounded-xl object-cover shrink-0" />
                    <div className="min-w-0 flex-1">
                      <h4 className="text-sm font-bold text-white truncate group-hover:text-emerald-400">{song.title}</h4>
                      <p className="text-xs text-slate-400 truncate">{song.artist}</p>
                    </div>
                    <span className="text-[10px] font-semibold text-emerald-400 px-2 py-0.5 rounded-full bg-emerald-500/10">
                      Offline Ready
                    </span>
                  </div>
                ))
              )}
            </div>
          )}
        </>
      )}

      {/* Create Playlist Modal */}
      {showCreateModal && (
        <div className="fixed inset-0 z-50 bg-black/75 backdrop-blur-md flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-white/10 w-full max-w-sm rounded-3xl p-6 shadow-2xl space-y-4">
            <h3 className="font-bold text-white text-base">Create New Playlist</h3>
            <form onSubmit={handleCreate} className="space-y-3">
              <input
                type="text"
                value={newTitle}
                onChange={(e) => setNewTitle(e.target.value)}
                placeholder="Playlist name..."
                autoFocus
                className="w-full px-3.5 py-2.5 rounded-xl bg-white/5 border border-white/10 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500"
              />
              <textarea
                value={newDesc}
                onChange={(e) => setNewDesc(e.target.value)}
                placeholder="Description (optional)..."
                rows={2}
                className="w-full px-3.5 py-2.5 rounded-xl bg-white/5 border border-white/10 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-indigo-500 resize-none"
              />
              <div className="flex gap-2 pt-2">
                <button
                  type="submit"
                  className="flex-1 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-xs font-semibold text-white"
                >
                  Create
                </button>
                <button
                  type="button"
                  onClick={() => setShowCreateModal(false)}
                  className="px-4 py-2.5 rounded-xl bg-white/5 text-xs text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
