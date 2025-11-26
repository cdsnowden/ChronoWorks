const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function removePhotoVerification() {
  try {
    const plansSnapshot = await admin.firestore()
      .collection('subscriptionPlans')
      .get();

    console.log(`Updating ${plansSnapshot.size} plans...\n`);

    const batch = admin.firestore().batch();

    plansSnapshot.forEach(doc => {
      const plan = doc.data();
      const features = plan.features || {};

      // Disable photo verification
      features.photoVerification = false;

      batch.update(doc.ref, { features });
      console.log(`✓ ${plan.name}: Photo verification disabled`);
    });

    await batch.commit();

    console.log('\n✓ All plans updated successfully!');
    console.log('✓ Photo verification removed from all plans');

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

removePhotoVerification();
