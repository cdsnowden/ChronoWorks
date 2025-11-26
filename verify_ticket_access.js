const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function verifyTicketAccess() {
  try {
    // Get the Account Manager (should be you - Christopher Snowden)
    const accountManagersSnapshot = await db.collection('accountManagers')
      .where('email', '==', 'snowdens@comcast.net')
      .limit(1)
      .get();

    if (accountManagersSnapshot.empty) {
      console.log('❌ No Account Manager found with that email!');
      return;
    }

    const amDoc = accountManagersSnapshot.docs[0];
    const amData = amDoc.data();
    console.log('\n📋 Account Manager Info:');
    console.log(`ID: ${amDoc.id}`);
    console.log(`Name: ${amData.displayName}`);
    console.log(`Email: ${amData.email}`);

    // Get the test ticket
    const ticketsSnapshot = await db.collection('supportTickets')
      .where('ticketNumber', '>=', 'TKT-2025')
      .limit(1)
      .get();

    if (ticketsSnapshot.empty) {
      console.log('\n❌ No test ticket found!');
      return;
    }

    const ticketDoc = ticketsSnapshot.docs[0];
    const ticketData = ticketDoc.data();
    console.log('\n🎫 Ticket Info:');
    console.log(`Ticket Number: ${ticketData.ticketNumber}`);
    console.log(`Company ID: ${ticketData.companyId}`);
    console.log(`Assigned To: ${ticketData.assignedTo}`);
    console.log(`Assigned To Name: ${ticketData.assignedToName}`);

    // Get the company
    const companyDoc = await db.collection('companies').doc(ticketData.companyId).get();
    const companyData = companyDoc.data();
    console.log('\n🏢 Company Info:');
    console.log(`Company Name: ${companyData.businessName}`);
    console.log(`Assigned AM ID: ${companyData.assignedAccountManager?.id}`);
    console.log(`Assigned AM Name: ${companyData.assignedAccountManager?.name}`);

    // Verify access
    console.log('\n✅ Access Verification:');
    console.log(`Account Manager ID matches ticket assignedTo: ${amDoc.id === ticketData.assignedTo}`);
    console.log(`Account Manager ID matches company assignment: ${amDoc.id === companyData.assignedAccountManager?.id}`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

verifyTicketAccess();
