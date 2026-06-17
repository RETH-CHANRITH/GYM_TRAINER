const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const { verifyToken, handleError, sendSuccess } = require('../middleware/auth');
const DatabaseService = require('../services/database');
const { v4: uuidv4 } = require('uuid');
const EmailService = require('../services/email');

/**
 * POST /api/v1/auth/register
 * Register a new user with email and password
 */
router.post('/register', async (req, res) => {
  try {
    const { email, password, fullName, userType } = req.body;

    if (!email || !password || !fullName) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Email, password, and fullName are required',
          code: 'INVALID_REQUEST',
          status: 400
        }
      });
    }

    // Create user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email,
      password,
      displayName: fullName,
    });

    // Create user profile in Firestore
    const userProfile = await DatabaseService.createDoc('users', {
      uid: userRecord.uid,
      email,
      fullName,
      userType: userType || 'user',
      profileImage: null,
      phone: null,
      address: null,
      rating: 0,
      reviews: 0,
      bio: null,
      verified: false,
      active: true
    }, userRecord.uid);

    // Set custom claims based on user type
    const role = userType === 'trainer' ? 'trainer' : 'user';
    await admin.auth().setCustomUserClaims(userRecord.uid, { role });

    return sendSuccess(res, {
      uid: userRecord.uid,
      email: userRecord.email,
      displayName: userRecord.displayName,
      role
    }, 'User registered successfully', 201);

  } catch (error) {
    if (error.code === 'auth/email-already-exists') {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Email already in use',
          code: 'EMAIL_EXISTS',
          status: 400
        }
      });
    }
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/auth/login
 * Login user and get Firebase token
 */
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Email and password are required',
          code: 'INVALID_REQUEST',
          status: 400
        }
      });
    }

    // Note: This endpoint should be called via Firebase SDK on client
    // Server login typically uses Firebase Admin SDK to create custom tokens
    // For complete implementation, use Firebase REST API or client SDK

    return res.status(200).json({
      success: true,
      message: 'Use Firebase SDK on client for login',
      note: 'Client should use firebase.auth().signInWithEmailAndPassword()'
    });

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * GET /api/v1/auth/profile
 * Get current user profile (requires authentication)
 */
router.get('/profile', verifyToken, async (req, res) => {
  try {
    const user = await DatabaseService.getDoc('users', req.userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'User profile not found',
          code: 'NOT_FOUND',
          status: 404
        }
      });
    }

    return sendSuccess(res, user);

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/auth/logout
 * Logout endpoint (token invalidation on client)
 */
router.post('/logout', verifyToken, async (req, res) => {
  try {
    // Revoke all refresh tokens for this user
    await admin.auth().revokeRefreshTokens(req.userId);

    return sendSuccess(res, null, 'Logged out successfully');

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/auth/refresh-token
 * Refresh user's authentication token
 */
router.post('/refresh-token', verifyToken, async (req, res) => {
  try {
    // Generate custom token for extended session
    const customToken = await admin.auth().createCustomToken(req.userId);

    return sendSuccess(res, { token: customToken }, 'Token refreshed');

  } catch (error) {
    return handleError(res, error);
  }
});

// Helper for local development testing without Firebase Admin credentials
const getFirestoreDb = () => {
  if (admin.apps.length > 0) {
    return admin.firestore();
  }
  return {
    collection: (colName) => {
      if (!global.mockFirestore) global.mockFirestore = {};
      if (!global.mockFirestore[colName]) global.mockFirestore[colName] = {};
      return {
        doc: (docId) => {
          return {
            set: async (data) => {
              global.mockFirestore[colName][docId] = {
                ...data,
                createdAt: data.createdAt || new Date(),
                expiresAt: data.expiresAt || new Date()
              };
            },
            get: async () => {
              const val = global.mockFirestore[colName][docId];
              return {
                exists: !!val,
                data: () => val
              };
            },
            delete: async () => {
              delete global.mockFirestore[colName][docId];
            }
          };
        }
      };
    }
  };
};

const getMockTimestampNow = () => {
  return {
    seconds: Math.floor(Date.now() / 1000)
  };
};

/**
 * POST /api/v1/auth/password-reset
 * Request password reset OTP email
 */
router.post('/password-reset', async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Email is required',
          code: 'INVALID_REQUEST',
          status: 400
        }
      });
    }

    // 1. Verify user exists in Firebase Auth (bypassed if Firebase not initialized locally)
    let userRecord;
    let userName = 'Gym Member';
    if (admin.apps.length > 0) {
      try {
        userRecord = await admin.auth().getUserByEmail(email.trim());
      } catch (err) {
        if (err.code === 'auth/user-not-found') {
          return res.status(404).json({
            success: false,
            error: {
              message: 'No account found with this email address.',
              code: 'USER_NOT_FOUND',
              status: 404
            }
          });
        }
        throw err;
      }

      // Retrieve user's display name from users collection if available
      try {
        const userProfile = await DatabaseService.getDoc('users', userRecord.uid);
        if (userProfile && userProfile.fullName) {
          userName = userProfile.fullName;
        }
      } catch (_) {}
    } else {
      console.log('⚠️ Firebase not initialized. Mocking user verification for local development.');
      userRecord = { uid: 'mock-uid-123', email: email.trim().toLowerCase() };
    }

    // 2. Generate 6-digit numeric OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // 3. Store OTP in Firestore (expires in 5 minutes)
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);
    const dbData = {
      email: email.trim().toLowerCase(),
      otp,
      createdAt: admin.apps.length > 0 ? admin.firestore.FieldValue.serverTimestamp() : new Date(),
      expiresAt: admin.apps.length > 0 ? admin.firestore.Timestamp.fromDate(expiresAt) : { seconds: Math.floor(expiresAt.getTime() / 1000) }
    };
    await getFirestoreDb().collection('otps').doc(email.trim().toLowerCase()).set(dbData);

    // 4. Send OTP Email using Google SMTP
    await EmailService.sendOtpEmail(email.trim().toLowerCase(), otp, userName);

    return sendSuccess(res, null, 'Verification code sent successfully.', 200);

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/auth/verify-otp
 * Verify OTP code and generate password reset token
 */
router.post('/verify-otp', async (req, res) => {
  try {
    const { email, otp } = req.body;

    if (!email || !otp) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Email and OTP are required.',
          code: 'INVALID_REQUEST',
          status: 400
        }
      });
    }

    const docRef = getFirestoreDb().collection('otps').doc(email.trim().toLowerCase());
    const doc = await docRef.get();

    if (!doc.exists) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Invalid verification code or code has expired.',
          code: 'INVALID_CODE',
          status: 400
        }
      });
    }

    const data = doc.data();
    if (data.otp !== otp.trim()) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Incorrect verification code. Please try again.',
          code: 'INCORRECT_CODE',
          status: 400
        }
      });
    }

    // Check expiration
    const now = admin.apps.length > 0 ? admin.firestore.Timestamp.now() : getMockTimestampNow();
    if (data.expiresAt && now.seconds > data.expiresAt.seconds) {
      await docRef.delete();
      return res.status(400).json({
        success: false,
        error: {
          message: 'Verification code has expired. Please request a new one.',
          code: 'EXPIRED_CODE',
          status: 400
        }
      });
    }

    // Delete OTP after successful verification so it cannot be reused
    await docRef.delete();

    // Generate a temporary secure reset token (valid for 10 minutes)
    const resetToken = uuidv4();
    const tokenExpiresAt = new Date(Date.now() + 10 * 60 * 1000);

    const tokenData = {
      email: email.trim().toLowerCase(),
      token: resetToken,
      createdAt: admin.apps.length > 0 ? admin.firestore.FieldValue.serverTimestamp() : new Date(),
      expiresAt: admin.apps.length > 0 ? admin.firestore.Timestamp.fromDate(tokenExpiresAt) : { seconds: Math.floor(tokenExpiresAt.getTime() / 1000) }
    };
    await getFirestoreDb().collection('resetTokens').doc(email.trim().toLowerCase()).set(tokenData);

    return sendSuccess(res, { resetToken }, 'OTP verified successfully.', 200);

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/auth/update-password
 * Complete password reset using secure reset token
 */
router.post('/update-password', async (req, res) => {
  try {
    const { email, resetToken, newPassword } = req.body;

    if (!email || !resetToken || !newPassword) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Email, resetToken, and newPassword are required.',
          code: 'INVALID_REQUEST',
          status: 400
        }
      });
    }

    if (newPassword.trim().length < 6) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Password must be at least 6 characters.',
          code: 'PASSWORD_TOO_SHORT',
          status: 400
        }
      });
    }

    const docRef = getFirestoreDb().collection('resetTokens').doc(email.trim().toLowerCase());
    const doc = await docRef.get();

    if (!doc.exists) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Password reset session not found or session has expired.',
          code: 'SESSION_NOT_FOUND',
          status: 400
        }
      });
    }

    const data = doc.data();
    if (data.token !== resetToken) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Invalid reset session token.',
          code: 'INVALID_SESSION',
          status: 400
        }
      });
    }

    // Check expiration
    const now = admin.apps.length > 0 ? admin.firestore.Timestamp.now() : getMockTimestampNow();
    if (data.expiresAt && now.seconds > data.expiresAt.seconds) {
      await docRef.delete();
      return res.status(400).json({
        success: false,
        error: {
          message: 'Reset session has expired. Please request a new verification code.',
          code: 'SESSION_EXPIRED',
          status: 400
        }
      });
    }

    // Delete reset token
    await docRef.delete();

    // Update user password in Firebase Auth (mocked if Firebase not initialized)
    if (admin.apps.length > 0) {
      const userRecord = await admin.auth().getUserByEmail(email.trim().toLowerCase());
      await admin.auth().updateUser(userRecord.uid, {
        password: newPassword.trim()
      });
    } else {
      console.log(`⚠️ Firebase not initialized. Mock password update for user: ${email.trim()}`);
    }

    return sendSuccess(res, null, 'Password updated successfully.', 200);

  } catch (error) {
    return handleError(res, error);
  }
});

module.exports = router;
