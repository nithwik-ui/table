import { NavLink } from 'react-router-dom';

const navItems = [
  { path: '/', icon: 'campaign', label: 'Broadcast', filled: true },
  { path: '/test-class', icon: 'science', label: 'Test Class', filled: true },
  { path: '/holidays', icon: 'event', label: 'Holidays', filled: true },
  { path: '/faculty', icon: 'manage_accounts', label: 'Faculty', filled: true },
];

export default function Sidebar() {
  return (
    <aside className="fixed h-full w-[250px] left-0 top-0 bg-surface border-r border-outline-variant flex flex-col py-stack-lg px-stack-md z-20 hidden md:flex">
      <div className="mb-stack-lg px-unit flex items-center gap-stack-sm cursor-pointer transition-transform active:scale-95">
        <div className="w-10 h-10 rounded-lg overflow-hidden bg-primary-container flex items-center justify-center shrink-0 text-on-primary-container">
          <span className="material-symbols-outlined font-headline-sm fill-icon">admin_panel_settings</span>
        </div>
        <div>
          <h1 className="font-headline-sm text-[16px] leading-[24px] font-bold text-primary">SRU Timetable</h1>
          <p className="font-label-sm text-[11px] text-on-surface-variant">Admin Console</p>
        </div>
      </div>
      
      <nav className="flex-1 flex flex-col gap-unit">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) =>
              `flex items-center gap-3 px-3 py-2.5 rounded-lg font-label-md text-label-md cursor-pointer active:scale-95 transition-transform ${
                isActive
                  ? 'bg-secondary-container text-on-secondary-container font-semibold'
                  : 'text-on-surface-variant hover:bg-surface-container transition-colors'
              }`
            }
          >
            {({ isActive }) => (
              <>
                <span className={`material-symbols-outlined font-label-md text-[18px] ${isActive || item.filled ? 'fill-icon' : ''}`}>
                  {item.icon}
                </span>
                <span className="font-label-md text-[13px]">{item.label}</span>
              </>
            )}
          </NavLink>
        ))}
      </nav>
      
      <div className="mt-auto flex flex-col gap-unit border-t border-outline-variant pt-stack-md">
        <div className="flex items-center gap-2 px-stack-sm py-2 text-[12px] font-semibold text-on-surface-variant">
          <span className="w-2 h-2 rounded-full bg-[#10B981]"></span> Backend Online
        </div>
        <a href="#" className="flex items-center gap-stack-sm px-stack-sm py-2 rounded-lg text-on-surface-variant hover:bg-surface-container transition-colors cursor-pointer active:scale-95 transition-transform">
          <span className="material-symbols-outlined font-label-md text-[18px]">help</span>
          <span className="font-label-md text-[13px]">Help Center</span>
        </a>
      </div>
    </aside>
  );
}
