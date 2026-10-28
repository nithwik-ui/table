import React, { useState, useEffect } from 'react';
import { api } from '../api';

export const Holidays: React.FC = () => {
  const [holidays, setHolidays] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [formData, setFormData] = useState({
    title: '',
    message: '',
    override_date: '',
    start_time: '',
    end_time: '',
    target_mode: 'both',
    is_active: true
  });

  const [editingId, setEditingId] = useState<string | null>(null);

  const fetchHolidays = async () => {
    try {
      const data = await api.getHolidays();
      setHolidays(data || []);
    } catch (err: any) {
      setError(err.message);
    }
  };

  useEffect(() => {
    fetchHolidays();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      if (editingId) {
        await api.updateHoliday(editingId, formData);
      } else {
        await api.createHoliday(formData);
      }
      
      setFormData({
        title: '',
        message: '',
        override_date: '',
        start_time: '',
        end_time: '',
        target_mode: 'both',
        is_active: true
      });
      setEditingId(null);
      fetchHolidays();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleEdit = (holiday: any) => {
    setEditingId(holiday.id);
    setFormData({
      title: holiday.title,
      message: holiday.message,
      override_date: holiday.override_date,
      start_time: holiday.start_time || '',
      end_time: holiday.end_time || '',
      target_mode: holiday.target_mode || 'both',
      is_active: holiday.is_active ?? true
    });
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this holiday record?')) return;
    try {
      await api.deleteHoliday(id);
      fetchHolidays();
    } catch (err: any) {
      alert(err.message);
    }
  };

  const handleToggleStatus = async (holiday: any) => {
    try {
      await api.updateHoliday(holiday.id, { ...holiday, is_active: !holiday.is_active });
      fetchHolidays();
    } catch (err: any) {
      alert(err.message);
    }
  };

  const totalActive = holidays.filter(h => h.is_active).length;

  return (
    <div className="flex flex-col gap-8 max-w-7xl mx-auto w-full relative z-0">
      
      {/* 3D Hero Banner */}
      <div className="p-6 rounded-2xl glass-panel-3d flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 mb-1">
            <span className="w-2.5 h-2.5 rounded-full bg-amber-400 shadow-[0_0_8px_#FBBF24]"></span>
            <h1 className="text-2xl lg:text-3xl font-extrabold text-white tracking-tight font-['Outfit']">
              Academic Calendar & Holidays
            </h1>
          </div>
          <p className="text-sm text-slate-400">
            Publish university-wide official holidays and timetable override exceptions.
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="px-4 py-2 rounded-xl bg-slate-900/90 border border-white/10 flex items-center gap-2.5">
            <span className="text-[11px] font-bold text-slate-400 uppercase">Active Overrides:</span>
            <span className="text-base font-extrabold text-amber-400 font-mono">{totalActive}</span>
          </div>
        </div>
      </div>

      {error && (
        <div className="p-4 rounded-xl bg-rose-500/15 border border-rose-500/30 text-rose-300 text-sm flex items-center gap-2">
          <span className="material-symbols-outlined text-[20px]">error</span>
          <span>{error}</span>
        </div>
      )}

      {/* Grid: Editor Left, Holidays List Right */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
        
        {/* Left Form: Add/Edit Holiday */}
        <div className="lg:col-span-5 flex flex-col gap-6">
          <div className="p-6 rounded-2xl card-3d">
            <div className="flex items-center justify-between pb-3 mb-4 border-b border-white/10">
              <h2 className="text-base font-bold text-white flex items-center gap-2 font-['Outfit']">
                <span className="material-symbols-outlined text-amber-400">
                  {editingId ? 'edit_calendar' : 'add_circle'}
                </span>
                {editingId ? 'Edit Holiday Override' : 'Add Holiday Override'}
              </h2>
              {editingId && (
                <button
                  type="button"
                  onClick={() => {
                    setEditingId(null);
                    setFormData({
                      title: '',
                      message: '',
                      override_date: '',
                      start_time: '',
                      end_time: '',
                      target_mode: 'both',
                      is_active: true
                    });
                  }}
                  className="text-[11px] font-bold text-slate-400 hover:text-white"
                >
                  Cancel
                </button>
              )}
            </div>

            <form onSubmit={handleSubmit} className="flex flex-col gap-4">
              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-1.5">
                  Holiday Title *
                </label>
                <input
                  required
                  type="text"
                  placeholder="e.g. Diwali Vacation / Maha Shivaratri"
                  value={formData.title}
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })}
                  className="w-full h-11 px-3.5 rounded-xl input-3d text-[13.5px]"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-1.5">
                  Announcement Details *
                </label>
                <textarea
                  required
                  rows={3}
                  placeholder="Details regarding holiday observance, campus closure, or makeup days..."
                  value={formData.message}
                  onChange={(e) => setFormData({ ...formData, message: e.target.value })}
                  className="w-full p-3 rounded-xl input-3d text-[13px] resize-none leading-relaxed"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-1.5">
                  Date of Observance *
                </label>
                <input
                  required
                  type="date"
                  value={formData.override_date}
                  onChange={(e) => setFormData({ ...formData, override_date: e.target.value })}
                  className="w-full h-11 px-3.5 rounded-xl input-3d text-[13.5px] font-mono text-slate-200"
                />
              </div>

              <div>
                <label className="block text-[11px] font-bold uppercase tracking-wider text-slate-400 mb-1.5">
                  Target Scope
                </label>
                <select
                  value={formData.target_mode}
                  onChange={(e) => setFormData({ ...formData, target_mode: e.target.value })}
                  className="w-full h-11 px-3.5 rounded-xl input-3d text-[13px]"
                >
                  <option value="both" className="bg-slate-900 text-white">Entire University (All Batches)</option>
                  <option value="student" className="bg-slate-900 text-white">Students Only</option>
                  <option value="faculty" className="bg-slate-900 text-white">Faculty Only</option>
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                    Start Time (Optional)
                  </label>
                  <input
                    type="time"
                    value={formData.start_time}
                    onChange={(e) => setFormData({ ...formData, start_time: e.target.value })}
                    className="w-full h-10 px-3 rounded-xl input-3d text-[13px] font-mono"
                  />
                </div>
                <div>
                  <label className="block text-[11px] font-semibold text-slate-400 mb-1">
                    End Time (Optional)
                  </label>
                  <input
                    type="time"
                    value={formData.end_time}
                    onChange={(e) => setFormData({ ...formData, end_time: e.target.value })}
                    className="w-full h-10 px-3 rounded-xl input-3d text-[13px] font-mono"
                  />
                </div>
              </div>

              <div className="pt-2">
                <button
                  type="submit"
                  disabled={loading}
                  className="w-full h-11 rounded-xl btn-3d-primary font-bold text-[13.5px] tracking-wide flex items-center justify-center gap-2"
                >
                  {loading ? (
                    <>
                      <span className="material-symbols-outlined animate-spin text-[16px]">progress_activity</span>
                      Saving...
                    </>
                  ) : (
                    <>
                      <span className="material-symbols-outlined text-[18px]">
                        {editingId ? 'save' : 'add'}
                      </span>
                      {editingId ? 'UPDATE HOLIDAY OVERRIDE' : 'ADD HOLIDAY OVERRIDE'}
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>

        {/* Right List: Holiday Calendar Records */}
        <div className="lg:col-span-7 flex flex-col gap-4">
          <div className="p-6 rounded-2xl card-3d">
            <div className="flex items-center justify-between pb-3 mb-4 border-b border-white/10">
              <div>
                <h3 className="text-base font-bold text-white flex items-center gap-2 font-['Outfit']">
                  <span className="material-symbols-outlined text-indigo-400">calendar_month</span>
                  Scheduled University Holidays
                </h3>
                <p className="text-[12px] text-slate-400">
                  {holidays.length} holiday entries registered in the database
                </p>
              </div>
            </div>

            <div className="flex flex-col gap-3">
              {holidays.length === 0 && (
                <div className="py-12 text-center text-slate-400">
                  <span className="material-symbols-outlined text-[36px] text-slate-500 mb-2">
                    event_busy
                  </span>
                  <p className="font-bold text-slate-300">No Holidays Scheduled</p>
                  <p className="text-[12px] text-slate-400">Use the form on the left to add upcoming holidays.</p>
                </div>
              )}

              {holidays.map((h) => {
                const dateObj = new Date(h.override_date);
                const month = dateObj.toLocaleString('en-US', { month: 'short' });
                const day = dateObj.getDate() || h.override_date;

                return (
                  <div
                    key={h.id}
                    className="p-4 rounded-xl bg-slate-900/80 border border-white/10 hover:border-white/20 transition-all flex flex-col sm:flex-row sm:items-center justify-between gap-4 shadow-sm"
                  >
                    <div className="flex items-center gap-3.5">
                      {/* 3D Calendar Date Block */}
                      <div className="w-12 h-13 rounded-xl bg-gradient-to-b from-indigo-500/20 to-purple-500/10 border border-indigo-500/30 flex flex-col items-center justify-center shrink-0 shadow-inner">
                        <span className="text-[10px] font-extrabold uppercase text-indigo-300 tracking-wider">
                          {month}
                        </span>
                        <span className="text-base font-extrabold text-white font-mono leading-none">
                          {day}
                        </span>
                      </div>

                      <div className="flex flex-col">
                        <div className="flex items-center gap-2">
                          <h4 className="text-[14px] font-bold text-white">
                            {h.title}
                          </h4>
                          <span className={`text-[10px] font-extrabold px-2 py-0.5 rounded-full border ${
                            h.is_active 
                              ? 'bg-emerald-500/15 text-emerald-300 border-emerald-500/30' 
                              : 'bg-slate-700/50 text-slate-400 border-white/10'
                          }`}>
                            {h.is_active ? 'Active' : 'Disabled'}
                          </span>
                        </div>

                        <p className="text-[12px] text-slate-300 line-clamp-1 mt-0.5">
                          {h.message}
                        </p>

                        <div className="flex items-center gap-2 mt-1 text-[11px] text-slate-400">
                          <span className="flex items-center gap-1 font-mono">
                            <span className="material-symbols-outlined text-[13px]">schedule</span>
                            {h.start_time ? `${h.start_time} - ${h.end_time}` : 'Full Day'}
                          </span>
                          <span>•</span>
                          <span className="capitalize text-slate-300">{h.target_mode || 'Entire Campus'}</span>
                        </div>
                      </div>
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-2 self-end sm:self-center shrink-0">
                      <button
                        onClick={() => handleToggleStatus(h)}
                        className={`px-3 py-1.5 rounded-lg text-[11.5px] font-bold border transition-colors ${
                          h.is_active
                            ? 'bg-amber-500/10 text-amber-300 border-amber-500/30 hover:bg-amber-500/20'
                            : 'bg-emerald-500/10 text-emerald-300 border-emerald-500/30 hover:bg-emerald-500/20'
                        }`}
                      >
                        {h.is_active ? 'Disable' : 'Enable'}
                      </button>

                      <button
                        onClick={() => handleEdit(h)}
                        className="p-1.5 rounded-lg bg-white/5 hover:bg-white/10 text-slate-300 hover:text-white border border-white/10 transition-colors"
                        title="Edit Holiday"
                      >
                        <span className="material-symbols-outlined text-[16px]">edit</span>
                      </button>

                      <button
                        onClick={() => handleDelete(h.id)}
                        className="p-1.5 rounded-lg bg-rose-500/10 hover:bg-rose-500/20 text-rose-300 border border-rose-500/30 transition-colors"
                        title="Delete Holiday"
                      >
                        <span className="material-symbols-outlined text-[16px]">delete</span>
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

