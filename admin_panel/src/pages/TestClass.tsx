import { useState, useEffect } from 'react';
import { api } from '../api';

export default function TestClass() {
  const [degrees, setDegrees] = useState<any[]>([]);
  const [years, setYears] = useState<any[]>([]);
  const [batches, setBatches] = useState<any[]>([]);
  
  const [selectedDegree, setSelectedDegree] = useState('');
  const [selectedYear, setSelectedYear] = useState('');
  const [selectedBatch, setSelectedBatch] = useState('');
  
  const [subject, setSubject] = useState('Notification Test');
  const [startTime, setStartTime] = useState('');
  const [endTime, setEndTime] = useState('');
  
  const [isSending, setIsSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);
  const [showToast, setShowToast] = useState(false);

  useEffect(() => {
    api.getDegrees().then(setDegrees).catch(console.error);
    
    // Set default times to current time + 7 minutes
    const now = new Date();
    now.setMinutes(now.getMinutes() + 7);
    const startHour = String(now.getHours()).padStart(2, '0');
    const startMin = String(now.getMinutes()).padStart(2, '0');
    setStartTime(`${startHour}:${startMin}`);
    
    now.setMinutes(now.getMinutes() + 60);
    const endHour = String(now.getHours()).padStart(2, '0');
    const endMin = String(now.getMinutes()).padStart(2, '0');
    setEndTime(`${endHour}:${endMin}`);
  }, []);

  useEffect(() => {
    if (selectedDegree) {
      api.getYears(selectedDegree).then(setYears).catch(console.error);
      setSelectedYear('');
      setSelectedBatch('');
      setBatches([]);
    }
  }, [selectedDegree]);

  useEffect(() => {
    if (selectedDegree && selectedYear) {
      api.getBatches(selectedDegree, selectedYear).then(setBatches).catch(console.error);
      setSelectedBatch('');
    }
  }, [selectedYear, selectedDegree]);

  const handleInjectClick = async () => {
    if (!selectedBatch || !subject || !startTime || !endTime) {
      setSendError('Please fill in all fields (Batch, Subject, Start Time, End Time).');
      return;
    }
    
    setIsSending(true);
    setSendError(null);
    try {
      const res = await api.injectTestClass(selectedBatch, subject, startTime, endTime);
      if (res.success) {
        setShowToast(true);
        setTimeout(() => setShowToast(false), 3000);
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
      setSendError('Please select a Batch first.');
      return;
    }
    setIsSending(true);
    setSendError(null);
    try {
      const res = await api.removeTestClasses(selectedBatch);
      if (res.success) {
        setShowToast(true);
        setTimeout(() => setShowToast(false), 3000);
      } else {
        setSendError(res.error || 'Failed to remove test classes');
      }
    } catch (err: any) {
      setSendError(err.message || 'Error connecting to server');
    } finally {
      setIsSending(false);
    }
  };

  return (
    <div className="flex flex-col gap-stack-lg max-w-7xl mx-auto w-full relative z-0">
      <div className="flex flex-col gap-2">
        <h1 className="font-headline-lg text-headline-lg text-primary">Test Class Injector</h1>
        <p className="font-body-md text-body-md text-on-surface-variant">
          Inject a temporary class into the database for the current day to test mobile notifications.
        </p>
      </div>

      <div className="flex flex-col lg:flex-row gap-6">
        <div className="lg:w-[60%] w-full flex flex-col gap-stack-md relative z-10">
          <div className="glass-panel rounded-[14px] p-6 flex flex-col gap-4">
             
            <div>
              <label className="block font-label-md text-on-surface mb-2 font-[600]">Degree</label>
              <select 
                value={selectedDegree} 
                onChange={e => setSelectedDegree(e.target.value)}
                className="w-full bg-surface-container-high border border-outline-variant text-on-surface text-body-md rounded-lg p-3 outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all"
              >
                <option value="">Select Degree...</option>
                {degrees.map(d => (
                  <option key={d.id} value={d.source_value}>{d.name || d.source_value}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block font-label-md text-on-surface mb-2 font-[600]">Year</label>
              <select 
                value={selectedYear} 
                onChange={e => setSelectedYear(e.target.value)}
                disabled={!selectedDegree}
                className="w-full bg-surface-container-high border border-outline-variant text-on-surface text-body-md rounded-lg p-3 outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all disabled:opacity-50"
              >
                <option value="">Select Year...</option>
                {years.map(y => (
                  <option key={y.id} value={y.name}>{y.name || y.id}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block font-label-md text-on-surface mb-2 font-[600]">Batch</label>
              <select 
                value={selectedBatch} 
                onChange={e => setSelectedBatch(e.target.value)}
                disabled={!selectedYear}
                className="w-full bg-surface-container-high border border-outline-variant text-on-surface text-body-md rounded-lg p-3 outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all disabled:opacity-50"
              >
                <option value="">Select Batch...</option>
                {batches.map(b => (
                  <option key={b.id} value={b.id}>{b.batch_code}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block font-label-md text-on-surface mb-2 font-[600]">Subject Name</label>
              <input 
                type="text" 
                value={subject}
                onChange={e => setSubject(e.target.value)}
                className="w-full bg-surface-container-high border border-outline-variant text-on-surface text-body-md rounded-lg p-3 outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all placeholder:text-on-surface-variant/50"
              />
            </div>
            
            <div className="flex gap-4">
              <div className="flex-1">
                <label className="block font-label-md text-on-surface mb-2 font-[600]">Start Time (24h)</label>
                <input 
                  type="time" 
                  value={startTime}
                  onChange={e => setStartTime(e.target.value)}
                  className="w-full bg-surface-container-high border border-outline-variant text-on-surface text-body-md rounded-lg p-3 outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all"
                />
              </div>
              <div className="flex-1">
                <label className="block font-label-md text-on-surface mb-2 font-[600]">End Time (24h)</label>
                <input 
                  type="time" 
                  value={endTime}
                  onChange={e => setEndTime(e.target.value)}
                  className="w-full bg-surface-container-high border border-outline-variant text-on-surface text-body-md rounded-lg p-3 outline-none focus:border-primary focus:ring-1 focus:ring-primary transition-all"
                />
              </div>
            </div>

            {sendError && (
              <div className="bg-error-container text-on-error-container p-3 rounded-lg text-body-sm font-medium mt-2">
                {sendError}
              </div>
            )}

            <div className="flex gap-4 mt-4">
              <button 
                onClick={handleInjectClick}
                disabled={isSending || !selectedBatch}
                className="flex-1 bg-primary text-on-primary font-label-lg py-3 rounded-[10px] hover:opacity-90 active:scale-[0.98] transition-all flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSending ? (
                  <span className="material-symbols-outlined animate-spin font-label-lg">progress_activity</span>
                ) : (
                  <span className="material-symbols-outlined font-label-lg">science</span>
                )}
                {isSending ? 'INJECTING...' : 'INJECT TEST CLASS'}
              </button>

              <button 
                onClick={handleRemoveClick}
                disabled={isSending || !selectedBatch}
                className="px-6 bg-error/10 text-error font-label-lg py-3 rounded-[10px] hover:bg-error/20 active:scale-[0.98] transition-all flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                title="Remove injected test classes for this batch"
              >
                <span className="material-symbols-outlined font-label-lg">delete</span>
                REMOVE
              </button>
            </div>
          </div>
        </div>
        
        <div className="lg:w-[40%] w-full">
           <div className="glass-panel rounded-[14px] p-6 h-full flex flex-col gap-4">
             <h2 className="font-headline-sm text-primary mb-2 flex items-center gap-2">
               <span className="material-symbols-outlined">info</span> Instructions
             </h2>
             <p className="text-body-sm text-on-surface-variant">1. Select your target batch.</p>
             <p className="text-body-sm text-on-surface-variant">2. By default, the start time is set to 7 minutes from now.</p>
             <p className="text-body-sm text-on-surface-variant">3. Click Inject. The class will be instantly added to today's timetable.</p>
             <p className="text-body-sm text-on-surface-variant">4. Open your mobile app and pull down on the timetable to sync.</p>
             <p className="text-body-sm text-on-surface-variant">5. Close the app. Exactly 5 minutes before the start time, the notification will trigger!</p>
           </div>
        </div>
      </div>

      {showToast && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 bg-surface border border-outline-variant shadow-lg text-on-surface px-6 py-3 rounded-full flex items-center gap-3 animate-slide-up z-50">
          <span className="material-symbols-outlined text-primary fill-icon">check_circle</span>
          <span className="font-label-md">Test class injected successfully!</span>
        </div>
      )}
    </div>
  );
}
