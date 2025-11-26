/**
 * Email Service Module
 * Handles all email sending via SendGrid for ChronoWorks registration system
 */

const sgMail = require('@sendgrid/mail');
const {logger} = require('firebase-functions');

// Initialize SendGrid with API key from environment
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

const FROM_EMAIL = process.env.SENDGRID_FROM_EMAIL || 'support@chronoworks.com';
const FROM_NAME = process.env.SENDGRID_FROM_NAME || 'ChronoWorks';
const ADMIN_EMAIL = process.env.SENDGRID_ADMIN_EMAIL || 'chris.s@snowdensjewelers.com';

/**
 * Sends an email via SendGrid
 * @param {Object} emailData - Email configuration
 * @param {string} emailData.to - Recipient email
 * @param {string} emailData.subject - Email subject
 * @param {string} emailData.html - HTML content
 * @param {string} emailData.text - Plain text content
 * @return {Promise<boolean>} - Success status
 */
async function sendEmail({to, subject, html, text}) {
  try {
    const msg = {
      to,
      from: {
        email: FROM_EMAIL,
        name: FROM_NAME,
      },
      subject,
      html,
      text,
    };

    await sgMail.send(msg);
    logger.info(`Email sent successfully to ${to}: ${subject}`);
    return true;
  } catch (error) {
    logger.error(`Failed to send email to ${to}:`, error);
    if (error.response) {
      logger.error('SendGrid error response:', error.response.body);
    }
    throw new Error(`Email send failed: ${error.message}`);
  }
}

/**
 * Sends notification to super admin about new registration
 * @param {Object} registration - Registration request data
 * @return {Promise<boolean>} - Success status
 */
async function sendAdminNotification(registration) {
  const subject = 'New ChronoWorks Registration Request';

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          font-family: Arial, sans-serif;
          line-height: 1.6;
          color: #333;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background-color: #4a90e2;
          color: white;
          padding: 20px;
          text-align: center;
          border-radius: 8px 8px 0 0;
        }
        .content {
          background-color: #f9f9f9;
          padding: 30px;
          border: 1px solid #ddd;
          border-radius: 0 0 8px 8px;
        }
        .section {
          margin-bottom: 20px;
        }
        .section-title {
          font-weight: bold;
          color: #4a90e2;
          margin-bottom: 10px;
        }
        .info-row {
          margin: 8px 0;
        }
        .label {
          font-weight: bold;
          display: inline-block;
          width: 150px;
        }
        .button {
          display: inline-block;
          background-color: #4a90e2;
          color: white;
          padding: 12px 24px;
          text-decoration: none;
          border-radius: 4px;
          margin-top: 20px;
        }
        .footer {
          text-align: center;
          margin-top: 20px;
          color: #666;
          font-size: 12px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h2>New Registration Request</h2>
        </div>
        <div class="content">
          <p>Hello Chris,</p>
          <p>A new business has registered for ChronoWorks and is awaiting approval.</p>

          <div class="section">
            <div class="section-title">Business Information</div>
            <div class="info-row">
              <span class="label">Business Name:</span>
              <span>${registration.businessName}</span>
            </div>
            <div class="info-row">
              <span class="label">Industry:</span>
              <span>${registration.industry}</span>
            </div>
            <div class="info-row">
              <span class="label">Employees:</span>
              <span>${registration.numberOfEmployees}</span>
            </div>
            ${registration.website ? `
            <div class="info-row">
              <span class="label">Website:</span>
              <span><a href="${registration.website}" target="_blank">${registration.website}</a></span>
            </div>
            ` : ''}
          </div>

          <div class="section">
            <div class="section-title">Owner Information</div>
            <div class="info-row">
              <span class="label">Name:</span>
              <span>${registration.ownerName}</span>
            </div>
            <div class="info-row">
              <span class="label">Email:</span>
              <span><a href="mailto:${registration.ownerEmail}">${registration.ownerEmail}</a></span>
            </div>
            <div class="info-row">
              <span class="label">Phone:</span>
              <span>${registration.ownerPhone}</span>
            </div>
            ${registration.jobTitle ? `
            <div class="info-row">
              <span class="label">Job Title:</span>
              <span>${registration.jobTitle}</span>
            </div>
            ` : ''}
          </div>

          ${registration.hrName && registration.hrEmail ? `
          <div class="section">
            <div class="section-title">HR Person (Also Will Have Admin Access)</div>
            <div class="info-row">
              <span class="label">Name:</span>
              <span>${registration.hrName}</span>
            </div>
            <div class="info-row">
              <span class="label">Email:</span>
              <span><a href="mailto:${registration.hrEmail}">${registration.hrEmail}</a></span>
            </div>
          </div>
          ` : ''}

          <div class="section">
            <div class="section-title">Business Address</div>
            <div class="info-row">
              <span class="label">Street:</span>
              <span>${registration.address.street}</span>
            </div>
            <div class="info-row">
              <span class="label">City, State ZIP:</span>
              <span>${registration.address.city}, ${registration.address.state} ${registration.address.zip}</span>
            </div>
            <div class="info-row">
              <span class="label">Timezone:</span>
              <span>${registration.timezone}</span>
            </div>
          </div>

          <p style="margin-top: 30px;">
            <a href="https://chronoworks.co/admin/registration-requests" class="button">
              Review Registration Request
            </a>
          </p>
        </div>
        <div class="footer">
          <p>ChronoWorks Admin System</p>
          <p>This is an automated notification from ChronoWorks</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
New ChronoWorks Registration Request

Hello Chris,

A new business has registered for ChronoWorks:

Business Information:
- Business Name: ${registration.businessName}
- Industry: ${registration.industry}
- Employees: ${registration.numberOfEmployees}
${registration.website ? `- Website: ${registration.website}\n` : ''}

Owner Information:
- Name: ${registration.ownerName}
- Email: ${registration.ownerEmail}
- Phone: ${registration.ownerPhone}
${registration.jobTitle ? `- Job Title: ${registration.jobTitle}\n` : ''}
${registration.hrName && registration.hrEmail ? `
HR Person (Also Will Have Admin Access):
- Name: ${registration.hrName}
- Email: ${registration.hrEmail}
` : ''}
Business Address:
- ${registration.address.street}
- ${registration.address.city}, ${registration.address.state} ${registration.address.zip}
- Timezone: ${registration.timezone}

Review and approve: https://chronoworks.co/admin/registration-requests

---
ChronoWorks Admin System
  `;

  return await sendEmail({
    to: ADMIN_EMAIL,
    subject,
    html,
    text,
  });
}

/**
 * Sends welcome email to newly approved business owner
 * @param {Object} data - Owner and company information
 * @param {string} data.ownerName - Owner's full name
 * @param {string} data.ownerEmail - Owner's email
 * @param {string} data.businessName - Business name
 * @param {string} data.temporaryPassword - Temporary password
 * @param {Date} data.freePhase1EndDate - Free Plan Phase 1 expiration date
 * @return {Promise<boolean>} - Success status
 */
async function sendWelcomeEmail({ownerName, ownerEmail, businessName, temporaryPassword, freePhase1EndDate}) {
  const subject = 'Welcome to ChronoWorks! Your Free Account is Ready';

  const formattedEndDate = freePhase1EndDate.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          font-family: Arial, sans-serif;
          line-height: 1.6;
          color: #333;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background-color: #4a90e2;
          color: white;
          padding: 30px;
          text-align: center;
          border-radius: 8px 8px 0 0;
        }
        .content {
          background-color: #f9f9f9;
          padding: 30px;
          border: 1px solid #ddd;
          border-radius: 0 0 8px 8px;
        }
        .credentials-box {
          background-color: #fff;
          border: 2px solid #4a90e2;
          padding: 20px;
          margin: 20px 0;
          border-radius: 4px;
        }
        .credential-row {
          margin: 10px 0;
        }
        .label {
          font-weight: bold;
          display: inline-block;
          width: 120px;
        }
        .button {
          display: inline-block;
          background-color: #4a90e2;
          color: white;
          padding: 12px 30px;
          text-decoration: none;
          border-radius: 4px;
          margin-top: 20px;
        }
        .trial-info {
          background-color: #e8f5e9;
          border-left: 4px solid #4caf50;
          padding: 15px;
          margin: 20px 0;
        }
        .steps {
          margin: 20px 0;
        }
        .step {
          margin: 10px 0;
          padding-left: 25px;
          position: relative;
        }
        .step::before {
          content: "✓";
          position: absolute;
          left: 0;
          color: #4caf50;
          font-weight: bold;
        }
        .footer {
          text-align: center;
          margin-top: 20px;
          color: #666;
          font-size: 12px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Welcome to ChronoWorks!</h1>
          <p>Your account has been approved</p>
        </div>
        <div class="content">
          <p>Hello ${ownerName},</p>
          <p>Great news! Your registration for <strong>${businessName}</strong> has been approved, and your Free Plan Phase 1 (30 days with full functionality) has started.</p>

          <div class="credentials-box">
            <h3 style="margin-top: 0;">Your Login Details</h3>
            <div class="credential-row">
              <span class="label">Email:</span>
              <span>${ownerEmail}</span>
            </div>
            <div class="credential-row">
              <span class="label">Temporary Password:</span>
              <span><code>${temporaryPassword}</code></span>
            </div>
            <div class="credential-row">
              <span class="label">Login URL:</span>
              <span><a href="https://chronoworks.co/login">chronoworks.com/login</a></span>
            </div>
            <p style="margin-top: 15px; color: #666; font-size: 14px;">
              <strong>Important:</strong> Please change your password after your first login.
            </p>
          </div>

          <div class="trial-info">
            <h3 style="margin-top: 0;">Your Free Plan Phase 1</h3>
            <p><strong>Full access to all features for 30 days</strong></p>
            <p><strong>Phase 1 ends:</strong> ${formattedEndDate}</p>
            <p><strong>No credit card required</strong></p>
          </div>

          <h3>Getting Started:</h3>
          <div class="steps">
            <div class="step">Log in to your account</div>
            <div class="step">Add your employees</div>
            <div class="step">Create your first schedule</div>
            <div class="step">Start tracking time</div>
          </div>

          <p style="text-align: center;">
            <a href="https://chronoworks.co/login" class="button">
              Log In Now
            </a>
          </p>

          <p style="margin-top: 30px;">Need help getting started? Reply to this email or visit our help center.</p>

          <p>Best regards,<br>
          The ChronoWorks Team</p>
        </div>
        <div class="footer">
          <p>ChronoWorks - Employee Time Tracking & Scheduling</p>
          <p>support@chronoworks.com</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Welcome to ChronoWorks!

Hello ${ownerName},

Your registration for ${businessName} has been approved and your Free Plan Phase 1 (30 days with full functionality) has started.

Your Login Details:
- Email: ${ownerEmail}
- Temporary Password: ${temporaryPassword}
- Login URL: https://chronoworks.co/login

IMPORTANT: Please change your password after your first login.

Your Free Plan Phase 1:
- Full access to all features for 30 days
- Phase 1 ends: ${formattedEndDate}
- No credit card required

Getting Started:
1. Log in to your account
2. Add your employees
3. Create your first schedule
4. Start tracking time

Log in now: https://chronoworks.co/login

Need help? Reply to this email or visit our help center.

Best regards,
The ChronoWorks Team

---
ChronoWorks - Employee Time Tracking & Scheduling
support@chronoworks.com
  `;

  return await sendEmail({
    to: ownerEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends rejection email to business owner
 * @param {Object} data - Owner and rejection information
 * @param {string} data.ownerName - Owner's full name
 * @param {string} data.ownerEmail - Owner's email
 * @param {string} data.businessName - Business name
 * @param {string} data.rejectionReason - Reason for rejection
 * @return {Promise<boolean>} - Success status
 */
async function sendRejectionEmail({ownerName, ownerEmail, businessName, rejectionReason}) {
  const subject = 'ChronoWorks Registration Update';

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          font-family: Arial, sans-serif;
          line-height: 1.6;
          color: #333;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background-color: #f44336;
          color: white;
          padding: 20px;
          text-align: center;
          border-radius: 8px 8px 0 0;
        }
        .content {
          background-color: #f9f9f9;
          padding: 30px;
          border: 1px solid #ddd;
          border-radius: 0 0 8px 8px;
        }
        .reason-box {
          background-color: #fff;
          border-left: 4px solid #f44336;
          padding: 15px;
          margin: 20px 0;
        }
        .footer {
          text-align: center;
          margin-top: 20px;
          color: #666;
          font-size: 12px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h2>Registration Update</h2>
        </div>
        <div class="content">
          <p>Hello ${ownerName},</p>
          <p>Thank you for your interest in ChronoWorks for <strong>${businessName}</strong>.</p>
          <p>Unfortunately, we're unable to approve your registration at this time.</p>

          <div class="reason-box">
            <h4 style="margin-top: 0;">Reason:</h4>
            <p>${rejectionReason}</p>
          </div>

          <p>If you have questions or would like to discuss this further, please reply to this email or contact us at support@chronoworks.com.</p>

          <p>Best regards,<br>
          The ChronoWorks Team</p>
        </div>
        <div class="footer">
          <p>ChronoWorks - Employee Time Tracking & Scheduling</p>
          <p>support@chronoworks.com</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
ChronoWorks Registration Update

Hello ${ownerName},

Thank you for your interest in ChronoWorks for ${businessName}.

Unfortunately, we're unable to approve your registration at this time.

Reason:
${rejectionReason}

If you have questions or would like to discuss this further, please reply to this email or contact us at support@chronoworks.com.

Best regards,
The ChronoWorks Team

---
ChronoWorks - Employee Time Tracking & Scheduling
support@chronoworks.com
  `;

  return await sendEmail({
    to: ownerEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends Free Plan Phase 1 warning email (3 days before expiration)
 * @param {Object} data - Company and phase information
 * @param {string} data.ownerName - Owner's full name
 * @param {string} data.ownerEmail - Owner's email
 * @param {string} data.businessName - Business name
 * @param {Date} data.phase1EndDate - Phase 1 expiration date (also accepts trialEndDate for backward compatibility)
 * @param {number} data.daysLeft - Days remaining in Phase 1
 * @return {Promise<boolean>} - Success status
 */
async function sendTrialWarningEmail({ownerName, ownerEmail, businessName, phase1EndDate, trialEndDate, daysLeft, managementUrl}) {
  // Support both old (trialEndDate) and new (phase1EndDate) parameter names
  const endDate = phase1EndDate || trialEndDate;
  const subject = `Your ChronoWorks Free Plan Phase 1 Expires in ${daysLeft} Days`;

  const formattedEndDate = endDate.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          font-family: Arial, sans-serif;
          line-height: 1.6;
          color: #333;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background-color: #ff9800;
          color: white;
          padding: 30px;
          text-align: center;
          border-radius: 8px 8px 0 0;
        }
        .content {
          background-color: #f9f9f9;
          padding: 30px;
          border: 1px solid #ddd;
          border-radius: 0 0 8px 8px;
        }
        .warning-box {
          background-color: #fff3cd;
          border-left: 4px solid #ff9800;
          padding: 15px;
          margin: 20px 0;
        }
        .button {
          display: inline-block;
          background-color: #4a90e2;
          color: white;
          padding: 12px 30px;
          text-decoration: none;
          border-radius: 4px;
          margin-top: 20px;
        }
        .footer {
          text-align: center;
          margin-top: 20px;
          color: #666;
          font-size: 12px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>⏰ Free Plan Phase 1 Ending Soon</h1>
        </div>
        <div class="content">
          <p>Hello ${ownerName},</p>
          <p>Your Free Plan Phase 1 for <strong>${businessName}</strong> is ending soon.</p>

          <div class="warning-box">
            <h3 style="margin-top: 0;">Phase 1 Expires: ${formattedEndDate}</h3>
            <p><strong>${daysLeft} days remaining</strong></p>
          </div>

          <h3>What Happens Next?</h3>
          <p><strong>If you upgrade to a paid plan:</strong></p>
          <ul>
            <li>Keep all your current features</li>
            <li>No interruption in service</li>
            <li>Continue tracking time and managing schedules</li>
          </ul>

          <p><strong>If you don't upgrade:</strong></p>
          <ul>
            <li>Day 31: Transition to Free Plan Phase 2 (limited features for 30 days)</li>
            <li>Day 60: Account locked (read-only access)</li>
          </ul>

          <h3>Free Plan Phase 2 Limitations:</h3>
          <ul>
            <li>Max 10 employees</li>
            <li>Basic reporting (last 7 days only)</li>
            <li>No overtime tracking or alerts</li>
            <li>No advanced features</li>
          </ul>

          <p style="text-align: center;">
            <a href="${managementUrl || 'https://chronoworks.co/subscription-plans'}" class="button">
              View Subscription Plans
            </a>
          </p>

          <p style="margin-top: 30px;">Questions? Reply to this email or contact support.</p>

          <p>Best regards,<br>
          The ChronoWorks Team</p>
        </div>
        <div class="footer">
          <p>ChronoWorks - Employee Time Tracking & Scheduling</p>
          <p>support@chronoworks.com</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Your ChronoWorks Free Plan Phase 1 Expires in ${daysLeft} Days

Hello ${ownerName},

Your Free Plan Phase 1 for ${businessName} is ending soon.

Phase 1 Expires: ${formattedEndDate}
${daysLeft} days remaining

What Happens Next?

If you upgrade to a paid plan:
- Keep all your current features
- No interruption in service
- Continue tracking time and managing schedules

If you don't upgrade:
- Day 31: Transition to Free Plan Phase 2 (limited features for 30 days)
- Day 60: Account locked (read-only access)

Free Plan Phase 2 Limitations:
- Max 10 employees
- Basic reporting (last 7 days only)
- No overtime tracking or alerts
- No advanced features

View subscription plans: ${managementUrl || 'https://chronoworks.co/subscription-plans'}

Questions? Reply to this email or contact support.

Best regards,
The ChronoWorks Team

---
ChronoWorks - Employee Time Tracking & Scheduling
support@chronoworks.com
  `;

  return await sendEmail({
    to: ownerEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends Phase 2 transition email (Day 31 - transitioned from Phase 1 to Phase 2)
 * @param {Object} data - Company information
 * @param {string} data.ownerName - Owner's full name
 * @param {string} data.ownerEmail - Owner's email
 * @param {string} data.businessName - Business name
 * @param {Date} data.phase2EndDate - Phase 2 expiration date (also accepts freeEndDate for backward compatibility)
 * @param {string} data.managementUrl - Subscription management URL
 * @return {Promise<boolean>} - Success status
 */
async function sendTrialExpiredEmail({ownerName, ownerEmail, businessName, phase2EndDate, freeEndDate, managementUrl}) {
  // Support both old (freeEndDate) and new (phase2EndDate) parameter names
  const endDate = phase2EndDate || freeEndDate;
  const subject = 'Free Plan Phase 1 Ended - Now on Phase 2 (Limited Features)';

  const formattedEndDate = endDate.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          font-family: Arial, sans-serif;
          line-height: 1.6;
          color: #333;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background-color: #2196f3;
          color: white;
          padding: 30px;
          text-align: center;
          border-radius: 8px 8px 0 0;
        }
        .content {
          background-color: #f9f9f9;
          padding: 30px;
          border: 1px solid #ddd;
          border-radius: 0 0 8px 8px;
        }
        .info-box {
          background-color: #e3f2fd;
          border-left: 4px solid #2196f3;
          padding: 15px;
          margin: 20px 0;
        }
        .button {
          display: inline-block;
          background-color: #4a90e2;
          color: white;
          padding: 12px 30px;
          text-decoration: none;
          border-radius: 4px;
          margin-top: 20px;
        }
        .footer {
          text-align: center;
          margin-top: 20px;
          color: #666;
          font-size: 12px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Free Plan Phase 2 Active</h1>
        </div>
        <div class="content">
          <p>Hello ${ownerName},</p>
          <p>Your Free Plan Phase 1 for <strong>${businessName}</strong> has ended. Your account has been automatically transitioned to <strong>Free Plan Phase 2</strong> with limited features.</p>

          <div class="info-box">
            <h3 style="margin-top: 0;">Free Plan Phase 2 Details</h3>
            <p><strong>Duration:</strong> 30 days (until ${formattedEndDate})</p>
            <p><strong>Cost:</strong> $0</p>
          </div>

          <h3>What You Still Have:</h3>
          <ul>
            <li>✓ Schedule management</li>
            <li>✓ Clock in/out</li>
            <li>✓ Basic reporting (last 7 days)</li>
            <li>✓ Up to 10 employees</li>
          </ul>

          <h3>What You No Longer Have:</h3>
          <ul>
            <li>✗ Overtime tracking & alerts</li>
            <li>✗ GPS tracking</li>
            <li>✗ Advanced reporting</li>
            <li>✗ API access</li>
            <li>✗ Payroll integration</li>
            <li>✗ More than 10 employees</li>
          </ul>

          <h3>Important: Account Lock on ${formattedEndDate}</h3>
          <p>If you don't upgrade to a paid plan by ${formattedEndDate}, your account will be locked and you'll have read-only access to your data.</p>

          <p style="text-align: center;">
            <a href="${managementUrl || 'https://chronoworks.co/subscription-plans'}" class="button">
              Upgrade to a Paid Plan
            </a>
          </p>

          <p style="margin-top: 30px;">Need help choosing? Reply to this email and we'll help you find the right plan.</p>

          <p>Best regards,<br>
          The ChronoWorks Team</p>
        </div>
        <div class="footer">
          <p>ChronoWorks - Employee Time Tracking & Scheduling</p>
          <p>support@chronoworks.com</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Free Plan Phase 1 Ended - Now on Phase 2 (Limited Features)

Hello ${ownerName},

Your Free Plan Phase 1 for ${businessName} has ended. Your account has been automatically transitioned to Free Plan Phase 2 with limited features.

Free Plan Phase 2 Details:
- Duration: 30 days (until ${formattedEndDate})
- Cost: $0

What You Still Have:
✓ Schedule management
✓ Clock in/out
✓ Basic reporting (last 7 days)
✓ Up to 10 employees

What You No Longer Have:
✗ Overtime tracking & alerts
✗ GPS tracking
✗ Advanced reporting
✗ API access
✗ Payroll integration
✗ More than 10 employees

Important: Account Lock on ${formattedEndDate}
If you don't upgrade to a paid plan by ${formattedEndDate}, your account will be locked and you'll have read-only access to your data.

Choose a paid plan: https://chronoworks.co/subscription-plans

Need help choosing? Reply to this email.

Best regards,
The ChronoWorks Team

---
ChronoWorks - Employee Time Tracking & Scheduling
support@chronoworks.com
  `;

  return await sendEmail({
    to: ownerEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends Free Plan Phase 2 warning email (3 days before account lock)
 * @param {Object} data - Company information
 * @param {string} data.ownerName - Owner's full name
 * @param {string} data.ownerEmail - Owner's email
 * @param {string} data.businessName - Business name
 * @param {Date} data.lockDate - Account lock date
 * @param {number} data.daysLeft - Days until account lock
 * @param {string} data.managementUrl - Subscription management URL
 * @return {Promise<boolean>} - Success status
 */
async function sendFreeAccountWarningEmail({ownerName, ownerEmail, businessName, lockDate, daysLeft, managementUrl}) {
  const subject = `ChronoWorks Account Will Be Locked in ${daysLeft} Days - Phase 2 Ending`;

  const formattedLockDate = lockDate.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          font-family: Arial, sans-serif;
          line-height: 1.6;
          color: #333;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background-color: #f44336;
          color: white;
          padding: 30px;
          text-align: center;
          border-radius: 8px 8px 0 0;
        }
        .content {
          background-color: #f9f9f9;
          padding: 30px;
          border: 1px solid #ddd;
          border-radius: 0 0 8px 8px;
        }
        .warning-box {
          background-color: #ffebee;
          border-left: 4px solid #f44336;
          padding: 15px;
          margin: 20px 0;
        }
        .button {
          display: inline-block;
          background-color: #4a90e2;
          color: white;
          padding: 12px 30px;
          text-decoration: none;
          border-radius: 4px;
          margin-top: 20px;
        }
        .footer {
          text-align: center;
          margin-top: 20px;
          color: #666;
          font-size: 12px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>⚠️ Account Lock Warning</h1>
        </div>
        <div class="content">
          <p>Hello ${ownerName},</p>
          <p>This is your final warning. Your ChronoWorks account for <strong>${businessName}</strong> will be locked soon.</p>

          <div class="warning-box">
            <h3 style="margin-top: 0;">Account Lock Date: ${formattedLockDate}</h3>
            <p><strong>${daysLeft} days remaining</strong></p>
          </div>

          <h3>What Happens When Your Account Is Locked?</h3>
          <ul>
            <li>❌ Cannot clock in or clock out</li>
            <li>❌ Cannot create or edit schedules</li>
            <li>❌ Cannot add employees</li>
            <li>✓ Read-only access to existing data</li>
            <li>✓ Can export your data</li>
          </ul>

          <h3>How to Prevent Account Lock</h3>
          <p>Choose any paid plan before ${formattedLockDate} to keep your account active and unlock all features.</p>

          <p>Our most popular plan is <strong>Silver</strong> at $89.99/month:</p>
          <ul>
            <li>Up to 50 employees</li>
            <li>Overtime tracking & alerts</li>
            <li>GPS tracking</li>
            <li>Advanced reporting</li>
            <li>API access & payroll integration</li>
          </ul>

          <p style="text-align: center;">
            <a href="${managementUrl || 'https://chronoworks.co/subscription-plans'}" class="button">
              Choose a Plan Now
            </a>
          </p>

          <p style="margin-top: 30px;">Questions or need help? Reply to this email and we'll assist you.</p>

          <p>Best regards,<br>
          The ChronoWorks Team</p>
        </div>
        <div class="footer">
          <p>ChronoWorks - Employee Time Tracking & Scheduling</p>
          <p>support@chronoworks.com</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
ChronoWorks Account Will Be Locked in ${daysLeft} Days

Hello ${ownerName},

This is your final warning. Your ChronoWorks account for ${businessName} will be locked soon.

Account Lock Date: ${formattedLockDate}
${daysLeft} days remaining

What Happens When Your Account Is Locked?
❌ Cannot clock in or clock out
❌ Cannot create or edit schedules
❌ Cannot add employees
✓ Read-only access to existing data
✓ Can export your data

How to Prevent Account Lock:
Choose any paid plan before ${formattedLockDate} to keep your account active and unlock all features.

Our most popular plan is Silver at $89.99/month:
- Up to 50 employees
- Overtime tracking & alerts
- GPS tracking
- Advanced reporting
- API access & payroll integration

Choose a plan now: https://chronoworks.co/subscription-plans

Questions or need help? Reply to this email.

Best regards,
The ChronoWorks Team

---
ChronoWorks - Employee Time Tracking & Scheduling
support@chronoworks.com
  `;

  return await sendEmail({
    to: ownerEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends account locked email (Day 60)
 * @param {Object} data - Company information
 * @param {string} data.ownerName - Owner's full name
 * @param {string} data.ownerEmail - Owner's email
 * @param {string} data.businessName - Business name
 * @return {Promise<boolean>} - Success status
 */
async function sendAccountLockedEmail({ownerName, ownerEmail, businessName}) {
  const subject = 'ChronoWorks Account Locked';

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          font-family: Arial, sans-serif;
          line-height: 1.6;
          color: #333;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background-color: #757575;
          color: white;
          padding: 30px;
          text-align: center;
          border-radius: 8px 8px 0 0;
        }
        .content {
          background-color: #f9f9f9;
          padding: 30px;
          border: 1px solid #ddd;
          border-radius: 0 0 8px 8px;
        }
        .lock-box {
          background-color: #f5f5f5;
          border-left: 4px solid #757575;
          padding: 15px;
          margin: 20px 0;
        }
        .button {
          display: inline-block;
          background-color: #4a90e2;
          color: white;
          padding: 12px 30px;
          text-decoration: none;
          border-radius: 4px;
          margin-top: 20px;
        }
        .footer {
          text-align: center;
          margin-top: 20px;
          color: #666;
          font-size: 12px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🔒 Account Locked</h1>
        </div>
        <div class="content">
          <p>Hello ${ownerName},</p>
          <p>Your ChronoWorks account for <strong>${businessName}</strong> has been locked due to the expiration of your free period.</p>

          <div class="lock-box">
            <h3 style="margin-top: 0;">Current Account Status</h3>
            <p><strong>Status:</strong> Locked</p>
            <p><strong>Reason:</strong> 60-day free period expired without paid subscription</p>
          </div>

          <h3>What This Means:</h3>
          <ul>
            <li>❌ Cannot clock in or clock out</li>
            <li>❌ Cannot create or edit schedules</li>
            <li>❌ Cannot add or manage employees</li>
            <li>✓ Read-only access to your data</li>
            <li>✓ Can still export your data</li>
          </ul>

          <h3>How to Reactivate Your Account</h3>
          <p>Choose any paid subscription plan to immediately unlock your account and restore full access to all features.</p>

          <p>Your data is safe and will be waiting for you when you reactivate.</p>

          <p style="text-align: center;">
            <a href="https://chronoworks.co/subscription-plans" class="button">
              Reactivate Your Account
            </a>
          </p>

          <h3>Data Retention</h3>
          <p>Your data will be retained for 90 days from the lock date. After that, inactive accounts may be permanently deleted.</p>

          <p style="margin-top: 30px;">Have questions? Reply to this email or contact us at support@chronoworks.com.</p>

          <p>Best regards,<br>
          The ChronoWorks Team</p>
        </div>
        <div class="footer">
          <p>ChronoWorks - Employee Time Tracking & Scheduling</p>
          <p>support@chronoworks.com</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
ChronoWorks Account Locked

Hello ${ownerName},

Your ChronoWorks account for ${businessName} has been locked due to the expiration of your free period.

Current Account Status:
- Status: Locked
- Reason: 60-day free period expired without paid subscription

What This Means:
❌ Cannot clock in or clock out
❌ Cannot create or edit schedules
❌ Cannot add or manage employees
✓ Read-only access to your data
✓ Can still export your data

How to Reactivate Your Account:
Choose any paid subscription plan to immediately unlock your account and restore full access to all features.

Your data is safe and will be waiting for you when you reactivate.

Reactivate your account: https://chronoworks.co/subscription-plans

Data Retention:
Your data will be retained for 90 days from the lock date. After that, inactive accounts may be permanently deleted.

Have questions? Reply to this email or contact us at support@chronoworks.com.

Best regards,
The ChronoWorks Team

---
ChronoWorks - Employee Time Tracking & Scheduling
support@chronoworks.com
  `;

  return await sendEmail({
    to: ownerEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends urgent task alert to account manager (Phase 3B - Retention)
 * @param {Object} params - Email parameters
 * @return {Promise<boolean>} - Success status
 */
async function sendManagerUrgentTaskEmail({managerEmail, managerName, companyName, ownerName, ownerPhone, ownerEmail, riskReason, planValue, expirationDate, taskId}) {
  const subject = `🔴 URGENT: Retention Task - ${companyName}`;

  const formattedDate = expirationDate.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  const daysAway = Math.ceil((expirationDate - new Date()) / (1000 * 60 * 60 * 24));

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #d32f2f 0%, #f44336 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
        .header h1 { margin: 0; font-size: 24px; }
        .urgent-badge { background-color: #ffffff; color: #d32f2f; padding: 8px 16px; border-radius: 20px; display: inline-block; margin-top: 15px; font-weight: bold; font-size: 14px; }
        .content { background-color: #fff; padding: 30px; border: 2px solid #d32f2f; border-top: none; border-radius: 0 0 8px 8px; }
        .company-card { background-color: #fef5f5; border-left: 4px solid #d32f2f; padding: 20px; margin: 20px 0; border-radius: 4px; }
        .info-row { margin: 12px 0; }
        .label { font-weight: bold; color: #666; display: inline-block; width: 120px; }
        .value { color: #333; }
        .risk-reason { background-color: #ffebee; padding: 15px; border-radius: 8px; margin: 20px 0; color: #c62828; font-weight: bold; text-align: center; font-size: 16px; }
        .quick-actions { background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .action-title { font-weight: bold; color: #333; margin-bottom: 15px; }
        .action-button { display: inline-block; background-color: #d32f2f; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 5px; font-weight: bold; }
        .action-button:hover { background-color: #b71c1c; }
        .contact-info { background-color: #fff; padding: 15px; border: 1px solid #e0e0e0; border-radius: 8px; margin: 15px 0; }
        .footer { text-align: center; color: #666; padding: 20px; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🔴 URGENT Retention Task</h1>
          <div class="urgent-badge">IMMEDIATE ACTION REQUIRED</div>
        </div>

        <div class="content">
          <p>Hi ${managerName},</p>

          <p>A high-priority retention task has been assigned to you:</p>

          <div class="company-card">
            <h3 style="margin-top: 0; color: #d32f2f;">${companyName}</h3>
            <div class="info-row">
              <span class="label">Owner:</span>
              <span class="value">${ownerName}</span>
            </div>
            <div class="info-row">
              <span class="label">Phone:</span>
              <span class="value">${ownerPhone}</span>
            </div>
            <div class="info-row">
              <span class="label">Email:</span>
              <span class="value">${ownerEmail}</span>
            </div>
            <div class="info-row">
              <span class="label">Plan Value:</span>
              <span class="value" style="color: #2e7d32; font-weight: bold;">$${planValue}/month</span>
            </div>
            <div class="info-row">
              <span class="label">Expires:</span>
              <span class="value" style="color: #d32f2f; font-weight: bold;">${formattedDate} - ${daysAway} ${daysAway === 1 ? 'day' : 'days'} away</span>
            </div>
          </div>

          <div class="risk-reason">
            ⚠️ ${riskReason}
          </div>

          <p style="font-weight: bold; color: #d32f2f;">This customer needs immediate attention. Please contact them today.</p>

          <div class="quick-actions">
            <div class="action-title">Quick Actions:</div>
            <a href="https://chronoworks.com/dashboard/retention?task=${taskId}" class="action-button">View Task</a>
            <a href="tel:${ownerPhone}" class="action-button">📞 Call Now</a>
            <a href="mailto:${ownerEmail}" class="action-button">✉️ Email</a>
          </div>

          <div class="contact-info">
            <strong>📋 Call Script Tips:</strong>
            <ul style="margin: 10px 0;">
              <li>Acknowledge their current plan and usage</li>
              <li>Ask about their experience so far</li>
              <li>Address any concerns or questions</li>
              <li>Highlight features that match their needs</li>
              <li>Offer to help with onboarding/training</li>
            </ul>
          </div>

          <p>Log your call notes and outcome in the retention dashboard.</p>

          <p>Best regards,<br>ChronoWorks Retention System</p>
        </div>

        <div class="footer">
          This is an automated retention alert. Track your progress in the Account Manager Dashboard.
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Hi ${managerName},

URGENT: High-priority retention task assigned to you

Company: ${companyName}
Contact: ${ownerName} - ${ownerPhone}
Email: ${ownerEmail}
Risk: ${riskReason}
Plan Value: $${planValue}/month
Expires: ${formattedDate} - ${daysAway} days away

This customer needs immediate attention. Please contact them today.

View Task: https://chronoworks.com/dashboard/retention?task=${taskId}
Call: ${ownerPhone}
Email: ${ownerEmail}

Best regards,
ChronoWorks Retention System
  `;

  return await sendEmail({
    to: managerEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends daily digest to account manager (Phase 3B - Retention)
 * @param {Object} params - Email parameters
 * @return {Promise<boolean>} - Success status
 */
async function sendManagerDailyDigestEmail({managerEmail, managerName, urgent, todayTasks, overdue, followUps, totalAtRiskValue, saveRate}) {
  const today = new Date().toLocaleDateString('en-US', {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  const subject = `📊 Your Retention Tasks for ${new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}`;

  const renderTaskList = (tasks, label) => {
    if (!tasks || tasks.length === 0) return '<li style="color: #999;">None</li>';
    return tasks.map((t) => `
      <li style="margin: 8px 0;">
        <strong>${t.companyName}</strong> - ${t.riskReason}<br>
        <span style="color: #2e7d32; font-weight: bold;">$${t.planValue}/mo</span>
      </li>
    `).join('');
  };

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #1976d2 0%, #2196f3 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
        .header h1 { margin: 0; font-size: 24px; }
        .header-subtitle { margin-top: 10px; opacity: 0.9; }
        .content { background-color: #fff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 8px 8px; }
        .metrics { display: flex; justify-content: space-between; margin: 25px 0; }
        .metric-card { background: linear-gradient(135deg, #f5f5f5 0%, #e0e0e0 100%); padding: 15px; border-radius: 8px; text-align: center; flex: 1; margin: 0 8px; }
        .metric-value { font-size: 32px; font-weight: bold; color: #1976d2; }
        .metric-label { font-size: 12px; color: #666; margin-top: 5px; }
        .section { margin: 25px 0; }
        .section-title { background-color: #f5f5f5; padding: 12px; border-left: 4px solid #1976d2; font-weight: bold; margin-bottom: 15px; }
        .urgent-section { border-left-color: #d32f2f; }
        .urgent-section .section-title { background-color: #ffebee; }
        .task-list { padding-left: 20px; }
        .task-list li { margin: 10px 0; }
        .view-dashboard { display: inline-block; background-color: #1976d2; color: white; padding: 15px 30px; text-decoration: none; border-radius: 6px; margin: 20px 0; font-weight: bold; }
        .view-dashboard:hover { background-color: #1565c0; }
        .footer { text-align: center; color: #666; padding: 20px; font-size: 12px; }
        .save-rate { background: linear-gradient(135deg, #4caf50 0%, #8bc34a 100%); color: white; padding: 15px; border-radius: 8px; text-align: center; margin: 20px 0; }
        .save-rate-value { font-size: 36px; font-weight: bold; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>📊 Retention Dashboard</h1>
          <div class="header-subtitle">${today}</div>
        </div>

        <div class="content">
          <p>Hi ${managerName},</p>

          <p>Here's your retention summary for today:</p>

          <div class="metrics" style="display: block; text-align: center;">
            <div class="metric-card" style="display: inline-block; margin: 10px;">
              <div class="metric-value" style="color: #d32f2f;">${urgent.length}</div>
              <div class="metric-label">URGENT</div>
            </div>
            <div class="metric-card" style="display: inline-block; margin: 10px;">
              <div class="metric-value">${todayTasks.length}</div>
              <div class="metric-label">DUE TODAY</div>
            </div>
            <div class="metric-card" style="display: inline-block; margin: 10px;">
              <div class="metric-value" style="color: #ff9800;">${overdue.length}</div>
              <div class="metric-label">OVERDUE</div>
            </div>
          </div>

          ${urgent.length > 0 ? `
          <div class="section urgent-section">
            <div class="section-title" style="background-color: #ffebee; border-left-color: #d32f2f;">🔴 URGENT (Call Today):</div>
            <ul class="task-list">
              ${renderTaskList(urgent)}
            </ul>
          </div>
          ` : ''}

          ${todayTasks.length > 0 ? `
          <div class="section">
            <div class="section-title">📅 Due Today:</div>
            <ul class="task-list">
              ${renderTaskList(todayTasks)}
            </ul>
          </div>
          ` : ''}

          ${overdue.length > 0 ? `
          <div class="section">
            <div class="section-title" style="border-left-color: #ff9800;">⚠️ Overdue:</div>
            <ul class="task-list">
              ${renderTaskList(overdue)}
            </ul>
          </div>
          ` : ''}

          ${followUps.length > 0 ? `
          <div class="section">
            <div class="section-title" style="border-left-color: #2196f3;">🔄 Follow-Ups:</div>
            <ul class="task-list">
              ${renderTaskList(followUps)}
            </ul>
          </div>
          ` : ''}

          <div class="metrics" style="display: block; text-align: center;">
            <div class="metric-card" style="display: inline-block; margin: 10px; background: linear-gradient(135deg, #4caf50 0%, #8bc34a 100%); color: white;">
              <div class="metric-value" style="color: white;">$${totalAtRiskValue.toLocaleString()}</div>
              <div class="metric-label" style="color: white;">Total At-Risk Value</div>
            </div>
          </div>

          ${saveRate > 0 ? `
          <div class="save-rate">
            <div>Your Save Rate This Month</div>
            <div class="save-rate-value">${saveRate}%</div>
            ${saveRate >= 75 ? '<div style="margin-top: 10px;">🎉 Excellent work! Above target!</div>' : ''}
          </div>
          ` : ''}

          <div style="text-align: center;">
            <a href="https://chronoworks.com/dashboard/retention" class="view-dashboard">View Full Dashboard</a>
          </div>

          <p>Best regards,<br>ChronoWorks Retention System</p>
        </div>

        <div class="footer">
          Keep up the great work! Every conversation makes a difference.
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Hi ${managerName},

Retention Dashboard for ${today}

SUMMARY:
- Urgent: ${urgent.length}
- Due Today: ${todayTasks.length}
- Overdue: ${overdue.length}
- Follow-Ups: ${followUps.length}
- Total At-Risk Value: $${totalAtRiskValue.toLocaleString()}/month
- Your Save Rate: ${saveRate}%

${urgent.length > 0 ? `
URGENT (Call Today):
${urgent.map((t) => `• ${t.companyName} - $${t.planValue}/mo`).join('\n')}
` : ''}

View Full Dashboard: https://chronoworks.com/dashboard/retention

Best regards,
ChronoWorks Retention System
  `;

  return await sendEmail({
    to: managerEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends overdue task alert to account manager (Phase 3B - Retention)
 * @param {Object} params - Email parameters
 * @return {Promise<boolean>} - Success status
 */
async function sendManagerOverdueTaskEmail({managerEmail, managerName, companyName, ownerName, ownerPhone, riskReason, createdDate, daysOverdue, taskId}) {
  const subject = `⚠️ Overdue Retention Task - ${companyName}`;

  const formattedDate = createdDate.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #ff9800 0%, #ffb74d 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
        .header h1 { margin: 0; font-size: 24px; }
        .warning-badge { background-color: #ffffff; color: #ff9800; padding: 8px 16px; border-radius: 20px; display: inline-block; margin-top: 15px; font-weight: bold; }
        .content { background-color: #fff; padding: 30px; border: 2px solid #ff9800; border-top: none; border-radius: 0 0 8px 8px; }
        .company-card { background-color: #fff3e0; border-left: 4px solid #ff9800; padding: 20px; margin: 20px 0; border-radius: 4px; }
        .info-row { margin: 12px 0; }
        .label { font-weight: bold; color: #666; display: inline-block; width: 120px; }
        .value { color: #333; }
        .overdue-notice { background-color: #ffebee; padding: 15px; border-radius: 8px; margin: 20px 0; color: #d32f2f; font-weight: bold; text-align: center; font-size: 16px; }
        .action-button { display: inline-block; background-color: #ff9800; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 5px; font-weight: bold; }
        .action-button:hover { background-color: #f57c00; }
        .footer { text-align: center; color: #666; padding: 20px; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>⚠️ Overdue Task Alert</h1>
          <div class="warning-badge">${daysOverdue} ${daysOverdue === 1 ? 'DAY' : 'DAYS'} OVERDUE</div>
        </div>

        <div class="content">
          <p>Hi ${managerName},</p>

          <p>The following retention task is now overdue and needs your immediate attention:</p>

          <div class="company-card">
            <h3 style="margin-top: 0; color: #ff9800;">${companyName}</h3>
            <div class="info-row">
              <span class="label">Contact:</span>
              <span class="value">${ownerName}</span>
            </div>
            <div class="info-row">
              <span class="label">Phone:</span>
              <span class="value">${ownerPhone}</span>
            </div>
            <div class="info-row">
              <span class="label">Created:</span>
              <span class="value">${formattedDate} (${daysOverdue} ${daysOverdue === 1 ? 'day' : 'days'} ago)</span>
            </div>
            <div class="info-row">
              <span class="label">Risk:</span>
              <span class="value">${riskReason}</span>
            </div>
          </div>

          <div class="overdue-notice">
            ⏰ This customer is at high risk of being lost. Please contact them as soon as possible.
          </div>

          <div style="text-align: center; margin: 25px 0;">
            <a href="https://chronoworks.com/dashboard/retention?task=${taskId}" class="action-button">View Task & Contact Now</a>
          </div>

          <p>If you've already contacted this customer, please update the task status with your notes.</p>

          <p>Best regards,<br>ChronoWorks Retention System</p>
        </div>

        <div class="footer">
          Need help? Contact your team lead or check the Retention Playbook.
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Hi ${managerName},

OVERDUE TASK ALERT - ${daysOverdue} ${daysOverdue === 1 ? 'day' : 'days'} overdue

Company: ${companyName}
Contact: ${ownerName} - ${ownerPhone}
Created: ${formattedDate}
Risk: ${riskReason}

This customer is at high risk of being lost. Please contact them as soon as possible.

View Task: https://chronoworks.com/dashboard/retention?task=${taskId}

If you've already contacted this customer, please update the task status with your notes.

Best regards,
ChronoWorks Retention System
  `;

  return await sendEmail({
    to: managerEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends upgrade confirmation email (Phase 4 - Subscription Management)
 * @param {Object} params - Email parameters
 * @return {Promise<boolean>} - Success status
 */
async function sendUpgradeConfirmationEmail({toEmail, toName, companyName, planName, billingCycle, amount, nextChargeDate, proratedAmount}) {
  const subject = `Welcome to ${planName}! 🎉`;

  const formattedNextChargeDate = nextChargeDate.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  const billingCycleLabel = billingCycle === 'yearly' ? 'Annual' : 'Monthly';
  const formattedAmount = amount.toLocaleString('en-US', { style: 'currency', currency: 'USD' });
  const formattedProratedAmount = proratedAmount ? proratedAmount.toLocaleString('en-US', { style: 'currency', currency: 'USD' }) : formattedAmount;

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #4caf50 0%, #66bb6a 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
        .header h1 { margin: 0; font-size: 28px; }
        .header-subtitle { margin-top: 10px; font-size: 16px; opacity: 0.9; }
        .content { background-color: #fff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 8px 8px; }
        .success-badge { background-color: #ffffff; color: #4caf50; padding: 8px 16px; border-radius: 20px; display: inline-block; margin-top: 15px; font-weight: bold; font-size: 14px; }
        .billing-summary { background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .billing-row { display: flex; justify-content: space-between; margin: 10px 0; padding: 8px 0; }
        .billing-label { font-weight: 500; color: #666; }
        .billing-value { font-weight: bold; color: #333; }
        .billing-total { border-top: 2px solid #4caf50; padding-top: 15px; margin-top: 15px; }
        .features { background-color: #e8f5e9; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .feature-list { list-style: none; padding: 0; margin: 15px 0; }
        .feature-list li { margin: 10px 0; padding-left: 30px; position: relative; }
        .feature-list li::before { content: "✓"; position: absolute; left: 0; color: #4caf50; font-weight: bold; font-size: 18px; }
        .button { display: inline-block; background-color: #4caf50; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin: 20px 0; font-weight: bold; }
        .button:hover { background-color: #43a047; }
        .footer { text-align: center; color: #666; padding: 20px; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🎉 Welcome to ${planName}!</h1>
          <div class="header-subtitle">Your subscription has been activated</div>
          <div class="success-badge">UPGRADE SUCCESSFUL</div>
        </div>

        <div class="content">
          <p>Hello ${toName},</p>

          <p>Great news! You've successfully upgraded <strong>${companyName}</strong> to the <strong>${planName}</strong> plan. All your new features are now active and ready to use!</p>

          <div class="billing-summary">
            <h3 style="margin-top: 0; color: #4caf50;">Billing Summary</h3>
            <div class="billing-row">
              <span class="billing-label">Plan:</span>
              <span class="billing-value">${planName}</span>
            </div>
            <div class="billing-row">
              <span class="billing-label">Billing Cycle:</span>
              <span class="billing-value">${billingCycleLabel}</span>
            </div>
            ${proratedAmount && proratedAmount !== amount ? `
            <div class="billing-row">
              <span class="billing-label">Charged Today (prorated):</span>
              <span class="billing-value">${formattedProratedAmount}</span>
            </div>
            ` : `
            <div class="billing-row">
              <span class="billing-label">Charged Today:</span>
              <span class="billing-value">${formattedAmount}</span>
            </div>
            `}
            <div class="billing-row billing-total">
              <span class="billing-label">Next Charge:</span>
              <span class="billing-value">${formattedAmount} on ${formattedNextChargeDate}</span>
            </div>
          </div>

          <div class="features">
            <h3 style="margin-top: 0; color: #2e7d32;">What You Get with ${planName}:</h3>
            <ul class="feature-list">
              <li>All features from lower tiers</li>
              <li>Increased employee limit</li>
              <li>Advanced reporting and analytics</li>
              <li>Priority customer support</li>
              <li>Access to new features as they're released</li>
            </ul>
          </div>

          <div style="text-align: center;">
            <a href="https://chronoworks.com/dashboard" class="button">Go to Dashboard</a>
          </div>

          <p>If you have any questions about your new plan or need help with any features, don't hesitate to reach out. We're here to help!</p>

          <p>Thank you for choosing ChronoWorks!</p>

          <p>Best regards,<br>The ChronoWorks Team</p>
        </div>

        <div class="footer">
          <p>ChronoWorks - Employee Time Tracking & Scheduling</p>
          <p>support@chronoworks.com | https://chronoworks.com</p>
          <p><a href="https://chronoworks.co/subscription-plans" style="color: #4caf50;">Manage Subscription</a></p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Welcome to ${planName}!

Hello ${toName},

You've successfully upgraded ${companyName} to the ${planName} plan!

Billing Summary:
- Plan: ${planName}
- Billing Cycle: ${billingCycleLabel}
- Charged Today: ${formattedProratedAmount}
- Next Charge: ${formattedAmount} on ${formattedNextChargeDate}

What You Get with ${planName}:
✓ All features from lower tiers
✓ Increased employee limit
✓ Advanced reporting and analytics
✓ Priority customer support
✓ Access to new features as they're released

Go to Dashboard: https://chronoworks.com/dashboard
Manage Subscription: https://chronoworks.co/subscription-plans

Questions? Reply to this email or contact support@chronoworks.com

Best regards,
The ChronoWorks Team

---
ChronoWorks - Employee Time Tracking & Scheduling
support@chronoworks.com
  `;

  return await sendEmail({
    to: toEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends scheduled downgrade confirmation email (Phase 4 - Subscription Management)
 * @param {Object} params - Email parameters
 * @return {Promise<boolean>} - Success status
 */
async function sendDowngradeScheduledEmail({toEmail, toName, companyName, currentPlan, newPlan, currentAmount, newAmount, effectiveDate, billingCycle}) {
  const subject = 'Subscription Change Scheduled';

  const formattedEffectiveDate = effectiveDate.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
  });

  const billingCycleLabel = billingCycle === 'yearly' ? 'Annual' : 'Monthly';
  const formattedCurrentAmount = currentAmount.toLocaleString('en-US', { style: 'currency', currency: 'USD' });
  const formattedNewAmount = newAmount.toLocaleString('en-US', { style: 'currency', currency: 'USD' });
  const savings = currentAmount - newAmount;
  const formattedSavings = savings.toLocaleString('en-US', { style: 'currency', currency: 'USD' });

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #2196f3 0%, #42a5f5 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
        .header h1 { margin: 0; font-size: 24px; }
        .header-subtitle { margin-top: 10px; opacity: 0.9; }
        .content { background-color: #fff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 8px 8px; }
        .info-box { background-color: #e3f2fd; padding: 20px; border-left: 4px solid #2196f3; border-radius: 4px; margin: 20px 0; }
        .change-summary { background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .plan-row { display: flex; justify-content: space-between; align-items: center; margin: 15px 0; padding: 15px; background-color: white; border-radius: 6px; }
        .plan-name { font-weight: bold; font-size: 18px; }
        .plan-price { font-size: 20px; color: #2196f3; font-weight: bold; }
        .arrow { text-align: center; color: #666; font-size: 24px; margin: 10px 0; }
        .warning-box { background-color: #fff3e0; padding: 15px; border-left: 4px solid #ff9800; border-radius: 4px; margin: 20px 0; }
        .warning-title { color: #f57c00; font-weight: bold; margin-bottom: 10px; }
        .button { display: inline-block; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 5px; font-weight: bold; }
        .button-primary { background-color: #2196f3; color: white; }
        .button-primary:hover { background-color: #1976d2; }
        .button-secondary { background-color: #ff9800; color: white; }
        .button-secondary:hover { background-color: #f57c00; }
        .footer { text-align: center; color: #666; padding: 20px; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>Subscription Change Scheduled</h1>
          <div class="header-subtitle">Your plan will change on ${formattedEffectiveDate}</div>
        </div>

        <div class="content">
          <p>Hello ${toName},</p>

          <p>Your plan change for <strong>${companyName}</strong> has been scheduled and confirmed.</p>

          <div class="change-summary">
            <h3 style="margin-top: 0;">Change Summary:</h3>
            <div class="plan-row">
              <div>
                <div class="plan-name">${currentPlan}</div>
                <div style="color: #666; font-size: 14px;">Current Plan</div>
              </div>
              <div class="plan-price">${formattedCurrentAmount}/${billingCycle === 'yearly' ? 'year' : 'month'}</div>
            </div>
            <div class="arrow">↓</div>
            <div class="plan-row">
              <div>
                <div class="plan-name">${newPlan}</div>
                <div style="color: #666; font-size: 14px;">New Plan</div>
              </div>
              <div class="plan-price">${formattedNewAmount}/${billingCycle === 'yearly' ? 'year' : 'month'}</div>
            </div>
          </div>

          <div class="info-box">
            <h3 style="margin-top: 0;">Important Details:</h3>
            <ul style="margin: 10px 0;">
              <li><strong>Effective Date:</strong> ${formattedEffectiveDate}</li>
              <li><strong>You'll Keep ${currentPlan} Until:</strong> ${formattedEffectiveDate}</li>
              <li><strong>New ${billingCycleLabel} Cost:</strong> ${formattedNewAmount} (Save ${formattedSavings}/${billingCycle === 'yearly' ? 'year' : 'month'})</li>
              <li><strong>Billing Cycle:</strong> ${billingCycleLabel}</li>
            </ul>
          </div>

          <div class="warning-box">
            <div class="warning-title">⚠️ What Changes</div>
            <p>On ${formattedEffectiveDate}, your access to ${currentPlan} features will be adjusted to match the ${newPlan} plan. Your data will be preserved.</p>
          </div>

          <h3>Changed Your Mind?</h3>
          <p>You can cancel this downgrade anytime before ${formattedEffectiveDate}. Just visit your subscription settings.</p>

          <div style="text-align: center; margin: 25px 0;">
            <a href="https://chronoworks.co/subscription-plans" class="button button-secondary">Cancel Downgrade</a>
            <a href="https://chronoworks.com/dashboard" class="button button-primary">View Dashboard</a>
          </div>

          <p>Questions about your plan change? We're here to help! Just reply to this email.</p>

          <p>Best regards,<br>The ChronoWorks Team</p>
        </div>

        <div class="footer">
          <p>ChronoWorks - Employee Time Tracking & Scheduling</p>
          <p>support@chronoworks.com | https://chronoworks.com</p>
          <p><a href="https://chronoworks.co/subscription-plans" style="color: #2196f3;">Manage Subscription</a></p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Subscription Change Scheduled

Hello ${toName},

Your plan change for ${companyName} has been scheduled:

Current Plan: ${currentPlan} (${formattedCurrentAmount}/${billingCycle === 'yearly' ? 'year' : 'month'})
    ↓
New Plan: ${newPlan} (${formattedNewAmount}/${billingCycle === 'yearly' ? 'year' : 'month'})

Important Details:
- Effective Date: ${formattedEffectiveDate}
- You'll Keep ${currentPlan} Until: ${formattedEffectiveDate}
- New ${billingCycleLabel} Cost: ${formattedNewAmount}
- Monthly Savings: ${formattedSavings}

Changed Your Mind?
You can cancel this downgrade anytime before ${formattedEffectiveDate}.

Cancel Downgrade: https://chronoworks.co/subscription-plans
View Dashboard: https://chronoworks.com/dashboard

Questions? Reply to this email or contact support@chronoworks.com

Best regards,
The ChronoWorks Team

---
ChronoWorks - Employee Time Tracking & Scheduling
support@chronoworks.com
  `;

  return await sendEmail({
    to: toEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends subscription management link to customer (Phase 4 - Subscription Management)
 * @param {Object} params - Email parameters
 * @return {Promise<boolean>} - Success status
 */
async function sendSubscriptionManagementEmail({toEmail, toName, companyName, managementUrl, expiresInHours}) {
  const subject = 'Manage Your ChronoWorks Subscription';

  const expiryText = expiresInHours === 72 ? '72 hours (3 days)' : `${expiresInHours} hours`;

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: linear-gradient(135deg, #4a90e2 0%, #5ba3f5 100%); color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
        .header h1 { margin: 0; font-size: 26px; }
        .header-subtitle { margin-top: 10px; opacity: 0.9; font-size: 14px; }
        .content { background-color: #fff; padding: 30px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 8px 8px; }
        .info-box { background-color: #e3f2fd; padding: 20px; border-left: 4px solid #4a90e2; border-radius: 4px; margin: 25px 0; }
        .link-box { background-color: #f5f5f5; padding: 20px; border-radius: 8px; margin: 25px 0; text-align: center; }
        .link-box a { display: inline-block; background-color: #4a90e2; color: white; padding: 15px 40px; text-decoration: none; border-radius: 6px; font-weight: bold; font-size: 16px; margin: 15px 0; }
        .link-box a:hover { background-color: #3a7bc8; }
        .link-url { background-color: #fff; padding: 15px; border-radius: 6px; word-break: break-all; font-size: 13px; color: #666; margin-top: 15px; border: 1px solid #ddd; }
        .warning-box { background-color: #fff3e0; padding: 15px; border-left: 4px solid #ff9800; border-radius: 4px; margin: 20px 0; }
        .warning-title { color: #f57c00; font-weight: bold; margin-bottom: 8px; }
        .features-list { background-color: #f9f9f9; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .features-list h4 { margin-top: 0; color: #4a90e2; }
        .features-list ul { margin: 10px 0; padding-left: 20px; }
        .features-list li { margin: 8px 0; }
        .footer { text-align: center; color: #666; padding: 20px; font-size: 12px; border-top: 1px solid #e0e0e0; margin-top: 30px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>📋 Manage Your Subscription</h1>
          <div class="header-subtitle">Update your plan and features for ${companyName}</div>
        </div>

        <div class="content">
          <p>Hello ${toName},</p>

          <p>Your Account Manager has sent you a secure link to manage your <strong>${companyName}</strong> subscription.</p>

          <div class="info-box">
            <h3 style="margin-top: 0;">📌 What You Can Do:</h3>
            <ul style="margin: 10px 0; padding-left: 20px;">
              <li><strong>View</strong> your current plan and features</li>
              <li><strong>Upgrade or downgrade</strong> your subscription plan</li>
              <li><strong>Add</strong> a la carte features to customize your plan</li>
              <li><strong>Review</strong> pricing and billing details</li>
            </ul>
          </div>

          <div class="link-box">
            <p style="margin-top: 0; font-weight: bold; color: #333;">Click the button below to manage your subscription:</p>
            <a href="${managementUrl}">Manage My Subscription</a>
            <div class="link-url">
              <strong>Or copy this link:</strong><br>
              ${managementUrl}
            </div>
          </div>

          <div class="warning-box">
            <div class="warning-title">🔒 Security Notice</div>
            <p style="margin: 8px 0 0 0;">This is a secure, one-time-use link that expires in <strong>${expiryText}</strong>. Do not share this link with anyone else.</p>
          </div>

          <div class="features-list">
            <h4>Available Subscription Plans:</h4>
            <ul>
              <li><strong>Bronze</strong> - Perfect for small teams (up to 25 employees)</li>
              <li><strong>Silver</strong> - Most popular for growing businesses (up to 50 employees)</li>
              <li><strong>Gold</strong> - Advanced features for larger teams (up to 100 employees)</li>
              <li><strong>Platinum</strong> - Enterprise solution (unlimited employees)</li>
            </ul>
          </div>

          <p>If you have any questions about changing your plan or need assistance, please don't hesitate to reply to this email or contact your Account Manager directly.</p>

          <p>Best regards,<br>
          The ChronoWorks Team</p>
        </div>

        <div class="footer">
          <p>ChronoWorks - Employee Time Tracking & Scheduling</p>
          <p>support@chronoworks.com | https://chronoworks.com</p>
          <p style="margin-top: 15px; font-size: 11px; color: #999;">This email was sent because your Account Manager generated a subscription management link for your account.</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Manage Your ChronoWorks Subscription

Hello ${toName},

Your Account Manager has sent you a secure link to manage your ${companyName} subscription.

What You Can Do:
- View your current plan and features
- Upgrade or downgrade your subscription plan
- Add a la carte features to customize your plan
- Review pricing and billing details

Manage your subscription:
${managementUrl}

SECURITY NOTICE:
This is a secure, one-time-use link that expires in ${expiryText}. Do not share this link with anyone else.

Available Subscription Plans:
- Bronze - Perfect for small teams (up to 25 employees)
- Silver - Most popular for growing businesses (up to 50 employees)
- Gold - Advanced features for larger teams (up to 100 employees)
- Platinum - Enterprise solution (unlimited employees)

If you have questions about changing your plan or need assistance, please reply to this email or contact your Account Manager directly.

Best regards,
The ChronoWorks Team

---
ChronoWorks - Employee Time Tracking & Scheduling
support@chronoworks.com
  `;

  return await sendEmail({
    to: toEmail,
    subject,
    html,
    text,
  });
}

/**
 * Sends weekly schedule email to employee
 * @param {Object} data - Schedule email data
 * @param {string} data.employeeName - Employee's full name
 * @param {string} data.employeeEmail - Employee's email address
 * @param {string} data.weekStart - Week start date (formatted)
 * @param {string} data.weekEnd - Week end date (formatted)
 * @param {Array} data.shifts - Array of shift objects {day, date, startTime, endTime, hours}
 * @return {Promise<boolean>} - Success status
 */
async function sendScheduleEmail(data) {
  const {employeeName, employeeEmail, weekStart, weekEnd, shifts} = data;

  const subject = `Your Schedule for ${weekStart} - ${weekEnd}`;

  // Build shifts HTML
  let shiftsHtml = '';
  shifts.forEach(shift => {
    shiftsHtml += `
      <tr>
        <td style="padding: 12px; border-bottom: 1px solid #eee;">${shift.day}</td>
        <td style="padding: 12px; border-bottom: 1px solid #eee;">${shift.date}</td>
        <td style="padding: 12px; border-bottom: 1px solid #eee;">${shift.startTime} - ${shift.endTime}</td>
        <td style="padding: 12px; border-bottom: 1px solid #eee; text-align: right;">${shift.hours} hrs</td>
      </tr>
    `;
  });

  // Calculate total hours
  const totalHours = shifts.reduce((sum, shift) => sum + parseFloat(shift.hours), 0);

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body {
          font-family: Arial, sans-serif;
          line-height: 1.6;
          color: #333;
        }
        .container {
          max-width: 600px;
          margin: 0 auto;
          padding: 20px;
        }
        .header {
          background-color: #4a90e2;
          color: white;
          padding: 20px;
          text-align: center;
          border-radius: 8px 8px 0 0;
        }
        .content {
          background-color: #f9f9f9;
          padding: 30px;
          border: 1px solid #ddd;
          border-radius: 0 0 8px 8px;
        }
        table {
          width: 100%;
          border-collapse: collapse;
          background: white;
          margin: 20px 0;
        }
        th {
          background-color: #4a90e2;
          color: white;
          padding: 12px;
          text-align: left;
        }
        .total-row {
          background-color: #e3f2fd;
          font-weight: bold;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>📅 Your Weekly Schedule</h1>
        </div>
        <div class="content">
          <p>Hi ${employeeName},</p>
          <p>Your schedule for <strong>${weekStart} - ${weekEnd}</strong> is now available:</p>

          <table>
            <thead>
              <tr>
                <th>Day</th>
                <th>Date</th>
                <th>Shift Time</th>
                <th style="text-align: right;">Hours</th>
              </tr>
            </thead>
            <tbody>
              ${shiftsHtml}
              <tr class="total-row">
                <td colspan="3" style="padding: 12px;">Total Hours</td>
                <td style="padding: 12px; text-align: right;">${totalHours.toFixed(1)} hrs</td>
              </tr>
            </tbody>
          </table>

          <p style="margin-top: 20px;">If you have any questions about your schedule, please contact your manager.</p>

          <p style="margin-top: 30px; color: #666; font-size: 12px;">
            This email was sent automatically by ChronoWorks. Please do not reply to this email.
          </p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `
Your Schedule for ${weekStart} - ${weekEnd}

Hi ${employeeName},

Your schedule for the week is now available:

${shifts.map(s => `${s.day}, ${s.date}: ${s.startTime} - ${s.endTime} (${s.hours} hrs)`).join('\n')}

Total Hours: ${totalHours.toFixed(1)} hrs

If you have any questions about your schedule, please contact your manager.
  `.trim();

  return await sendEmail({
    to: employeeEmail,
    subject,
    html,
    text,
  });
}

/**
 * Send off-premises clock-in alert to admins
 */
async function sendOffPremisesAlert(data) {
  const {adminName, adminEmail, employeeName, employeeEmail, clockInTime, distance, locationUrl} = data;

  const subject = `⚠️ Off-Premises Clock-In Alert: ${employeeName}`;

  const html = `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #f97316 0%, #ea580c 100%);
              color: white; padding: 30px; text-align: center; border-radius: 8px 8px 0 0; }
    .content { background: #ffffff; padding: 30px; border: 1px solid #e5e7eb;
               border-top: none; border-radius: 0 0 8px 8px; }
    .alert-box { background: #fef2f2; border-left: 4px solid #ef4444;
                 padding: 15px; margin: 20px 0; border-radius: 4px; }
    .detail-row { margin: 12px 0; padding: 10px; background: #f9fafb; border-radius: 4px; }
    .detail-label { font-weight: bold; color: #6b7280; display: inline-block; width: 120px; }
    .button { display: inline-block; padding: 12px 24px; background: #3b82f6;
              color: white; text-decoration: none; border-radius: 6px;
              font-weight: bold; margin-top: 20px; }
    .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #e5e7eb;
              text-align: center; color: #6b7280; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0; font-size: 28px;">⚠️ Off-Premises Clock-In Alert</h1>
    </div>

    <div class="content">
      <p>Hi ${adminName},</p>

      <div class="alert-box">
        <strong>🚨 Geofence Violation Detected</strong>
        <p style="margin: 8px 0 0 0;">An employee has clocked in outside the designated work location.</p>
      </div>

      <h3 style="color: #1f2937; margin-top: 25px;">Clock-In Details</h3>

      <div class="detail-row">
        <span class="detail-label">Employee:</span>
        <span>${employeeName}</span>
      </div>

      <div class="detail-row">
        <span class="detail-label">Email:</span>
        <span>${employeeEmail}</span>
      </div>

      <div class="detail-row">
        <span class="detail-label">Time:</span>
        <span>${clockInTime}</span>
      </div>

      <div class="detail-row">
        <span class="detail-label">Distance:</span>
        <span style="color: #ef4444; font-weight: bold;">${distance} from work location</span>
      </div>

      ${locationUrl ? `
      <div style="text-align: center;">
        <a href="${locationUrl}" class="button" target="_blank">
          📍 View Location on Map
        </a>
      </div>
      ` : ''}

      <div style="margin-top: 25px; padding: 15px; background: #eff6ff; border-radius: 6px;">
        <p style="margin: 0; font-size: 14px; color: #1e40af;">
          <strong>ℹ️ What to do:</strong> Please review this clock-in and follow up with the employee
          if necessary. The employee was able to clock in, but this alert has been generated for your awareness.
        </p>
      </div>

      <div class="footer">
        <p>This is an automated alert from ChronoWorks.</p>
        <p style="margin-top: 10px;">
          <a href="https://chronoworks-dcfd6.web.app" style="color: #3b82f6;">View Dashboard</a>
        </p>
      </div>
    </div>
  </div>
</body>
</html>
  `.trim();

  const text = `
OFF-PREMISES CLOCK-IN ALERT

Hi ${adminName},

An employee has clocked in outside the designated work location.

DETAILS:
Employee: ${employeeName}
Email: ${employeeEmail}
Time: ${clockInTime}
Distance: ${distance} from work location

${locationUrl ? `View Location: ${locationUrl}` : ''}

Please review this clock-in and follow up with the employee if necessary.

---
This is an automated alert from ChronoWorks.
  `.trim();

  return await sendEmail({
    to: adminEmail,
    subject,
    html,
    text,
  });
}

/**
 * Send welcome email to new employee
 */
async function sendEmployeeWelcomeEmail(data) {
  const {employeeName, employeeEmail, companyName, temporaryPassword, appUrl} = data;

  const subject = `Welcome to ${companyName} - Get Started with ChronoWorks!`;

  const html = `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .header h1 { margin: 0; font-size: 28px; }
    .content { background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; }
    .welcome-box { background: #f0f4ff; border-left: 4px solid #667eea;
                   padding: 15px; margin: 20px 0; border-radius: 4px; }
    .credentials { background: #fff9e6; border: 2px solid #ffd700;
                   padding: 15px; margin: 20px 0; border-radius: 4px; }
    .credentials strong { color: #d97706; }
    .button { display: inline-block; padding: 14px 28px; background: #667eea;
              color: white; text-decoration: none; border-radius: 6px; font-weight: bold;
              margin: 20px 0; }
    .button:hover { background: #5568d3; }
    .checklist { background: #f9fafb; padding: 20px; margin: 20px 0; border-radius: 4px; }
    .checklist li { margin: 10px 0; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 14px; }
    .highlight { background: #fef3c7; padding: 2px 6px; border-radius: 3px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Welcome to ${companyName}!</h1>
      <p style="margin: 10px 0 0 0; font-size: 16px;">Let's get you started with ChronoWorks</p>
    </div>

    <div class="content">
      <p>Hi ${employeeName},</p>

      <div class="welcome-box">
        <strong>🎉 Your account has been created!</strong>
        <p style="margin: 10px 0 0 0;">You've been added to the ${companyName} team. We're excited to have you on board!</p>
      </div>

      <h2 style="color: #667eea;">Your Login Credentials</h2>
      <div class="credentials">
        <p style="margin-top: 0;"><strong>📧 Email:</strong> ${employeeEmail}</p>
        <p><strong>🔐 Temporary Password:</strong> <span class="highlight">${temporaryPassword}</span></p>
        <p style="margin-bottom: 0; font-size: 14px; color: #d97706;">⚠️ You'll be prompted to change this password on your first login.</p>
      </div>

      <div style="text-align: center;">
        <a href="${appUrl || 'https://chronoworks-dcfd6.web.app'}" class="button">
          🚀 Log In to ChronoWorks
        </a>
      </div>

      <h2 style="color: #667eea; margin-top: 30px;">Next Steps - Complete Your Profile</h2>
      <div class="checklist">
        <p style="margin-top: 0;"><strong>After logging in, please complete your profile with:</strong></p>
        <ul>
          <li>✅ Home address</li>
          <li>✅ Phone number (if not already provided)</li>
          <li>✅ Date of birth</li>
          <li>✅ Update your password to something secure and memorable</li>
        </ul>
        <p style="margin-bottom: 0; font-size: 14px; color: #666;">
          <em>Having a complete profile helps us serve you better and ensures accurate payroll processing.</em>
        </p>
      </div>

      <h2 style="color: #667eea;">What You Can Do in ChronoWorks</h2>
      <ul>
        <li>⏰ <strong>Clock In/Out</strong> - Track your work hours easily</li>
        <li>📅 <strong>View Your Schedule</strong> - See your upcoming shifts</li>
        <li>📊 <strong>Track Your Time</strong> - Review your work history and hours</li>
        <li>👤 <strong>Manage Your Profile</strong> - Keep your information up to date</li>
      </ul>

      <p style="margin-top: 30px;">If you have any questions or need assistance, please reach out to your manager or administrator.</p>

      <p style="margin-top: 20px;">Welcome aboard!</p>
      <p style="margin-top: 5px;"><strong>The ${companyName} Team</strong></p>
    </div>

    <div class="footer">
      <p>This is an automated message from ChronoWorks</p>
      <p style="font-size: 12px; color: #999;">Powered by ChronoWorks Time Tracking System</p>
    </div>
  </div>
</body>
</html>
  `;

  const text = `
Welcome to ${companyName}!

Hi ${employeeName},

Your account has been created! You've been added to the ${companyName} team.

LOGIN CREDENTIALS:
Email: ${employeeEmail}
Temporary Password: ${temporaryPassword}

⚠️ You'll be prompted to change this password on your first login.

Log in at: ${appUrl || 'https://chronoworks-dcfd6.web.app'}

NEXT STEPS - Complete Your Profile:
After logging in, please complete your profile with:
- Home address
- Phone number (if not already provided)
- Date of birth
- Update your password to something secure and memorable

WHAT YOU CAN DO IN CHRONOWORKS:
- ⏰ Clock In/Out - Track your work hours easily
- 📅 View Your Schedule - See your upcoming shifts
- 📊 Track Your Time - Review your work history and hours
- 👤 Manage Your Profile - Keep your information up to date

If you have any questions or need assistance, please reach out to your manager or administrator.

Welcome aboard!
The ${companyName} Team
  `;

  return await sendEmail({
    to: employeeEmail,
    subject,
    html,
    text,
  });
}

/**
 * Send email to employee when their time-off request is approved
 */
async function sendTimeOffApprovedEmail(data) {
  const {employeeName, employeeEmail, companyName, startDate, endDate, type, reviewerName, reviewNotes, appUrl} = data;

  const subject = `Time-Off Request Approved - ${companyName}`;

  const html = `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #10b981 0%, #059669 100%);
              color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .header h1 { margin: 0; font-size: 28px; }
    .content { background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; }
    .approved-box { background: #d1fae5; border-left: 4px solid #10b981;
                   padding: 15px; margin: 20px 0; border-radius: 4px; }
    .details-box { background: #f9fafb; padding: 20px; margin: 20px 0; border-radius: 4px; }
    .button { display: inline-block; padding: 14px 28px; background: #10b981;
              color: white; text-decoration: none; border-radius: 6px; font-weight: bold;
              margin: 20px 0; }
    .button:hover { background: #059669; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>✓ Time-Off Request Approved</h1>
      <p style="margin: 10px 0 0 0; font-size: 16px;">${companyName}</p>
    </div>

    <div class="content">
      <p>Hi ${employeeName},</p>

      <div class="approved-box">
        <strong>✓ Great news! Your time-off request has been approved.</strong>
      </div>

      <h2 style="color: #10b981;">Request Details</h2>
      <div class="details-box">
        <p style="margin-top: 0;"><strong>Type:</strong> ${type}</p>
        <p><strong>Start Date:</strong> ${startDate}</p>
        <p><strong>End Date:</strong> ${endDate}</p>
        <p style="margin-bottom: 0;"><strong>Approved By:</strong> ${reviewerName}</p>
        ${reviewNotes ? `
        <hr style="margin: 15px 0; border: none; border-top: 1px solid #e0e0e0;">
        <p style="margin-bottom: 0;"><strong>Notes:</strong><br>${reviewNotes}</p>
        ` : ''}
      </div>

      <p>Your time off is now confirmed. Please make sure to complete any necessary handoffs before your time away.</p>

      <div style="text-align: center;">
        <a href="${appUrl || 'https://chronoworks-dcfd6.web.app'}" class="button">
          View in ChronoWorks
        </a>
      </div>

      <p style="margin-top: 30px;">Enjoy your time off!</p>
      <p style="margin-top: 5px;"><strong>The ${companyName} Team</strong></p>
    </div>

    <div class="footer">
      <p>This is an automated message from ChronoWorks</p>
      <p style="font-size: 12px; color: #999;">Powered by ChronoWorks Time Tracking System</p>
    </div>
  </div>
</body>
</html>
  `;

  const text = `
Time-Off Request Approved

Hi ${employeeName},

Great news! Your time-off request has been approved.

REQUEST DETAILS:
Type: ${type}
Start Date: ${startDate}
End Date: ${endDate}
Approved By: ${reviewerName}
${reviewNotes ? `Notes: ${reviewNotes}` : ''}

Your time off is now confirmed. Please make sure to complete any necessary handoffs before your time away.

View in ChronoWorks: ${appUrl || 'https://chronoworks-dcfd6.web.app'}

Enjoy your time off!
The ${companyName} Team
  `;

  return await sendEmail({
    to: employeeEmail,
    subject,
    html,
    text,
  });
}

/**
 * Send email to employee when their time-off request is denied
 */
async function sendTimeOffDeniedEmail(data) {
  const {employeeName, employeeEmail, companyName, startDate, endDate, type, reviewerName, reviewNotes, appUrl} = data;

  const subject = `Time-Off Request Update - ${companyName}`;

  const html = `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #f59e0b 0%, #d97706 100%);
              color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .header h1 { margin: 0; font-size: 28px; }
    .content { background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; }
    .denied-box { background: #fef3c7; border-left: 4px solid #f59e0b;
                   padding: 15px; margin: 20px 0; border-radius: 4px; }
    .details-box { background: #f9fafb; padding: 20px; margin: 20px 0; border-radius: 4px; }
    .reason-box { background: #fff7ed; padding: 15px; margin: 20px 0; border-radius: 4px;
                  border: 1px solid #fed7aa; }
    .button { display: inline-block; padding: 14px 28px; background: #667eea;
              color: white; text-decoration: none; border-radius: 6px; font-weight: bold;
              margin: 20px 0; }
    .button:hover { background: #5568d3; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Time-Off Request Update</h1>
      <p style="margin: 10px 0 0 0; font-size: 16px;">${companyName}</p>
    </div>

    <div class="content">
      <p>Hi ${employeeName},</p>

      <div class="denied-box">
        <strong>We're unable to approve your time-off request at this time.</strong>
      </div>

      <h2 style="color: #f59e0b;">Request Details</h2>
      <div class="details-box">
        <p style="margin-top: 0;"><strong>Type:</strong> ${type}</p>
        <p><strong>Requested Dates:</strong> ${startDate} - ${endDate}</p>
        <p style="margin-bottom: 0;"><strong>Reviewed By:</strong> ${reviewerName}</p>
      </div>

      ${reviewNotes ? `
      <h3 style="color: #d97706;">Reason</h3>
      <div class="reason-box">
        <p style="margin: 0;">${reviewNotes}</p>
      </div>
      ` : ''}

      <p>If you have questions about this decision or would like to discuss alternative dates, please reach out to your manager or ${reviewerName}.</p>

      <div style="text-align: center;">
        <a href="${appUrl || 'https://chronoworks-dcfd6.web.app'}" class="button">
          View in ChronoWorks
        </a>
      </div>

      <p style="margin-top: 30px;">Thank you for your understanding.</p>
      <p style="margin-top: 5px;"><strong>The ${companyName} Team</strong></p>
    </div>

    <div class="footer">
      <p>This is an automated message from ChronoWorks</p>
      <p style="font-size: 12px; color: #999;">Powered by ChronoWorks Time Tracking System</p>
    </div>
  </div>
</body>
</html>
  `;

  const text = `
Time-Off Request Update

Hi ${employeeName},

We're unable to approve your time-off request at this time.

REQUEST DETAILS:
Type: ${type}
Requested Dates: ${startDate} - ${endDate}
Reviewed By: ${reviewerName}

${reviewNotes ? `REASON:\n${reviewNotes}` : ''}

If you have questions about this decision or would like to discuss alternative dates, please reach out to your manager or ${reviewerName}.

View in ChronoWorks: ${appUrl || 'https://chronoworks-dcfd6.web.app'}

Thank you for your understanding.
The ${companyName} Team
  `;

  return await sendEmail({
    to: employeeEmail,
    subject,
    html,
    text,
  });
}

/**
 * Send email to manager/admin when a new time-off request is submitted
 */
async function sendTimeOffRequestSubmittedEmail(data) {
  const {managerName, managerEmail, employeeName, companyName, startDate, endDate, type, reason, daysRequested, hasConflicts, conflictCount, appUrl} = data;

  const subject = `New Time-Off Request from ${employeeName} - ${companyName}`;

  const html = `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              color: white; padding: 30px 20px; text-align: center; border-radius: 8px 8px 0 0; }
    .header h1 { margin: 0; font-size: 28px; }
    .content { background: #ffffff; padding: 30px; border: 1px solid #e0e0e0; }
    .pending-box { background: #fef3c7; border-left: 4px solid #f59e0b;
                   padding: 15px; margin: 20px 0; border-radius: 4px; }
    .conflict-box { background: #fee2e2; border-left: 4px solid #ef4444;
                   padding: 15px; margin: 20px 0; border-radius: 4px; }
    .details-box { background: #f9fafb; padding: 20px; margin: 20px 0; border-radius: 4px; }
    .button { display: inline-block; padding: 14px 28px; background: #667eea;
              color: white; text-decoration: none; border-radius: 6px; font-weight: bold;
              margin: 20px 0; }
    .button:hover { background: #5568d3; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 14px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>⏰ New Time-Off Request</h1>
      <p style="margin: 10px 0 0 0; font-size: 16px;">${companyName}</p>
    </div>

    <div class="content">
      <p>Hi ${managerName},</p>

      <div class="pending-box">
        <strong>${employeeName} has submitted a new time-off request that needs your review.</strong>
      </div>

      ${hasConflicts ? `
      <div class="conflict-box">
        <strong>⚠️ Scheduling Conflict</strong>
        <p style="margin: 8px 0 0 0;">${conflictCount} other employee${conflictCount === 1 ? '' : 's'} ${conflictCount === 1 ? 'has' : 'have'} time off during this period. Please review staffing needs carefully.</p>
      </div>
      ` : ''}

      <h2 style="color: #667eea;">Request Details</h2>
      <div class="details-box">
        <p style="margin-top: 0;"><strong>Employee:</strong> ${employeeName}</p>
        <p><strong>Type:</strong> ${type}</p>
        <p><strong>Start Date:</strong> ${startDate}</p>
        <p><strong>End Date:</strong> ${endDate}</p>
        <p style="margin-bottom: 0;"><strong>Duration:</strong> ${daysRequested} day${daysRequested === 1 ? '' : 's'}</p>
        ${reason ? `
        <hr style="margin: 15px 0; border: none; border-top: 1px solid #e0e0e0;">
        <p style="margin-bottom: 0;"><strong>Reason:</strong><br>${reason}</p>
        ` : ''}
      </div>

      <p>Please review and respond to this request as soon as possible.</p>

      <div style="text-align: center;">
        <a href="${appUrl || 'https://chronoworks-dcfd6.web.app'}" class="button">
          Review Request
        </a>
      </div>

      <p style="margin-top: 30px;">Thank you,</p>
      <p style="margin-top: 5px;"><strong>ChronoWorks System</strong></p>
    </div>

    <div class="footer">
      <p>This is an automated message from ChronoWorks</p>
      <p style="font-size: 12px; color: #999;">Powered by ChronoWorks Time Tracking System</p>
    </div>
  </div>
</body>
</html>
  `;

  const text = `
New Time-Off Request

Hi ${managerName},

${employeeName} has submitted a new time-off request that needs your review.

${hasConflicts ? `⚠️ SCHEDULING CONFLICT: ${conflictCount} other employee${conflictCount === 1 ? '' : 's'} ${conflictCount === 1 ? 'has' : 'have'} time off during this period.\n` : ''}
REQUEST DETAILS:
Employee: ${employeeName}
Type: ${type}
Start Date: ${startDate}
End Date: ${endDate}
Duration: ${daysRequested} day${daysRequested === 1 ? '' : 's'}
${reason ? `Reason: ${reason}` : ''}

Please review and respond to this request as soon as possible.

Review Request: ${appUrl || 'https://chronoworks-dcfd6.web.app'}

Thank you,
ChronoWorks System
  `;

  return await sendEmail({
    to: managerEmail,
    subject,
    html,
    text,
  });
}


module.exports = {
  sendAdminNotification,
  sendWelcomeEmail,
  sendRejectionEmail,
  sendEmployeeWelcomeEmail,
  // New Free Plan Phase email functions
  sendFreePhase1WarningEmail: sendTrialWarningEmail,
  sendFreePhase2TransitionEmail: sendTrialExpiredEmail,
  sendFreePhase2WarningEmail: sendFreeAccountWarningEmail,
  sendAccountLockedEmail,
  sendManagerUrgentTaskEmail,
  sendManagerDailyDigestEmail,
  sendManagerOverdueTaskEmail,
  sendUpgradeConfirmationEmail,
  sendDowngradeScheduledEmail,
  sendSubscriptionManagementEmail,
  sendScheduleEmail,
  sendOffPremisesAlert,
  // Old names (deprecated - for backward compatibility)
  sendTrialWarningEmail,
  sendTrialExpiredEmail,
  sendFreeAccountWarningEmail,
  sendTimeOffApprovedEmail,
  sendTimeOffDeniedEmail,
  sendTimeOffRequestSubmittedEmail,
};
