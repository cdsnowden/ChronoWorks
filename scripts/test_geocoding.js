/**
 * Test script to verify Google Maps Geocoding API is working
 *
 * Usage:
 *   node scripts/test_geocoding.js "123 Main St, Wilmington, NC 28403"
 *
 * Or with default test address:
 *   node scripts/test_geocoding.js
 */

const axios = require('axios');

// Get API key from environment or use the one from Firebase secrets
const API_KEY = process.env.GOOGLE_MAPS_API_KEY || 'AIzaSyAGBDxJw9D2Nbix14jfD_hVFHJSQeY8LiY';

async function testGeocoding(address) {
  console.log('\n=== Google Maps Geocoding API Test ===\n');
  console.log(`Testing address: "${address}"`);
  console.log(`API Key: ${API_KEY.substring(0, 10)}...${API_KEY.substring(API_KEY.length - 4)}`);
  console.log('');

  try {
    const response = await axios.get(
      'https://maps.googleapis.com/maps/api/geocode/json',
      {
        params: {
          address: address,
          key: API_KEY,
        },
      }
    );

    console.log(`Status: ${response.data.status}`);

    if (response.data.status === 'OK') {
      const result = response.data.results[0];
      const location = result.geometry.location;

      console.log('\n✅ SUCCESS! Geocoding is working.\n');
      console.log('Results:');
      console.log(`  Formatted Address: ${result.formatted_address}`);
      console.log(`  Latitude:  ${location.lat}`);
      console.log(`  Longitude: ${location.lng}`);
      console.log('\nworkLocation format for Firestore:');
      console.log(JSON.stringify({ lat: location.lat, lng: location.lng }, null, 2));

      return { lat: location.lat, lng: location.lng };
    } else if (response.data.status === 'REQUEST_DENIED') {
      console.log('\n❌ REQUEST_DENIED - API key issue\n');
      console.log('Possible causes:');
      console.log('  1. Geocoding API is not enabled for this project');
      console.log('  2. API key has restrictions blocking server-side calls');
      console.log('  3. Billing is not enabled on the Google Cloud project');
      console.log('\nTo fix:');
      console.log('  1. Go to: https://console.cloud.google.com/apis/library/geocoding-backend.googleapis.com');
      console.log('  2. Click "Enable" for Geocoding API');
      console.log('  3. Go to APIs & Services > Credentials');
      console.log('  4. Edit API key restrictions (remove HTTP referrer restrictions or create new key)');

      if (response.data.error_message) {
        console.log(`\nError message: ${response.data.error_message}`);
      }
    } else if (response.data.status === 'ZERO_RESULTS') {
      console.log('\n⚠️ ZERO_RESULTS - Address not found\n');
      console.log('The address could not be geocoded. Try a different address format.');
    } else {
      console.log(`\n⚠️ Unexpected status: ${response.data.status}`);
      if (response.data.error_message) {
        console.log(`Error: ${response.data.error_message}`);
      }
    }

    return null;
  } catch (error) {
    console.log('\n❌ ERROR making request:\n');
    console.log(error.message);
    return null;
  }
}

// Get address from command line or use default
const testAddress = process.argv[2] || '1600 Amphitheatre Parkway, Mountain View, CA 94043';

testGeocoding(testAddress);
