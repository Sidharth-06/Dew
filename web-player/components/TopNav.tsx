"use client";

import { Suspense } from "react";
import Link from "next/link";
import { Search, User, Music4 } from "lucide-react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";

function SearchInput() {
    const router = useRouter();
    const pathname = usePathname();
    const searchParams = useSearchParams();
    const query = searchParams.get("q") || "";

    return (
        <input
            type="text"
            value={query}
            placeholder="SEARCH TRACKS, ARTISTS..."
            className="bg-transparent border-none outline-none w-full font-kalam text-lg text-gray-800 placeholder:text-gray-500 uppercase tracking-widest placeholder:font-caveat"
            onChange={(e) => {
                const val = e.target.value;
                const target = val ? `/?q=${encodeURIComponent(val)}` : "/";
                if (pathname === "/") {
                    router.replace(target, { scroll: false });
                } else {
                    router.push(target);
                }
            }}
        />
    );
}

export function TopNav() {
    return (
        <header className="w-full h-24 flex items-center justify-between px-6 md:px-12 z-40 relative sticky top-0">
            {/* Logo */}
            <Link href="/" className="tape-strip !relative !top-0 !left-0 !transform-none !w-auto bg-white/80 px-4 py-2 flex items-center gap-2 group transform -rotate-2 hover:rotate-0 transition-all font-kalam">
                <div className="bg-orange-500 text-white p-1 rounded-sm shadow-sm group-hover:scale-110 transition-transform">
                    <Music4 className="w-5 h-5" />
                </div>
                <span className="text-xl font-bold tracking-tight text-gray-900">DEW</span>
            </Link>

            {/* Search Bar */}
            <div className="absolute left-1/2 -translate-x-1/2 top-6 w-[400px] hidden md:block z-10">
                <div className="tape-strip !relative !top-0 !left-0 !transform-none !w-full bg-[#e5decf] px-4 py-3 flex items-center gap-3 shadow-sm transform rotate-1">
                    <Search className="w-5 h-5 text-gray-500" />
                    <Suspense fallback={
                        <input type="text" placeholder="SEARCH TRACKS, ARTISTS..." className="bg-transparent border-none outline-none w-full font-kalam text-lg text-gray-800 placeholder:text-gray-500 uppercase tracking-widest placeholder:font-caveat" readOnly />
                    }>
                        <SearchInput />
                    </Suspense>
                </div>
            </div>
            
        </header>
    );
}
