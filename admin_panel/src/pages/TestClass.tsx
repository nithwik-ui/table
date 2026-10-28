import { useState, useEffect } from 'react';
import { api } from '../api';

const SUBJECT_PRESETS = [
  'Machine Learning & AI',
  'Operating Systems Lab',
  'Cloud Computing Architecture',
  'Database Management Systems',
  'Computer Networks'
];

export default function TestClass() {
  const [degrees, setDegrees] = useState<any[]>([]);
  const [years, setYears] = useState<any[]>([]);
  const [batches, setBatches] = useState<any[]>([]);

  const [selectedDegree, setSelectedDegree] = useState('');
  const [selectedYear, setSelectedYear] = useState('');
  const [selectedBatch, setSelectedBatch] = useState('');
  
  const [subject, setSubject] = useState('Machine Learning & AI');
  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');

  const [isSending, setIsSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const [showToast, setShowToast] = useState(false);
  const [toastMessage, setToastMessage] = useState('Test class injected successfully!');

  // Helper: set times relative to now
  const setRelativeTime = (startMinutesFromNow: number, durationMinutes: number = 50) => {
    const now = new Date();
    now.setMinutes(now.getMinutes() + startMinutesFromNow);
    const startStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    
    now.setMinutes(now.getMinutes() + durationMinutes);
    const endStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    
    setStartTime(startStr);
    setEndTime(endStr);
  };

  useEffect(() => {
    setRelativeTime(7, 50);
  }, []);

  useEffect(() => {
    api.getDegrees()
      .then(setDegrees)
      .catch(err => setSendError(err.message));
  }, []);

  useEffect(() => {
    if (!selectedDegree) {
      setYears([]);
      setSelectedYear('');
      return;
    }
    api.getYears(selectedDegree)
      .then(setYears)
      .catch(err => setSendError(err.message));
  }, [selectedDegree]);

  useEffect(() => {
    if (!selectedDegree || !selectedYear) {
      setBatches([]);
      setSelectedBatch('');
      return;
    }
    api.getBatches(selectedDegree, selectedYear)
      .then(setBatches)
      .catch(err => setSendError(err.message));
  }, [selectedDegree, selectedYear]);

  const handleInjectClick = async () => {
    if (!selectedBatch || !subject.trim() || !startTime || !endTime) {
      setSendError('Please select Degree, Year, Batch, and fill time details.');
      return;
    }
    setIsSending(true);
    setSendError(null);
    try {
      const res = await api.injectTestClass(selectedBatch, subject, startTime, endTime);
      if (res.success) {
        setToastMessage(`Test class "${subject}" injected for today!`);
        setShowToast(true);
        setTimeout(() => setShowToast(false), 3500);
      } else {
        setSendError(res.error || 'Failed to inject test class');
      }
    } catch (err: any) {
      setSendError(err.message || 'Error connecting to server');
    } finally {
      setIsSending(false);
    }
  };

  const handleRemoveClick = async () => {
    if (!selectedBatch) {
      setSendError('Please select a batch to clear test classes for.');
      return;
    }
    setIsSending(true);
    setSendError(null);
    try {
      const res = await api.removeTestClasses(selectedBatch);
      if (res.success) {
        setToastMessage('Test classes removed successfully!');
        setShowToast(true);
        setTimeout(() => setShowToast(false), 3500);
      } else {
        setSendError(res.error || 'Failed to remove test classes');
      }
    } catch (err: any) {
      setSendError(err.message || 'Error connecting to server');
    } finally {
      setIsSending(false);
    }
  };

  const selectedBatchObj = batches.find(b => b.id === selectedBatch);

  return (
    <div className="flex flex-col gap-8 max-w-7xl mx-auto w-full relative z-0">
      
      {/* 3D Hero Banner */}
      <div className="p-6 rounded-2xl glass-panel-3d flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="w-2.5 h-2.5 rounded-full bg-emerald-400 shadow-[0_0_8px_#34D399]"></span>
            <h1 className="text-2xl lg:text-3xl font-extrabold text-white tracking-tight font-['Outfit']">
              Class Simulator Workbench
            </h1>
          </div>
          <p className="text-sm text-slate-400">
            Inject mock timetable classes to verify 5-minute pre-class push alerts and live widgets.
          </p>
        </div>

        <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 text-xs font-bold font-mono">
          <span className="material-symbols-outlined text-[16px]">verified</span>
          <span>Target: Mobile App + PWA</span>
        </div>
      </div>

      {/* Main Grid: Form Left, 3D Preview Right */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        
        {/* Left Form: Injection Control */}
        <div className="lg:col-span-7 flex flex-col gap-6">
          <div className="p-6 rounded-2xl card-3d flex flex-col gap-5">
            
            <div className="flex items-center justify-between pb-3 border-b border-white/10">
              <h2 className="text-lg font-bold text-white flex items-center gap-2 font-['Outfit']">
                <span className="material-symbols-outlined text-emerald-400">tune</span>
                Select Student Cohort
              </h2>
              <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-slate-800 text-slate-300 border border-white/10">
                Step 1 of 2
              </span>
            </div>

            {/* Target Selectors Grid */}
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-1.5">
                  1. Degree *
                </label>
                <select
                  value={selectedDegree}
                  onChange={(e) => setSelectedDegree(e.target.value)}
                  className="w-full h-11 px-3 rounded-xl input-3d text-[13px]"
                >
                  <option value="">Select Degree...</option>
                  {degrees.map((d) => (
                    <option key={d.id} value={d.source_value} className="bg-slate-900 text-white">
                      {d.name || d.source_value}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-1.5">
                  2. Year *
                </label>
                <select
                  value={selectedYear}
                  onChange={(e) => setSelectedYear(e.target.value)}
                  disabled={!selectedDegree}
                  className="w-full h-11 px-3 rounded-xl input-3d text-[13px] disabled:opacity-40"
                >
                  <option value="">Select Year...</option>
                  {years.map((y) => (
                    <option key={y.id} value={y.name} className="bg-slate-900 text-white">
                      {y.name || y.id}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-1.5">
                  3. Batch *
                </label>
                <select
                  value={selectedBatch}
                  onChange={(e) => setSelectedBatch(e.target.value)}
                  disabled={!selectedYear}
                  className="w-full h-11 px-3 rounded-xl input-3d text-[13px] disabled:opacity-40"
                >
                  <option value="">Select Batch...</option>
                  {batches.map((b) => (
                    <option key={b.id} value={b.id} className="bg-slate-900 text-white">
                      {b.batch_code}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            {/* Class Details */}
            <div className="pt-3 border-t border-white/10 flex flex-col gap-4">
              <div className="flex items-center justify-between">
                <span className="text-[12px] font-bold text-slate-200 tracking-wide uppercase">
                  Subject Name
                </span>
                <span className="text-[11px] text-slate-400">Presets available below</span>
              </div>

              <input
                type="text"
                value={subject}
                onChange={(e) => setSubject(e.target.value)}
                placeholder="e.g. Machine Learning & AI"
                className="w-full h-11 px-4 rounded-xl input-3d text-[14px]"
              />

              {/* Subject Presets */}
              <div className="flex flex-wrap gap-1.5">
                {SUBJECT_PRESETS.map((p, i) => (
                  <button
                    key={i}
                    type="button"
                    onClick={() => setSubject(p)}
                    className="px-2.5 py-1 rounded-lg text-[11px] font-semibold bg-white/5 hover:bg-emerald-500/20 text-slate-300 hover:text-emerald-300 border border-white/10 transition-colors"
                  >
                    {p}
                  </button>
                ))}
              </div>
            </div>

            {/* Time Configuration & Quick Presets */}
            <div className="pt-3 border-t border-white/10 flex flex-col gap-3">
              <div className="flex items-center justify-between">
                <span className="text-[12px] font-bold text-slate-200 tracking-wide uppercase">
                  Class Schedule Window (24h)
                </span>
                
                {/* Quick Presets */}
                <div className="flex items-center gap-1.5">
                  <button
                    type="button"
                    onClick={() => setRelativeTime(5, 50)}
                    className="px-2 py-0.5 rounded-md text-[10.5px] font-mono bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 hover:bg-indigo-500/30 transition-colors"
                  >
                    +5 min
                  </button>
                  <button
                    type="button"
                    onClick={() => setRelativeTime(10, 50)}
                    className="px-2 py-0.5 rounded-md text-[10.5px] font-mono bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 hover:bg-indigo-500/30 transition-colors"
                  >
                    +10 min
                  </button>
                  <button
                    type="button"
                    onClick={() => setRelativeTime(15, 50)}
                    className="px-2 py-0.5 rounded-md text-[10.5px] font-mono bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 hover:bg-indigo-500/30 transition-colors"
                  >
                    +15 min
                  </button>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                    Start Time
                  </label>
                  <input
                    type="time"
                    value={startTime}
                    onChange={(e) => setStartTime(e.target.value)}
                    className="w-full h-11 px-3 rounded-xl input-3d text-[14px] font-mono"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                    End Time
                  </label>
                  <input
                    type="time"
                    value={endTime}
                    onChange={(e) => setEndTime(e.target.value)}
                    className="w-full h-11 px-3 rounded-xl input-3d text-[14px] font-mono"
                  />
                </div>
              </div>
            </div>

            {sendError && (
              <div className="p-3 rounded-xl bg-rose-500/15 border border-rose-500/30 text-rose-300 text-[13px] flex items-center gap-2">
                <span className="material-symbols-outlined text-[18px]">error</span>
                <span>{sendError}</span>
              </div>
            )}

            {/* 3D Action Buttons */}
            <div className="grid grid-cols-1 sm:grid-cols-12 gap-3 pt-2">
              <button
                onClick={handleInjectClick}
                disabled={isSending || !selectedBatch}
                className="sm:col-span-8 h-12 rounded-xl btn-3d-emerald font-extrabold text-[13.5px] tracking-wide flex items-center justify-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed"
              >
                {isSending ? (
                  <>
                    <span className="material-symbols-outlined animate-spin text-[18px]">progress_activity</span>
                    INJECTING CLASS...
                  </>
                ) : (
                  <>
                    <span className="material-symbols-outlined text-[20px]">add_circle</span>
                    INJECT TEST CLASS NOW
                  </>
                )}
              </button>

              <button
                onClick={handleRemoveClick}
                disabled={isSending || !selectedBatch}
                className="sm:col-span-4 h-12 rounded-xl btn-3d-rose font-bold text-[13px] tracking-wide flex items-center justify-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed"
              >
                <span className="material-symbols-outlined text-[18px]">delete_sweep</span>
                CLEAR ALL
              </button>
            </div>
          </div>
        </div>

        {/* Right Preview & Verification Steps */}
        <div className="lg:col-span-5 flex flex-col gap-6">
          
          {/* 3D Student App Timetable Card Preview */}
          <div className="p-6 rounded-2xl card-3d">
            <div className="flex items-center justify-between mb-3">
              <h3 className="text-sm font-bold text-white flex items-center gap-2 font-['Outfit']">
                <span className="material-symbols-outlined text-emerald-400">preview</span>
                Student App Live Card Simulation
              </h3>
              <span className="text-[10px] font-mono bg-emerald-500/20 text-emerald-300 px-2 py-0.5 rounded-full border border-emerald-500/30">
                Today's Slot
              </span>
            </div>

            <div className="p-4 rounded-xl bg-gradient-to-br from-[#1E293B] via-[#0F172A] to-[#0A0D14] border border-white/15 shadow-[0_10px_25px_rgba(0,0,0,0.6)] relative overflow-hidden">
              <div className="flex items-center justify-between mb-2">
                <span className="text-[11px] font-bold px-2 py-0.5 rounded-md bg-indigo-500/20 text-indigo-300 border border-indigo-500/30">
                  {selectedBatchObj?.batch_code || 'Target Batch'}
                </span>
                <span className="text-[12px] font-mono font-bold text-emerald-400">
                  {startTime || '00:00'} - {endTime || '00:00'}
                </span>
              </div>

              <h4 className="text-base font-extrabold text-white mb-1">
                {subject || 'Subject Name'}
              </h4>
              <p className="text-[12px] text-slate-400 mb-3">
                Room 304, Academic Block A • Test Simulator Lecturer
              </p>

              {/* Progress Simulation Bar */}
              <div className="w-full h-1.5 rounded-full bg-slate-800 overflow-hidden mb-2">
                <div className="h-full bg-gradient-to-r from-emerald-500 to-teal-400 w-1/3"></div>
              </div>

              <div className="flex items-center justify-between text-[11px] text-slate-400">
                <span className="flex items-center gap-1 text-emerald-400 font-semibold">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></span>
                  Starts in 5 minutes
                </span>
                <span>50m duration</span>
              </div>
            </div>
          </div>

          {/* Verification Protocol Checklist */}
          <div className="p-6 rounded-2xl glass-panel-3d flex flex-col gap-3">
            <h3 className="text-sm font-bold text-white flex items-center gap-2 font-['Outfit']">
              <span className="material-symbols-outlined text-indigo-400">checklist</span>
              Testing & Verification Steps
            </h3>
            
            <div className="flex items-start gap-2.5 text-[12.5px] text-slate-300">
              <span className="w-5 h-5 rounded-full bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 flex items-center justify-center shrink-0 text-[11px] font-bold">1</span>
              <span>Pick the Degree, Year, and Batch registered on your test phone.</span>
            </div>

            <div className="flex items-start gap-2.5 text-[12.5px] text-slate-300">
              <span className="w-5 h-5 rounded-full bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 flex items-center justify-center shrink-0 text-[11px] font-bold">2</span>
              <span>Click <b>+5 min</b> so the class starts 5 minutes in the future.</span>
            </div>

            <div className="flex items-start gap-2.5 text-[12.5px] text-slate-300">
              <span className="w-5 h-5 rounded-full bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 flex items-center justify-center shrink-0 text-[11px] font-bold">3</span>
              <span>Click <b>INJECT TEST CLASS NOW</b>.</span>
            </div>

            <div className="flex items-start gap-2.5 text-[12.5px] text-slate-300">
              <span className="w-5 h-5 rounded-full bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 flex items-center justify-center shrink-0 text-[11px] font-bold">4</span>
              <span>Open the SRU mobile app, pull down on the Home tab to refresh, and lock your screen. Notice the class notification triggers!</span>
            </div>
          </div>
        </div>
      </div>

      {/* Toast Notification */}
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

