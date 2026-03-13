import { NextResponse } from "next/server";
import { fetchHomePageData } from "@/lib/jiosaavn";

export const preferredRegion = "bom1";

export async function GET() {
    try {
        const sections = await fetchHomePageData();
        return NextResponse.json({ sections, _debug: { count: sections.length, region: process.env.VERCEL_REGION } });
    } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        return NextResponse.json({ sections: [], error: errorMessage, _debug: { region: process.env.VERCEL_REGION } });
    }
}
