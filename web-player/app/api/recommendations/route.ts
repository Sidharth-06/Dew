import { NextResponse } from "next/server";
import { getSongRecommendations } from "@/lib/jiosaavn";

export async function GET(request: Request) {
    const { searchParams } = new URL(request.url);
    const id = searchParams.get("id");

    if (!id) return NextResponse.json({ songs: [] });

    try {
        const songs = await getSongRecommendations(id);
        return NextResponse.json({ songs });
    } catch {
        return NextResponse.json({ songs: [] });
    }
}
