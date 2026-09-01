const API_BASE = `http://${window.location.hostname}:8000/api`;
const ADMIN_PASSWORD = 'SRUAdminPass2026';

export const api = {
  sendBroadcast: async (title: string, message: string, isTest: boolean = false): Promise<{ success: boolean; count?: number; isTest?: boolean; error?: string }> => {
    const res = await fetch(`${API_BASE}/admin/broadcast`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        password: ADMIN_PASSWORD,
        title,
        message,
        isTest,
      }),
    });
    return res.json();
  },

  getAnnouncementsHistory: async (): Promise<any[]> => {
    const res = await fetch(`${API_BASE}/admin/announcements?password=${ADMIN_PASSWORD}`);
    if (!res.ok) throw new Error('Failed to fetch announcement history');
    return res.json();
  },

  getDegrees: async (): Promise<any[]> => {
    const res = await fetch(`${API_BASE}/degrees`);
    if (!res.ok) throw new Error('Failed to fetch degrees');
    return res.json();
  },

  getYears: async (degreeValue: string): Promise<any[]> => {
    const res = await fetch(`${API_BASE}/degrees/${encodeURIComponent(degreeValue)}/years`);
    if (!res.ok) throw new Error('Failed to fetch years');
    return res.json();
  },

  getBatches: async (degreeValue: string, yearName: string): Promise<any[]> => {
    const res = await fetch(`${API_BASE}/degrees/${encodeURIComponent(degreeValue)}/years/${encodeURIComponent(yearName)}/batches`);
    if (!res.ok) throw new Error('Failed to fetch batches');
    return res.json();
  },

  injectTestClass: async (batchId: string, subject: string, startTime: string, endTime: string): Promise<{ success: boolean; error?: string }> => {
    const res = await fetch(`${API_BASE}/admin/test-class`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        password: ADMIN_PASSWORD,
        batchId,
        subject,
        startTime,
        endTime,
      }),
    });
    return res.json();
  },

  removeTestClasses: async (batchId: string): Promise<{ success: boolean; error?: string }> => {
    const res = await fetch(`${API_BASE}/admin/test-class`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        password: ADMIN_PASSWORD,
        batchId,
      }),
    });
    return res.json();
  }
};
