/**
 * Multi-Tenant Migration Script
 *
 * This script migrates existing ChronoWorks data to the multi-tenant structure
 * by adding companyId to all existing documents.
 *
 * IMPORTANT: This script should only be run ONCE during the migration process.
 *
 * Prerequisites:
 *   1. Create a test company in the companies collection first
 *   2. Update TEST_COMPANY_ID below with the actual company ID
 *   3. Backup all Firestore data before running
 *   4. Test on a development environment first
 *
 * Usage:
 *   node scripts/migrate_to_multitenant.js
 *
 * What this script does:
 *   - Adds companyId field to all documents in existing collections
 *   - Uses batch writes for efficiency (500 documents per batch)
 *   - Provides progress updates and summary
 *   - Skips documents that already have companyId
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

// ⚠️ IMPORTANT: Update this with your actual test company ID
// Create a company document first, then copy its ID here
const TEST_COMPANY_ID = 'YOUR_TEST_COMPANY_ID_HERE';

// Collections that need to be migrated
const COLLECTIONS_TO_MIGRATE = [
  'users',
  'shifts',
  'timeEntries',
  'activeClockIns',
  'overtimeRequests',
  'breakEntries',
  'overtimeRiskNotifications',
  'missedClockOutWarnings'
];

/**
 * Migrates a single collection by adding companyId to all documents
 */
async function migrateCollection(collectionName) {
  console.log(`\n📦 Migrating collection: ${collectionName}`);

  try {
    const snapshot = await db.collection(collectionName).get();

    if (snapshot.empty) {
      console.log(`   ℹ️  Collection is empty, skipping...`);
      return { total: 0, migrated: 0, skipped: 0 };
    }

    let migratedCount = 0;
    let skippedCount = 0;
    let batchCount = 0;
    let batch = db.batch();
    const BATCH_LIMIT = 500;

    for (const doc of snapshot.docs) {
      const data = doc.data();

      // Skip if document already has companyId
      if (data.companyId) {
        skippedCount++;
        console.log(`   ⏭️  Skipped ${doc.id} (already has companyId)`);
        continue;
      }

      // Add companyId to document
      batch.update(doc.ref, { companyId: TEST_COMPANY_ID });
      migratedCount++;
      batchCount++;

      // Commit batch every 500 documents
      if (batchCount >= BATCH_LIMIT) {
        await batch.commit();
        console.log(`   ✓ Committed batch of ${batchCount} documents`);
        batch = db.batch();
        batchCount = 0;
      }
    }

    // Commit remaining documents
    if (batchCount > 0) {
      await batch.commit();
      console.log(`   ✓ Committed final batch of ${batchCount} documents`);
    }

    console.log(`   ✅ Completed: ${migratedCount} migrated, ${skippedCount} skipped`);

    return {
      total: snapshot.size,
      migrated: migratedCount,
      skipped: skippedCount
    };
  } catch (error) {
    console.error(`   ❌ Error migrating ${collectionName}:`, error);
    throw error;
  }
}

/**
 * Main migration function
 */
async function runMigration() {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║         ChronoWorks Multi-Tenant Migration Script        ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  // Validate company ID
  if (TEST_COMPANY_ID === 'YOUR_TEST_COMPANY_ID_HERE') {
    console.error('❌ ERROR: Please update TEST_COMPANY_ID in the script first!');
    console.error('   1. Create a company document in the companies collection');
    console.error('   2. Copy the company ID');
    console.error('   3. Update TEST_COMPANY_ID constant in this script');
    process.exit(1);
  }

  // Verify company exists
  console.log('🔍 Verifying test company exists...');
  const companyDoc = await db.collection('companies').doc(TEST_COMPANY_ID).get();
  if (!companyDoc.exists) {
    console.error(`❌ ERROR: Company ${TEST_COMPANY_ID} does not exist!`);
    console.error('   Create the company document first, then run this script.');
    process.exit(1);
  }

  const companyData = companyDoc.data();
  console.log(`✅ Found company: ${companyData.businessName}`);
  console.log(`   Owner: ${companyData.ownerName} (${companyData.ownerEmail})\n`);

  // Confirm migration
  console.log('⚠️  WARNING: This will add companyId to ALL existing documents.');
  console.log(`   Target Company: ${companyData.businessName} (${TEST_COMPANY_ID})\n`);
  console.log('   Press Ctrl+C to cancel, or wait 5 seconds to continue...\n');

  // Wait 5 seconds for user to cancel
  await new Promise(resolve => setTimeout(resolve, 5000));

  console.log('🚀 Starting migration...\n');

  const startTime = Date.now();
  const results = {};

  try {
    // Migrate each collection
    for (const collectionName of COLLECTIONS_TO_MIGRATE) {
      results[collectionName] = await migrateCollection(collectionName);
    }

    const endTime = Date.now();
    const duration = ((endTime - startTime) / 1000).toFixed(2);

    // Print summary
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║                    Migration Summary                      ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    let totalDocuments = 0;
    let totalMigrated = 0;
    let totalSkipped = 0;

    for (const [collection, stats] of Object.entries(results)) {
      console.log(`${collection}:`);
      console.log(`  Total: ${stats.total} | Migrated: ${stats.migrated} | Skipped: ${stats.skipped}`);
      totalDocuments += stats.total;
      totalMigrated += stats.migrated;
      totalSkipped += stats.skipped;
    }

    console.log('\n' + '─'.repeat(61));
    console.log(`Total Documents: ${totalDocuments}`);
    console.log(`Migrated: ${totalMigrated}`);
    console.log(`Skipped: ${totalSkipped}`);
    console.log(`Duration: ${duration} seconds`);
    console.log('─'.repeat(61) + '\n');

    console.log('✅ Migration completed successfully!\n');
    console.log('Next steps:');
    console.log('1. Deploy new Firestore indexes: firebase deploy --only firestore:indexes');
    console.log('2. Deploy new security rules: firebase deploy --only firestore:rules');
    console.log('3. Test data isolation with different user accounts');
    console.log('4. Update Flutter app to include companyId in all queries\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    console.error('\nPlease review the error and fix any issues before retrying.');
    console.error('You may need to restore from backup if data was partially migrated.\n');
    process.exit(1);
  }
}

// Run the migration
runMigration();
