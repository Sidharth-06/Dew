"use client";

import { useState, useEffect } from "react";
import { AlertCircle, Loader } from "lucide-react";

interface ApiStatus {
    status: "checking" | "ok" | "error";
    message: string;
}

export function ApiStatusChecker() {
    const [homeStatus, setHomeStatus] = useState<ApiStatus>({ status: "checking", message: "Checking..." });
    const [showDetails, setShowDetails] = useState(false);

    useEffect(() => {
        const checkApi = async () => {
            try {
                const response = await fetch("/api/home", { cache: "no-store" });
                if (!response.ok) {
                    const error = await response.json();
                    setHomeStatus({
                        status: "error",
                        message: `API Error: ${response.status} - ${error.details || error.error}`,
                    });
                } else {
                    const data = await response.json();
                    if (data.sections && data.sections.length > 0) {
                        setHomeStatus({
                            status: "ok",
                            message: `✓ API Working - Loaded ${data.sections.length} sections`,
                        });
                    } else {
                        setHomeStatus({
                            status: "error",
                            message: "API returned empty data",
                        });
                    }
                }
            } catch (error) {
                setHomeStatus({
                    status: "error",
                    message: `Network Error: ${error instanceof Error ? error.message : String(error)}`,
                });
            }
        };

        checkApi();
    }, []);

    if (homeStatus.status === "ok") return null; // Hide if working

    return (
        <div className="fixed bottom-24 right-4 z-50 max-w-xs">
            <button
                onClick={() => setShowDetails(!showDetails)}
                className={`
                    px-4 py-2 rounded-lg flex items-center gap-2 text-sm font-medium
                    transition-all cursor-pointer shadow-lg
                    ${homeStatus.status === "error"
                        ? "bg-red-500/20 text-red-300 hover:bg-red-500/30 border border-red-500/30"
                        : "bg-yellow-500/20 text-yellow-300 hover:bg-yellow-500/30 border border-yellow-500/30"
                    }
                `}
            >
                {homeStatus.status === "checking" && <Loader className="w-4 h-4 animate-spin" />}
                {homeStatus.status === "error" && <AlertCircle className="w-4 h-4" />}
                <span className="line-clamp-1">{homeStatus.message}</span>
            </button>

            {showDetails && (
                <div className="absolute bottom-full right-0 mb-2 bg-black/90 border border-white/20 rounded-lg p-4 text-xs text-white/70 w-64">
                    <p className="mb-2"><strong>API Status Debug:</strong></p>
                    <p className="mb-2 font-mono text-white">{homeStatus.message}</p>
                    <p className="text-xs">
                        If you see API errors, the JioSaavn backend might be temporarily unavailable or blocking requests from Vercel servers.
                        Try refreshing the page or check back later.
                    </p>
                </div>
            )}
        </div>
    );
}
