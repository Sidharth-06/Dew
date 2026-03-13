"use client";

import { Suspense } from "react";
import { useState, useEffect } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { motion } from "framer-motion";
import { Search, Music } from "lucide-react";
import SongCard from "@/components/SongCard";
import SongRow from "@/components/SongRow";
import { useAudio, Song } from "@/components/AudioProvider";
import { SplitText, BlurText } from "@/components/ui/TextAnimations";
import { useLiveQuery } from "dexie-react-hooks";
import { db } from "@/lib/db/database";

interface HomeSection {
  title: string;
  type: "songs" | "playlists";
  items: (Song | Playlist)[];
}

interface Playlist {
  id: string;
  title: string;
  image: string;
  subtitle?: string;
  type: string;
  songCount?: number;
}

function HomePageContent() {
  const router = useRouter();
  const { playQueue } = useAudio();
  const searchParams = useSearchParams();
  const searchQuery = searchParams.get("q") || "";
  const recentlyPlayedData = useLiveQuery(() => db.recentlyPlayed.orderBy('playedAt').reverse().toArray());
  const recentlyPlayed = recentlyPlayedData?.map(r => r.song) || [];

  const [sections, setSections] = useState<HomeSection[]>([]);
  const [searchResults, setSearchResults] = useState<Song[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      fetch("/api/home").then((r) => r.json()),
    ])
      .then(([homeData]: [{ sections?: HomeSection[] }]) => {
        if (homeData.sections) setSections(homeData.sections);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (!searchQuery.trim()) {
      setSearchResults([]);
      setIsSearching(false);
      return;
    }
    setIsSearching(true);
    const timer = setTimeout(async () => {
      try {
        const res = await fetch(`/api/search?q=${encodeURIComponent(searchQuery)}`);
        const data = await res.json();
        setSearchResults(data.songs || []);
      } catch (e) {
        console.error("Search error:", e);
      } finally {
        setIsSearching(false);
      }
    }, 400);
    return () => clearTimeout(timer);
  }, [searchQuery]);

  const handlePlaylistClick = (playlist: Playlist) => {
    const type = (playlist.type === "album" ? "album" : "playlist");
    router.push(`/playlist/${playlist.id}?type=${type}`);
  };

  const getGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  };

    const rotations = [-4, -3, -2, -1, 1, 2, 3, 4, 5, -5];
    const getRandomRotation = (index: number) => `rotate(${rotations[index % rotations.length]}deg)`;
    const getZIndex = (index: number) => (index % 5) + 10;

    return (
        <div className="min-h-screen pb-32">
            {/* Search Results */}
            {searchQuery.trim() && (
                <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="mb-12"
                >
                    <h2 className="text-3xl font-bold font-caveat mb-6 pl-4 border-b-2 border-orange-500 inline-block text-gray-900 border-dashed">
                       Search Results: {searchQuery}
                    </h2>
                    {isSearching && searchResults.length === 0 ? (
                        <div className="flex items-center gap-2 pl-4 font-kalam text-xl">
                            <Music className="w-6 h-6 animate-pulse text-orange-500" /> Searching...
                        </div>
                    ) : (
                        <div className="flex flex-wrap gap-8 justify-center mt-8">
                            {searchResults.map((song, i) => (
                                <motion.div
                                    initial={{ opacity: 0, scale: 0.8 }}
                                    animate={{ opacity: 1, scale: 1 }}
                                    transition={{ delay: i * 0.05 }}
                                    key={song.id}
                                    style={{ transform: getRandomRotation(i + 13), zIndex: getZIndex(i) }}
                                    className="hover:z-50 hover:scale-105 transition-transform"
                                >
                                    <div className="polaroid max-w-[200px] cursor-pointer" onClick={() => playQueue(searchResults, i)}>
                                         <div className="tape-strip top-[-10px]"></div>
                                         <img src={song.image} alt={song.title} className="w-full aspect-square object-cover mb-3 bg-gray-200" />
                                         <p className="font-caveat font-bold text-lg leading-tight truncate">{song.title}</p>
                                         <p className="font-kalam text-sm text-gray-500 truncate">{song.artist}</p>
                                    </div>
                                </motion.div>
                            ))}
                        </div>
                    )}
                </motion.div>
            )}

            {/* Home Content (Scrapbook Scatter) */}
            {!searchQuery.trim() && (
                <div className="relative w-full py-12 px-4 sm:px-12 flex flex-wrap gap-x-8 gap-y-16 justify-center max-w-7xl mx-auto">
                    
                    {/* Welcome Doodle */}
                    <motion.div
                        initial={{ opacity: 0, scale: 0.8 }}
                        animate={{ opacity: 1, scale: 1 }}
                        className="w-full flex justify-center mb-4"
                    >
                        <div className="font-caveat text-4xl sm:text-6xl font-bold text-gray-800 transform -rotate-2 relative inline-block px-8 py-2 border-4 border-black/80 rounded-[255px_15px_225px_15px/15px_225px_15px_255px] bg-white/50 backdrop-blur-sm shadow-xl">
                            {getGreeting()} <span className="text-orange-500">Music Lover</span>!
                        </div>
                    </motion.div>

                    {loading ? (
                        <div className="flex items-center gap-2 font-kalam text-xl mx-auto mt-20">
                            <Music className="w-6 h-6 animate-pulse text-orange-500" /> Loading your board...
                        </div>
                    ) : (
                        <>
                            {recentlyPlayed.length > 0 && (
                                <div className="w-full">
                                    <h2 className="text-3xl font-bold font-caveat mb-6 border-b-4 border-orange-500 inline-block text-gray-900 px-2 transform rotate-1">
                                        Recently Doodled
                                    </h2>
                                    <div className="flex flex-wrap gap-8 justify-start">
                                        {recentlyPlayed.slice(0, 5).map((song: Song, j: number) => (
                                            <motion.div
                                                key={`recent-${song.id}`}
                                                initial={{ opacity: 0, y: 20 }}
                                                animate={{ opacity: 1, y: 0 }}
                                                transition={{ delay: j * 0.1 }}
                                                style={{ transform: getRandomRotation(j), zIndex: getZIndex(j) }}
                                                className="hover:z-50 hover:scale-105 transition-all w-[200px]"
                                onClick={() => playQueue(recentlyPlayed, j)}
                                            >
                                                <div className="polaroid max-w-full cursor-pointer hover:shadow-2xl">
                                                    <div className="tape-strip top-[-10px] w-16 left-1/2 -translate-x-1/2"></div>
                                                    <img src={song.image} alt={song.title} className="w-full aspect-square object-cover mb-3" />
                                                    <p className="font-caveat font-bold text-xl leading-tight truncate">{song.title}</p>
                                                    <p className="font-kalam text-sm text-gray-500 truncate">{song.artist}</p>
                                                </div>
                                            </motion.div>
                                        ))}
                                    </div>
                                </div>
                            )}

                            {sections.map((section, i) => (
                                <div key={section.title} className="w-full mt-12">
                                    <h2 
                                        className="text-3xl font-bold font-caveat mb-8 bg-yellow-300 inline-block shadow-sm px-4 py-1 transform"
                                        style={{ transform: getRandomRotation(i+5) }}
                                    >
                                        📌 {section.title}
                                    </h2>
                                    <div className="flex flex-wrap gap-10 lg:gap-16 justify-center xl:justify-start items-center relative">
                                        {section.items.slice(0, 8).map((item, j) => {
                                            // Mix of Polaroids and Sticky Notes depending on index
                                            const isSticky = j % 2 === 0;
                                            const colors = ['bg-yellow-200', 'bg-pink-200', 'bg-blue-200', 'bg-green-200'];
                                            const stickyColor = colors[j % colors.length];

                                            return (
                                                <motion.div
                                                    key={item.id}
                                                    initial={{ opacity: 0, scale: 0.5 }}
                                                    animate={{ opacity: 1, scale: 1 }}
                                                    transition={{ delay: i * 0.1 + j * 0.1, type: "spring" }}
                                                    style={{ transform: getRandomRotation(i * 10 + j), zIndex: getZIndex(i + j) }}
                                                    className={`hover:z-50 hover:scale-110 transition-transform cursor-pointer shadow-xl border border-gray-200 relative ${
                                                        isSticky ? `${stickyColor} p-6 w-[220px] aspect-square flex flex-col justify-center rounded-bl-3xl` 
                                                                 : 'polaroid w-[240px]'
                                                    }`}
                                                    onClick={() => section.type === 'playlists' ? handlePlaylistClick(item as Playlist) : playQueue(section.items as Song[], j)}
                                                >
                                                    {!isSticky && <div className="tape-strip top-[-10px]"></div>}
                                                    {isSticky && <div className="absolute -top-3 left-1/2 -translate-x-1/2 w-4 h-4 rounded-full bg-red-600 shadow-md"></div>}
                                                    
                                                    {isSticky ? (
                                                        <div className="text-center font-caveat">
                                                            <h3 className="text-3xl font-bold leading-tight mb-2 text-gray-900">{item.title}</h3>
                                                            {'subtitle' in item && item.subtitle && <p className="text-lg text-gray-700">{item.subtitle}</p>}
                                                        </div>
                                                    ) : (
                                                        <>
                                                            <img src={item.image} alt={item.title} className="w-full aspect-square object-cover mb-3 shadow-inner" />
                                                            <div className="font-caveat text-center">
                                                                <h3 className="text-2xl font-bold leading-tight truncate px-2">{item.title}</h3>
                                                            </div>
                                                        </>
                                                    )}
                                                </motion.div>
                                            );
                                        })}
                                    </div>
                                </div>
                            ))}
                        </>
                    )}
                </div>
            )}
        </div>
    );
}

export default function HomePage() {
    return (
        <Suspense>
            <HomePageContent />
        </Suspense>
    );
}
