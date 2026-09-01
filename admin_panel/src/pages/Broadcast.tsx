import { useState, useEffect } from 'react';
import AndroidNotificationPreview from '../components/AndroidNotificationPreview';
import { api } from '../api';

export default function Broadcast() {
  const [title, setTitle] = useState('');
  const [message, setMessage] = useState('');
  const [isTestMode, setIsTestMode] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [showToast, setShowToast] = useState(false);
  const [isSending, setIsSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  
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
      const res = await api.sendBroadcast(title, message, isTestMode);
      if (res.success) {
        setIsModalOpen(false);
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

  return (
    <div className="flex flex-col gap-stack-lg max-w-7xl mx-auto w-full relative z-0">
      <div className="flex flex-col gap-2">
        <div className="flex justify-between items-start">
          <div>
            <h1 className="font-headline-lg text-headline-lg text-primary">Quick Announcements</h1>
            <p className="font-body-md text-body-md text-on-surface-variant">Send a notification to all SRU Timetable users.</p>
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
                className="w-full h-[48px] rounded-[8px] bg-gradient-to-r from-primary to-primary-container text-on-primary font-[600] tracking-wide hover:shadow-lg hover:shadow-primary/20 transition-all transform hover:-translate-y-[1px] flex items-center justify-center gap-2"
              >
                <span className="material-symbols-outlined font-[18px]">send</span>
                SEND TO ALL USERS
              </button>
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
                <span className="inline-flex items-center px-2 py-1 rounded-full bg-secondary-fixed text-on-secondary-fixed text-[11px] font-[600] gap-1 border border-secondary-container">
                  All Users
                </span>
              </div>
              <p className="text-[12px] text-on-surface-variant">This announcement will be delivered to the existing <code className="bg-surface-container px-1 py-0.5 rounded">sru_all_users</code> FCM topic.</p>
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
            <div className={`h-2 ${isTestMode ? 'bg-primary' : 'bg-error'}`}></div>
            <div className="p-6 flex flex-col gap-4">
              <div className="flex gap-4">
                <div className={`w-12 h-12 rounded-full flex items-center justify-center shrink-0 ${isTestMode ? 'bg-primary-container text-on-primary-container' : 'bg-error-container text-on-error-container'}`}>
                  <span className="material-symbols-outlined text-[24px]">
                    {isTestMode ? 'science' : 'warning'}
                  </span>
                </div>
                <div>
                  <h3 className="font-headline-sm text-[18px] text-on-surface">Confirm Broadcast</h3>
                  <p className="font-body-sm text-[14px] text-on-surface-variant mt-1">
                    {isTestMode 
                      ? 'You are about to send a test push notification. This will only be delivered to your local testing devices and will not wake up normal users.'
                      : 'WARNING: You are about to send a production push notification. This will instantly wake up and alert ALL registered users.'}
                  </p>
                </div>
              </div>
              
              <div className="bg-surface-container-lowest border border-outline-variant rounded-xl p-4 mt-2">
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
                  isTestMode 
                    ? 'bg-primary text-on-primary hover:bg-primary/90' 
                    : 'bg-error text-on-error hover:bg-error/90'
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
                    {isTestMode ? 'Send Test' : 'Send to All Users'}
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
            Broadcast dispatched successfully
          </div>
        </div>
      )}
    </div>
  );
}
