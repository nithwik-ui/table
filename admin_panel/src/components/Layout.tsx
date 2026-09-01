import { Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Header from './Header';

export default function Layout() {
  return (
    <div className="flex h-screen bg-background text-on-background font-body-md overflow-hidden relative">
      {/* Animated gradient mesh background */}
      <div className="absolute inset-0 z-0 overflow-hidden pointer-events-none">
        <div className="absolute -top-[20%] -left-[10%] w-[50%] h-[50%] rounded-full bg-gradient-to-br from-primary/20 to-transparent blur-[100px] animate-gradient-xy"></div>
        <div className="absolute top-[40%] -right-[10%] w-[60%] h-[60%] rounded-full bg-gradient-to-tl from-secondary-fixed/30 to-transparent blur-[120px] animate-gradient-xy" style={{ animationDelay: '2s' }}></div>
      </div>
      
      <div className="relative z-10 flex h-full w-full">
        <Sidebar />
        <div className="flex-1 flex flex-col md:ml-[250px] min-w-0 h-full bg-surface/30 backdrop-blur-sm">
          <Header />
          <main className="flex-1 overflow-y-auto p-container-padding-desktop">
            <Outlet />
          </main>
        </div>
      </div>
    </div>
  );
}
