"use client";
import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'motion/react';
import { Plus, Folder, Download, Play, Settings, Terminal, Search, Library, Star, Cpu, Gamepad2, RefreshCw } from 'lucide-react';
import Image from 'next/image';

type Game = {
  id: string;
  title: string;
  image: string;
  exePath: string;
  is_favorite: boolean;
  proton_version: string;
};

const AVAILABLE_PROTONS = [
  { name: 'GE-Proton8-25', url: 'https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton8-25/GE-Proton8-25.tar.gz' },
{ name: 'GE-Proton8-24', url: 'https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton8-24/GE-Proton8-24.tar.gz' },
{ name: 'GE-Proton7-43', url: 'https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton7-43/GE-Proton7-43.tar.gz' }
];

export default function ScreenUI() {
  const [games, setGames] = useState<Game[]>([]);
  const [protonVersions, setProtonVersions] = useState<string[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [isAddingGame, setIsAddingGame] = useState(false);
  const [installStep, setInstallStep] = useState(0);
  const [newGameName, setNewGameName] = useState('');
  const [newGameExePath, setNewGameExePath] = useState<string>('');
  const [selectedProton, setSelectedProton] = useState<string>('');
  const [isTauri, setIsTauri] = useState(false);
  const [activeTab, setActiveTab] = useState('library');
  const [isDownloadingProton, setIsDownloadingProton] = useState<string | null>(null);
  const [isScanningSteam, setIsScanningSteam] = useState(false);

  useEffect(() => {
    const checkTauri = typeof window !== 'undefined' && '__TAURI__' in window;
    setIsTauri(checkTauri);
    if (checkTauri) {
      loadData();
    }
  }, []);

  const loadData = async () => {
    try {
      const { invoke } = await import('@tauri-apps/api/tauri');
      const loadedGames: Game[] = await invoke('load_games');
      setGames(loadedGames);
      const versions: string[] = await invoke('get_proton_versions');
      setProtonVersions(versions);
      if (versions.length > 0) setSelectedProton(versions[0]);
    } catch (e) {
      console.error("Failed to load data", e);
    }
  };

  const saveGames = async (newGames: Game[]) => {
    setGames(newGames);
    if (isTauri) {
      try {
        const { invoke } = await import('@tauri-apps/api/tauri');
        await invoke('save_games', { games: newGames });
      } catch (e) {
        console.error("Failed to save games", e);
      }
    }
  };

  const handleSelectExe = async () => {
    if (isTauri) {
      const { open } = await import('@tauri-apps/api/dialog');
      const selected = await open({
        filters: [{ name: 'Executable', extensions: ['exe'] }],
        multiple: false,
      });
      if (selected && typeof selected === 'string') {
        setNewGameExePath(selected);
      }
    } else {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = '.exe';
      input.onchange = (e) => {
        const file = (e.target as HTMLInputElement).files?.[0];
        if (file) setNewGameExePath(file.name);
      };
        input.click();
    }
  };

  const handleInstall = async () => {
    if (!newGameName || !newGameExePath || !selectedProton) return;

    setInstallStep(1);
    if (isTauri) {
      const { invoke } = await import('@tauri-apps/api/tauri');
      try {
        await invoke('create_prefix', { gameName: newGameName, protonVersion: selectedProton });
      } catch (e) {
        console.error(e);
      }
    } else {
      await new Promise(r => setTimeout(r, 2000));
    }

    setInstallStep(2);
    await new Promise(r => setTimeout(r, 1000));

    const newGame: Game = {
      id: Date.now().toString(),
      title: newGameName,
      image: `https://picsum.photos/seed/${newGameName.replace(/\s/g, '')}/400/600`,
      exePath: newGameExePath,
      is_favorite: false,
      proton_version: selectedProton,
    };

    await saveGames([...games, newGame]);
    setIsAddingGame(false);
    setInstallStep(0);
    setNewGameName('');
    setNewGameExePath('');
  };

  const handlePlayGame = async (game: Game) => {
    if (isTauri && game.exePath) {
      const { invoke } = await import('@tauri-apps/api/tauri');
      try {
        await invoke('run_game', { gameName: game.title, exePath: game.exePath, protonVersion: game.proton_version });
      } catch (e) {
        console.error(e);
      }
    } else {
      console.log(`Simulating running game: ${game.title}`);
    }
  };

  const toggleFavorite = async (gameId: string) => {
    const updated = games.map(g => g.id === gameId ? { ...g, is_favorite: !g.is_favorite } : g);
    await saveGames(updated);
  };

  const handleScanSteam = async () => {
    if (!isTauri) return;
    setIsScanningSteam(true);
    try {
      const { invoke } = await import('@tauri-apps/api/tauri');
      const steamGames: Game[] = await invoke('scan_steam_games');

      const existingTitles = new Set(games.map(g => g.title));
      const newGames = steamGames.filter(g => !existingTitles.has(g.title));

      if (newGames.length > 0) {
        await saveGames([...games, ...newGames]);
      }
    } catch (e) {
      console.error(e);
    }
    setIsScanningSteam(false);
  };

  const handleDownloadProton = async (proton: typeof AVAILABLE_PROTONS[0]) => {
    if (!isTauri) return;
    setIsDownloadingProton(proton.name);
    try {
      const { invoke } = await import('@tauri-apps/api/tauri');
      await invoke('download_proton', { versionUrl: proton.url, versionName: proton.name });
      await loadData();
    } catch (e) {
      console.error(e);
    }
    setIsDownloadingProton(null);
  };

  const filteredGames = games.filter(g => {
    if (activeTab === 'favorites' && !g.is_favorite) return false;
    return g.title.toLowerCase().includes(searchQuery.toLowerCase());
  });

  return (
    <div className="w-full h-full bg-[#050510] text-white flex font-sans overflow-hidden">
    {/* Sidebar */}
    <div className="w-64 bg-[#0a0f1c] border-r border-blue-900/30 flex flex-col z-20">
    <div className="p-6 flex items-center gap-3 text-blue-400">
    <Terminal className="w-8 h-8" />
    <h1 className="text-2xl font-vt323 tracking-widest uppercase" style={{ textShadow: '0 0 10px rgba(96,165,250,0.5)' }}>HackerDeck</h1>
    </div>

    <nav className="flex-1 px-4 space-y-2 mt-4">
    <button
    onClick={() => setActiveTab('library')}
    className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all ${activeTab === 'library' ? 'bg-blue-600/20 text-blue-400 border border-blue-500/30 shadow-[inset_0_0_20px_rgba(37,99,235,0.1)]' : 'text-gray-400 hover:bg-white/5 hover:text-gray-200'}`}
    >
    <Library className="w-5 h-5" />
    <span className="font-medium">All Games</span>
    </button>
    <button
    onClick={() => setActiveTab('favorites')}
    className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all ${activeTab === 'favorites' ? 'bg-blue-600/20 text-blue-400 border border-blue-500/30 shadow-[inset_0_0_20px_rgba(37,99,235,0.1)]' : 'text-gray-400 hover:bg-white/5 hover:text-gray-200'}`}
    >
    <Star className="w-5 h-5" />
    <span className="font-medium">Favorites</span>
    </button>
    <button
    onClick={() => setActiveTab('runners')}
    className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl transition-all ${activeTab === 'runners' ? 'bg-blue-600/20 text-blue-400 border border-blue-500/30 shadow-[inset_0_0_20px_rgba(37,99,235,0.1)]' : 'text-gray-400 hover:bg-white/5 hover:text-gray-200'}`}
    >
    <Cpu className="w-5 h-5" />
    <span className="font-medium">Proton Versions</span>
    </button>
    </nav>
    </div>

    {/* Main Content */}
    <div className="flex-1 flex flex-col relative z-10">
    <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-blue-600/10 blur-[120px] rounded-full pointer-events-none" />

    {/* Top Bar */}
    <div className="h-20 border-b border-blue-900/30 flex items-center justify-between px-8 relative z-10 bg-[#050510]/50 backdrop-blur-md">
    <div className="relative w-96">
    <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-500" />
    <input
    type="text"
    placeholder="Search games..."
    value={searchQuery}
    onChange={(e) => setSearchQuery(e.target.value)}
    className="w-full bg-black/40 border border-blue-900/50 rounded-full pl-10 pr-4 py-2.5 text-sm focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500 transition-all text-gray-200 placeholder-gray-500"
    />
    </div>

    <button
    onClick={() => setIsAddingGame(true)}
    className="flex items-center gap-2 bg-blue-600 hover:bg-blue-500 text-white px-5 py-2.5 rounded-full font-medium transition-all shadow-[0_0_20px_rgba(37,99,235,0.3)] hover:shadow-[0_0_30px_rgba(37,99,235,0.5)]"
    >
    <Plus className="w-5 h-5" />
    Add Game
    </button>
    </div>

    {/* Dynamic Content based on Tab */}
    {(activeTab === 'library' || activeTab === 'favorites') && (
      <div className="flex-1 overflow-y-auto p-8 relative z-10">
      <div className="flex justify-between items-end mb-6">
      <h2 className="text-2xl font-bold text-white">
      {activeTab === 'library' ? 'All Games' : 'Favorites'}
      </h2>
      {activeTab === 'library' && (
        <button
        onClick={handleScanSteam}
        disabled={isScanningSteam}
        className="flex items-center gap-2 text-sm font-medium text-gray-400 hover:text-white transition-colors bg-white/5 px-4 py-2 rounded-lg border border-white/10 hover:border-white/20"
        >
        <RefreshCw className={`w-4 h-4 ${isScanningSteam ? 'animate-spin' : ''}`} />
        Import from Steam
        </button>
      )}
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5 gap-6">
      {filteredGames.map((game) => (
        <motion.div
        key={game.id}
        layout
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="group relative aspect-[2/3] rounded-xl overflow-hidden bg-gray-900 border border-blue-900/30 hover:border-blue-500/50 transition-colors shadow-lg"
        >
        <Image src={game.image} alt={game.title} fill className="object-cover transition-transform duration-500 group-hover:scale-105" />

        <button
        onClick={(e) => { e.stopPropagation(); toggleFavorite(game.id); }}
        className="absolute top-3 right-3 z-20 p-2 rounded-full bg-black/50 backdrop-blur-md border border-white/10 opacity-0 group-hover:opacity-100 transition-opacity hover:bg-black/70"
        >
        <Star className={`w-4 h-4 ${game.is_favorite ? 'fill-yellow-400 text-yellow-400' : 'text-white'}`} />
        </button>

        <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/40 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex flex-col justify-end p-4">
        <h3 className="font-bold text-lg text-white mb-1 translate-y-4 group-hover:translate-y-0 transition-transform duration-300">{game.title}</h3>
        <p className="text-xs text-blue-300 mb-4 translate-y-4 group-hover:translate-y-0 transition-transform duration-300 delay-75">{game.proton_version || 'Native/Steam'}</p>
        <div className="flex gap-2 translate-y-4 group-hover:translate-y-0 transition-transform duration-300 delay-100">
        <button
        onClick={() => handlePlayGame(game)}
        className="flex-1 bg-green-500 hover:bg-green-400 text-black font-bold py-2 rounded-lg flex items-center justify-center gap-2 transition-colors"
        >
        <Play className="w-4 h-4 fill-current" /> Play
        </button>
        </div>
        </div>
        </motion.div>
      ))}
      </div>
      {filteredGames.length === 0 && (
        <div className="flex flex-col items-center justify-center h-64 text-gray-500">
        <Gamepad2 className="w-16 h-16 mb-4 opacity-50" />
        <p className="text-lg">No games found</p>
        {activeTab === 'library' && (
          <p className="text-sm mt-2">Click "Add Game" or "Import from Steam" to get started.</p>
        )}
        </div>
      )}
      </div>
    )}

    {activeTab === 'runners' && (
      <div className="flex-1 overflow-y-auto p-8 relative z-10">
      <div className="max-w-4xl mx-auto w-full">
      <h2 className="text-2xl font-bold mb-6">Proton Versions</h2>

      <div className="mb-8">
      <h3 className="text-lg font-semibold text-blue-400 mb-4">Installed Versions</h3>
      {protonVersions.length === 0 ? (
        <p className="text-gray-500 bg-black/30 p-4 rounded-lg border border-white/5">No Proton versions installed yet.</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {protonVersions.map(v => (
          <div key={v} className="bg-blue-900/20 border border-blue-500/30 p-4 rounded-xl flex items-center gap-3">
          <Cpu className="w-6 h-6 text-blue-400" />
          <span className="font-medium">{v}</span>
          </div>
        ))}
        </div>
      )}
      </div>

      <div>
      <h3 className="text-lg font-semibold text-purple-400 mb-4">Available to Download</h3>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      {AVAILABLE_PROTONS.map(p => {
        const isInstalled = protonVersions.includes(p.name);
        const isDownloading = isDownloadingProton === p.name;
        return (
          <div key={p.name} className="bg-black/40 border border-white/10 p-4 rounded-xl flex items-center justify-between">
          <div className="flex items-center gap-3">
          <Download className="w-5 h-5 text-gray-400" />
          <span className="font-medium text-gray-200">{p.name}</span>
          </div>
          {isInstalled ? (
            <span className="text-xs font-bold text-green-500 bg-green-500/10 px-3 py-1 rounded-full">INSTALLED</span>
          ) : (
            <button
            onClick={() => handleDownloadProton(p)}
            disabled={isDownloading || isDownloadingProton !== null}
            className="text-xs font-bold bg-purple-600 hover:bg-purple-500 text-white px-4 py-2 rounded-lg transition-colors disabled:opacity-50 flex items-center gap-2"
            >
            {isDownloading ? <RefreshCw className="w-3 h-3 animate-spin" /> : null}
            {isDownloading ? 'DOWNLOADING...' : 'DOWNLOAD'}
            </button>
          )}
          </div>
        );
      })}
      </div>
      </div>
      </div>
      </div>
    )}
    </div>

    {/* Add Game Modal */}
    <AnimatePresence>
    {isAddingGame && (
      <motion.div
      initial={{ opacity: 0, backdropFilter: 'blur(0px)' }}
      animate={{ opacity: 1, backdropFilter: 'blur(8px)' }}
      exit={{ opacity: 0, backdropFilter: 'blur(0px)' }}
      className="absolute inset-0 bg-black/60 z-50 flex items-center justify-center p-4 md:p-8"
      >
      <motion.div
      initial={{ scale: 0.9, y: 20 }}
      animate={{ scale: 1, y: 0 }}
      exit={{ scale: 0.9, y: 20 }}
      className="bg-[#0a0f1c] border border-blue-500/30 rounded-2xl p-6 md:p-8 max-w-md w-full shadow-[0_0_50px_rgba(0,0,0,0.8)]"
      >
      <h3 className="text-xl font-bold mb-6 text-blue-400 flex items-center gap-2">
      <Settings className="w-5 h-5" /> Install Windows Game
      </h3>

      {installStep === 0 && (
        <div className="space-y-4">
        <div>
        <label className="block text-xs text-blue-200/70 mb-1 uppercase tracking-wider">Game Title</label>
        <input
        type="text"
        value={newGameName}
        onChange={(e) => setNewGameName(e.target.value)}
        placeholder="e.g. Cyberpunk 2077"
        className="w-full bg-black/50 border border-blue-900/50 rounded-lg px-4 py-2 text-sm focus:outline-none focus:border-blue-500 transition-colors text-white"
        />
        </div>
        <div>
        <label className="block text-xs text-blue-200/70 mb-1 uppercase tracking-wider">Executable File (.exe)</label>
        <div className="relative flex items-center gap-2">
        <button
        onClick={handleSelectExe}
        className="bg-blue-600 hover:bg-blue-500 text-white text-xs font-bold py-2 px-4 rounded-md transition-colors"
        >
        BROWSE
        </button>
        <span className="text-xs text-gray-400 truncate max-w-[200px]" title={newGameExePath}>
        {newGameExePath || 'No file selected'}
        </span>
        </div>
        </div>
        <div>
        <label className="block text-xs text-blue-200/70 mb-1 uppercase tracking-wider">Proton Version</label>
        <select
        value={selectedProton}
        onChange={(e) => setSelectedProton(e.target.value)}
        className="w-full bg-black/50 border border-blue-900/50 rounded-lg px-4 py-2 text-sm focus:outline-none focus:border-blue-500 transition-colors text-white appearance-none"
        >
        {protonVersions.length === 0 ? (
          <option value="">No Proton versions installed</option>
        ) : (
          protonVersions.map(v => (
            <option key={v} value={v}>{v}</option>
          ))
        )}
        </select>
        {protonVersions.length === 0 && (
          <p className="text-[10px] text-red-400 mt-1">Please install a Proton version from the Proton tab first.</p>
        )}
        </div>
        <div className="flex justify-end gap-3 mt-8">
        <button
        onClick={() => setIsAddingGame(false)}
        className="px-5 py-2 rounded-lg text-sm font-bold text-gray-400 hover:text-white hover:bg-white/5 transition-colors"
        >
        CANCEL
        </button>
        <button
        onClick={handleInstall}
        disabled={!newGameName || !newGameExePath || !selectedProton}
        className="px-5 py-2 rounded-lg text-sm font-bold bg-blue-600 text-white hover:bg-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors shadow-[0_0_15px_rgba(37,99,235,0.5)]"
        >
        INSTALL PROTON
        </button>
        </div>
        </div>
      )}

      {installStep === 1 && (
        <div className="flex flex-col items-center justify-center py-8 space-y-6">
        <div className="relative">
        <div className="absolute inset-0 bg-blue-500 blur-xl opacity-20 rounded-full animate-pulse" />
        <Folder className="w-16 h-16 text-blue-400 relative z-10" />
        </div>
        <div className="text-center w-full">
        <p className="font-bold text-lg text-blue-100">Creating Wine Prefix...</p>
        <div className="bg-black/50 p-3 rounded-lg mt-3 border border-white/5">
        <p className="text-[10px] text-green-400 font-mono break-all text-left">
        $ mkdir -p ~/.hackeros/HackerDeck/Prefix/{newGameName.replace(/\s/g, '')} <br/>
        $ WINEPREFIX=... wineboot --init <br/>
        <span className="animate-pulse">_</span>
        </p>
        </div>
        </div>
        <div className="w-full h-1.5 bg-gray-900 rounded-full overflow-hidden mt-4">
        <motion.div
        className="h-full bg-blue-500 shadow-[0_0_10px_rgba(59,130,246,0.8)]"
        initial={{ width: 0 }}
        animate={{ width: "100%" }}
        transition={{ duration: 2, ease: "linear" }}
        />
        </div>
        </div>
      )}

      {installStep === 2 && (
        <div className="flex flex-col items-center justify-center py-8 space-y-4">
        <motion.div
        initial={{ scale: 0 }}
        animate={{ scale: 1 }}
        transition={{ type: "spring", bounce: 0.5 }}
        >
        <Play className="w-16 h-16 text-green-400 drop-shadow-[0_0_15px_rgba(74,222,128,0.5)]" />
        </motion.div>
        <div className="text-center">
        <p className="font-bold text-xl text-white">Ready to Play!</p>
        <p className="text-sm text-blue-200/70 mt-2">{newGameName} has been configured with Proton.</p>
        </div>
        </div>
      )}
      </motion.div>
      </motion.div>
    )}
    </AnimatePresence>
    </div>
  );
}
