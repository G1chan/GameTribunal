const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();
setGlobalOptions({ region: 'asia-northeast3' });

const db = admin.firestore();
const MIN_VOTES = 3;
const DECISIVE_THRESHOLD = 0.6;

function determineWinner(leftVotes, rightVotes) {
  const total = leftVotes + rightVotes;
  if (total < MIN_VOTES) return 'draw';
  if (leftVotes / total >= DECISIVE_THRESHOLD) return 'left';
  if (rightVotes / total >= DECISIVE_THRESHOLD) return 'right';
  return 'draw';
}

function statusLabel(winner) {
  if (winner === 'left') return '판정 종결 · 신청인 과실';
  if (winner === 'right') return '판정 종결 · 상대방 과실';
  return '판정 종결 · 치열한 논쟁(보류)';
}

/** 1) 5분마다 마감 시간이 지난 사건을 서버에서 자동 종결 및 알림 생성 */
exports.autoCloseExpiredCases = onSchedule('every 5 minutes', async () => {
  const now = admin.firestore.Timestamp.now();
  const expiredSnap = await db
    .collection('cases')
    .where('status', '==', 'open')
    .where('expiresAt', '<=', now)
    .limit(50)
    .get();

  for (const doc of expiredSnap.docs) {
    const data = doc.data();
    const leftVotes = Number(data.leftVotes || 0);
    const rightVotes = Number(data.rightVotes || 0);
    const winner = determineWinner(leftVotes, rightVotes);

    await doc.ref.update({
      status: 'closed',
      winner,
      closedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const votesSnap = await doc.ref.collection('votes').get();
    const recipients = new Set();
    if (data.authorUid) recipients.add(data.authorUid);
    votesSnap.docs.forEach((v) => recipients.add(v.id));

    const batch = db.batch();
    recipients.forEach((uid) => {
      const ref = db.collection('users').doc(uid).collection('notifications').doc();
      batch.set(ref, {
        type: 'closed',
        caseId: doc.id,
        title: '참여한 사건의 판정이 종결되었습니다',
        body: `${data.title || '사건'} → ${statusLabel(winner)}`,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();
  }
});

/** 2) 인앱 알림 문서 생성 시 해당 유저의 FCM 기기들로 실제 푸시 알림 발송 */
exports.sendPushOnNotification = onDocumentCreated(
  'users/{uid}/notifications/{notifId}',
  async (event) => {
    const uid = event.params.uid;
    const notif = event.data?.data();
    if (!notif) return;

    const userSnap = await db.collection('users').doc(uid).get();
    if (!userSnap.exists) return;

    const userData = userSnap.data() || {};
    if (userData.notificationsEnabled === false) return;

    const tokens = Array.isArray(userData.fcmTokens) ? userData.fcmTokens : [];
    if (tokens.length === 0) return;

    const response = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: notif.title || '겜문철 새 알림',
        body: notif.body || '',
      },
      data: {
        caseId: String(notif.caseId || ''),
        type: String(notif.type || 'notice'),
      },
    });

    // 만료·무효 토큰 자동 정리
    const invalidTokens = [];
    response.responses.forEach((res, idx) => {
      if (!res.success) {
        const code = res.error?.code || '';
        if (
          code === 'messaging/invalid-registration-token' ||
          code === 'messaging/registration-token-not-registered'
        ) {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      await userSnap.ref.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
      });
    }
  }
);