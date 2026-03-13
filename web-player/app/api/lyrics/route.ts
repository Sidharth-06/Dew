import { NextResponse } from "next/server";

export async function GET(request: Request) {
    const { searchParams } = new URL(request.url);
    const id = searchParams.get("id");

    if (!id) {
        return NextResponse.json({ error: "Missing song ID" }, { status: 400 });
    }

    try {
        const res = await fetch(`https://saavn.dev/api/songs/${id}/lyrics`, {
            headers: { Accept: "application/json" },
            next: { revalidate: 86400 },
        });

        if (!res.ok) {
            return NextResponse.json({ error: "Lyrics unavailable" }, { status: 404 });
        }

        const json = await res.json();
        const lyrics = json?.data?.lyrics;

        if (!lyrics) {
            return NextResponse.json({ error: "No lyrics found" }, { status: 404 });
        }

        return NextResponse.json({ lyrics });
    } catch (error) {
        console.error("Lyrics fetch error:", error);
        return NextResponse.json({ error: "Lyrics unavailable" }, { status: 404 });
    }
}
