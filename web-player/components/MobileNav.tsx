"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, Compass, ListMusic, User } from "lucide-react";

export function MobileNav() {
    const pathname = usePathname();

    return (
        <div className="md:hidden fixed bottom-4 left-1/2 -translate-x-1/2 z-50 px-4 w-full max-w-xs">
            <div className="bg-white rounded-[2rem] shadow-2xl border-t-[3px] border-gray-900 border px-6 py-3 flex items-center justify-between font-kalam text-gray-500">
                <Link
                    href="/"
                    className={`flex flex-col items-center gap-1 hover:text-gray-900 transition-colors ${pathname === "/" ? "text-orange-600" : ""}`}
                >
                    <div className={pathname === "/" ? "bg-orange-100 p-2 rounded-xl" : "p-2"}>
                        <Home className="w-5 h-5" strokeWidth={pathname === "/" ? 2.5 : 2} />
                    </div>
                    <span className={`text-xs font-bold ${pathname === "/" ? "text-gray-900" : ""}`}>Home</span>
                </Link>

                <Link
                    href="/discover"
                    className={`flex flex-col items-center gap-1 hover:text-gray-900 transition-colors ${pathname === "/discover" ? "text-orange-600" : ""}`}
                >
                    <div className={pathname === "/discover" ? "bg-orange-100 p-2 rounded-xl" : "p-2"}>
                        <Compass className="w-5 h-5" strokeWidth={pathname === "/discover" ? 2.5 : 2} />
                    </div>
                    <span className={`text-xs font-bold ${pathname === "/discover" ? "text-gray-900" : ""}`}>Discover</span>
                </Link>

                <Link
                    href="/library"
                    className={`flex flex-col items-center gap-1 hover:text-gray-900 transition-colors ${pathname === "/library" ? "text-orange-600" : ""}`}
                >
                    <div className={pathname === "/library" ? "bg-orange-100 p-2 rounded-xl" : "p-2"}>
                        <ListMusic className="w-5 h-5" strokeWidth={pathname === "/library" ? 2.5 : 2} />
                    </div>
                    <span className={`text-xs font-bold ${pathname === "/library" ? "text-gray-900" : ""}`}>Library</span>
                </Link>

                <Link
                    href="/me"
                    className={`flex flex-col items-center gap-1 hover:text-gray-900 transition-colors ${pathname === "/me" ? "text-orange-600" : ""}`}
                >
                    <div className={pathname === "/me" ? "bg-orange-100 p-2 rounded-xl" : "p-2"}>
                        <User className="w-5 h-5" strokeWidth={pathname === "/me" ? 2.5 : 2} />
                    </div>
                    <span className={`text-xs font-bold ${pathname === "/me" ? "text-gray-900" : ""}`}>Me</span>
                </Link>
            </div>
        </div>
    );
}
