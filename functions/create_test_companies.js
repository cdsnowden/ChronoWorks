const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

// Initialize with service account
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'chronoworks-dcfd6'
});

const firestore = admin.firestore();

async function createTestCompanies() {
  try {
    console.log('🏢 Creating test companies...\n');

    const testCompanies = [
      {
        businessName: 'Acme Corporation',
        email: 'admin@acme-corp.com',
        contactName: 'John Smith',
        phoneNumber: '(555) 123-4567',
        address: '123 Main St, New York, NY 10001',
        status: 'active',
        subscriptionPlan: 'professional',
        subscriptionStatus: 'active',
        employeeCount: 50,
        industry: 'Technology',
      },
      {
        businessName: 'Blue Sky Retail',
        email: 'contact@bluesky-retail.com',
        contactName: 'Sarah Johnson',
        phoneNumber: '(555) 234-5678',
        address: '456 Oak Ave, Los Angeles, CA 90001',
        status: 'trial',
        subscriptionPlan: 'trial',
        subscriptionStatus: 'trial',
        employeeCount: 25,
        industry: 'Retail',
      },
      {
        businessName: 'Green Valley Services',
        email: 'info@greenvalley.com',
        contactName: 'Mike Davis',
        phoneNumber: '(555) 345-6789',
        address: '789 Pine Rd, Chicago, IL 60601',
        status: 'active',
        subscriptionPlan: 'basic',
        subscriptionStatus: 'active',
        employeeCount: 15,
        industry: 'Services',
      },
      {
        businessName: 'TechStart Inc',
        email: 'hello@techstart.io',
        contactName: 'Emily Chen',
        phoneNumber: '(555) 456-7890',
        address: '321 Tech Blvd, San Francisco, CA 94102',
        status: 'trial',
        subscriptionPlan: 'trial',
        subscriptionStatus: 'trial',
        employeeCount: 10,
        industry: 'Technology',
      },
      {
        businessName: 'Sunrise Manufacturing',
        email: 'contact@sunrise-mfg.com',
        contactName: 'Robert Wilson',
        phoneNumber: '(555) 567-8901',
        address: '654 Industrial Way, Houston, TX 77001',
        status: 'active',
        subscriptionPlan: 'professional',
        subscriptionStatus: 'active',
        employeeCount: 100,
        industry: 'Manufacturing',
      }
    ];

    for (const company of testCompanies) {
      const companyRef = firestore.collection('companies').doc();

      const companyData = {
        id: companyRef.id,
        ...company,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        healthMetrics: {
          daysSinceLastLogin: Math.floor(Math.random() * 7),
          loginFrequency: Math.floor(Math.random() * 20) + 5,
          activeUsers: Math.floor(Math.random() * company.employeeCount / 2),
          featuresUsed: Math.floor(Math.random() * 5) + 3,
        }
      };

      await companyRef.set(companyData);
      console.log(`✅ Created: ${company.businessName} (${companyRef.id})`);
    }

    console.log(`\n🎉 Successfully created ${testCompanies.length} test companies!`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

createTestCompanies();
