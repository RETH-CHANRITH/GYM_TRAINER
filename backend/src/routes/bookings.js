const express = require('express');
const router = express.Router();
const { verifyToken, handleError, sendSuccess } = require('../middleware/auth');
const DatabaseService = require('../services/database');
const { v4: uuidv4 } = require('uuid');

/**
 * POST /api/v1/bookings
 * Create a new booking
 */
router.post('/', verifyToken, async (req, res) => {
  try {
    const { trainerId, availabilityId, date, startTime, endTime, notes, price } = req.body;

    if (!trainerId || !availabilityId || !date || !startTime || !endTime) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'trainerId, availabilityId, date, startTime, and endTime are required',
          code: 'INVALID_REQUEST',
          status: 400
        }
      });
    }

    // Verify availability slot exists and is available
    const availability = await DatabaseService.getDoc('availability', availabilityId);
    if (!availability || !availability.available) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'Availability slot not available',
          code: 'SLOT_UNAVAILABLE',
          status: 400
        }
      });
    }

    // Create booking
    const bookingId = uuidv4();
    const booking = await DatabaseService.createDoc('bookings', {
      bookingId,
      userId: req.userId,
      trainerId,
      availabilityId,
      date: new Date(date),
      startTime,
      endTime,
      notes: notes || '',
      price: parseFloat(price || availability.price),
      status: 'confirmed',
      paymentStatus: 'pending',
      paymentMethod: null,
      transactionId: null,
      cancelledAt: null,
      cancelledBy: null,
      cancellationReason: null
    }, bookingId);

    // Mark availability as booked
    await DatabaseService.updateDoc('availability', availabilityId, {
      available: false,
      booked: true
    });

    return sendSuccess(res, booking, 'Booking created successfully', 201);

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * GET /api/v1/bookings/:bookingId
 * Get booking details
 */
router.get('/:bookingId', async (req, res) => {
  try {
    const booking = await DatabaseService.getDoc('bookings', req.params.bookingId);

    if (!booking) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'Booking not found',
          code: 'NOT_FOUND',
          status: 404
        }
      });
    }

    return sendSuccess(res, booking);

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * GET /api/v1/bookings
 * Get user's bookings with filters
 */
router.get('/', verifyToken, async (req, res) => {
  try {
    const { limit = 10, offset = 0, status, trainerId } = req.query;

    let filters = [{ field: 'userId', operator: '==', value: req.userId }];

    if (status) {
      filters.push({ field: 'status', operator: '==', value: status });
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
 * PUT /api/v1/bookings/:bookingId
 * Update booking (reschedule, update notes)
 */
router.put('/:bookingId', verifyToken, async (req, res) => {
  try {
    const booking = await DatabaseService.getDoc('bookings', req.params.bookingId);

    if (!booking) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'Booking not found',
          code: 'NOT_FOUND',
          status: 404
        }
      });
    }

    // Only user who created booking or trainer can update
    if (req.userId !== booking.userId && req.userId !== booking.trainerId) {
      return res.status(403).json({
        success: false,
        error: {
          message: 'Unauthorized',
          code: 'FORBIDDEN',
          status: 403
        }
      });
    }

    const { notes, startTime, endTime } = req.body;
    const updateData = {};

    if (notes !== undefined) updateData.notes = notes;
    if (startTime) updateData.startTime = startTime;
    if (endTime) updateData.endTime = endTime;

    const updated = await DatabaseService.updateDoc('bookings', req.params.bookingId, updateData);

    return sendSuccess(res, updated, 'Booking updated successfully');

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * DELETE /api/v1/bookings/:bookingId
 * Cancel booking
 */
router.delete('/:bookingId', verifyToken, async (req, res) => {
  try {
    const booking = await DatabaseService.getDoc('bookings', req.params.bookingId);

    if (!booking) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'Booking not found',
          code: 'NOT_FOUND',
          status: 404
        }
      });
    }

    // Only user who created booking or trainer can cancel
    if (req.userId !== booking.userId && req.userId !== booking.trainerId) {
      return res.status(403).json({
        success: false,
        error: {
          message: 'Unauthorized',
          code: 'FORBIDDEN',
          status: 403
        }
      });
    }

    const { reason } = req.body;

    // Update booking status
    await DatabaseService.updateDoc('bookings', req.params.bookingId, {
      status: 'cancelled',
      cancelledAt: new Date(),
      cancelledBy: req.userId,
      cancellationReason: reason || null
    });

    // Release availability slot
    if (booking.availabilityId) {
      await DatabaseService.updateDoc('availability', booking.availabilityId, {
        available: true,
        booked: false
      });
    }

    return sendSuccess(res, null, 'Booking cancelled successfully');

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/bookings/:bookingId/complete
 * Mark booking as completed
 */
router.post('/:bookingId/complete', verifyToken, async (req, res) => {
  try {
    const booking = await DatabaseService.getDoc('bookings', req.params.bookingId);

    if (!booking) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'Booking not found',
          code: 'NOT_FOUND',
          status: 404
        }
      });
    }

    // Only trainer or admin can mark as completed
    if (req.userId !== booking.trainerId) {
      return res.status(403).json({
        success: false,
        error: {
          message: 'Only trainer can mark booking as completed',
          code: 'FORBIDDEN',
          status: 403
        }
      });
    }

    const updated = await DatabaseService.updateDoc('bookings', req.params.bookingId, {
      status: 'completed',
      completedAt: new Date()
    });

    return sendSuccess(res, updated, 'Booking marked as completed');

  } catch (error) {
    return handleError(res, error);
  }
});

/**
 * POST /api/v1/bookings/:bookingId/payment
 * Record payment for booking
 */
router.post('/:bookingId/payment', verifyToken, async (req, res) => {
  try {
    const booking = await DatabaseService.getDoc('bookings', req.params.bookingId);

    if (!booking) {
      return res.status(404).json({
        success: false,
        error: {
          message: 'Booking not found',
          code: 'NOT_FOUND',
          status: 404
        }
      });
    }

    const { paymentMethod, transactionId, amount } = req.body;

    if (!paymentMethod || !transactionId) {
      return res.status(400).json({
        success: false,
        error: {
          message: 'paymentMethod and transactionId are required',
          code: 'INVALID_REQUEST',
          status: 400
        }
      });
    }

    const updated = await DatabaseService.updateDoc('bookings', req.params.bookingId, {
      paymentStatus: 'fully_paid',
      paid: true,
      amountPaid: parseFloat(amount || booking.price),
      paymentMethod,
      transactionId,
      paymentAmount: parseFloat(amount || booking.price)
    });

    return sendSuccess(res, updated, 'Payment recorded successfully');

  } catch (error) {
    return handleError(res, error);
  }
});

module.exports = router;
