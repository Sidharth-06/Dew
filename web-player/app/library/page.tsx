"use client";

import { useState } from "react";
import { useLiveQuery } from "dexie-react-hooks";
import { db } from "@/lib/db/database";
import { motion } from "framer-motion";
import { Plus, Heart, Music, Mic2, Star } from "lucide-react";
import { useRouter } from "next/navigation";
import Link from "next/link";

export default function LibraryPage() {
    const router = useRouter();
    const [activeTab, setActiveTab] = useState("EVERYTHING");
    const tabs = ["EVERYTHING", "PLAYLISTS", "ALBUMS", "ARTISTS"];

    const likedSongsData = useLiveQuery(() => db.likedSongs.orderBy('addedAt').reverse().toArray());
    const recentlyPlayedData = useLiveQuery(() => db.recentlyPlayed.orderBy('playedAt').reverse().toArray());
    const customPlaylists = useLiveQuery(async () => {
        const playlists = await db.playlists.orderBy('createdAt').reverse().toArray();
        return Promise.all(
            playlists.map(async (p) => {
                const songs = await db.playlistSongs.where('playlistId').equals(p.id).sortBy('addedAt');
                return {
                    ...p,
                    songs: songs.map((s: any) => s.song).reverse()
                };
            })
        );
    });

    const handleCreatePlaylist = async () => {
        const title = prompt("Enter playlist name:");
        if (title) {
            await db.playlists.put({
                id: Date.now().toString(),
                title,
                createdAt: Date.now()
            });
        }
    };

    const deleteCustomPlaylist = async (id: string, e: React.MouseEvent) => {
        e.stopPropagation();
        if (confirm("Delete this playlist?")) {
            await db.playlists.delete(id);
            const songs = await db.playlistSongs.where('playlistId').equals(id).toArray();
            const songKeys = songs.map((s: any) => [s.playlistId, s.songId] as [string, string]);
            await db.playlistSongs.bulkDelete(songKeys);
        }
    };

    const rotations = [-3, 2, -1, 4, -2, 3];
    const getRandomRotation = (index: number) => `rotate(${rotations[index % rotations.length]}deg)`;

    const stickyColors = ['bg-yellow-300', 'bg-pink-300', 'bg-green-300', 'bg-blue-300'];

    return (
        <div className="min-h-screen pt-12 md:pt-16 pb-32 px-4 sm:px-8 max-w-7xl mx-auto">
            
            {/* Library Header simulating 'YOUR BOARD' within the white context */}
            <div className="bg-white rounded-3xl shadow-xl border border-gray-200 p-8 sm:p-12 relative overflow-hidden"
                 style={{ backgroundImage: `radial-gradient(#e5e7eb 1.5px, transparent 1.5px)`, backgroundSize: '30px 30px' }}
            >
                {/* Header Row */}
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 mb-12">
                    <div className="flex items-center gap-4">
                        <div className="w-12 h-12 bg-orange-200 rounded-xl flex items-center justify-center transform -rotate-6 shadow-sm">
                            <Music className="w-6 h-6 text-orange-600" />
                        </div>
                        <h1 className="text-4xl font-bold font-caveat tracking-widest text-gray-900 uppercase">
                            Your Board
                        </h1>
                    </div>
                </div>

                {/* Tabs */}
                <div className="flex flex-wrap gap-8 mb-12 border-b border-gray-300/50 pb-2">
                    {tabs.map((tab) => (
                        <button 
                            key={tab}
                            onClick={() => setActiveTab(tab)}
                            className={`font-caveat text-xl sm:text-2xl font-bold uppercase transition-all relative ${
                                activeTab === tab ? "text-orange-500" : "text-gray-500 hover:text-gray-800"
                            }`}
                        >
                            {tab}
                            {activeTab === tab && (
                                <motion.div 
                                    layoutId="tab-indicator"
                                    className="absolute -bottom-[10px] left-0 right-0 h-1 bg-orange-500 rounded-full"
                                    style={{ backgroundImage: "repeating-linear-gradient(45deg, transparent, transparent 2px, rgba(0,0,0,0.1) 2px, rgba(0,0,0,0.1) 4px)" }}
                                />
                            )}
                        </button>
                    ))}
                </div>

                {/* Grid Layout for Board Items */}
                <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-x-8 gap-y-12 place-items-center">
                    
                    {/* Draft New List (Dashed Box) */}
                    {(activeTab === "EVERYTHING" || activeTab === "PLAYLISTS") && (
                        <motion.div
                            whileHover={{ scale: 1.05 }}
                            onClick={handleCreatePlaylist}
                            className="w-full max-w-[220px] aspect-square border-4 border-dashed border-gray-400/60 rounded-xl flex flex-col items-center justify-center cursor-pointer hover:bg-gray-50/50 transition-colors relative"
                        >
                            <div className="absolute -top-3 -left-3 tape-strip w-12 opacity-50 transform -rotate-12"></div>
                            <div className="w-16 h-16 bg-gray-400 rounded-full flex items-center justify-center text-white mb-4 shadow-sm">
                                <Plus className="w-8 h-8" strokeWidth={3} />
                            </div>
                            <span className="font-caveat text-xl font-bold text-gray-700">Draft new list</span>
                        </motion.div>
                    )}

                    {/* Liked Songs Sticky Note */}
                    {(activeTab === "EVERYTHING" || activeTab === "PLAYLISTS") && (
                        <motion.div
                            whileHover={{ scale: 1.05, zIndex: 50 }}
                            style={{ transform: getRandomRotation(0) }}
                            className="bg-pink-300 p-6 w-full max-w-[220px] aspect-square flex flex-col justify-end shadow-xl cursor-pointer relative rounded-br-3xl"
                        >
                            <Heart className="absolute top-4 right-4 w-6 h-6 text-gray-900" fill="currentColor" />
                            <div className="text-gray-900 font-caveat">
                                <h3 className="text-3xl font-bold leading-tight uppercase">Liked<br/>Songs</h3>
                                <p className="text-lg mt-2 text-gray-800">{likedSongsData?.length || 0} tracks</p>
                            </div>
                        </motion.div>
                    )}

                    {/* Custom Playlists */}
                    {(activeTab === "EVERYTHING" || activeTab === "PLAYLISTS") && customPlaylists?.map((playlist: any, i: number) => (
                        <Link key={playlist.id} href={`/library/${playlist.id}`}>
                            <motion.div
                                whileHover={{ scale: 1.05, zIndex: 50 }}
                                style={{ transform: getRandomRotation(i + 1) }}
                                className={`${stickyColors[i % stickyColors.length]} p-6 w-full max-w-[220px] aspect-square flex flex-col justify-end shadow-xl cursor-pointer relative rounded-bl-3xl border-t border-r border-white/20`}
                            >
                                {i % 2 === 0 ? (
                                    <Star className="absolute top-4 right-4 w-5 h-5 text-gray-900" fill="currentColor" />
                                ) : (
                                    <div className="absolute top-4 right-4 w-3 h-3 bg-red-600 rounded-full shadow-[2px_2px_4px_rgba(0,0,0,0.5)]" />
                                )}
                                <button onClick={(e) => deleteCustomPlaylist(playlist.id, e)} className="absolute top-4 left-4 text-gray-900/50 hover:text-gray-900 font-sans text-xs font-bold">✕</button>
                                <div className="text-gray-900 font-caveat w-full overflow-hidden">
                                    <h3 className="text-3xl font-bold leading-tight uppercase line-clamp-2 break-words">{playlist.title}</h3>
                                    <p className="text-lg mt-2 text-gray-800 truncate">{playlist.songs.length} tracks - Custom</p>
                                </div>
                            </motion.div>
                        </Link>
                    ))}

                    {/* Recently Played / ALBUMS (Polaroids) */}
                    {(activeTab === "EVERYTHING" || activeTab === "ALBUMS") && recentlyPlayedData?.slice(0, 4).map((record: any, i: number) => {
                        const song = record.song;
                        return (
                            <motion.div
                                key={`recent-${song.id}-${i}`}
                                whileHover={{ scale: 1.05, zIndex: 50 }}
                                style={{ transform: getRandomRotation(i + 5) }}
                                className="polaroid w-full max-w-[200px] cursor-pointer"
                            >
                                <div className="tape-strip top-[-10px] left-1/2 -translate-x-1/2"></div>
                                <img src={song.image} alt={song.title} className="w-full aspect-square object-cover mb-3" />
                                <div className="font-caveat text-center w-full overflow-hidden">
                                    <h3 className="text-2xl font-bold leading-tight truncate px-2">{song.album || song.title}</h3>
                                    <p className="text-sm text-gray-500 font-kalam truncate px-2">{song.artist}</p>
                                </div>
                            </motion.div>
                        );
                    })}

                    {/* A decorative sticky note */}
                    {activeTab === "EVERYTHING" && (
                        <motion.div
                            style={{ transform: "rotate(6deg)" }}
                            className="bg-white p-6 w-full max-w-[200px] aspect-square flex flex-col justify-center items-center shadow-md cursor-pointer relative border border-gray-200"
                        >
                            <div className="tape-strip top-[-10px] left-4 rotate-[15deg] w-12"></div>
                            <p className="text-gray-800 font-caveat text-2xl font-bold leading-tight text-center">
                                *Finish the bass line for track 7 by Friday!*
                            </p>
                            <Mic2 className="absolute bottom-4 right-4 w-6 h-6 text-orange-500 transform rotate-12" />
                        </motion.div>
                    )}

                </div>
            </div>
        </div>
    );
}
