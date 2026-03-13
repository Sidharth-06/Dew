"use client";

import { useEffect, useRef } from "react";
import { db } from "@/lib/db/database";
import { Song } from "@/lib/jiosaavn";

interface StoredPlaylist {
    id: string;
    title: string;
    songs: Song[];
    createdAt?: number;
}

interface LibraryState {
    likedSongs: Song[];
    recentlyPlayed: Song[];
    customPlaylists: StoredPlaylist[];
}

interface ParsedStore {
    state?: LibraryState;
}

export function DatabaseMigrator({ children }: { children: React.ReactNode }) {
    const hasMigrated = useRef(false);

    useEffect(() => {
        const migrateData = async () => {
            if (hasMigrated.current) return;
            hasMigrated.current = true;

            try {
                const rawZustand = localStorage.getItem("dew-library-storage");
                if (!rawZustand) return; // Nothing to migrate, or already migrated

                const parsedStore: ParsedStore = JSON.parse(rawZustand);
                const { state } = parsedStore;

                if (!state) return;

                // Migrate Liked Songs
                if (state.likedSongs && Array.isArray(state.likedSongs)) {
                    const likedToImport = state.likedSongs.map((song: Song, index: number) => ({
                        songId: song.id,
                        song: song,
                        addedAt: Date.now() - index * 1000, // Preserve rough ordering 
                    }));

                    await db.likedSongs.bulkPut(likedToImport);
                }

                // Migrate Recently Played
                if (state.recentlyPlayed && Array.isArray(state.recentlyPlayed)) {
                    const recentToImport = state.recentlyPlayed.map((song: Song, index: number) => ({
                        songId: song.id,
                        song: song,
                        playedAt: Date.now() - index * 1000,
                    }));

                    await db.recentlyPlayed.bulkPut(recentToImport);
                }

                // Migrate Custom Playlists
                if (state.customPlaylists && Array.isArray(state.customPlaylists)) {
                    for (const playlist of state.customPlaylists) {
                        await db.playlists.put({
                            id: playlist.id,
                            title: playlist.title,
                            createdAt: playlist.createdAt || Date.now()
                        });

                        if (playlist.songs && Array.isArray(playlist.songs)) {
                            const playlistSongsToImport = playlist.songs.map((song: Song, index: number) => ({
                                playlistId: playlist.id,
                                songId: song.id,
                                song: song,
                                addedAt: Date.now() - index * 1000,
                            }));

                            await db.playlistSongs.bulkPut(playlistSongsToImport);
                        }
                    }
                }

                console.log("Successfully migrated LocalStorage to IndexedDB Dexie");

                // Clear local storage so we don't migrate again and free up the 5MB limit
                localStorage.removeItem("dew-library-storage");

            } catch (error) {
                console.error("Failed to migrate data to IndexedDB:", error);
            }
        };

        migrateData();
    }, []);

    return <>{children}</>;
}
