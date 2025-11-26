// Run this script from the functions directory: cd functions && node ../scripts/test_sendgrid.js
const sgMail = require('@sendgrid/mail');
require('dotenv').config({ path: '.env' });

// Load SendGrid configuration
const SENDGRID_API_KEY = process.env.SENDGRID_API_KEY;
const FROM_EMAIL = process.env.SENDGRID_FROM_EMAIL || 'support@chronoworks.com';
const FROM_NAME = process.env.SENDGRID_FROM_NAME || 'ChronoWorks';
const ADMIN_EMAIL = process.env.SENDGRID_ADMIN_EMAIL || 'chris.s@snowdensjewelers.com';

console.log('\n=== SENDGRID CONFIGURATION TEST ===\n');
console.log('Configuration:');
console.log(`  API Key: ${SENDGRID_API_KEY ? `${SENDGRID_API_KEY.substring(0, 10)}...` : 'NOT SET'}`);
console.log(`  From Email: ${FROM_EMAIL}`);
console.log(`  From Name: ${FROM_NAME}`);
console.log(`  Test To: ${ADMIN_EMAIL}`);
console.log('');

if (!SENDGRID_API_KEY) {
  console.error('❌ SENDGRID_API_KEY not found in .env file');
  process.exit(1);
}

sgMail.setApiKey(SENDGRID_API_KEY);

async function testSendGrid() {
  console.log('Attempting to send test email...\n');

  const msg = {
    to: ADMIN_EMAIL,
    from: {
      email: FROM_EMAIL,
      name: FROM_NAME
    },
    subject: 'ChronoWorks SendGrid Test',
    text: 'This is a test email from ChronoWorks to verify SendGrid configuration.',
    html: `
      <div style="font-family: Arial, sans-serif; padding: 20px;">
        <h2 style="color: #4CAF50;">✅ SendGrid Test Successful!</h2>
        <p>This test email confirms that:</p>
        <ul>
          <li>SendGrid API key is valid</li>
          <li>Sender email (${FROM_EMAIL}) is verified</li>
          <li>Email delivery is working</li>
        </ul>
        <p><strong>Timestamp:</strong> ${new Date().toLocaleString()}</p>
        <hr>
        <p style="color: #666; font-size: 12px;">
          Sent from ChronoWorks Email Testing Script
        </p>
      </div>
    `
  };

  try {
    const response = await sgMail.send(msg);
    console.log('✅ SUCCESS! Email sent successfully.');
    console.log(`Status Code: ${response[0].statusCode}`);
    console.log(`\nCheck ${ADMIN_EMAIL} for the test email.`);
    console.log('\n=== SENDGRID IS WORKING CORRECTLY ===\n');
    process.exit(0);
  } catch (error) {
    console.error('❌ FAILED to send email\n');

    if (error.response) {
      console.error('Error Details:');
      console.error(`  Status Code: ${error.response.statusCode}`);
      console.error(`  Body: ${JSON.stringify(error.response.body, null, 2)}`);

      if (error.response.statusCode === 403) {
        console.error('\n⚠️  ERROR 403: FORBIDDEN');
        console.error('\nThis error means the sender email is NOT VERIFIED in SendGrid.');
        console.error('\nTo fix this, you need to verify the sender in SendGrid:');
        console.error('\n1. Go to: https://app.sendgrid.com/settings/sender_auth/senders');
        console.error('\n2. Option A - Single Sender Verification (Quick):');
        console.error(`   - Click "Create New Sender"`);
        console.error(`   - Add: ${FROM_EMAIL}`);
        console.error(`   - SendGrid will email you a verification link`);
        console.error(`   - Click the link to verify`);
        console.error('\n3. Option B - Domain Authentication (Recommended):');
        console.error('   - Go to: https://app.sendgrid.com/settings/sender_auth');
        console.error('   - Authenticate the domain: chronoworks.com');
        console.error('   - Add DNS records (CNAME, etc.) to your domain registrar');
        console.error('   - Wait for DNS propagation (can take 24-48 hours)');
        console.error('\n4. After verification, run this script again to test.');
      }
    } else {
      console.error('Error:', error.message);
    }

    console.error('\n=== TEST FAILED ===\n');
    process.exit(1);
  }
}

testSendGrid();
