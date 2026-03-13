import { NextResponse } from "next/server";

export const preferredRegion = "bom1";

export async function GET(request: Request) {
    const { searchParams } = new URL(request.url);
    const id = searchParams.get("id");

    if (!id) {
        return NextResponse.json({ error: "Missing song ID" }, { status: 400 });
    }

    try {
        const url = `https://jiosaavn-proxy.sidharthkrishna441.workers.dev/api.php?__call=lyrics.getLyrics&lyrics_id=${id}&ctx=web6dot0&api_version=4&_format=json`;

        const response = await fetch(url, {
            cache: "no-store",
        });

        if (!response.ok) {
            throw new Error(`JioSaavn API ${response.status}`);
        }

        const data = await response.json();
        if (data.lyrics) {
            return NextResponse.json({ lyrics: data.lyrics });
        }
        return NextResponse.json({ error: "No lyrics found" }, { status: 404 });
    } catch (error) {
        console.error("Lyrics API error:", error);
        return NextResponse.json({ error: "Lyrics unavailable" }, { status: 404 });
    }
}
