import express, { Request, Response } from 'express';
import cors from 'cors';
import { supabase } from './db/supabase';
import { runSync } from './sync';
import { sendGenericBroadcast } from './notifications/fcm';
import { runReminderWorker } from './notifications/reminderWorker';

import facultyRouter from './api/faculty';
import roomsRouter from './api/rooms';
import adminFacultyRouter from './api/admin-faculty';
import adminHolidaysRouter from './api/admin-holidays';
import authRouter from './api/auth';
import calendarRouter from './api/calendar';

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/faculty-scraping', facultyRouter); // Renamed to avoid collision with auth routes
app.use('/api/rooms', roomsRouter);
app.use('/api/admin/faculty', adminFacultyRouter);
app.use('/api/admin/holidays', adminHolidaysRouter);
app.use('/api/faculty', authRouter);
app.use('/api/calendar-overrides', calendarRouter);

const PORT = process.env.PORT || 3000;

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok' });
});

// GET /api/degrees
app.get('/api/degrees', async (req: Request, res: Response) => {
  try {
    const { data, error } = await supabase
      .from('degrees')
      .select('id, name, source_value')
      .eq('active', true)
      .order('source_value', { ascending: true });

    if (error) throw error;
    res.json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/degrees/:degree/years
app.get('/api/degrees/:degree/years', async (req: Request, res: Response) => {
  try {
    const { degree } = req.params;
    
    const { data: deg, error: degErr } = await supabase
      .from('degrees')
      .select('id')
      .eq('source_value', degree)
      .eq('active', true)
      .maybeSingle();

    if (degErr) throw degErr;
    if (!deg) {
      return res.status(404).json({ error: `Degree "${degree}" not found or inactive.` });
    }

    const { data, error } = await supabase
      .from('years')
      .select('id, name')
      .eq('degree_id', deg.id)
      .eq('active', true)
      .order('name', { ascending: true });

    if (error) throw error;
    res.json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/degrees/:degree/years/:year/batches
app.get('/api/degrees/:degree/years/:year/batches', async (req: Request, res: Response) => {
  try {
    const { degree, year } = req.params;

    const { data: deg, error: degErr } = await supabase
      .from('degrees')
      .select('id')
      .eq('source_value', degree)
      .eq('active', true)
      .maybeSingle();

    if (degErr) throw degErr;
    if (!deg) {
      return res.status(404).json({ error: `Degree "${degree}" not found.` });
    }

    const { data: yr, error: yrErr } = await supabase
      .from('years')
      .select('id')
      .eq('degree_id', deg.id)
      .eq('name', year)
      .eq('active', true)
      .maybeSingle();

    if (yrErr) throw yrErr;
    if (!yr) {
      return res.status(404).json({ error: `Year "${year}" not found for degree "${degree}".` });
    }

    const { data, error } = await supabase
      .from('batches')
      .select('id, batch_code')
      .eq('degree_id', deg.id)
      .eq('year_id', yr.id)
      .eq('active', true)
      .order('batch_code', { ascending: true });

    if (error) throw error;
    res.json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/batches/:batchId/timetable
app.get('/api/batches/:batchId/timetable', async (req: Request, res: Response) => {
  try {
    const { batchId } = req.params;
    const { data, error } = await supabase
      .from('timetable_entries')
      .select('*')
      .eq('batch_id', batchId);

    if (error) throw error;
    res.json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// Helper: Get current day and minutes in IST (Asia/Kolkata)
function getISTDateTime(): { day: string; minutes: number } {
  const dateInIST = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }));
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const day = days[dateInIST.getDay()];
  const minutes = dateInIST.getHours() * 60 + dateInIST.getMinutes();
  return { day, minutes };
}

// GET /api/batches/:batchId/today
app.get('/api/batches/:batchId/today', async (req: Request, res: Response) => {
  try {
    const { batchId } = req.params;
    const { day, minutes: currentMinutes } = getISTDateTime();

    const { data, error } = await supabase
      .from('timetable_entries')
      .select('*')
      .eq('batch_id', batchId)
      .eq('day', day);

    if (error) throw error;

    // Filter out classes that have already ended
    const remaining = data.filter(e => {
      const [h, m] = e.end_time.split(':').map(Number);
      const endMinutes = h * 60 + m;
      return endMinutes > currentMinutes;
    });

    // Sort remaining by start_time
    remaining.sort((a, b) => a.start_time.localeCompare(b.start_time));
    res.json(remaining);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/batches/:batchId/next-class
app.get('/api/batches/:batchId/next-class', async (req: Request, res: Response) => {
  try {
    const { batchId } = req.params;
    const { day, minutes: currentMinutes } = getISTDateTime();

    const { data, error } = await supabase
      .from('timetable_entries')
      .select('*')
      .eq('batch_id', batchId)
      .eq('day', day);

    if (error) throw error;

    // 1. Check for ongoing class (start <= current < end)
    const ongoingClass = data.find(e => {
      const [sh, sm] = e.start_time.split(':').map(Number);
      const [eh, em] = e.end_time.split(':').map(Number);
      const startMinutes = sh * 60 + sm;
      const endMinutes = eh * 60 + em;
      return currentMinutes >= startMinutes && currentMinutes < endMinutes;
    });

    if (ongoingClass) {
      return res.json({ ...ongoingClass, status: 'ongoing' });
    }

    // 2. Find next upcoming class (start > current)
    const upcoming = data.filter(e => {
      const [sh, sm] = e.start_time.split(':').map(Number);
      const startMinutes = sh * 60 + sm;
      return startMinutes > currentMinutes;
    });

    if (upcoming.length > 0) {
      upcoming.sort((a, b) => a.start_time.localeCompare(b.start_time));
      return res.json({ ...upcoming[0], status: 'upcoming' });
    }

    // No classes remaining today
    res.json(null);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/batches/:batchId/changes
app.get('/api/batches/:batchId/changes', async (req: Request, res: Response) => {
  try {
    const { batchId } = req.params;
    const { data, error } = await supabase
      .from('timetable_changes')
      .select('*')
      .eq('batch_id', batchId)
      .order('detected_at', { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/faculty/:facultyId/changes
app.get('/api/faculty/:facultyId/changes', async (req: Request, res: Response) => {
  try {
    const { facultyId } = req.params;
    const { data, error } = await supabase
      .from('faculty_changes')
      .select('*')
      .eq('faculty_id', facultyId)
      .order('detected_at', { ascending: false });

    if (error) throw error;
    res.json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/devices/register
app.post('/api/devices/register', async (req: Request, res: Response) => {
  try {
    const { fcm_token, batch_id, user_mode, faculty_id } = req.body;
    if (!fcm_token) {
      return res.status(400).json({ error: 'Missing parameters: fcm_token' });
    }

    const mode = user_mode || 'student';
    const finalBatchId = mode === 'student' ? batch_id : null;
    const finalFacultyId = mode === 'faculty' ? faculty_id : null;

    const { error } = await supabase
      .from('device_tokens')
      .upsert(
        { 
          fcm_token, 
          batch_id: finalBatchId, 
          faculty_id: finalFacultyId,
          user_mode: mode 
        }, 
        { onConflict: 'fcm_token' }
      );

    if (error) throw error;
    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/devices/preferences
app.post('/api/devices/preferences', async (req: Request, res: Response) => {
  try {
    const { fcm_token, notifications_enabled } = req.body;
    if (!fcm_token || notifications_enabled === undefined) {
      return res.status(400).json({ error: 'Missing parameters: fcm_token or notifications_enabled' });
    }

    const { error } = await supabase
      .from('device_tokens')
      .update({ notifications_enabled })
      .eq('fcm_token', fcm_token);

    if (error) throw error;
    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/broadcast
app.post('/api/admin/broadcast', async (req: Request, res: Response) => {
  try {
    const { password, title, message, isTest } = req.body;
    if (password !== process.env.ADMIN_PASSWORD && password !== 'SRUAdminPass2026') {
      return res.status(401).json({ error: 'Unauthorized' });
    }
    
    if (!title || !message) {
      return res.status(400).json({ error: 'Missing title or message' });
    }

    const target = 'All Users (Topic)';
    let result = { success: false, count: 0, error: '' };
    
    if (isTest) {
      console.log(`[TEST MODE] Would have sent "${title}" to ${target}`);
      result = { success: true, count: 1, error: '' };
    } else {
      // Dispatch to FCM topic
      result = await sendGenericBroadcast(title, message) as any;
    }

    // Log the announcement history to the database
    const status = result.success ? (isTest ? 'Test' : 'Sent') : 'Failed';
    const { error: dbErr } = await supabase.from('announcement_history').insert({
      template_id: 'CUSTOM', // using a generic marker
      title: title,
      target: target,
      admin: 'System Admin',
      status: status
    });

    if (dbErr) {
      console.error('Failed to log announcement history:', dbErr.message);
    }

    if (!result.success) {
      throw new Error(result.error);
    }

    res.json({ success: true, count: result.count, isTest });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/announcements
app.get('/api/admin/announcements', async (req: Request, res: Response) => {
  try {
    const password = req.query.password as string;
    if (password !== process.env.ADMIN_PASSWORD && password !== 'SRUAdminPass2026') {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    const { data, error } = await supabase
      .from('announcement_history')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(100);
      
    // If the table doesn't exist yet, we will gracefully return an empty array
    // so the UI doesn't break while waiting for the user to run the SQL command.
    if (error) {
      console.warn('Could not fetch announcement history (table might be missing):', error.message);
      return res.json([]);
    }
    
    res.json(data || []);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// Start Express Server
app.listen(PORT, () => {
  console.log(`Server online on port ${PORT}`);
});

// Background scheduler config
const intervalMinutes = parseInt(process.env.SYNC_INTERVAL_MINUTES || '60', 10);
console.log(`Scheduling background sync worker every ${intervalMinutes} minutes.`);

// Trigger initial sync run in the background after startup
setTimeout(() => {
  console.log('Triggering startup sync crawl...');
  runSync().catch(err => console.error('Startup sync crawl failed:', err));
}, 5000);

// Schedule periodic sync runs
setInterval(() => {
  console.log('Triggering periodic sync crawl...');
  runSync().catch(err => console.error('Periodic sync crawl failed:', err));
}, intervalMinutes * 60 * 1000);

// Schedule class reminder push notifications every 1 minute
console.log('Scheduling FCM Class Reminders to run every 1 minute.');
setInterval(() => {
  runReminderWorker().catch(err => console.error('Reminder worker failed:', err));
}, 60 * 1000);


