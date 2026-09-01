interface NotificationPreviewProps {
  title: string;
  message: string;
  logoUrl?: string;
  timestamp?: string;
}

export default function AndroidNotificationPreview({
  title,
  message,
  timestamp = "10:00"
}: NotificationPreviewProps) {
  return (
    <div className="flex-1 bg-surface-container-high rounded-xl flex items-center justify-center p-stack-lg border border-outline-variant overflow-hidden relative min-h-[500px]">
      {/* Faux Phone Background */}
      <div 
        className="absolute inset-0 opacity-10 pointer-events-none" 
        style={{ backgroundImage: "url('data:image/svg+xml,%3Csvg width=\\'20\\' height=\\'20\\' viewBox=\\'0 0 20 20\\' xmlns=\\'http://www.w3.org/2000/svg\\'%3E%3Cg fill=\\'%23091426\\' fill-opacity=\\'1\\' fill-rule=\\'evenodd\\'%3E%3Ccircle cx=\\'3\\' cy=\\'3\\' r=\\'3\\'/%3E%3Ccircle cx=\\'13\\' cy=\\'13\\' r=\\'3\\'/%3E%3C/g%3E%3C/svg%3E')" }}
      ></div>
      
      {/* Android Lockscreen Mock */}
      <div className="w-[390px] h-[780px] bg-[#000000] rounded-[32px] p-3 shadow-2xl relative border-[6px] border-[#303032] flex flex-col transform scale-75 xl:scale-90 origin-top z-10">
        
        {/* Top Bar */}
        <div className="flex justify-between items-center text-white px-3 py-1 mb-16">
          <span className="text-[13px] font-medium opacity-80">{timestamp}</span>
          <div className="flex gap-1.5 opacity-80">
            <span className="material-symbols-outlined text-[14px]">signal_cellular_4_bar</span>
            <span className="material-symbols-outlined text-[14px]">wifi</span>
            <span className="material-symbols-outlined text-[14px]">battery_full</span>
          </div>
        </div>

        {/* Time */}
        <div className="text-center text-white mb-8">
          <h4 className="text-6xl font-light tracking-tight">{timestamp}</h4>
          <p className="text-base opacity-80 mt-2">Mon, Aug 29</p>
        </div>

        {/* Notification Card */}
        <div className="w-[350px] mx-auto bg-[#1C1C1E]/90 backdrop-blur-md rounded-[16px] p-4 shadow-lg text-white border border-[#ffffff]/10">
          <div className="flex items-center gap-2 mb-2">
            <div className="w-[32px] h-[32px] rounded-md bg-white p-0.5 flex items-center justify-center text-primary shrink-0">
              <span className="material-symbols-outlined text-[20px]">calendar_today</span>
            </div>
            <span className="text-[12px] font-medium opacity-80">SRU Timetable</span>
            <span className="text-[12px] opacity-60 ml-auto flex items-center gap-1">
              now <span className="material-symbols-outlined text-[14px]">expand_more</span>
            </span>
          </div>
          <h5 className="font-medium text-sm mb-1 line-clamp-1">{title}</h5>
          <p className="text-[13px] opacity-80 line-clamp-2 leading-tight whitespace-pre-wrap">{message}</p>
        </div>

        {/* Home Indicator */}
        <div className="w-1/3 h-1 bg-white/40 rounded-full mx-auto mt-auto mb-2"></div>
      </div>
    </div>
  );
}
