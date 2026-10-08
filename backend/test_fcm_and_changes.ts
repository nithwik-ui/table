import * as admin from 'firebase-admin';
import * as dotenv from 'dotenv';
import * as path from 'path';
import { createClient } from '@supabase/supabase-js';

dotenv.config({ path: path.join(__dirname, '.env') });

const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

const supabase = createClient(supabaseUrl, supabaseKey);

let serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON!;
if (serviceAccountJson.startsWith("'") && serviceAccountJson.endsWith("'")) {
  serviceAccountJson = serviceAccountJson.slice(1, -1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(serviceAccountJson)),
  });
}

async function runTest() {
  console.log('=== SRU Timetable FCM & Live Changes Test ===\n');

  // 1. Identify Target Batch
  const batchCode = '26CAIBTAIB21';
  const { data: batch, error: batchErr } = await supabase
    .from('batches')
    .select('id, batch_code')
    .eq('batch_code', batchCode)
    .single();

  if (batchErr || !batch) {
    console.error('Failed to find batch:', batchErr);
    return;
  }

  const batchId = batch.id;
  console.log(`Found Target Batch: ${batch.batch_code} (ID: ${batchId})`);

  // 2. Fetch Registered Device Tokens
  const { data: deviceTokens, error: devErr } = await supabase
    .from('device_tokens')
    .select('fcm_token, created_at, user_mode')
    .eq('batch_id', batchId)
    .eq('notifications_enabled', true)
    .order('created_at', { ascending: false });

  if (devErr) {
    console.error('Error fetching device tokens:', devErr);
  }

  const tokens = (deviceTokens || []).map((t) => t.fcm_token);
  console.log(`Found ${tokens.length} registered device token(s) for ${batchCode}:`);
  tokens.forEach((t, i) => console.log(`  [${i + 1}] ${t.substring(0, 25)}...`));

  // 3. Insert Test Class into timetable_entries
  console.log('\n--- 1. Adding Test Class to timetable_entries ---');
  const testEntry = {
    batch_id: batchId,
    day: 'Wednesday',
    start_time: '15:30',
    end_time: '16:30',
    subject: 'TEST: Cloud Computing & DevOps',
    faculty: 'Dr. SRU Test Faculty',
    room: '8301-BL8-TF',
    semester: 'I',
    ltp: 'Lecture',
    source_hash: 'manual-test-' + Date.now(),
  };

  const { data: insertedClass, error: insertErr } = await supabase
    .from('timetable_entries')
    .upsert(testEntry, { onConflict: 'batch_id,day,start_time,end_time,subject,faculty,room,ltp,semester' })
    .select();

  if (insertErr) {
    console.error('Error inserting test class:', insertErr);
  } else {
    console.log('✅ Added Test Class to Timetable Entries:', testEntry.subject, `(${testEntry.day} ${testEntry.start_time} - ${testEntry.end_time} in ${testEntry.room})`);
  }

  // 4. Insert Live Room Change into timetable_changes
  console.log('\n--- 2. Injecting Room Change & Class Added into timetable_changes ---');
  const nowIso = new Date().toISOString();
  const mockChanges = [
    {
      batch_id: batchId,
      change_type: 'ROOM_CHANGED',
      field_name: 'room:Computational Chemistry|Wednesday|10:30',
      old_value: '8105-BL8-FF',
      new_value: '9201-BL9-SF (Moved to Block 9 Lab)',
      detected_at: nowIso,
    },
    {
      batch_id: batchId,
      change_type: 'CLASS_ADDED',
      field_name: 'class:TEST: Cloud Computing & DevOps|Wednesday|15:30',
      old_value: 'None',
      new_value: '8301-BL8-TF (Dr. SRU Test Faculty)',
      detected_at: nowIso,
    },
  ];

  const { error: changeErr } = await supabase.from('timetable_changes').insert(mockChanges);
  if (changeErr) {
    console.error('Error inserting timetable changes:', changeErr);
  } else {
    console.log('✅ Injected 2 Live Changes into timetable_changes table.');
  }

  // 5. Send FCM Push Notifications
  console.log('\n--- 3. Sending Real FCM Push Notifications ---');

  const notificationsToSend = [
    {
      title: '🔴 Room Changed: Computational Chemistry',
      body: `Class moved to 9201-BL9-SF (Block 9 Lab) for ${batchCode}`,
      change_type: 'ROOM_CHANGED',
      room: '9201-BL9-SF',
    },
    {
      title: '🟢 Class Added: Cloud Computing & DevOps',
      body: `New class scheduled today 3:30 PM - 4:30 PM in 8301-BL8-TF (${batchCode})`,
      change_type: 'CLASS_ADDED',
      room: '8301-BL8-TF',
    },
  ];

  for (const notif of notificationsToSend) {
    console.log(`\nDispatching notification: "${notif.title}"...`);

    // A. Send to specific device tokens for this batch
    if (tokens.length > 0) {
      const multicastPayload: admin.messaging.MulticastMessage = {
        tokens: tokens,
        notification: {
          title: notif.title,
          body: notif.body,
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          batch_id: batchId,
          change_type: notif.change_type,
          room: notif.room,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'sru_timetable_alerts',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            sound: 'default',
            priority: 'high',
          },
        },
      };

      const res = await admin.messaging().sendEachForMulticast(multicastPayload);
      console.log(`  -> Device multicast result: ${res.successCount} succeeded, ${res.failureCount} failed`);
      res.responses.forEach((r, idx) => {
        if (r.success) {
          console.log(`     ✓ Token [${idx + 1}] Message ID: ${r.messageId}`);
        } else {
          console.log(`     ✗ Token [${idx + 1}] Error: ${r.error?.code} - ${r.error?.message}`);
        }
      });
    }

    // B. Also dispatch to topic 'sru_all_users'
    try {
      const topicPayload: admin.messaging.Message = {
        topic: 'sru_all_users',
        notification: {
          title: notif.title,
          body: notif.body,
        },
        data: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          batch_id: batchId,
          change_type: notif.change_type,
          room: notif.room,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'sru_timetable_alerts',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
            sound: 'default',
            priority: 'high',
          },
        },
      };

      const topicRes = await admin.messaging().send(topicPayload);
      console.log(`  -> Topic 'sru_all_users' broadcast success: ${topicRes}`);
    } catch (tErr: any) {
      console.error(`  -> Topic broadcast error:`, tErr.message);
    }
  }

  console.log('\n=== FCM & Live Changes Test Completed Successfully ===');
}

runTest();
