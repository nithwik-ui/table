import * as admin from 'firebase-admin';
import { supabase } from '../db/supabase';
import { TimetableChangeInsert } from '../sync/diff';

let fcmInitialized = false;

try {
  // Initialize Firebase Admin SDK safely
  // Production environments locate credentials from applicationDefault()
  admin.initializeApp({
    credential: admin.credential.applicationDefault()
  });
  fcmInitialized = true;
  console.log('Firebase Admin SDK initialized successfully.');
} catch (err: any) {
  console.warn('Firebase Admin SDK could not initialize (Application Default Credentials missing):', err.message);
  
  // Fallback: Check if service account JSON configuration is stored in environment variables
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (serviceAccountJson) {
    try {
      admin.initializeApp({
        credential: admin.credential.cert(JSON.parse(serviceAccountJson))
      });
      fcmInitialized = true;
      console.log('Firebase Admin SDK initialized successfully via FIREBASE_SERVICE_ACCOUNT_JSON env var.');
    } catch (subErr: any) {
      console.error('Failed to initialize Firebase Admin SDK with service account JSON:', subErr.message);
    }
  }
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

    // 3. Dispatch multicast message for each change
    for (const change of changes) {
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
