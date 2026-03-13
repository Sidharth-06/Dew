export function CanvasBackground() {
  return (
    <>
      {/* Base Canvas Color - A soft, light gray/off-white */}
      <div className="fixed inset-0 bg-[#f4f4f5] z-[-2]" />

      {/* Dot Grid Pattern Overlay */}
      <div 
        className="fixed inset-0 z-[-1] pointer-events-none"
        style={{
          backgroundImage: `radial-gradient(#d4d4d8 1.5px, transparent 1.5px)`,
          backgroundSize: '24px 24px',
        }}
      />
      
      {/* Very subtle subtle vignette to frame the content without darkening too much */}
      <div className="fixed inset-0 z-[-1] bg-[radial-gradient(ellipse_at_center,transparent_0%,rgba(0,0,0,0.03)_100%)] pointer-events-none" />
    </>
  );
}
