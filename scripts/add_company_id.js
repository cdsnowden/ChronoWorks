/**
 * Add companyId to existing documents
 *
 * Run this to add companyId to all existing documents in your collections
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

// Your company ID from the companies collection
const COMPANY_ID = 'FnbqytlyHdRZQzsfe5oU';

// Collections that need companyId added
const COLLECTIONS = [
  'users',
  'shifts',
  'timeEntries',
  'activeClockIns',
  'overtimeRiskNotifications',
  'shiftTemplates'
];

async function addCompanyIdToCollection(collectionName) {
  console.log(`\n📦 Processing collection: ${collectionName}`);

  try {
    const snapshot = await db.collection(collectionName).get();

    if (snapshot.empty) {
      console.log(`   ℹ️  Collection is empty, skipping...`);
      return { total: 0, updated: 0, skipped: 0 };
    }

    let updatedCount = 0;
    let skippedCount = 0;
    const batch = db.batch();

    for (const doc of snapshot.docs) {
      const data = doc.data();

      // Skip if already has companyId
      if (data.companyId) {
        skippedCount++;
        continue;
      }

      // Add companyId
      batch.update(doc.ref, { companyId: COMPANY_ID });
      updatedCount++;
    }

    if (updatedCount > 0) {
      await batch.commit();
      console.log(`   ✅ Updated ${updatedCount} documents`);
    } else {
      console.log(`   ℹ️  All documents already have companyId`);
    }

    if (skippedCount > 0) {
      console.log(`   ⏭️  Skipped ${skippedCount} documents (already had companyId)`);
    }

    return {
      total: snapshot.size,
      updated: updatedCount,
      skipped: skippedCount
    };
  } catch (error) {
    console.error(`   ❌ Error updating ${collectionName}:`, error);
    throw error;
  }
}

async function main() {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║           Add CompanyId to Existing Documents            ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  console.log(`Company ID: ${COMPANY_ID}\n`);

  const results = {};

  try {
    for (const collection of COLLECTIONS) {
      results[collection] = await addCompanyIdToCollection(collection);
    }

    // Summary
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║                         Summary                           ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    let totalDocs = 0;
    let totalUpdated = 0;
    let totalSkipped = 0;

    for (const [collection, stats] of Object.entries(results)) {
      console.log(`${collection}:`);
      console.log(`  Total: ${stats.total} | Updated: ${stats.updated} | Skipped: ${stats.skipped}`);
      totalDocs += stats.total;
      totalUpdated += stats.updated;
      totalSkipped += stats.skipped;
    }

    console.log('\n' + '─'.repeat(61));
    console.log(`Total Documents: ${totalDocs}`);
    console.log(`Updated: ${totalUpdated}`);
    console.log(`Already had companyId: ${totalSkipped}`);
    console.log('─'.repeat(61) + '\n');

    console.log('✅ All documents updated successfully!\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
}

main();
