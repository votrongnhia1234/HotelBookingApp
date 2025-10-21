import Stripe from "stripe";

const ZERO_DECIMAL_CURRENCIES = new Set([
  "bif", "clp", "djf", "gnf", "jpy", "kmf", "krw", "mga", "pyg", "rwf", "ugx",
  "vnd", "vuv", "xaf", "xof", "xpf",
]);

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
  apiVersion: "2024-06-20",
});

export { stripe };

const normalizeAmount = (amount, currency) => {
  const numeric = Number(amount);
  if (!Number.isFinite(numeric) || numeric <= 0) {
    throw new Error("Invalid payment amount");
  }
  const threeLetter = String(currency || "").toLowerCase();
  if (ZERO_DECIMAL_CURRENCIES.has(threeLetter)) {
    return Math.round(numeric);
  }
  return Math.round(numeric * 100);
};

export async function createPaymentIntent({ amount, currency = "usd", metadata = {} }) {
  const normalizedAmount = normalizeAmount(amount, currency);
  return stripe.paymentIntents.create({
    amount: normalizedAmount,
    currency,
    metadata,
    automatic_payment_methods: { enabled: true },
  });
}
