const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function check() {
  try {
    const ticketsSnapshot = await db.collection('supportTickets')
      .where('ticketNumber', '>=', 'TKT-2025')
      .limit(1)
      .get();

    if (!ticketsSnapshot.empty) {
      const ticketDoc = ticketsSnapshot.docs[0];
      const ticketData = ticketDoc.data();
      console.log('Ticket Number:', ticketData.ticketNumber);
      console.log('Company ID:', ticketData.companyId);
      console.log('Assigned To:', ticketData.assignedTo);

      const companyDoc = await db.collection('companies').doc(ticketData.companyId).get();
      const companyData = companyDoc.data();
      console.log('Company AM ID:', companyData.assignedAccountManager.id);
      console.log('Match with your account:', companyData.assignedAccountManager.id === 'i2tVFKOQdRgIGhetg2CbgNWll2W2');
    }

    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

check();
