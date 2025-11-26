/**
 * Test Script for SendGrid Email Configuration
 *
 * This script tests if SendGrid is properly configured and can send emails.
 * Run this locally before deploying to verify your setup.
 *
 * Usage:
 *   1. Create a .env file with:
 *      SENDGRID_API_KEY=your_api_key
 *      SENDGRID_FROM_EMAIL=noreply@yourdomain.com
 *      TEST_EMAIL=your_email@example.com
 *
 *   2. Run: node test-email-config.js
 */

require('dotenv').config();
const sgMail = require('@sendgrid/mail');

async function testEmailConfiguration() {
  console.log('\n🔧 Testing SendGrid Email Configuration...\n');

  // Check environment variables
  const apiKey = process.env.SENDGRID_API_KEY;
  const fromEmail = process.env.SENDGRID_FROM_EMAIL;
  const testEmail = process.env.TEST_EMAIL;

  if (!apiKey) {
    console.error('❌ ERROR: SENDGRID_API_KEY not found in environment variables');
    console.log('   Add it to your .env file or set it with:');
    console.log('   firebase functions:config:set sendgrid.api_key="YOUR_API_KEY"\n');
    process.exit(1);
  }

  if (!fromEmail) {
    console.error('❌ ERROR: SENDGRID_FROM_EMAIL not found in environment variables');
    console.log('   Add it to your .env file or set it with:');
    console.log('   firebase functions:config:set sendgrid.from_email="noreply@yourdomain.com"\n');
    process.exit(1);
  }

  if (!testEmail) {
    console.error('❌ ERROR: TEST_EMAIL not found in environment variables');
    console.log('   Add it to your .env file: TEST_EMAIL=your_email@example.com\n');
    process.exit(1);
  }

  console.log('✅ Environment variables found:');
  console.log(`   API Key: ${apiKey.substring(0, 10)}...`);
  console.log(`   From Email: ${fromEmail}`);
  console.log(`   Test Email: ${testEmail}\n`);

  // Set API key
  sgMail.setApiKey(apiKey);

  // Prepare test email
  const msg = {
    to: testEmail,
    from: fromEmail,
    subject: 'ChronoWorks - Email Configuration Test',
    text: 'This is a test email from ChronoWorks to verify SendGrid configuration.',
    html: `
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
          .container { max-width: 600px; margin: 0 auto; padding: 20px; }
          .header { background-color: #2563eb; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
          .content { background-color: #f9fafb; padding: 30px; border: 1px solid #e5e7eb; }
          .success { background-color: #d1fae5; border-left: 4px solid #10b981; padding: 15px; margin: 20px 0; }
          .footer { text-align: center; color: #6b7280; font-size: 12px; margin-top: 20px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <h1 style="margin: 0;">✅ Email Configuration Test</h1>
          </div>
          <div class="content">
            <div class="success">
              <strong>Success!</strong> Your SendGrid configuration is working correctly.
            </div>

            <h2>Test Details</h2>
            <p><strong>From:</strong> ${fromEmail}</p>
            <p><strong>To:</strong> ${testEmail}</p>
            <p><strong>Timestamp:</strong> ${new Date().toISOString()}</p>

            <p>This confirms that:</p>
            <ul>
              <li>SendGrid API key is valid</li>
              <li>Sender email is verified</li>
              <li>Email delivery is working</li>
            </ul>

            <p><strong>Next Steps:</strong></p>
            <ol>
              <li>Deploy the Cloud Function: <code>firebase deploy --only functions:checkMissedClockOuts</code></li>
              <li>Monitor the function logs for any issues</li>
              <li>Test with actual missed clock-outs</li>
            </ol>
          </div>
          <div class="footer">
            <p>ChronoWorks Time Tracking System - Configuration Test</p>
          </div>
        </div>
      </body>
      </html>
    `,
  };

  // Send email
  console.log('📧 Sending test email...\n');

  try {
    const response = await sgMail.send(msg);

    console.log('✅ SUCCESS! Test email sent successfully!\n');
    console.log('Response Details:');
    console.log(`   Status Code: ${response[0].statusCode}`);
    console.log(`   Message ID: ${response[0].headers['x-message-id']}`);
    console.log(`\n📬 Check your inbox at: ${testEmail}\n`);
    console.log('If you don\'t see the email:');
    console.log('   1. Check your spam/junk folder');
    console.log('   2. Wait a few minutes for delivery');
    console.log('   3. Verify the sender email is verified in SendGrid\n');

    console.log('🎉 Your SendGrid configuration is ready for production!\n');
    process.exit(0);
  } catch (error) {
    console.error('❌ ERROR: Failed to send test email\n');

    if (error.response) {
      console.error('SendGrid Error Response:');
      console.error(`   Status Code: ${error.response.statusCode}`);
      console.error(`   Body: ${JSON.stringify(error.response.body, null, 2)}\n`);

      if (error.response.body.errors) {
        console.error('Common Issues:');
        error.response.body.errors.forEach((err) => {
          console.error(`   • ${err.message}`);
        });
        console.log('');
      }
    } else {
      console.error(`   ${error.message}\n`);
    }

    console.log('Troubleshooting Steps:');
    console.log('   1. Verify your API key is correct and has "Mail Send" permissions');
    console.log('   2. Verify sender email is verified in SendGrid dashboard');
    console.log('   3. Check SendGrid account status (not suspended)');
    console.log('   4. Review SendGrid documentation: https://docs.sendgrid.com/\n');

    process.exit(1);
  }
}

// Run the test
testEmailConfiguration();
