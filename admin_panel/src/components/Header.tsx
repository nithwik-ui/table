import { useState, useEffect } from 'react';

export default function Header() {
  const [timeStr, setTimeStr] = useState('');

  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      setTimeStr(
        now.toLocaleTimeString('en-IN', {
          timeZone: 'Asia/Kolkata',
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit',
          hour12: true
        }) + ' IST'
      );
    };
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  return (
    <header className="flex justify-between items-center h-[70px] px-6 w-full bg-[#0F172A]/70 backdrop-blur-xl border-b border-white/10 shadow-[0_4px_25px_rgba(0,0,0,0.4)] z-20 shrink-0 sticky top-0">
      {/* Mobile Drawer Toggle / Breadcrumb */}
      <div className="flex items-center gap-3">
        <div className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-slate-900/80 border border-white/10 shadow-[inset_0_1px_1px_rgba(255,255,255,0.1)]">
          <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
          <span className="text-[12px] font-semibold text-slate-300 font-mono">
            {timeStr || 'SRU Campus Time'}
          </span>
        </div>
        <span className="hidden sm:inline-block text-[11px] font-medium text-slate-400 border-l border-white/10 pl-3">
          Warangal Campus
        </span>
      </div>

      {/* Right Controls */}
      <div className="flex items-center gap-3">
        <div className="hidden lg:flex items-center gap-2 px-3 py-1.5 rounded-xl bg-indigo-500/10 border border-indigo-500/20 text-indigo-300 text-[12px] font-medium">
          <span className="material-symbols-outlined text-[16px] text-indigo-400">cloud_done</span>
          <span>FCM & Cloud Sync Online</span>
        </div>

        <div className="flex items-center gap-3 pl-3 border-l border-white/10">
          <div className="text-right hidden sm:block">
            <p className="text-[13px] font-bold text-white leading-tight">Admin Console</p>
            <p className="text-[11px] text-emerald-400 font-mono leading-none mt-0.5">Active Session</p>
          </div>
          
          <div className="relative group cursor-pointer">
            <div className="absolute -inset-0.5 bg-gradient-to-r from-indigo-500 to-cyan-500 rounded-full blur opacity-60 group-hover:opacity-100 transition duration-200"></div>
            <div className="relative w-9 h-9 rounded-full bg-gradient-to-br from-indigo-600 via-purple-600 to-slate-900 border border-white/30 flex items-center justify-center font-bold text-xs text-white shadow-[0_2px_8px_rgba(0,0,0,0.4),inset_0_1px_2px_rgba(255,255,255,0.4)]">
              AU
            </div>
            <span className="absolute bottom-0 right-0 w-2.5 h-2.5 rounded-full bg-emerald-400 border-2 border-[#0F172A]"></span>
          </div>
        </div>
      </div>
    </header>
  );
}

