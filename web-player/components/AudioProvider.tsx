"use client";

import React, {
    createContext,
    useContext,
    useState,
    useRef,
    useCallback,
    useEffect,
} from "react";
import { db } from "@/lib/db/database";

export interface Song {
    id: string;
    title: string;
    artist: string;
    album: string;
    image: string;
    duration: number;
    url: string;
    hasLyrics?: boolean;
}

interface AudioContextType {
    currentSong: Song | null;
    isPlaying: boolean;
    progress: number;
    duration: number;
    volume: number;
    queue: Song[];
    queueIndex: number;
    shuffle: boolean;
    repeat: "off" | "all" | "one";
    playSong: (song: Song) => void;
    playQueue: (songs: Song[], startIndex?: number) => void;
    addToQueue: (song: Song) => void;
    togglePlay: () => void;
    seek: (time: number) => void;
    setVolume: (vol: number) => void;
    skipNext: () => void;
    skipPrevious: () => void;
    toggleShuffle: () => void;
    toggleRepeat: () => void;
    removeFromQueue: (index: number) => void;
}

const AudioContext = createContext<AudioContextType | null>(null);

export function useAudio() {
    const ctx = useContext(AudioContext);
    if (!ctx) throw new Error("useAudio must be used within AudioProvider");
    return ctx;
}

export function AudioProvider({ children }: { children: React.ReactNode }) {
    const audioRef = useRef<HTMLAudioElement | null>(null);
    const [currentSong, setCurrentSong] = useState<Song | null>(null);
    const [isPlaying, setIsPlaying] = useState(false);
    const [progress, setProgress] = useState(0);
    const [duration, setDuration] = useState(0);
    const [volume, setVolumeState] = useState(0.8);
    const [queue, setQueue] = useState<Song[]>([]);
    const [queueIndex, setQueueIndex] = useState(-1);
    const [shuffle, setShuffle] = useState(false);
    const [repeat, setRepeat] = useState<"off" | "all" | "one">("off");

    // Initialize audio element
    useEffect(() => {
        if (!audioRef.current) {
            audioRef.current = new Audio();
            audioRef.current.volume = 0.8;
        }

        const audio = audioRef.current;

        const onTimeUpdate = () => setProgress(audio.currentTime);
        const onDurationChange = () => setDuration(audio.duration || 0);
        const onEnded = () => handleSongEnd();
        const onPlay = () => setIsPlaying(true);
        const onPause = () => setIsPlaying(false);

        audio.addEventListener("timeupdate", onTimeUpdate);
        audio.addEventListener("durationchange", onDurationChange);
        audio.addEventListener("ended", onEnded);
        audio.addEventListener("play", onPlay);
        audio.addEventListener("pause", onPause);

        return () => {
            audio.removeEventListener("timeupdate", onTimeUpdate);
            audio.removeEventListener("durationchange", onDurationChange);
            audio.removeEventListener("ended", onEnded);
            audio.removeEventListener("play", onPlay);
            audio.removeEventListener("pause", onPause);
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    const handleSongEnd = useCallback(() => {
        if (repeat === "one") {
            if (audioRef.current) {
                audioRef.current.currentTime = 0;
                audioRef.current.play();
            }
            return;
        }

        setQueueIndex((prev) => {
            const next = shuffle
                ? Math.floor(Math.random() * queue.length)
                : prev + 1;

            if (next >= queue.length) {
                if (repeat === "all") {
                    return 0;
                }
                setIsPlaying(false);
                return prev;
            }
            return next;
        });
    }, [repeat, shuffle, queue.length]);

    // Play song when queueIndex changes
    useEffect(() => {
        if (queueIndex < 0 || queueIndex >= queue.length || !audioRef.current) return;

        let disposed = false;

        const playSelectedSong = async () => {
            let song = queue[queueIndex];

            // Some list APIs may not include playable URL; hydrate on demand.
            if (!song.url) {
                try {
                    const res = await fetch(`/api/song/${encodeURIComponent(song.id)}`, {
                        cache: "no-store",
                    });
                    if (res.ok) {
                        const fullSong = (await res.json()) as Song;
                        if (fullSong?.url) {
                            song = { ...song, url: fullSong.url };
                        }
                    }
                } catch (err) {
                    console.error("Failed to hydrate song URL", err);
                }
            }

            if (disposed) return;
            setCurrentSong(song);

            db.recentlyPlayed.put({
                songId: song.id,
                song: song,
                playedAt: Date.now()
            }).catch((e: Error) => console.error("Failed to save to recently played", e));

            if (!song.url) {
                console.error("Missing playable URL for song", song.id);
                return;
            }

            const audio = audioRef.current;
            if (!audio) return;
            audio.src = song.url;
            audio.play().catch((err) => {
                console.error("Audio playback failed", err);
            });
            updateMediaSession(song);
        };

        void playSelectedSong();

        return () => {
            disposed = true;
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [queueIndex, queue]);

    const updateMediaSession = (song: Song) => {
        if ("mediaSession" in navigator) {
            navigator.mediaSession.metadata = new MediaMetadata({
                title: song.title,
                artist: song.artist,
                album: song.album,
                artwork: [
                    { src: song.image, sizes: "500x500", type: "image/jpeg" },
                ],
            });
            navigator.mediaSession.setActionHandler("play", () => togglePlay());
            navigator.mediaSession.setActionHandler("pause", () => togglePlay());
            navigator.mediaSession.setActionHandler("previoustrack", () => skipPrevious());
            navigator.mediaSession.setActionHandler("nexttrack", () => skipNext());
        }
    };

    const playSong = useCallback((song: Song) => {
        setQueue([song]);
        setQueueIndex(0);
    }, []);

    const playQueue = useCallback((songs: Song[], startIndex = 0) => {
        setQueue(songs);
        setQueueIndex(startIndex);
    }, []);

    const addToQueue = useCallback((song: Song) => {
        setQueue((prev) => [...prev, song]);
    }, []);

    const togglePlay = useCallback(() => {
        if (!audioRef.current) return;
        if (audioRef.current.paused) {
            audioRef.current.play().catch(console.error);
        } else {
            audioRef.current.pause();
        }
    }, []);

    const seek = useCallback((time: number) => {
        if (audioRef.current) {
            audioRef.current.currentTime = time;
        }
    }, []);

    const setVolume = useCallback((vol: number) => {
        setVolumeState(vol);
        if (audioRef.current) {
            audioRef.current.volume = vol;
        }
    }, []);

    const skipNext = useCallback(() => {
        setQueueIndex((prev) => {
            if (shuffle) return Math.floor(Math.random() * queue.length);
            const next = prev + 1;
            if (next >= queue.length) return repeat === "all" ? 0 : prev;
            return next;
        });
    }, [shuffle, queue.length, repeat]);

    const skipPrevious = useCallback(() => {
        if (audioRef.current && audioRef.current.currentTime > 3) {
            audioRef.current.currentTime = 0;
            return;
        }
        setQueueIndex((prev) => {
            if (prev <= 0) return repeat === "all" ? queue.length - 1 : 0;
            return prev - 1;
        });
    }, [queue.length, repeat]);

    const toggleShuffle = useCallback(() => {
        setShuffle((prev) => !prev);
    }, []);

    const toggleRepeat = useCallback(() => {
        setRepeat((prev) => {
            if (prev === "off") return "all";
            if (prev === "all") return "one";
            return "off";
        });
    }, []);

    const removeFromQueue = useCallback(
        (index: number) => {
            setQueue((prev) => prev.filter((_, i) => i !== index));
            if (index < queueIndex) {
                setQueueIndex((prev) => prev - 1);
            } else if (index === queueIndex) {
                // If removing current, just skip
                skipNext();
            }
        },
        [queueIndex, skipNext]
    );

    return (
        <AudioContext.Provider
            value={{
                currentSong,
                isPlaying,
                progress,
                duration,
                volume,
                queue,
                queueIndex,
                shuffle,
                repeat,
                playSong,
                playQueue,
                addToQueue,
                togglePlay,
                seek,
                setVolume,
                skipNext,
                skipPrevious,
                toggleShuffle,
                toggleRepeat,
                removeFromQueue,
            }}
        >
            {children}
        </AudioContext.Provider>
    );
}
