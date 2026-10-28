interface NotificationPreviewProps {
  title: string;
  message: string;
  logoUrl?: string;
  timestamp?: string;
}

export default function AndroidNotificationPreview({
  title,
  message,
  timestamp = "10:30"
}: NotificationPreviewProps) {
  return (
    <div className="flex-1 flex flex-col items-center justify-center p-4 relative min-h-[520px]">
      {/* 3D Floor Shadow / Radial Glow */}
      <div className="absolute bottom-4 w-72 h-8 bg-indigo-500/20 blur-xl rounded-full transform scale-x-125"></div>
      
      {/* 3D Realistic Smartphone Frame */}
      <div className="w-[320px] sm:w-[350px] bg-[#121620] rounded-[44px] p-3 shadow-[0_25px_60px_-15px_rgba(0,0,0,0.85),0_0_0_1px_rgba(255,255,255,0.15),0_2px_4px_rgba(255,255,255,0.2)_inset] relative flex flex-col border-[5px] border-[#222838] transition-transform duration-300 hover:scale-[1.02] group">
        
        {/* Dynamic Glass Specular Highlight (Reflection) */}
        <div className="absolute inset-0 rounded-[38px] bg-gradient-to-tr from-transparent via-white/[0.04] to-white/[0.08] pointer-events-none z-30"></div>

        {/* Screen Bezel Container */}
        <div className="w-full bg-[#05070B] rounded-[36px] overflow-hidden flex flex-col p-4 relative min-h-[500px] border border-white/5">
          
          {/* Top Notch / Camera & Speaker */}
          <div className="flex justify-between items-center text-slate-300 px-2 py-1 mb-8 z-20">
            <span className="text-[12px] font-semibold tracking-tight">{timestamp}</span>
            
            {/* Center Punch Hole Camera */}
            <div className="w-3.5 h-3.5 rounded-full bg-black border border-slate-700/60 flex items-center justify-center">
              <div className="w-1.5 h-1.5 rounded-full bg-blue-900/60"></div>
            </div>

            <div className="flex items-center gap-1.5 text-slate-300">
              <span className="material-symbols-outlined text-[13px]">signal_cellular_alt</span>
              <span className="material-symbols-outlined text-[13px]">wifi</span>
              <span className="material-symbols-outlined text-[13px]">battery_full</span>
            </div>
          </div>

          {/* Lockscreen Ambient Clock */}
          <div className="text-center text-white my-auto flex flex-col items-center">
            <h4 className="text-5xl font-light tracking-tight font-['Outfit'] drop-shadow-md">
              {timestamp}
            </h4>
            <p className="text-[13px] text-slate-400 mt-1 font-medium tracking-wide">
              Wednesday, Today
            </p>
          </div>

          {/* 3D Floating Push Notification Card */}
          <div className="my-auto w-full z-20">
            <div className="w-full bg-[#1A2234]/95 backdrop-blur-xl rounded-2xl p-3.5 shadow-[0_15px_30px_rgba(0,0,0,0.6),0_0_0_1px_rgba(255,255,255,0.12)_inset] border border-white/10 text-white transition-all duration-200 hover:border-indigo-500/50">
              
              {/* Notification Header */}
              <div className="flex items-center gap-2 mb-2">
                <div className="w-7 h-7 rounded-lg bg-gradient-to-tr from-indigo-600 to-purple-600 flex items-center justify-center text-white shadow-[0_2px_6px_rgba(99,102,241,0.5),inset_0_1px_1px_rgba(255,255,255,0.4)]">
                  <span className="material-symbols-outlined text-[16px]">calendar_today</span>
                </div>
                <div className="flex flex-col">
                  <span className="text-[11.5px] font-bold tracking-tight text-slate-100 flex items-center gap-1">
                    SRU Timetable
                    <span className="w-1 h-1 rounded-full bg-indigo-400"></span>
                  </span>
                  <span className="text-[9.5px] text-indigo-300/80 font-mono">FCM Broadcast</span>
                </div>
                <span className="text-[10px] text-slate-400 ml-auto flex items-center gap-0.5">
                  now <span className="material-symbols-outlined text-[12px]">expand_more</span>
                </span>
              </div>

              {/* Notification Body */}
              <h5 className="font-bold text-[13px] text-white mb-1 leading-snug line-clamp-1">
                {title || 'Announcement Title Preview'}
              </h5>
              <p className="text-[12px] text-slate-300 line-clamp-3 leading-relaxed whitespace-pre-wrap">
                {message || 'This is how your students and members will see your notification on their lockscreen and notification tray.'}
              </p>

              {/* Quick Action Chips */}
              <div className="mt-3 pt-2.5 border-t border-white/10 flex items-center gap-2">
                <button className="px-2.5 py-1 rounded-lg bg-white/10 hover:bg-white/15 text-[10.5px] font-semibold text-slate-200 transition-colors">
                  Open App
                </button>
                <button className="px-2.5 py-1 rounded-lg bg-transparent hover:bg-white/5 text-[10.5px] font-medium text-slate-400 transition-colors">
                  Dismiss
                </button>
              </div>
            </div>
          </div>

          {/* Android Gesture Bar */}
          <div className="w-28 h-1 bg-white/30 rounded-full mx-auto mt-auto mb-1"></div>
        </div>
      </div>
    </div>
  );
}

