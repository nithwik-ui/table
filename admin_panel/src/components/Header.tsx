export default function Header() {
  return (
    <header className="flex justify-between items-center h-[64px] px-container-padding-desktop w-full bg-surface border-b border-outline-variant shadow-sm z-40 shrink-0 sticky top-0">
      <div className="flex items-center md:hidden">
        <button className="p-2 text-on-surface-variant hover:bg-surface-container rounded-lg">
          <span className="material-symbols-outlined">menu</span>
        </button>
      </div>
      
      <div className="hidden md:block flex-1"></div>

      <div className="flex items-center gap-stack-md">
        <button className="w-10 h-10 rounded-full flex items-center justify-center text-on-surface-variant hover:text-primary transition-all duration-200 hover:bg-surface-container">
          <span className="material-symbols-outlined font-headline-md text-headline-md">notifications_active</span>
        </button>
        <button className="w-10 h-10 rounded-full flex items-center justify-center text-on-surface-variant hover:text-primary transition-all duration-200 hover:bg-surface-container">
          <span className="material-symbols-outlined font-headline-md text-headline-md">settings</span>
        </button>
        
        <div className="flex items-center gap-stack-sm border-l border-outline-variant pl-stack-md ml-stack-sm">
          <span className="font-label-md text-[13px] text-primary font-medium hidden sm:block">Admin User</span>
          <div className="w-8 h-8 rounded-full bg-primary-fixed-dim text-on-primary-fixed flex items-center justify-center font-bold text-sm cursor-pointer hover:ring-2 ring-primary transition-all overflow-hidden border border-outline-variant">
            AU
          </div>
        </div>
      </div>
    </header>
  );
}
