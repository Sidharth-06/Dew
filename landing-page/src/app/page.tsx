"use client";

import { useState, useEffect } from "react";

import Image from "next/image";
import { motion } from "framer-motion";
import {
  Music,
  Shield,
  Zap,
  Smartphone,
  Download,
  Github,
  Mic,
  Compass,
  Users
} from "lucide-react";
import { SplitText, BlurText } from "@/components/ui/TextAnimations";
import ShinyText from "@/components/ui/ShinyText";
import PrismaticBurst from "@/components/ui/PrismaticBurst";

export default function Home() {
  const [latestVersion, setLatestVersion] = useState("v9.0");
  const [downloadUrl, setDownloadUrl] = useState("https://appho.st/d/E7TYgfqU");

  useEffect(() => {
    fetch("https://api.github.com/repos/Sidharth-06/Dew/releases/latest")
      .then((res) => res.json())
      .then((data) => {
        if (data.tag_name) {
          setLatestVersion(data.tag_name);
        }
      })
      .catch((err) => console.error("Failed to fetch latest release:", err));
  }, []);

  const fadeInUp = {
    initial: { opacity: 0, y: 20 },
    animate: { opacity: 1, y: 0 },
    transition: { duration: 0.5 }
  };
  // ... (start of component)
  // inside return:
  <motion.div variants={fadeInUp} className="inline-block px-4 py-1.5 rounded-full border border-purple-500/30 bg-purple-500/10 text-sm font-medium shadow-[0_0_15px_rgba(168,85,247,0.3)]">
    <ShinyText
      text="v9.0 is now available"
      disabled={false}
      speed={3}
      className="custom-class"
      color="#d8b4fe" // purple-300
      shineColor="#ffffff"
    />
  </motion.div>

  const stagger = {
    animate: {
      transition: {
        staggerChildren: 0.1
      }
    }
  };

  return (
    <div className="min-h-screen bg-[#0a0a0a] text-white selection:bg-purple-500 selection:text-white overflow-hidden relative">
      <div className="fixed inset-0 z-0">
        <PrismaticBurst
          animationType="rotate3d"
          intensity={2}
          speed={0.5}
          distort={0}
          paused={false}
          offset={{ x: 0, y: 0 }}
          hoverDampness={0.25}
          rayCount={0}
          mixBlendMode="lighten"
          colors={['#ff007a', '#4d3dff', '#ffffff']}
        />
      </div>

      {/* Background Gradients (Static Overlay) */}
      <div className="fixed inset-0 z-0 overflow-hidden pointer-events-none mix-blend-overlay">
        <div className="absolute top-[-20%] left-[-10%] w-[50%] h-[50%] bg-purple-900/10 rounded-full blur-[120px] animate-pulse" />
        <div className="absolute bottom-[-20%] right-[-10%] w-[50%] h-[50%] bg-blue-900/10 rounded-full blur-[120px] animate-pulse delay-700" />
      </div>

      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">

        {/* Navigation */}
        <nav className="flex justify-between items-center py-6 backdrop-blur-sm sticky top-0 z-50">
          <div className="flex-1" />
          <div className="hidden md:flex gap-8 text-gray-400 bg-white/5 px-6 py-2 rounded-full border border-white/5 hover:border-white/10 transition-all">
            <a href="#features" className="hover:text-white transition-colors">Features</a>
            <a href="#download" className="hover:text-white transition-colors">Download</a>
            <a href="https://github.com/Sidharth-06/Dew" target="_blank" rel="noopener noreferrer" className="hover:text-white transition-colors">
              <Github className="w-5 h-5" />
            </a>
          </div>
        </nav>

        {/* Hero Section */}
        <main className="mt-20 md:mt-32 flex flex-col items-center text-center">
          <motion.div
            initial="initial"
            animate="animate"
            variants={stagger}
            className="space-y-8 max-w-5xl"
          >
            <motion.div variants={fadeInUp} className="flex items-center gap-3 justify-center mb-0">
              <span className="text-4xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-purple-400 to-blue-400">
                Dew
              </span>
            </motion.div>

            <motion.div variants={fadeInUp} className="inline-block px-4 py-1.5 rounded-full border border-purple-500/30 bg-purple-500/10 text-sm font-medium text-purple-300 shadow-[0_0_15px_rgba(168,85,247,0.3)]">
              {latestVersion} is now available
            </motion.div>

            <div className="overflow-hidden">
              <SplitText
                text="Music Streaming, Reimagined."
                className="text-5xl md:text-8xl font-bold tracking-tighter bg-clip-text text-transparent bg-gradient-to-br from-white via-gray-200 to-gray-500 pb-2"
                delay={0.2}
              />
            </div>

            <div className="max-w-2xl mx-auto">
              <BlurText
                text="Experience your music library like never before. Built with Flutter for seamless performance across all your devices."
                className="text-lg md:text-xl text-gray-400"
                delay={0.8}
              />
            </div>


            <motion.div variants={fadeInUp} className="flex flex-col sm:flex-row gap-4 justify-center mt-12">
              <a
                href={downloadUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="group relative px-8 py-4 rounded-full bg-white text-black font-bold text-lg hover:scale-105 transition-transform overflow-hidden"
              >
                <span className="relative z-10 flex items-center gap-2">
                  <Download className="w-5 h-5" />
                  Download for Android
                </span>
                <div className="absolute inset-0 bg-gradient-to-r from-purple-400 to-blue-500 opacity-0 group-hover:opacity-10 transition-opacity" />
              </a>
              <a href="https://github.com/Sidharth-06/Dew" target="_blank" className="px-8 py-4 rounded-full border border-white/20 hover:bg-white/5 hover:border-white/40 transition-all flex items-center justify-center gap-2 backdrop-blur-md">
                <Github className="w-5 h-5" />
                View Source
              </a>
            </motion.div>
          </motion.div>


        </main>

        {/* Features Grid */}
        <section id="features" className="py-32 relative">
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-purple-900/5 rounded-full blur-[100px] pointer-events-none" />

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6 relative z-10">
            <FeatureCard
              icon={<Zap className="w-8 h-8 text-yellow-400" />}
              title="Adaptive Flow"
              description="Music that reacts to your world. Volume adjusts automatically when you speak or when the room gets quiet."
              delay={0}
            />
            <FeatureCard
              icon={<Users className="w-8 h-8 text-purple-400" />}
              title="Together, In Sync"
              description="Host jam sessions where playback is perfectly synchronized across everyone's devices."
              delay={0.1}
            />
            <FeatureCard
              icon={<Smartphone className="w-8 h-8 text-blue-400" />}
              title="Share the Vibe"
              description="Flick a song like a card to a friend's phone to share it instantly. Playful and physical."
              delay={0.2}
            />
            <FeatureCard
              icon={<Shield className="w-8 h-8 text-green-400" />}
              title="Private by Design"
              description="All intelligent features run on-device. Your audio interaction data never leaves your phone."
              delay={0.3}
            />
            <FeatureCard
              icon={<Mic className="w-8 h-8 text-pink-400" />}
              title="Smart Lyrics"
              description="Lyrics that don't just scroll—they breathe and pulse in time with the music's rhythm."
              delay={0.4}
            />
            <FeatureCard
              icon={<Compass className="w-8 h-8 text-gray-400" />}
              title="Endless Discovery"
              description="From hidden gems to trending tracks, keep your soundtrack evolving with smart suggestions."
              delay={0.5}
            />
          </div>
        </section>

        {/* Footer */}
        <footer className="py-12 border-t border-white/5 text-center text-gray-500">
          <div className="flex flex-col items-center gap-4 mb-8">
            <div className="w-8 h-8 relative grayscale hover:grayscale-0 transition-all opacity-50 hover:opacity-100">
              <Image src="/icon.png" alt="Dew" fill className="object-contain" />
            </div>
            <p className="text-sm">Designed & Built with ❤️ by Sidharth-06</p>
          </div>
          <p>© {new Date().getFullYear()} Dew Music. All rights reserved.</p>
        </footer>

      </div>
    </div>
  );
}

function FeatureCard({ icon, title, description, delay }: { icon: React.ReactNode, title: string, description: string, delay: number }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true }}
      transition={{ delay, duration: 0.5 }}
      whileHover={{ y: -5 }}
      className="p-8 rounded-3xl bg-white/[0.03] border border-white/5 hover:border-white/10 hover:bg-white/[0.06] transition-all group backdrop-blur-sm"
    >
      <div className="mb-6 p-4 rounded-2xl bg-black/40 w-fit group-hover:scale-110 group-hover:bg-black/60 transition-all shadow-lg ring-1 ring-white/10">
        {icon}
      </div>
      <h3 className="text-xl font-bold mb-3 text-white/90 group-hover:text-white transition-colors">{title}</h3>
      <p className="text-gray-400 leading-relaxed">{description}</p>
    </motion.div>
  );
}
