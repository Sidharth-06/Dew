import { NextRequest, NextResponse } from "next/server";
import { searchSongs } from "@/lib/jiosaavn";

export const preferredRegion = "bom1";

export async function GET(request: NextRequest) {
    const query = request.nextUrl.searchParams.get("q");
    if (!query) {
        return NextResponse.json({ error: "Missing query parameter" }, { status: 400 });
    }

    try {
        const songs = await searchSongs(query);
        if (!songs || songs.length === 0) {
            console.warn(`[API] Search returned no songs for query: ${query}`);
        }
        return NextResponse.json({ songs });
    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        console.error(`[API] Search error for query "${query}":`, errorMessage);
        // Return empty results instead of 500 so the UI degrades gracefully
        return NextResponse.json({ songs: [], error: errorMessage });
    }
}
