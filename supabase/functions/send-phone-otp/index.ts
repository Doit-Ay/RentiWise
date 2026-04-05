// Supabase Edge Function: send-phone-otp
// Sends a real SMS via MSG91 with a 6-digit OTP
// Set these secrets in Supabase Dashboard → Project Settings → Edge Functions → Secrets:
//   MSG91_AUTH_KEY, MSG91_TEMPLATE_ID

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  try {
    const { phone, user_id } = await req.json();
    if (!phone || !user_id) {
      return new Response(JSON.stringify({ error: "phone and user_id required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[send-phone-otp] Sending OTP to ${phone} for user ${user_id}`);

    // Generate 6-digit OTP
    const otp = String(Math.floor(100000 + Math.random() * 900000));

    // SHA-256 hash
    const encoder = new TextEncoder();
    const data = encoder.encode(otp);
    const hashBuffer = await crypto.subtle.digest("SHA-256", data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const otpHash = hashArray.map(b => b.toString(16).padStart(2, "0")).join("");

    // Expiry: 5 minutes from now
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();

    // Store hash in users table
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceKey);

    const { error: dbError } = await supabase
      .from("users")
      .update({
        phone: phone,
        phone_otp_hash: otpHash,
        phone_otp_expires_at: expiresAt,
      })
      .eq("id", user_id);

    if (dbError) {
      console.error("[send-phone-otp] DB error:", dbError.message);
      return new Response(JSON.stringify({ error: "DB error: " + dbError.message }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Send SMS via MSG91
    const msg91AuthKey = Deno.env.get("MSG91_AUTH_KEY") || "505958A7DLtRhHn69d1653bP1";
    // IMPORTANT: Set MSG91_TEMPLATE_ID to your actual numeric template ID from MSG91 dashboard
    // e.g. "6612a1234d6fc812345678ab" — NOT the template name
    const msg91TemplateId = Deno.env.get("MSG91_TEMPLATE_ID") || "69d1730dfc71fe9096014012";

    if (!msg91TemplateId) {
      console.error("[send-phone-otp] MSG91_TEMPLATE_ID is not set!");
      return new Response(JSON.stringify({ error: "MSG91 template ID not configured. Set MSG91_TEMPLATE_ID in Edge Function secrets." }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Clean phone number — MSG91 requires country code but NO '+' sign (e.g., 919999999999)
    const cleanPhone = phone.replace("+", "");

    console.log(`[send-phone-otp] Calling MSG91 OTP API for ${cleanPhone}, template=${msg91TemplateId}`);

    // MSG91 OTP API: pass template_id and mobile as query params, otp in query, and
    // also send OTP value in body for template variable substitution (##OTP## placeholder)
    const msg91Url = `https://control.msg91.com/api/v5/otp?template_id=${encodeURIComponent(msg91TemplateId)}&mobile=${cleanPhone}&otp=${otp}`;
    const msg91Resp = await fetch(msg91Url, {
      method: "POST",
      headers: {
        "authkey": msg91AuthKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        OTP: otp,
        otp: otp
      }),
    });

    const respText = await msg91Resp.text();
    console.log(`[send-phone-otp] MSG91 response status=${msg91Resp.status}, body=${respText}`);

    // MSG91 returns 200 even on some errors — check the response body
    let msg91Ok = msg91Resp.ok;
    try {
      const parsed = JSON.parse(respText);
      // MSG91 returns { "type": "success" } on success
      // and { "type": "error", "message": "..." } on failure
      if (parsed.type === "error") {
        msg91Ok = false;
      }
    } catch {
      // Non-JSON response — check HTTP status only
    }

    if (!msg91Ok) {
      console.error("[send-phone-otp] MSG91 error:", respText);
      return new Response(JSON.stringify({ error: `MSG91 Error: ${respText}` }), {
        status: 200, // Return 200 so Swift can parse the JSON error
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[send-phone-otp] OTP sent successfully to ${cleanPhone}`);

    return new Response(JSON.stringify({ 
      success: true, 
      message: "OTP sent via SMS",
      msg91_response: respText 
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("[send-phone-otp] Unexpected error:", err);
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }
});
