import { z } from "zod";

const dateRegex = /^\d{4}-\d{2}-\d{2}$/;

export const createBookingSchema = z.object({
  room_id: z.number().int().positive({ message: "room_id phải là số > 0" }),
  check_in: z.string().regex(dateRegex, { message: "check_in phải có định dạng YYYY-MM-DD" }),
  check_out: z.string().regex(dateRegex, { message: "check_out phải có định dạng YYYY-MM-DD" }),
}).refine((data) => data.check_out > data.check_in, {
  message: "check_out phải sau check_in",
  path: ["check_out"],
});

export const updateBookingStatusSchema = z.object({
  status: z.enum(["pending", "confirmed", "cancelled"], {
    message: "Trạng thái phải là pending, confirmed hoặc cancelled",
  }),
});