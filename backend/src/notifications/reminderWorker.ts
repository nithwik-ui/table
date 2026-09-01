import { supabase } from '../db/supabase';
import { sendClassReminderPush } from './fcm';

// Helper: Get current day and minutes in IST (Asia/Kolkata)
function getISTDateTime(): { day: string; minutes: number } {
  const dateInIST = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }));
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  const day = days[dateInIST.getDay()];
  const minutes = dateInIST.getHours() * 60 + dateInIST.getMinutes();
  return { day, minutes };
}

export async function runReminderWorker() {
  try {
    const { day, minutes: currentMinutes } = getISTDateTime();
    
    // We want classes starting in exactly 5 minutes
    const targetStartMinutes = currentMinutes + 5;
    
    // Convert targetStartMinutes to HH:MM format for querying
    const targetH = Math.floor(targetStartMinutes / 60);
    const targetM = targetStartMinutes % 60;
    const targetTimeStr = `${String(targetH).padStart(2, '0')}:${String(targetM).padStart(2, '0')}`;

    // Query timetable for classes on the current day that start at the target time
    const { data: classes, error } = await supabase
      .from('timetable_entries')
      .select('batch_id, subject, room')
      .eq('day', day)
      .eq('start_time', targetTimeStr);

    if (error) {
      console.error('ReminderWorker: Error querying timetable:', error.message);
      return;
    }

    if (!classes || classes.length === 0) {
      return; // No classes starting in exactly 5 minutes
    }

    console.log(`ReminderWorker: Found ${classes.length} class(es) starting at ${targetTimeStr}. Dispatching FCM pushes...`);

    // We dispatch pushes per class to its corresponding batch_id
    for (const c of classes) {
      await sendClassReminderPush(c.batch_id, c.subject, c.room);
    }

  } catch (err: any) {
    console.error('ReminderWorker: Exception:', err.message || err);
  }
}
