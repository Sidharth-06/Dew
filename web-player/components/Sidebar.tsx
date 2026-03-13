"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Home, Search, Library, Plus } from "lucide-react";
import { useLiveQuery } from "dexie-react-hooks";
import { db } from "@/lib/db/database";

export function Sidebar() {
    const pathname = usePathname();
    const customPlaylists = useLiveQuery(() => db.playlists.orderBy('createdAt').reverse().toArray()) || [];

    const handleCreatePlaylist = async () => {
        const title = prompt("Enter playlist name:");
        if (title) {
            await db.playlists.put({
                id: Date.now().toString(),
                title,
                createdAt: Date.now()
            });
        }
    };

    return (
        <aside className="w-64 bg-[#f8f6f0] border-r-2 border-dashed border-gray-400 hidden md:flex flex-col h-[95vh] mt-[2.5vh] ml-2 z-40 relative shadow-lg font-caveat text-xl rounded-l-md custom-scrollbar torn-paper">
            {/* The clipboard clip / tape */}
            <div className="absolute -top-3 left-1/2 -translate-x-1/2 w-16 h-8 bg-black/80 rounded-sm shadow-md z-50 transform rotate-1">
                <div className="absolute top-2 left-1/2 -translate-x-1/2 w-4 h-4 rounded-full bg-gray-300 inset-shadow-sm" />
            </div>

            <div className="p-6 pt-12">
                <nav className="space-y-6">
                    <Link
                        href="/"
                        className={`flex items-center gap-4 transition-colors ${pathname === "/" ? "text-purple-800 font-bold text-2xl" : "text-gray-600 hover:text-black"
                            }`}
                    >
                        <Home className="w-7 h-7" /> Home
                    </Link>
                    <button
                        onClick={() => {
                            // Focus search on home page if we are there, otherwise route to home
                            if (pathname !== "/") window.location.href = "/";
                        }}
                        className="flex items-center gap-4 text-gray-600 hover:text-black transition-colors w-full text-left"
                    >
                        <Search className="w-7 h-7" /> Search
                    </button>
                </nav>
            </div>

            <div className="flex-1 overflow-y-auto px-6 py-4 mt-6 border-t border-gray-300 border-dashed">
                <div className="flex items-center justify-between mb-4 group">
                    <Link
                        href="/library"
                        className={`flex items-center gap-3 transition-colors ${pathname === "/library" ? "text-purple-800 font-bold text-2xl" : "text-gray-600 hover:text-black"
                            }`}
                    >
                        <Library className="w-7 h-7" /> Your Library
                    </Link>
                    <button
                        onClick={handleCreatePlaylist}
                        className="text-gray-400 hover:text-black transition-all p-1 hover:bg-black/5 rounded-full"
                    >
                        <Plus className="w-6 h-6" />
                    </button>
                </div>

                <ul className="space-y-3 font-kalam text-lg">
                    {customPlaylists.map((playlist) => (
                        <li key={playlist.id}>
                            <Link
                                href={`/library/playlist/${playlist.id}`}
                                className={`block px-3 py-2 rounded-sm truncate transition-all ${pathname === `/library/playlist/${playlist.id}`
                                    ? "bg-purple-100 text-purple-900 font-bold border-l-4 border-purple-500"
                                    : "text-gray-700 hover:text-black hover:bg-gray-200"
                                    }`}
                            >
                                • {playlist.title}
                            </Link>
                        </li>
                    ))}
                </ul>
            </div>
        </aside>
    );
}
