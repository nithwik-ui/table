// Firebase Web Push Service Worker for SRU Timetable
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.23.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyD9_WzJsEJSi-0ke0rdZVdA6ohgX_yib-Q",
  appId: "1:712842876134:web:6a81c13779ec2828949727",
  messagingSenderId: "712842876134",
  projectId: "timetable-77a7d",
  authDomain: "timetable-77a7d.firebaseapp.com",
  storageBucket: "timetable-77a7d.firebasestorage.app",
  measurementId: "G-WRP2DM4ZRL"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Background push received:', payload);
  const notificationTitle = payload.notification?.title || payload.data?.title || 'SRU Timetable Update';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || 'Your timetable or classroom has been updated.',
    icon: '/icons/Icon-192.png',
    badge: '/favicon.png',
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
