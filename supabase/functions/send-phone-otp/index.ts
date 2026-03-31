// Supabase Edge Function: send-phone-otp
// Sends a real SMS via Twilio with a 6-digit OTP
// Set these secrets in Supabase Dashboard → Project Settings → Edge Functions → Secrets:
//   TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  try {
    const { phone, user_id } = await req.json();
    if (!phone || !user_id) {
      return new Response(JSON.stringify({ error: "phone and user_id required" }), { status: 400 });
    }

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
      return new Response(JSON.stringify({ error: "DB error: " + dbError.message }), { status: 500 });
    }

    // Send SMS via Twilio
    const twilioSid = Deno.env.get("TWILIO_ACCOUNT_SID")!;
    const twilioToken = Deno.env.get("TWILIO_AUTH_TOKEN")!;
    const twilioPhone = Deno.env.get("TWILIO_PHONE_NUMBER")!;

    const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${twilioSid}/Messages.json`;
    const credentials = btoa(`${twilioSid}:${twilioToken}`);

    const smsBody = `Your RentiWise verification code is: ${otp}. Valid for 5 minutes. Do not share this code.`;

    const twilioResp = await fetch(twilioUrl, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${credentials}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({
        To: phone,
        From: twilioPhone,
        Body: smsBody,
      }),
    });

    if (!twilioResp.ok) {
      const errText = await twilioResp.text();
      console.error("Twilio error:", errText);
      return new Response(JSON.stringify({ error: `Twilio Error: ${errText}` }), { 
        status: 200, // Return 200 so Swift can parse the JSON error instead of throwing generic 502
        headers: { "Content-Type": "application/json" }
      });
    }

    return new Response(JSON.stringify({ success: true, message: "OTP sent via SMS" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });

  } catch (err) {
    console.error("send-phone-otp error:", err);
    return new Response(JSON.stringify({ error: err.message }), { status: 500 });
  }
});
