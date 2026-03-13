"use client";

import React from 'react';

interface ShinyTextProps {
    text: string;
    disabled?: boolean;
    speed?: number;
    className?: string;
    shinyColor?: string; // Matching the user's prop name if possible, or mapping it. User said 'shineColor'
    shineColor?: string;
    color?: string;
    spread?: number;
    direction?: string;
    yoyo?: boolean;
    pauseOnHover?: boolean;
    delay?: number;
}

const ShinyText: React.FC<ShinyTextProps> = ({
    text,
    disabled = false,
    speed = 3,
    className = '',
    shineColor = '#b5b5b5',
    color = '#ffffff',
}) => {
    const animationDuration = `${speed}s`;

    return (
        <div
            className={`text-[#b5b5b5] bg-clip-text inline-block ${disabled ? '' : 'animate-shine'} ${className}`}
            style={{
                backgroundImage: disabled
                    ? 'none'
                    : `linear-gradient(120deg, transparent 40%, ${shineColor} 50%, transparent 60%)`,
                backgroundSize: '200% 100%',
                WebkitBackgroundClip: 'text',
                animationDuration: animationDuration,
                color: color,
            }}
        >
            {text}
        </div>
    );
};

export default ShinyText;
