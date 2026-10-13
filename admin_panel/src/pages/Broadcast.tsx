import { useState, useEffect } from 'react';
import AndroidNotificationPreview from '../components/AndroidNotificationPreview';
import { api } from '../api';

export default function Broadcast() {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [isTestMode, setIsTestMode] = useState(true);
  const [targetAudience, setTargetAudience] = useState<'all' | 'pwa_only'>('all');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [showToast, setShowToast] = useState(false);
  const [toastMessage, setToastMessage] = useState('Broadcast dispatched successfully');
  const [isSending, setIsSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);

  // Dedicated PWA Test State
  const [pwaCustomToken, setPwaCustomToken] = useState('');
  const [isPwaTesting, setIsPwaTesting] = useState(false);
  const [pwaTestResult, setPwaTestResult] = useState<{ success?: boolean; message?: string; error?: string } | null>(null);
  
  const [history, setHistory] = useState<any[]>([]);
  const [historyLoading, setHistoryLoading] = useState(true);

  const fetchHistory = async () => {
    try {
      const data = await api.getAnnouncementsHistory();
      setHistory(data);
    } catch (err) {
      console.error(err);
    } finally {
      setHistoryLoading(false);
    }
  };

  useEffect(() => {
    fetchHistory();
  }, []);

  const handleSendClick = () => {
    if (!title.trim() || !message.trim()) {
      setSendError('Please enter a title and message.');
      return;
    }
    setIsModalOpen(true);
    setSendError(null);
  };

  const confirmSend = async () => {
    setIsSending(true);
    setSendError(null);
    try {
      const res = await api.sendBroadcast(title, message, isTestMode, targetAudience);
      if (res.success) {
        setIsModalOpen(false);
        setToastMessage(targetAudience === 'pwa_only' ? 'PWA Web Push dispatched successfully' : 'Broadcast dispatched successfully');
        setShowToast(true);
        setTitle('');
        setMessage('');
        setTimeout(() => setShowToast(false), 3000);
        fetchHistory(); // Refresh history
      } else {
        setSendError(res.error || 'Failed to send announcement');
      }
    } catch (err: any) {
      if (err.message.includes('429')) {
        setSendError('Too many requests. Please wait and try again.');
      } else if (err.message.includes('401') || err.message.includes('403')) {
        setSendError('You are not authorized to send announcements.');
      } else if (err.message.includes('500')) {
        setSendError('Server error. Please try again later.');
      } else {
        setSendError(err.message || 'Error connecting to server');
      }
    } finally {
      setIsSending(false);
    }
  };

  const handleQuickPwaTest = async () => {
    setIsPwaTesting(true);
    setPwaTestResult(null);
    try {
      const testTitle = title.trim() || '🔔 SRU Timetable PWA Alert';
      const testBody = message.trim() || 'Test push notification delivered specifically to PWA web members!';
      const res = await api.sendPwaTestNotification(testTitle, testBody, pwaCustomToken.trim() || undefined);
      if (res.success) {
        setPwaTestResult({
          success: true,
          message: pwaCustomToken.trim() 
            ? 'Test push sent directly to specified PWA token!'
            : 'Test push broadcasted to all PWA members (topic: sru_pwa_users)!'
        });
        setToastMessage('PWA test notification sent successfully');
        setShowToast(true);
        setTimeout(() => setShowToast(false), 3000);
      } else {
        setPwaTestResult({
          success: false,
          error: res.error || 'Failed to dispatch PWA test push'
        });
      }
    } catch (err: any) {
      setPwaTestResult({
        success: false,
        error: err.message || 'Network error connecting to backend'
      });
    } finally {
      setIsPwaTesting(false);
    }
  };

  return (
    <div className="flex flex-col gap-stack-lg max-w-7xl mx-auto w-full relative z-0">
      <div className="flex flex-col gap-2">
        <div className="flex justify-between items-start">
          <div>
            <h1 className="font-headline-lg text-headline-lg text-primary">Announcements & Push Notifications</h1>
            <p className="font-body-md text-body-md text-on-surface-variant">Send broadcasts and test push notifications across Mobile and PWA Web.</p>
          </div>
          
          <label className="flex items-center gap-3 cursor-pointer bg-surface p-2 rounded-lg border border-outline-variant shadow-sm">
            <span className={`font-label-md text-[13px] ${isTestMode ? 'text-primary font-bold' : 'text-on-surface-variant'}`}>TEST MODE</span>
            <div className={`relative inline-flex h-[24px] w-[44px] items-center rounded-full transition-colors ${isTestMode ? 'bg-primary' : 'bg-error'}`}>
              <span className={`inline-block h-[18px] w-[18px] transform rounded-full bg-white transition-transform ${isTestMode ? 'translate-x-[22px]' : 'translate-x-[4px]'}`} />
            </div>
            <span className={`font-label-md text-[13px] ${!isTestMode ? 'text-error font-bold' : 'text-on-surface-variant'}`}>PRODUCTION</span>
            <input type="checkbox" className="sr-only" checked={isTestMode} onChange={(e) => setIsTestMode(e.target.checked)} />
          </label>
        </div>
      </div>

      {/* Target Audience Selector Bar */}
      <div className="flex flex-wrap items-center gap-3 bg-surface p-3 rounded-[12px] border border-outline-variant">
        <span className="font-label-md text-[13px] font-[600] text-on-surface-variant flex items-center gap-1.5">
          <span className="material-symbols-outlined text-[18px]">group</span> Target Audience:
        </span>
        <button
          onClick={() => setTargetAudience('all')}
          className={`px-4 py-2 rounded-lg font-label-md text-[13px] transition-all flex items-center gap-2 ${
            targetAudience === 'all'
              ? 'bg-primary text-on-primary font-bold shadow-sm'
              : 'bg-surface-container-high text-on-surface hover:bg-surface-container-highest'
          }`}
        >
          <span className="material-symbols-outlined text-[16px]">devices</span>
          All Users (Mobile + PWA)
        </button>
        <button
          onClick={() => setTargetAudience('pwa_only')}
          className={`px-4 py-2 rounded-lg font-label-md text-[13px] transition-all flex items-center gap-2 ${
            targetAudience === 'pwa_only'
              ? 'bg-[#0284C7] text-white font-bold shadow-sm'
              : 'bg-surface-container-high text-on-surface hover:bg-surface-container-highest'
          }`}
        >
          <span className="material-symbols-outlined text-[16px]">laptop_chromebook</span>
          PWA Members Only (Web Push)
        </button>
        {targetAudience === 'pwa_only' && (
          <span className="ml-auto text-[12px] text-[#0284C7] bg-[#0284C7]/10 px-2.5 py-1 rounded-md font-medium border border-[#0284C7]/20 flex items-center gap-1">
            <span className="material-symbols-outlined text-[14px]">info</span>
            Only devices running the Web PWA will receive this
          </span>
        )}
      </div>

      <div className="flex flex-col lg:flex-row gap-6">
        {/* Editor Section */}
        <div className="lg:w-[60%] w-full flex flex-col gap-stack-md relative z-10">
          <div className="glass-panel rounded-[14px] p-6">
             <div className="mb-4">
                <label className="block font-label-md text-on-surface mb-2 font-[600]">Notification Title</label>
                <input 
                  type="text" 
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  placeholder="Enter notification title..."
                  className="w-full h-[40px] px-3 rounded-[8px] bg-white/50 border border-outline-variant/60 text-[14px] text-on-surface outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all shadow-sm"
                />
             </div>
             <div className="mb-6">
                <label className="block font-label-md text-on-surface mb-2 font-[600]">Notification Message</label>
                <textarea 
                  value={message}
                  onChange={(e) => setMessage(e.target.value)}
                  placeholder="Enter notification message..."
                  className="w-full h-[120px] p-3 rounded-[8px] bg-white/50 border border-outline-variant/60 text-[14px] text-on-surface outline-none focus:border-primary focus:ring-2 focus:ring-primary/20 transition-all resize-none shadow-sm"
                />
             </div>
             
             {sendError && !isModalOpen && (
               <div className="mb-4 text-error text-[13px] bg-error/10 p-3 rounded border border-error/20">
                 {sendError}
               </div>
             )}

             <button 
                onClick={handleSendClick}
                className={`w-full h-[48px] rounded-[8px] text-white font-[600] tracking-wide hover:shadow-lg transition-all transform hover:-translate-y-[1px] flex items-center justify-center gap-2 ${
                  targetAudience === 'pwa_only'
                    ? 'bg-gradient-to-r from-[#0284C7] to-[#0369A1] hover:shadow-[#0284C7]/20'
                    : 'bg-gradient-to-r from-primary to-primary-container hover:shadow-primary/20 text-on-primary'
                }`}
              >
                <span className="material-symbols-outlined font-[18px]">send</span>
                {targetAudience === 'pwa_only' ? 'SEND TO PWA MEMBERS ONLY' : 'SEND TO ALL USERS'}
              </button>
          </div>

          {/* Dedicated PWA Test Card */}
          <div className="glass-panel rounded-[14px] p-6 border-l-4 border-l-[#0284C7]">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <span className="material-symbols-outlined text-[#0284C7] text-[22px]">notifications_active</span>
                <h3 className="font-headline-sm text-[16px] font-bold text-on-surface">PWA Members Notification Test</h3>
              </div>
              <span className="text-[11px] font-bold bg-[#0284C7]/15 text-[#0284C7] px-2 py-0.5 rounded-full uppercase tracking-wider">
                Topic: sru_pwa_users
              </span>
            </div>
            <p className="text-[13px] text-on-surface-variant mb-4">
              Instantly send a test notification specifically to PWA web devices. You can also specify a single token to test an individual browser.
            </p>

            <div className="flex flex-col gap-3">
              <div>
                <label className="block text-[12px] font-semibold text-on-surface-variant mb-1">
                  Optional: Specific PWA FCM Token (leave empty to broadcast to all PWA members)
                </label>
                <input
                  type="text"
                  value={pwaCustomToken}
                  onChange={(e) => setPwaCustomToken(e.target.value)}
                  placeholder="Paste browser FCM token or leave blank for all PWA users..."
                  className="w-full h-[38px] px-3 rounded-[8px] bg-white/50 border border-outline-variant/60 text-[13px] font-mono text-on-surface outline-none focus:border-[#0284C7] focus:ring-1 focus:ring-[#0284C7] transition-all"
                />
              </div>

              {pwaTestResult && (
                <div className={`p-3 rounded-lg text-[13px] border ${
                  pwaTestResult.success 
                    ? 'bg-[#10B981]/10 text-[#10B981] border-[#10B981]/20' 
                    : 'bg-error/10 text-error border-error/20'
                }`}>
                  {pwaTestResult.success ? pwaTestResult.message : pwaTestResult.error}
                </div>
              )}

              <button
                onClick={handleQuickPwaTest}
                disabled={isPwaTesting}
                className="w-full h-[42px] rounded-[8px] bg-[#0284C7] hover:bg-[#0369A1] text-white font-[600] text-[13px] transition-all flex items-center justify-center gap-2 disabled:opacity-50"
              >
                {isPwaTesting ? (
                  <>
                    <span className="material-symbols-outlined animate-spin text-[18px]">progress_activity</span>
                    Sending PWA Push...
                  </>
                ) : (
                  <>
                    <span className="material-symbols-outlined text-[18px]">bolt</span>
                    SEND TEST TO PWA MEMBERS NOW
                  </>
                )}
              </button>
            </div>
          </div>
        </div>

        {/* Live Preview Section */}
        <div className="lg:w-[40%] w-full flex flex-col relative z-10">
          <div className="glass-panel rounded-[14px] p-6 h-full flex flex-col sticky top-24">
            <h3 className="font-headline-sm text-[18px] text-primary mb-stack-md flex items-center gap-2">
              <span className="material-symbols-outlined text-on-surface-variant">preview</span> Live Preview
            </h3>
            <AndroidNotificationPreview 
              title={title || 'Notification Title'} 
              message={message || 'Notification Message'} 
            />
            
            <div className="mt-8 p-4 bg-surface-container-lowest border border-outline-variant rounded-[12px]">
              <div className="flex justify-between items-center mb-2">
                <span className="text-[11px] font-[600] text-on-surface-variant uppercase tracking-wider">Target Audience</span>
                <span className={`inline-flex items-center px-2 py-1 rounded-full text-[11px] font-[600] gap-1 border ${
                  targetAudience === 'pwa_only'
                    ? 'bg-[#0284C7]/15 text-[#0284C7] border-[#0284C7]/30'
                    : 'bg-secondary-fixed text-on-secondary-fixed border-secondary-container'
                }`}>
                  {targetAudience === 'pwa_only' ? 'PWA Members Only' : 'All Users'}
                </span>
              </div>
              <p className="text-[12px] text-on-surface-variant">
                {targetAudience === 'pwa_only'
                  ? 'Delivered to browsers running the PWA via WebPush (topic: sru_pwa_users). Mobile devices will not receive this.'
                  : 'Delivered to all registered devices via the sru_all_users FCM topic.'}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Broadcast History */}
      <div className="glass-panel rounded-xl overflow-hidden flex flex-col mt-4 relative z-10">
        <div className="p-stack-md border-b border-white/20 flex justify-between items-center bg-white/40">
          <h3 className="font-headline-sm text-headline-sm text-primary font-[700]">Announcement History</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left border-collapse backdrop-blur-sm">
            <thead>
              <tr className="bg-white/30 font-label-sm text-[12px] text-on-surface-variant border-b border-white/20">
                <th className="py-3 px-stack-md font-[600] uppercase tracking-wider">Date</th>
                <th className="py-3 px-stack-md font-[600] uppercase tracking-wider">Title</th>
                <th className="py-3 px-stack-md font-[600] uppercase tracking-wider">Message</th>
                <th className="py-3 px-stack-md font-[600] uppercase tracking-wider text-right">Status</th>
              </tr>
            </thead>
            <tbody className="font-body-sm text-[13px] text-on-surface divide-y divide-outline-variant/50">
              {historyLoading && (
                <tr className="h-14">
                  <td colSpan={4} className="py-3 px-stack-md text-center text-on-surface-variant">Loading history...</td>
                </tr>
              )}
              {!historyLoading && history.length === 0 && (
                <tr className="h-14">
                  <td colSpan={4} className="py-3 px-stack-md text-center text-on-surface-variant">No announcement history recorded.</td>
                </tr>
              )}
              {history.map(item => (
                <tr key={item.id} className="hover:bg-white/40 transition-colors border-b border-white/10 last:border-0">
                  <td className="py-3 px-stack-md whitespace-nowrap text-on-surface-variant">{new Date(item.created_at).toLocaleString()}</td>
                  <td className="py-3 px-stack-md font-medium text-primary">{item.title}</td>
                  <td className="py-3 px-stack-md text-on-surface-variant truncate max-w-[200px]" title={item.message}>{item.message || '-'}</td>
                  <td className="py-3 px-stack-md text-right">
                    <span className={`inline-flex items-center px-2 py-1 rounded-full text-[11px] font-[600] ${
                      item.status === 'Sent' ? 'bg-[#10B981]/10 text-[#10B981] border border-[#10B981]/20' :
                      item.status === 'Test' ? 'bg-primary/10 text-primary border border-primary/20' :
                      'bg-error/10 text-error border border-error/20'
                    }`}>
                      {item.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Confirmation Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/30 backdrop-blur-md animate-fade-in">
          <div className="bg-surface w-full max-w-md rounded-2xl shadow-2xl overflow-hidden animate-slide-up border border-outline-variant/30">
            <div className={`h-2 ${targetAudience === 'pwa_only' ? 'bg-[#0284C7]' : (isTestMode ? 'bg-primary' : 'bg-error')}`}></div>
            <div className="p-6 flex flex-col gap-4">
              <div className="flex gap-4">
                <div className={`w-12 h-12 rounded-full flex items-center justify-center shrink-0 ${
                  targetAudience === 'pwa_only' ? 'bg-[#0284C7]/20 text-[#0284C7]' : (isTestMode ? 'bg-primary-container text-on-primary-container' : 'bg-error-container text-on-error-container')
                }`}>
                  <span className="material-symbols-outlined text-[24px]">
                    {targetAudience === 'pwa_only' ? 'laptop_chromebook' : (isTestMode ? 'science' : 'warning')}
                  </span>
                </div>
                <div>
                  <h3 className="font-headline-sm text-[18px] text-on-surface">Confirm Broadcast</h3>
                  <p className="font-body-sm text-[14px] text-on-surface-variant mt-1">
                    {targetAudience === 'pwa_only'
                      ? 'This push notification will be delivered ONLY to PWA Web users. Mobile apps will not receive it.'
                      : (isTestMode 
                          ? 'You are about to send a test push notification. This will only be delivered to your local testing devices.'
                          : 'WARNING: You are about to send a production push notification to ALL registered users.')}
                  </p>
                </div>
              </div>
              
              <div className="bg-surface-container-lowest border border-outline-variant rounded-xl p-4 mt-2">
                <div className="text-[12px] font-[600] text-on-surface-variant mb-1 uppercase tracking-wider">Target</div>
                <div className="font-body-md text-primary mb-3 font-[600]">
                  {targetAudience === 'pwa_only' ? '💻 PWA Members Only' : '📱 All Users (Mobile + PWA)'}
                </div>
                <div className="text-[12px] font-[600] text-on-surface-variant mb-1 uppercase tracking-wider">Title</div>
                <div className="font-body-md text-on-surface mb-3 font-[500]">{title}</div>
                <div className="text-[12px] font-[600] text-on-surface-variant mb-1 uppercase tracking-wider">Message</div>
                <div className="font-body-md text-on-surface">{message}</div>
              </div>

              {sendError && (
                <div className="p-3 bg-error-container/50 text-on-error-container text-[13px] rounded-lg border border-error/20">
                  {sendError}
                </div>
              )}
            </div>
            
            <div className="p-4 bg-surface-container-low flex justify-end gap-2 border-t border-outline-variant/50">
              <button 
                onClick={() => setIsModalOpen(false)}
                disabled={isSending}
                className="px-5 py-2.5 rounded-full font-label-md text-[14px] font-[600] text-on-surface-variant hover:bg-surface-container transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
              <button 
                onClick={confirmSend}
                disabled={isSending}
                className={`px-5 py-2.5 rounded-full font-label-md text-[14px] font-[600] transition-colors flex items-center gap-2 disabled:opacity-50 ${
                  targetAudience === 'pwa_only'
                    ? 'bg-[#0284C7] text-white hover:bg-[#0369A1]'
                    : (isTestMode 
                        ? 'bg-primary text-on-primary hover:bg-primary/90' 
                        : 'bg-error text-on-error hover:bg-error/90')
                }`}
              >
                {isSending ? (
                  <>
                    <span className="material-symbols-outlined animate-spin text-[18px]">progress_activity</span>
                    Sending...
                  </>
                ) : (
                  <>
                    <span className="material-symbols-outlined text-[18px]">send</span>
                    {targetAudience === 'pwa_only' ? 'Send to PWA Members' : (isTestMode ? 'Send Test' : 'Send to All Users')}
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Success Toast */}
      {showToast && (
        <div className="fixed bottom-8 left-1/2 -translate-x-1/2 z-50 animate-fade-in-up">
          <div className="bg-inverse-surface text-inverse-on-surface px-4 py-3 rounded-xl shadow-lg flex items-center gap-3 font-body-md">
            <span className="material-symbols-outlined text-[#10B981]">check_circle</span>
            {toastMessage}
          </div>
        </div>
      )}
    </div>
  );
}
