import * as admin from 'firebase-admin';
import { supabase } from '../db/supabase';
import { TimetableChangeInsert } from '../sync/diff';

let fcmInitialized = false;

  let serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson) {
    try {
      if (serviceAccountJson.startsWith("'") && serviceAccountJson.endsWith("'")) {
        serviceAccountJson = serviceAccountJson.slice(1, -1);
      }
      admin.initializeApp({
        credential: admin.credential.cert(JSON.parse(serviceAccountJson))
      });
      fcmInitialized = true;
      console.log('Firebase Admin SDK initialized successfully via FIREBASE_SERVICE_ACCOUNT_JSON.');
    } catch (subErr: any) {
      console.error('Failed to initialize Firebase Admin SDK with service account JSON:', subErr.message);
    }
  } else {
    try {
      admin.initializeApp({
        credential: admin.credential.applicationDefault()
      });
      fcmInitialized = true;
      console.log('Firebase Admin SDK initialized successfully (Application Default Credentials).');
    } catch (err: any) {
      console.warn('Firebase Admin SDK could not initialize:', err.message);
    }
  }

async function isHolidayToday(targetMode: string): Promise<boolean> {
  const dateInIST = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }));
  const year = dateInIST.getFullYear();
  const month = String(dateInIST.getMonth() + 1).padStart(2, '0');
  const day = String(dateInIST.getDate()).padStart(2, '0');
  const dateString = `${year}-${month}-${day}`;

  const { data, error } = await supabase
    .from('calendar_overrides')
    .select('id')
    .eq('override_date', dateString)
    .eq('is_active', true)
    .in('target_mode', [targetMode, 'both'])
    .maybeSingle();

  if (error || !data) {
    return false;
  }
  return true;
}

function getISTDay(): string {
  const dateInIST = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }));
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  return days[dateInIST.getDay()];
}

function extractDayFromFieldName(fieldName: string | null): string | null {
  if (!fieldName) return null;
  const parts = fieldName.split('|');
  if (parts.length >= 2) {
    return parts[1];
  }
  return null;
}

export async function sendBatchNotifications(batchId: string, changes: TimetableChangeInsert[]) {
  if (!fcmInitialized) {
    console.warn('Skipping push notification dispatch: Firebase Admin SDK is not initialized.');
    return;
  }

  if (changes.length === 0) return;

  try {
    // 1. Get batch code for copy templates
    const { data: batch, error: batchErr } = await supabase
      .from('batches')
      .select('batch_code')
      .eq('id', batchId)
      .maybeSingle();

    if (batchErr || !batch) {
      console.error('Failed to get batch details for notifications:', batchErr?.message);
      return;
    }

    const batchCode = batch.batch_code;

    // 2. Fetch device tokens registered for this batch
    const { data: tokens, error: tokensErr } = await supabase
      .from('device_tokens')
      .select('fcm_token')
      .eq('batch_id', batchId)
      .eq('notifications_enabled', true);

    if (tokensErr) {
      console.error('Failed to retrieve device tokens:', tokensErr.message);
      return;
    }

    if (!tokens || tokens.length === 0) {
      console.log(`No active device tokens found for batch ${batchCode}. Skipping FCM push.`);
      return;
    }

    const fcmTokens = tokens.map(t => t.fcm_token);

    const isHoliday = await isHolidayToday('student');
    const todayDay = getISTDay();

    // 3. Dispatch multicast message for each change
    for (const change of changes) {
      const changeDay = extractDayFromFieldName(change.field_name);
      if (isHoliday && changeDay === todayDay) {
        console.log(`Skipping FCM for ${change.change_type} on ${changeDay} because today is a holiday.`);
        continue;
      }

      const type = change.change_type;
      const oldVal = change.old_value || '';
      const newVal = change.new_value || '';

      // Parse subject name from field_name (stored as fieldName:SubjectName)
      let subject = 'Class';
      const fieldParts = (change.field_name || '').split(':');
      if (fieldParts.length > 1) {
        subject = fieldParts.slice(1).join(':');
      }

      let title = '';
      let body = '';

      if (type === 'ROOM_CHANGED') {
        title = 'Room Changed';
        body = `Room Changed: ${subject} (${batchCode}) moved to ${newVal}`;
      } else if (type === 'FACULTY_CHANGED') {
        title = 'Faculty Changed';
        body = `Faculty Changed: ${subject} taken by ${newVal} today`;
      } else if (type === 'CLASS_REMOVED') {
        title = 'Class Cancelled';
        const oldSubject = oldVal.split(' (')[0];
        body = `Class Cancelled: ${oldSubject} (${batchCode}) has been cancelled for today`;
      } else if (type === 'CLASS_ADDED') {
        title = 'Class Added';
        const newSubject = newVal.split(' (')[0];
        body = `Class Added: ${newSubject} (${batchCode}) has been added`;
      } else if (type === 'TIME_CHANGED') {
        title = 'Class Rescheduled';
        body = `Class Rescheduled: ${subject} rescheduled to ${newVal}`;
      } else {
        title = 'Timetable Updated';
        body = `Schedule modified for ${subject} (${batchCode})`;
      }

      // Build multicast message payload
      const payload = {
        tokens: fcmTokens,
        notification: {
          title,
          body,
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          batch_id: batchId,
          change_type: type,
        },
        android: {
          notification: {
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            sound: 'default',
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            }
          }
        }
      };

      const response = await admin.messaging().sendEachForMulticast(payload);
      console.log(`Dispatched FCM notifications for "${title}": ${response.successCount} succeeded, ${response.failureCount} failed.`);
      
      // Cleanup failed or unregistered registration tokens
      if (response.failureCount > 0) {
        const tokensToDelete: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success && resp.error) {
            const code = resp.error.code;
            if (
              code === 'messaging/invalid-registration-token' ||
              code === 'messaging/registration-token-not-registered'
            ) {
              tokensToDelete.push(fcmTokens[idx]);
            }
          }
        });

        if (tokensToDelete.length > 0) {
          await supabase
            .from('device_tokens')
            .delete()
            .in('fcm_token', tokensToDelete);
          console.log(`Pruned ${tokensToDelete.length} stale/invalid FCM tokens from database.`);
        }
      }
    }
  } catch (err: any) {
    console.error('Error dispatching notifications:', err.message || err);
  }
}

export async function sendFacultyBatchNotifications(facultyId: string, facultyName: string, changes: TimetableChangeInsert[]) {
  if (!fcmInitialized) {
    console.warn('Skipping push notification dispatch: Firebase Admin SDK is not initialized.');
    return;
  }

  if (changes.length === 0) return;

  try {
    const { data: tokens, error: tokensErr } = await supabase
      .from('device_tokens')
      .select('fcm_token')
      .eq('user_mode', 'faculty')
      .eq('faculty_id', facultyId)
      .eq('notifications_enabled', true);

    if (tokensErr) {
      console.error('Failed to retrieve device tokens:', tokensErr.message);
      return;
    }

    if (!tokens || tokens.length === 0) {
      console.log(`No active device tokens found for faculty ${facultyId}. Skipping FCM push.`);
      return;
    }

    const fcmTokens = tokens.map(t => t.fcm_token);

    const isHoliday = await isHolidayToday('faculty');
    const todayDay = getISTDay();

    for (const change of changes) {
      const changeDay = extractDayFromFieldName(change.field_name);
      if (isHoliday && changeDay === todayDay) {
        console.log(`Skipping Faculty FCM for ${change.change_type} on ${changeDay} because today is a holiday.`);
        continue;
      }

      const type = change.change_type;
      const oldVal = change.old_value || '';
      const newVal = change.new_value || '';

      let subject = 'Class';
      const fieldParts = (change.field_name || '').split(':');
      if (fieldParts.length > 1) {
        subject = fieldParts.slice(1).join(':');
      }

      let title = '';
      let body = '';

      if (type === 'ROOM_CHANGED') {
        title = 'Room Changed';
        body = `Room Changed: ${subject} moved to ${newVal}`;
      } else if (type === 'CLASS_REMOVED') {
        title = 'Class Cancelled';
        const oldSubject = oldVal.split(' (')[0];
        body = `Class Cancelled: ${oldSubject} has been cancelled for today`;
      } else if (type === 'CLASS_ADDED') {
        title = 'Class Added';
        const newSubject = newVal.split(' (')[0];
        body = `Class Added: ${newSubject} has been added`;
      } else if (type === 'TIME_CHANGED') {
        title = 'Class Rescheduled';
        body = `Class Rescheduled: ${subject} rescheduled to ${newVal}`;
      } else {
        title = 'Timetable Updated';
        body = `Schedule modified for ${subject}`;
      }

      const payload = {
        tokens: fcmTokens,
        notification: {
          title,
          body,
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          faculty_id: facultyId,
          change_type: type,
        },
        android: {
          notification: {
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            sound: 'default',
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            }
          }
        }
      };

      const response = await admin.messaging().sendEachForMulticast(payload);
      console.log(`Dispatched Faculty FCM notifications for "${title}": ${response.successCount} succeeded, ${response.failureCount} failed.`);
      
      if (response.failureCount > 0) {
        const tokensToDelete: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success && resp.error) {
            const code = resp.error.code;
            if (
              code === 'messaging/invalid-registration-token' ||
              code === 'messaging/registration-token-not-registered'
            ) {
              tokensToDelete.push(fcmTokens[idx]);
            }
          }
        });

        if (tokensToDelete.length > 0) {
          await supabase
            .from('device_tokens')
            .delete()
            .in('fcm_token', tokensToDelete);
        }
      }
    }
  } catch (err: any) {
    console.error('Error dispatching notifications:', err.message || err);
  }
}


export async function sendGenericBroadcast(title: string, message: string) {
  if (!fcmInitialized) {
    console.warn('Skipping broadcast: Firebase Admin SDK is not initialized.');
    return { success: false, error: 'FCM not initialized' };
  }

  try {
    const payload = {
      topic: 'sru_all_users',
      notification: {
        title,
        body: message,
      },
      data: {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        type: 'broadcast'
      },
      android: {
        notification: {
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          sound: 'default',
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          }
        }
      }
    };

    const response = await admin.messaging().send(payload);
    console.log(`Dispatched Broadcast "${title}" to topic sru_all_users. MessageId: ${response}`);
    
    // For topic messages, we don't get success/failure counts per device, just a single success.
    return { success: true, count: 1 };
  } catch (err: any) {
    console.error('Error dispatching topic broadcast:', err.message || err);
    return { success: false, error: err.message || err };
  }
}

export async function sendHolidaySilentPush(date: string, targetMode: string) {
  if (!fcmInitialized) {
    console.warn('Skipping holiday silent push: Firebase Admin SDK is not initialized.');
    return;
  }
  
  try {
    const payload = {
      topic: 'sru_all_users',
      data: {
        type: 'calendar_override_updated',
        date,
        target_mode: targetMode
      }
    };
    
    // We send this as a pure data message (silent push). 
    // The mobile app background handler will intercept this and cancel any invalid local notifications.
    const response = await admin.messaging().send(payload);
    console.log(`Dispatched Holiday Silent Push for ${date} (${targetMode}). MessageId: ${response}`);
  } catch (err: any) {
    console.error('Error dispatching holiday silent push:', err.message || err);
  }
}
