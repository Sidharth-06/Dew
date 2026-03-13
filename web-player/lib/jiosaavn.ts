// saavn.dev — public JioSaavn API wrapper (works from Vercel / any server)
const SAAVN_API = "https://saavn.dev";

// ─── Types ───────────────────────────────────────────────────────────────────

export interface Song {
    id: string;
    title: string;
    artist: string;
    album: string;
    image: string;
    duration: number;
    url: string;
    year?: string;
    language?: string;
    hasLyrics?: boolean;
}

export interface Playlist {
    id: string;
    title: string;
    image: string;
    subtitle?: string;
    type: string;
    songCount?: number;
}

interface SaavnArtist {
    name: string;
}

interface SaavnImageItem {
    quality: string;
    url: string;
}

interface SaavnDownloadUrl {
    quality: string;
    url: string;
}

interface SaavnSong {
    id: string;
    name: string;
    year?: string;
    duration?: number;
    language?: string;
    hasLyrics?: boolean;
    image?: SaavnImageItem[];
    downloadUrl?: SaavnDownloadUrl[];
    artists?: {
        primary?: SaavnArtist[];
        featured?: SaavnArtist[];
        all?: SaavnArtist[];
    };
    album?: { name?: string };
}

interface SaavnPlaylist {
    id: string;
    name: string;
    description?: string;
    songCount?: number;
    image?: SaavnImageItem[];
    songs?: SaavnSong[];
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function getBestImage(images?: SaavnImageItem[]): string {
    if (!images?.length) return "";
    return (
        images.find((i) => i.quality === "500x500")?.url ||
        images[images.length - 1].url
    );
}

function formatSong(s: SaavnSong): Song | null {
    try {
        const artistNames =
            s.artists?.primary?.map((a) => a.name) ||
            s.artists?.featured?.map((a) => a.name) ||
            s.artists?.all?.map((a) => a.name) ||
            ["Unknown"];

        const url =
            s.downloadUrl?.find((d) => d.quality === "320kbps")?.url ||
            s.downloadUrl?.[s.downloadUrl.length - 1]?.url ||
            "";

        return {
            id: s.id,
            title: s.name || "",
            artist: artistNames.join(", "),
            album: s.album?.name || "",
            image: getBestImage(s.image),
            duration: s.duration || 0,
            url,
            year: s.year,
            language: s.language,
            hasLyrics: s.hasLyrics,
        };
    } catch {
        return null;
    }
}

async function saavnGet<T>(path: string, revalidate = 300): Promise<T> {
    const res = await fetch(`${SAAVN_API}${path}`, {
        headers: { Accept: "application/json" },
        next: { revalidate },
    });
    if (!res.ok) {
        throw new Error(`saavn.dev ${res.status} for ${path}`);
    }
    const json = await res.json();
    if (json.data === undefined) {
        throw new Error(`saavn.dev: unexpected response for ${path}`);
    }
    return json.data as T;
}

// ─── Public API Functions ────────────────────────────────────────────────────

export async function searchSongs(query: string, count = 20): Promise<Song[]> {
    const data = await saavnGet<{ results: SaavnSong[] }>(
        `/api/search/songs?query=${encodeURIComponent(query)}&limit=${count}`,
        60
    );
    return (data.results || []).map(formatSong).filter(Boolean) as Song[];
}

export async function getSongDetails(songId: string): Promise<Song | null> {
    const data = await saavnGet<SaavnSong[]>(`/api/songs?id=${songId}`, 3600);
    return data?.[0] ? formatSong(data[0]) : null;
}

interface HomeSection {
    title: string;
    type: "songs" | "playlists";
    items: (Song | Playlist)[];
}

export async function fetchHomePageData(): Promise<HomeSection[]> {
    const [trendingRes, playlistsRes, albumsRes] = await Promise.allSettled([
        saavnGet<{ results: SaavnSong[] }>(
            `/api/search/songs?query=trending+hindi+2025&limit=20`,
            600
        ),
        saavnGet<{ results: SaavnPlaylist[] }>(
            `/api/search/playlists?query=top+charts&limit=10`,
            600
        ),
        saavnGet<{ results: SaavnPlaylist[] }>(
            `/api/search/albums?query=new+releases+2025&limit=10`,
            600
        ),
    ]);

    const sections: HomeSection[] = [];

    if (trendingRes.status === "fulfilled") {
        const songs = (trendingRes.value.results || [])
            .map(formatSong)
            .filter(Boolean) as Song[];
        if (songs.length > 0) {
            sections.push({ title: "Trending Now", type: "songs", items: songs });
        }
    }

    if (playlistsRes.status === "fulfilled") {
        const playlists = (playlistsRes.value.results || []).map(
            (p): Playlist => ({
                id: p.id,
                title: p.name,
                image: getBestImage(p.image),
                subtitle: p.description,
                type: "playlist",
                songCount: p.songCount,
            })
        );
        if (playlists.length > 0) {
            sections.push({ title: "Top Playlists", type: "playlists", items: playlists });
        }
    }

    if (albumsRes.status === "fulfilled") {
        const playlists = (albumsRes.value.results || []).map(
            (p): Playlist => ({
                id: p.id,
                title: p.name,
                image: getBestImage(p.image),
                subtitle: p.description,
                type: "album",
                songCount: p.songCount,
            })
        );
        if (playlists.length > 0) {
            sections.push({ title: "New Releases", type: "playlists", items: playlists });
        }
    }

    return sections;
}

export async function fetchPlaylistSongs(playlistId: string): Promise<{
    songs: Song[];
    title: string;
    image: string;
}> {
    const data = await saavnGet<SaavnPlaylist>(
        `/api/playlists?id=${playlistId}`,
        1800
    );
    return {
        songs: (data.songs || []).map(formatSong).filter(Boolean) as Song[],
        title: data.name || "",
        image: getBestImage(data.image),
    };
}

export async function fetchAlbumSongs(albumId: string): Promise<{
    songs: Song[];
    title: string;
    image: string;
}> {
    const data = await saavnGet<SaavnPlaylist>(
        `/api/albums?id=${albumId}`,
        1800
    );
    return {
        songs: (data.songs || []).map(formatSong).filter(Boolean) as Song[],
        title: data.name || "",
        image: getBestImage(data.image),
    };
}

export async function getSearchSuggestions(query: string): Promise<string[]> {
    try {
        const data = await saavnGet<{ results: SaavnSong[] }>(
            `/api/search/songs?query=${encodeURIComponent(query)}&limit=5`,
            60
        );
        return (data.results || []).map((s) => s.name).filter(Boolean);
    } catch {
        return [];
    }
}

export async function getTopSearches(): Promise<string[]> {
    return [];
}

export async function getSongRecommendations(songId: string): Promise<Song[]> {
    try {
        const data = await saavnGet<SaavnSong[]>(
            `/api/songs/${songId}/suggestions?limit=10`,
            300
        );
        return (Array.isArray(data) ? data : [])
            .map(formatSong)
            .filter(Boolean) as Song[];
    } catch {
        return [];
    }
}
