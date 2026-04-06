import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (payload: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });

const sha256Hex = async (value: string) => {
  const buffer = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(buffer))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
};

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const { request_id, otp } = await req.json();

    if (!request_id || !otp) {
      return json({ success: false, error: "request_id and otp are required" }, 400);
    }

    const normalizedOTP = String(otp).trim();
    if (!/^\d{4}$/.test(normalizedOTP)) {
      return json({ success: false, error: "Enter the full 4-digit return code." }, 200);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing authorization token" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !anonKey || !serviceKey) {
      return json({ error: "Supabase environment variables are not configured." }, 500);
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: authError,
    } = await authClient.auth.getUser();

    if (authError || !user) {
      return json({ error: "Unauthorized" }, 401);
    }

    const serviceClient = createClient(supabaseUrl, serviceKey);

    const { data: booking, error: bookingError } = await serviceClient
      .from("requests")
      .select("id, borrower_id, owner_id, item_id, status")
      .eq("id", request_id)
      .single();

    if (bookingError || !booking) {
      return json({ success: false, error: "Rental request not found." }, 404);
    }

    if (booking.borrower_id !== user.id) {
      return json({ error: "Only the borrower can verify this return code." }, 403);
    }

    const bookingStatus = String(booking.status ?? "").trim().toLowerCase();

    const { data: returnRequests, error: returnError } = await serviceClient
      .from("return_requests")
      .select("id, status")
      .eq("request_id", request_id)
      .order("created_at", { ascending: false })
      .limit(1);

    if (returnError) {
      return json({ error: `Could not load the return request: ${returnError.message}` }, 500);
    }

    const latest = returnRequests?.[0];
    if (!latest) {
      return json({ success: false, error: "No approved return request was found." }, 200);
    }

    const returnStatus = String(latest.status ?? "").trim().toLowerCase();
    const alreadyCompleted = bookingStatus === "completed" || returnStatus === "completed";

    if (!alreadyCompleted && returnStatus !== "accepted") {
      return json({ success: false, error: "The lender has not approved the return yet." }, 200);
    }

    const { data: payments, error: paymentError } = await serviceClient
      .from("payments")
      .select("id")
      .eq("request_id", request_id)
      .order("created_at", { ascending: false })
      .limit(1);

    if (paymentError) {
      return json({ error: `Could not load payment context: ${paymentError.message}` }, 500);
    }

    const paymentId = payments?.[0]?.id;
    if (!paymentId) {
      return json({ success: false, error: "No payment record was found for this rental." }, 200);
    }

    const { data: generatedEvents, error: generatedError } = await serviceClient
      .from("payment_events")
      .select("raw_payload, created_at")
      .eq("payment_id", paymentId)
      .eq("event_type", "return_code_generated")
      .order("created_at", { ascending: false })
      .limit(1);

    if (generatedError) {
      return json({ error: `Could not load the latest return code: ${generatedError.message}` }, 500);
    }

    const generated = generatedEvents?.[0];
    const payload =
      generated?.raw_payload && typeof generated.raw_payload === "string"
        ? JSON.parse(generated.raw_payload)
        : generated?.raw_payload ?? null;

    const storedHash = payload?.otp_hash;
    const expiresAt = payload?.expires_at;

    if (!alreadyCompleted && (!storedHash || !expiresAt)) {
      return json({ success: false, error: "The lender has not generated a return code yet." }, 200);
    }

    const expiry = new Date(expiresAt);
    if (!alreadyCompleted && (Number.isNaN(expiry.getTime()) || expiry.getTime() < Date.now())) {
      return json({ success: false, error: "This return code expired. Ask the lender to regenerate it." }, 200);
    }

    const hashedInput = await sha256Hex(normalizedOTP);
    if (!alreadyCompleted && hashedInput !== storedHash) {
      return json({ success: false, error: "Incorrect return code. Please try again." }, 200);
    }

    const { error: requestUpdateError } = await serviceClient
      .from("requests")
      .update({ status: "completed" })
      .eq("id", request_id);

    if (requestUpdateError) {
      return json({ error: `Could not complete the rental: ${requestUpdateError.message}` }, 500);
    }

    const { error: returnUpdateError } = await serviceClient
      .from("return_requests")
      .update({ status: "completed" })
      .eq("id", latest.id)
      .eq("request_id", request_id);

    if (returnUpdateError) {
      return json({ error: `Could not complete the return request: ${returnUpdateError.message}` }, 500);
    }

    const { error: itemUpdateError } = await serviceClient
      .from("items")
      .update({ is_active: true })
      .eq("id", booking.item_id)
      .eq("owner_id", booking.owner_id);

    if (itemUpdateError) {
      return json({ error: `Could not reactivate the item: ${itemUpdateError.message}` }, 500);
    }

    if (!alreadyCompleted) {
      const { error: verifyEventError } = await serviceClient
        .from("payment_events")
        .insert({
          payment_id: paymentId,
          event_type: "return_code_verified",
          raw_payload: {
            request_id,
            return_request_id: latest.id,
            verified_at: new Date().toISOString(),
          },
        });

      if (verifyEventError) {
        return json({ error: `Return verified, but the verification event could not be stored: ${verifyEventError.message}` }, 500);
      }
    }

    return json({ success: true }, 200);
  } catch (error) {
    console.error("[verify-return-otp] Unexpected error:", error);
    return json({ error: (error as Error).message }, 500);
  }
});
