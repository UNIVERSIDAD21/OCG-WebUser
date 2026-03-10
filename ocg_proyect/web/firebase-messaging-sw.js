/* eslint-disable no-undef */
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAMmJh3fXAsLfe1XVUA6kGm9kEHHuj5iRY',
  authDomain: 'ocg-humanbionics.firebaseapp.com',
  projectId: 'ocg-humanbionics',
  storageBucket: 'ocg-humanbionics.firebasestorage.app',
  messagingSenderId: '196011124818',
  appId: '1:196011124818:web:c526108c8a981a71d7d78b',
  measurementId: 'G-9WZ1GY1YZR',
});

firebase.messaging();
