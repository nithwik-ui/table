"use client";

import React, { useState, useEffect } from 'react';

const DEFAULT_API_URL = 'https://sru-timetable-api.onrender.com';
const LOCAL_API_URL = 'http://localhost:8000';

interface Batch {
  id: string;
  batch_code: string;
  active: boolean;
  degree_id: string;
  year_id: string;
}

interface Degree {
  id: string;
  name: string;
  source_value: string;
}

interface ChangeLog {
  id: string;
  batch_id: string;
  change_type: string;
  field_name: string;
  old_value: string;
  new_value: string;
  detected_at: string;
}

export default function Home() {
  const [password, setPassword] = useState('');
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [loginError, setLoginError] = useState('');
  
  // API URL State
  const [apiUrl, setApiUrl] = useState(DEFAULT_API_URL);
  
  // Dashboard Metrics & Data State
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [syncStatus, setSyncStatus] = useState<'idle' | 'running' | 'success' | 'failed'>('idle');
  const [syncMessage, setSyncMessage] = useState('');
  
  const [counts, setCounts] = useState({ degrees: 0, years: 0, batches: 0 });
  const [degrees, setDegrees] = useState<Degree[]>([]);
  const [batches, setBatches] = useState<Batch[]>([]);
  const [recentChanges, setRecentChanges] = useState<ChangeLog[]>([]);

  // Check stored credentials on load
  useEffect(() => {
    const storedAuth = localStorage.getItem('sru_admin_auth');
    const storedUrl = localStorage.getItem('sru_admin_api_url');
    
    if (storedAuth === 'true') {
      setIsLoggedIn(true);
    }
    if (storedUrl) {
      setApiUrl(storedUrl);
    } else {
      // Auto-detect local development environments
      if (typeof window !== 'undefined' && window.location.hostname === 'localhost') {
        setApiUrl(LOCAL_API_URL);
      }
    }
  }, []);

  // Fetch metrics data
  const fetchDashboardData = async () => {
    setLoading(true);
    setError('');
    try {
      const response = await fetch(`${apiUrl}/api/admin/metrics?password=${password || 'SRUAdminPass2026'}`);
      if (!response.ok) {
        throw new Error(response.status === 401 ? 'Invalid administrator password.' : 'Failed to reach API server.');
      }
      const data = await response.json();
      setCounts(data.counts);
      setDegrees(data.degrees);
      setBatches(data.batches);
      setRecentChanges(data.recentChanges);
    } catch (err: any) {
      setError(err.message || 'An unexpected connection error occurred.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isLoggedIn) {
      fetchDashboardData();
    }
  }, [isLoggedIn, apiUrl]);

  // Login handler
  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    if (password === 'SRUAdminPass2026') {
      setIsLoggedIn(true);
      setLoginError('');
      localStorage.setItem('sru_admin_auth', 'true');
    } else {
      setLoginError('Invalid administrator credentials.');
    }
  };

  // Logout handler
  const handleLogout = () => {
    setIsLoggedIn(false);
    setPassword('');
    localStorage.removeItem('sru_admin_auth');
  };

  // Trigger sync crawl
  const handleTriggerSync = async () => {
    setSyncStatus('running');
    setSyncMessage('Crawl worker initialized in the background...');
    try {
      const response = await fetch(`${apiUrl}/api/sync/trigger`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ password: password || 'SRUAdminPass2026' })
      });
      const data = await response.json();
      if (response.ok && data.success) {
        setSyncStatus('success');
        setSyncMessage('Sync crawl process started! Updates will reflect shortly.');
        // Refresh tables after 5 seconds delay
        setTimeout(fetchDashboardData, 5000);
      } else {
        setSyncStatus('failed');
        setSyncMessage(data.error || 'Server rejected synchronization trigger.');
      }
    } catch (err: any) {
      setSyncStatus('failed');
      setSyncMessage(err.message || 'Network request failed.');
    }
  };

  // Save customized API URL
  const handleSaveApiUrl = (url: string) => {
    setApiUrl(url);
    localStorage.setItem('sru_admin_api_url', url);
  };

  // Render Login Gate
  if (!isLoggedIn) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#090A0F] text-zinc-100 p-4 font-sans">
        <div className="w-full max-w-md bg-[#11131E] border border-zinc-800/80 rounded-2xl p-8 shadow-2xl">
          <div className="flex flex-col items-center mb-8">
            <div className="w-16 h-16 bg-blue-600/10 border border-blue-500/25 rounded-2xl flex items-center justify-center mb-4">
              <svg className="w-8 h-8 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
              </svg>
            </div>
            <h1 className="text-2xl font-bold tracking-tight">SRU Admin Gate</h1>
            <p className="text-sm text-zinc-400 mt-1">Provide credentials to enter control panel</p>
          </div>

          <form onSubmit={handleLogin} className="space-y-6">
            <div>
              <label className="block text-xs font-semibold uppercase tracking-wider text-zinc-400 mb-2">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••••••••"
                className="w-full bg-[#161825] border border-zinc-800 focus:border-blue-500 rounded-xl px-4 py-3 text-zinc-100 focus:outline-none transition-colors"
                required
              />
            </div>

            {loginError && (
              <div className="bg-red-950/30 border border-red-500/20 text-red-400 text-sm px-4 py-3 rounded-xl">
                {loginError}
              </div>
            )}

            <button
              type="submit"
              className="w-full bg-blue-600 hover:bg-blue-500 text-white font-semibold py-3 px-4 rounded-xl transition-all shadow-lg shadow-blue-600/10 focus:outline-none"
            >
              Sign In
            </button>
          </form>
        </div>
      </div>
    );
  }

  // Render Dashboard
  return (
    <div className="min-h-screen bg-[#090A0F] text-zinc-100 font-sans">
      {/* Navbar */}
      <header className="border-b border-zinc-800/80 bg-[#11131E] sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-6 h-18 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 bg-blue-600/10 border border-blue-500/25 rounded-lg flex items-center justify-center">
              <svg className="w-5 h-5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
              </svg>
            </div>
            <span className="font-bold text-lg tracking-tight">SRU Dashboard</span>
          </div>

          <div className="flex items-center gap-4">
            {/* API Config dropdown/input */}
            <div className="flex items-center gap-2 bg-[#161825] border border-zinc-800 rounded-lg px-3 py-1.5">
              <span className="text-xs text-zinc-400 font-medium">API:</span>
              <select
                value={apiUrl}
                onChange={(e) => handleSaveApiUrl(e.target.value)}
                className="bg-transparent text-xs text-zinc-200 border-none outline-none focus:ring-0 cursor-pointer"
              >
                <option value={DEFAULT_API_URL} className="bg-[#11131E]">Production (Render)</option>
                <option value={LOCAL_API_URL} className="bg-[#11131E]">Local (localhost:3000)</option>
              </select>
            </div>

            <button
              onClick={handleLogout}
              className="text-xs font-semibold text-zinc-400 hover:text-zinc-100 bg-[#161825] border border-zinc-800/80 hover:border-zinc-700 rounded-lg px-4 py-2 transition-all cursor-pointer"
            >
              Sign Out
            </button>
          </div>
        </div>
      </header>

      {/* Main Workspace */}
      <main className="max-w-7xl mx-auto px-6 py-10 space-y-10">
        
        {/* Connection status or general errors */}
        {error && (
          <div className="bg-red-950/20 border border-red-500/20 text-red-400 px-6 py-4 rounded-xl flex items-center justify-between">
            <span>{error}</span>
            <button onClick={fetchDashboardData} className="text-xs underline font-semibold hover:text-red-300">
              Retry Connection
            </button>
          </div>
        )}

        {/* Stats Grid */}
        <section className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-[#11131E] border border-zinc-800/80 rounded-2xl p-6 relative overflow-hidden">
            <h3 className="text-sm font-semibold uppercase tracking-wider text-zinc-400">Total Degrees</h3>
            <p className="text-4xl font-bold tracking-tight mt-2">{counts.degrees}</p>
            <div className="absolute right-4 bottom-4 text-zinc-800 opacity-20">
              <svg className="w-16 h-16" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 3L1 9l11 6 9-4.91V17h2V9L12 3z" />
              </svg>
            </div>
          </div>
          <div className="bg-[#11131E] border border-zinc-800/80 rounded-2xl p-6 relative overflow-hidden">
            <h3 className="text-sm font-semibold uppercase tracking-wider text-zinc-400">Total Academic Years</h3>
            <p className="text-4xl font-bold tracking-tight mt-2">{counts.years}</p>
            <div className="absolute right-4 bottom-4 text-zinc-800 opacity-20">
              <svg className="w-16 h-16" fill="currentColor" viewBox="0 0 24 24">
                <path d="M19 3h-1V1h-2v2H8V1H6v2H5c-1.11 0-1.99.9-1.99 2L3 19c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H5V8h14v11z" />
              </svg>
            </div>
          </div>
          <div className="bg-[#11131E] border border-zinc-800/80 rounded-2xl p-6 relative overflow-hidden">
            <h3 className="text-sm font-semibold uppercase tracking-wider text-zinc-400">Active Batches</h3>
            <p className="text-4xl font-bold tracking-tight mt-2">{counts.batches}</p>
            <div className="absolute right-4 bottom-4 text-zinc-800 opacity-20">
              <svg className="w-16 h-16" fill="currentColor" viewBox="0 0 24 24">
                <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5zm8 0c-.29 0-.62.02-.97.05 1.16.84 1.97 1.97 1.97 3.45V19h6v-2.5c0-2.33-4.67-3.5-7-3.5z" />
              </svg>
            </div>
          </div>
        </section>

        {/* Control and Crawler Section */}
        <section className="bg-[#11131E] border border-zinc-800/80 rounded-2xl p-6 md:p-8">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
            <div className="space-y-1">
              <h2 className="text-xl font-bold tracking-tight">Crawler Sync Manager</h2>
              <p className="text-sm text-zinc-400">
                Trigger manual background crawls of the SRU portal to update batch records instantly.
              </p>
            </div>
            <div>
              <button
                onClick={handleTriggerSync}
                disabled={syncStatus === 'running'}
                className="bg-blue-600 hover:bg-blue-500 disabled:bg-zinc-800 text-white font-semibold py-3 px-6 rounded-xl transition-all shadow-lg shadow-blue-600/10 focus:outline-none flex items-center gap-3 cursor-pointer"
              >
                {syncStatus === 'running' && (
                  <svg className="animate-spin h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                    <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                    <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                  </svg>
                )}
                Trigger Portal Sync Crawl
              </button>
            </div>
          </div>

          {syncMessage && (
            <div className={`mt-6 p-4 rounded-xl text-sm border ${
              syncStatus === 'success' ? 'bg-emerald-950/20 border-emerald-500/20 text-emerald-400' :
              syncStatus === 'failed' ? 'bg-red-950/20 border-red-500/20 text-red-400' :
              'bg-blue-950/20 border-blue-500/20 text-blue-400'
            }`}>
              {syncMessage}
            </div>
          )}
        </section>

        {/* Data Tables Workspace */}
        <section className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Active Batches Table */}
          <div className="bg-[#11131E] border border-zinc-800/80 rounded-2xl p-6 lg:col-span-2 space-y-6">
            <h2 className="text-lg font-bold tracking-tight">Active Batches Metadata</h2>
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead>
                  <tr className="border-b border-zinc-800 text-zinc-400">
                    <th className="py-3 px-4 font-semibold">Batch Code</th>
                    <th className="py-3 px-4 font-semibold">Status</th>
                    <th className="py-3 px-4 font-semibold">Degree ID</th>
                    <th className="py-3 px-4 font-semibold">Year ID</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-800/50">
                  {batches.length === 0 ? (
                    <tr>
                      <td colSpan={4} className="py-6 text-center text-zinc-500">
                        {loading ? 'Fetching records...' : 'No active batches synced.'}
                      </td>
                    </tr>
                  ) : (
                    batches.map((batch) => (
                      <tr key={batch.id} className="hover:bg-[#161825]/50 transition-colors">
                        <td className="py-3.5 px-4 font-semibold text-zinc-200">{batch.batch_code}</td>
                        <td className="py-3.5 px-4">
                          <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold ${
                            batch.active ? 'bg-emerald-500/10 text-emerald-400' : 'bg-zinc-800 text-zinc-500'
                          }`}>
                            <span className={`w-1.5 h-1.5 rounded-full ${batch.active ? 'bg-emerald-500' : 'bg-zinc-500'}`} />
                            {batch.active ? 'Active' : 'Inactive'}
                          </span>
                        </td>
                        <td className="py-3.5 px-4 text-xs font-mono text-zinc-500">{batch.degree_id}</td>
                        <td className="py-3.5 px-4 text-xs font-mono text-zinc-500">{batch.year_id}</td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Sync History / Recent Changes */}
          <div className="bg-[#11131E] border border-zinc-800/80 rounded-2xl p-6 space-y-6">
            <h2 className="text-lg font-bold tracking-tight">Recent Scraper Diffs</h2>
            <div className="space-y-4 max-h-[450px] overflow-y-auto pr-1">
              {recentChanges.length === 0 ? (
                <p className="text-sm text-zinc-500 text-center py-8">
                  No recent timetable changes recorded.
                </p>
              ) : (
                recentChanges.map((change) => {
                  let field = change.field_name;
                  let subject = 'Class';
                  const parts = field.split(':');
                  if (parts.length > 1) {
                    field = parts[0];
                    subject = parts.slice(1).join(':');
                  }
                  
                  return (
                    <div key={change.id} className="border border-zinc-800/60 rounded-xl p-4 space-y-2 bg-[#161825]/30">
                      <div className="flex items-center justify-between">
                        <span className={`text-[10px] uppercase font-bold tracking-wider px-2 py-0.5 rounded-md ${
                          change.change_type === 'ROOM_CHANGED' ? 'bg-amber-500/10 text-amber-400' :
                          change.change_type === 'FACULTY_CHANGED' ? 'bg-indigo-500/10 text-indigo-400' :
                          change.change_type === 'CLASS_REMOVED' ? 'bg-red-500/10 text-red-400' :
                          'bg-emerald-500/10 text-emerald-400'
                        }`}>
                          {change.change_type.replace('_', ' ')}
                        </span>
                        <span className="text-[10px] text-zinc-500">
                          {new Date(change.detected_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                        </span>
                      </div>
                      <p className="text-sm font-semibold text-zinc-200">{subject}</p>
                      <p className="text-xs text-zinc-400">
                        {change.change_type === 'ROOM_CHANGED' && `Moved to ${change.new_value}`}
                        {change.change_type === 'FACULTY_CHANGED' && `Taken by ${change.new_value}`}
                        {change.change_type === 'CLASS_REMOVED' && 'Cancelled'}
                        {change.change_type === 'CLASS_ADDED' && `Added slot ${change.new_value}`}
                        {change.change_type === 'TIME_CHANGED' && `Rescheduled to ${change.new_value}`}
                      </p>
                    </div>
                  );
                })
              )}
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}
