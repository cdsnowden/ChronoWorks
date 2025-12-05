/**
 * Quick Compliance Rules Seeder
 * Uses default credentials from Firebase CLI
 */

const admin = require('firebase-admin');

// Initialize without service account - uses GOOGLE_APPLICATION_CREDENTIALS or gcloud auth
admin.initializeApp({
  projectId: 'chronoworks-dcfd6'
});

const db = admin.firestore();
const Timestamp = admin.firestore.Timestamp;
const CURRENT_RULES_VERSION = '2024.1.0';
const now = Timestamp.now();

const createRule = (data) => ({
  ...data,
  version: CURRENT_RULES_VERSION,
  createdAt: now,
  updatedAt: now,
  isActive: true,
});

function generateAllRules() {
  const rules = [];

  // Federal Rules
  rules.push(createRule({ id: 'fed_weekly_ot', name: 'Federal Weekly Overtime', description: 'Non-exempt employees must receive 1.5x pay for hours over 40 per week', category: 'weeklyOvertime', jurisdiction: 'federal', overtimeThreshold: 40, overtimeMultiplier: 1.5, warningMinutesBefore: 60, enforcementAction: 'warnManager', legalReference: 'FLSA Section 7(a)' }));
  rules.push(createRule({ id: 'fed_minor_hours', name: 'Federal Minor Work Hours', description: 'Minors 14-15: max 3 hours on school days, 8 hours non-school days', category: 'minorHours', jurisdiction: 'federal', maxHoursSchoolDay: 3, maxHoursNonSchoolDay: 8, warningMinutesBefore: 30, enforcementAction: 'blockAction', legalReference: 'FLSA Child Labor Provisions' }));

  // California - comprehensive
  rules.push(createRule({ id: 'ca_meal_break', name: 'California Meal Break', description: '30-minute meal break required after 5 hours of work', category: 'mealBreak', jurisdiction: 'state', state: 'CA', hoursThreshold: 5, durationMinutes: 30, warningMinutesBefore: 30, enforcementAction: 'requireAcknowledgment', isWaivable: true, waiverRequirements: 'Written waiver for shifts 6 hours or less', legalReference: 'California Labor Code Section 512' }));
  rules.push(createRule({ id: 'ca_rest_break', name: 'California Rest Break', description: '10-minute paid rest break for every 4 hours worked', category: 'restBreak', jurisdiction: 'state', state: 'CA', hoursThreshold: 4, durationMinutes: 10, warningMinutesBefore: 15, enforcementAction: 'warnEmployee', legalReference: 'California Labor Code Section 226.7' }));
  rules.push(createRule({ id: 'ca_daily_ot', name: 'California Daily Overtime', description: 'Overtime pay (1.5x) for hours worked over 8 in a day', category: 'dailyOvertime', jurisdiction: 'state', state: 'CA', overtimeThreshold: 8, overtimeMultiplier: 1.5, warningMinutesBefore: 60, enforcementAction: 'warnManager', legalReference: 'California Labor Code Section 510' }));
  rules.push(createRule({ id: 'ca_double_time', name: 'California Double Time', description: 'Double time pay (2x) for hours worked over 12 in a day', category: 'doubleTime', jurisdiction: 'state', state: 'CA', overtimeThreshold: 12, overtimeMultiplier: 2.0, warningMinutesBefore: 30, enforcementAction: 'warnManager', legalReference: 'California Labor Code Section 510' }));

  // Colorado
  rules.push(createRule({ id: 'co_meal_break', name: 'Colorado Meal Break', description: '30-minute meal break after 5 hours', category: 'mealBreak', jurisdiction: 'state', state: 'CO', hoursThreshold: 5, durationMinutes: 30, warningMinutesBefore: 30, enforcementAction: 'requireAcknowledgment', isWaivable: true, legalReference: 'Colorado COMPS Order #38' }));
  rules.push(createRule({ id: 'co_rest_break', name: 'Colorado Rest Break', description: '10-minute rest break every 4 hours', category: 'restBreak', jurisdiction: 'state', state: 'CO', hoursThreshold: 4, durationMinutes: 10, warningMinutesBefore: 15, enforcementAction: 'warnEmployee', legalReference: 'Colorado COMPS Order #38' }));
  rules.push(createRule({ id: 'co_daily_ot', name: 'Colorado Daily Overtime', description: 'Overtime after 12 hours/day', category: 'dailyOvertime', jurisdiction: 'state', state: 'CO', overtimeThreshold: 12, overtimeMultiplier: 1.5, warningMinutesBefore: 60, enforcementAction: 'warnManager', legalReference: 'Colorado COMPS Order #38' }));

  // States with meal break requirements
  const mealBreakStates = [
    { state: 'CT', hours: 7.5, ref: 'Connecticut General Statutes Section 31-51ii' },
    { state: 'DE', hours: 7.5, ref: 'Delaware Code Title 19, Section 707' },
    { state: 'IL', hours: 7.5, ref: 'Illinois One Day Rest in Seven Act' },
    { state: 'KY', hours: 5, ref: 'Kentucky Revised Statutes 337.355' },
    { state: 'ME', hours: 6, ref: 'Maine Revised Statutes Title 26, Section 601' },
    { state: 'MA', hours: 6, ref: 'Massachusetts General Laws Chapter 149, Section 100' },
    { state: 'MN', hours: 8, ref: 'Minnesota Statutes Section 177.254' },
    { state: 'NV', hours: 8, ref: 'Nevada Revised Statutes 608.019' },
    { state: 'NH', hours: 5, ref: 'New Hampshire RSA 275:30-a' },
    { state: 'NY', hours: 6, ref: 'New York Labor Law Section 162' },
    { state: 'ND', hours: 5, ref: 'North Dakota Admin Code 46-02-07-02' },
    { state: 'OR', hours: 6, ref: 'Oregon ORS 653.261' },
    { state: 'RI', hours: 6, ref: 'Rhode Island General Laws 28-3-14' },
    { state: 'TN', hours: 6, ref: 'Tennessee Code 50-2-103' },
    { state: 'VT', hours: 6, ref: 'Vermont Statutes Title 21' },
    { state: 'WA', hours: 5, ref: 'Washington WAC 296-126-092' },
    { state: 'WV', hours: 6, ref: 'West Virginia Code 21-3-10a' },
  ];

  mealBreakStates.forEach(s => {
    rules.push(createRule({
      id: s.state.toLowerCase() + '_meal_break',
      name: s.state + ' Meal Break',
      description: '30-minute meal break required after ' + s.hours + ' hours of work',
      category: 'mealBreak',
      jurisdiction: 'state',
      state: s.state,
      hoursThreshold: s.hours,
      durationMinutes: 30,
      warningMinutesBefore: 30,
      enforcementAction: 'requireAcknowledgment',
      legalReference: s.ref,
    }));
  });

  // States with rest break requirements
  const restBreakStates = [
    { state: 'KY', ref: 'Kentucky Revised Statutes 337.365' },
    { state: 'MN', ref: 'Minnesota Statutes Section 177.253' },
    { state: 'NV', ref: 'Nevada Revised Statutes 608.019' },
    { state: 'OR', ref: 'Oregon ORS 653.261' },
    { state: 'WA', ref: 'Washington WAC 296-126-092' },
  ];

  restBreakStates.forEach(s => {
    rules.push(createRule({
      id: s.state.toLowerCase() + '_rest_break',
      name: s.state + ' Rest Break',
      description: '10-minute paid rest break for every 4 hours worked',
      category: 'restBreak',
      jurisdiction: 'state',
      state: s.state,
      hoursThreshold: 4,
      durationMinutes: 10,
      warningMinutesBefore: 15,
      enforcementAction: 'warnEmployee',
      legalReference: s.ref,
    }));
  });

  // Daily overtime states
  rules.push(createRule({ id: 'nv_daily_ot', name: 'Nevada Daily Overtime', description: 'Overtime pay (1.5x) for hours over 8/day', category: 'dailyOvertime', jurisdiction: 'state', state: 'NV', overtimeThreshold: 8, overtimeMultiplier: 1.5, warningMinutesBefore: 60, enforcementAction: 'warnManager', legalReference: 'Nevada Constitution Article 15' }));
  rules.push(createRule({ id: 'ak_daily_ot', name: 'Alaska Daily Overtime', description: 'Overtime pay (1.5x) for hours over 8/day', category: 'dailyOvertime', jurisdiction: 'state', state: 'AK', overtimeThreshold: 8, overtimeMultiplier: 1.5, warningMinutesBefore: 60, enforcementAction: 'warnManager', legalReference: 'Alaska Stat. 23.10.060' }));

  // City-level rules
  rules.push(createRule({ id: 'nyc_predictive_scheduling', name: 'NYC Fair Workweek Law', description: 'Fast food and retail employers must provide 72-hour advance schedule notice', category: 'predictiveScheduling', jurisdiction: 'city', state: 'NY', city: 'New York City', advanceNoticeDays: 3, enforcementAction: 'warnManager', legalReference: 'NYC Admin Code 20-1221' }));
  rules.push(createRule({ id: 'seattle_predictive_scheduling', name: 'Seattle Secure Scheduling', description: 'Retail and food service must provide 14-day advance schedule notice', category: 'predictiveScheduling', jurisdiction: 'city', state: 'WA', city: 'Seattle', advanceNoticeDays: 14, enforcementAction: 'warnManager', legalReference: 'Seattle Municipal Code 14.22' }));
  rules.push(createRule({ id: 'sf_predictive_scheduling', name: 'San Francisco Formula Retail', description: '14-day advance schedule notice for formula retail employees', category: 'predictiveScheduling', jurisdiction: 'city', state: 'CA', city: 'San Francisco', advanceNoticeDays: 14, enforcementAction: 'warnManager', legalReference: 'SF Police Code Article 33F' }));

  return rules;
}

async function seedRules() {
  console.log('Starting compliance rules seeding...');

  const rules = generateAllRules();
  console.log(`Generated ${rules.length} rules`);

  const batch = db.batch();

  rules.forEach(rule => {
    const ref = db.collection('complianceRules').doc(rule.id);
    batch.set(ref, rule);
  });

  // Update metadata
  const metaRef = db.collection('complianceMetadata').doc('rulesInfo');
  batch.set(metaRef, {
    version: CURRENT_RULES_VERSION,
    lastUpdated: now,
    totalRules: rules.length,
    federalRules: rules.filter(r => r.jurisdiction === 'federal').length,
    stateRules: rules.filter(r => r.jurisdiction === 'state').length,
    cityRules: rules.filter(r => r.jurisdiction === 'city').length,
  });

  await batch.commit();
  console.log(`SUCCESS! Seeded ${rules.length} compliance rules to Firestore`);
}

seedRules()
  .then(() => {
    console.log('Seeding complete!');
    process.exit(0);
  })
  .catch(err => {
    console.error('Error seeding rules:', err);
    process.exit(1);
  });
