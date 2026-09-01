require('dotenv').config();
const admin = require('firebase-admin');
admin.initializeApp({
  credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON))
});
const tokens = [
  'cTH89IqQRUaoJETk7qKO7Q:APA91bEjLz-uuHMAUK-AB2ex5ypTJDPXz3UoN1G79NEmSQkixq7DRGXR-Xak0i0Dx5aQ_1QhpVZ9xC2ePz_rdtV8sh-wmhPeTxAiKC988nSc_njX920VNA4',
  'cSkif7suS3aS6IXxHxcNG8:APA91bHcVW8Cr9h41dY-v5wqT2kLbjyyKz2dL2Abzmtaig7IhpEAzr21dISwrITwojvYoGddjtZvvUNA4GxtOYruxzSVL4CTn8z-jQIRnhBJdRgoG3ZK4IY',
  'cQQG4a4VSRWAjbZc9wVJXk:APA91bGQRUu2yJ5-diQIB_B0kxQX-b7aVXtb11uOSCUszZCSXvPsZyIEEnXjJvCv4Wv4z4zSHSq8DUOkIOMe1fh7yJ8r3Zb-pLo3y00C_lHKNV7K2Jf2GnY',
  'dsuKE_BsTJqK-MRdsFXVm2:APA91bGdvJCna7n0mLd-QoMpRU0w6zmILNqMBPgZV7zYdJvj3EKDAHq2fN496ZmsL6aKw3Lba75MXqKVBzwevu6Q1AEDKoDRWu7r3WRCttudhBioKMppS-Q',
  'evU92ScqTGS-BIG24w1ock:APA91bGKAUuxi1B3EiHJNjAh98iRKDEJkGIQpS0Nn9-xsExDO75J9iUvWR5mB2TnArmVhefszOLa5Q1R4MluZNy4M6TAiMTqb87PPs4qTMMIDLZ8GW8RKQ0'
];

async function run() {
  for (let token of tokens) {
    try {
      const res = await admin.messaging().send({
        token: token,
        notification: { title: 'SRU Timetable Test', body: 'FCM notification test' },
        data: { click_action: 'FLUTTER_NOTIFICATION_CLICK' },
        android: { notification: { clickAction: 'FLUTTER_NOTIFICATION_CLICK', sound: 'default' } }
      });
      console.log('Success:', res);
    } catch(e) {
      console.error('Fail:', token.substring(0, 15) + '...', e.code);
    }
  }
}
run();
