/**
 * Subscription Plans Seeding Script
 *
 * This script populates the subscriptionPlans collection with the 7 subscription tiers
 * for ChronoWorks SaaS platform.
 *
 * Usage:
 *   node scripts/seed_subscription_plans.js
 *
 * Prerequisites:
 *   - Firebase Admin SDK initialized
 *   - Service account key configured
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin (if not already initialized)
if (!admin.apps.length) {
  const serviceAccount = require('../service-account-key.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'chronoworks-dcfd6'
  });
}

const db = admin.firestore();

const subscriptionPlans = [
  {
    planId: 'free',
    name: 'Free Plan',
    description: 'Limited features for businesses testing the platform (Days 31-60 only)',
    tagline: 'Try before you buy',

    // Pricing
    priceMonthly: 0,
    priceYearly: 0,
    currency: 'USD',

    // Features
    features: {
      // Core Features
      scheduleManagement: true,  // Full editing capability
      clockInOut: true,
      basicReporting: true,      // Last 7 days only

      // Employee Management
      breakTracking: false,
      shiftTemplates: false,
      photoVerification: false,
      departmentManagement: false,
      roleBasedPermissions: false,

      // Advanced Features
      overtimeTracking: false,
      missedClockoutAlerts: false,
      lateClockInAlerts: false,
      gpsTracking: false,
      advancedReporting: false,
      exportData: false,

      // Scheduling
      shiftSwapping: false,
      autoScheduling: false,

      // Payroll & Analytics
      payrollIntegration: false,
      laborCostTracking: false,
      paidTimeOff: false,
      customDashboards: false,
      historicalTrends: false,

      // Integration
      apiAccess: false,
      customIntegrations: false,
      biometricClockIn: false,

      // Communication
      teamMessaging: false,
      complianceReports: false,

      // Support
      emailSupport: true,        // Limited support
      prioritySupport: false,
      phoneSupport: false,
      dedicatedManager: false
    },

    // Limits
    maxEmployees: 10,
    maxLocations: 1,
    dataRetention: 7, // days

    // Display
    displayOrder: 0,
    isPopular: false,
    isVisible: true,

    // Stripe Integration (to be added later)
    stripePriceIdMonthly: null,
    stripePriceIdYearly: null,

    // Metadata
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },

  {
    planId: 'starter',
    name: 'Starter Plan',
    description: 'Perfect for small businesses just getting started',
    tagline: 'Essential time tracking',

    // Pricing
    priceMonthly: 24.99,
    priceYearly: 249.99, // Save ~17%
    currency: 'USD',

    // Features
    features: {
      // Core Features
      scheduleManagement: true,
      clockInOut: true,
      basicReporting: true,      // 30 days

      // Employee Management
      breakTracking: true,
      shiftTemplates: true,
      photoVerification: false,
      departmentManagement: false,
      roleBasedPermissions: false,

      // Advanced Features
      overtimeTracking: false,
      missedClockoutAlerts: false,
      lateClockInAlerts: false,
      gpsTracking: false,
      advancedReporting: false,
      exportData: false,

      // Scheduling
      shiftSwapping: false,
      autoScheduling: false,

      // Payroll & Analytics
      payrollIntegration: false,
      laborCostTracking: false,
      paidTimeOff: false,
      customDashboards: false,
      historicalTrends: false,

      // Integration
      apiAccess: false,
      customIntegrations: false,
      biometricClockIn: false,

      // Communication
      teamMessaging: false,
      complianceReports: false,

      // Support
      emailSupport: true,
      prioritySupport: false,
      phoneSupport: false,
      dedicatedManager: false
    },

    // Limits
    maxEmployees: 12,
    maxLocations: 1,
    dataRetention: 30, // days

    // Display
    displayOrder: 1,
    isPopular: false,
    isVisible: true,

    // Stripe Integration (to be added later)
    stripePriceIdMonthly: null,
    stripePriceIdYearly: null,

    // Metadata
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },

  {
    planId: 'bronze',
    name: 'Bronze Plan',
    description: 'Growing business essentials with overtime tracking',
    tagline: 'Overtime management & alerts',

    // Pricing
    priceMonthly: 49.99,
    priceYearly: 499.99, // Save ~17%
    currency: 'USD',

    // Features
    features: {
      // Core Features
      scheduleManagement: true,
      clockInOut: true,
      basicReporting: true,      // 30 days

      // Employee Management
      breakTracking: true,
      shiftTemplates: true,
      photoVerification: false,
      departmentManagement: false,
      roleBasedPermissions: false,

      // Advanced Features
      overtimeTracking: true,
      missedClockoutAlerts: true,
      lateClockInAlerts: true,
      gpsTracking: false,
      advancedReporting: false,
      exportData: false,

      // Scheduling
      shiftSwapping: false,
      autoScheduling: false,

      // Payroll & Analytics
      payrollIntegration: false,
      laborCostTracking: false,
      paidTimeOff: false,
      customDashboards: false,
      historicalTrends: false,

      // Integration
      apiAccess: false,
      customIntegrations: false,
      biometricClockIn: false,

      // Communication
      teamMessaging: false,
      complianceReports: false,

      // Support
      emailSupport: true,
      prioritySupport: false,
      phoneSupport: false,
      dedicatedManager: false
    },

    // Limits
    maxEmployees: 25,
    maxLocations: 1,
    dataRetention: 90, // days

    // Display
    displayOrder: 2,
    isPopular: false,
    isVisible: true,

    // Stripe Integration (to be added later)
    stripePriceIdMonthly: null,
    stripePriceIdYearly: null,

    // Metadata
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },

  {
    planId: 'silver',
    name: 'Silver Plan',
    description: 'Growing businesses with more advanced needs',
    tagline: 'Advanced features, integrations & reporting',

    // Pricing
    priceMonthly: 89.99,
    priceYearly: 899.99, // Save ~17%
    currency: 'USD',

    // Features
    features: {
      // Core Features
      scheduleManagement: true,
      clockInOut: true,
      basicReporting: true,

      // Employee Management
      breakTracking: true,
      shiftTemplates: true,
      photoVerification: true,
      departmentManagement: false,
      roleBasedPermissions: false,

      // Advanced Features
      overtimeTracking: true,
      missedClockoutAlerts: true,
      lateClockInAlerts: true,
      gpsTracking: true,
      advancedReporting: true,
      exportData: true,            // CSV export

      // Scheduling
      shiftSwapping: true,
      autoScheduling: false,

      // Payroll & Analytics
      payrollIntegration: true,    // MOVED FROM GOLD
      laborCostTracking: false,
      paidTimeOff: false,
      customDashboards: false,
      historicalTrends: false,

      // Integration
      apiAccess: true,             // MOVED FROM GOLD
      customIntegrations: false,
      biometricClockIn: false,

      // Communication
      teamMessaging: false,
      complianceReports: false,

      // Support
      emailSupport: true,
      prioritySupport: true,
      phoneSupport: false,
      dedicatedManager: false
    },

    // Limits
    maxEmployees: 50,
    maxLocations: 3,
    dataRetention: 365, // 1 year

    // Display
    displayOrder: 3,
    isPopular: true, // Most popular plan
    isVisible: true,

    // Stripe Integration (to be added later)
    stripePriceIdMonthly: null,
    stripePriceIdYearly: null,

    // Metadata
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },

  {
    planId: 'gold',
    name: 'Gold Plan',
    description: 'Established businesses requiring comprehensive solutions',
    tagline: 'Premium analytics & AI scheduling',

    // Pricing
    priceMonthly: 149.99,
    priceYearly: 1499.99, // Save ~17%
    currency: 'USD',

    // Features
    features: {
      // Core Features
      scheduleManagement: true,
      clockInOut: true,
      basicReporting: true,

      // Employee Management
      breakTracking: true,
      shiftTemplates: true,
      photoVerification: true,
      departmentManagement: true,
      roleBasedPermissions: false,

      // Advanced Features
      overtimeTracking: true,
      missedClockoutAlerts: true,
      lateClockInAlerts: true,
      gpsTracking: true,
      advancedReporting: true,
      exportData: true,

      // Scheduling
      shiftSwapping: true,
      autoScheduling: true,           // AI-powered scheduling

      // Payroll & Analytics (API & payroll moved to Silver)
      payrollIntegration: true,     // Also in Silver
      laborCostTracking: true,      // Gold exclusive
      paidTimeOff: true,            // Gold exclusive
      customDashboards: true,        // Gold exclusive
      historicalTrends: false,

      // Integration
      apiAccess: true,              // Also in Silver
      customIntegrations: false,
      biometricClockIn: false,

      // Communication
      teamMessaging: false,
      complianceReports: false,

      // Support
      emailSupport: true,
      prioritySupport: true,
      phoneSupport: true,
      dedicatedManager: false
    },

    // Limits
    maxEmployees: 100,
    maxLocations: 10,
    dataRetention: 730, // 2 years

    // Display
    displayOrder: 4,
    isPopular: false,
    isVisible: true,

    // Stripe Integration (to be added later)
    stripePriceIdMonthly: null,
    stripePriceIdYearly: null,

    // Metadata
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },

  {
    planId: 'platinum',
    name: 'Platinum Plan',
    description: 'Enterprise-level businesses with complex requirements',
    tagline: 'Complete solution with dedicated support',

    // Pricing
    priceMonthly: 249.99,
    priceYearly: 2499.99, // Save ~17%
    currency: 'USD',

    // Features
    features: {
      // Core Features
      scheduleManagement: true,
      clockInOut: true,
      basicReporting: true,

      // Employee Management
      breakTracking: true,
      shiftTemplates: true,
      photoVerification: true,
      departmentManagement: true,
      roleBasedPermissions: true,

      // Advanced Features
      overtimeTracking: true,
      missedClockoutAlerts: true,
      lateClockInAlerts: true,
      gpsTracking: true,
      advancedReporting: true,
      exportData: true,

      // Scheduling
      shiftSwapping: true,
      autoScheduling: true,

      // Payroll & Analytics
      payrollIntegration: true,
      laborCostTracking: true,
      paidTimeOff: true,
      customDashboards: true,
      historicalTrends: true,

      // Integration
      apiAccess: true,
      customIntegrations: true,
      biometricClockIn: true,

      // Communication
      teamMessaging: true,
      complianceReports: true,

      // Support
      emailSupport: true,
      prioritySupport: true,
      phoneSupport: true,
      dedicatedManager: true
    },

    // Limits
    maxEmployees: 250,
    maxLocations: 50,
    dataRetention: 1825, // 5 years

    // Display
    displayOrder: 5,
    isPopular: false,
    isVisible: true,

    // Stripe Integration (to be added later)
    stripePriceIdMonthly: null,
    stripePriceIdYearly: null,

    // Metadata
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },

  {
    planId: 'diamond',
    name: 'Diamond Plan',
    description: 'Large enterprises with maximum scalability needs',
    tagline: 'Ultimate enterprise solution',

    // Pricing
    priceMonthly: 499.99,
    priceYearly: 4999.99, // Save ~17%
    currency: 'USD',

    // Features
    features: {
      // Core Features
      scheduleManagement: true,
      clockInOut: true,
      basicReporting: true,

      // Employee Management
      breakTracking: true,
      shiftTemplates: true,
      photoVerification: true,
      departmentManagement: true,
      roleBasedPermissions: true,

      // Advanced Features
      overtimeTracking: true,
      missedClockoutAlerts: true,
      lateClockInAlerts: true,
      gpsTracking: true,
      advancedReporting: true,
      exportData: true,

      // Scheduling
      shiftSwapping: true,
      autoScheduling: true,

      // Payroll & Analytics
      payrollIntegration: true,
      laborCostTracking: true,
      paidTimeOff: true,
      customDashboards: true,
      historicalTrends: true,

      // Integration
      apiAccess: true,               // Priority API access
      customIntegrations: true,
      biometricClockIn: true,

      // Communication
      teamMessaging: true,
      complianceReports: true,

      // Support
      emailSupport: true,
      prioritySupport: true,
      phoneSupport: true,
      dedicatedManager: true         // Dedicated account manager
    },

    // Limits
    maxEmployees: 999999,            // Unlimited
    maxLocations: 999,               // Virtually unlimited
    dataRetention: 3650,             // 10 years

    // Display
    displayOrder: 6,
    isPopular: false,
    isVisible: true,

    // Stripe Integration (to be added later)
    stripePriceIdMonthly: null,
    stripePriceIdYearly: null,

    // Metadata
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }
];

async function seedSubscriptionPlans() {
  console.log('╔═══════════════════════════════════════════════════════════╗');
  console.log('║       ChronoWorks Subscription Plans Seeding             ║');
  console.log('╚═══════════════════════════════════════════════════════════╝\n');

  try {
    const batch = db.batch();

    for (const plan of subscriptionPlans) {
      const planRef = db.collection('subscriptionPlans').doc(plan.planId);
      batch.set(planRef, plan);
      console.log(`✓ Prepared ${plan.name} (${plan.planId})`);
      console.log(`  Price: $${plan.priceMonthly}/mo | Max Employees: ${plan.maxEmployees}`);
      console.log(`  Popular: ${plan.isPopular ? 'Yes' : 'No'}`);
      console.log('');
    }

    await batch.commit();

    console.log('╔═══════════════════════════════════════════════════════════╗');
    console.log('║              Successfully Seeded All Plans!               ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    console.log('Summary:');
    console.log(`  - Free Plan: $0/mo (10 employees, limited features)`);
    console.log(`  - Starter Plan: $24.99/mo (12 employees)`);
    console.log(`  - Bronze Plan: $49.99/mo (25 employees)`);
    console.log(`  - Silver Plan: $89.99/mo (50 employees) ⭐ POPULAR`);
    console.log(`  - Gold Plan: $149.99/mo (100 employees)`);
    console.log(`  - Platinum Plan: $249.99/mo (250 employees)`);
    console.log(`  - Diamond Plan: $499.99/mo (unlimited employees)`);
    console.log('');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error seeding subscription plans:', error);
    process.exit(1);
  }
}

// Run the seeding function
seedSubscriptionPlans();
