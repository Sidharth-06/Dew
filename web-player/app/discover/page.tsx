"use client";

import { useState, useEffect, useRef } from "react";
import { motion } from "framer-motion";
import { Disc3, Headphones, Keyboard, PenLine, Search, History } from "lucide-react";
import { useRouter } from "next/navigation";

const card = (
    label: string,
    bg: string,
    rot: string,
    extra?: string,
    children?: React.ReactNode
) => (
    <motion.div
        whileHover={{ scale: 1.07, zIndex: 50 }}
        whileTap={{ scale: 0.97 }}
        style={{ transform: rot }}
        className={`${bg} ${extra ?? ""} p-4 shadow-xl cursor-pointer flex flex-col justify-between relative font-caveat select-none`}
    >
        {children}
        <span className="text-2xl sm:text-3xl font-bold">{label}</span>
    </motion.div>
);

export default function DiscoverPage() {
    const router = useRouter();
    const [q, setQ] = useState("");
    const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

    const handleSearch = (val: string) => {
        setQ(val);
        if (debounceRef.current) clearTimeout(debounceRef.current);
        debounceRef.current = setTimeout(() => {
            if (val.trim()) router.push(`/?q=${encodeURIComponent(val.trim())}`);
        }, 500);
    };

    const searchGenre = (genre: string) => router.push(`/?q=${encodeURIComponent(genre)}`);

    useEffect(() => () => { if (debounceRef.current) clearTimeout(debounceRef.current); }, []);

    return (
        <div className="pb-8 max-w-4xl mx-auto relative flex flex-col items-center">

            {/* Search bar — only shown on mobile since TopNav has one on desktop */}
            <motion.div
                initial={{ y: -16, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                className="md:hidden z-10 w-full mb-8"
            >
                <div className="w-full bg-[#E5DCC5] py-3 px-5 transform -rotate-1 shadow-sm flex items-center gap-3 rounded-sm">
                    <Search className="w-5 h-5 text-gray-600 flex-shrink-0" />
                    <input
                        type="text"
                        value={q}
                        placeholder="SEARCH TRACKS, ARTISTS…"
                        className="bg-transparent border-none outline-none w-full font-caveat text-xl text-gray-800 placeholder:text-gray-500 uppercase"
                        onChange={(e) => handleSearch(e.target.value)}
                    />
                </div>
            </motion.div>

            {/* ── Mobile: 2-col responsive grid ── */}
            <div className="md:hidden w-full grid grid-cols-2 gap-4 z-10">
                {/* Rock */}
                <div className="w-full h-36 bg-yellow-300 p-4 shadow-xl cursor-pointer flex flex-col justify-between relative font-caveat select-none rounded-sm"
                    style={{ transform: "rotate(-3deg)" }} onClick={() => searchGenre("rock music")}>
                    <div className="absolute -top-2 left-1/2 -translate-x-1/2 tape-strip w-10 h-4" />
                    <span className="text-3xl font-bold">Rock</span>
                </div>
                {/* Jazz */}
                <div className="w-full h-36 bg-cyan-300 p-4 shadow-xl cursor-pointer flex flex-col items-center justify-center relative font-caveat select-none rounded-sm"
                    style={{ transform: "rotate(3deg)" }} onClick={() => searchGenre("jazz music")}>
                    <span className="text-3xl font-bold">Jazz</span>
                </div>
                {/* LO-FI */}
                <div className="w-full h-36 bg-white border border-gray-200 p-4 shadow-lg cursor-pointer relative font-kalam select-none rounded-sm"
                    style={{ transform: "rotate(-2deg)" }} onClick={() => searchGenre("lofi chill beats")}>
                    <div className="absolute top-2 left-2 text-orange-400">★</div>
                    <span className="text-2xl font-bold uppercase block mb-1">LO-FI</span>
                    <span className="font-caveat text-base text-gray-500 leading-tight">Chill beats to study to…</span>
                </div>
                {/* Pop! */}
                <div className="w-full h-36 bg-pink-400 p-4 shadow-xl cursor-pointer flex items-center justify-center relative font-caveat select-none rounded-sm"
                    style={{ transform: "rotate(-6deg)" }} onClick={() => searchGenre("pop hits")}>
                    <span className="text-4xl font-bold">Pop!</span>
                </div>
                {/* INDIE */}
                <div className="w-full h-28 px-4 py-3 border-2 border-dashed border-gray-400 cursor-pointer flex items-center justify-center select-none"
                    style={{ transform: "rotate(4deg)" }} onClick={() => searchGenre("indie songs")}>
                    <span className="font-kalam text-2xl font-bold text-orange-600 tracking-widest uppercase">INDIE</span>
                </div>
                {/* Folk */}
                <div className="w-full h-28 bg-green-400 p-4 shadow-xl cursor-pointer relative font-caveat select-none rounded-sm"
                    style={{ transform: "rotate(3deg)" }} onClick={() => searchGenre("folk music")}>
                    <span className="text-2xl font-bold">Folk</span>
                </div>
                {/* SYNTHWAVE — full width */}
                <div className="col-span-2 bg-[#111] text-white px-6 py-4 shadow-lg cursor-pointer flex items-center gap-3 font-kalam select-none"
                    style={{ transform: "rotate(-1deg)" }} onClick={() => searchGenre("synthwave electronic")}>
                    <Keyboard className="w-5 h-5 text-orange-400 flex-shrink-0" />
                    <span className="text-xl font-bold tracking-widest uppercase">SYNTHWAVE</span>
                </div>
            </div>

            {/* ── Desktop: scattered absolute layout ── */}
            <div className="hidden md:flex relative w-full min-h-[560px] justify-center items-center">

                {/* Background doodles */}
                <div className="absolute inset-0 pointer-events-none opacity-15 z-0">
                    <Disc3 className="absolute top-10 left-8 w-24 h-24 text-gray-600 -rotate-12" strokeWidth={1} />
                    <Headphones className="absolute bottom-20 left-16 w-28 h-28 text-gray-600 rotate-12" strokeWidth={1} />
                    <Keyboard className="absolute top-1/2 right-8 w-24 h-24 text-gray-600 -rotate-45" strokeWidth={1} />
                    <PenLine className="absolute bottom-24 right-20 w-20 h-20 text-gray-600 rotate-45" strokeWidth={1} />
                </div>

                {/* Rock */}
                <motion.div whileHover={{ scale: 1.1, zIndex: 50 }} style={{ transform: "rotate(-4deg)" }}
                    onClick={() => searchGenre("rock music")}
                    className="absolute top-10 left-[8%] w-40 h-40 bg-yellow-300 p-4 shadow-xl cursor-pointer font-caveat">
                    <div className="absolute -top-3 left-1/2 -translate-x-1/2 tape-strip w-12" />
                    <span className="text-3xl font-bold">Rock</span>
                </motion.div>

                {/* Jazz */}
                <motion.div whileHover={{ scale: 1.1, zIndex: 50 }} style={{ transform: "rotate(3deg)" }}
                    onClick={() => searchGenre("jazz music")}
                    className="absolute top-32 left-[38%] w-36 h-36 bg-cyan-300 p-4 shadow-xl cursor-pointer flex flex-col items-center justify-center font-caveat">
                    <span className="text-3xl font-bold">Jazz</span>
                </motion.div>

                {/* LO-FI */}
                <motion.div whileHover={{ scale: 1.1, zIndex: 50 }} style={{ transform: "rotate(-2deg)" }}
                    onClick={() => searchGenre("lofi chill beats")}
                    className="absolute top-0 right-[12%] w-48 h-32 bg-white border border-gray-200 p-4 shadow-lg cursor-pointer">
                    <div className="absolute top-2 left-2 text-orange-400">★</div>
                    <div className="absolute -top-2 right-4 w-2 h-2 bg-red-400 rounded-full shadow-sm" />
                    <span className="font-kalam text-2xl font-bold block mb-1 uppercase">LO-FI</span>
                    <span className="font-caveat text-lg text-gray-600 leading-tight block">Chill beats to<br />study to…</span>
                </motion.div>

                {/* INDIE */}
                <motion.div whileHover={{ scale: 1.1, zIndex: 50 }} style={{ transform: "rotate(6deg)" }}
                    onClick={() => searchGenre("indie songs")}
                    className="absolute top-64 left-[22%] px-6 py-2 border-2 border-dashed border-gray-400 cursor-pointer">
                    <span className="font-kalam text-2xl font-bold text-orange-600 tracking-widest uppercase">INDIE</span>
                </motion.div>

                {/* SYNTHWAVE */}
                <motion.div whileHover={{ scale: 1.05, zIndex: 50 }} style={{ transform: "rotate(-2deg)" }}
                    onClick={() => searchGenre("synthwave electronic")}
                    className="absolute bottom-32 left-[38%] bg-[#111] text-white px-6 py-2 shadow-lg cursor-pointer flex items-center gap-2">
                    <Keyboard className="w-4 h-4 text-orange-400" />
                    <span className="font-kalam text-xl font-bold tracking-widest uppercase">SYNTHWAVE</span>
                </motion.div>

                {/* Pop! */}
                <motion.div whileHover={{ scale: 1.1, zIndex: 50 }} style={{ transform: "rotate(-8deg)" }}
                    onClick={() => searchGenre("pop hits")}
                    className="absolute top-48 right-[28%] w-32 h-32 bg-pink-400 p-4 shadow-xl cursor-pointer flex items-center justify-center font-caveat rounded-sm">
                    <span className="text-4xl font-bold">Pop!</span>
                </motion.div>

                {/* Folk */}
                <motion.div whileHover={{ scale: 1.1, zIndex: 50 }} style={{ transform: "rotate(5deg)" }}
                    onClick={() => searchGenre("folk music")}
                    className="absolute bottom-16 right-[18%] w-36 h-36 bg-green-400 p-4 shadow-xl cursor-pointer font-caveat">
                    <span className="text-3xl font-bold">Folk</span>
                </motion.div>
            </div>

            {/* Recently Doodled */}
            <div className="w-full mt-10 md:mt-20 z-10">
                <div className="flex items-center gap-2 mb-6">
                    <History className="w-5 h-5 text-gray-800" />
                    <h2 className="text-2xl md:text-3xl font-caveat font-bold text-gray-900 uppercase tracking-wider">Recently Doodled</h2>
                </div>
                <div className="flex flex-wrap gap-6 items-center opacity-70">
                    <div className="font-kalam text-2xl md:text-3xl font-bold text-orange-600 relative">
                        Radiohead
                        <svg className="absolute -bottom-2 w-full h-3" viewBox="0 0 100 10" preserveAspectRatio="none">
                            <path d="M0 5 Q 10 0, 20 5 T 40 5 T 60 5 T 80 5 T 100 5" fill="transparent" stroke="#ea580c" strokeWidth="2" />
                        </svg>
                        <div className="absolute -left-4 top-0 text-orange-400 text-sm">✧</div>
                    </div>
                    <div className="font-caveat text-3xl md:text-4xl font-normal text-gray-800 relative">
                        Lana Del Rey
                        <div className="absolute -bottom-1 left-0 w-full border-b border-gray-800 border-dashed" />
                    </div>
                </div>
            </div>

        </div>
    );
}
