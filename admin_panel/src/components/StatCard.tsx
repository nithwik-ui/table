interface StatCardProps {
  title: string;
  value: string | number;
  icon: string;
  trendText?: string;
  trendIcon?: string;
  colorScheme?: 'primary' | 'secondary' | 'tertiary' | 'error';
}

export default function StatCard({ 
  title, 
  value, 
  icon, 
  trendText, 
  trendIcon,
  colorScheme = 'primary'
}: StatCardProps) {
  
  const colors = {
    primary: {
      bgHover: 'group-hover:bg-primary-fixed/50',
      bgBlur: 'bg-primary-fixed/30',
      iconBg: 'bg-surface-container',
      iconColor: 'text-on-surface-variant',
      border: 'border-outline-variant',
      trendColor: 'text-emerald-600'
    },
    secondary: {
      bgHover: 'group-hover:bg-secondary-fixed/50',
      bgBlur: 'bg-secondary-fixed/30',
      iconBg: 'bg-surface-container',
      iconColor: 'text-on-surface-variant',
      border: 'border-outline-variant',
      trendColor: 'text-on-surface-variant'
    },
    tertiary: {
      bgHover: 'group-hover:bg-tertiary-fixed/50',
      bgBlur: 'bg-tertiary-fixed/30',
      iconBg: 'bg-surface-container',
      iconColor: 'text-on-surface-variant',
      border: 'border-outline-variant',
      trendColor: 'text-on-surface-variant'
    },
    error: {
      bgHover: 'group-hover:bg-error-container/80',
      bgBlur: 'bg-error-container/50',
      iconBg: 'bg-error-container',
      iconColor: 'text-error',
      border: 'border-error-container',
      trendColor: 'text-error'
    }
  };

  const scheme = colors[colorScheme];

  return (
    <div className={`bg-surface border ${scheme.border} rounded-[14px] p-[20px] h-[132px] shadow-sm hover:shadow-md transition-shadow relative overflow-hidden group`}>
      <div className={`absolute -right-4 -top-4 w-24 h-24 rounded-full blur-2xl transition-colors ${scheme.bgBlur} ${scheme.bgHover}`}></div>
      
      <div className="flex justify-between items-start mb-4">
        <div className={`p-2 rounded-lg ${scheme.iconBg} ${scheme.iconColor} relative z-10`}>
          <span className="material-symbols-outlined">{icon}</span>
        </div>
      </div>
      
      <div className="relative z-10">
        <p className="font-label-sm text-label-sm text-on-surface-variant uppercase tracking-wider mb-1">{title}</p>
        <h3 className="text-[28px] font-semibold text-on-surface mb-2 leading-none">{value}</h3>
        
        {trendText && (
          <div className={`flex items-center gap-1 mt-2 ${scheme.trendColor}`}>
            {trendIcon === 'dot' ? (
               <span className="w-2 h-2 rounded-full bg-emerald-500"></span>
            ) : (
               <span className="material-symbols-outlined text-sm">{trendIcon}</span>
            )}
            <span className="font-label-sm text-label-sm">{trendText}</span>
          </div>
        )}
      </div>
    </div>
  );
}
