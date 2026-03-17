"use client";

import { useLiveQuery } from "dexie-react-hooks";
import { db } from "@/lib/db/database";
import { useAudio } from "@/components/AudioProvider";
import { useState, useEffect, useRef } from "react";
import { Song } from "@/lib/jiosaavn";
import { Heart, Music4, Clock, Play, Flame, Pause, Camera, Pencil, Check, Zap, Star, Trophy } from "lucide-react";
import { motion } from "framer-motion";
import Link from "next/link";

function fmtDuration(secs: number) {
    const h = Math.floor(secs / 3600);
    const m = Math.floor((secs % 3600) / 60);
    if (h > 0) return `${h}h ${m}m`;
    return `${m}m`;
}

function timeAgo(ms: number) {
    const diff = Date.now() - ms;
    const m = Math.floor(diff / 60000);
    if (m < 1) return "just now";
    if (m < 60) return `${m}m ago`;
    const h = Math.floor(m / 60);
    if (h < 24) return `${h}h ago`;
    return `${Math.floor(h / 24)}d ago`;
}

const STICKY_COLORS = ["bg-yellow-300", "bg-cyan-300", "bg-pink-400", "bg-green-400", "bg-orange-300"];
const STICKY_ROTS   = ["-rotate-3", "rotate-2", "-rotate-2", "rotate-4", "-rotate-1"];

export default function MePage() {
    const { currentSong, isPlaying, playQueue, togglePlay } = useAudio();

    const likedSongs     = useLiveQuery(() => db.likedSongs.orderBy("addedAt").reverse().toArray());
    const recentlyPlayed = useLiveQuery(() => db.recentlyPlayed.orderBy("playedAt").reverse().toArray());
    const profilePicSetting = useLiveQuery(() => db.settings.get("profilePicture"));
    const displayNameSetting = useLiveQuery(() => db.settings.get("displayName"));

    const profilePic  = profilePicSetting?.value ?? null;
    const displayName = displayNameSetting?.value ?? "";

    // Inline name edit
    const [editingName, setEditingName] = useState(false);
    const [nameInput, setNameInput] = useState("");
    const nameInputRef = useRef<HTMLInputElement>(null);

    const startEditName = () => {
        setNameInput(displayName);
        setEditingName(true);
        setTimeout(() => nameInputRef.current?.focus(), 50);
    };

    const saveName = async () => {
        const trimmed = nameInput.trim();
        if (trimmed) await db.settings.put({ key: "displayName", value: trimmed });
        else await db.settings.delete("displayName");
        setEditingName(false);
    };

    // Profile picture upload
    const fileInputRef = useRef<HTMLInputElement>(null);

    const handleAvatarClick = () => fileInputRef.current?.click();

    const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const file = e.target.files?.[0];
        if (!file) return;
        // Resize before storing to keep it lightweight (~200KB)
        const reader = new FileReader();
        reader.onload = (ev) => {
            const dataUrl = ev.target?.result as string;
            // Resize via canvas to max 400×400
            const img = new Image();
            img.onload = () => {
                const canvas = document.createElement("canvas");
                canvas.width = 400;
                canvas.height = 400;
                const ctx = canvas.getContext("2d")!;
                // Scale-to-fill square crop, biased toward top for portrait images (captures face)
                let sw, sh, sx, sy;
                if (img.width <= img.height) {
                    // Portrait or square: crop width as the square side, start near top
                    sw = sh = img.width;
                    sx = 0;
                    sy = (img.height - sh) * 0.2; // 20% from top instead of 50% center
                } else {
                    // Landscape: center crop
                    sw = sh = img.height;
                    sx = (img.width - sw) / 2;
                    sy = 0;
                }
                ctx.drawImage(img, sx, sy, sw, sh, 0, 0, 400, 400);
                const resized = canvas.toDataURL("image/jpeg", 0.82);
                db.settings.put({ key: "profilePicture", value: resized });
            };
            img.src = dataUrl;
        };
        reader.readAsDataURL(file);
        // Reset so selecting the same file triggers onChange again
        e.target.value = "";
    };

    // Recommendations
    const [recs, setRecs]               = useState<Song[]>([]);
    const [recsBasedOn, setRecsBasedOn] = useState("");
    const [recsLoading, setRecsLoading] = useState(false);
    const fetchedForRef = useRef<string | null>(null);

    useEffect(() => {
        if (!recentlyPlayed || recentlyPlayed.length === 0) return;
        const latest = recentlyPlayed[0];
        if (fetchedForRef.current === latest.song.id) return;
        fetchedForRef.current = latest.song.id;
        setRecsBasedOn(latest.song.title);
        setRecsLoading(true);
        fetch(`/api/recommendations?id=${latest.song.id}`)
            .then((r) => r.json())
            .then((d) => setRecs(d.songs || []))
            .catch(() => setRecs([]))
            .finally(() => setRecsLoading(false));
    }, [recentlyPlayed]);

    // ── Stats ──────────────────────────────────────────────────────────────────
    const totalPlays = recentlyPlayed?.length ?? 0;
    const totalLiked = likedSongs?.length ?? 0;
    const listenSecs = recentlyPlayed?.reduce((s, r) => s + (r.song.duration ?? 0), 0) ?? 0;

    // Listening streak — count consecutive days going backward from today
    const streak = (() => {
        if (!recentlyPlayed || recentlyPlayed.length === 0) return 0;
        const fmt = (ms: number) => {
            const d = new Date(ms);
            return `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
        };
        const days = new Set(recentlyPlayed.map((r) => fmt(r.playedAt)));
        let count = 0;
        for (let i = 0; ; i++) {
            const d = new Date();
            d.setDate(d.getDate() - i);
            if (days.has(fmt(d.getTime()))) count++;
            else break;
        }
        return count;
    })();

    // Music Wrapped data
    const firstEver = recentlyPlayed && recentlyPlayed.length > 0
        ? [...recentlyPlayed].sort((a, b) => a.playedAt - b.playedAt)[0]
        : null;

    const artistCount: Record<string, number> = {};
    recentlyPlayed?.forEach((r) => {
        const a = r.song.artist.split(",")[0].trim();
        artistCount[a] = (artistCount[a] ?? 0) + 1;
    });
    likedSongs?.forEach((r) => {
        const a = r.song.artist.split(",")[0].trim();
        artistCount[a] = (artistCount[a] ?? 0) + 0.5;
    });
    const topArtists = Object.entries(artistCount)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([name]) => name);

    const hasData = totalPlays > 0 || totalLiked > 0;

    return (
        <div className="max-w-4xl mx-auto pb-16 space-y-12 font-kalam">

            {/* Hidden file input */}
            <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                className="hidden"
                onChange={handleFileChange}
            />

            {/* ── Profile Header ─────────────────────────────────────────── */}
            <div className="flex flex-col sm:flex-row items-center sm:items-start gap-8">

                {/* Avatar polaroid — tap to change */}
                <motion.div
                    whileHover={{ scale: 1.03 }}
                    whileTap={{ scale: 0.97 }}
                    onClick={handleAvatarClick}
                    className="w-48 bg-white p-3 pb-10 shadow-[0_10px_30px_-5px_rgba(0,0,0,0.2)] transform -rotate-2 flex-shrink-0 relative cursor-pointer group"
                    title="Tap to change photo"
                >
                    <div className="absolute -top-2 left-1/2 -translate-x-1/2 tape-strip w-16" />

                    {/* Image or placeholder */}
                    <div className="w-full aspect-square overflow-hidden relative">
                        {profilePic ? (
                            <img src={profilePic} alt="Profile" className="w-full h-full object-cover" />
                        ) : (
                            <div className="w-full h-full bg-gradient-to-br from-orange-400 to-pink-500 flex items-center justify-center">
                                <Music4 className="w-16 h-16 text-white" strokeWidth={1.5} />
                            </div>
                        )}
                        {/* Camera overlay on hover */}
                        <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex flex-col items-center justify-center gap-1">
                            <Camera className="w-8 h-8 text-white" />
                            <span className="text-white text-xs font-caveat font-bold">Change photo</span>
                        </div>
                    </div>

                    <p className="text-center font-caveat text-sm text-gray-500 mt-3">tap to change</p>
                </motion.div>

                {/* Name + stats */}
                <div className="flex-1 flex flex-col justify-center gap-4">

                    {/* Display name */}
                    <div className="transform rotate-1">
                        {editingName ? (
                            <div className="flex items-center gap-2">
                                <input
                                    ref={nameInputRef}
                                    value={nameInput}
                                    onChange={(e) => setNameInput(e.target.value)}
                                    onKeyDown={(e) => { if (e.key === "Enter") saveName(); if (e.key === "Escape") setEditingName(false); }}
                                    onBlur={saveName}
                                    placeholder="your name"
                                    className="font-caveat text-4xl font-bold text-gray-900 bg-transparent border-b-2 border-orange-500 outline-none w-full lowercase"
                                    maxLength={24}
                                />
                                <button onClick={saveName} className="text-orange-500 hover:scale-110 transition-transform flex-shrink-0">
                                    <Check className="w-6 h-6" />
                                </button>
                            </div>
                        ) : (
                            <div className="flex items-center gap-3 group cursor-pointer" onClick={startEditName}>
                                <span className="font-caveat text-4xl sm:text-5xl font-bold text-gray-900 leading-tight">
                                    {displayName ? `hey, ${displayName} 👋` : "Hey, listener. 👋"}
                                </span>
                                <Pencil className="w-5 h-5 text-gray-400 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0" />
                            </div>
                        )}
                        <span className="font-caveat text-lg text-gray-500 mt-1 block">
                            Here's your music world at a glance.
                        </span>
                    </div>

                    {/* Stat pills */}
                    <div className="flex flex-wrap gap-3 mt-2">
                        <div className="flex items-center gap-2 bg-white px-4 py-2 rounded-full shadow-sm border border-gray-200">
                            <span className="text-orange-500 text-base">🎧</span>
                            <span className="text-sm font-bold text-gray-700">{totalPlays} plays</span>
                        </div>
                        <div className="flex items-center gap-2 bg-white px-4 py-2 rounded-full shadow-sm border border-gray-200">
                            <Heart className="w-4 h-4 text-red-500" fill="currentColor" />
                            <span className="text-sm font-bold text-gray-700">{totalLiked} liked</span>
                        </div>
                        {listenSecs > 0 && (
                            <div className="flex items-center gap-2 bg-white px-4 py-2 rounded-full shadow-sm border border-gray-200">
                                <Clock className="w-4 h-4 text-blue-500" />
                                <span className="text-sm font-bold text-gray-700">{fmtDuration(listenSecs)} listened</span>
                            </div>
                        )}
                        {streak > 0 && (
                            <div className="flex items-center gap-2 bg-orange-500 px-4 py-2 rounded-full shadow-sm">
                                <Zap className="w-4 h-4 text-white" fill="white" />
                                <span className="text-sm font-bold text-white">{streak} day streak 🔥</span>
                            </div>
                        )}
                    </div>
                </div>
            </div>

            {!hasData && (
                <div className="text-center py-16 font-caveat">
                    <Music4 className="w-16 h-16 text-gray-300 mx-auto mb-4" />
                    <p className="text-2xl text-gray-400">Start listening to see your stats here!</p>
                </div>
            )}

            {/* ── Music Wrapped ───────────────────────────────────────────── */}
            {hasData && (
                <section>
                    <div className="flex items-center gap-2 mb-6 transform rotate-1 w-fit">
                        <Trophy className="w-5 h-5 text-orange-500" />
                        <h2 className="font-caveat text-3xl font-bold text-gray-900">Your Dew Wrapped</h2>
                    </div>
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                        {/* Songs explored */}
                        <div className="bg-yellow-300 p-4 shadow-lg transform -rotate-1 relative">
                            <div className="absolute -top-2 left-1/2 -translate-x-1/2 tape-strip w-10" />
                            <Star className="w-6 h-6 text-gray-800 mb-2" fill="currentColor" />
                            <p className="font-caveat text-4xl font-bold text-gray-900">{totalPlays}</p>
                            <p className="font-caveat text-sm text-gray-700 mt-1">songs explored</p>
                        </div>
                        {/* Listening time */}
                        <div className="bg-cyan-300 p-4 shadow-lg transform rotate-2 relative">
                            <div className="absolute -top-2 right-4 w-3 h-3 bg-red-500 rounded-full shadow" />
                            <Clock className="w-6 h-6 text-gray-800 mb-2" />
                            <p className="font-caveat text-4xl font-bold text-gray-900">{fmtDuration(listenSecs)}</p>
                            <p className="font-caveat text-sm text-gray-700 mt-1">of music</p>
                        </div>
                        {/* Loved songs */}
                        <div className="bg-pink-400 p-4 shadow-lg transform -rotate-2 relative">
                            <div className="absolute -top-2 left-1/2 -translate-x-1/2 tape-strip w-10" />
                            <Heart className="w-6 h-6 text-white mb-2" fill="white" />
                            <p className="font-caveat text-4xl font-bold text-white">{totalLiked}</p>
                            <p className="font-caveat text-sm text-white/80 mt-1">songs loved</p>
                        </div>
                        {/* Streak / first song */}
                        <div className="bg-white border-2 border-gray-200 p-4 shadow-lg transform rotate-1 relative">
                            <div className="absolute -top-2 right-4 w-3 h-3 bg-orange-400 rounded-full shadow" />
                            <Zap className="w-6 h-6 text-orange-500 mb-2" fill="currentColor" />
                            <p className="font-caveat text-4xl font-bold text-gray-900">{streak}</p>
                            <p className="font-caveat text-sm text-gray-600 mt-1">day streak</p>
                        </div>
                    </div>
                    {firstEver && (
                        <div className="mt-6 bg-white border border-gray-200 rounded-xl p-4 shadow-sm flex items-center gap-4">
                            <img src={firstEver.song.image} alt="" className="w-12 h-12 object-cover rounded-lg flex-shrink-0" />
                            <div className="min-w-0">
                                <p className="font-caveat text-sm text-gray-500">Your first song on Dew:</p>
                                <p className="font-caveat text-xl font-bold text-gray-900 truncate">{firstEver.song.title}</p>
                                <p className="font-caveat text-sm text-orange-500 truncate">{firstEver.song.artist.split(",")[0]}</p>
                            </div>
                        </div>
                    )}
                </section>
            )}

            {/* ── Top Artists ────────────────────────────────────────────── */}
            {topArtists.length > 0 && (
                <section>
                    <div className="flex items-center gap-2 mb-6 transform -rotate-1 w-fit">
                        <Flame className="w-5 h-5 text-orange-500" />
                        <h2 className="font-caveat text-3xl font-bold text-gray-900">Your Top Artists</h2>
                    </div>
                    <div className="flex flex-wrap gap-6">
                        {topArtists.map((artist, i) => (
                            <Link key={artist} href={`/artist/${encodeURIComponent(artist)}`}>
                                <motion.div
                                    whileHover={{ scale: 1.08, zIndex: 10 }}
                                    whileTap={{ scale: 0.96 }}
                                    className={`${STICKY_COLORS[i % STICKY_COLORS.length]} ${STICKY_ROTS[i % STICKY_ROTS.length]} px-5 py-4 shadow-lg cursor-pointer relative font-caveat`}
                                >
                                    <div className="absolute -top-2 left-1/2 -translate-x-1/2 tape-strip w-10" />
                                    <p className="text-xl font-bold text-gray-900 whitespace-nowrap">{artist}</p>
                                    <p className="text-xs text-gray-600 mt-1">#{i + 1} most played</p>
                                </motion.div>
                            </Link>
                        ))}
                    </div>
                </section>
            )}

            {/* ── For You ────────────────────────────────────────────────── */}
            {(recs.length > 0 || recsLoading) && (
                <section>
                    <div className="mb-6 transform rotate-1 w-fit">
                        <h2 className="font-caveat text-3xl font-bold text-gray-900">For You</h2>
                        {recsBasedOn && (
                            <p className="font-caveat text-sm text-gray-500 mt-0.5">
                                because you listened to <span className="text-orange-600 font-bold">{recsBasedOn}</span>
                            </p>
                        )}
                    </div>

                    {recsLoading ? (
                        <div className="flex gap-4 overflow-x-auto pb-4 snap-x scrollbar-hide">
                            {Array.from({ length: 5 }).map((_, i) => (
                                <div key={i} className="flex-shrink-0 w-36 snap-start">
                                    <div className="w-36 h-36 bg-gray-200 animate-pulse rounded-sm" />
                                    <div className="h-4 bg-gray-200 animate-pulse mt-3 rounded w-4/5" />
                                </div>
                            ))}
                        </div>
                    ) : (
                        <div className="flex gap-5 overflow-x-auto pb-4 snap-x scrollbar-hide">
                            {recs.map((song, i) => (
                                <motion.div
                                    key={song.id}
                                    whileHover={{ scale: 1.04 }}
                                    whileTap={{ scale: 0.97 }}
                                    className="flex-shrink-0 w-36 snap-start cursor-pointer group"
                                    onClick={() => playQueue(recs, i)}
                                >
                                    <div className="bg-white p-2 pb-10 shadow-md relative">
                                        <img src={song.image} alt={song.title} className="w-full aspect-square object-cover" />
                                        <div className="absolute inset-2 bottom-10 bg-black/30 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                                            {currentSong?.id === song.id && isPlaying
                                                ? <Pause className="w-8 h-8 text-white" fill="currentColor" />
                                                : <Play className="w-8 h-8 text-white ml-1" fill="currentColor" />
                                            }
                                        </div>
                                        <p className="absolute bottom-2 left-2 right-2 text-center font-caveat text-xs font-bold text-gray-700 truncate">{song.title}</p>
                                    </div>
                                    <p className="font-caveat text-xs text-gray-500 mt-2 truncate text-center">{song.artist}</p>
                                </motion.div>
                            ))}
                        </div>
                    )}
                </section>
            )}

            {/* ── Recently Played ────────────────────────────────────────── */}
            {recentlyPlayed && recentlyPlayed.length > 0 && (
                <section>
                    <div className="flex items-center gap-2 mb-6 transform -rotate-1 w-fit">
                        <Clock className="w-5 h-5 text-gray-700" />
                        <h2 className="font-caveat text-3xl font-bold text-gray-900">Recently Played</h2>
                    </div>

                    <div
                        className="bg-[#fdfaf6] shadow-md border-l-4 border-pink-300 pl-8 pr-6 py-6 relative"
                        style={{
                            backgroundImage: `repeating-linear-gradient(transparent, transparent 39px, #bae6fd 39px, #bae6fd 40px)`,
                            backgroundPosition: "0 10px",
                        }}
                    >
                        <div className="absolute left-3 top-8 w-3 h-3 bg-gray-200 rounded-full shadow-inner border border-gray-300" />
                        <div className="absolute left-3 top-1/2 w-3 h-3 bg-gray-200 rounded-full shadow-inner border border-gray-300" />

                        <div className="space-y-0">
                            {recentlyPlayed.slice(0, 12).map((entry, i) => {
                                const isActive = currentSong?.id === entry.song.id;
                                return (
                                    <motion.div
                                        key={entry.songId}
                                        whileHover={{ x: 4 }}
                                        className="flex items-center gap-4 py-2 cursor-pointer group"
                                        style={{ height: "40px" }}
                                        onClick={() => {
                                            if (isActive) togglePlay();
                                            else playQueue(recentlyPlayed.slice(0, 12).map((e) => e.song), i);
                                        }}
                                    >
                                        <span className="font-caveat text-sm text-gray-400 w-5 text-right flex-shrink-0">{i + 1}</span>
                                        <img src={entry.song.image} alt="" className="w-7 h-7 object-cover rounded-sm flex-shrink-0 shadow-sm" />
                                        <div className="flex-1 min-w-0 flex items-center gap-2">
                                            <span className={`font-caveat text-lg font-bold truncate ${isActive ? "text-orange-600" : "text-gray-900 group-hover:text-orange-600"} transition-colors`}>
                                                {entry.song.title}
                                            </span>
                                            {isActive && isPlaying && (
                                                <span className="flex gap-0.5 items-end flex-shrink-0">
                                                    {[3, 5, 4].map((h, k) => (
                                                        <motion.span
                                                            key={k}
                                                            className="w-0.5 bg-orange-500 rounded-full"
                                                            animate={{ height: [`${h}px`, "12px", `${h}px`] }}
                                                            transition={{ repeat: Infinity, duration: 0.7 + k * 0.15, ease: "easeInOut" }}
                                                        />
                                                    ))}
                                                </span>
                                            )}
                                        </div>
                                        <span className="font-caveat text-sm text-gray-400 flex-shrink-0 hidden sm:block truncate max-w-[120px]">
                                            {entry.song.artist.split(",")[0]}
                                        </span>
                                        <span className="font-caveat text-xs text-gray-400 flex-shrink-0">{timeAgo(entry.playedAt)}</span>
                                    </motion.div>
                                );
                            })}
                        </div>
                    </div>
                </section>
            )}

            {/* ── Liked Songs ────────────────────────────────────────────── */}
            {likedSongs && likedSongs.length > 0 && (
                <section>
                    <div className="flex items-center gap-2 mb-5 transform rotate-1 w-fit">
                        <Heart className="w-5 h-5 text-red-500" fill="currentColor" />
                        <h2 className="font-caveat text-3xl font-bold text-gray-900">Songs You Love</h2>
                    </div>
                    <div className="flex gap-4 overflow-x-auto pb-3 snap-x scrollbar-hide">
                        {likedSongs.slice(0, 10).map((entry, i) => (
                            <motion.div
                                key={entry.songId}
                                whileHover={{ scale: 1.05 }}
                                whileTap={{ scale: 0.97 }}
                                className="flex-shrink-0 flex items-center gap-3 bg-white px-4 py-3 rounded-xl shadow-sm border border-gray-100 cursor-pointer group snap-start"
                                onClick={() => playQueue(likedSongs.map((e) => e.song), i)}
                            >
                                <img src={entry.song.image} alt="" className="w-10 h-10 object-cover rounded-sm flex-shrink-0" />
                                <div className="min-w-0">
                                    <p className="font-caveat text-base font-bold text-gray-900 truncate group-hover:text-orange-600 transition-colors max-w-[120px]">{entry.song.title}</p>
                                    <p className="font-caveat text-xs text-gray-500 truncate max-w-[120px]">{entry.song.artist.split(",")[0]}</p>
                                </div>
                                <Heart className="w-4 h-4 text-red-400 flex-shrink-0" fill="currentColor" />
                            </motion.div>
                        ))}
                    </div>
                </section>
            )}

        </div>
    );
}
