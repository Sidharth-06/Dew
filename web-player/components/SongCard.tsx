"use client";

import { motion } from "framer-motion";

interface SongCardProps {
    title: string;
    subtitle?: string;
    image: string;
    onClick?: () => void;
    size?: "sm" | "md" | "lg";
    index?: number; // Used for deterministic random rotations
}

export default function SongCard({
    title,
    subtitle,
    image,
    onClick,
    size = "md",
    index = 0
}: SongCardProps) {
    const sizes = {
        sm: "w-32",
        md: "w-40",
        lg: "w-48",
    };

    // Cycle through sticky colors based on index to ensure deterministic rendering
    const colorClasses = [
        "sticky-note-yellow",
        "sticky-note-pink",
        "sticky-note-blue",
        "sticky-note-green"
    ];
    const colorClass = colorClasses[index % colorClasses.length];

    // Slight randomized rotation based on index to make it feel pasted by hand
    const rotation = (index % 5) - 2; // Returns -2, -1, 0, 1, 2

    return (
        <motion.div
            whileHover={{ scale: 1.05, rotate: 0, zIndex: 10 }}
            whileTap={{ scale: 0.95 }}
            onClick={onClick}
            // `font-kalam` applied to force marker text on these cards
            className={`${sizes[size]} sticky-note ${colorClass} p-3 flex-shrink-0 cursor-pointer group font-kalam relative`}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0, rotate: rotation }}
            transition={{ type: "spring", stiffness: 300, damping: 20 }}
            style={{ transformOrigin: "top center" }}
        >
            {/* The piece of tape holding it up */}
            <div className="tape-strip" />

            <div className="relative overflow-hidden shadow-sm ring-1 ring-black/5 aspect-square mb-2 bg-[#f8f8f8] p-1 border border-black/10">
                <img
                    src={image}
                    alt={title}
                    className="w-full h-full object-cover grayscale-[0.2] contrast-[1.1] transition-transform duration-300 group-hover:scale-105"
                    loading="lazy"
                />
            </div>

            <h3 className="text-base sm:text-lg font-bold text-gray-900 leading-tight tracking-tight line-clamp-2">
                {title}
            </h3>
            {subtitle && (
                <p className="text-sm text-gray-700 truncate mt-1">{subtitle}</p>
            )}
        </motion.div>
    );
}
