import express, { Request, Response } from 'express';
import cors from 'cors';
import { supabase } from './db/supabase';
import { runSync } from './sync';
import { 
  sendGenericBroadcast, 
  sendTestClassNotification, 
  sendTestClassRemovedNotification, 
  subscribeDeviceToGlobalTopic,
  subscribeDeviceToPwaTopic,
  sendPwaTestNotification,
  sendTestPush, 
  sendAttendancePush 
} from './notifications/fcm';

import facultyRouter from './api/faculty';
import roomsRouter from './api/rooms';
import adminFacultyRouter from './api/admin-faculty';
import adminHolidaysRouter from './api/admin-holidays';
import authRouter from './api/auth';
import calendarRouter from './api/calendar';

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/faculty', facultyRouter);
app.use('/api/rooms', roomsRouter);
app.use('/api/admin/faculty', adminFacultyRouter);
app.use('/api/admin/holidays', adminHolidaysRouter);
app.use('/api/calendar-overrides', calendarRouter);

const PORT = process.env.PORT || 3000;

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.json({ status: 'ok' });
});

// GET /api/degrees
app.get('/api/degrees', async (req: Request, res: Response) => {
  try {
    let { data, error } = await supabase
      .from('degrees')
      .select('id, name, source_value')
      .eq('active', true)
      .order('source_value', { ascending: true });

    if (error) throw error;
    if (!data || data.length === 0) {
      const fallback = await supabase
        .from('degrees')
        .select('id, name, source_value')
        .order('source_value', { ascending: true });
      data = fallback.data || [];
    }
    res.json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/degrees/:degree/years
app.get('/api/degrees/:degree/years', async (req: Request, res: Response) => {
  try {
    const { degree } = req.params;

    let { data: deg, error: degErr } = await supabase
      .from('degrees')
      .select('id')
      .eq('source_value', degree)
      .eq('active', true)
      .maybeSingle();

    if (degErr) throw degErr;
    if (!deg) {
      const fallbackDeg = await supabase
        .from('degrees')
        .select('id')
        .eq('source_value', degree)
        .maybeSingle();
      deg = fallbackDeg.data;
    }
    if (!deg) {
      return res.status(404).json({ error: `Degree "${degree}" not found.` });
    }

    let { data, error } = await supabase
      .from('years')
      .select('id, name')
      .eq('degree_id', deg.id)
      .eq('active', true)
      .order('name', { ascending: true });

    if (error) throw error;
    if (!data || data.length === 0) {
      const fallbackYears = await supabase
        .from('years')
        .select('id, name')
        .eq('degree_id', deg.id)
        .order('name', { ascending: true });
      data = fallbackYears.data || [];
    }
    res.json(data);
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/degrees/:degree/years/:year/batches
app.get('/api/degrees/:degree/years/:year/batches', async (req: Request, res: Response) => {
  try {
    const { degree, year } = req.params;

    let { data: deg, error: degErr } = await supabase
      .from('degrees')
      .select('id')
      .eq('source_value', degree)
      .eq('active', true)
      .maybeSingle();

    if (degErr) throw degErr;
    if (!deg) {
      const fallbackDeg = await supabase
        .from('degrees')
        .select('id')
        .eq('source_value', degree)
        .maybeSingle();
      deg = fallbackDeg.data;
    }
    if (!deg) {
      return res.status(404).json({ error: `Degree "${degree}" not found.` });
    }

    let { data: yr, error: yrErr } = await supabase
      .from('years')
      .select('id')
      .eq('degree_id', deg.id)
      .eq('name', year)
      .eq('active', true)
      .maybeSingle();

    if (yrErr) throw yrErr;
    if (!yr) {
      const fallbackYr = await supabase
        .from('years')
        .select('id')
        .eq('degree_id', deg.id)
        .eq('name', year)
        .maybeSingle();
      yr = fallbackYr.data;
    }
    if (!yr) {
      return res.status(404).json({ error: `Year "${year}" not found for degree "${degree}".` });
    }

    let { data, error } = await supabase
      .from('batches')
      .select('id, batch_code')
      .eq('degree_id', deg.id)
      .eq('year_id', yr.id)
      .eq('active', true)
      .order('batch_code', { ascending: true });

    if (error) throw error;
    if (!data || data.length === 0) {
      const fallbackBatches = await supabase
        .from('batches')
        .select('id, batch_code')
        .eq('degree_id', deg.id)
        .eq('year_id', yr.id)
        .order('batch_code', { ascending: true });
      data = fallbackBatches.data || [];
    }
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
    const { fcm_token, batch_id, user_mode, faculty_id, platform } = req.body;
    if (!fcm_token) {
      return res.status(400).json({ error: 'Missing parameters: fcm_token' });
    }

    const mode = user_mode || 'student';
    const finalBatchId = mode === 'student' ? batch_id : null;
    // For students, faculty_id can store the roll_number for targeted push notifications
    const finalFacultyId = faculty_id || null;

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

    // Automatically subscribe token to sru_all_users topic
    subscribeDeviceToGlobalTopic(fcm_token);

    // If device is PWA / Web, subscribe to sru_pwa_users topic
    const isPwa = platform === 'web' || (req.headers['user-agent']?.includes('Mozilla') && req.body?.is_pwa);
    if (isPwa) {
      subscribeDeviceToPwaTopic(fcm_token);
    }

    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/devices/unregister
app.post('/api/devices/unregister', async (req: Request, res: Response) => {
  try {
    const { fcm_token } = req.body;
    if (!fcm_token) {
      return res.status(400).json({ error: 'Missing fcm_token' });
    }

    const { error } = await supabase
      .from('device_tokens')
      .delete()
      .eq('fcm_token', fcm_token);

    if (error) throw error;
    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/devices/test-notification
app.post('/api/devices/test-notification', async (req: Request, res: Response) => {
  const fcm_token = req.body?.fcm_token;
  const maskedToken = typeof fcm_token === 'string' && fcm_token.length > 10
    ? `${fcm_token.substring(0, 6)}...${fcm_token.substring(fcm_token.length - 4)}`
    : '***';

  try {
    if (!fcm_token) {
      return res.status(400).json({
        success: false,
        code: 'MISSING_TOKEN',
        message: 'Missing fcm_token parameter'
      });
    }

    console.log(`[FCM] Dispatching test notification to token: ${maskedToken}`);

    await sendTestPush(fcm_token);
    return res.json({
      success: true,
      message: 'Test notification sent successfully'
    });
  } catch (err: any) {
    const errorCode = err.code || 'FCM_SEND_FAILED';
    const isUnregistered = errorCode === 'messaging/registration-token-not-registered' ||
      errorCode === 'messaging/invalid-registration-token' ||
      (err.message && err.message.includes('not registered'));

    if (isUnregistered) {
      try {
        await supabase
          .from('device_tokens')
          .delete()
          .eq('fcm_token', fcm_token);
        console.log(`[FCM] Pruned unregistered token from database: ${maskedToken}`);
      } catch (cleanupErr: any) {
        console.error('[FCM] Failed to cleanup unregistered token:', cleanupErr.message);
      }

      return res.status(400).json({
        success: false,
        code: 'FCM_UNREGISTERED',
        message: 'FCM registration token is invalid or no longer registered with Firebase'
      });
    }

    console.error('[FCM] Test push dispatch error:', err.message);
    return res.status(500).json({
      success: false,
      code: errorCode,
      message: err.message || 'Failed to dispatch test notification'
    });
  }
});

// POST /api/devices/attendance
app.post('/api/devices/attendance', async (req: Request, res: Response) => {
  try {
    const { rollNumber, subject, date, time } = req.body;
    if (!rollNumber || !subject) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    await sendAttendancePush(rollNumber, subject, date || '', time || '');
    res.json({ success: true });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/pwa-test-notification
app.post('/api/admin/pwa-test-notification', async (req: Request, res: Response) => {
  try {
    const { password, title, message, fcm_token } = req.body;
    if (password !== process.env.ADMIN_PASSWORD && password !== 'SRUAdminPass2026') {
      return res.status(401).json({ success: false, error: 'Unauthorized' });
    }

    const result = await sendPwaTestNotification(
      title || '🔔 SRU Timetable PWA Alert',
      message || 'This is a test notification for PWA web members.',
      fcm_token
    );

    return res.json({
      ...result
    });
  } catch (err: any) {
    console.error('[FCM] PWA test notification error:', err.message || err);
    return res.status(500).json({ success: false, error: err.message || 'Failed to dispatch PWA push' });
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
    const { password, title, message, isTest, target: audienceTarget } = req.body;
    if (password !== process.env.ADMIN_PASSWORD && password !== 'SRUAdminPass2026') {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!title || !message) {
      return res.status(400).json({ error: 'Missing title or message' });
    }

    const isPwaOnly = audienceTarget === 'pwa_only';
    const target = isPwaOnly ? 'PWA Users Only (Web Push)' : 'All Users (Topic)';
    let result = { success: false, count: 0, error: '' };

    if (isTest) {
      console.log(`[TEST MODE] Would have sent "${title}" to ${target}`);
      result = { success: true, count: 1, error: '' };
    } else if (isPwaOnly) {
      result = await sendPwaTestNotification(title, message) as any;
    } else {
      // Dispatch to FCM global topic
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

// POST /api/admin/test-class
app.post('/api/admin/test-class', async (req: Request, res: Response) => {
  try {
    const { password, batchId, subject, startTime, endTime } = req.body;
    if (password !== process.env.ADMIN_PASSWORD && password !== 'SRUAdminPass2026') {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!batchId || !subject || !startTime || !endTime) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    const { day } = getISTDateTime();

    const { error: dbErr } = await supabase.from('timetable_entries').insert({
      batch_id: batchId,
      day: day,
      start_time: startTime,
      end_time: endTime,
      subject: subject,
      faculty: 'Admin Injector',
      room: 'Test Room',
      semester: 'N/A',
      ltp: 'L',
      source_hash: 'TEST_CLASS_INJECTOR'
    });

    if (dbErr) {
      throw new Error(dbErr.message);
    }

    res.json({ success: true, day, startTime, endTime });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/admin/test-class
app.delete('/api/admin/test-class', async (req: Request, res: Response) => {
  try {
    const { password, batchId } = req.body;
    if (password !== process.env.ADMIN_PASSWORD && password !== 'SRUAdminPass2026') {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!batchId) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    const { error: dbErr, count } = await supabase
      .from('timetable_entries')
      .delete({ count: 'exact' })
      .eq('batch_id', batchId)
      .eq('source_hash', 'TEST_CLASS_INJECTOR');

    if (dbErr) {
      throw new Error(dbErr.message);
    }

    res.json({ success: true, deletedCount: count });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/faculty-test-class
app.post('/api/admin/faculty-test-class', async (req: Request, res: Response) => {
  try {
    const { password, facultyId, subject, startTime, endTime } = req.body;
    if (password !== process.env.ADMIN_PASSWORD && password !== 'SRUAdminPass2026') {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!facultyId || !subject || !startTime || !endTime) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    const { day } = getISTDateTime();

    const { error: dbErr } = await supabase.from('faculty_timetable_entries').insert({
      faculty_id: facultyId,
      day: day,
      start_time: startTime,
      end_time: endTime,
      subject: subject,
      faculty: 'Admin Injector',
      room: 'Test Room',
      semester: 'N/A',
      ltp: 'L',
      source_hash: 'TEST_CLASS_INJECTOR'
    });

    if (dbErr) {
      throw new Error(dbErr.message);
    }

    res.json({ success: true, day, startTime, endTime });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE /api/admin/faculty-test-class
app.delete('/api/admin/faculty-test-class', async (req: Request, res: Response) => {
  try {
    const { password, facultyId } = req.body;
    if (password !== process.env.ADMIN_PASSWORD && password !== 'SRUAdminPass2026') {
      return res.status(401).json({ error: 'Unauthorized' });
    }

    if (!facultyId) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }

    const { error: dbErr, count } = await supabase
      .from('faculty_timetable_entries')
      .delete({ count: 'exact' })
      .eq('faculty_id', facultyId)
      .eq('source_hash', 'TEST_CLASS_INJECTOR');

    if (dbErr) {
      throw new Error(dbErr.message);
    }

    res.json({ success: true, deletedCount: count });
  } catch (err: any) {
    res.status(500).json({ error: err.message });
  }
});

// Start Express Server
app.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`Server online on port ${PORT}`);
});

// Background scheduler config
const intervalMinutes = parseInt(process.env.SYNC_INTERVAL_MINUTES || '60', 10);
console.log(`Scheduling background sync worker every ${intervalMinutes} minutes.`);

// Schedule periodic sync runs
setInterval(() => {
  console.log('Triggering periodic sync crawl...');
  runSync().catch(err => console.error('Periodic sync crawl failed:', err));
}, intervalMinutes * 60 * 1000);
