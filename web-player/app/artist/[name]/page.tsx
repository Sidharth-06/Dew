"use client";

import { use, useEffect, useState } from "react";
import { useAudio } from "@/components/AudioProvider";
import { Song } from "@/lib/jiosaavn";
import { motion } from "framer-motion";
import { Play, Pause, Shuffle, ArrowLeft, Mic2, Heart } from "lucide-react";
import Link from "next/link";
import { db } from "@/lib/db/database";
import { useLiveQuery } from "dexie-react-hooks";

function formatDuration(s: number) {
    if (!s || isNaN(s)) return "0:00";
    return `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;
}

export default function ArtistPage({ params }: { params: Promise<{ name: string }> }) {
    const { name } = use(params);
    const artistName = decodeURIComponent(name);

    const { currentSong, isPlaying, playQueue, togglePlay } = useAudio();
    const [songs, setSongs] = useState<Song[]>([]);
    const [loading, setLoading] = useState(true);

    const likedIds = useLiveQuery(() => db.likedSongs.toCollection().primaryKeys()) as string[] | undefined;
    const likedSet = new Set(likedIds ?? []);

    useEffect(() => {
        setLoading(true);
        fetch(`/api/search?q=${encodeURIComponent(artistName)}`)
            .then((r) => r.json())
            .then((d) => setSongs(d.songs ?? []))
            .catch(() => setSongs([]))
            .finally(() => setLoading(false));
    }, [artistName]);

    const toggleLike = async (song: Song) => {
        if (likedSet.has(song.id)) await db.likedSongs.delete(song.id);
        else await db.likedSongs.put({ songId: song.id, song, addedAt: Date.now() });
    };

    return (
        <div className="max-w-3xl mx-auto pb-16 font-kalam">
            <Link href="/" className="inline-flex items-center gap-2 text-gray-500 hover:text-gray-900 transition-colors mb-8 font-caveat text-lg">
                <ArrowLeft className="w-4 h-4" />
                Back
            </Link>

            {/* Artist Header */}
            <div className="flex flex-col sm:flex-row gap-8 items-start mb-10">
                <div className="w-40 h-40 flex-shrink-0 bg-gradient-to-br from-orange-400 to-pink-500 flex items-center justify-center shadow-[0_10px_30px_-5px_rgba(0,0,0,0.3)] transform -rotate-2 relative">
                    <div className="absolute -top-2 left-1/2 -translate-x-1/2 tape-strip w-14" />
                    <Mic2 className="w-16 h-16 text-white" strokeWidth={1.5} />
                </div>

                <div className="flex-1 flex flex-col justify-end gap-4">
                    <div className="transform rotate-1">
                        <h1 className="font-caveat text-4xl sm:text-5xl font-bold text-gray-900 leading-tight">{artistName}</h1>
                        <p className="font-caveat text-lg text-gray-500 mt-1">{songs.length} songs found</p>
                    </div>
                    <div className="flex gap-3 flex-wrap">
                        <button
                            onClick={() => songs.length > 0 && playQueue(songs, 0)}
                            disabled={songs.length === 0 || loading}
                            className="flex items-center gap-2 px-5 py-2.5 bg-orange-500 text-white rounded-full font-bold shadow-md hover:bg-orange-600 active:scale-95 transition-all disabled:opacity-40"
                        >
                            <Play className="w-4 h-4" fill="currentColor" />
                            Play All
                        </button>
                        <button
                            onClick={() => { const s = [...songs].sort(() => Math.random() - 0.5); playQueue(s, 0); }}
                            disabled={songs.length === 0 || loading}
                            className="flex items-center gap-2 px-5 py-2.5 bg-white border border-gray-200 text-gray-700 rounded-full font-bold shadow-sm hover:bg-gray-50 active:scale-95 transition-all disabled:opacity-40"
                        >
                            <Shuffle className="w-4 h-4" />
                            Shuffle
                        </button>
                    </div>
                </div>
            </div>

            {/* Song list */}
            {loading ? (
                <div className="space-y-3">
                    {Array.from({ length: 8 }).map((_, i) => (
                        <div key={i} className="h-12 bg-gray-200 animate-pulse rounded-lg" style={{ opacity: 1 - i * 0.1 }} />
                    ))}
                </div>
            ) : (
                <div className="bg-[#fdfaf6] shadow-md border-l-4 border-orange-300 pl-8 pr-4 py-4 relative"
                    style={{ backgroundImage: `repeating-linear-gradient(transparent, transparent 39px, #bae6fd 39px, #bae6fd 40px)`, backgroundPosition: "0 10px" }}
                >
                    <div className="absolute left-3 top-8 w-3 h-3 bg-gray-200 rounded-full shadow-inner border border-gray-300" />
                    <div className="absolute left-3 top-1/2 w-3 h-3 bg-gray-200 rounded-full shadow-inner border border-gray-300" />
                    {songs.map((song, i) => {
                        const isActive = currentSong?.id === song.id;
                        return (
                            <motion.div
                                key={song.id}
                                whileHover={{ x: 4 }}
                                className="flex items-center gap-3 py-2 group cursor-pointer"
                                style={{ height: "40px" }}
                                onClick={() => { if (isActive) togglePlay(); else playQueue(songs, i); }}
                            >
                                <span className="font-caveat text-sm text-gray-400 w-5 text-right flex-shrink-0">{i + 1}</span>
                                <img src={song.image} alt="" className="w-7 h-7 object-cover rounded-sm flex-shrink-0 shadow-sm" />
                                <div className="flex-1 min-w-0">
                                    <p className={`font-caveat text-lg font-bold truncate transition-colors ${isActive ? "text-orange-600" : "text-gray-900 group-hover:text-orange-600"}`}>{song.title}</p>
                                </div>
                                <span className="tabular-nums font-caveat text-xs text-gray-400 flex-shrink-0">{formatDuration(song.duration)}</span>
                                <button
                                    onClick={(e) => { e.stopPropagation(); toggleLike(song); }}
                                    className={`p-1 rounded transition-all opacity-0 group-hover:opacity-100 ${likedSet.has(song.id) ? "text-red-500" : "text-gray-400 hover:text-red-400"}`}
                                >
                                    <Heart className="w-4 h-4" fill={likedSet.has(song.id) ? "currentColor" : "none"} />
                                </button>
                            </motion.div>
                        );
                    })}
                </div>
            )}
        </div>
    );
}
