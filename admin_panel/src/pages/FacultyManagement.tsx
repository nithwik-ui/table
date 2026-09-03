import React, { useState, useEffect } from 'react';
import { api } from '../api';

export const FacultyManagement: React.FC = () => {
  const [faculty, setFaculty] = useState<any[]>([]);
  const [newFacultyName, setNewFacultyName] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [lastGeneratedCode, setLastGeneratedCode] = useState<{name: string, code: string} | null>(null);

  const [liveFaculty, setLiveFaculty] = useState<{id: string, name: string}[]>([]);

  const fetchFaculty = async () => {
    try {
      const data = await api.getFaculty();
      setFaculty(data);
    } catch (err: any) {
      setError(err.message);
    }
  };

  const fetchLiveFaculty = async () => {
    try {
      const data = await api.getLiveFacultyList();
      setLiveFaculty(data);
    } catch (err: any) {
      console.error('Failed to fetch live faculty list', err);
    }
  };

  useEffect(() => {
    fetchFaculty();
    fetchLiveFaculty();
  }, []);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newFacultyName.trim()) return;

    setLoading(true);
    setError(null);
    setLastGeneratedCode(null);

    try {
      const res = await api.createFaculty(newFacultyName.trim());
      if (res.error) throw new Error(res.error);
      
      setLastGeneratedCode({
        name: res.faculty.faculty_name,
        code: res.activation_password
      });
      setNewFacultyName('');
      fetchFaculty();
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleToggleStatus = async (id: string, currentStatus: boolean) => {
    try {
      await api.updateFacultyStatus(id, !currentStatus);
      fetchFaculty();
    } catch (err: any) {
      alert(err.message);
    }
  };

  const handleResetActivation = async (id: string) => {
    if (!window.confirm("Are you sure you want to generate a new activation code? This will wipe the user's permanent password.")) return;
    
    try {
      const res = await api.resetFacultyActivation(id);
      if (res.error) throw new Error(res.error);
      setLastGeneratedCode({
        name: res.faculty.faculty_name,
        code: res.activation_password
      });
      fetchFaculty();
    } catch (err: any) {
      alert(err.message);
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm("Are you sure you want to completely delete this faculty account?")) return;
    
    try {
      await api.deleteFaculty(id);
      fetchFaculty();
    } catch (err: any) {
      alert(err.message);
    }
  };

  return (
    <div>
      <h1 className="text-2xl font-bold mb-6">Faculty Management</h1>

      {error && (
        <div className="bg-red-50 text-red-600 p-4 rounded-md mb-6">
          {error}
        </div>
      )}

      {lastGeneratedCode && (
        <div className="bg-green-50 border border-green-200 text-green-800 p-4 rounded-md mb-6 shadow-sm">
          <h3 className="font-bold text-lg mb-2">Account Created/Reset Successfully</h3>
          <p className="mb-2">Please give this activation code to <strong>{lastGeneratedCode.name}</strong> securely.</p>
          <div className="bg-white px-4 py-2 rounded text-xl font-mono inline-block border">
            {lastGeneratedCode.code}
          </div>
          <p className="text-sm mt-2 text-green-600">This code will only be shown once.</p>
        </div>
      )}

      <div className="bg-white p-6 rounded-lg shadow-sm border mb-8">
        <h2 className="text-lg font-semibold mb-4">Add New Faculty</h2>
        <form onSubmit={handleCreate} className="flex gap-4">
          <input
            list="liveFacultyList"
            type="text"
            value={newFacultyName}
            onChange={(e) => setNewFacultyName(e.target.value)}
            placeholder="Select or type e.g. Mr. Sallauddin Mohammad"
            className="flex-1 px-4 py-2 border rounded-md"
            disabled={loading}
          />
          <datalist id="liveFacultyList">
            {liveFaculty.map((f) => (
              <option key={f.id} value={f.name} />
            ))}
          </datalist>
          <button
            type="submit"
            disabled={loading || !newFacultyName.trim()}
            className="px-6 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 disabled:opacity-50"
          >
            {loading ? 'Adding...' : 'Add Faculty'}
          </button>
        </form>
      </div>

      <div className="bg-white rounded-lg shadow-sm border overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Activation</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {faculty.map((f) => (
              <tr key={f.id}>
                <td className="px-6 py-4 whitespace-nowrap font-medium">{f.faculty_name}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${f.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                    {f.is_active ? 'Active' : 'Disabled'}
                  </span>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  {f.activation_used ? (
                    <span className="text-green-600 font-medium">Activated</span>
                  ) : (
                    <span className="text-orange-500">Pending</span>
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button
                    onClick={() => handleResetActivation(f.id)}
                    className="text-blue-600 hover:text-blue-900 mr-4"
                  >
                    Reset Password
                  </button>
                  <button
                    onClick={() => handleToggleStatus(f.id, f.is_active)}
                    className={`${f.is_active ? 'text-orange-600 hover:text-orange-900' : 'text-green-600 hover:text-green-900'} mr-4`}
                  >
                    {f.is_active ? 'Disable' : 'Enable'}
                  </button>
                  <button
                    onClick={() => handleDelete(f.id)}
                    className="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            ))}
            {faculty.length === 0 && (
              <tr>
                <td colSpan={4} className="px-6 py-8 text-center text-gray-500">
                  No faculty accounts found.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
};
