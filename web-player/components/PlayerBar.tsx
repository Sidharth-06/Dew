"use client";

import { useAudio } from "./AudioProvider";
import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
    Play,
    Pause,
    SkipForward,
    SkipBack,
    Volume2,
    VolumeX,
    ListMusic,
    ChevronUp,
    Home,
    Compass,
    User
} from "lucide-react";
import NowPlaying from "./NowPlaying";
import QueueDrawer from "./QueueDrawer";
import { motion, AnimatePresence } from "framer-motion";

function formatTime(seconds: number): string {
    if (!seconds || isNaN(seconds)) return "0:00";
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s.toString().padStart(2, "0")}`;
}

export default function PlayerBar() {
    const {
        currentSong,
        isPlaying,
        progress,
        duration,
        volume,
        togglePlay,
        seek,
        setVolume,
        skipNext,
        skipPrevious,
        playQueue,
        queueIndex,
    } = useAudio();

    const pathname = usePathname();
    const [showNowPlaying, setShowNowPlaying] = useState(false);
    const [showQueue, setShowQueue] = useState(false);
    const [isMuted, setIsMuted] = useState(false);

    if (!currentSong) {
        // Nav Pill fallback when nothing is playing (matching Image 1)
        return (
            <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-40">
                <div className="bg-white rounded-[2rem] shadow-2xl border-t-[3px] border-gray-900 border px-6 sm:px-10 py-3 flex items-center gap-8 sm:gap-16 font-kalam text-gray-500">
                    <Link href="/" className={`flex flex-col items-center gap-1 hover:text-gray-900 transition-colors ${pathname === '/' ? 'text-orange-600' : ''}`}>
                        <div className={pathname === '/' ? "bg-orange-100 p-2 rounded-xl" : "p-2"}><Home className="w-5 h-5 sm:w-6 sm:h-6" strokeWidth={pathname === '/' ? 2.5 : 2}/></div>
                        <span className={`text-xs sm:text-sm font-bold ${pathname === '/' ? 'text-gray-900' : ''}`}>Home</span>
                    </Link>
                    <Link href="/discover" className={`flex flex-col items-center gap-1 hover:text-gray-900 transition-colors ${pathname === '/discover' ? 'text-orange-600' : ''}`}>
                        <div className={pathname === '/discover' ? "bg-orange-100 p-2 rounded-xl" : "p-2"}><Compass className="w-5 h-5 sm:w-6 sm:h-6" strokeWidth={pathname === '/discover' ? 2.5 : 2}/></div>
                        <span className={`text-xs sm:text-sm font-bold ${pathname === '/discover' ? 'text-gray-900' : ''}`}>Discover</span>
                    </Link>
                    <Link href="/library" className={`flex flex-col items-center gap-1 hover:text-gray-900 transition-colors ${pathname === '/library' ? 'text-orange-600' : ''}`}>
                        <div className={pathname === '/library' ? "bg-orange-100 p-2 rounded-xl" : "p-2"}><ListMusic className="w-5 h-5 sm:w-6 sm:h-6" strokeWidth={pathname === '/library' ? 2.5 : 2}/></div>
                        <span className={`text-xs sm:text-sm font-bold ${pathname === '/library' ? 'text-gray-900' : ''}`}>Library</span>
                    </Link>
                    <Link href="/me" className={`flex flex-col items-center gap-1 hover:text-gray-900 transition-colors ${pathname === '/me' ? 'text-orange-600' : ''}`}>
                        <div className={pathname === '/me' ? "bg-orange-100 p-2 rounded-xl" : "p-2"}><User className="w-5 h-5 sm:w-6 sm:h-6" strokeWidth={pathname === '/me' ? 2.5 : 2}/></div>
                        <span className={`text-xs sm:text-sm font-bold ${pathname === '/me' ? 'text-gray-900' : ''}`}>Me</span>
                    </Link>
                </div>
            </div>
        );
    }

    const progressPercent = duration > 0 ? (progress / duration) * 100 : 0;

    return (
        <AnimatePresence>
            <motion.div
                initial={{ y: 100, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                exit={{ y: 100, opacity: 0 }}
                transition={{ type: "spring", stiffness: 300, damping: 30 }}
                className="fixed bottom-6 w-full max-w-[800px] left-1/2 -translate-x-1/2 z-40 px-4"
            >
                {/* Float Pill Player (matching Image 3) */}
                <div className="bg-white rounded-[1.5rem] shadow-2xl border border-gray-200 border-t-4 border-t-orange-500 px-4 sm:px-6 py-3 flex flex-col sm:flex-row items-center gap-4 sm:gap-6 font-kalam">
                    
                    {/* Left: Album & Info */}
                    <div 
                        className="flex items-center gap-4 flex-1 w-full min-w-0 cursor-pointer group"
                        onClick={() => setShowNowPlaying(true)}
                    >
                        <div className="w-12 h-12 bg-gray-100 rounded-md overflow-hidden flex-shrink-0 shadow-sm border border-gray-200 group-hover:scale-105 transition-transform">
                            <img src={currentSong.image} alt={currentSong.title} className="w-full h-full object-cover" />
                        </div>
                        <div className="min-w-0 flex-1">
                            <p className="text-lg font-bold text-gray-900 truncate uppercase mt-1 leading-none">{currentSong.title}</p>
                            <p className="text-sm font-caveat text-gray-500 uppercase truncate mt-1">{currentSong.artist}</p>
                        </div>
                    </div>

                    {/* Middle: Controls */}
                    <div className="flex items-center gap-4 flex-shrink-0 z-10">
                        <button onClick={skipPrevious} className="text-gray-700 hover:text-black hover:scale-110 active:scale-95 transition-all">
                            <SkipBack className="w-5 h-5" fill="currentColor" strokeWidth={1} />
                        </button>

                        <button
                            onClick={togglePlay}
                            className="w-10 h-10 flex items-center justify-center bg-orange-500 rounded-full text-white hover:scale-105 active:scale-95 transition-all shadow-[2px_2px_0px_rgba(0,0,0,0.2)]"
                        >
                            {isPlaying ? (
                                <Pause className="w-5 h-5" fill="currentColor" />
                            ) : (
                                <Play className="w-5 h-5 ml-1" fill="currentColor" />
                            )}
                        </button>

                        <button onClick={skipNext} className="text-gray-700 hover:text-black hover:scale-110 active:scale-95 transition-all">
                            <SkipForward className="w-5 h-5" fill="currentColor" strokeWidth={1} />
                        </button>
                    </div>

                    {/* Right: Progress */}
                    <div className="flex items-center gap-2 flex-1 w-full text-xs font-mono font-bold text-gray-600">
                        <span>{formatTime(progress)}</span>
                        <div className="relative flex-1 h-3 group"
                             onClick={(e) => {
                                 const rect = e.currentTarget.getBoundingClientRect();
                                 const x = e.clientX - rect.left;
                                 seek((x / rect.width) * duration);
                             }}
                        >
                            {/* Sketchy line base */}
                            <div className="absolute inset-y-1 left-0 right-0 bg-gray-200 rounded-full cursor-pointer overflow-hidden border border-gray-300">
                                <div 
                                    className="h-full bg-orange-500 relative transition-all duration-100"
                                    style={{ width: `${progressPercent}%` }}
                                />
                            </div>
                        </div>
                        <span>{formatTime(duration)}</span>
                    </div>

                </div>
            </motion.div>

            {/* Now Playing Modal */}
            {showNowPlaying && (
                <NowPlaying isOpen={showNowPlaying} onClose={() => setShowNowPlaying(false)} />
            )}

            {/* Queue Drawer */}
            {showQueue && <QueueDrawer onClose={() => setShowQueue(false)} />}
        </AnimatePresence>
    );
}
