import Dexie, { type Table } from 'dexie';
import { Song } from '@/lib/jiosaavn';

export interface LikedSong {
    songId: string;
    song: Song;
    addedAt: number;
}

export interface RecentlyPlayed {
    songId: string;
    song: Song;
    playedAt: number;
}

export interface Playlist {
    id: string;
    title: string;
    createdAt: number;
}

export interface PlaylistSong {
    playlistId: string;
    songId: string;
    song: Song;
    addedAt: number;
}

export class DewDatabase extends Dexie {
    likedSongs!: Table<LikedSong, string>;
    recentlyPlayed!: Table<RecentlyPlayed, string>; // Using string (songId) as primary key to ensure uniqueness
    playlists!: Table<Playlist, string>;
    playlistSongs!: Table<PlaylistSong, [string, string]>; // Compound primary key [playlistId, songId]

    constructor() {
        super('DewMusicDB');
        this.version(1).stores({
            likedSongs: 'songId, addedAt',
            recentlyPlayed: 'songId, playedAt',
            playlists: 'id, title, createdAt',
            playlistSongs: '[playlistId+songId], playlistId, songId, addedAt'
        });
    }
}

export const db = new DewDatabase();
