"use client";

import { useAudio, Song } from "./AudioProvider";
import { motion } from "framer-motion";
import { X, GripVertical, Play, Trash2 } from "lucide-react";

function formatTime(seconds: number): string {
    if (!seconds || isNaN(seconds)) return "0:00";
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m}:${s.toString().padStart(2, "0")}`;
}

export default function QueueDrawer({ onClose }: { onClose: () => void }) {
    const { queue, queueIndex, playQueue, removeFromQueue } = useAudio();

    return (
        <>
            {/* Backdrop */}
            <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm"
                onClick={onClose}
            />

            {/* Drawer */}
            <motion.div
                initial={{ x: "100%" }}
                animate={{ x: 0 }}
                exit={{ x: "100%" }}
                transition={{ type: "spring", damping: 30, stiffness: 300 }}
                className="fixed right-0 top-0 bottom-0 z-50 w-full max-w-md bg-[#111]/95 backdrop-blur-xl border-l border-white/[0.06] flex flex-col"
            >
                {/* Header */}
                <div className="flex items-center justify-between px-5 py-4 border-b border-white/[0.06]">
                    <h2 className="text-lg font-bold text-white">Queue</h2>
                    <button
                        onClick={onClose}
                        className="p-2 text-gray-400 hover:text-white transition-colors"
                    >
                        <X className="w-5 h-5" />
                    </button>
                </div>

                {/* Queue List */}
                <div className="flex-1 overflow-y-auto py-2">
                    {queue.length === 0 ? (
                        <div className="flex flex-col items-center justify-center h-full text-gray-500">
                            <p className="text-sm">Queue is empty</p>
                            <p className="text-xs mt-1">Play a song to get started</p>
                        </div>
                    ) : (
                        queue.map((song, index) => (
                            <div
                                key={`${song.id}-${index}`}
                                className={`flex items-center gap-3 px-5 py-3 hover:bg-white/[0.04] transition-colors group cursor-pointer ${index === queueIndex
                                    ? "bg-purple-500/10 border-l-2 border-purple-500"
                                    : ""
                                    }`}
                                onClick={() => playQueue(queue, index)}
                            >
                                <div className="text-gray-600 group-hover:hidden w-5 flex-shrink-0">
                                    <GripVertical className="w-4 h-4" />
                                </div>
                                <div className="hidden group-hover:block w-5 flex-shrink-0 text-white">
                                    <Play className="w-4 h-4" fill="currentColor" />
                                </div>

                                <div className="w-10 h-10 rounded overflow-hidden flex-shrink-0">
                                    <img
                                        src={song.image}
                                        alt={song.title}
                                        className="w-full h-full object-cover"
                                    />
                                </div>

                                <div className="flex-1 min-w-0">
                                    <p
                                        className={`text-sm truncate ${index === queueIndex
                                            ? "text-purple-400 font-semibold"
                                            : "text-white"
                                            }`}
                                    >
                                        {song.title}
                                    </p>
                                    <p className="text-xs text-gray-500 truncate">
                                        {song.artist}
                                    </p>
                                </div>

                                <button
                                    onClick={(e) => {
                                        e.stopPropagation();
                                        removeFromQueue(index);
                                    }}
                                    className="p-2 text-gray-600 hover:text-red-400 transition-colors opacity-0 group-hover:opacity-100"
                                >
                                    <Trash2 className="w-4 h-4" />
                                </button>
                            </div>
                        ))
                    )}
                </div>
            </motion.div>
        </>
    );
}
