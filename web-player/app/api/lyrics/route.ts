import { NextResponse } from "next/server";

export const preferredRegion = "bom1";

export async function GET(request: Request) {
    const { searchParams } = new URL(request.url);
    const id = searchParams.get("id");

    if (!id) {
        return NextResponse.json({ error: "Missing song ID" }, { status: 400 });
    }

    try {
        const url = `https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyrics_id=${id}&ctx=web6dot0&api_version=4&_format=json`;

        const response = await fetch(url, {
            headers: {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
                Accept: "application/json, text/javascript, */*; q=0.01",
                "Accept-Language": "en-US,en;q=0.9,hi;q=0.8",
                Referer: "https://www.jiosaavn.com/",
                Cookie: "L=english; DL=english; gdpr_acceptance=true",
                "X-Requested-With": "XMLHttpRequest",
            },
            cache: "no-store",
        });

        if (!response.ok) {
            throw new Error(`JioSaavn API ${response.status}`);
        }

        const contentType = response.headers.get("content-type") || "";
        if (!contentType.includes("json") && !contentType.includes("javascript")) {
            return NextResponse.json({ error: "Lyrics unavailable" }, { status: 404 });
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
