const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});
const db = admin.firestore();

async function checkAccounts() {
  console.log('=== CHRONOWORKS REGISTERED ACCOUNTS ===\n');

  // Check companies
  console.log('📊 COMPANIES:');
  const companies = await db.collection('companies').get();
  if (companies.empty) {
    console.log('  No companies found\n');
  } else {
    companies.forEach(doc => {
      const data = doc.data();
      console.log(`  - ${data.businessName || 'Unknown'}`);
      console.log(`    Company ID: ${doc.id}`);
      console.log(`    Owner: ${data.ownerName || 'N/A'} (${data.ownerEmail || 'N/A'})`);
      console.log(`    Plan: ${data.currentPlan || 'N/A'}`);
      console.log(`    Status: ${data.status || 'N/A'}`);
      console.log(`    Employees: ${data.numberOfEmployees || 'N/A'}`);
      console.log('');
    });
  }

  // Check users
  console.log('👥 USERS:');
  const users = await db.collection('users').get();
  if (users.empty) {
    console.log('  No users found\n');
  } else {
    users.forEach(doc => {
      const data = doc.data();
      const fullName = data.fullName || (data.firstName + ' ' + data.lastName) || 'Unknown';
      console.log(`  - ${fullName}`);
      console.log(`    Email: ${data.email || 'N/A'}`);
      console.log(`    Role: ${data.role || 'N/A'}`);
      console.log(`    Company ID: ${data.companyId || 'N/A'}`);
      console.log(`    Owner: ${data.isCompanyOwner ? 'Yes' : 'No'}`);
      console.log(`    Status: ${data.status || 'N/A'}`);
      console.log('');
    });
  }

  // Check registration requests
  console.log('📝 REGISTRATION REQUESTS:');
  const requests = await db.collection('registrationRequests').orderBy('submittedAt', 'desc').limit(20).get();
  if (requests.empty) {
    console.log('  No registration requests found\n');
  } else {
    requests.forEach(doc => {
      const data = doc.data();
      const status = data.status || 'pending';
      const emoji = status === 'approved' ? '✅' : status === 'rejected' ? '❌' : '⏳';
      console.log(`  ${emoji} ${data.businessName || 'Unknown'}`);
      console.log(`    Request ID: ${doc.id}`);
      console.log(`    Owner: ${data.ownerName || 'N/A'} (${data.ownerEmail || 'N/A'})`);
      console.log(`    Status: ${status}`);
      console.log(`    Submitted: ${data.submittedAt ? data.submittedAt.toDate().toLocaleString() : 'N/A'}`);
      if (status === 'approved') {
        console.log(`    Company ID: ${data.companyId || 'N/A'}`);
      }
      console.log('');
    });
  }

  // Check super admins
  console.log('🔐 SUPER ADMINS:');
  const superAdmins = await db.collection('superAdmins').get();
  if (superAdmins.empty) {
    console.log('  No super admins found\n');
  } else {
    superAdmins.forEach(doc => {
      const data = doc.data();
      console.log(`  - ${data.displayName || data.name || 'Unknown'}`);
      console.log(`    Email: ${data.email || 'N/A'}`);
      console.log(`    UID: ${doc.id}`);
      console.log('');
    });
  }

  // Summary
  console.log('=== SUMMARY ===');
  console.log(`Companies: ${companies.size}`);
  console.log(`Users: ${users.size}`);
  console.log(`Registration Requests: ${requests.size}`);
  console.log(`Super Admins: ${superAdmins.size}`);
}

checkAccounts().then(() => process.exit()).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
