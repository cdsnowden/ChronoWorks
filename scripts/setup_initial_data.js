/**
 * Initial Data Setup Script
 *
 * Creates:
 * 1. Super admin document for Chris
 * 2. Test company (ChronoWorks Test Company)
 *
 * Run this ONCE at the beginning of Phase 1
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

// Configuration
const SUPER_ADMIN_UID = 'Z1eL0Hz4pcdqYk1GJKbr0OWGOKv2';
const SUPER_ADMIN_EMAIL = 'chris.s@snowdensjewelers.com';
const SUPER_ADMIN_NAME = 'Chris Snowden';

async function setupInitialData() {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║         ChronoWorks Initial Data Setup                   ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  try {
    // Step 1: Create Super Admin document
    console.log('📝 Creating super admin document...');

    const superAdminData = {
      uid: SUPER_ADMIN_UID,
      email: SUPER_ADMIN_EMAIL,
      name: SUPER_ADMIN_NAME,
      role: 'super_admin',
      permissions: ['all'],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true
    };

    await db.collection('superAdmins').doc(SUPER_ADMIN_UID).set(superAdminData);
    console.log(`✅ Created super admin: ${SUPER_ADMIN_NAME} (${SUPER_ADMIN_EMAIL})\n`);

    // Step 2: Create Test Company
    console.log('🏢 Creating test company...');

    const companyRef = db.collection('companies').doc();
    const companyId = companyRef.id;

    const now = new Date();
    const trialEndDate = new Date(now.getTime() + (30 * 24 * 60 * 60 * 1000)); // 30 days

    const companyData = {
      companyId: companyId,

      // Business Information
      businessName: 'ChronoWorks Test Company',
      ownerName: SUPER_ADMIN_NAME,
      ownerEmail: SUPER_ADMIN_EMAIL,
      phone: '+1-555-123-4567',
      address: {
        street: '123 Main Street',
        city: 'Wilmington',
        state: 'NC',
        zip: '28403'
      },
      numberOfEmployees: 10,
      industry: 'Technology',
      timezone: 'America/New_York',

      // Registration & Approval
      status: 'active',
      registeredAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      approvedBy: SUPER_ADMIN_UID,

      // Trial Management
      trialStartDate: admin.firestore.FieldValue.serverTimestamp(),
      trialEndDate: admin.firestore.Timestamp.fromDate(trialEndDate),

      // Subscription
      currentPlan: 'trial',
      planStartDate: admin.firestore.FieldValue.serverTimestamp(),

      // Feature Limits
      maxEmployees: 25,

      // Metadata
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: SUPER_ADMIN_UID,
      lastLoginAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,

      // Notes
      notes: 'Initial test company for development'
    };

    await companyRef.set(companyData);
    console.log(`✅ Created test company: ChronoWorks Test Company`);
    console.log(`   Company ID: ${companyId}\n`);

    // Step 3: Update existing users with companyId
    console.log('👥 Checking for existing users to update...');

    const usersSnapshot = await db.collection('users').get();

    if (!usersSnapshot.empty) {
      const batch = db.batch();
      let updateCount = 0;

      usersSnapshot.docs.forEach(doc => {
        const userData = doc.data();
        if (!userData.companyId) {
          batch.update(doc.ref, { companyId: companyId });
          updateCount++;
        }
      });

      if (updateCount > 0) {
        await batch.commit();
        console.log(`✅ Updated ${updateCount} existing users with companyId\n`);
      } else {
        console.log(`ℹ️  No users needed updating\n`);
      }
    } else {
      console.log(`ℹ️  No existing users found\n`);
    }

    // Success summary
    console.log('╔═══════════════════════════════════════════════════════════╗');
    console.log('║                  Setup Complete!                          ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    console.log('✅ Super Admin Created:');
    console.log(`   UID: ${SUPER_ADMIN_UID}`);
    console.log(`   Email: ${SUPER_ADMIN_EMAIL}`);
    console.log(`   Name: ${SUPER_ADMIN_NAME}\n`);

    console.log('✅ Test Company Created:');
    console.log(`   Company ID: ${companyId}`);
    console.log(`   Business Name: ChronoWorks Test Company`);
    console.log(`   Owner: ${SUPER_ADMIN_NAME}`);
    console.log(`   Trial End: ${trialEndDate.toLocaleDateString()}\n`);

    console.log('📋 Next Steps:');
    console.log('1. Run: npm run seed:plans (to seed subscription plans)');
    console.log('2. Run: firebase deploy --only firestore:indexes');
    console.log('3. Run: firebase deploy --only firestore:rules\n');

    console.log(`⚠️  IMPORTANT: Save this Company ID for migration script:`);
    console.log(`   ${companyId}\n`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error during setup:', error);
    process.exit(1);
  }
}

// Run the setup
setupInitialData();
