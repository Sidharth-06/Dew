import { NextRequest, NextResponse } from "next/server";
import { getSearchSuggestions } from "@/lib/jiosaavn";

export const preferredRegion = "bom1";

export async function GET(request: NextRequest) {
    const query = request.nextUrl.searchParams.get("q");
    if (!query) {
        return NextResponse.json({ suggestions: [] });
    }

    try {
        const suggestions = await getSearchSuggestions(query);
        return NextResponse.json({ suggestions });
    } catch (error) {
        console.error("Suggestions error:", error);
        return NextResponse.json({ suggestions: [] });
    }
}
