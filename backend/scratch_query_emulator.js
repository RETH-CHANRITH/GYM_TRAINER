const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';

admin.initializeApp({
  projectId: 'gym-trainer-booking-app',
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
