const admin = require('firebase-admin');
const serviceAccount = require('./service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function checkShiftTemplates() {
  try {
    const templatesSnapshot = await admin.firestore()
      .collection('shiftTemplates')
      .get();

    console.log(`Found ${templatesSnapshot.size} shift templates\n`);

    templatesSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`\n=== ${data.name} ===`);
      console.log(`ID: ${doc.id}`);
      console.log(`Is Global: ${data.isGlobal}`);
      console.log(`Created By: ${data.createdBy || 'N/A'}`);
      console.log(`Company ID: ${data.companyId || 'N/A'}`);
      console.log(`Is Day Off: ${data.isDayOff}`);
      if (!data.isDayOff && data.startTime) {
        const startMin = data.startTime.minute.toString().padStart(2, '0');
        const endMin = data.endTime.minute.toString().padStart(2, '0');
        console.log(`Time: ${data.startTime.hour}:${startMin} - ${data.endTime.hour}:${endMin}`);
        console.log(`Duration: ${data.durationHours}h`);
      }
    });

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

checkShiftTemplates();
