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

export interface UserSetting {
    key: string;   // primary key — e.g. "profilePicture", "displayName"
    value: string; // stringified or base64 dataURL
}

export class DewDatabase extends Dexie {
    likedSongs!: Table<LikedSong, string>;
    recentlyPlayed!: Table<RecentlyPlayed, string>;
    playlists!: Table<Playlist, string>;
    playlistSongs!: Table<PlaylistSong, [string, string]>;
    settings!: Table<UserSetting, string>;

    constructor() {
        super('DewMusicDB');
        this.version(1).stores({
            likedSongs: 'songId, addedAt',
            recentlyPlayed: 'songId, playedAt',
            playlists: 'id, title, createdAt',
            playlistSongs: '[playlistId+songId], playlistId, songId, addedAt'
        });
        this.version(2).stores({
            likedSongs: 'songId, addedAt',
            recentlyPlayed: 'songId, playedAt',
            playlists: 'id, title, createdAt',
            playlistSongs: '[playlistId+songId], playlistId, songId, addedAt',
            settings: 'key'
        });
    }
}

export const db = new DewDatabase();
