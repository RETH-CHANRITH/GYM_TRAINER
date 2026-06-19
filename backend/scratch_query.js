const dotenv = require('dotenv');
dotenv.config();
const admin = require('firebase-admin');

const decoded = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf-8');
const serviceAccount = JSON.parse(decoded);
serviceAccount.private_key = serviceAccount.private_key.replace(/\\n/g, '\n');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: process.env.FIREBASE_DATABASE_URL,
});

const db = admin.firestore();

async function run() {
  console.log("=== QUERYING TRAINERS ===");
  const trainerProfiles = await db.collection('trainerProfiles').get();
  trainerProfiles.forEach(doc => {
    console.log(`Trainer ID: ${doc.id}, Name: ${doc.data().displayName || doc.data().name}, Bio: ${doc.data().bio}`);
  });

  console.log("\n=== QUERYING PAYOUTS ===");
  const payouts = await db.collection('payouts').get();
  payouts.forEach(doc => {
    const data = doc.data();
    console.log(`Payout ID: ${doc.id}, Trainer ID: ${data.trainerId}, Trainer Name: ${data.trainerName}, Amount: ${data.amount}, Status: ${data.status}`);
  });

  console.log("\n=== QUERYING REFUNDS ===");
  const refunds = await db.collection('refunds').get();
  refunds.forEach(doc => {
    const data = doc.data();
    console.log(`Refund ID: ${doc.id}, Trainer ID: ${data.trainerId}, Trainer Name: ${data.trainerName}, Amount: ${data.amount}, Status: ${data.status}`);
  });

  console.log("\n=== QUERYING BOOKINGS ===");
  const bookings = await db.collection('bookings').get();
  bookings.forEach(doc => {
    const data = doc.data();
    console.log(`Booking ID: ${doc.id}, Trainer ID: ${data.trainerId}, Status: ${data.status}, Paid: ${data.paid}, PaymentStatus: ${data.paymentStatus}, AmountPaid: ${data.amountPaid}, Price: ${data.price}`);
  });

  process.exit(0);
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
