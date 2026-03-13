import { NextRequest, NextResponse } from "next/server";
import { getSongDetails } from "@/lib/jiosaavn";

export const preferredRegion = "bom1";

export async function GET(
    request: NextRequest,
    { params }: { params: Promise<{ id: string }> }
) {
    const { id } = await params;
    if (!id) {
        return NextResponse.json({ error: "Missing song ID" }, { status: 400 });
    }

    try {
        const song = await getSongDetails(id);
        if (!song) {
            return NextResponse.json({ error: "Song not found" }, { status: 404 });
        }
        return NextResponse.json(song);
    } catch (error) {
        console.error("Song details error:", error);
        return NextResponse.json({ error: "Failed to fetch song details" }, { status: 503 });
    }
}
