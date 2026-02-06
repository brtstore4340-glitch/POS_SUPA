const functions = require('firebase-functions');
const admin = require('firebase-admin');

// 1. ตรวจสอบการ Initialize (ป้องกันการ Error 500 จากการหา SDK ไม่เจอ)
if (admin.apps.length === 0) {
    admin.initializeApp();
}

const db = admin.firestore();

// ฟังก์ชัน bootstrapAdmin ที่จัดการ Error อย่างเป็นระบบ
exports.bootstrapAdmin = functions.region('asia-southeast1').https.onCall(async (data, context) => {
    try {
        // ตรวจสอบว่ามีข้อมูลส่งมาไหม
        if (!data.email) {
            throw new functions.https.HttpsError('invalid-argument', 'ต้องระบุ email');
        }

        // 2. Logic การสร้าง Admin หรืออัปเดต Role
        const user = await admin.auth().getUserByEmail(data.email);
        
        // ตั้งค่า Custom Claims (Role-based)
        await admin.auth().setCustomUserClaims(user.uid, { admin: true });

        // บันทึกลง Firestore เพื่อให้ Rules (ที่เราเขียนก่อนหน้านี้) ตรวจสอบได้
        await db.collection('users').doc(user.uid).set({
            email: data.email,
            role: 'admin',
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        return { message: `Success: ${data.email} is now an admin.` };

    } catch (error) {
        console.error("BOOTSTRAP_ERROR:", error); // อันนี้จะไปโผล่ใน Cloud Logging
        // ส่ง Error กลับไปหา Client ให้ชัดเจน ไม่ใช่แค่ 500
        throw new functions.https.HttpsError('internal', error.message);
    }
});
