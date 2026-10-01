import React from 'react';
import { Home, Compass, Search, Library, User, Download } from 'lucide-react';
import { TwilightLogo } from './TwilightLogo';

export type NavTab = 'home' | 'explore' | 'search' | 'library' | 'profile' | 'landing';

interface NavigationProps {
  currentTab: NavTab;
  onSelectTab: (tab: NavTab) => void;
}

export const Navigation: React.FC<NavigationProps> = ({ currentTab, onSelectTab }) => {
  // Mobile bottom navigation tabs (clean 5-tab layout without cramped downloads)
  const mobileNavItems: { id: NavTab; label: string; icon: React.ReactNode }[] = [
    { id: 'home', label: 'Home', icon: <Home className="w-5 h-5" /> },
    { id: 'explore', label: 'Explore', icon: <Compass className="w-5 h-5" /> },
    { id: 'search', label: 'Search', icon: <Search className="w-5 h-5" /> },
    { id: 'library', label: 'Library', icon: <Library className="w-5 h-5" /> },
    { id: 'profile', label: 'Profile', icon: <User className="w-5 h-5" /> },
  ];

  const desktopNavItems: { id: NavTab; label: string; icon: React.ReactNode }[] = [
    ...mobileNavItems,
    { id: 'landing', label: 'Download Apps', icon: <Download className="w-5 h-5" /> },
  ];

  return (
    <>
      {/* Desktop Sidebar */}
      <aside className="hidden md:flex flex-col w-64 bg-slate-900/80 backdrop-blur-xl border-r border-white/5 p-4 shrink-0 z-30 select-none">
        <div
          onClick={() => onSelectTab('home')}
          className="flex items-center gap-3 px-3 py-4 mb-4 cursor-pointer group"
        >
          <TwilightLogo size={40} className="rounded-2xl group-hover:scale-105 transition-transform" />
          <div>
            <span className="text-lg font-black tracking-tight text-white block group-hover:text-indigo-200 transition-colors">
              Twilight
            </span>
            <span className="text-xs text-indigo-400 font-semibold tracking-wider">MUSIC STREAMING</span>
          </div>
        </div>

        <nav className="space-y-1">
          {desktopNavItems.map((item) => {
            const isActive = currentTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => onSelectTab(item.id)}
                className={`w-full flex items-center gap-3.5 px-3.5 py-2.5 rounded-xl font-medium text-sm transition-all duration-200 ${
                  isActive
                    ? 'bg-indigo-600 text-white shadow-md shadow-indigo-600/25 font-semibold'
                    : 'text-slate-400 hover:text-white hover:bg-white/5'
                }`}
              >
                {item.icon}
                <span>{item.label}</span>
              </button>
            );
          })}
        </nav>

        <div className="mt-auto pt-6 border-t border-white/5 px-2">
          <div className="bg-gradient-to-br from-indigo-950/40 to-purple-950/40 border border-indigo-500/20 rounded-2xl p-3.5 text-xs text-slate-300">
            <div className="flex items-center gap-1.5 text-indigo-400 font-semibold mb-1">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
              256 kbps Audio
            </div>
            <p className="text-slate-400 text-[11px] leading-relaxed">
              High-fidelity playback with cloud sync & offline cache.
            </p>
          </div>
        </div>
      </aside>

      {/* Mobile Bottom Navigation (Clean 5-item bar with generous touch targets) */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 h-16 bg-slate-950/95 backdrop-blur-2xl border-t border-white/10 z-40 flex items-center justify-around px-2 shadow-2xl">
        {mobileNavItems.map((item) => {
          const isActive = currentTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => onSelectTab(item.id)}
              className={`flex flex-col items-center justify-center flex-1 py-1 transition-colors ${
                isActive ? 'text-indigo-400 font-bold' : 'text-slate-400 hover:text-slate-200'
              }`}
            >
              <div className={`p-1 rounded-full transition-transform ${isActive ? 'scale-110 text-indigo-400' : ''}`}>
                {item.icon}
              </div>
              <span className="text-[11px] mt-0.5 tracking-tight font-medium">{item.label}</span>
            </button>
          );
        })}
      </nav>
    </>
  );
};
