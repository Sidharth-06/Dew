import { NextResponse } from "next/server";
import { fetchHomePageData } from "@/lib/jiosaavn";

export const preferredRegion = "bom1";

export async function GET() {
    try {
        const sections = await fetchHomePageData();
        return NextResponse.json({ sections });
    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        console.error("[API] Home page data error:", errorMessage);
        // Return empty sections instead of 500 so the UI degrades gracefully
        return NextResponse.json({ sections: [], error: errorMessage });
    }
}
