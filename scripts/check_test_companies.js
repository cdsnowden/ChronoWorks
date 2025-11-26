/**
 * Script to check the status of test companies after trial lifecycle test
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  const serviceAccount = require('../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'chronoworks-dcfd6'
  });
}

const db = admin.firestore();

async function checkTestCompanies() {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║       Test Company Status Check                          ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  // Get all test companies
  const testCompaniesSnapshot = await db.collection('companies')
    .where('businessName', '>=', 'Test Company')
    .where('businessName', '<=', 'Test Company\uf8ff')
    .get();

  console.log(`Found ${testCompaniesSnapshot.size} test companies\n`);

  testCompaniesSnapshot.forEach(doc => {
    const company = doc.data();
    console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
    console.log(`Company: ${company.businessName}`);
    console.log(`ID: ${doc.id}`);
    console.log(`Current Plan: ${company.currentPlan}`);
    console.log(`Status: ${company.status}`);

    if (company.trialStartDate) {
      console.log(`Trial Start: ${company.trialStartDate.toDate().toLocaleDateString()}`);
    }
    if (company.trialEndDate) {
      console.log(`Trial End: ${company.trialEndDate.toDate().toLocaleDateString()}`);
    }
    if (company.freeStartDate) {
      console.log(`Free Start: ${company.freeStartDate.toDate().toLocaleDateString()}`);
    }
    if (company.freeEndDate) {
      console.log(`Free End: ${company.freeEndDate.toDate().toLocaleDateString()}`);
    }
    if (company.lockedAt) {
      console.log(`Locked At: ${company.lockedAt.toDate().toLocaleString()}`);
      console.log(`Locked Reason: ${company.lockedReason}`);
    }
    console.log('');
  });

  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║              Expected Results:                           ║');
  console.log('╚═══════════════════════════════════════════════════════════╝');
  console.log('✓ Day 27 company: Should still be on TRIAL (warning sent)');
  console.log('✓ Day 30 company: Should be on FREE now (transitioned)');
  console.log('✓ Day 57 company: Should still be on FREE (warning sent)');
  console.log('✓ Day 60 company: Should be LOCKED now');
  console.log('');
}

checkTestCompanies()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Error:', error);
    process.exit(1);
  });
