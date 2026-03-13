import { NextRequest, NextResponse } from "next/server";
import { fetchPlaylistSongs, fetchAlbumSongs } from "@/lib/jiosaavn";

export const preferredRegion = "bom1";

export async function GET(
    request: NextRequest,
    { params }: { params: Promise<{ id: string }> }
) {
    const { id } = await params;
    const type = request.nextUrl.searchParams.get("type") || "playlist";

    if (!id) {
        return NextResponse.json({ error: "Missing playlist ID" }, { status: 400 });
    }

    try {
        const data = type === "album"
            ? await fetchAlbumSongs(id)
            : await fetchPlaylistSongs(id);
        return NextResponse.json(data);
    } catch (error) {
        console.error("Playlist error:", error);
        return NextResponse.json({ songs: [], title: "", image: "", error: String(error) });
    }
}
