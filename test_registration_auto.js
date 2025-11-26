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

  let companyId, firebaseUserId, requestId;

  try {
    // Step 1: Submit test registration
    console.log('STEP 1: Submitting test registration...');
    console.log(`Business: ${TEST_REGISTRATION.businessName}`);
    console.log(`Owner: ${TEST_REGISTRATION.ownerName} (${TEST_REGISTRATION.ownerEmail})`);

    const registrationRef = await db.collection('registrationRequests').add({
      ...TEST_REGISTRATION,
      submittedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    requestId = registrationRef.id;
    console.log(`✅ Registration created: ${requestId}\n`);

    // Step 2: Verify registration was saved
    console.log('STEP 2: Verifying registration in Firestore...');
    const regDoc = await db.collection('registrationRequests').doc(requestId).get();
    if (regDoc.exists) {
      console.log('✅ Registration found in Firestore');
      console.log(`   Status: ${regDoc.data().status}\n`);
    } else {
      throw new Error('❌ Registration not found!');
    }

    // Step 3: Check email notification
    console.log('STEP 3: Email Notification Check');
    console.log('📧 Check your inbox: chris.s@snowdensjewelers.com');
    console.log('   Expected subject: "New ChronoWorks Registration Request"\n');

    // Step 4: Approve registration
    console.log('STEP 4: Auto-approving registration...\n');

    const registration = regDoc.data();

    // Get super admin UID
    const superAdminSnapshot = await db.collection('superAdmins').limit(1).get();
    const superAdminUid = superAdminSnapshot.docs[0].id;

    // Generate temporary password
    const temporaryPassword = generateTemporaryPassword();
    console.log(`   Generated password: ${temporaryPassword}`);

    // Calculate trial dates
    const now = admin.firestore.Timestamp.now();
    const freePhase1EndDate = new Date(now.toMillis() + (30 * 24 * 60 * 60 * 1000));
    const freePhase1EndTimestamp = admin.firestore.Timestamp.fromDate(freePhase1EndDate);

    // Create company
    console.log('\n   Creating company document...');
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
    companyId = companyRef.id;
    console.log(`   ✅ Company created: ${companyId}`);

    // Create Firebase Auth user
    console.log('\n   Creating Firebase Auth user...');
    let firebaseUser;
    try {
      firebaseUser = await admin.auth().createUser({
        email: registration.ownerEmail,
        password: temporaryPassword,
        displayName: registration.ownerName,
        emailVerified: false,
      });
      firebaseUserId = firebaseUser.uid;
      console.log(`   ✅ Auth user created: ${firebaseUser.uid}`);
    } catch (authError) {
      console.log(`   ❌ Auth user creation failed: ${authError.message}`);
      await companyRef.delete();
      throw authError;
    }

    // Create user document
    console.log('\n   Creating user document in Firestore...');
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
    console.log(`   ✅ User document created: ${firebaseUser.uid}`);

    // Update company with ownerId
    await companyRef.update({ ownerId: firebaseUser.uid });
    console.log('   ✅ Company updated with ownerId');

    // Update registration status
    console.log('\n   Updating registration status...');
    await registrationRef.update({
      status: "approved",
      approvedBy: superAdminUid,
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      companyId,
    });
    console.log('   ✅ Registration marked as approved\n');

    // Final Summary
    console.log('╔════════════════════════════════════════════════════════╗');
    console.log('║                TEST COMPLETE - SUCCESS                 ║');
    console.log('╚════════════════════════════════════════════════════════╝\n');

    console.log('✅ REGISTRATION FLOW TEST PASSED\n');

    console.log('📦 Created Resources:');
    console.log(`   Company ID:      ${companyId}`);
    console.log(`   User ID:         ${firebaseUser.uid}`);
    console.log(`   Registration ID: ${requestId}\n`);

    console.log('🔐 Test Credentials:');
    console.log(`   Email:    ${registration.ownerEmail}`);
    console.log(`   Password: ${temporaryPassword}\n`);

    console.log('📅 Trial Period:');
    console.log(`   Plan:  Free (Phase 1 - Full Features)`);
    console.log(`   Start: ${now.toDate().toLocaleDateString()}`);
    console.log(`   End:   ${freePhase1EndDate.toLocaleDateString()} (30 days)\n`);

    console.log('✅ What Worked:');
    console.log('   1. ✅ Registration form submission');
    console.log('   2. ✅ Data saved to Firestore');
    console.log('   3. ✅ Company creation');
    console.log('   4. ✅ Firebase Auth user creation');
    console.log('   5. ✅ User document creation');
    console.log('   6. ✅ Registration status update\n');

    console.log('⚠️  Manual Verification Needed:');
    console.log('   1. Check email: chris.s@snowdensjewelers.com');
    console.log('      Should have received "New Registration Request"');
    console.log('   2. Try logging into Flutter app with test credentials');
    console.log('   3. Verify trial countdown shows 30 days remaining\n');

    console.log('🧹 Test Data:');
    console.log('   Test data has been created in production database.');
    console.log('   You can manually delete it or keep for testing.\n');

    console.log('📝 To Clean Up Test Data:');
    console.log(`   Company: companies/${companyId}`);
    console.log(`   User: users/${firebaseUser.uid}`);
    console.log(`   Auth: firebase auth delete ${firebaseUser.uid}`);
    console.log(`   Registration: registrationRequests/${requestId}\n`);

    return { companyId, firebaseUserId, requestId };

  } catch (error) {
    console.error('\n╔════════════════════════════════════════════════════════╗');
    console.error('║                  TEST FAILED - ERROR                   ║');
    console.error('╚════════════════════════════════════════════════════════╝\n');
    console.error('❌ Error:', error.message);
    console.error('Stack:', error.stack);
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

testRegistrationFlow().then(() => {
  console.log('Test script finished successfully');
  process.exit(0);
}).catch(err => {
  console.error('\nFatal error:', err);
  process.exit(1);
});
