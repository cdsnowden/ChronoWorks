/**
 * Test Script for Phase 3 Trial Lifecycle
 *
 * This script creates test companies with backdated trials to simulate
 * the complete 60-day lifecycle without waiting.
 *
 * Test Scenarios:
 * 1. Company 27 days into trial (3 days left) - should get warning email
 * 2. Company 30 days into trial (expired yesterday) - should transition to Free
 * 3. Company 57 days into free (3 days left) - should get warning email
 * 4. Company 60 days into free (expired yesterday) - should be locked
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  const serviceAccount = require('../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'chronoworks-dcfd6'
  });
}

const db = admin.firestore();

// Helper function to create a date X days ago
function daysAgo(days) {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return admin.firestore.Timestamp.fromDate(date);
}

// Helper function to create a date X days from now
function daysFromNow(days) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return admin.firestore.Timestamp.fromDate(date);
}

async function createTestCompanies() {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║       Phase 3 Trial Lifecycle Test Setup                 ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  const testCompanies = [
    {
      name: 'Test Co - Day 27 (Warning Due)',
      data: {
        businessName: 'Test Company - Day 27',
        ownerName: 'Trial Warning Test',
        ownerEmail: 'chris.s@snowdensjewelers.com',
        ownerPhone: '(555) 111-2222',
        currentPlan: 'trial',
        status: 'active',
        trialStartDate: daysAgo(27),
        trialEndDate: daysFromNow(3), // 3 days from now
        industry: 'Technology',
        numberOfEmployees: 25,
        address: {
          street: '123 Test St',
          city: 'New York',
          state: 'NY',
          zip: '10001'
        },
        timezone: 'America/New_York',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    },
    {
      name: 'Test Co - Day 30 (Should Transition to Free)',
      data: {
        businessName: 'Test Company - Day 30',
        ownerName: 'Trial Expired Test',
        ownerEmail: 'chris.s@snowdensjewelers.com',
        ownerPhone: '(555) 222-3333',
        currentPlan: 'trial',
        status: 'active',
        trialStartDate: daysAgo(30),
        trialEndDate: daysAgo(1), // Yesterday (expired)
        industry: 'Retail',
        numberOfEmployees: 15,
        address: {
          street: '456 Test Ave',
          city: 'Los Angeles',
          state: 'CA',
          zip: '90001'
        },
        timezone: 'America/Los_Angeles',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    },
    {
      name: 'Test Co - Day 57 Free (Lock Warning Due)',
      data: {
        businessName: 'Test Company - Day 57',
        ownerName: 'Free Warning Test',
        ownerEmail: 'chris.s@snowdensjewelers.com',
        ownerPhone: '(555) 333-4444',
        currentPlan: 'free',
        status: 'active',
        trialStartDate: daysAgo(57),
        trialEndDate: daysAgo(27),
        freeStartDate: daysAgo(27),
        freeEndDate: daysFromNow(3), // 3 days from now
        industry: 'Healthcare',
        numberOfEmployees: 8,
        address: {
          street: '789 Test Blvd',
          city: 'Chicago',
          state: 'IL',
          zip: '60601'
        },
        timezone: 'America/Chicago',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    },
    {
      name: 'Test Co - Day 60 Free (Should Lock)',
      data: {
        businessName: 'Test Company - Day 60',
        ownerName: 'Account Lock Test',
        ownerEmail: 'chris.s@snowdensjewelers.com',
        ownerPhone: '(555) 444-5555',
        currentPlan: 'free',
        status: 'active',
        trialStartDate: daysAgo(60),
        trialEndDate: daysAgo(30),
        freeStartDate: daysAgo(30),
        freeEndDate: daysAgo(1), // Yesterday (expired)
        industry: 'Construction',
        numberOfEmployees: 12,
        address: {
          street: '321 Test Rd',
          city: 'Houston',
          state: 'TX',
          zip: '77001'
        },
        timezone: 'America/Chicago',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }
    }
  ];

  console.log('Creating test companies...\n');

  const createdCompanies = [];

  for (const testCompany of testCompanies) {
    try {
      const docRef = await db.collection('companies').add(testCompany.data);
      console.log(`✓ Created: ${testCompany.name}`);
      console.log(`  Company ID: ${docRef.id}`);
      console.log(`  Owner: ${testCompany.data.ownerEmail}`);
      console.log(`  Current Plan: ${testCompany.data.currentPlan}`);

      if (testCompany.data.trialEndDate) {
        const trialEnd = testCompany.data.trialEndDate.toDate();
        console.log(`  Trial Ends: ${trialEnd.toLocaleDateString()}`);
      }

      if (testCompany.data.freeEndDate) {
        const freeEnd = testCompany.data.freeEndDate.toDate();
        console.log(`  Free Ends: ${freeEnd.toLocaleDateString()}`);
      }

      console.log('');

      createdCompanies.push({
        id: docRef.id,
        name: testCompany.name,
        data: testCompany.data
      });
    } catch (error) {
      console.error(`❌ Failed to create ${testCompany.name}:`, error.message);
    }
  }

  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║              Test Companies Created!                     ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  console.log('Summary:');
  console.log(`  Total companies created: ${createdCompanies.length}`);
  console.log('');

  console.log('Next Steps:');
  console.log('  1. Manually trigger the scheduled functions:');
  console.log('     - Check Firebase Console > Functions');
  console.log('     - Or wait until 9 AM ET tomorrow');
  console.log('');
  console.log('  2. Expected Results:');
  console.log('     - Day 27 company: Should receive trial warning email');
  console.log('     - Day 30 company: Should transition to Free + email');
  console.log('     - Day 57 company: Should receive lock warning email');
  console.log('     - Day 60 company: Should be locked + email');
  console.log('');
  console.log('  3. Check your email: chris.s@snowdensjewelers.com');
  console.log('');
  console.log('  4. Verify database changes in Firestore Console');
  console.log('');

  return createdCompanies;
}

async function cleanupTestCompanies() {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║       Cleaning Up Test Companies                         ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  const testCompaniesSnapshot = await db.collection('companies')
    .where('businessName', '>=', 'Test Company')
    .where('businessName', '<=', 'Test Company\uf8ff')
    .get();

  console.log(`Found ${testCompaniesSnapshot.size} test companies to delete\n`);

  const deletePromises = testCompaniesSnapshot.docs.map(async (doc) => {
    const data = doc.data();
    console.log(`Deleting: ${data.businessName} (${doc.id})`);
    return doc.ref.delete();
  });

  await Promise.all(deletePromises);

  console.log('\n✓ All test companies deleted');
}

// Main execution
async function main() {
  const args = process.argv.slice(2);

  if (args.includes('--cleanup')) {
    await cleanupTestCompanies();
  } else if (args.includes('--help')) {
    console.log('Phase 3 Trial Lifecycle Test Script');
    console.log('');
    console.log('Usage:');
    console.log('  node test_trial_lifecycle.js          Create test companies');
    console.log('  node test_trial_lifecycle.js --cleanup Delete test companies');
    console.log('  node test_trial_lifecycle.js --help    Show this help');
    console.log('');
  } else {
    await createTestCompanies();
  }

  process.exit(0);
}

// Run the script
main();
