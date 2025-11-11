// supabase/functions/event-created/index.ts
// Deno Deploy target
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
 
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!; // service key
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY")!; // de Firebase (Cloud Messaging)

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

type EventPayload = {
  id: number;
  city_id: number;    
  lat: number;
  lng: number;
  title: string;
  starts_at: string;
};

async function sendPushToTokens(tokens: string[], title: string, body: string, data: Record<string,string>) {
  if (tokens.length === 0) return;

  // FCM "multicast" con HTTP v1 legacy (simple). Para HTTP v1 moderno, usa OAuth; esto es rápido de integrar.
  const res = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `key=${FCM_SERVER_KEY}`,
    },
    body: JSON.stringify({
      registration_ids: tokens,
      notification: { title, body },
      data,
      priority: "high",
      android: { priority: "high" }
    }),
  });
  if (!res.ok) {
    const txt = await res.text();
    console.error("FCM error:", txt);
  }
}

serve(async (req) => {
  try {
    // Opcional: validar header Authorization si vienes desde trigger
    const payload = await req.json() as EventPayload;

    // 1) Buscar usuarios cercanos
    const { data: nearUsers, error: nearErr } = await supabase
    .rpc("users_for_event_city", { p_city_id: payload.city_id })

    if (nearErr) throw nearErr;

    const userIds = (nearUsers ?? []).map((u: any) => u.user_id);
    // 2) Obtener tokens de esos usuarios
    const { data: tokensRows, error: tokErr } = await supabase
    .from("device_tokens").select("fcm_token")
    .in("user_id", userIds);


    // 3) Enviar push
    await sendPushToTokens(tokens, payload.title, body, data);

    return new Response(JSON.stringify({ ok: true, sent: tokens.length }), { headers: { "Content-Type": "application/json" }});
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 });
  }
});
