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
      setHolidays(data);
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
      target_mode: holiday.target_mode,
      is_active: holiday.is_active
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

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Calendar & Holidays</h1>

      {error && (
        <div className="bg-red-50 text-red-600 p-4 rounded-md mb-6">
          {error}
        </div>
      )}

      <div className="bg-white p-6 rounded-lg shadow-sm border mb-8">
        <h2 className="text-lg font-semibold mb-4">{editingId ? 'Edit Override' : 'Add New Override'}</h2>
        <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1">Title (e.g. Sri Krishna Janmashtami)</label>
            <input
              required
              type="text"
              value={formData.title}
              onChange={(e) => setFormData({...formData, title: e.target.value})}
              className="w-full px-4 py-2 border rounded-md"
            />
          </div>
          
          <div className="md:col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1">Message</label>
            <textarea
              required
              value={formData.message}
              onChange={(e) => setFormData({...formData, message: e.target.value})}
              className="w-full px-4 py-2 border rounded-md"
              rows={2}
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Date</label>
            <input
              required
              type="date"
              value={formData.override_date}
              onChange={(e) => setFormData({...formData, override_date: e.target.value})}
              className="w-full px-4 py-2 border rounded-md"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Applies To</label>
            <select
              value={formData.target_mode}
              onChange={(e) => setFormData({...formData, target_mode: e.target.value})}
              className="w-full px-4 py-2 border rounded-md"
            >
              <option value="both">Student & Faculty</option>
              <option value="student">Student Only</option>
              <option value="faculty">Faculty Only</option>
            </select>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Start Time (Optional, e.g. 10:00)</label>
            <input
              type="time"
              value={formData.start_time}
              onChange={(e) => setFormData({...formData, start_time: e.target.value})}
              className="w-full px-4 py-2 border rounded-md"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">End Time (Optional, e.g. 12:00)</label>
            <input
              type="time"
              value={formData.end_time}
              onChange={(e) => setFormData({...formData, end_time: e.target.value})}
              className="w-full px-4 py-2 border rounded-md"
            />
          </div>

          <div className="md:col-span-2 flex gap-4 mt-2">
            <button
              type="submit"
              disabled={loading}
              className="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
            >
              {loading ? 'Saving...' : (editingId ? 'Update Override' : 'Add Override')}
            </button>
            
            {editingId && (
              <button
                type="button"
                onClick={() => {
                  setEditingId(null);
                  setFormData({ title: '', message: '', override_date: '', start_time: '', end_time: '', target_mode: 'both', is_active: true });
                }}
                className="px-6 py-2 bg-gray-200 text-gray-800 rounded-md hover:bg-gray-300"
              >
                Cancel
              </button>
            )}
          </div>
        </form>
      </div>

      <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Date</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Title</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Target</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Time</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {holidays.map((h) => (
              <tr key={h.id}>
                <td className="px-6 py-4 whitespace-nowrap font-medium">{h.override_date}</td>
                <td className="px-6 py-4">
                  <div className="font-medium text-gray-900">{h.title}</div>
                  <div className="text-sm text-gray-500 truncate max-w-xs">{h.message}</div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap capitalize">{h.target_mode}</td>
                <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {h.start_time ? `${h.start_time} - ${h.end_time}` : 'Full Day'}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${h.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                    {h.is_active ? 'Active' : 'Disabled'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button onClick={() => handleToggleStatus(h)} className="text-gray-600 hover:text-gray-900 mr-4">
                    {h.is_active ? 'Disable' : 'Enable'}
                  </button>
                  <button onClick={() => handleEdit(h)} className="text-blue-600 hover:text-blue-900 mr-4">
                    Edit
                  </button>
                  <button onClick={() => handleDelete(h.id)} className="text-red-600 hover:text-red-900">
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {holidays.length === 0 && (
              <tr>
                <td colSpan={6} className="px-6 py-8 text-center text-gray-500">
                  No holidays found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
