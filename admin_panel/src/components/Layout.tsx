import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Header from './Header';

export default function Layout() {
  return (
    <div className="flex h-screen bg-[#07090E] text-slate-100 overflow-hidden relative selection:bg-indigo-500/30 selection:text-indigo-200">
      {/* 3D Dynamic Ambient Lighting Glows */}
      <div className="absolute inset-0 z-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-[15%] -left-[10%] w-[55%] h-[55%] rounded-full bg-gradient-to-br from-indigo-600/25 via-purple-600/15 to-transparent blur-[140px] animate-ambient-1"></div>
        <div className="absolute top-[35%] -right-[15%] w-[60%] h-[60%] rounded-full bg-gradient-to-tl from-cyan-600/20 via-blue-600/10 to-transparent blur-[160px] animate-ambient-2"></div>
        <div className="absolute -bottom-[20%] left-[25%] w-[50%] h-[50%] rounded-full bg-gradient-to-tr from-emerald-600/15 via-teal-600/10 to-transparent blur-[150px] animate-ambient-1"></div>
      </div>
      
      <div className="relative z-10 flex h-full w-full">
        <Sidebar />
        <div className="flex-1 flex flex-col md:ml-[270px] min-w-0 h-full bg-[#0A0D14]/40 backdrop-blur-md">
          <Header />
          <main className="flex-1 overflow-y-auto px-6 py-8 lg:px-10 lg:py-10">
            <Outlet />
          </main>
        </div>
      </div>
    </div>
  );
}

