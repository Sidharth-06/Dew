"use client";

import { useEffect, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { X, Plus, Check, ListMusic } from "lucide-react";
import { db } from "@/lib/db/database";
import { useLiveQuery } from "dexie-react-hooks";
import { Song } from "./AudioProvider";

interface Props {
    song: Song;
    onClose: () => void;
}

export default function AddToPlaylistModal({ song, onClose }: Props) {
    const playlists = useLiveQuery(() => db.playlists.orderBy("createdAt").reverse().toArray());
    const [added, setAdded] = useState<Record<string, boolean>>({});
    const [creating, setCreating] = useState(false);
    const [newName, setNewName] = useState("");

    // Check which playlists already contain this song
    useEffect(() => {
        if (!playlists) return;
        Promise.all(
            playlists.map(async (p) => {
                const exists = await db.playlistSongs.get([p.id, song.id]);
                return { id: p.id, exists: !!exists };
            })
        ).then((results) => {
            const map: Record<string, boolean> = {};
            results.forEach((r) => (map[r.id] = r.exists));
            setAdded(map);
        });
    }, [playlists, song.id]);

    const toggle = async (playlistId: string) => {
        if (added[playlistId]) {
            await db.playlistSongs.delete([playlistId, song.id]);
            setAdded((p) => ({ ...p, [playlistId]: false }));
        } else {
            await db.playlistSongs.put({
                playlistId,
                songId: song.id,
                song,
                addedAt: Date.now(),
            });
            setAdded((p) => ({ ...p, [playlistId]: true }));
        }
    };

    const createAndAdd = async () => {
        const name = newName.trim();
        if (!name) return;
        const id = Date.now().toString();
        await db.playlists.put({ id, title: name, createdAt: Date.now() });
        await db.playlistSongs.put({ playlistId: id, songId: song.id, song, addedAt: Date.now() });
        setAdded((p) => ({ ...p, [id]: true }));
        setCreating(false);
        setNewName("");
    };

    return (
        <AnimatePresence>
            <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                className="fixed inset-0 z-[60] flex items-end sm:items-center justify-center p-4"
                onClick={onClose}
            >
                <div className="absolute inset-0 bg-black/50 backdrop-blur-sm" />
                <motion.div
                    initial={{ y: 40, opacity: 0 }}
                    animate={{ y: 0, opacity: 1 }}
                    exit={{ y: 40, opacity: 0 }}
                    transition={{ type: "spring", damping: 28, stiffness: 280 }}
                    className="relative z-10 w-full max-w-sm bg-white rounded-2xl shadow-2xl overflow-hidden border-t-4 border-orange-500 font-kalam"
                    onClick={(e) => e.stopPropagation()}
                >
                    {/* Header */}
                    <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100">
                        <div className="flex items-center gap-2">
                            <ListMusic className="w-5 h-5 text-orange-500" />
                            <h2 className="text-lg font-bold text-gray-900">Add to Playlist</h2>
                        </div>
                        <button onClick={onClose} className="p-1.5 hover:bg-gray-100 rounded-full transition-colors">
                            <X className="w-5 h-5 text-gray-500" />
                        </button>
                    </div>

                    {/* Song info */}
                    <div className="flex items-center gap-3 px-5 py-3 bg-orange-50/50 border-b border-orange-100">
                        <img src={song.image} alt="" className="w-10 h-10 object-cover rounded-lg shadow-sm" />
                        <div className="min-w-0">
                            <p className="font-bold text-gray-900 truncate">{song.title}</p>
                            <p className="text-sm text-gray-500 truncate">{song.artist.split(",")[0]}</p>
                        </div>
                    </div>

                    {/* Playlist list */}
                    <div className="max-h-64 overflow-y-auto py-2">
                        {(!playlists || playlists.length === 0) && !creating && (
                            <p className="text-center text-gray-400 py-6 font-caveat text-lg">No playlists yet</p>
                        )}
                        {playlists?.map((p) => (
                            <button
                                key={p.id}
                                onClick={() => toggle(p.id)}
                                className="w-full flex items-center justify-between px-5 py-3 hover:bg-gray-50 transition-colors"
                            >
                                <span className="font-bold text-gray-900 truncate">{p.title}</span>
                                <div className={`w-6 h-6 rounded-full flex items-center justify-center transition-colors ${added[p.id] ? "bg-orange-500" : "border-2 border-gray-300"}`}>
                                    {added[p.id] && <Check className="w-3.5 h-3.5 text-white" strokeWidth={3} />}
                                </div>
                            </button>
                        ))}
                    </div>

                    {/* Create new */}
                    <div className="border-t border-gray-100 px-5 py-3">
                        {creating ? (
                            <div className="flex gap-2">
                                <input
                                    autoFocus
                                    value={newName}
                                    onChange={(e) => setNewName(e.target.value)}
                                    onKeyDown={(e) => { if (e.key === "Enter") createAndAdd(); if (e.key === "Escape") setCreating(false); }}
                                    placeholder="Playlist name…"
                                    className="flex-1 border border-gray-300 rounded-lg px-3 py-1.5 text-sm outline-none focus:border-orange-400 font-caveat"
                                />
                                <button onClick={createAndAdd} className="px-3 py-1.5 bg-orange-500 text-white rounded-lg text-sm font-bold hover:bg-orange-600">Create</button>
                                <button onClick={() => setCreating(false)} className="px-2 py-1.5 text-gray-400 hover:text-gray-600 text-sm">✕</button>
                            </div>
                        ) : (
                            <button
                                onClick={() => setCreating(true)}
                                className="w-full flex items-center gap-2 text-orange-500 font-bold text-sm hover:text-orange-600 transition-colors py-1"
                            >
                                <Plus className="w-4 h-4" />
                                New Playlist
                            </button>
                        )}
                    </div>
                </motion.div>
            </motion.div>
        </AnimatePresence>
    );
}
