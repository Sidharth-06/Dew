"use client";

import { useState, useEffect } from "react";
import { useParams, useSearchParams } from "next/navigation";
import { useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { Play, ArrowLeft, Clock, Music, Shuffle } from "lucide-react";
import SongRow from "@/components/SongRow";
import { useAudio, Song } from "@/components/AudioProvider";

export default function PlaylistPage() {
    const params = useParams();
    const searchParams = useSearchParams();
    const router = useRouter();
    const { playQueue } = useAudio();
    const [songs, setSongs] = useState<Song[]>([]);
    const [title, setTitle] = useState("");
    const [image, setImage] = useState("");
    const [loading, setLoading] = useState(true);

    const id = params.id as string;
    const type = searchParams.get("type") || "playlist";

    useEffect(() => {
        if (!id) return;
        fetch(`/api/playlist/${id}?type=${type}`)
            .then((r) => r.json())
            .then((data) => {
                setSongs(data.songs || []);
                setTitle(data.title || "Playlist");
                setImage(data.image || "");
            })
            .catch(console.error)
            .finally(() => setLoading(false));
    }, [id, type]);

    const totalDuration = songs.reduce((acc, s) => acc + (s.duration || 0), 0);
    const durationStr = totalDuration > 3600
        ? `${Math.floor(totalDuration / 3600)}h ${Math.floor((totalDuration % 3600) / 60)}m`
        : `${Math.floor(totalDuration / 60)} min`;

    return (
        <div className="min-h-screen">
            {/* Header with background */}
            <div className="relative">
                {/* Background blur */}
                {image && (
                    <div className="absolute inset-0 overflow-hidden">
                        <img
                            src={image}
                            alt=""
                            className="absolute inset-0 w-full h-full object-cover scale-110 blur-[60px] opacity-30"
                        />
                        <div className="absolute inset-0 bg-gradient-to-b from-[#0a0a0a]/60 via-[#0a0a0a]/80 to-[#0a0a0a]" />
                    </div>
                )}

                <div className="relative z-10 max-w-screen-xl mx-auto px-4 pt-6 pb-8">
                    {/* Back button */}
                    <button
                        onClick={() => router.back()}
                        className="p-2 text-gray-400 hover:text-white transition-colors mb-6"
                    >
                        <ArrowLeft className="w-5 h-5" />
                    </button>

                    <div className="flex flex-col sm:flex-row items-center sm:items-end gap-6">
                        {/* Playlist Image */}
                        <motion.div
                            initial={{ opacity: 0, scale: 0.9 }}
                            animate={{ opacity: 1, scale: 1 }}
                            className="w-52 h-52 rounded-xl overflow-hidden shadow-2xl shadow-black/40 ring-1 ring-white/10 flex-shrink-0"
                        >
                            {image ? (
                                <img
                                    src={image}
                                    alt={title}
                                    className="w-full h-full object-cover"
                                />
                            ) : (
                                <div className="w-full h-full bg-gradient-to-br from-purple-500/20 to-blue-500/20 flex items-center justify-center">
                                    <Music className="w-16 h-16 text-gray-600" />
                                </div>
                            )}
                        </motion.div>

                        {/* Playlist Info */}
                        <motion.div
                            initial={{ opacity: 0, y: 20 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: 0.1 }}
                            className="text-center sm:text-left"
                        >
                            <p className="text-xs text-gray-400 uppercase tracking-widest mb-2">
                                {type === "album" ? "Album" : "Playlist"}
                            </p>
                            <h1 className="text-3xl sm:text-4xl font-bold text-white mb-3">
                                {loading ? (
                                    <span className="skeleton inline-block w-48 h-8" />
                                ) : (
                                    title
                                )}
                            </h1>
                            {!loading && (
                                <div className="flex items-center gap-3 text-sm text-gray-400 justify-center sm:justify-start">
                                    <span>{songs.length} songs</span>
                                    <span>•</span>
                                    <span className="flex items-center gap-1">
                                        <Clock className="w-3.5 h-3.5" />
                                        {durationStr}
                                    </span>
                                </div>
                            )}
                        </motion.div>
                    </div>

                    {/* Action buttons */}
                    {!loading && songs.length > 0 && (
                        <motion.div
                            initial={{ opacity: 0, y: 10 }}
                            animate={{ opacity: 1, y: 0 }}
                            transition={{ delay: 0.2 }}
                            className="flex items-center gap-3 mt-6"
                        >
                            <button
                                onClick={() => playQueue(songs, 0)}
                                className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-purple-500 to-blue-600 rounded-full text-white font-semibold hover:scale-105 active:scale-95 transition-transform shadow-lg shadow-purple-500/20"
                            >
                                <Play className="w-5 h-5" fill="currentColor" />
                                Play All
                            </button>
                            <button
                                onClick={() => {
                                    const shuffled = [...songs].sort(() => Math.random() - 0.5);
                                    playQueue(shuffled, 0);
                                }}
                                className="flex items-center gap-2 px-6 py-3 bg-white/[0.06] rounded-full text-white font-medium hover:bg-white/[0.1] transition-colors border border-white/[0.08]"
                            >
                                <Shuffle className="w-4 h-4" />
                                Shuffle
                            </button>
                        </motion.div>
                    )}
                </div>
            </div>

            {/* Songs List */}
            <div className="max-w-screen-xl mx-auto px-4 pb-8">
                {loading ? (
                    <div className="space-y-2 mt-4">
                        {[...Array(10)].map((_, i) => (
                            <div key={i} className="flex items-center gap-3 px-4 py-3">
                                <div className="w-8 h-3 skeleton" />
                                <div className="w-10 h-10 skeleton" />
                                <div className="flex-1 space-y-2">
                                    <div className="w-48 h-3 skeleton" />
                                    <div className="w-32 h-2 skeleton" />
                                </div>
                            </div>
                        ))}
                    </div>
                ) : (
                    <div className="space-y-1 mt-4">
                        {songs.map((song, i) => (
                            <SongRow
                                key={song.id}
                                song={song}
                                index={i}
                                showIndex
                                allSongs={songs}
                            />
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}
