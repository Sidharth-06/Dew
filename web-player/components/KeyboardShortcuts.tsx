"use client";

import { useEffect } from "react";
import { useAudio } from "./AudioProvider";
import { db } from "@/lib/db/database";

// Global keyboard shortcuts:
//   Space           → Play / Pause
//   Alt + →         → Skip next
//   Alt + ←         → Skip previous
//   L               → Toggle like on current song
export default function KeyboardShortcuts() {
    const { togglePlay, skipNext, skipPrevious, currentSong } = useAudio();

    useEffect(() => {
        const handleKey = (e: KeyboardEvent) => {
            const tag = (e.target as HTMLElement).tagName;
            if (tag === "INPUT" || tag === "TEXTAREA") return;

            if (e.code === "Space") {
                e.preventDefault();
                togglePlay();
            } else if (e.code === "ArrowRight" && e.altKey) {
                e.preventDefault();
                skipNext();
            } else if (e.code === "ArrowLeft" && e.altKey) {
                e.preventDefault();
                skipPrevious();
            } else if (e.code === "KeyL" && !e.metaKey && !e.ctrlKey) {
                if (!currentSong) return;
                db.likedSongs.get(currentSong.id).then((liked) => {
                    if (liked) db.likedSongs.delete(currentSong.id);
                    else db.likedSongs.put({ songId: currentSong.id, song: currentSong, addedAt: Date.now() });
                });
            }
        };
        window.addEventListener("keydown", handleKey);
        return () => window.removeEventListener("keydown", handleKey);
    }, [togglePlay, skipNext, skipPrevious, currentSong]);

    return null;
}
