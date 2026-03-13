"use client";

import { useEffect, useRef } from "react";

export function AnimatedGradientBackground() {
    const canvasRef = useRef<HTMLCanvasElement>(null);

    useEffect(() => {
        const canvas = canvasRef.current;
        if (!canvas) return;

        const ctx = canvas.getContext("2d");
        if (!ctx) return;

        let animationFrameId: number;
        let t = 0;

        const resize = () => {
            canvas.width = window.innerWidth;
            canvas.height = window.innerHeight;
        };

        window.addEventListener("resize", resize);
        resize();

        const render = () => {
            t += 0.0015;
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            // Create a gradient that moves organically
            const gradient = ctx.createLinearGradient(
                canvas.width * (0.5 + Math.cos(t) * 0.5),
                canvas.height * (0.5 + Math.sin(t * 0.8) * 0.5),
                canvas.width * (0.5 + Math.cos(t + Math.PI) * 0.5),
                canvas.height * (0.5 + Math.sin(t * 1.2 + Math.PI) * 0.5)
            );

            // Deep Space / Nebula Theme
            gradient.addColorStop(0, "#0a0a0a"); // Pure Black background base
            gradient.addColorStop(0.3, "#0f0c29"); // Deep space purple/black
            gradient.addColorStop(0.7, "#302b63"); // Indigo nebula
            gradient.addColorStop(1, "#1a0b2e"); // Dark violet edges

            ctx.fillStyle = gradient;
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            // Ambient floating particles (dust/stars)
            for (let i = 0; i < 60; i++) {
                // Slower, more elegant movement
                const x = (Math.sin(i * 13.5 + t * 0.2) * 0.5 + 0.5) * canvas.width;
                const y = (Math.cos(i * 7.5 + t * 0.15) * 0.5 + 0.5) * canvas.height;
                const size = (Math.sin(i * 11 + t) * 0.5 + 0.5) * 2;

                const opacity = Math.abs(Math.sin(t * 0.5 + i)) * 0.4;
                ctx.fillStyle = `rgba(180, 160, 255, ${opacity})`;
                ctx.beginPath();
                ctx.arc(x, y, size, 0, Math.PI * 2);
                ctx.fill();
            }

            animationFrameId = requestAnimationFrame(render);
        };

        render();

        return () => {
            window.removeEventListener("resize", resize);
            cancelAnimationFrame(animationFrameId);
        };
    }, []);

    return (
        <canvas
            ref={canvasRef}
            className="fixed inset-0 w-full h-full -z-50 pointer-events-none opacity-80 mix-blend-screen"
        />
    );
}
