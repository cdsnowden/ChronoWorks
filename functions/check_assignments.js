const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'chronoworks-dcfd6'
});

const firestore = admin.firestore();

async function checkAssignments() {
  try {
    console.log('🔍 Checking company assignments...\n');

    const companiesSnapshot = await firestore.collection('companies').get();
    
    console.log(`Total companies: ${companiesSnapshot.size}\n`);
    
    companiesSnapshot.forEach(doc => {
      const data = doc.data();
      const businessName = data.businessName || 'Unknown';
      const hasAM = data.assignedAccountManager;
      
      if (hasAM) {
        console.log(`✅ ${businessName} -> Assigned to ${hasAM.name}`);
      } else {
        console.log(`⚪ ${businessName} -> Not assigned`);
      }
    });
    
    console.log('\n---\n');
    
    const amsSnapshot = await firestore.collection('accountManagers').get();
    console.log(`Total Account Managers: ${amsSnapshot.size}\n`);
    
    amsSnapshot.forEach(doc => {
      const data = doc.data();
      const assignedCount = data.assignedCompanies?.length || 0;
      console.log(`👤 ${data.displayName}: ${assignedCount} assigned companies`);
    });
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

checkAssignments();
