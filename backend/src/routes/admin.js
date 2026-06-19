const express = require('express');
const router = express.Router();
const admin = require('firebase-admin');
const { verifyToken, verifyAdmin, handleError, sendSuccess } = require('../middleware/auth');
const DatabaseService = require('../services/database');

/**
 * GET /api/v1/admin/dashboard
 * Get admin dashboard statistics
 */
router.get('/dashboard', verifyToken, verifyAdmin, async (req, res) => {
  try {
    // Get basic statistics
    const users = await DatabaseService.query('users', [], null, 1000, 0);
    const bookings = await DatabaseService.query('bookings', [], null, 1000, 0);
    const reviews = await DatabaseService.query('reviews', [], null, 1000, 0);

    const stats = {
      totalUsers: users.total,
      totalTrainers: users.items.filter(u => u.userType === 'trainer').length,
      totalBookings: bookings.total,
      completedBookings: bookings.items.filter(b => b.status === 'completed').length,
      totalRevenue: bookings.items
        .filter(b => b.paymentStatus === 'completed' || b.paymentStatus === 'fully_paid' || b.paymentStatus === 'partially_paid' || b.paid === true)
        .reduce((sum, b) => sum + (b.amountPaid || b.paymentAmount || b.price || 0), 0),
      totalReviews: reviews.total,
      averageRating: reviews.items.length > 0
        ? (reviews.items.reduce((sum, r) => sum + r.rating, 0) / reviews.items.length).toFixed(1)
        : 0
    };

    return sendSuccess(res, stats);

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * GET /api/v1/admin/users
 * Get all users with pagination
 */
router.get('/users', verifyToken, verifyAdmin, async (req, res) => {
  try {
    const { limit = 20, offset = 0, userType, search } = req.query;

    let filters = [];
    if (userType) {
      filters.push({ field: 'userType', operator: '==', value: userType });
    }

    const result = await DatabaseService.query(
      'users',
      filters,
      { field: 'createdAt', direction: 'desc' },
      parseInt(limit),
      parseInt(offset)
    );

    return sendSuccess(res, result);

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * GET /api/v1/admin/trainers/applications
 * Get trainer applications
 */
router.get('/trainers/applications', verifyToken, verifyAdmin, async (req, res) => {
  try {
    const { limit = 20, offset = 0, status } = req.query;

    let filters = [];
    if (status) {
      filters.push({ field: 'status', operator: '==', value: status });
    }

    const result = await DatabaseService.query(
      'trainer_applications',
      filters,
      { field: 'appliedAt', direction: 'desc' },
      parseInt(limit),
      parseInt(offset)
    );

    return sendSuccess(res, result);

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/admin/trainers/applications/:applicationId/approve
 * Approve trainer application
 */
router.post('/trainers/applications/:applicationId/approve', verifyToken, verifyAdmin, async (req, res) => {
  try {
    const application = await DatabaseService.getDoc('trainer_applications', req.params.applicationId);

    if (!application) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'Application not found',
          code: 'NOT_FOUND',
          status: 404
        }
      });
    }

    // Update application status
    await DatabaseService.updateDoc('trainer_applications', req.params.applicationId, {
      status: 'approved',
      approvedAt: new Date(),
      approvedBy: req.userId
    });

    // Update user type to trainer
    await DatabaseService.updateDoc('users', application.userId, {
      userType: 'trainer',
      speciality: application.speciality,
      experience: application.experience
    });

    // Set trainer custom claim
    await admin.auth().setCustomUserClaims(application.userId, { role: 'trainer' });

    return sendSuccess(res, null, 'Trainer application approved');

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/admin/trainers/applications/:applicationId/reject
 * Reject trainer application
 */
router.post('/trainers/applications/:applicationId/reject', verifyToken, verifyAdmin, async (req, res) => {
  try {
    const { reason } = req.body;
    const application = await DatabaseService.getDoc('trainer_applications', req.params.applicationId);

    if (!application) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'Application not found',
          code: 'NOT_FOUND',
          status: 404
        }
      });
    }

    // Update application status
    await DatabaseService.updateDoc('trainer_applications', req.params.applicationId, {
      status: 'rejected',
      rejectedAt: new Date(),
      rejectedBy: req.userId,
      rejectionReason: reason || null
    });

    return sendSuccess(res, null, 'Trainer application rejected');

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * GET /api/v1/admin/bookings
 * Get all bookings
 */
router.get('/bookings', verifyToken, verifyAdmin, async (req, res) => {
  try {
    const { limit = 20, offset = 0, status, userId, trainerId } = req.query;

    let filters = [];
    if (status) {
      filters.push({ field: 'status', operator: '==', value: status });
    }
    if (userId) {
      filters.push({ field: 'userId', operator: '==', value: userId });
    }
    if (trainerId) {
      filters.push({ field: 'trainerId', operator: '==', value: trainerId });
    }

    const result = await DatabaseService.query(
      'bookings',
      filters,
      { field: 'date', direction: 'desc' },
      parseInt(limit),
      parseInt(offset)
    );

    return sendSuccess(res, result);

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/admin/users/:userId/ban
 * Ban a user
 */
router.post('/users/:userId/ban', verifyToken, verifyAdmin, async (req, res) => {
  try {
    const { reason } = req.body;

    const user = await DatabaseService.getDoc('users', req.params.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'User not found',
          code: 'NOT_FOUND',
          status: 404
        }
      });
    }

    // Update user status
    await DatabaseService.updateDoc('users', req.params.userId, {
      active: false,
      bannedAt: new Date(),
      bannedBy: req.userId,
      banReason: reason || null
    });

    // Disable Firebase account
    await admin.auth().updateUser(req.params.userId, { disabled: true });

    return sendSuccess(res, null, 'User banned successfully');

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/admin/users/:userId/unban
 * Unban a user
 */
router.post('/users/:userId/unban', verifyToken, verifyAdmin, async (req, res) => {
  try {
    // Update user status
    await DatabaseService.updateDoc('users', req.params.userId, {
      active: true,
      bannedAt: null,
      bannedBy: null
    });

    // Enable Firebase account
    await admin.auth().updateUser(req.params.userId, { disabled: false });

    return sendSuccess(res, null, 'User unbanned successfully');

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * GET /api/v1/admin/reports
 * Get flagged/reported content
 */
router.get('/reports', verifyToken, verifyAdmin, async (req, res) => {
  try {
    const { limit = 20, offset = 0, status } = req.query;

    let filters = [];
    if (status) {
      filters.push({ field: 'status', operator: '==', value: status });
    }

    const result = await DatabaseService.query(
      'reports',
      filters,
      { field: 'reportedAt', direction: 'desc' },
      parseInt(limit),
      parseInt(offset)
    );

    return sendSuccess(res, result);

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/admin/analytics
 * Get analytics data
 */
router.get('/analytics', verifyToken, verifyAdmin, async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    // Get bookings in date range
    const bookings = await DatabaseService.query('bookings', [], { field: 'date', direction: 'desc' }, 1000, 0);

    const analytics = {
      bookingsThisMonth: bookings.items.filter(b => {
        const bookingDate = new Date(b.date);
        const now = new Date();
        return bookingDate.getMonth() === now.getMonth() && bookingDate.getFullYear() === now.getFullYear();
      }).length,
      revenueThisMonth: bookings.items
        .filter(b => {
          const bookingDate = new Date(b.date);
          const now = new Date();
          return bookingDate.getMonth() === now.getMonth() && bookingDate.getFullYear() === now.getFullYear();
        })
        .filter(b => b.paymentStatus === 'completed' || b.paymentStatus === 'fully_paid' || b.paymentStatus === 'partially_paid' || b.paid === true)
        .reduce((sum, b) => sum + (b.amountPaid || b.paymentAmount || b.price || 0), 0),
      topTrainers: await getTopTrainers(bookings.items),
      userGrowth: await getUserGrowth()
    };

    return sendSuccess(res, analytics);

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * Helper function: Get top trainers by bookings
 */
async function getTopTrainers(bookings) {
  const trainerMap = {};
  bookings.forEach(b => {
    if (!trainerMap[b.trainerId]) {
      trainerMap[b.trainerId] = 0;
    }
    trainerMap[b.trainerId]++;
  });

  return Object.entries(trainerMap)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([trainerId, count]) => ({ trainerId, bookings: count }));
}

/**
 * Helper function: Get user growth
 */
async function getUserGrowth() {
  const users = await DatabaseService.query('users', [], { field: 'createdAt', direction: 'asc' }, 1000, 0);
  const months = {};

  users.items.forEach(user => {
    const date = new Date(user.createdAt);
    const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
    months[monthKey] = (months[monthKey] || 0) + 1;
  });

  return months;
}

/**
 * POST /api/v1/admin/send-campaign-push
 * Send FCM push notification to all users when a campaign is published.
 * Body: { title, discount, label }
 */
router.post('/send-campaign-push', verifyToken, verifyAdmin, async (req, res) => {
  try {
    const { title, discount, label } = req.body;
    if (!title || discount === undefined || !label) {
      return res.status(400).json({ success: false, message: 'title, discount, and label are required.' });
    }

    const db = admin.firestore();

    // Fetch all users that have an FCM token stored
    const usersSnap = await db.collection('users').get();
    const tokens = [];

    usersSnap.forEach((doc) => {
      const data = doc.data();
      const role = (data.role || 'user').toLowerCase();
      // Only send to regular users and trainers, not admins
      if (role !== 'admin' && data.fcmToken && data.fcmToken.length > 10) {
        tokens.push(data.fcmToken);
      }
    });

    if (tokens.length === 0) {
      return res.json({ success: true, message: 'No FCM tokens found. 0 pushes sent.', sent: 0 });
    }

    // FCM allows max 500 tokens per multicast — chunk if needed
    const CHUNK = 500;
    let totalSent = 0;
    let totalFailed = 0;

    for (let i = 0; i < tokens.length; i += CHUNK) {
      const chunk = tokens.slice(i, i + CHUNK);
      const message = {
        tokens: chunk,
        notification: {
          title: `🎉 New Promotion: ${label}`,
          body: `${title} — Get ${discount}% off! Tap to claim now.`,
        },
        data: {
          type: 'promo',
          discount: String(discount),
          label: label,
          title: title,
        },
        android: {
          notification: {
            channelId: 'gym_trainer_channel',
            priority: 'high',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
          priority: 'high',
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      totalSent += response.successCount;
      totalFailed += response.failureCount;

      console.log(`📱 FCM chunk ${Math.floor(i / CHUNK) + 1}: ${response.successCount} sent, ${response.failureCount} failed`);
    }

    console.log(`✅ FCM campaign push complete: ${totalSent} sent, ${totalFailed} failed`);
    return res.json({
      success: true,
      message: `Push sent to ${totalSent} devices.`,
      sent: totalSent,
      failed: totalFailed,
    });
  } catch (error) {
    console.error('❌ FCM push error:', error);
    return handleError(res, error);
  }
});

module.exports = router;

