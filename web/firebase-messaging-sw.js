/* Same Firebase JS SDK version used by firebase_core_web. No private keys here. */
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.19.0/firebase-messaging-compat.js');
firebase.initializeApp({
  apiKey: 'AIzaSyDs_rc0MCk5KxcTQyAaakjK9MhDxxsgeok',
  appId: '1:1821240632:web:12b872386b5a158ffae5cd',
  messagingSenderId: '1821240632',
  projectId: 'sistema-de-gestion-y-pqrs',
  authDomain: 'sistema-de-gestion-y-pqrs.firebaseapp.com',
});
// FCM displays notification payloads and handles fcmOptions.link. Never display twice.
firebase.messaging();
