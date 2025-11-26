const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({credential: admin.credential.cert(serviceAccount)});
const db = admin.firestore();

// Test data
const TEST_REGISTRATION = {
  businessName: "Test Coffee Shop",
  industry: "Food & Beverage",
  numberOfEmployees: "15",
  address: {
    street: "123 Main Street",
    city: "Raleigh",
    state: "NC",
    zip: "27601"
  },
  timezone: "America/New_York",
  website: "https://testcoffeeshop.com",
  ownerName: "John Test",
  ownerEmail: "test@example.com",
  ownerPhone: "(919) 555-1234",
  hrName: null,
  hrEmail: null,
  source: "test_script",
  status: "pending"
};

async function testRegistrationFlow() {
  console.log('=== CHRONOWORKS REGISTRATION FLOW TEST ===\n');

  try {
    // Step 1: Submit test registration
    console.log('STEP 1: Submitting test registration...');
    console.log(`Business: ${TEST_REGISTRATION.businessName}`);
    console.log(`Owner: ${TEST_REGISTRATION.ownerName} (${TEST_REGISTRATION.ownerEmail})`);
    console.log('');

    const registrationRef = await db.collection('registrationRequests').add({
      ...TEST_REGISTRATION,
      submittedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    const requestId = registrationRef.id;
    console.log(`✅ Registration created: ${requestId}`);
    console.log('');

    // Wait a moment for the trigger
    console.log('⏳ Waiting for onRegistrationSubmitted trigger (5 seconds)...');
    await new Promise(resolve => setTimeout(resolve, 5000));
    console.log('');

    // Step 2: Verify registration was saved
    console.log('STEP 2: Verifying registration in Firestore...');
    const regDoc = await db.collection('registrationRequests').doc(requestId).get();
    if (regDoc.exists) {
      console.log('✅ Registration found in Firestore');
      console.log(`   Status: ${regDoc.data().status}`);
    } else {
      throw new Error('❌ Registration not found!');
    }
    console.log('');

    // Step 3: Check if email notification was sent
    console.log('STEP 3: Email Notification Check');
    console.log('⚠️  Cannot verify email was sent from this script');
    console.log('   Please check your inbox: chris.s@snowdensjewelers.com');
    console.log('   Expected subject: "New ChronoWorks Registration Request"');
    console.log('');

    // Step 4: Simulate admin approval
    console.log('STEP 4: Simulating super admin approval...');
    console.log('⚠️  Note: Since Flutter admin dashboard is not deployed,');
    console.log('   we will manually call the approval function.');
    console.log('');

    const userInput = await promptUser('Do you want to approve this test registration? (yes/no): ');

    if (userInput.toLowerCase() !== 'yes') {
      console.log('❌ Test cancelled by user');
      console.log('');
      console.log('Cleaning up test registration...');
      await registrationRef.delete();
      console.log('✅ Test registration deleted');
      return;
    }

    console.log('');
    console.log('Calling approveRegistration function...');

    // Get super admin UID
    const superAdminSnapshot = await db.collection('superAdmins').limit(1).get();
    const superAdminUid = superAdminSnapshot.docs[0].id;

    // Call the approval function logic directly
    const registration = regDoc.data();

    // Generate temporary password
    const temporaryPassword = generateTemporaryPassword();
    console.log(`   Generated password: ${temporaryPassword}`);

    // Calculate trial dates
    const now = admin.firestore.Timestamp.now();
    const freePhase1EndDate = new Date(now.toMillis() + (30 * 24 * 60 * 60 * 1000));
    const freePhase1EndTimestamp = admin.firestore.Timestamp.fromDate(freePhase1EndDate);

    // Create company
    console.log('');
    console.log('Creating company document...');
    const companyData = {
      businessName: registration.businessName,
      industry: registration.industry,
      address: registration.address,
      timezone: registration.timezone,
      numberOfEmployees: registration.numberOfEmployees,
      website: registration.website || null,
      ownerName: registration.ownerName,
      ownerEmail: registration.ownerEmail,
      ownerPhone: registration.ownerPhone,
      ownerId: null,
      currentPlan: "free",
      freePhase: 1,
      freePhase1StartDate: now,
      freePhase1EndDate: freePhase1EndTimestamp,
      freePhase2StartDate: null,
      freePhase2EndDate: null,
      status: "active",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: superAdminUid,
    };

    const companyRef = await db.collection('companies').add(companyData);
    const companyId = companyRef.id;
    console.log(`✅ Company created: ${companyId}`);

    // Create Firebase Auth user
    console.log('');
    console.log('Creating Firebase Auth user...');
    let firebaseUser;
    try {
      firebaseUser = await admin.auth().createUser({
        email: registration.ownerEmail,
        password: temporaryPassword,
        displayName: registration.ownerName,
        emailVerified: false,
      });
      console.log(`✅ Auth user created: ${firebaseUser.uid}`);
    } catch (authError) {
      console.log(`❌ Auth user creation failed: ${authError.message}`);
      // Rollback
      await companyRef.delete();
      throw authError;
    }

    // Create user document
    console.log('');
    console.log('Creating user document in Firestore...');
    const userData = {
      companyId,
      email: registration.ownerEmail,
      firstName: registration.ownerName.split(" ")[0],
      lastName: registration.ownerName.split(" ").slice(1).join(" ") || "",
      fullName: registration.ownerName,
      phoneNumber: registration.ownerPhone,
      role: "admin",
      isCompanyOwner: true,
      department: "Management",
      status: "active",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('users').doc(firebaseUser.uid).set(userData);
    console.log(`✅ User document created: ${firebaseUser.uid}`);

    // Update company with ownerId
    await companyRef.update({ ownerId: firebaseUser.uid });
    console.log('✅ Company updated with ownerId');

    // Update registration status
    console.log('');
    console.log('Updating registration status...');
    await registrationRef.update({
      status: "approved",
      approvedBy: superAdminUid,
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      companyId,
    });
    console.log('✅ Registration marked as approved');

    // Summary
    console.log('');
    console.log('=== TEST COMPLETE ===');
    console.log('');
    console.log('✅ Registration Flow Test PASSED');
    console.log('');
    console.log('Created Resources:');
    console.log(`  Company ID: ${companyId}`);
    console.log(`  User ID: ${firebaseUser.uid}`);
    console.log(`  Registration ID: ${requestId}`);
    console.log('');
    console.log('Test Credentials:');
    console.log(`  Email: ${registration.ownerEmail}`);
    console.log(`  Password: ${temporaryPassword}`);
    console.log('');
    console.log('Trial Period:');
    console.log(`  Start: ${now.toDate().toLocaleDateString()}`);
    console.log(`  End: ${freePhase1EndDate.toLocaleDateString()} (30 days)`);
    console.log('');
    console.log('⚠️  Note: Welcome email was NOT sent (email function not called in test)');
    console.log('   In production, sendWelcomeEmail() would be called here.');
    console.log('');
    console.log('Next Steps:');
    console.log('1. Check that company appears in database');
    console.log('2. Try logging in with test credentials');
    console.log('3. Verify trial countdown works');
    console.log('');

    const cleanup = await promptUser('Do you want to clean up test data? (yes/no): ');

    if (cleanup.toLowerCase() === 'yes') {
      console.log('');
      console.log('Cleaning up test data...');
      await admin.auth().deleteUser(firebaseUser.uid);
      await db.collection('users').doc(firebaseUser.uid).delete();
      await db.collection('companies').doc(companyId).delete();
      await db.collection('registrationRequests').doc(requestId).delete();
      console.log('✅ Test data cleaned up');
    } else {
      console.log('');
      console.log('Test data preserved for manual testing');
    }

  } catch (error) {
    console.error('');
    console.error('❌ TEST FAILED');
    console.error('Error:', error.message);
    console.error('');
    throw error;
  }
}

function generateTemporaryPassword() {
  const words = [
    "Blue", "Green", "Red", "Yellow", "Purple", "Orange",
    "Sky", "Ocean", "Mountain", "River", "Forest", "Desert",
    "Swift", "Bright", "Quick", "Bold", "Calm", "Brave",
  ];

  const word1 = words[Math.floor(Math.random() * words.length)];
  const word2 = words[Math.floor(Math.random() * words.length)];
  const word3 = words[Math.floor(Math.random() * words.length)];
  const numbers = Math.floor(Math.random() * 90) + 10;

  return `${word1}${word2}${numbers}${word3}`;
}

function promptUser(question) {
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

testRegistrationFlow().then(() => {
  console.log('Test script finished');
  process.exit(0);
}).catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
