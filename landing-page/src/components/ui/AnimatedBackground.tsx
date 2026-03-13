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
            t += 0.002;
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            // Create a gradient that moves
            const gradient = ctx.createLinearGradient(
                0,
                0,
                canvas.width * Math.cos(t),
                canvas.height * Math.sin(t)
            );

            // Deep Purple / Blue / Black theme
            gradient.addColorStop(0, "#0a0a0a"); // Black
            gradient.addColorStop(0.5, "#1e1b4b"); // Dark Indigo
            gradient.addColorStop(1, "#312e81"); // Indigo

            ctx.fillStyle = gradient;
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            // Add "stars" or particles
            for (let i = 0; i < 50; i++) {
                const x = (Math.sin(i + t) * 0.5 + 0.5) * canvas.width;
                const y = (Math.cos(i * 0.5 + t) * 0.5 + 0.5) * canvas.height;
                const size = Math.random() * 2;

                ctx.fillStyle = `rgba(255, 255, 255, ${Math.abs(Math.sin(t + i)) * 0.5})`;
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
            className="fixed inset-0 w-full h-full -z-10 pointer-events-none opacity-60"
        />
    );
}
