const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const Razorpay = require("razorpay");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

setGlobalOptions({ region: "asia-south1" });

const razorpayKeyId = defineSecret("RAZORPAY_KEY_ID");
const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");
const razorpayWebhookSecret = defineSecret("RAZORPAY_WEBHOOK_SECRET"); 

const ADMIN_EMAILS = ["admin@loqx.com", "app.sportsbuzz@gmail.com", "loqxarena@gmail.com"];

// --- 1. CORE TRANSACTION ENGINE (PREVENTS DOUBLE CREDITING) ---
const processWalletDeposit = async (paymentId, userId, amount) => {
  const txRef = db.collection("transactions").doc(paymentId);

  await db.runTransaction(async (t) => {
    // Check if this specific payment ID was already added to the wallet
    const txDoc = await t.get(txRef);
    if (txDoc.exists) {
      console.log(`Payment ${paymentId} already processed. Skipping.`);
      return; 
    }

    const txData = {
      userId: userId,
      amount: amount,
      type: "deposit",
      description: "Wallet Recharge via Razorpay",
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Log in Root Transactions
    t.set(txRef, txData);

    // Log in User's History
    const userTxRef = db.collection("users").doc(userId).collection("transactions").doc(paymentId);
    t.set(userTxRef, txData);

    // ACTUALLY ADD THE COINS TO THE WALLET
    const userRef = db.collection("users").doc(userId);
    t.set(userRef, {
      wallet_balance: admin.firestore.FieldValue.increment(amount)
    }, { merge: true });
  });
};

// --- 2. CREATE RAZORPAY ORDER ---
exports.createRazorpayOrder = onCall({ secrets: [razorpayKeyId, razorpayKeySecret] }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const razorpay = new Razorpay({
    key_id: razorpayKeyId.value(),
    key_secret: razorpayKeySecret.value(),
  });

  try {
    const order = await razorpay.orders.create({
      amount: request.data.amount * 100,
      currency: "INR",
      receipt: `rcpt_${Date.now()}`,
      notes: {
        userId: request.auth.uid,
        type: "wallet_deposit" // Explicitly marking this as a coin purchase
      }
    });
    return { orderId: order.id, keyId: razorpayKeyId.value() };
  } catch (error) {
    throw new HttpsError("internal", error.message);
  }
});

// --- 3. VERIFY PAYMENT (FROM FLUTTER APP) ---
exports.verifyPayment = onCall({ secrets: [razorpayKeySecret] }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");

  const { orderId, paymentId, signature, amount } = request.data;
  const userId = request.auth.uid;

  const generatedSignature = crypto
    .createHmac("sha256", razorpayKeySecret.value())
    .update(orderId + "|" + paymentId)
    .digest("hex");

  if (generatedSignature !== signature) throw new HttpsError("aborted", "Signature mismatch.");

  // Inject coins into wallet securely
  await processWalletDeposit(paymentId, userId, amount);

  return { success: true, message: "Payment verified. Coins added." };
});

// --- 4. GHOST TRANSACTION WEBHOOK ---
exports.razorpayWebhook = onRequest({ secrets: [razorpayWebhookSecret] }, async (req, res) => {
  try {
    const signature = req.headers["x-razorpay-signature"];
    const payload = req.rawBody; 

    const expectedSignature = crypto
      .createHmac("sha256", razorpayWebhookSecret.value())
      .update(payload)
      .digest("hex");

    if (signature !== expectedSignature) return res.status(400).send("Invalid signature");

    const event = req.body;
    
    if (event.event === "payment.captured") {
      const payment = event.payload.payment.entity;
      const paymentId = payment.id;
      const amount = payment.amount / 100;
      const userId = payment.notes?.userId;

      if (userId) {
        // Inject coins securely if app crashed during payment
        await processWalletDeposit(paymentId, userId, amount);
      }
    }
    res.status(200).send("OK");
  } catch (error) {
    console.error("Webhook Error:", error);
    res.status(500).send("Internal Server Error");
  }
});

// --- 5. DISTRIBUTE PRIZES (Admin) ---
exports.distributePrizes = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const email = (request.auth.token.email || "").toLowerCase();
  if (!ADMIN_EMAILS.includes(email)) throw new HttpsError("permission-denied", "Not Admin.");

  const { tournamentId, winners } = request.data; 
  if (!winners || winners.length === 0) return { success: false };

  const batch = db.batch();

  winners.forEach((winner) => {
    const userRef = db.collection("users").doc(winner.userId);
    batch.set(userRef, { 
      totalWinnings: admin.firestore.FieldValue.increment(winner.amount),
      wallet_balance: admin.firestore.FieldValue.increment(winner.amount) // Make sure winnings go to wallet!
    }, { merge: true });

    const prizeTxId = `prize_${Date.now()}_${winner.userId}`;
    const txData = {
      userId: winner.userId,
      amount: winner.amount,
      type: "winnings",
      description: `Rank ${winner.rank} Prize`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      tournamentId: tournamentId
    };

    batch.set(db.collection("transactions").doc(prizeTxId), txData, { merge: true });
    batch.set(userRef.collection("transactions").doc(prizeTxId), txData, { merge: true });
  });

  await batch.commit();
  return { success: true };
});

// --- 6. SEND GLOBAL NOTIFICATION (Admin) ---
exports.sendGlobalNotification = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Login required.");
  const email = (request.auth.token.email || "").toLowerCase();
  if (!ADMIN_EMAILS.includes(email)) throw new HttpsError("permission-denied", "Not Admin.");

  const { title, message } = request.data;
  if (!message) throw new HttpsError("invalid-argument", "Message cannot be empty.");

  const payload = { notification: { title: title || "LOQX ARENA", body: message }, topic: "all_users" };

  try {
    const response = await admin.messaging().send(payload);
    return { success: true, messageId: response };
  } catch (error) {
    throw new HttpsError("internal", "Failed to send push notification.");
  }
});