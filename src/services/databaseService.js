import { 
  doc, 
  onSnapshot, 
  getFirestore, 
  collection, 
  query, 
  where,
  getDocs,
  getDoc,
  writeBatch
} from "firebase/firestore";

const db = getFirestore();

/**
 * Monitor System Connection Status (Public Access)
 * Returns real-time connection/online status visible to all users
 */
export const monitorSystemStatus = (callback) => {
  try {
    const statusRef = doc(db, "system_status", "connectivity");
    return onSnapshot(
      statusRef,
      (snapshot) => {
        if (snapshot.exists()) {
          callback({
            success: true,
            data: snapshot.data(),
            timestamp: new Date()
          });
        } else {
          callback({
            success: true,
            data: { status: "offline" },
            timestamp: new Date()
          });
        }
      },
      (error) => {
        callback({
          success: false,
          error: error.message,
          timestamp: new Date()
        });
      }
    );
  } catch (error) {
    console.error("Error monitoring system status:", error);
    throw error;
  }
};

/**
 * Fetch Protected Data by Role (Authenticated Users Only)
 * จะใช้ได้เมื่อ Login และมีสิทธิ์เท่านั้น
 */
export const fetchDataByRole = async (collectionName, userRole) => {
  try {
    if (!['admin', 'SM-SGM', 'editor', 'user'].includes(userRole)) {
      throw new Error("คุณไม่มีสิทธิ์เข้าถึงข้อมูลนี้");
    }

    const collRef = collection(db, collectionName);
    const snapshot = await getDocs(collRef);
    
    if (snapshot.empty) {
      return {
        success: true,
        data: [],
        message: `ไม่พบข้อมูลใน ${collectionName}`
      };
    }

    const data = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    return {
      success: true,
      data,
      count: data.length
    };
  } catch (error) {
    console.error(`Error fetching data from ${collectionName}:`, error);
    return {
      success: false,
      error: error.message,
      data: []
    };
  }
};

/**
 * Get User Profile (Protected)
 * ดึงข้อมูลโปรไฟล์ของตัวเองเท่านั้น
 */
export const getUserProfile = async (uid) => {
  try {
    const userRef = doc(db, "users", uid);
    const snapshot = await getDoc(userRef);
    
    if (!snapshot.exists()) {
      return {
        success: false,
        error: "ไม่พบข้อมูลผู้ใช้",
        data: null
      };
    }

    return {
      success: true,
      data: {
        uid,
        ...snapshot.data()
      }
    };
  } catch (error) {
    console.error("Error fetching user profile:", error);
    return {
      success: false,
      error: error.message,
      data: null
    };
  }
};

/**
 * Get Product Catalog (Protected - Authenticated Users)
 * ดึงรายการสินค้าทั้งหมด (เฉพาะ Login เท่านั้น)
 */
export const getProducts = async () => {
  try {
    const productsRef = collection(db, "products");
    const snapshot = await getDocs(productsRef);
    
    if (snapshot.empty) {
      return {
        success: true,
        data: [],
        message: "ไม่พบสินค้า"
      };
    }

    const products = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    return {
      success: true,
      data: products,
      count: products.length
    };
  } catch (error) {
    console.error("Error fetching products:", error);
    return {
      success: false,
      error: error.message,
      data: []
    };
  }
};

/**
 * Get Admin Metadata (Protected - Admin Only)
 * ดึงข้อมูล Admin Metadata (Admin เท่านั้น)
 */
export const getAdminMetadata = async () => {
  try {
    const adminMetaRef = collection(db, "adminMeta");
    const snapshot = await getDocs(adminMetaRef);
    
    if (snapshot.empty) {
      return {
        success: true,
        data: [],
        message: "ไม่พบข้อมูล Admin Metadata"
      };
    }

    const metadata = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    return {
      success: true,
      data: metadata,
      count: metadata.length
    };
  } catch (error) {
    console.error("Error fetching admin metadata:", error);
    if (error.code === 'permission-denied') {
      return {
        success: false,
        error: "คุณไม่มีสิทธิ์เข้าถึง Admin Metadata",
        data: []
      };
    }
    return {
      success: false,
      error: error.message,
      data: []
    };
  }
};

/**
 * Handle Firestore Permission Errors
 * ระบบจัดการ Error จากสิทธิ์ Firestore
 */
export const handleFirestoreError = (error, collectionName = "unknown") => {
  const errorMap = {
    'permission-denied': `ขออภัย - คุณไม่มีสิทธิ์เข้าถึง ${collectionName}`,
    'unavailable': 'Firestore ไม่พร้อมใช้งานชั่วขณะ กรุณาลองใหม่',
    'unauthenticated': 'กรุณา Login ก่อนที่จะเข้าถึงข้อมูล',
    'invalid-argument': 'ข้อมูลที่ส่งมาไม่ถูกต้อง'
  };

  return {
    code: error.code,
    message: errorMap[error.code] || error.message,
    userMessage: true
  };
};

export default {
  monitorSystemStatus,
  fetchDataByRole,
  getUserProfile,
  getProducts,
  getAdminMetadata,
  handleFirestoreError
};
