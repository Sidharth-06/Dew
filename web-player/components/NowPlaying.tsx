"use client";

import { useEffect, useState, useRef } from "react";
import { useAudio } from "./AudioProvider";
import { motion, AnimatePresence } from "framer-motion";
import {
    Play,
    Pause,
    SkipForward,
    SkipBack,
    Shuffle,
    Repeat,
    Repeat1,
    ChevronDown,
    Heart,
    Quote,
    Music4
} from "lucide-react";

import { useLiveQuery } from "dexie-react-hooks";
import { db } from "@/lib/db/database";

function formatDuration(seconds: number): string {
    if (!seconds || isNaN(seconds)) return "0:00";
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s.toString().padStart(2, "0")}`;
}

export default function NowPlaying({
    isOpen,
    onClose,
}: {
    isOpen: boolean;
    onClose: () => void;
}) {
    const {
        currentSong,
        isPlaying,
        progress,
        duration,
        togglePlay,
        skipNext,
        skipPrevious,
        shuffle,
        repeat,
        toggleShuffle,
        toggleRepeat,
        seek,
    } = useAudio();

    const isLiked = useLiveQuery(
        async () => {
            if (!currentSong) return false;
            const liked = await db.likedSongs.get(currentSong.id);
            return !!liked;
        },
        [currentSong?.id]
    );

    const toggleLikedSong = async () => {
        if (!currentSong) return;
        if (isLiked) {
            await db.likedSongs.delete(currentSong.id);
        } else {
            await db.likedSongs.put({
                songId: currentSong.id,
                song: currentSong,
                addedAt: Date.now()
            });
        }
    };

    const [isScrubbing, setIsScrubbing] = useState(false);
    const [scrubValue, setScrubValue] = useState(0);
    const progressBarRef = useRef<HTMLDivElement>(null);

    const [showLyrics, setShowLyrics] = useState(false);
    const [lyrics, setLyrics] = useState<string>("");
    const [loadingLyrics, setLoadingLyrics] = useState(false);

    useEffect(() => {
        if (showLyrics && currentSong && currentSong.hasLyrics) {
            const fetchLyrics = async () => {
                setLoadingLyrics(true);
                try {
                    const res = await fetch(`/api/lyrics?id=${currentSong.id}`);
                    const data = await res.json();
                    if (data.lyrics) {
                        // Unescape HTML <br> tags
                        setLyrics(data.lyrics.replace(/<br\s*\/?>/gi, '\n'));
                    } else {
                        setLyrics("Lyrics not available.");
                    }
                } catch {
                    setLyrics("Error loading lyrics.");
                } finally {
                    setLoadingLyrics(false);
                }
            };
            fetchLyrics();
        } else {
            setLyrics("");
        }
    }, [showLyrics, currentSong]);

    if (!currentSong) return null;

    const displayProgress = isScrubbing ? scrubValue : progress;
    const progressPercent = duration > 0 ? (displayProgress / duration) * 100 : 0;

    return (
        <AnimatePresence>
            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.95 }}
                transition={{ type: "spring", damping: 30, stiffness: 300 }}
                className="fixed inset-0 z-50 flex items-center justify-center font-kalam text-gray-800 p-4 sm:p-8"
            >
                {/* Overlay Background */}
                <div className="absolute inset-0 bg-black/40 backdrop-blur-sm" onClick={onClose} />

                {/* Main Content Area */}
                <div className="relative z-10 w-full max-w-6xl max-h-full overflow-y-auto custom-scrollbar bg-[#f0f0f0] rounded-2xl shadow-[0_20px_60px_-15px_rgba(0,0,0,0.5)] flex flex-col lg:flex-row gap-12 lg:gap-20 p-8 lg:p-16 border-2 border-white pointer-events-auto"
                     style={{ backgroundImage: `radial-gradient(#d4d4d8 1.5px, transparent 1.5px)`, backgroundSize: '24px 24px' }}
                >
                    
                    {/* Top Right Close Button */}
                    <div className="absolute top-6 right-6 flex gap-3">
                        <button onClick={onClose} className="w-10 h-10 bg-white rounded-full flex items-center justify-center shadow-md hover:scale-110 transition-transform">
                            <ChevronDown className="w-6 h-6" strokeWidth={2.5} />
                        </button>
                    </div>

                    {/* Left Column: Polaroid & Controls */}
                    <div className="flex-1 flex flex-col items-center lg:items-start max-w-md mx-auto w-full">
                        
                        {/* Header Mock */}
                        <div className="flex items-center gap-3 mb-8 self-start ml-2 lg:ml-0 transform -rotate-2">
                            <div className="bg-orange-500 rounded-sm p-1.5 text-white">
                                <Quote className="w-4 h-4" />
                            </div>
                            <span className="text-xl font-bold font-caveat tracking-wide">{currentSong.title.toLowerCase().replace(/\s+/g, '_')}.mp3</span>
                        </div>

                        {/* Polaroid */}
                        <div className="w-full aspect-[4/5] bg-white p-4 pb-24 shadow-[0_15px_30px_-5px_rgba(0,0,0,0.2)] transform -rotate-1 relative group">
                            <div className="absolute -top-3 left-1/2 -translate-x-1/2 w-16 h-6 bg-white/50 backdrop-blur-md shadow-sm transform rotate-1"></div>
                            <div className="w-full aspect-square bg-gray-200 overflow-hidden shadow-inner border border-gray-100">
                                <img src={currentSong.image.replace("150x150", "500x500")} alt={currentSong.title} className="w-full h-full object-cover grayscale-[0.1]" />
                            </div>
                            <div className="absolute bottom-6 left-0 right-0 text-center font-caveat px-4">
                                <h3 className="text-2xl sm:text-3xl font-bold leading-tight line-clamp-2">{currentSong.title}</h3>
                                <p className="text-orange-500 font-bold mt-1 text-lg sm:text-xl truncate">{currentSong.artist}</p>
                            </div>
                        </div>

                        {/* Player Controls */}
                        <div className="w-full mt-10 px-2 lg:px-4">
                            {/* Progress Bar */}
                            <div className="flex items-center gap-3 text-xs font-mono font-bold text-gray-600 mb-6">
                                <span>{formatDuration(displayProgress)}</span>
                                <div className="relative flex-1 h-3 group"
                                    onClick={(e) => {
                                        const rect = e.currentTarget.getBoundingClientRect();
                                        const x = e.clientX - rect.left;
                                        seek((x / rect.width) * duration);
                                    }}
                                >
                                    <div className="absolute inset-y-1 left-0 right-0 bg-gray-300 rounded-full cursor-pointer">
                                        <div 
                                            className="h-full bg-gray-800 rounded-full relative transition-all duration-100"
                                            style={{ width: `${progressPercent}%` }}
                                        />
                                    </div>
                                </div>
                                <span>{formatDuration(duration)}</span>
                            </div>

                            {/* Play Buttons */}
                            <div className="flex items-center justify-between">
                                <button onClick={toggleShuffle} className={`p-2 transition-transform hover:scale-110 ${shuffle ? "text-orange-500" : "text-gray-500"}`}>
                                    <Shuffle className="w-5 h-5" strokeWidth={2.5}/>
                                </button>
                                <div className="flex items-center gap-4">
                                    <button onClick={skipPrevious} className="p-2 hover:scale-110 active:scale-95 transition-transform">
                                        <SkipBack className="w-6 h-6" fill="currentColor" />
                                    </button>
                                    <button onClick={togglePlay} className="w-14 h-14 bg-orange-500 rounded-full flex items-center justify-center text-white shadow-lg hover:scale-105 active:scale-95 transition-transform">
                                        {isPlaying ? <Pause className="w-6 h-6" fill="currentColor" /> : <Play className="w-6 h-6 ml-1" fill="currentColor" />}
                                    </button>
                                    <button onClick={skipNext} className="p-2 hover:scale-110 active:scale-95 transition-transform">
                                        <SkipForward className="w-6 h-6" fill="currentColor" />
                                    </button>
                                </div>
                                <button onClick={toggleRepeat} className={`p-2 transition-transform hover:scale-110 ${repeat !== "off" ? "text-orange-500" : "text-gray-500"}`}>
                                    {repeat === "one" ? <Repeat1 className="w-5 h-5" /> : <Repeat className="w-5 h-5" />}
                                </button>
                            </div>
                        </div>
                    </div>

                    {/* Right Column: Lyrics Lined Paper */}
                    <div className="flex-1 w-full max-w-lg mx-auto relative mt-8 lg:mt-0">
                        {/* Red Push Pin */}
                        <div className="absolute -top-3 left-1/2 -translate-x-1/2 w-4 h-4 rounded-full bg-red-600 shadow-[2px_4px_4px_rgba(0,0,0,0.3)] z-20 border border-red-800"></div>
                        
                        {/* The Lined Paper */}
                        <div className="bg-[#fdfaf6] w-full min-h-[500px] shadow-[0_15px_30px_-5px_rgba(0,0,0,0.15)] transform rotate-1 border-l-2 border-pink-300 relative font-caveat pl-12 pr-6 py-10"
                             style={{
                                 backgroundImage: `repeating-linear-gradient(transparent, transparent 31px, #bae6fd 31px, #bae6fd 32px)`,
                                 backgroundPosition: '0 10px'
                             }}
                        >
                            {/* Paper holes */}
                            <div className="absolute left-4 top-12 w-3 h-3 bg-gray-200 rounded-full shadow-inner border border-gray-300" />
                            <div className="absolute left-4 top-1/2 w-3 h-3 bg-gray-200 rounded-full shadow-inner border border-gray-300" />
                            <div className="absolute left-4 bottom-12 w-3 h-3 bg-gray-200 rounded-full shadow-inner border border-gray-300" />

                            <div className="flex items-center justify-between mb-8">
                                <h1 className="text-3xl font-bold text-gray-900 border-b-2 border-gray-900 inline-block">Lyrics: {currentSong.title}</h1>
                                <button onClick={toggleLikedSong} className={`p-2 hover:scale-110 transition-transform ${isLiked ? 'text-red-500' : 'text-gray-400'}`}>
                                    <Heart className="w-8 h-8" fill={isLiked ? "currentColor" : "none"} strokeWidth={2} />
                                </button>
                            </div>

                            <div className="h-[350px] overflow-y-auto custom-scrollbar pr-4 text-2xl leading-[32px] text-gray-700 space-y-4">
                                {loadingLyrics ? (
                                     <div className="flex items-center gap-2 text-gray-500"><div className="w-4 h-4 rounded-full border-2 border-gray-300 border-t-gray-600 animate-spin" /> Fetching lyrics...</div>
                                ) : currentSong.hasLyrics && lyrics ? (
                                    lyrics.split('\n').map((line, i) => (
                                        <p key={i} className={i % 2 === 0 ? "text-gray-900" : "text-orange-600"}>{line || '\u00A0'}</p>
                                    ))
                                ) : (
                                    <p className="text-gray-500 italic flex items-center gap-2">
                                        <Music4 className="w-5 h-5"/> Instrumental / No lyrics found.
                                    </p>
                                )}
                            </div>
                        </div>

                        {/* Little Sticky Note Overlay */}
                        <div className="absolute -bottom-6 -left-6 bg-yellow-300 w-32 h-32 p-3 shadow-lg transform -rotate-6 font-kalam text-sm leading-tight border-b border-r border-yellow-400 flex flex-col justify-between">
                            <span className="text-gray-900">Don't forget to like this track!</span>
                            <span className="text-[10px] text-gray-500 text-right self-end mt-4">vibe check: 100%</span>
                            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-8 h-3 bg-white/40 shadow-sm" />
                        </div>
                    </div>

                </div>
            </motion.div>
        </AnimatePresence>
    );
}
