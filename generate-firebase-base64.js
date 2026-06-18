#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

// Read the credentials file path from command line arguments or use default
const args = process.argv.slice(2);
const credentialsPath = args[0] 
  ? path.resolve(args[0]) 
  : path.join(__dirname, 'backend/config/firebase-service-account.json');

try {
  if (!fs.existsSync(credentialsPath)) {
    console.error(`❌ File not found at path: ${credentialsPath}`);
    console.error('Usage: node generate-firebase-base64.js [path-to-firebase-service-account.json]');
    process.exit(1);
  }

  const credentials = JSON.parse(fs.readFileSync(credentialsPath, 'utf-8'));

  // Encode to base64
  const base64 = Buffer.from(JSON.stringify(credentials)).toString('base64');
  console.log('\n🚀 Copy the environment variable line below:');
  console.log('--------------------------------------------------');
  console.log('FIREBASE_SERVICE_ACCOUNT_BASE64=' + base64);
  console.log('--------------------------------------------------\n');
} catch (error) {
  console.error('❌ Failed to parse or encode service account key:', error.message);
  process.exit(1);
}
