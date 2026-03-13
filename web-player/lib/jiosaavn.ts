import crypto from "crypto";

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

// ─── DES Decryption ──────────────────────────────────────────────────────────
// JioSaavn encrypts stream URLs with DES-ECB. OpenSSL 3+ (Node 18+) disables
// legacy DES, so we use 3DES with K1=K2=K3 which is mathematically identical.
const DES_KEY = "38346591";
const TRIPLE_DES_KEY = Buffer.from(DES_KEY.repeat(3), "utf8");

function decryptMediaUrl(encryptedUrl: string): string {
    if (!encryptedUrl) return "";
    try {
        const encrypted = Buffer.from(encryptedUrl, "base64");
        const decipher = crypto.createDecipheriv("des-ede3", TRIPLE_DES_KEY, null);
        decipher.setAutoPadding(true);
        let decrypted = decipher.update(encrypted, undefined, "utf8");
        decrypted += decipher.final("utf8");
        return decrypted
            .replace(/\.mp4.*/, ".mp4")
            .replace(/\.m4a.*/, ".m4a")
            .replace(/^http:/, "https:");
    } catch {
        return "";
    }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function unescape(text: string | undefined | null): string {
    if (!text) return "";
    return text
        .replace(/&amp;/g, "&")
        .replace(/&#039;/g, "'")
        .replace(/&quot;/g, '"')
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">");
}

function getImageUrl(url: string, quality: "low" | "medium" | "high" = "high"): string {
    const sizes: Record<string, string> = { low: "150x150", medium: "350x350", high: "500x500" };
    return url.replace(/150x150|50x50/, sizes[quality]);
}

// ─── JioSaavn API ────────────────────────────────────────────────────────────

const BASE_URL = "https://www.jiosaavn.com";
const API_PATH = "/api.php?_format=json&_marker=0&api_version=4&ctx=web6dot0";

const ENDPOINTS: Record<string, string> = {
    homeData: "__call=webapi.getLaunchData",
    topSearches: "__call=content.getTopSearches",
    songDetails: "__call=song.getDetails",
    playlistDetails: "__call=playlist.getDetails",
    albumDetails: "__call=content.getAlbumDetails",
    getResults: "__call=search.getResults",
    getReco: "__call=reco.getreco",
    autocomplete: "__call=autocomplete.get",
};

const HEADERS: Record<string, string> = {
    "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
    Accept: "application/json, text/javascript, */*; q=0.01",
    "Accept-Language": "en-US,en;q=0.9,hi;q=0.8",
    Referer: "https://www.jiosaavn.com/",
    Origin: "https://www.jiosaavn.com",
    Cookie: "L=english; DL=english; gdpr_acceptance=true",
    "X-Requested-With": "XMLHttpRequest",
};

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function apiRequest(params: string, usev4 = true): Promise<any> {
    const path = usev4 ? `${API_PATH}&${params}` : `${API_PATH}&${params}`.replace("&api_version=4", "");
    const url = `${BASE_URL}${path}`;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);

    try {
        const res = await fetch(url, {
            headers: HEADERS,
            signal: controller.signal,
            cache: "no-store",
        });

        if (!res.ok) {
            throw new Error(`JioSaavn API ${res.status}`);
        }

        const contentType = res.headers.get("content-type") || "";
        if (!contentType.includes("json") && !contentType.includes("javascript")) {
            throw new Error("JioSaavn returned non-JSON (likely blocked)");
        }

        return await res.json();
    } finally {
        clearTimeout(timeout);
    }
}

// ─── Song Formatting ─────────────────────────────────────────────────────────

interface Artist { name: string }
interface ArtistMap { primary_artists?: Artist[]; featured_artists?: Artist[]; artists?: Artist[] }
interface MoreInfo {
    artistMap?: ArtistMap;
    album?: string;
    duration?: string;
    encrypted_media_url?: string;
    has_lyrics?: boolean | string;
    music?: string;
    "320kbps"?: string | boolean;
    [key: string]: unknown;
}
interface ApiSong {
    id: string;
    title: string;
    image?: string;
    year?: string;
    language?: string;
    type?: string;
    more_info?: MoreInfo;
}
interface ApiPlaylist {
    id: string;
    title: string;
    image?: string;
    subtitle?: string;
    description?: string;
    type?: string;
    more_info?: { song_count?: string; [key: string]: unknown };
}

function formatSong(s: ApiSong): Song | null {
    try {
        const info = s.more_info || {};
        const map = info.artistMap || {};

        const artists =
            (map.primary_artists?.length ? map.primary_artists : null) ??
            (map.featured_artists?.length ? map.featured_artists : null) ??
            (map.artists?.length ? map.artists : null);

        const artistStr = artists
            ? artists.map((a) => a.name).join(", ")
            : info.music
              ? String(info.music)
              : "Unknown";

        let audioUrl = "";
        if (info.encrypted_media_url) {
            audioUrl = decryptMediaUrl(String(info.encrypted_media_url));
            if (info["320kbps"] === "true" || info["320kbps"] === true) {
                audioUrl = audioUrl.replace("_96.mp4", "_320.mp4");
            }
        }

        return {
            id: s.id,
            title: unescape(s.title),
            artist: unescape(artistStr),
            album: unescape(String(info.album || "")),
            image: getImageUrl(s.image || ""),
            duration: parseInt(String(info.duration || "0"), 10),
            url: audioUrl,
            year: s.year,
            language: s.language,
            hasLyrics: info.has_lyrics === "true" || info.has_lyrics === true,
        };
    } catch {
        return null;
    }
}

function formatPlaylist(p: ApiPlaylist): Playlist | null {
    try {
        return {
            id: p.id,
            title: unescape(p.title),
            image: getImageUrl(p.image || ""),
            subtitle: unescape(p.subtitle || p.description || ""),
            type: p.type || "playlist",
            songCount: p.more_info?.song_count ? parseInt(p.more_info.song_count, 10) : undefined,
        };
    } catch {
        return null;
    }
}

// ─── Public API ──────────────────────────────────────────────────────────────

export async function searchSongs(query: string, count = 20): Promise<Song[]> {
    const data = await apiRequest(`p=1&q=${encodeURIComponent(query)}&n=${count}&${ENDPOINTS.getResults}`);
    return ((data.results as ApiSong[]) || []).map(formatSong).filter(Boolean) as Song[];
}

export async function getSongDetails(songId: string): Promise<Song | null> {
    const data = await apiRequest(`pids=${songId}&${ENDPOINTS.songDetails}`);
    return data.songs?.[0] ? formatSong(data.songs[0]) : null;
}

interface HomeSection {
    title: string;
    type: "songs" | "playlists";
    items: (Song | Playlist)[];
}

export async function fetchHomePageData(): Promise<HomeSection[]> {
    const data = await apiRequest(ENDPOINTS.homeData);
    const sections: HomeSection[] = [];

    // Debug: log top-level keys from JioSaavn response
    console.log("[Home] JioSaavn response keys:", Object.keys(data));
    console.log("[Home] new_trending type:", typeof data.new_trending, Array.isArray(data.new_trending) ? `(${(data.new_trending as unknown[]).length} items)` : "");
    console.log("[Home] charts type:", typeof data.charts, Array.isArray(data.charts) ? `(${(data.charts as unknown[]).length} items)` : "");

    // Trending songs
    if (Array.isArray(data.new_trending)) {
        const songs = (data.new_trending as ApiSong[])
            .filter((i) => i.type === "song")
            .map(formatSong)
            .filter(Boolean) as Song[];
        if (songs.length > 0) sections.push({ title: "Trending Now", type: "songs", items: songs });
    }

    // Charts
    if (Array.isArray(data.charts)) {
        const pls = (data.charts as ApiPlaylist[]).map(formatPlaylist).filter(Boolean) as Playlist[];
        if (pls.length > 0) sections.push({ title: "Top Charts", type: "playlists", items: pls });
    }

    // New albums
    if (Array.isArray(data.new_albums)) {
        const pls = (data.new_albums as ApiPlaylist[]).map(formatPlaylist).filter(Boolean) as Playlist[];
        if (pls.length > 0) sections.push({ title: "New Releases", type: "playlists", items: pls });
    }

    // Top playlists
    if (Array.isArray(data.top_playlists)) {
        const pls = (data.top_playlists as ApiPlaylist[]).map(formatPlaylist).filter(Boolean) as Playlist[];
        if (pls.length > 0) sections.push({ title: "Top Playlists", type: "playlists", items: pls });
    }

    return sections;
}

export async function fetchPlaylistSongs(playlistId: string): Promise<{
    songs: Song[];
    title: string;
    image: string;
}> {
    const data = await apiRequest(`${ENDPOINTS.playlistDetails}&cc=in&listid=${playlistId}`);
    const songs = Array.isArray(data.list)
        ? ((data.list as ApiSong[]).map(formatSong).filter(Boolean) as Song[])
        : [];
    return {
        songs,
        title: unescape(String(data.listname || data.title || "")),
        image: getImageUrl(String(data.image || "")),
    };
}

export async function fetchAlbumSongs(albumId: string): Promise<{
    songs: Song[];
    title: string;
    image: string;
}> {
    const data = await apiRequest(`${ENDPOINTS.albumDetails}&cc=in&albumid=${albumId}`);
    const songs = Array.isArray(data.list)
        ? ((data.list as ApiSong[]).map(formatSong).filter(Boolean) as Song[])
        : [];
    return {
        songs,
        title: unescape(String(data.title || "")),
        image: getImageUrl(String(data.image || "")),
    };
}

export async function getSearchSuggestions(query: string): Promise<string[]> {
    try {
        const data = await apiRequest(
            `__call=autocomplete.get&cc=in&includeMetaTags=1&query=${encodeURIComponent(query)}`,
            false
        );
        const suggestions: string[] = [];
        const extract = (arr: unknown[]) =>
            arr.forEach((item: unknown) => {
                if (typeof item === "object" && item !== null && "title" in item) {
                    suggestions.push(unescape((item as Record<string, unknown>).title as string));
                }
            });

        const topquery = (data.topquery as Record<string, unknown> | undefined)?.data;
        if (Array.isArray(topquery)) extract(topquery);
        const songsData = (data.songs as Record<string, unknown> | undefined)?.data;
        if (Array.isArray(songsData)) extract(songsData);
        const albumsData = (data.albums as Record<string, unknown> | undefined)?.data;
        if (Array.isArray(albumsData)) extract(albumsData);

        return [...new Set(suggestions)].slice(0, 10);
    } catch {
        return [];
    }
}

export async function getTopSearches(): Promise<string[]> {
    try {
        const data = await apiRequest(ENDPOINTS.topSearches);
        if (Array.isArray(data)) {
            return data.map((item: Record<string, unknown>) => String(item.title || "")).filter(Boolean);
        }
    } catch { /* empty */ }
    return [];
}

export async function getSongRecommendations(songId: string): Promise<Song[]> {
    try {
        const data = await apiRequest(`${ENDPOINTS.getReco}&pid=${songId}`);
        if (Array.isArray(data)) {
            return data.map(formatSong).filter(Boolean) as Song[];
        }
    } catch { /* empty */ }
    return [];
}
