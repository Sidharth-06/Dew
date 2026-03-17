export function CanvasBackground() {
  return (
    <>
      {/* Base canvas color */}
      <div className="fixed inset-0 bg-[#f4f4f5] z-[-2]" />

      {/* Dot grid */}
      <div
        className="fixed inset-0 z-[-1] pointer-events-none"
        style={{
          backgroundImage: `radial-gradient(#d4d4d8 1.5px, transparent 1.5px)`,
          backgroundSize: '24px 24px',
        }}
      />

      {/* Live doodle layer */}
      <div className="fixed inset-0 z-[-1] pointer-events-none overflow-hidden select-none">

        {/* ── Music notes ── */}
        <span className="absolute text-5xl text-gray-500 font-serif"
          style={{ top: '12%', left: '6%', animation: 'doodle-float 7s ease-in-out infinite', '--doodle-rot': '-15deg', '--doodle-op': '0.09' } as React.CSSProperties}>♩</span>

        <span className="absolute text-3xl text-gray-500 font-serif"
          style={{ top: '38%', left: '4%', animation: 'doodle-float 9.5s ease-in-out infinite 1.4s', '--doodle-rot': '10deg', '--doodle-op': '0.07' } as React.CSSProperties}>♪</span>

        <span className="absolute text-6xl text-gray-500 font-serif"
          style={{ top: '68%', left: '9%', animation: 'doodle-drift 11s ease-in-out infinite 2.8s', '--doodle-rot': '-8deg', '--doodle-op': '0.07' } as React.CSSProperties}>♫</span>

        <span className="absolute text-4xl text-gray-500 font-serif"
          style={{ top: '18%', right: '8%', animation: 'doodle-float 10s ease-in-out infinite 0.6s', '--doodle-rot': '14deg', '--doodle-op': '0.08' } as React.CSSProperties}>♩</span>

        <span className="absolute text-5xl text-gray-500 font-serif"
          style={{ top: '52%', right: '5%', animation: 'doodle-float 8.5s ease-in-out infinite 3.2s', '--doodle-rot': '-6deg', '--doodle-op': '0.07' } as React.CSSProperties}>♫</span>

        <span className="absolute text-3xl text-gray-500 font-serif"
          style={{ top: '80%', right: '12%', animation: 'doodle-drift 12s ease-in-out infinite 1.8s', '--doodle-rot': '20deg', '--doodle-op': '0.07' } as React.CSSProperties}>♪</span>

        <span className="absolute text-4xl text-gray-500 font-serif"
          style={{ top: '5%', left: '45%', animation: 'doodle-float 13s ease-in-out infinite 4s', '--doodle-rot': '-3deg', '--doodle-op': '0.06' } as React.CSSProperties}>♬</span>

        {/* ── Stars / sparkles ── */}
        <span className="absolute text-2xl text-orange-400"
          style={{ top: '28%', left: '18%', animation: 'doodle-sway 8s ease-in-out infinite 2s', '--doodle-rot': '0deg', '--doodle-op': '0.18' } as React.CSSProperties}>✦</span>

        <span className="absolute text-xl text-orange-400"
          style={{ top: '62%', right: '22%', animation: 'doodle-sway 10s ease-in-out infinite 4.5s', '--doodle-rot': '15deg', '--doodle-op': '0.15' } as React.CSSProperties}>✦</span>

        <span className="absolute text-3xl text-orange-300"
          style={{ top: '8%', left: '78%', animation: 'doodle-float 9s ease-in-out infinite 1s', '--doodle-rot': '-10deg', '--doodle-op': '0.14' } as React.CSSProperties}>✧</span>

        <span className="absolute text-2xl text-orange-300"
          style={{ top: '85%', left: '35%', animation: 'doodle-sway 11s ease-in-out infinite 0.5s', '--doodle-rot': '5deg', '--doodle-op': '0.13' } as React.CSSProperties}>✧</span>

        {/* ── Dashed circles (SVG) ── */}
        <svg className="absolute w-28 h-28 text-gray-400" viewBox="0 0 100 100" fill="none" stroke="currentColor" strokeWidth="1.5"
          style={{ top: '22%', right: '28%', animation: 'doodle-sway 14s ease-in-out infinite', '--doodle-rot': '20deg', '--doodle-op': '0.1' } as React.CSSProperties}>
          <circle cx="50" cy="50" r="42" strokeDasharray="6 5" />
        </svg>

        <svg className="absolute w-20 h-20 text-gray-400" viewBox="0 0 100 100" fill="none" stroke="currentColor" strokeWidth="1.5"
          style={{ top: '58%', left: '27%', animation: 'doodle-float 12s ease-in-out infinite 3s', '--doodle-rot': '-18deg', '--doodle-op': '0.09' } as React.CSSProperties}>
          <circle cx="50" cy="50" r="42" strokeDasharray="4 7" />
        </svg>

        <svg className="absolute w-16 h-16 text-gray-400" viewBox="0 0 100 100" fill="none" stroke="currentColor" strokeWidth="2"
          style={{ top: '6%', left: '32%', animation: 'doodle-drift 15s ease-in-out infinite 2s', '--doodle-rot': '8deg', '--doodle-op': '0.08' } as React.CSSProperties}>
          <circle cx="50" cy="50" r="36" strokeDasharray="5 8" />
        </svg>

        {/* ── Wavy line ── */}
        <svg className="absolute w-32 h-8 text-gray-400" viewBox="0 0 120 20" fill="none" stroke="currentColor" strokeWidth="1.5"
          style={{ top: '44%', left: '55%', animation: 'doodle-float 10s ease-in-out infinite 5s', '--doodle-rot': '-6deg', '--doodle-op': '0.1' } as React.CSSProperties}>
          <path d="M0 10 Q15 2,30 10 T60 10 T90 10 T120 10" strokeLinecap="round" />
        </svg>

        <svg className="absolute w-24 h-8 text-gray-400" viewBox="0 0 120 20" fill="none" stroke="currentColor" strokeWidth="1.5"
          style={{ top: '75%', left: '55%', animation: 'doodle-drift 13s ease-in-out infinite 1s', '--doodle-rot': '3deg', '--doodle-op': '0.08' } as React.CSSProperties}>
          <path d="M0 10 Q15 2,30 10 T60 10 T90 10 T120 10" strokeLinecap="round" />
        </svg>

      </div>

      {/* Subtle vignette */}
      <div className="fixed inset-0 z-[-1] bg-[radial-gradient(ellipse_at_center,transparent_0%,rgba(0,0,0,0.03)_100%)] pointer-events-none" />
    </>
  );
}
