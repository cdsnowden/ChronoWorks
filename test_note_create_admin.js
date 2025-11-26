const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testNoteCreation() {
  try {
    console.log('=== Testing Note Creation via Admin SDK ===\n');

    // Use the known Account Manager and Company from our diagnostic
    const accountManagerId = 'i2tVFKOQdRgIGhetg2CbgNWll2W2';
    const companyId = '1sjTHFApDxS3Zhan3Rtf';

    // Create a test note directly
    const noteData = {
      companyId: companyId,
      companyName: 'TechStart Inc',
      note: 'Test note created via Admin SDK to verify permissions',
      noteType: 'interaction',
      createdBy: accountManagerId,
      createdByName: 'Christopher Snowden',
      createdByRole: 'account_manager',
      tags: ['test', 'admin_sdk'],
      sentiment: 'neutral',
      followUpRequired: false,
      followUpCompleted: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    console.log('Creating note with data:');
    console.log(JSON.stringify(noteData, null, 2));
    console.log();

    const docRef = await db.collection('customerNotes').add(noteData);

    console.log('✅ Note created successfully!');
    console.log(`   Note ID: ${docRef.id}`);
    console.log();

    // Read it back to verify
    const noteDoc = await docRef.get();
    const noteDataRead = noteDoc.data();

    console.log('✅ Note read back successfully:');
    console.log(`   Company: ${noteDataRead.companyName}`);
    console.log(`   Note: ${noteDataRead.note}`);
    console.log(`   Created By: ${noteDataRead.createdByName}`);
    console.log();

    // Now try to list all notes for this Account Manager
    const notesSnapshot = await db.collection('customerNotes')
      .where('createdBy', '==', accountManagerId)
      .get();

    console.log(`✅ Total notes by this Account Manager: ${notesSnapshot.size}`);
    notesSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${data.note.substring(0, 50)}...`);
    });

    console.log('\n=== Test Complete ===');
    console.log('The Admin SDK can create notes successfully.');
    console.log('This means the database structure is correct.');
    console.log('The issue is with the security rules or authentication in the Flutter app.\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error);
  }
}

testNoteCreation().then(() => {
  process.exit(0);
});
