import { initializeApp, getApps, getApp } from 'firebase/app';
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signOut as fbSignOut,
  onAuthStateChanged,
  User as FirebaseUser,
} from 'firebase/auth';
import {
  getFirestore,
  doc,
  setDoc,
  getDoc,
} from 'firebase/firestore';
import firebaseConfigJson from '../../firebase-applet-config.json';
import { Song, Playlist } from '../types';

const app = getApps().length === 0 ? initializeApp(firebaseConfigJson) : getApp();

export const auth = getAuth(app);
export const googleProvider = new GoogleAuthProvider();
googleProvider.addScope('https://www.googleapis.com/auth/drive.file');

// In-memory access token cache for Google Workspace APIs (per security guidelines)
let cachedDriveAccessToken: string | null = null;

export const setDriveAccessToken = (token: string | null) => {
  cachedDriveAccessToken = token;
};

export const getDriveAccessToken = () => cachedDriveAccessToken;

// Clear cached token on sign-out
auth.onAuthStateChanged((user) => {
  if (!user) {
    cachedDriveAccessToken = null;
  }
});

export const db = getFirestore(app, (firebaseConfigJson as Record<string, any>).firestoreDatabaseId || '(default)');

export interface CloudUserData {
  favorites?: Song[];
  playlists?: Playlist[];
  history?: Song[];
  updatedAt?: number;
}

export class CloudSyncService {
  static async saveUserData(
    uid: string,
    data: { favorites?: Song[]; playlists?: Playlist[]; history?: Song[] }
  ): Promise<void> {
    if (!uid) return;
    try {
      const userRef = doc(db, 'users', uid);
      await setDoc(
        userRef,
        {
          ...data,
          updatedAt: Date.now(),
        },
        { merge: true }
      );
    } catch (err) {
      console.warn('Could not sync user data to cloud:', err);
    }
  }

  static async loadUserData(uid: string): Promise<CloudUserData | null> {
    if (!uid) return null;
    try {
      const userRef = doc(db, 'users', uid);
      const snap = await getDoc(userRef);
      if (snap.exists()) {
        return snap.data() as CloudUserData;
      }
    } catch (err) {
      console.warn('Could not load user data from cloud:', err);
    }
    return null;
  }
}

export {
  signInWithPopup,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  fbSignOut,
  onAuthStateChanged,
};
export type { FirebaseUser };
