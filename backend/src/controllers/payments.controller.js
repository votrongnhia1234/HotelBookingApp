import pool from "../config/db.js";
import { createPaymentIntent, stripe } from "../services/stripe.service.js";
import {
  paymentsHasCurrencyColumn,
  paymentsMethodAllowedValues,
  paymentsStatusAllowedValues,
} from "../utils/schema.js";
import { sendPaymentReceipt, sendPaymentFailed } from "../utils/email.js";

const ONLINE_METHOD = "online";

export const createPayment = async (req, res, next) => {
  try {
    const { booking_id, amount, method = ONLINE_METHOD, currency = "usd" } = req.body;
    if (!booking_id || amount == null) {
      return res.status(400).json({ message: "booking_id and amount are required", code: "VALIDATION_ERROR" });
    }

    const [rows] = await pool.query(
      "SELECT id, status FROM bookings WHERE id = ? LIMIT 1",
      [booking_id],
    );
    if (!rows.length) return res.status(404).json({ message: "Booking not found", code: "NOT_FOUND" });
    const hasCurrencyColumn = await paymentsHasCurrencyColumn(pool);
    const methodAllowedValues = await paymentsMethodAllowedValues(pool);
    const statusAllowedValues = await paymentsStatusAllowedValues(pool);

    const pickFromEnum = (requested, allowedValues, fallbacks = []) => {
      if (!Array.isArray(allowedValues) || !allowedValues.length) {
        return requested;
      }
      if (allowedValues.includes(requested)) {
        return requested;
      }
      for (const candidate of fallbacks) {
        if (allowedValues.includes(candidate)) {
          return candidate;
        }
      }
      return allowedValues[0];
    };

    if (method !== ONLINE_METHOD) {
      const nextStatus = method === "cod" ? "confirmed" : "pending";

      const dbMethod = pickFromEnum(method, methodAllowedValues, [
        "cod",
        "cash",
        "manual",
      ]);
      const dbStatus = pickFromEnum(
        nextStatus,
        statusAllowedValues,
        ["pending", "created"],
      );
      const insertColumns = [
        "booking_id",
        "amount",
        "method",
        "status",
        "transaction_id",
        "provider",
      ];
      const updateSet = [
        "amount=VALUES(amount)",
        "status=VALUES(status)",
        "method=VALUES(method)",
        "provider='manual'",
      ];
      const params = [booking_id, amount, dbMethod, dbStatus, null, "manual"];
      if (hasCurrencyColumn) {
        insertColumns.push("currency");
        updateSet.push("currency=VALUES(currency)");
        params.push(currency);
      }
      const placeholders = insertColumns.map(() => "?").join(", ");
      const sql = `INSERT INTO payments (${insertColumns.join(", ")})
         VALUES (${placeholders})
         ON DUPLICATE KEY UPDATE ${updateSet.join(", ")}`;
      await pool.query(sql, params);

      await pool.query("UPDATE bookings SET status = ? WHERE id = ?", [nextStatus, booking_id]);

      return res.status(201).json({
        data: {
          booking_id,
          amount: Number(amount),
          method,
          status: nextStatus,
        },
      });
    }

    // ONLINE METHOD: handle zero-amount gracefully and currency fallback
    const numericAmount = Number(amount);
    if (!Number.isFinite(numericAmount) || numericAmount <= 0) {
      const nextStatus = "confirmed";
      const dbMethod = pickFromEnum("manual", methodAllowedValues, ["cash", "cod", "manual"]);
      const dbStatus = pickFromEnum(nextStatus, statusAllowedValues, ["pending", "created"]);
      const insertColumns = [
        "booking_id",
        "amount",
        "method",
        "status",
        "transaction_id",
        "provider",
      ];
      const updateSet = [
        "amount=VALUES(amount)",
        "status=VALUES(status)",
        "method=VALUES(method)",
        "provider='manual'",
      ];
      const params = [booking_id, 0, dbMethod, dbStatus, null, "manual"];
      if (hasCurrencyColumn) {
        insertColumns.push("currency");
        updateSet.push("currency=VALUES(currency)");
        params.push(currency);
      }
      const placeholders = insertColumns.map(() => "?").join(", ");
      const sql = `INSERT INTO payments (${insertColumns.join(", ")})
         VALUES (${placeholders})
         ON DUPLICATE KEY UPDATE ${updateSet.join(", ")}`;
      await pool.query(sql, params);
      await pool.query("UPDATE bookings SET status = ? WHERE id = ?", [nextStatus, booking_id]);
      return res.status(201).json({
        data: {
          booking_id,
          amount: 0,
          method: ONLINE_METHOD,
          status: nextStatus,
        },
      });
    }

    let currencyToUse = currency;
    let paymentIntent;
    try {
      paymentIntent = await createPaymentIntent({
        amount,
        currency: currencyToUse,
        metadata: { booking_id },
      });
    } catch (err) {
      const msg = String(err?.message ?? err);
      // Fallback to USD if the requested currency is not supported
      if (String(currencyToUse || '').toLowerCase() !== 'usd') {
        currencyToUse = 'usd';
        paymentIntent = await createPaymentIntent({
          amount,
          currency: currencyToUse,
          metadata: { booking_id },
        });
      } else {
        throw err;
      }
    }

    const dbMethod = pickFromEnum("stripe_card", methodAllowedValues, [
      "stripe",
      "credit_card",
      "card",
      "online",
    ]);
    const dbStatus = pickFromEnum(
      "processing",
      statusAllowedValues,
      ["pending", "created"],
    );
    const insertColumns = [
      "booking_id",
      "amount",
      "method",
      "status",
      "transaction_id",
      "provider",
    ];
    const updateSet = [
      "amount=VALUES(amount)",
      "status='processing'",
      "provider='stripe'",
      "method=VALUES(method)",
    ];
    const params = [booking_id, amount, dbMethod, dbStatus, paymentIntent.id, "stripe"];
    if (hasCurrencyColumn) {
      insertColumns.push("currency");
      updateSet.push("currency=VALUES(currency)");
      params.push(currencyToUse);
    }
    const placeholders = insertColumns.map(() => "?").join(", ");
    const sql = `INSERT INTO payments (${insertColumns.join(", ")})
       VALUES (${placeholders})
       ON DUPLICATE KEY UPDATE ${updateSet.join(", ")}`;
    await pool.query(sql, params);

    return res.json({ clientSecret: paymentIntent.client_secret });
  } catch (err) {
    next(err);
  }
};

export const handleStripeWebhook = async (req, res) => {
  try {
    const signature = req.headers["stripe-signature"];
    const event = stripe.webhooks.constructEvent(
      req.body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET,
    );

    // Start idempotent handling: record event once, then process transactionally
    const conn = await pool.getConnection();
    try {
      await conn.beginTransaction();
      try {
        await conn.query(
          "INSERT INTO webhook_events (provider, event_id, type) VALUES (?,?,?)",
          ["stripe", event.id, event.type]
        );
      } catch (sqlErr) {
        // Duplicate event: skip processing, acknowledge webhook
        if (sqlErr && sqlErr.code === "ER_DUP_ENTRY") {
          await conn.rollback();
          return res.json({ received: true });
        }
        throw sqlErr;
      }

      if (event.type === "payment_intent.succeeded") {
        const paymentIntent = event.data.object;
        const bookingId = paymentIntent.metadata.booking_id;

        await conn.query(
          "UPDATE payments SET status='completed' WHERE transaction_id=?",
          [paymentIntent.id]
        );
        await conn.query(
          "UPDATE bookings SET status='completed' WHERE id=?",
          [bookingId]
        );

        // Fetch booking & user to send receipt email (do not block webhook)
        const [[info]] = await conn.query(
          `SELECT b.id, b.check_in, b.check_out, b.total_price,
                  u.email AS user_email, u.name AS user_name,
                  r.room_number, r.type AS room_type, r.price_per_night,
                  h.name AS hotel_name,
                  GREATEST(DATEDIFF(b.check_out, b.check_in), 1) AS nights
             FROM bookings b
             JOIN users u ON u.id=b.user_id
             JOIN rooms r ON r.id=b.room_id
             JOIN hotels h ON h.id=r.hotel_id
            WHERE b.id=? LIMIT 1`,
          [bookingId]
        );

        await conn.commit();

        const recipient = info?.user_email;
        const fallbackSuffix = '@firebase-user.stayeasy';
        if (recipient && !recipient.endsWith(fallbackSuffix)) {
          const booking = {
            id: info.id,
            check_in: info.check_in,
            check_out: info.check_out,
            total_price: info.total_price,
            hotel_name: info.hotel_name,
            room_number: info.room_number,
            room_type: info.room_type,
            nights: info.nights,
            user_name: info.user_name,
          };
          const payment = {
            amount_minor: paymentIntent.amount,
            currency: paymentIntent.currency,
            transaction_id: paymentIntent.id,
          };
          sendPaymentReceipt({ to: recipient, booking, payment }).catch(err => {
            console.error('Failed to send payment receipt email', err);
          });
        }

        return res.json({ received: true });
      }

      if (event.type === "payment_intent.payment_failed") {
        const paymentIntent = event.data.object;
        await conn.query(
          "UPDATE payments SET status='failed' WHERE transaction_id=?",
          [paymentIntent.id]
        );

        const bookingId = paymentIntent.metadata?.booking_id;
        let info = null;
        if (bookingId) {
          const [[row]] = await conn.query(
            `SELECT b.id, b.check_in, b.check_out, b.total_price,
                    u.email AS user_email, u.name AS user_name
               FROM bookings b JOIN users u ON u.id=b.user_id
              WHERE b.id=? LIMIT 1`,
            [bookingId]
          );
          info = row;
        }

        await conn.commit();

        if (info) {
          const recipient = info?.user_email;
          const fallbackSuffix = '@firebase-user.stayeasy';
          if (recipient && !recipient.endsWith(fallbackSuffix)) {
            const booking = {
              id: info.id,
              check_in: info.check_in,
              check_out: info.check_out,
              total_price: info.total_price,
              user_name: info.user_name,
            };
            const payment = {
              amount_minor: paymentIntent.amount,
              currency: paymentIntent.currency,
              transaction_id: paymentIntent.id,
            };
            sendPaymentFailed({ to: recipient, booking, payment }).catch(err => {
              console.error('Failed to send payment failure email', err);
            });
          }
        }

        return res.json({ received: true });
      }

      // For other event types, just acknowledge
      await conn.commit();
      return res.json({ received: true });
    } catch (txErr) {
      try { await conn.rollback(); } catch (_) {}
      throw txErr;
    } finally {
      conn.release();
    }
  } catch (err) {
    console.error("Stripe webhook error:", err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
  }
};

export const confirmPaymentDemo = async (req, res, next) => {
  try {
    const { booking_id, amount, currency = "vnd" } = req.body;
    if (!booking_id || amount == null) {
      return res.status(400).json({ message: "booking_id and amount are required", code: "VALIDATION_ERROR" });
    }

    const [rows] = await pool.query(
      "SELECT id FROM bookings WHERE id = ? LIMIT 1",
      [booking_id],
    );
    if (!rows.length) return res.status(404).json({ message: "Booking not found", code: "NOT_FOUND" });

    const hasCurrencyColumn = await paymentsHasCurrencyColumn(pool);
    const methodAllowedValues = await paymentsMethodAllowedValues(pool);
    const statusAllowedValues = await paymentsStatusAllowedValues(pool);

    const pickFromEnum = (requested, allowedValues, fallbacks = []) => {
      if (!Array.isArray(allowedValues) || !allowedValues.length) {
        return requested;
      }
      if (allowedValues.includes(requested)) {
        return requested;
      }
      for (const candidate of fallbacks) {
        if (allowedValues.includes(candidate)) {
          return candidate;
        }
      }
      return allowedValues[0];
    };

    const dbMethod = pickFromEnum("stripe_card", methodAllowedValues, [
      "stripe",
      "credit_card",
      "card",
      "online",
    ]);
    const dbStatus = pickFromEnum("completed", statusAllowedValues, [
      "confirmed",
      "paid",
      "completed",
    ]);

    const demoTxId = `demo_${Date.now()}`;
    const insertColumns = [
      "booking_id",
      "amount",
      "method",
      "status",
      "transaction_id",
      "provider",
    ];
    const updateSet = [
      "amount=VALUES(amount)",
      "status=VALUES(status)",
      "provider=VALUES(provider)",
      "method=VALUES(method)",
      "transaction_id=VALUES(transaction_id)",
    ];
    const params = [booking_id, amount, dbMethod, dbStatus, demoTxId, "stripe"];
    if (hasCurrencyColumn) {
      insertColumns.push("currency");
      updateSet.push("currency=VALUES(currency)");
      params.push(currency);
    }
    const placeholders = insertColumns.map(() => "?").join(", ");
    const sql = `INSERT INTO payments (${insertColumns.join(", ")})
       VALUES (${placeholders})
       ON DUPLICATE KEY UPDATE ${updateSet.join(", ")}`;
    await pool.query(sql, params);

    await pool.query("UPDATE bookings SET status='completed' WHERE id=?", [booking_id]);

    const [[info]] = await pool.query(
      `SELECT b.id, b.check_in, b.check_out, b.total_price,
              u.email AS user_email, u.name AS user_name,
              r.room_number, r.type AS room_type, r.price_per_night,
              h.name AS hotel_name,
              GREATEST(DATEDIFF(b.check_out, b.check_in), 1) AS nights
         FROM bookings b
         JOIN users u ON u.id=b.user_id
         JOIN rooms r ON r.id=b.room_id
         JOIN hotels h ON h.id=r.hotel_id
        WHERE b.id=? LIMIT 1`,
      [booking_id]
    );

    const recipient = info?.user_email;
    const fallbackSuffix = '@firebase-user.stayeasy';
    if (recipient && !recipient.endsWith(fallbackSuffix)) {
      const booking = {
        id: info.id,
        check_in: info.check_in,
        check_out: info.check_out,
        total_price: info.total_price,
        hotel_name: info.hotel_name,
        room_number: info.room_number,
        room_type: info.room_type,
        nights: info.nights,
        user_name: info.user_name,
      };
      const threeLetter = String(currency || '').toLowerCase();
      const ZERO_DECIMAL = new Set([
        "bif","clp","djf","gnf","jpy","kmf","krw","mga","pyg","rwf","ugx",
        "vnd","vuv","xaf","xof","xpf",
      ]);
      const numericAmount = Number(amount);
      const amountMinor = ZERO_DECIMAL.has(threeLetter)
        ? Math.round(numericAmount)
        : Math.round(numericAmount * 100);
      const payment = {
        amount_minor: amountMinor,
        currency: threeLetter || 'vnd',
        transaction_id: demoTxId,
      };
      await sendPaymentReceipt({ to: recipient, booking, payment });
    }

    return res.json({
      data: {
        booking_id,
        amount: Number(amount),
        currency,
        status: 'completed',
      },
    });
  } catch (err) {
    next(err);
  }
};
