"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, Search, Library } from "lucide-react";

export function MobileNav() {
    const pathname = usePathname();

    return (
        <nav className="md:hidden fixed bottom-0 left-0 right-0 z-40 bg-[#0a0a0a]/90 backdrop-blur-xl border-t border-white/5 pb-safe pt-2 px-6">
            <div className="flex justify-between items-center max-w-sm mx-auto h-16">
                <Link
                    href="/"
                    className={`flex flex-col items-center gap-1 transition-colors ${pathname === "/" ? "text-white" : "text-white/40 hover:text-white/80"
                        }`}
                >
                    <Home className="w-6 h-6" />
                    <span className="text-[10px] font-medium tracking-wide">Home</span>
                </Link>

                {/* Search maps to home page focusing search input */}
                <Link
                    href="/"
                    className={`flex flex-col items-center gap-1 transition-colors ${pathname === "/search" ? "text-white" : "text-white/40 hover:text-white/80"
                        }`}
                >
                    <Search className="w-6 h-6" />
                    <span className="text-[10px] font-medium tracking-wide">Search</span>
                </Link>

                <Link
                    href="/library"
                    className={`flex flex-col items-center gap-1 transition-colors ${pathname.startsWith("/library") ? "text-white" : "text-white/40 hover:text-white/80"
                        }`}
                >
                    <Library className="w-6 h-6" />
                    <span className="text-[10px] font-medium tracking-wide">Library</span>
                </Link>
            </div>
        </nav>
    );
}
