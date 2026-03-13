import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { Song, Playlist } from '@/lib/jiosaavn';

interface CustomPlaylist {
    id: string;
    title: string;
    songs: Song[];
    createdAt: number;
}

interface LibraryState {
    likedSongs: Song[];
    recentlyPlayed: Song[];
    customPlaylists: CustomPlaylist[];

    // Actions
    toggleLikedSong: (song: Song) => void;
    isSongLiked: (songId: string) => boolean;
    addRecentlyPlayed: (song: Song) => void;
    createCustomPlaylist: (title: string) => void;
    addSongToPlaylist: (playlistId: string, song: Song) => void;
    removeSongFromPlaylist: (playlistId: string, songId: string) => void;
    deleteCustomPlaylist: (playlistId: string) => void;
}

export const useLibraryStore = create<LibraryState>()(
    persist(
        (set, get) => ({
            likedSongs: [],
            recentlyPlayed: [],
            customPlaylists: [],

            toggleLikedSong: (song) => {
                set((state) => {
                    const isLiked = state.likedSongs.some((s) => s.id === song.id);
                    if (isLiked) {
                        return { likedSongs: state.likedSongs.filter((s) => s.id !== song.id) };
                    } else {
                        return { likedSongs: [song, ...state.likedSongs] };
                    }
                });
            },

            isSongLiked: (songId: string) => {
                return get().likedSongs.some((s) => s.id === songId);
            },

            addRecentlyPlayed: (song) => {
                set((state) => {
                    const filtered = state.recentlyPlayed.filter((s) => s.id !== song.id);
                    return { recentlyPlayed: [song, ...filtered].slice(0, 50) };
                });
            },

            createCustomPlaylist: (title) => {
                set((state) => ({
                    customPlaylists: [
                        ...state.customPlaylists,
                        {
                            id: Date.now().toString(),
                            title,
                            songs: [],
                            createdAt: Date.now(),
                        },
                    ],
                }));
            },

            addSongToPlaylist: (playlistId, song) => {
                set((state) => ({
                    customPlaylists: state.customPlaylists.map((p) => {
                        if (p.id === playlistId && !p.songs.some((s) => s.id === song.id)) {
                            return { ...p, songs: [...p.songs, song] };
                        }
                        return p;
                    }),
                }));
            },

            removeSongFromPlaylist: (playlistId, songId) => {
                set((state) => ({
                    customPlaylists: state.customPlaylists.map((p) => {
                        if (p.id === playlistId) {
                            return { ...p, songs: p.songs.filter((s) => s.id !== songId) };
                        }
                        return p;
                    }),
                }));
            },

            deleteCustomPlaylist: (playlistId: string) => {
                set((state) => ({
                    customPlaylists: state.customPlaylists.filter((p) => p.id !== playlistId)
                }));
            }
        }),
        {
            name: 'dew-library-storage', // unique name
            storage: createJSONStorage(() => localStorage),
        }
    )
);
