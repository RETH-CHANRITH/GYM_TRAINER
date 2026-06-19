const dotenv = require('dotenv');
dotenv.config();

console.log("BASE64 Length:", process.env.FIREBASE_SERVICE_ACCOUNT_BASE64 ? process.env.FIREBASE_SERVICE_ACCOUNT_BASE64.length : "undefined");
if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
  try {
    const decoded = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf-8');
    console.log("Decoded length:", decoded.length);
    console.log("Ends with } ?", decoded.endsWith('}'));
    const parsed = JSON.parse(decoded);
    console.log("Parsed keys:", Object.keys(parsed));
    console.log("Private key length:", parsed.private_key ? parsed.private_key.length : "undefined");
  } catch (err) {
    console.error("Error:", err.message);
  }
}
