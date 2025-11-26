const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function setupAndSendWarning() {
  console.log('\n=== SETTING UP TRIAL WARNING ===\n');

  // Get the company
  const companiesSnapshot = await admin.firestore().collection('companies').limit(1).get();

  if (companiesSnapshot.empty) {
    console.error('No companies found!');
    process.exit(1);
  }

  const companyDoc = companiesSnapshot.docs[0];
  const company = companyDoc.data();

  console.log('Found company:');
  console.log(`  ID: ${companyDoc.id}`);
  console.log(`  Name: ${company.name || 'Unnamed'}`);
  console.log(`  Owner Email: ${company.ownerEmail || 'Not set'}`);
  console.log(`  Current Plan: ${company.currentPlan || 'none'}`);
  console.log('');

  // Calculate dates
  const now = new Date();
  const threeDaysFromNow = new Date(now);
  threeDaysFromNow.setDate(now.getDate() + 3);

  const trialStartDate = new Date(now);
  trialStartDate.setDate(now.getDate() - 27); // Started 27 days ago

  console.log('Setting up trial:');
  console.log(`  Trial Started: ${trialStartDate.toLocaleDateString()}`);
  console.log(`  Trial Ends: ${threeDaysFromNow.toLocaleDateString()} (3 days from now)`);
  console.log('');

  // Update company with trial dates
  await companyDoc.ref.update({
    currentPlan: 'trial',
    status: 'active',
    trialStartDate: admin.firestore.Timestamp.fromDate(trialStartDate),
    trialEndDate: admin.firestore.Timestamp.fromDate(threeDaysFromNow),
  });

  console.log('✅ Company updated with trial dates');
  console.log('');

  // Trigger the trial expiration check function
  console.log('Triggering trial expiration check...');
  console.log('');

  const https = require('https');
  const url = 'https://testtrialexpirations-4i2x6khbwq-uc.a.run.app';

  https.get(url, (res) => {
    let data = '';

    res.on('data', (chunk) => {
      data += chunk;
    });

    res.on('end', () => {
      console.log('Response from trial check:');
      console.log(data);
      console.log('');
      console.log('✅ Trial warning email should be sent!');
      console.log(`Check ${company.ownerEmail || 'the owner email'} for the email.`);
      console.log('');
      process.exit(0);
    });
  }).on('error', (err) => {
    console.error('Error triggering function:', err);
    process.exit(1);
  });
}

setupAndSendWarning().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
