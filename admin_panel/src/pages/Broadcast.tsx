import { useState, useEffect } from 'react';
import AndroidNotificationPreview from '../components/AndroidNotificationPreview';
import { api } from '../api';

const QUICK_TEMPLATES = [
  {
    title: '📅 Timetable Changes Updated',
    message: 'The timetable for your batch has been updated with newly rescheduled lecture slots. Check the Changes tab in the app.'
  },
  {
    title: '🔔 Class Cancellation Notice',
    message: 'Please note: Upcoming period has been cancelled due to faculty meeting. Self-study hours in the library are assigned.'
  },
  {
    title: '🏖️ Official Holiday Announcement',
    message: 'The University will remain closed tomorrow in accordance with the academic calendar. Have a restful day!'
  },
  {
    title: '⚡ SRAAP Attendance Sync Active',
    message: 'Attendance percentages have been updated from the SRAAP portal. Open the Academic tab to review your latest aggregate.'
  }
];

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
    setHistoryLoading(true);
    try {
      const data = await api.getAnnouncementsHistory();
      setHistory(data || []);
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
      setSendError('Please enter both a notification title and message.');
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
        setToastMessage(targetAudience === 'pwa_only' ? 'PWA Web Push dispatched successfully!' : 'Push notification broadcasted successfully!');
        setShowToast(true);
        setTitle('');
        setMessage('');
        setTimeout(() => setShowToast(false), 3500);
        fetchHistory();
      } else {
        setSendError(res.error || 'Failed to send announcement');
      }
    } catch (err: any) {
      setSendError(err.message || 'Error connecting to server');
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
            ? 'Test push delivered directly to specified device token!'
            : 'Test push broadcasted to topic: sru_pwa_users!'
        });
        setToastMessage('PWA test notification sent');
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
    <div className="flex flex-col gap-8 max-w-7xl mx-auto w-full relative z-0">
      
      {/* Top Hero Bar & Safety Mode Switch */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 p-6 rounded-2xl glass-panel-3d">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="w-2.5 h-2.5 rounded-full bg-indigo-400 shadow-[0_0_8px_#818CF8]"></span>
            <h1 className="text-2xl lg:text-3xl font-extrabold text-white tracking-tight font-['Outfit']">
              Broadcast & Push Dispatcher
            </h1>
          </div>
          <p className="text-sm text-slate-400">
            Instant global push notifications across Android, iOS, and PWA Web clients.
          </p>
        </div>

        {/* 3D Tactile Production / Test Mode Switcher */}
        <div className="flex items-center gap-3 self-start md:self-auto bg-[#131B2E] p-2 rounded-2xl border border-white/10 shadow-[0_4px_12px_rgba(0,0,0,0.5),inset_0_1px_1px_rgba(255,255,255,0.1)]">
          <div className="flex flex-col text-right">
            <span className="text-[10px] font-bold tracking-wider uppercase text-slate-400">Environment</span>
            <span className={`text-[12px] font-extrabold font-mono ${isTestMode ? 'text-amber-400' : 'text-rose-400'}`}>
              {isTestMode ? 'SANDBOX TEST' : 'LIVE PRODUCTION'}
            </span>
          </div>

          <button 
            type="button"
            onClick={() => setIsTestMode(!isTestMode)}
            className={`relative inline-flex h-8 w-16 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none shadow-[inset_0_2px_4px_rgba(0,0,0,0.6)] ${
              isTestMode ? 'bg-amber-600/60' : 'bg-rose-600'
            }`}
          >
            <span
              className={`pointer-events-none inline-block h-7 w-7 transform rounded-full bg-white shadow-[0_2px_6px_rgba(0,0,0,0.4)] transition duration-200 ease-in-out flex items-center justify-center ${
                isTestMode ? 'translate-x-0 text-amber-600' : 'translate-x-8 text-rose-600'
              }`}
            >
              <span className="material-symbols-outlined text-[16px] font-bold">
                {isTestMode ? 'science' : 'bolt'}
              </span>
            </span>
          </button>
        </div>
      </div>

      {/* Target Audience 3D Segmented Control */}
      <div className="flex flex-wrap items-center justify-between gap-4 p-4 rounded-2xl bg-gradient-to-r from-[#111827] to-[#1E293B] border border-white/10 shadow-[0_6px_20px_rgba(0,0,0,0.4)]">
        <div className="flex items-center gap-2">
          <span className="material-symbols-outlined text-indigo-400 text-[20px]">hub</span>
          <span className="text-[13px] font-bold text-slate-200 uppercase tracking-wider">
            Target Audience:
          </span>
        </div>

        <div className="flex items-center gap-2 bg-[#0B0F19] p-1.5 rounded-xl border border-white/10 shadow-[inset_0_2px_4px_rgba(0,0,0,0.5)]">
          <button
            onClick={() => setTargetAudience('all')}
            className={`px-4 py-2 rounded-lg text-[13px] font-bold transition-all flex items-center gap-2 ${
              targetAudience === 'all'
                ? 'bg-gradient-to-r from-indigo-600 to-indigo-500 text-white shadow-[0_2px_10px_rgba(99,102,241,0.5),inset_0_1px_1px_rgba(255,255,255,0.3)]'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <span className="material-symbols-outlined text-[16px]">devices</span>
            All Users (Mobile + PWA)
          </button>
          
          <button
            onClick={() => setTargetAudience('pwa_only')}
            className={`px-4 py-2 rounded-lg text-[13px] font-bold transition-all flex items-center gap-2 ${
              targetAudience === 'pwa_only'
                ? 'bg-gradient-to-r from-sky-500 to-cyan-500 text-white shadow-[0_2px_10px_rgba(14,165,233,0.5),inset_0_1px_1px_rgba(255,255,255,0.3)]'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <span className="material-symbols-outlined text-[16px]">laptop_chromebook</span>
            PWA Members Only
          </button>
        </div>
      </div>

      {/* Main Form & 3D Phone Preview Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        
        {/* Left Form Editor */}
        <div className="lg:col-span-7 flex flex-col gap-6">
          
          <div className="p-6 rounded-2xl card-3d">
            <div className="flex items-center justify-between mb-4 pb-3 border-b border-white/10">
              <h2 className="text-lg font-bold text-white flex items-center gap-2 font-['Outfit']">
                <span className="material-symbols-outlined text-indigo-400">edit_note</span>
                Draft Announcement
              </h2>
              <span className="text-[11px] font-mono text-slate-400">
                {title.length}/60 chars
              </span>
            </div>

            {/* Quick Templates Pill Bar */}
            <div className="mb-5">
              <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-2">
                Quick Template Presets
              </label>
              <div className="flex flex-wrap gap-2">
                {QUICK_TEMPLATES.map((tpl, i) => (
                  <button
                    key={i}
                    type="button"
                    onClick={() => {
                      setTitle(tpl.title);
                      setMessage(tpl.message);
                    }}
                    className="px-3 py-1.5 rounded-lg text-[11.5px] font-semibold bg-white/5 hover:bg-indigo-500/20 text-slate-300 hover:text-indigo-300 border border-white/10 hover:border-indigo-500/40 transition-all text-left truncate max-w-full"
                  >
                    {tpl.title}
                  </button>
                ))}
              </div>
            </div>

            {/* Title Input */}
            <div className="mb-4">
              <label className="block text-[12px] font-bold text-slate-200 mb-1.5 tracking-wide">
                Notification Title *
              </label>
              <input
                type="text"
                maxLength={60}
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="e.g. 📢 Important Timetable Update"
                className="w-full h-11 px-4 rounded-xl input-3d text-[14px]"
              />
            </div>

            {/* Message Input */}
            <div className="mb-5">
              <div className="flex justify-between items-center mb-1.5">
                <label className="text-[12px] font-bold text-slate-200 tracking-wide">
                  Notification Message *
                </label>
                <span className="text-[11px] font-mono text-slate-400">
                  {message.length}/240 chars
                </span>
              </div>
              <textarea
                maxLength={240}
                rows={4}
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                placeholder="Enter message text that will be displayed in notification tray..."
                className="w-full p-3.5 rounded-xl input-3d text-[14px] resize-none leading-relaxed"
              />
            </div>

            {sendError && (
              <div className="mb-4 p-3 rounded-xl bg-rose-500/15 border border-rose-500/30 text-rose-300 text-[13px] flex items-center gap-2">
                <span className="material-symbols-outlined text-[18px]">error</span>
                <span>{sendError}</span>
              </div>
            )}

            {/* 3D Dispatch Button */}
            <button
              onClick={handleSendClick}
              disabled={isSending}
              className={`w-full h-12 rounded-xl text-white font-extrabold text-[14px] tracking-wide flex items-center justify-center gap-2 cursor-pointer ${
                targetAudience === 'pwa_only'
                  ? 'btn-3d-cyan'
                  : (isTestMode ? 'btn-3d-primary' : 'btn-3d-rose')
              }`}
            >
              <span className="material-symbols-outlined text-[20px]">
                {targetAudience === 'pwa_only' ? 'laptop_chromebook' : (isTestMode ? 'send' : 'warning')}
              </span>
              {targetAudience === 'pwa_only'
                ? 'DISPATCH TO PWA MEMBERS ONLY'
                : (isTestMode ? 'DISPATCH TEST BROADCAST' : 'DISPATCH PRODUCTION BROADCAST TO ALL')}
            </button>
          </div>

          {/* Dedicated PWA Test Widget */}
          <div className="p-6 rounded-2xl bg-gradient-to-br from-[#0C1B2E] via-[#0F172A] to-[#111827] border border-sky-500/30 shadow-[0_10px_25px_rgba(14,165,233,0.15)] relative overflow-hidden">
            <div className="absolute top-0 right-0 w-32 h-32 bg-sky-500/10 rounded-full blur-2xl pointer-events-none"></div>
            
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2.5">
                <div className="w-8 h-8 rounded-lg bg-sky-500/20 text-sky-400 border border-sky-500/40 flex items-center justify-center">
                  <span className="material-symbols-outlined text-[18px]">bolt</span>
                </div>
                <div>
                  <h3 className="text-sm font-bold text-white">Direct PWA Web Push Diagnostic</h3>
                  <p className="text-[11px] text-sky-300/80">Test Chrome / Edge / Safari browser delivery</p>
                </div>
              </div>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-sky-500/20 text-sky-300 border border-sky-500/30">
                Topic: sru_pwa_users
              </span>
            </div>

            <div className="flex flex-col gap-3">
              <div>
                <label className="block text-[11px] font-semibold text-slate-300 mb-1">
                  Optional Specific Device FCM Token (leave blank for all PWA subscribers)
                </label>
                <input
                  type="text"
                  value={pwaCustomToken}
                  onChange={(e) => setPwaCustomToken(e.target.value)}
                  placeholder="Paste browser FCM registration token..."
                  className="w-full h-10 px-3 rounded-lg input-3d text-[12px] font-mono text-sky-200"
                />
              </div>

              {pwaTestResult && (
                <div className={`p-3 rounded-xl text-[12.5px] border ${
                  pwaTestResult.success 
                    ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30' 
                    : 'bg-rose-500/15 text-rose-300 border-rose-500/30'
                }`}>
                  {pwaTestResult.success ? pwaTestResult.message : pwaTestResult.error}
                </div>
              )}

              <button
                onClick={handleQuickPwaTest}
                disabled={isPwaTesting}
                className="w-full h-10 rounded-lg btn-3d-cyan font-bold text-[13px] flex items-center justify-center gap-2"
              >
                {isPwaTesting ? (
                  <>
                    <span className="material-symbols-outlined animate-spin text-[16px]">progress_activity</span>
                    Sending Web Push...
                  </>
                ) : (
                  <>
                    <span className="material-symbols-outlined text-[16px]">send_time_extension</span>
                    SEND TEST WEB PUSH TO PWA
                  </>
                )}
              </button>
            </div>
          </div>
        </div>

        {/* Right Phone Mockup Preview */}
        <div className="lg:col-span-5 flex flex-col">
          <div className="p-6 rounded-2xl card-3d sticky top-24">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-base font-bold text-white flex items-center gap-2 font-['Outfit']">
                <span className="material-symbols-outlined text-indigo-400">phone_iphone</span>
                Realistic 3D Device Preview
              </h3>
              <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-indigo-500/20 text-indigo-300 border border-indigo-500/30">
                Interactive Mock
              </span>
            </div>
            <p className="text-[12px] text-slate-400 mb-4">
              Real-time visualization of how the push alert appears on students' phones.
            </p>

            <AndroidNotificationPreview 
              title={title} 
              message={message} 
            />
          </div>
        </div>
      </div>

      {/* Announcement History Section */}
      <div className="p-6 rounded-2xl card-3d">
        <div className="flex items-center justify-between mb-4 pb-3 border-b border-white/10">
          <div>
            <h3 className="text-lg font-bold text-white flex items-center gap-2 font-['Outfit']">
              <span className="material-symbols-outlined text-indigo-400">history</span>
              Broadcast History
            </h3>
            <p className="text-[12px] text-slate-400">
              Live audit trail of previously dispatched notifications
            </p>
          </div>

          <button
            onClick={fetchHistory}
            disabled={historyLoading}
            className="p-2 rounded-xl bg-slate-800/80 hover:bg-slate-700 text-slate-300 hover:text-white border border-white/10 transition-colors flex items-center gap-1.5 text-[12px] font-semibold"
          >
            <span className={`material-symbols-outlined text-[16px] ${historyLoading ? 'animate-spin' : ''}`}>
              refresh
            </span>
            Refresh
          </button>
        </div>

        <div className="overflow-x-auto rounded-xl border border-white/10">
          <table className="w-full text-left border-collapse text-[13px]">
            <thead>
              <tr className="bg-slate-900/80 text-slate-400 uppercase text-[11px] font-bold tracking-wider border-b border-white/10">
                <th className="py-3 px-4">Timestamp</th>
                <th className="py-3 px-4">Title</th>
                <th className="py-3 px-4">Target</th>
                <th className="py-3 px-4">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-white/5 font-medium">
              {historyLoading && (
                <tr>
                  <td colSpan={4} className="py-8 text-center text-slate-400">
                    <span className="material-symbols-outlined animate-spin text-[24px] text-indigo-400 mb-2">
                      progress_activity
                    </span>
                    <p>Loading announcement logs...</p>
                  </td>
                </tr>
              )}

              {!historyLoading && history.length === 0 && (
                <tr>
                  <td colSpan={4} className="py-8 text-center text-slate-400">
                    <span className="material-symbols-outlined text-[32px] text-slate-500 mb-2">
                      notifications_off
                    </span>
                    <p className="text-[13px] text-slate-300 font-semibold">No Broadcasts Logged Yet</p>
                    <p className="text-[11px] text-slate-400">Send your first push notification above!</p>
                  </td>
                </tr>
              )}

              {history.map((item) => (
                <tr key={item.id || item.created_at} className="hover:bg-white/[0.03] transition-colors">
                  <td className="py-3.5 px-4 text-slate-400 whitespace-nowrap font-mono text-[12px]">
                    {new Date(item.created_at).toLocaleString('en-IN', {
                      timeZone: 'Asia/Kolkata',
                      dateStyle: 'short',
                      timeStyle: 'short'
                    })}
                  </td>
                  <td className="py-3.5 px-4 font-bold text-white">
                    {item.title}
                  </td>
                  <td className="py-3.5 px-4 text-slate-300">
                    {item.target || 'All Users'}
                  </td>
                  <td className="py-3.5 px-4">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-[11px] font-extrabold border ${
                      item.status === 'Sent'
                        ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30'
                        : item.status === 'Test'
                        ? 'bg-amber-500/15 text-amber-300 border-amber-500/30'
                        : 'bg-rose-500/15 text-rose-300 border-rose-500/30'
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

      {/* 3D Confirmation Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/75 backdrop-blur-md">
          <div className="w-full max-w-lg bg-[#0F172A] border border-white/20 rounded-2xl shadow-[0_25px_60px_rgba(0,0,0,0.8)] overflow-hidden">
            <div className={`h-2 ${targetAudience === 'pwa_only' ? 'bg-sky-500' : (isTestMode ? 'bg-amber-500' : 'bg-rose-500')}`} />
            
            <div className="p-6">
              <div className="flex items-center gap-3 mb-4">
                <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                  targetAudience === 'pwa_only' ? 'bg-sky-500/20 text-sky-400' : (isTestMode ? 'bg-amber-500/20 text-amber-400' : 'bg-rose-500/20 text-rose-400')
                }`}>
                  <span className="material-symbols-outlined text-[28px]">
                    {targetAudience === 'pwa_only' ? 'laptop_chromebook' : (isTestMode ? 'science' : 'warning')}
                  </span>
                </div>
                <div>
                  <h3 className="text-lg font-bold text-white font-['Outfit']">
                    Confirm Notification Broadcast
                  </h3>
                  <p className="text-[12px] text-slate-400">
                    Verify details before dispatching to the cloud
                  </p>
                </div>
              </div>

              <div className="p-4 rounded-xl bg-slate-900/90 border border-white/10 mb-4 flex flex-col gap-2.5">
                <div>
                  <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Target Scope</span>
                  <p className="text-[13px] font-bold text-indigo-300">
                    {targetAudience === 'pwa_only' ? '💻 PWA Web Push Members (topic: sru_pwa_users)' : '📱 All Registered Devices (Mobile + PWA)'}
                  </p>
                </div>
                <div>
                  <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Title</span>
                  <p className="text-[13px] font-bold text-white">{title}</p>
                </div>
                <div>
                  <span className="text-[10px] font-bold text-slate-400 uppercase tracking-wider">Message</span>
                  <p className="text-[12px] text-slate-300 leading-relaxed">{message}</p>
                </div>
              </div>

              {sendError && (
                <div className="mb-4 p-3 rounded-xl bg-rose-500/20 border border-rose-500/30 text-rose-300 text-[12px]">
                  {sendError}
                </div>
              )}

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  disabled={isSending}
                  className="px-4 py-2 rounded-xl text-[13px] font-semibold text-slate-400 hover:text-white transition-colors"
                >
                  Cancel
                </button>
                <button
                  type="button"
                  onClick={confirmSend}
                  disabled={isSending}
                  className={`px-5 py-2.5 rounded-xl text-white font-extrabold text-[13px] flex items-center gap-2 ${
                    targetAudience === 'pwa_only'
                      ? 'btn-3d-cyan'
                      : (isTestMode ? 'btn-3d-primary' : 'btn-3d-rose')
                  }`}
                >
                  {isSending ? (
                    <>
                      <span className="material-symbols-outlined animate-spin text-[16px]">progress_activity</span>
                      Dispatching...
                    </>
                  ) : (
                    <>
                      <span className="material-symbols-outlined text-[16px]">send</span>
                      Confirm & Dispatch Now
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* 3D Success Toast Notification */}
      {showToast && (
        <div className="fixed bottom-8 right-8 z-50">
          <div className="px-5 py-3 rounded-2xl bg-gradient-to-r from-emerald-600 to-teal-600 text-white shadow-[0_15px_30px_rgba(16,185,129,0.4),0_0_0_1px_rgba(255,255,255,0.3)_inset] flex items-center gap-3 font-bold text-[13px]">
            <span className="material-symbols-outlined text-[20px]">check_circle</span>
            {toastMessage}
          </div>
        </div>
      )}
    </div>
  );
}

