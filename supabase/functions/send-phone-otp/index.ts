// Supabase Edge Function: send-phone-otp
// Sends a real SMS via MSG91 with a 6-digit OTP
// Set these secrets in Supabase Dashboard → Project Settings → Edge Functions → Secrets:
//   MSG91_AUTH_KEY, MSG91_TEMPLATE_ID

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const json = (payload: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    const { phone, user_id } = await req.json();
    if (!phone || !user_id) {
      return json({ error: "phone and user_id required" }, 400);
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
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    });

    const {
      data: { user },
      error: authError,
    } = await authClient.auth.getUser();

    if (authError || !user) {
      console.error("[send-phone-otp] Auth error:", authError?.message ?? "Unauthorized");
      return json({ error: "Unauthorized" }, 401);
    }

    if (user.id !== user_id) {
      return json({ error: "Authenticated user does not match the requested user." }, 403);
    }

    const cleanPhone = String(phone).trim().replace(/^\+/, "");
    if (!/^\d{10,15}$/.test(cleanPhone)) {
      return json({ error: "Phone number must include 10 to 15 digits." }, 400);
    }

    console.log(`[send-phone-otp] Sending OTP to ${cleanPhone} for user ${user_id}`);

    const msg91AuthKey = Deno.env.get("MSG91_AUTH_KEY");
    const msg91TemplateId = Deno.env.get("MSG91_TEMPLATE_ID");

    if (!msg91AuthKey || !msg91TemplateId) {
      console.error("[send-phone-otp] MSG91 secrets are not configured.");
      return json({ error: "MSG91 secrets are not configured." }, 500);
    }

    const otp = String(Math.floor(100000 + Math.random() * 900000));

    // SHA-256 hash
    const encoder = new TextEncoder();
    const data = encoder.encode(otp);
    const hashBuffer = await crypto.subtle.digest("SHA-256", data);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const otpHash = hashArray.map(b => b.toString(16).padStart(2, "0")).join("");

    // Expiry: 5 minutes from now
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();

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
      return json({ error: `MSG91 Error: ${respText}` }, 502);
    }

    const supabase = createClient(supabaseUrl, serviceKey);
    const { error: dbError } = await supabase
      .from("users")
      .update({
        phone: `+${cleanPhone}`,
        phone_otp_hash: otpHash,
        phone_otp_expires_at: expiresAt,
      })
      .eq("id", user.id);

    if (dbError) {
      console.error("[send-phone-otp] DB error:", dbError.message);
      return json({ error: "DB error: " + dbError.message }, 500);
    }

    console.log(`[send-phone-otp] OTP sent successfully to ${cleanPhone}`);

    return json({
      success: true,
      message: "OTP sent via SMS",
    });

  } catch (err) {
    console.error("[send-phone-otp] Unexpected error:", err);
    return json({ error: (err as Error).message }, 500);
  }
});
