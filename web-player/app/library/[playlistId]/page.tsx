"use client";

import { use } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { db } from "@/lib/db/database";
import { useAudio } from "@/components/AudioProvider";
import { motion } from "framer-motion";
import {
    Play, Pause, Shuffle, ArrowLeft,
    Trash2, Heart, Music4, GripVertical, ListMusic
} from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { Song } from "@/lib/jiosaavn";

function formatDuration(s: number) {
    if (!s || isNaN(s)) return "0:00";
    return `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, "0")}`;
}

export default function PlaylistDetailPage({ params }: { params: Promise<{ playlistId: string }> }) {
    const { playlistId } = use(params);
    const { currentSong, isPlaying, playQueue, togglePlay, addToQueue } = useAudio();

    const playlist = useLiveQuery(() => db.playlists.get(playlistId));
    const songRows = useLiveQuery(
        () => db.playlistSongs.where("playlistId").equals(playlistId).sortBy("addedAt"),
        [playlistId]
    );
    const likedIds = useLiveQuery(() => db.likedSongs.toCollection().primaryKeys()) as string[] | undefined;

    const songs: Song[] = songRows ? songRows.map((r: any) => r.song) : [];
    const totalDuration = songs.reduce((s, song) => s + (song.duration ?? 0), 0);
    const likedSet = new Set(likedIds ?? []);

    const [removingId, setRemovingId] = useState<string | null>(null);

    const removeSong = async (songId: string) => {
        setRemovingId(songId);
        await db.playlistSongs.delete([playlistId, songId]);
        setTimeout(() => setRemovingId(null), 300);
    };

    const toggleLike = async (song: Song) => {
        if (likedSet.has(song.id)) await db.likedSongs.delete(song.id);
        else await db.likedSongs.put({ songId: song.id, song, addedAt: Date.now() });
    };

    if (!playlist) {
        return (
            <div className="flex items-center justify-center h-64 font-caveat text-gray-400 text-2xl">
                Playlist not found
            </div>
        );
    }

    return (
        <div className="max-w-3xl mx-auto pb-16 font-kalam">
            {/* Back */}
            <Link href="/library" className="inline-flex items-center gap-2 text-gray-500 hover:text-gray-900 transition-colors mb-8 font-caveat text-lg">
                <ArrowLeft className="w-4 h-4" />
                Your Board
            </Link>

            {/* Header */}
            <div className="flex flex-col sm:flex-row gap-8 items-start mb-10">
                {/* Cover art */}
                <div className="w-44 flex-shrink-0 bg-white p-3 pb-10 shadow-[0_10px_30px_-5px_rgba(0,0,0,0.2)] transform -rotate-2 relative">
                    <div className="absolute -top-2 left-1/2 -translate-x-1/2 tape-strip w-14" />
                    {songs[0] ? (
                        <img src={songs[0].image} alt="" className="w-full aspect-square object-cover" />
                    ) : (
                        <div className="w-full aspect-square bg-gradient-to-br from-orange-400 to-pink-500 flex items-center justify-center">
                            <ListMusic className="w-12 h-12 text-white" />
                        </div>
                    )}
                    <p className="text-center font-caveat text-sm text-gray-600 mt-2 font-bold">{playlist.title}</p>
                </div>

                {/* Meta */}
                <div className="flex-1 flex flex-col justify-end gap-4">
                    <div className="transform -rotate-1">
                        <h1 className="font-caveat text-4xl sm:text-5xl font-bold text-gray-900 leading-tight">{playlist.title}</h1>
                        <p className="font-caveat text-lg text-gray-500 mt-1">{songs.length} tracks · {Math.floor(totalDuration / 60)}m</p>
                    </div>
                    <div className="flex gap-3 flex-wrap">
                        <button
                            onClick={() => songs.length > 0 && playQueue(songs, 0)}
                            disabled={songs.length === 0}
                            className="flex items-center gap-2 px-5 py-2.5 bg-orange-500 text-white rounded-full font-bold shadow-md hover:bg-orange-600 active:scale-95 transition-all disabled:opacity-40"
                        >
                            <Play className="w-4 h-4" fill="currentColor" />
                            Play All
                        </button>
                        <button
                            onClick={() => {
                                if (songs.length === 0) return;
                                const shuffled = [...songs].sort(() => Math.random() - 0.5);
                                playQueue(shuffled, 0);
                            }}
                            disabled={songs.length === 0}
                            className="flex items-center gap-2 px-5 py-2.5 bg-white border border-gray-200 text-gray-700 rounded-full font-bold shadow-sm hover:bg-gray-50 active:scale-95 transition-all disabled:opacity-40"
                        >
                            <Shuffle className="w-4 h-4" />
                            Shuffle
                        </button>
                    </div>
                </div>
            </div>

            {/* Song list */}
            {songs.length === 0 ? (
                <div className="text-center py-16 font-caveat">
                    <Music4 className="w-16 h-16 text-gray-300 mx-auto mb-4" />
                    <p className="text-2xl text-gray-400">No songs yet.</p>
                    <p className="text-lg text-gray-400 mt-1">Open a song &rarr; + &rarr; Add to this playlist.</p>
                </div>
            ) : (
                <div className="bg-[#fdfaf6] shadow-md border-l-4 border-pink-300 pl-8 pr-4 py-4 relative"
                    style={{ backgroundImage: `repeating-linear-gradient(transparent, transparent 39px, #bae6fd 39px, #bae6fd 40px)`, backgroundPosition: "0 10px" }}
                >
                    <div className="absolute left-3 top-8 w-3 h-3 bg-gray-200 rounded-full shadow-inner border border-gray-300" />
                    <div className="absolute left-3 top-1/2 w-3 h-3 bg-gray-200 rounded-full shadow-inner border border-gray-300" />

                    {songs.map((song, i) => {
                        const isActive = currentSong?.id === song.id;
                        return (
                            <motion.div
                                key={song.id}
                                animate={{ opacity: removingId === song.id ? 0 : 1, x: removingId === song.id ? -20 : 0 }}
                                className="flex items-center gap-3 py-2 group cursor-pointer"
                                style={{ height: "40px" }}
                                onClick={() => {
                                    if (isActive) togglePlay();
                                    else playQueue(songs, i);
                                }}
                            >
                                <span className="font-caveat text-sm text-gray-400 w-5 text-right flex-shrink-0">{i + 1}</span>
                                <img src={song.image} alt="" className="w-7 h-7 object-cover rounded-sm flex-shrink-0 shadow-sm" />
                                <div className="flex-1 min-w-0">
                                    <p className={`font-caveat text-lg font-bold truncate ${isActive ? "text-orange-600" : "text-gray-900 group-hover:text-orange-600"} transition-colors`}>
                                        {song.title}
                                    </p>
                                </div>
                                <span className="font-caveat text-sm text-gray-500 flex-shrink-0 hidden sm:block">{song.artist.split(",")[0]}</span>
                                <span className="font-caveat text-xs text-gray-400 flex-shrink-0 tabular-nums">{formatDuration(song.duration)}</span>
                                <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
                                    <button onClick={(e) => { e.stopPropagation(); toggleLike(song); }}
                                        className={`p-1 rounded transition-colors ${likedSet.has(song.id) ? "text-red-500" : "text-gray-400 hover:text-red-400"}`}>
                                        <Heart className="w-4 h-4" fill={likedSet.has(song.id) ? "currentColor" : "none"} />
                                    </button>
                                    <button onClick={(e) => { e.stopPropagation(); addToQueue(song); }}
                                        className="p-1 text-gray-400 hover:text-gray-700 rounded transition-colors">
                                        <ListMusic className="w-4 h-4" />
                                    </button>
                                    <button onClick={(e) => { e.stopPropagation(); removeSong(song.id); }}
                                        className="p-1 text-gray-400 hover:text-red-500 rounded transition-colors">
                                        <Trash2 className="w-4 h-4" />
                                    </button>
                                </div>
                            </motion.div>
                        );
                    })}
                </div>
            )}
        </div>
    );
}
