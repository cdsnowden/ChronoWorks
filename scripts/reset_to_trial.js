const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function resetToFreePhase1() {
  console.log('\n=== RESETTING COMPANY TO FREE PLAN PHASE 1 ===\n');

  const companiesSnapshot = await admin.firestore()
    .collection('companies')
    .where('businessName', '==', 'exalt video')
    .limit(1)
    .get();

  if (!companiesSnapshot.empty) {
    const doc = companiesSnapshot.docs[0];

    // Set Free Plan Phase 1 dates (30 days from now)
    const now = new Date();
    const freePhase1EndDate = new Date();
    freePhase1EndDate.setDate(now.getDate() + 30);

    await doc.ref.update({
      currentPlan: 'free',
      freePhase: 1,
      freePhase1StartDate: admin.firestore.Timestamp.fromDate(now),
      freePhase1EndDate: admin.firestore.Timestamp.fromDate(freePhase1EndDate),
      freePhase2StartDate: null,
      freePhase2EndDate: null,
      status: 'active',
      billingCycle: null,
      // Remove old trial/free fields if they exist
      trialStartDate: admin.firestore.FieldValue.delete(),
      trialEndDate: admin.firestore.FieldValue.delete(),
      freeStartDate: admin.firestore.FieldValue.delete(),
      freeEndDate: admin.firestore.FieldValue.delete(),
      lastModified: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log('✅ Company reset to Free Plan Phase 1');
    console.log('Phase 1 Start Date:', now.toLocaleDateString());
    console.log('Phase 1 End Date:', freePhase1EndDate.toLocaleDateString());
    console.log('');
  } else {
    console.log('Company not found');
  }

  process.exit(0);
}

resetToFreePhase1();
