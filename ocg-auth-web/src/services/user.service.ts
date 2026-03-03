import { doc, getDoc, serverTimestamp, setDoc } from 'firebase/firestore';
import { db } from './firebase';

export const ensureUserProfile = async (uid: string, email: string | null) => {
  const ref = doc(db, 'users', uid);
  const snapshot = await getDoc(ref);

  if (snapshot.exists()) return;

  await setDoc(ref, {
    uid,
    email: email ?? '',
    displayName: '',
    role: 'patient',
    createdAt: serverTimestamp(),
    status: 'active',
  });
};
