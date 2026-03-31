// supabase/functions/delete-account/index.ts
//
// Supabase Edge Function to fully delete a user's RentiWise account data
// and Supabase Auth identity in one backend-controlled flow.
//
// Apple Guideline 5.1.1(v): Account deletion must remove all user data,
// including the authentication identity.
//
// Deploy:  supabase functions deploy delete-account --no-verify-jwt
// (JWT verification is done manually below for better error messages)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json",
};

type AdminClient = ReturnType<typeof createClient>;
type OwnedItemRow = {
  id: string;
  images: string[] | null;
};
type IdRow = {
  id: string;
};
type ReturnRequestMediaRow = {
  proof_media: string[] | null;
};

function json(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

async function ensureDelete(
  label: string,
  operation: PromiseLike<{ error: { message: string } | null }>
) {
  const { error } = await operation;
  if (error) {
    throw new Error(`${label}: ${error.message}`);
  }
}

async function removeStoragePaths(
  adminClient: AdminClient,
  bucket: string,
  paths: Array<string | null | undefined>
) {
  const uniquePaths = [
    ...new Set(paths.filter((path): path is string => Boolean(path && path.trim()))),
  ];
  if (!uniquePaths.length) return;

  const { error } = await adminClient.storage.from(bucket).remove(uniquePaths);
  if (error) {
    throw new Error(`Failed to remove ${bucket} files: ${error.message}`);
  }
}

async function deleteRentiWiseData(adminClient: AdminClient, user: { id: string; email?: string | null }) {
  const userId = user.id;
  const userEmail = user.email?.trim() || null;

  const [
    ownedItemsResult,
    requestRowsResult,
    supportTicketRowsResult,
    chatConversationRowsResult,
  ] = await Promise.all([
    adminClient.from("items").select("id,images").eq("owner_id", userId),
    adminClient.from("requests").select("id").or(`borrower_id.eq.${userId},owner_id.eq.${userId}`),
    adminClient.from("support_tickets").select("id").eq("user_id", userId),
    adminClient.from("chat_conversations").select("id").or(`lender_id.eq.${userId},borrower_id.eq.${userId}`),
  ]);

  if (ownedItemsResult.error) throw new Error(`Failed to load owned items: ${ownedItemsResult.error.message}`);
  if (requestRowsResult.error) throw new Error(`Failed to load requests: ${requestRowsResult.error.message}`);
  if (supportTicketRowsResult.error) throw new Error(`Failed to load support tickets: ${supportTicketRowsResult.error.message}`);
  if (chatConversationRowsResult.error) throw new Error(`Failed to load chat conversations: ${chatConversationRowsResult.error.message}`);

  const ownedItems = (ownedItemsResult.data ?? []) as OwnedItemRow[];
  const requestIds = ((requestRowsResult.data ?? []) as IdRow[]).map((row) => row.id);
  const supportTicketIds = ((supportTicketRowsResult.data ?? []) as IdRow[]).map((row) => row.id);
  const chatConversationIds = ((chatConversationRowsResult.data ?? []) as IdRow[]).map((row) => row.id);
  const ownedItemIds = ownedItems.map((item) => item.id);
  const ownedItemImagePaths = ownedItems.flatMap((item) => item.images ?? []);

  if (requestIds.length) {
    const returnRequestMediaResult = await adminClient
      .from("return_requests")
      .select("proof_media")
      .in("request_id", requestIds);

    if (returnRequestMediaResult.error) {
      throw new Error(`Failed to load return proof media: ${returnRequestMediaResult.error.message}`);
    }

    const returnProofPaths = ((returnRequestMediaResult.data ?? []) as ReturnRequestMediaRow[])
      .flatMap((row) => row.proof_media ?? []);

    await removeStoragePaths(adminClient, "itemimages", returnProofPaths);

    await ensureDelete(
      "Failed to delete rental agreements",
      adminClient.from("rental_agreements").delete().in("request_id", requestIds)
    );
    await ensureDelete(
      "Failed to delete return reports",
      adminClient.from("return_reports").delete().in("request_id", requestIds)
    );
    await ensureDelete(
      "Failed to delete return requests",
      adminClient.from("return_requests").delete().in("request_id", requestIds)
    );
    await ensureDelete(
      "Failed to delete extension requests",
      adminClient.from("extension_requests").delete().in("request_id", requestIds)
    );
  }

  if (chatConversationIds.length) {
    await ensureDelete(
      "Failed to delete chat messages",
      adminClient.from("chat_messages").delete().in("conversation_id", chatConversationIds)
    );
    await ensureDelete(
      "Failed to delete chat conversations",
      adminClient.from("chat_conversations").delete().in("id", chatConversationIds)
    );
  } else {
    await ensureDelete(
      "Failed to delete direct chat messages",
      adminClient.from("chat_messages").delete().eq("sender_id", userId)
    );
  }

  if (supportTicketIds.length) {
    await ensureDelete(
      "Failed to delete support messages",
      adminClient.from("support_messages").delete().in("ticket_id", supportTicketIds)
    );
  } else {
    await ensureDelete(
      "Failed to delete direct support messages",
      adminClient.from("support_messages").delete().eq("sender_id", userId)
    );
  }

  if (requestIds.length) {
    await ensureDelete(
      "Failed to delete requests",
      adminClient.from("requests").delete().or(`borrower_id.eq.${userId},owner_id.eq.${userId}`)
    );
  }

  if (ownedItemIds.length) {
    await ensureDelete(
      "Failed to delete wishlist references",
      adminClient.from("wishlist").delete().in("item_id", ownedItemIds)
    );
    await ensureDelete(
      "Failed to delete reviews for owned items",
      adminClient.from("reviews").delete().in("item_id", ownedItemIds)
    );
  }

  await removeStoragePaths(adminClient, "itemimages", ownedItemImagePaths);

  await ensureDelete(
    "Failed to delete owned items",
    adminClient.from("items").delete().eq("owner_id", userId)
  );

  if (userEmail) {
    await ensureDelete(
      "Failed to delete verification codes",
      adminClient.from("verification_codes").delete().eq("email", userEmail)
    );
  }

  await ensureDelete(
    "Failed to delete authored reviews",
    adminClient.from("reviews").delete().eq("reviewer_id", userId)
  );
  await ensureDelete(
    "Failed to delete remaining support messages",
    adminClient.from("support_messages").delete().eq("sender_id", userId)
  );
  await ensureDelete(
    "Failed to delete support tickets",
    adminClient.from("support_tickets").delete().eq("user_id", userId)
  );
  await ensureDelete(
    "Failed to delete addresses",
    adminClient.from("addresses").delete().eq("user_id", userId)
  );
  await ensureDelete(
    "Failed to delete viewer distance cache",
    adminClient.from("user_item_distances").delete().eq("viewer_user_id", userId)
  );
  await ensureDelete(
    "Failed to delete owner distance cache",
    adminClient.from("user_item_distances").delete().eq("owner_user_id", userId)
  );
  await ensureDelete(
    "Failed to delete wishlist entries",
    adminClient.from("wishlist").delete().eq("user_id", userId)
  );
  await ensureDelete(
    "Failed to delete public profile",
    adminClient.from("user_profiles").delete().eq("id", userId)
  );
  await ensureDelete(
    "Failed to delete user record",
    adminClient.from("users").delete().eq("id", userId)
  );
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    // 1. Validate Authorization header
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return json({ error: "Missing or invalid Authorization header" }, 401);
    }

    const jwt = authHeader.replace("Bearer ", "");

    // 2. Create a Supabase client with the user's JWT to verify identity
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
    });

    // Verify the JWT is valid and get the user
    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return json({ error: "Invalid or expired token" }, 401);
    }

    // 3. Parse body to get user_id and verify it matches the JWT
    const body = await req.json().catch(() => ({}));
    const requestedUserId = body.user_id;
    const dryRun = body.dry_run === true;

    if (requestedUserId && requestedUserId.toLowerCase() !== user.id.toLowerCase()) {
      return json({ error: "user_id does not match authenticated user" }, 403);
    }

    // 4. Create an admin client with service_role key to manage deletion
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    if (dryRun) {
      return json({ success: true, available: true });
    }

    await deleteRentiWiseData(adminClient, user);

    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);

    if (deleteError) {
      console.error("[delete-account] Admin deleteUser failed:", deleteError);
      return json(
        {
          error: "Failed to delete auth identity",
          details: deleteError.message,
        },
        500
      );
    }

    console.log(`[delete-account] Successfully deleted account and auth identity for user ${user.id}`);

    return json({ success: true });
  } catch (err) {
    console.error("[delete-account] Unexpected error:", err);
    return json(
      {
        error: "Internal server error",
        details: err instanceof Error ? err.message : "Unknown error",
      },
      500
    );
  }
});
