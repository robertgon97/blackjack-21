// Service worker de Firebase Cloud Messaging para la web (Fase 11b).
// Recibe las notificaciones push cuando la pestaña está en segundo plano.
// La config es pública (la misma de firebase_options.dart → web).
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyC5Amr6qBWd-JRb2nORGNUH5XzgRDLezIA',
  appId: '1:822375769128:web:3aad776ef0bc900492011d',
  messagingSenderId: '822375769128',
  projectId: 'blackjack-21-app',
  authDomain: 'blackjack-21-app.firebaseapp.com',
  storageBucket: 'blackjack-21-app.firebasestorage.app',
});

firebase.messaging();
