"use client";

import { motion } from "framer-motion";
import { Disc3, Headphones, Keyboard, PenLine, Bus, Phone, Bell, Search, History } from "lucide-react";

export default function DiscoverPage() {
    
    // Some static categories based on the mockup
    const categories = [
        { name: "Rock", color: "bg-yellow-300", type: "sticky", rotation: -4, align: "left", icon: <Bus className="w-5 h-5 text-gray-800" /> },
        { name: "Jazz", color: "bg-cyan-300", type: "sticky", rotation: 3, align: "center", icon: <Phone className="w-6 h-6 text-gray-800 mb-1" /> },
        { name: "Pop!", color: "bg-pink-400", type: "sticky", rotation: -6, align: "center" },
        { name: "Folk", color: "bg-green-400", type: "sticky", rotation: 5, align: "right", icon: <Bell className="w-5 h-5 text-gray-800" /> },
    ];

    return (
        <div className="min-h-screen pt-24 pb-32 px-4 sm:px-8 max-w-7xl mx-auto relative overflow-hidden flex flex-col items-center">
            
            {/* Background Doodles */}
            <div className="absolute inset-0 pointer-events-none opacity-20 z-0">
                <Disc3 className="absolute top-40 left-10 sm:left-32 w-24 h-24 text-gray-600 transform -rotate-12" strokeWidth={1} />
                <Headphones className="absolute bottom-60 left-12 sm:left-40 w-32 h-32 text-gray-600 transform rotate-12" strokeWidth={1} />
                <Keyboard className="absolute top-1/2 right-10 sm:right-32 w-28 h-28 text-gray-600 transform -rotate-45" strokeWidth={1} />
                <PenLine className="absolute bottom-40 right-20 sm:right-48 w-20 h-20 text-gray-600 transform rotate-45" strokeWidth={1} />
                {/* Note shape */}
                <div className="absolute top-60 left-24 sm:left-64 w-16 h-16 bg-gray-400 rounded-lg transform rotate-12 flex items-center justify-center">
                    <div className="w-4 h-4 bg-white rounded-full"></div>
                </div>
            </div>

            {/* If TopNav is used, we already have a search bar. But to match the mockup perfectly, we might add a centered large search sticky here. I'll add one just in case */}
            <motion.div
                initial={{ y: -20, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                className="z-10 w-full max-w-2xl mb-20 relative"
            >
                {/* Torn tape style search bar */}
                <div className="w-full bg-[#E5DCC5] py-4 px-8 transform -rotate-1 relative shadow-sm"
                     style={{ clipPath: 'polygon(2% 0%, 98% 3%, 100% 95%, 1% 100%)' }}>
                    <div className="flex items-center gap-4">
                        <Search className="w-6 h-6 text-gray-600" />
                        <input 
                            type="text" 
                            placeholder="SEARCH TRACKS, ARTISTS..."
                            className="bg-transparent border-none outline-none text-2xl font-caveat text-gray-800 placeholder-gray-500 w-full uppercase"
                        />
                    </div>
                </div>
            </motion.div>

            {/* Scattered Categories Grid */}
            <div className="relative w-full max-w-4xl min-h-[500px] z-10 flex justify-center items-center">
                
                {/* Rock */}
                <motion.div
                    whileHover={{ scale: 1.1, zIndex: 50 }}
                    style={{ transform: "rotate(-4deg)" }}
                    className="absolute top-10 left-[10%] sm:left-[20%] w-40 h-40 bg-yellow-300 p-4 shadow-xl cursor-pointer"
                >
                    <div className="absolute -top-3 left-1/2 -translate-x-1/2 tape-strip w-12"></div>
                    <span className="font-caveat text-3xl font-bold">Rock</span>
                    <div className="absolute bottom-4 right-4">{categories[0].icon}</div>
                </motion.div>

                {/* Jazz */}
                <motion.div
                    whileHover={{ scale: 1.1, zIndex: 50 }}
                    style={{ transform: "rotate(3deg)" }}
                    className="absolute top-32 left-[40%] w-36 h-36 bg-cyan-300 p-4 shadow-xl cursor-pointer flex flex-col items-center justify-center"
                >
                    {categories[1].icon}
                    <span className="font-caveat text-3xl font-bold">Jazz</span>
                </motion.div>

                {/* LO-FI (White note) */}
                <motion.div
                    whileHover={{ scale: 1.1, zIndex: 50 }}
                    style={{ transform: "rotate(-2deg)" }}
                    className="absolute top-0 right-[15%] sm:right-[20%] w-48 h-32 bg-white border border-gray-200 p-4 shadow-lg cursor-pointer"
                >
                    <div className="absolute top-2 left-2 text-orange-400">★</div>
                    <div className="absolute -top-2 right-4 w-2 h-2 bg-red-400 rounded-full shadow-sm"></div>
                    <span className="font-kalam text-2xl font-bold block mb-1 uppercase">LO-FI</span>
                    <span className="font-caveat text-lg text-gray-600 leading-tight block">Chill beats to<br/>study to...</span>
                </motion.div>

                {/* INDIE (Dotted border) */}
                <motion.div
                    whileHover={{ scale: 1.1, zIndex: 50 }}
                    style={{ transform: "rotate(6deg)" }}
                    className="absolute top-60 left-[15%] sm:left-[25%] px-6 py-2 border-2 border-dashed border-gray-400 cursor-pointer"
                >
                    <span className="font-kalam text-2xl font-bold text-orange-600 tracking-widest uppercase">INDIE</span>
                    <div className="absolute -bottom-4 -right-4 w-8 h-6 bg-gray-300/50 rounded-full blur-sm"></div>
                </motion.div>

                {/* SYNTHWAVE (Black tape) */}
                <motion.div
                    whileHover={{ scale: 1.1, zIndex: 50 }}
                    style={{ transform: "rotate(-2deg)" }}
                    className="absolute bottom-40 left-[40%] bg-[#111] text-white px-6 py-2 shadow-lg cursor-pointer flex items-center gap-2"
                >
                    <Keyboard className="w-4 h-4 text-orange-400" />
                    <span className="font-kalam text-xl font-bold tracking-widest uppercase">SYNTHWAVE</span>
                </motion.div>

                {/* Pop! */}
                <motion.div
                    whileHover={{ scale: 1.1, zIndex: 50 }}
                    style={{ transform: "rotate(-8deg)" }}
                    className="absolute top-48 right-[30%] w-32 h-32 bg-pink-400 p-4 shadow-xl cursor-pointer flex items-center justify-center rounded-sm"
                >
                    <span className="font-caveat text-4xl font-bold">Pop!</span>
                </motion.div>

                {/* Folk */}
                <motion.div
                    whileHover={{ scale: 1.1, zIndex: 50 }}
                    style={{ transform: "rotate(5deg)" }}
                    className="absolute bottom-20 right-[15%] sm:right-[25%] w-36 h-36 bg-green-400 p-4 shadow-xl cursor-pointer"
                >
                    <span className="font-caveat text-3xl font-bold">Folk</span>
                    <div className="absolute bottom-4 left-1/2 -translate-x-1/2">{categories[3].icon}</div>
                </motion.div>
                
            </div>

            {/* Recently Doodled Component Placeholder */}
            <div className="w-full max-w-4xl mt-20 z-10">
                <div className="flex items-center gap-2 mb-6">
                    <History className="w-6 h-6 text-gray-800" />
                    <h2 className="text-3xl font-caveat font-bold text-gray-900 uppercase tracking-wider">Recently Doodled</h2>
                </div>
                <div className="flex flex-wrap gap-8 items-center opacity-70">
                    {/* Simulated hand-drawn logos */}
                    <div className="font-kalam text-3xl font-bold text-orange-600 relative">
                        Radiohead
                        <svg className="absolute -bottom-2 w-full h-3" viewBox="0 0 100 10" preserveAspectRatio="none">
                            <path d="M0 5 Q 10 0, 20 5 T 40 5 T 60 5 T 80 5 T 100 5" fill="transparent" stroke="#ea580c" strokeWidth="2" />
                        </svg>
                        <div className="absolute -left-4 top-0 text-orange-400 text-sm">✧</div>
                    </div>
                    <div className="font-caveat text-4xl font-normal text-gray-800 relative">
                        Lana Del Rey
                        <div className="absolute -bottom-1 left-0 w-full border-b border-gray-800 border-dashed"></div>
                    </div>
                </div>
            </div>

        </div>
    );
}
