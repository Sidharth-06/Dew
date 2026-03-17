import { NextResponse } from "next/server";

export const preferredRegion = "bom1";

export async function GET(request: Request) {
    const { searchParams } = new URL(request.url);
    const id = searchParams.get("id");
    const title = searchParams.get("title") || "";
    const artist = searchParams.get("artist") || "";

    if (!id) {
        return NextResponse.json({ error: "Missing song ID" }, { status: 400 });
    }

    // 1. Try JioSaavn lyrics (works for older songs)
    try {
        const url = `https://jiosaavn-proxy.sidharthkrishna441.workers.dev/api.php?__call=lyrics.getLyrics&lyrics_id=${id}&ctx=web6dot0&api_version=4&_format=json`;
        const response = await fetch(url, { cache: "no-store" });
        if (response.ok) {
            const data = await response.json();
            if (data.lyrics) {
                return NextResponse.json({ lyrics: data.lyrics });
            }
        }
    } catch {
        // fall through to lrclib
    }

    // 2. Fallback to lrclib.net (covers newer songs, free, no key)
    if (title) {
        try {
            const q = encodeURIComponent(`${title} ${artist}`.trim());
            const lrcRes = await fetch(`https://lrclib.net/api/search?q=${q}`, { cache: "no-store" });
            if (lrcRes.ok) {
                const results = await lrcRes.json();
                if (Array.isArray(results) && results.length > 0) {
                    const withSynced = results.find((r: { syncedLyrics?: string }) => r.syncedLyrics);
                    const withPlain  = results.find((r: { plainLyrics?: string }) => r.plainLyrics);
                    const match = withSynced || withPlain;
                    if (match) {
                        if (match.syncedLyrics) {
                            return NextResponse.json({ syncedLyrics: match.syncedLyrics, lyrics: match.plainLyrics || "" });
                        }
                        const lyrics = match.plainLyrics.replace(/\n/g, "<br>");
                        return NextResponse.json({ lyrics });
                    }
                }
            }
        } catch {
            // fall through
        }
    }

    return NextResponse.json({ error: "No lyrics found" }, { status: 404 });
}
