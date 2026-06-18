require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const admin = require('firebase-admin');

// Version: 1.0.1 - Fixed route loading errors

// Initialize Firebase Admin FIRST before importing routes
let serviceAccount;
let firebaseInitialized = false;

try {
  if (process.env.FIREBASE_SERVICE_ACCOUNT_BASE64) {
    // Use base64-encoded service account (more reliable for Render)
    console.log('📦 FIREBASE_SERVICE_ACCOUNT_BASE64 length:', process.env.FIREBASE_SERVICE_ACCOUNT_BASE64.length);
    const decoded = Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf-8');
    console.log('📦 Decoded string length:', decoded.length);
    console.log('📦 Decoded preview:', decoded.substring(0, 100) + '...');
    try {
      serviceAccount = JSON.parse(decoded);
      console.log('📦 Parsed serviceAccount keys:', Object.keys(serviceAccount));
      if (serviceAccount && serviceAccount.private_key) {
        console.log('📦 Private key length:', serviceAccount.private_key.length);
        serviceAccount.private_key = serviceAccount.private_key.replace(/\\n/g, '\n');
        console.log('📦 Private key start:', serviceAccount.private_key.substring(0, 30));
      }
    } catch (parseError) {
      console.error('❌ JSON parsing of decoded credentials failed:', parseError.message);
      throw parseError;
    }
  } else if (process.env.FIREBASE_PROJECT_ID) {
    // Fallback: build from individual env vars
    serviceAccount = {
      type: "service_account",
      project_id: process.env.FIREBASE_PROJECT_ID,
      private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
      private_key: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n') : undefined,
      client_email: process.env.FIREBASE_CLIENT_EMAIL,
      client_id: process.env.FIREBASE_CLIENT_ID,
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
    };
  }

  if (serviceAccount && serviceAccount.private_key) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      databaseURL: process.env.FIREBASE_DATABASE_URL,
    });
    firebaseInitialized = true;
    console.log('✅ Firebase initialized with project:', serviceAccount.project_id);
    console.log('✅ Service account email:', serviceAccount.client_email);
  } else {
    console.log('⚠️ Firebase credentials incomplete');
    if (serviceAccount) {
      console.log('   - Project ID:', serviceAccount.project_id);
      console.log('   - Has private_key:', !!serviceAccount.private_key);
      console.log('   - Client email:', serviceAccount.client_email);
    }
    console.log('Running backend without Firebase for now...');
  }
} catch (error) {
  console.log('⚠️ Firebase initialization failed:', error.message);
  console.log('Running backend without Firebase for now...');
}

// Import routes - will handle missing Firebase gracefully inside route files
let authRoutes, userRoutes, trainerRoutes, bookingRoutes, adminRoutes;

try {
  authRoutes = require('./src/routes/auth');
  userRoutes = require('./src/routes/users');
  trainerRoutes = require('./src/routes/trainers');
  bookingRoutes = require('./src/routes/bookings');
  adminRoutes = require('./src/routes/admin');
  console.log('✅ All routes loaded successfully');
} catch (error) {
  console.log('⚠️ Route loading error:', error.message);
  // Create dummy routes if real ones fail
  authRoutes = userRoutes = trainerRoutes = bookingRoutes = adminRoutes = require('express').Router();
}

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Request logging middleware
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Gym Trainer Booking App Backend API',
    status: 'running',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      auth: '/api/v1/auth',
      users: '/api/v1/users',
      trainers: '/api/v1/trainers',
      bookings: '/api/v1/bookings',
      admin: '/api/v1/admin'
    }
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// API Routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/users', userRoutes);
app.use('/api/v1/trainers', trainerRoutes);
app.use('/api/v1/bookings', bookingRoutes);
app.use('/api/v1/admin', adminRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: {
      message: 'Endpoint not found',
      code: 'NOT_FOUND',
      status: 404
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);

  const status = err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  res.status(status).json({
    success: false,
    error: {
      message,
      code: err.code || 'INTERNAL_ERROR',
      status,
      ...(process.env.NODE_ENV === 'development' && { details: err.stack })
    }
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔥 Health: http://localhost:${PORT}/health`);
});

module.exports = app;
