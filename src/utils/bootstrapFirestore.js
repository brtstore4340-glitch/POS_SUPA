import { collection, doc, setDoc, getDocs } from 'firebase/firestore';
import { db, auth } from '../config/firebase';

export const bootstrapFirestore = async () => {
  try {
    const user = auth.currentUser;
    
    if (!user) {
      throw new Error('No user authenticated');
    }

    console.log('🔧 Bootstrapping Firestore for user:', user.uid);

    // ตรวจสอบว่ามี collection 'ids' หรือยัง
    const idsRef = collection(db, 'ids');
    const snapshot = await getDocs(idsRef);

    console.log('Current IDs count:', snapshot.size);

    // ถ้ายังไม่มี ID ให้สร้างอันแรก
    if (snapshot.empty) {
      console.log('Creating default admin ID...');
      
      const adminId = 'admin001';
      await setDoc(doc(db, 'ids', adminId), {
        userId: user.uid,
        idCode: adminId,
        role: 'admin',
        displayName: 'Administrator',
        pin: '1234',
        status: 'active',
        menus: ['pos', 'admin', 'reports'],
        createdAt: new Date().toISOString(),
      });

      console.log('✅ Created admin ID:', adminId);
      return adminId;
    }

    console.log('✅ IDs already exist');
    return null;
  } catch (error) {
    console.error('❌ Bootstrap error:', error);
    throw error;
  }
};