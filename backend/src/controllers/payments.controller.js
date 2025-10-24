import pool from "../config/db.js";
import { createPaymentIntent, stripe } from "../services/stripe.service.js";
import {
  paymentsHasCurrencyColumn,
  paymentsMethodAllowedValues,
  paymentsStatusAllowedValues,
} from "../utils/schema.js";

const ONLINE_METHOD = "online";

export const createPayment = async (req, res, next) => {
  try {
    const { booking_id, amount, method = ONLINE_METHOD, currency = "usd" } = req.body;
    if (!booking_id || amount == null) {
      return res.status(400).json({ message: "booking_id and amount are required" });
    }

    const [rows] = await pool.query(
      "SELECT id, status FROM bookings WHERE id = ? LIMIT 1",
      [booking_id],
    );
    if (!rows.length) return res.status(404).json({ message: "Booking not found" });
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

    if (event.type === "payment_intent.succeeded") {
      const paymentIntent = event.data.object;
      const bookingId = paymentIntent.metadata.booking_id;

      await pool.query(
        "UPDATE payments SET status='completed' WHERE transaction_id=?",
        [paymentIntent.id],
      );
      await pool.query("UPDATE bookings SET status='completed' WHERE id=?", [bookingId]);
    }

    if (event.type === "payment_intent.payment_failed") {
      const paymentIntent = event.data.object;
      await pool.query(
        "UPDATE payments SET status='failed' WHERE transaction_id=?",
        [paymentIntent.id],
      );
    }

    res.json({ received: true });
  } catch (err) {
    console.error("Stripe webhook error:", err.message);
    res.status(400).send(`Webhook Error: ${err.message}`);
  }
};
