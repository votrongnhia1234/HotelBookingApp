import { z } from "zod";

export const createPaymentSchema = z.object({
  booking_id: z.number().int().positive({ message: "booking_id phải là số > 0" }),
  amount: z.number().min(0, { message: "amount phải >= 0" }),
  method: z.string().optional(),
  currency: z.string().optional(),
});

export const confirmPaymentDemoSchema = z.object({
  booking_id: z.number().int().positive({ message: "booking_id phải là số > 0" }),
  amount: z.number().min(0, { message: "amount phải >= 0" }),
  currency: z.string().optional(),
});