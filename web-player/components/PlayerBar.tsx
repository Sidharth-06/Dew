"use client";

import { useAudio } from "./AudioProvider";
import { useState, useRef, useEffect } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
    Play,
    Pause,
    SkipForward,
    SkipBack,
    ListMusic,
    Home,
    Compass,
    User,
    Moon,
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
        togglePlay,
        seek,
        skipNext,
        skipPrevious,
    } = useAudio();

    const pathname = usePathname();
    const [showNowPlaying, setShowNowPlaying] = useState(false);
    const [showQueue, setShowQueue] = useState(false);

    // Sleep timer
    const SLEEP_OPTIONS = [0, 15, 30, 60]; // minutes; 0 = off
    const [sleepMinutes, setSleepMinutes] = useState(0);
    const [sleepEndsAt, setSleepEndsAt] = useState<number | null>(null);
    const [sleepOptIdx, setSleepOptIdx] = useState(0);

    const cycleSleep = () => {
        const next = (sleepOptIdx + 1) % SLEEP_OPTIONS.length;
        setSleepOptIdx(next);
        const mins = SLEEP_OPTIONS[next];
        setSleepMinutes(mins);
        if (mins === 0) {
            setSleepEndsAt(null);
        } else {
            setSleepEndsAt(Date.now() + mins * 60 * 1000);
        }
    };

    // Check sleep timer
    useEffect(() => {
        if (!sleepEndsAt) return;
        const id = setInterval(() => {
            if (Date.now() >= sleepEndsAt) {
                togglePlay();
                setSleepEndsAt(null);
                setSleepMinutes(0);
                setSleepOptIdx(0);
                clearInterval(id);
            }
        }, 5000);
        return () => clearInterval(id);
    }, [sleepEndsAt, togglePlay]);

    // Seeker drag state
    const seekBarRef = useRef<HTMLDivElement>(null);
    const [isScrubbing, setIsScrubbing] = useState(false);
    const [scrubPct, setScrubPct] = useState(0);

    const getPct = (clientX: number): number => {
        if (!seekBarRef.current) return 0;
        const rect = seekBarRef.current.getBoundingClientRect();
        return Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
    };

    if (!currentSong) {
        return (
            <div className="hidden md:block fixed bottom-6 left-1/2 -translate-x-1/2 z-40">
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
    const displayPct = isScrubbing ? scrubPct * 100 : progressPercent;
    const displayProgress = isScrubbing ? scrubPct * duration : progress;

    return (
        <AnimatePresence>
            <motion.div
                initial={{ y: 100, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                exit={{ y: 100, opacity: 0 }}
                transition={{ type: "spring", stiffness: 300, damping: 30 }}
                className="fixed bottom-28 md:bottom-6 w-full max-w-[800px] left-1/2 -translate-x-1/2 z-40 px-4"
            >
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

                    {/* Right: Seeker */}
                    <div className="flex items-center gap-2 flex-1 w-full text-xs font-mono font-bold text-gray-600">
                        <span className="tabular-nums w-8 text-right">{formatTime(displayProgress)}</span>

                        {/* Seek track */}
                        <div
                            ref={seekBarRef}
                            className="relative flex-1 h-5 group cursor-pointer select-none"
                            style={{ touchAction: 'none' }}
                            onPointerDown={(e) => {
                                e.currentTarget.setPointerCapture(e.pointerId);
                                const pct = getPct(e.clientX);
                                setIsScrubbing(true);
                                setScrubPct(pct);
                            }}
                            onPointerMove={(e) => {
                                if (!isScrubbing) return;
                                setScrubPct(getPct(e.clientX));
                            }}
                            onPointerUp={(e) => {
                                if (!isScrubbing) return;
                                seek(getPct(e.clientX) * duration);
                                setIsScrubbing(false);
                            }}
                            onPointerCancel={() => setIsScrubbing(false)}
                        >
                            {/* Track fill */}
                            <div className={`absolute inset-x-0 rounded-full overflow-hidden border border-gray-300 bg-gray-200 transition-all duration-150 ${isScrubbing ? 'top-1 bottom-1' : 'top-1.5 bottom-1.5 group-hover:top-1 group-hover:bottom-1'}`}>
                                <div
                                    className="h-full bg-orange-500"
                                    style={{ width: `${displayPct}%`, transition: isScrubbing ? 'none' : 'width 0.1s linear' }}
                                />
                            </div>
                            {/* Thumb */}
                            <div
                                className={`absolute top-1/2 -translate-y-1/2 -translate-x-1/2 w-3.5 h-3.5 rounded-full bg-orange-500 border-2 border-white shadow-md pointer-events-none transition-opacity duration-150 ${isScrubbing ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'}`}
                                style={{ left: `${displayPct}%` }}
                            />
                        </div>

                        <span className="tabular-nums w-8">{formatTime(duration)}</span>

                        {/* Queue + Sleep timer (desktop only) */}
                        <div className="hidden sm:flex items-center gap-1 ml-1">
                            {/* Sleep timer */}
                            <button
                                onClick={cycleSleep}
                                title={sleepMinutes > 0 ? `Sleep in ${sleepMinutes}m` : "Sleep timer off"}
                                className={`relative p-1.5 rounded-lg transition-colors ${sleepMinutes > 0 ? "text-orange-500 bg-orange-50" : "text-gray-400 hover:text-gray-700"}`}
                            >
                                <Moon className="w-4 h-4" />
                                {sleepMinutes > 0 && (
                                    <span className="absolute -top-1 -right-1 text-[9px] font-bold bg-orange-500 text-white rounded-full px-1 leading-tight">{sleepMinutes}</span>
                                )}
                            </button>
                            {/* Queue */}
                            <button
                                onClick={() => setShowQueue(true)}
                                title="View queue"
                                className="p-1.5 text-gray-400 hover:text-gray-700 rounded-lg transition-colors"
                            >
                                <ListMusic className="w-4 h-4" />
                            </button>
                        </div>
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
