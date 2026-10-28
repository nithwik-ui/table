import { NavLink } from 'react-router-dom';

const navItems = [
  { 
    path: '/', 
    icon: 'campaign', 
    label: 'Broadcast & Push', 
    badge: 'Live',
    badgeColor: 'bg-indigo-500/20 text-indigo-300 border-indigo-500/30'
  },
  { 
    path: '/test-class', 
    icon: 'science', 
    label: 'Class Simulator', 
    badge: 'Lab',
    badgeColor: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/30'
  },
  { 
    path: '/holidays', 
    icon: 'calendar_month', 
    label: 'Holidays & Calendar', 
    badge: 'Sync',
    badgeColor: 'bg-amber-500/20 text-amber-300 border-amber-500/30'
  },
];

export default function Sidebar() {
  return (
    <aside className="fixed h-full w-[270px] left-0 top-0 bg-[#0F172A]/85 backdrop-blur-2xl border-r border-white/10 flex flex-col py-6 px-4 z-30 hidden md:flex shadow-[10px_0_30px_rgba(0,0,0,0.5)]">
      {/* Brand Header with 3D Emblem */}
      <div className="mb-8 px-2 flex items-center gap-3">
        <div className="relative group">
          <div className="absolute -inset-1 bg-gradient-to-r from-indigo-500 via-purple-500 to-cyan-500 rounded-2xl blur opacity-70 group-hover:opacity-100 transition duration-300"></div>
          <div className="relative w-12 h-12 rounded-xl bg-gradient-to-b from-[#1E293B] to-[#0F172A] border border-white/20 flex items-center justify-center shadow-[0_4px_10px_rgba(0,0,0,0.5),inset_0_1px_1px_rgba(255,255,255,0.3)]">
            <span className="material-symbols-outlined text-[26px] bg-gradient-to-tr from-indigo-400 via-cyan-300 to-white bg-clip-text text-transparent">
              admin_panel_settings
            </span>
          </div>
        </div>
        <div>
          <div className="flex items-center gap-1.5">
            <h1 className="text-[17px] font-extrabold tracking-tight text-white font-['Outfit']">
              SRU Timetable
            </h1>
            <span className="text-[10px] font-bold px-1.5 py-0.5 rounded-full bg-gradient-to-r from-indigo-500 to-purple-500 text-white shadow-sm">
              v3.0
            </span>
          </div>
          <p className="text-[11px] font-medium text-slate-400 tracking-wide uppercase">
            Master Console
          </p>
        </div>
      </div>

      {/* Navigation Section */}
      <div className="px-2 mb-2 text-[11px] font-bold tracking-wider text-slate-400 uppercase">
        Modules
      </div>
      
      <nav className="flex-1 flex flex-col gap-2">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) =>
              `relative group flex items-center justify-between px-3.5 py-3 rounded-xl transition-all duration-200 ${
                isActive
                  ? 'bg-gradient-to-r from-indigo-600/30 via-indigo-500/20 to-transparent text-white border border-indigo-500/40 shadow-[0_4px_15px_rgba(99,102,241,0.25),inset_0_1px_1px_rgba(255,255,255,0.2)]'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-white/5 border border-transparent'
              }`
            }
          >
            {({ isActive }) => (
              <>
                <div className="flex items-center gap-3">
                  <div className={`w-8 h-8 rounded-lg flex items-center justify-center transition-all ${
                    isActive 
                      ? 'bg-indigo-500 text-white shadow-[0_2px_8px_rgba(99,102,241,0.5)]' 
                      : 'bg-slate-800/80 text-slate-400 group-hover:text-white group-hover:bg-slate-700/80'
                  }`}>
                    <span className="material-symbols-outlined text-[19px]">
                      {item.icon}
                    </span>
                  </div>
                  <span className="text-[13.5px] font-semibold tracking-wide">
                    {item.label}
                  </span>
                </div>
                
                {item.badge && (
                  <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full border ${item.badgeColor} shadow-sm`}>
                    {item.badge}
                  </span>
                )}

                {isActive && (
                  <div className="absolute right-0 top-1/2 -translate-y-1/2 w-1.5 h-6 bg-gradient-to-b from-indigo-400 to-cyan-400 rounded-l-full shadow-[0_0_8px_#6366F1]" />
                )}
              </>
            )}
          </NavLink>
        ))}
      </nav>
      
      {/* Footer Info & Server Pulse */}
      <div className="mt-auto flex flex-col gap-3 pt-4 border-t border-white/10">
        <div className="p-3 rounded-xl bg-gradient-to-b from-slate-900/90 to-slate-950 border border-white/10 shadow-[inset_0_1px_1px_rgba(255,255,255,0.05)]">
          <div className="flex items-center justify-between mb-1">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Server Status</span>
            <span className="flex items-center gap-1.5 text-[11px] font-bold text-emerald-400">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
              </span>
              Operational
            </span>
          </div>
          <p className="text-[11px] text-slate-400 leading-tight">
            FCM & Timetable API sync active on port 8000
          </p>
        </div>

        <div className="flex items-center justify-between px-2 text-[11px] text-slate-400">
          <span>SRU Timetable 3.0</span>
          <span className="text-indigo-400 font-mono">v3.0.0+31</span>
        </div>
      </div>
    </aside>
  );
}

