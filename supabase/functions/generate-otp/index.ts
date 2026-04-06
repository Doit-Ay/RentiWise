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
    const { request_id, type } = await req.json();

    if (!request_id || type !== "return") {
      return json({ error: "request_id and type='return' are required" }, 400);
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
      .select("id, owner_id, status")
      .eq("id", request_id)
      .single();

    if (bookingError || !booking) {
      return json({ error: "Rental request not found." }, 404);
    }

    if (booking.owner_id !== user.id) {
      return json({ error: "Only the lender can generate a return code." }, 403);
    }

    const bookingStatus = String(booking.status ?? "").trim().toLowerCase();
    if (!["approved", "returned", "completed"].includes(bookingStatus)) {
      return json({ error: "Return codes are only available for active rentals." }, 400);
    }

    const { data: returnRequests, error: returnError } = await serviceClient
      .from("return_requests")
      .select("id, status")
      .eq("request_id", request_id)
      .order("created_at", { ascending: false })
      .limit(1);

    if (returnError) {
      return json({ error: `Could not load return request: ${returnError.message}` }, 500);
    }

    const latest = returnRequests?.[0];
    if (!latest) {
      return json({ error: "No return request was found for this rental." }, 404);
    }

    const returnStatus = String(latest.status ?? "").trim().toLowerCase();
    if (returnStatus === "completed") {
      return json({ error: "This return has already been completed." }, 409);
    }

    if (!["pending", "accepted"].includes(returnStatus)) {
      return json({ error: "This return request is not eligible for a handoff code." }, 400);
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
      return json({ error: "No payment record was found for this rental." }, 400);
    }

    const otp = String(Math.floor(1000 + Math.random() * 9000));
    const otpHash = await sha256Hex(otp);
    const nowIso = new Date().toISOString();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const { error: returnUpdateError } = await serviceClient
      .from("return_requests")
      .update({ status: "accepted" })
      .eq("id", latest.id)
      .eq("request_id", request_id);

    if (returnUpdateError) {
      return json({ error: `Could not mark the return as approved: ${returnUpdateError.message}` }, 500);
    }

    const { error: eventError } = await serviceClient
      .from("payment_events")
      .insert({
        payment_id: paymentId,
        event_type: "return_code_generated",
        raw_payload: {
          request_id,
          return_request_id: latest.id,
          otp_hash: otpHash,
          expires_at: expiresAt,
          generated_at: nowIso,
        },
      });

    if (eventError) {
      return json({ error: `Could not store the return code: ${eventError.message}` }, 500);
    }

    return json({
      success: true,
      otp,
      expires_at: expiresAt,
    });
  } catch (error) {
    console.error("[generate-otp] Unexpected error:", error);
    return json({ error: (error as Error).message }, 500);
  }
});
