const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function viewPendingRegistrations() {
  console.log('\n=== PENDING REGISTRATIONS ===\n');

  const registrations = await admin.firestore()
    .collection('registrationRequests')
    .where('status', '==', 'pending')
    .orderBy('createdAt', 'desc')
    .get();

  if (registrations.empty) {
    console.log('No pending registrations found.');
    process.exit(0);
  }

  console.log(`Found ${registrations.size} pending registration(s):\n`);

  registrations.forEach((doc, index) => {
    const reg = doc.data();
    console.log(`[${index + 1}] Registration ID: ${doc.id}`);
    console.log(`    Company Name: ${reg.companyName || reg.businessName}`);
    console.log(`    Admin Name: ${reg.adminName}`);
    console.log(`    Admin Email: ${reg.adminEmail}`);
    console.log(`    Phone: ${reg.adminPhone || 'Not provided'}`);
    console.log(`    Website: ${reg.website || 'Not provided'}`);
    console.log(`    Industry: ${reg.industry || 'Not provided'}`);
    console.log(`    Selected Plan: ${reg.selectedPlan || 'Not specified'}`);
    console.log(`    Billing Cycle: ${reg.billingCycle || 'Not specified'}`);
    console.log(`    Status: ${reg.status}`);
    console.log(`    Created: ${reg.createdAt ? reg.createdAt.toDate().toLocaleString() : 'Unknown'}`);
    console.log('');
  });

  console.log('\n=== Next Steps ===');
  console.log('To approve this registration, you can:');
  console.log('1. Use the Flutter app Super Admin Dashboard');
  console.log('2. Or run: node approve_registration.js <registration-id>');
  console.log('\n');

  process.exit(0);
}

viewPendingRegistrations().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
