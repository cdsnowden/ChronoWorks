const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function createTestTicket() {
  try {
    // Get the first company that has an assigned account manager
    const companiesSnapshot = await db.collection('companies')
      .where('assignedAccountManager', '!=', null)
      .limit(1)
      .get();

    if (companiesSnapshot.empty) {
      console.log('No companies with assigned account managers found!');
      return;
    }

    const companyDoc = companiesSnapshot.docs[0];
    const companyData = companyDoc.data();
    const companyId = companyDoc.id;

    console.log(`Creating ticket for company: ${companyData.businessName}`);

    // Use company owner info from company data
    const userId = 'test-user-id';
    const userData = {
      displayName: companyData.ownerName || 'Test User',
      email: companyData.ownerEmail || 'test@example.com',
      role: 'company_admin'
    };

    // Create a test ticket
    const ticketData = {
      ticketNumber: `TKT-2025-${Math.random().toString(36).substr(2, 8).toUpperCase()}`,
      companyId: companyId,
      companyName: companyData.businessName,
      submittedBy: {
        userId: userId,
        name: userData.displayName || userData.firstName + ' ' + userData.lastName,
        email: userData.email,
        role: userData.role
      },
      subject: 'Need help with overtime tracking',
      description: 'We are having issues with the overtime tracking feature. Employees are reporting that their overtime hours are not being calculated correctly.',
      category: 'technical',
      priority: 'high',
      status: 'open',
      assignedTo: companyData.assignedAccountManager.id,
      assignedToName: companyData.assignedAccountManager.name,
      assignedAt: admin.firestore.FieldValue.serverTimestamp(),
      resolution: null,
      resolvedAt: null,
      resolvedBy: null,
      messages: [
        {
          messageId: Math.random().toString(36).substr(2, 9),
          from: userId,
          fromName: userData.displayName || userData.firstName + ' ' + userData.lastName,
          fromRole: userData.role,
          message: 'We are having issues with the overtime tracking feature. Employees are reporting that their overtime hours are not being calculated correctly.',
          timestamp: new Date(),
          attachments: []
        }
      ],
      tags: ['overtime', 'tracking', 'urgent'],
      escalatedToSuperAdmin: false,
      escalatedAt: null,
      internalNotes: null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      closedAt: null
    };

    const ticketRef = await db.collection('supportTickets').add(ticketData);

    console.log('✅ Test ticket created successfully!');
    console.log(`Ticket ID: ${ticketRef.id}`);
    console.log(`Ticket Number: ${ticketData.ticketNumber}`);
    console.log(`Company: ${companyData.businessName}`);
    console.log(`Assigned to: ${companyData.assignedAccountManager.name}`);
    console.log(`Status: ${ticketData.status}`);
    console.log(`Priority: ${ticketData.priority}`);

    process.exit(0);
  } catch (error) {
    console.error('Error creating test ticket:', error);
    process.exit(1);
  }
}

createTestTicket();
