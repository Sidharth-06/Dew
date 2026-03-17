import type { Metadata, Viewport } from "next";
import { Inter, Caveat, Kalam } from "next/font/google";
import "./globals.css";
// import { ThemeProvider } from "@/components/theme-provider"; // File missing
import { AudioProvider } from "@/components/AudioProvider";
import PlayerBar from "@/components/PlayerBar";
import { CanvasBackground } from "@/components/ui/CanvasBackground";
import { TopNav } from "@/components/TopNav";
import { MobileNav } from "@/components/MobileNav";
import { DatabaseMigrator } from "@/components/DatabaseMigrator";
import { ApiStatusChecker } from "@/components/ApiStatusChecker";
import KeyboardShortcuts from "@/components/KeyboardShortcuts";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

const caveat = Caveat({
  subsets: ["latin"],
  variable: "--font-caveat",
  weight: ["400", "700"],
});

const kalam = Kalam({
  subsets: ["latin"],
  variable: "--font-kalam",
  weight: ["300", "400", "700"],
});

export const metadata: Metadata = {
  title: "Dew | Scrapbook Music Player",
  description: "A crazy sticky note canvas music player",
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "Dew",
  },
};

export const viewport: Viewport = {
  themeColor: "#0a0a0a",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" suppressHydrationWarning className={`${inter.variable} ${caveat.variable} ${kalam.variable}`}>
      <head>
        <link rel="apple-touch-icon" href="/icon-192.png" />
      </head>
      <body className={`${inter.variable} font-caveat antialiased text-gray-800 selection:bg-purple-500/30 selection:text-purple-200 overflow-hidden relative bg-[#f4f4f5]`}>
        <CanvasBackground />

        <script
          dangerouslySetInnerHTML={{
            __html: `
              if ('serviceWorker' in navigator) {
                window.addEventListener('load', function() {
                  navigator.serviceWorker.register('/sw.js').then(function(registration) {
                    console.log('ServiceWorker registration successful');
                  }, function(err) {
                    console.log('ServiceWorker registration failed: ', err);
                  });
                });
              }
            `,
          }}
        />

        <DatabaseMigrator>
          <AudioProvider>
            <div className="flex flex-col h-[100dvh] w-full overflow-hidden relative z-10 pt-2">
              <TopNav />
              <main className="flex-1 overflow-y-auto pb-56 md:pb-32 custom-scrollbar relative px-4 md:px-12 mt-4">
                {children}
              </main>
            </div>
            <MobileNav />
            <PlayerBar />
            <KeyboardShortcuts />
            <ApiStatusChecker />
          </AudioProvider>
        </DatabaseMigrator>
      </body>
    </html>
  );
}
