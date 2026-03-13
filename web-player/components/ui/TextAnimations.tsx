"use client";

import { motion } from "framer-motion";

export function SplitText({ text, className = "", delay = 0 }: { text: string, className?: string, delay?: number }) {
    const words = text.split(" ");

    return (
        <h1 className={className}>
            {words.map((word, i) => (
                <span key={i} className="inline-block overflow-hidden">
                    <motion.span
                        initial={{ y: "100%" }}
                        animate={{ y: 0 }}
                        transition={{
                            duration: 0.5,
                            delay: delay + i * 0.1,
                            ease: [0.33, 1, 0.68, 1],
                        }}
                        className="inline-block mr-2"
                    >
                        {word}
                    </motion.span>
                </span>
            ))}
        </h1>
    );
}

export function BlurText({ text, className = "", delay = 0 }: { text: string, className?: string, delay?: number }) {
    return (
        <motion.p
            initial={{ filter: "blur(10px)", opacity: 0 }}
            animate={{ filter: "blur(0px)", opacity: 1 }}
            transition={{ duration: 1, delay, ease: "easeOut" }}
            className={className}
        >
            {text}
        </motion.p>
    );
}
