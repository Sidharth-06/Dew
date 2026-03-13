"use client";

import { useAudio, Song } from "./AudioProvider";
import { Play, Plus, MoreHorizontal } from "lucide-react";
import { useState } from "react";
import { motion } from "framer-motion";

function formatDuration(seconds: number): string {
    if (!seconds) return "";
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s.toString().padStart(2, "0")}`;
}

interface SongRowProps {
    song: Song;
    index?: number;
    showIndex?: boolean;
    allSongs?: Song[];
}

export default function SongRow({ song, index = 0, showIndex = false, allSongs }: SongRowProps) {
    const { playSong, addToQueue, currentSong, isPlaying, playQueue } = useAudio();
    const [showMenu, setShowMenu] = useState(false);
    const isActive = currentSong?.id === song.id;

    const handlePlay = () => {
        if (allSongs && allSongs.length > 0) {
            playQueue(allSongs, index);
        } else {
            playSong(song);
        }
    };

    return (
        <div
            className={`group flex items-center gap-3 px-4 py-3 rounded-r-lg hover:bg-white/[0.6] transition-all duration-300 cursor-pointer relative overflow-hidden torn-paper mt-2 mb-2 ${isActive ? "bg-purple-100" : ""
                }`}
            onClick={handlePlay}
            style={{ transform: `rotate(${(index % 3) - 1}deg)`}}
        >
            {/* Active Highlight (Like a highlighter marker) */}
            {isActive && (
                <motion.div
                    layoutId="activeRowGlow"
                    className="absolute left-0 top-0 bottom-0 w-full bg-yellow-200/50 mix-blend-multiply pointer-events-none"
                />
            )}

            {/* Index / Play Icon */}
            <div className="w-8 text-center flex-shrink-0 relative z-10 font-kalam">
                {showIndex ? (
                    <>
                        <span
                            className={`text-lg transition-colors ${isActive ? "text-purple-700 font-bold" : "text-gray-500 font-bold"
                                }`}
                        >
                            {index + 1}
                        </span>
                        <Play
                            className="w-5 h-5 text-black hidden group-hover:block mx-auto transform hover:scale-110 transition-transform drop-shadow-sm"
                            fill="currentColor"
                        />
                    </>
                ) : (
                    <Play
                        className={`w-5 h-5 mx-auto transition-all duration-300 transform group-hover:scale-110 ${isActive
                            ? "text-purple-600 opacity-100 scale-110"
                            : "text-gray-800 opacity-0 group-hover:opacity-100"
                            }`}
                        fill="currentColor"
                    />
                )}
            </div>

            {/* Image (Small Polaroid effect) */}
            <div className="w-12 h-12 bg-white p-1 pb-3 shadow-sm transform -rotate-2 flex-shrink-0">
                <img
                    src={song.image}
                    alt={song.title}
                    className="w-full h-full object-cover grayscale-[0.2]"
                    loading="lazy"
                />
            </div>

            {/* Info */}
            <div className="flex-1 min-w-0 ml-2 font-kalam">
                <p
                    className={`text-lg font-bold leading-none truncate ${isActive ? "text-purple-800" : "text-gray-900"
                        }`}
                >
                    {song.title}
                </p>
                <p className="text-sm text-gray-600 truncate mt-1">{song.artist}</p>
            </div>

            {/* Duration */}
            <span className="text-sm font-caveat text-gray-500 flex-shrink-0 hidden sm:block rotate-1">
                {formatDuration(song.duration)}
            </span>

            {/* Actions */}
            <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button
                    onClick={(e) => {
                        e.stopPropagation();
                        addToQueue(song);
                    }}
                    className="p-1.5 text-black hover:bg-black/5 rounded-full transition-colors"
                    title="Add to queue"
                >
                    <Plus className="w-5 h-5" />
                </button>
            </div>
        </div>
    );
}
