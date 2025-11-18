// supabase/functions/notify-new-activity/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://deno.land/x/jose@v4.14.4/index.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") 

const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
if (!raw) {
  throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON no configurado");
}
const serviceAccount = JSON.parse(raw);

if (!supabaseUrl) {
  console.error("Falta SUPABASE_URL/_SUPABASE_URL en las env vars");
  throw new Error("SUPABASE_URL no configurado");
}
if (!serviceRoleKey) {
  console.error("Falta SUPABASE_SERVICE_ROLE_KEY/_SUPABASE_SERVICE_ROLE_KEY");
  throw new Error("SUPABASE_SERVICE_ROLE_KEY no configurado");
}

const supabase = createClient(supabaseUrl, serviceRoleKey);

// ---------- Helper: obtener access token para FCM HTTP v1 ----------
async function getAccessToken(serviceAccount: any): Promise<string> {
  const privateKey = serviceAccount.private_key as string;
  const clientEmail = serviceAccount.client_email as string;

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: clientEmail,
    sub: clientEmail,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const alg = "RS256";
  const pk = await jose.importPKCS8(privateKey, alg);

  const jwt = await new jose.SignJWT(payload)
    .setProtectedHeader({ alg, typ: "JWT" })
    .sign(pk);

  const tokenResp = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResp.ok) {
    const text = await tokenResp.text();
    console.error("Error obteniendo access token FCM:", text);
    throw new Error("No se pudo obtener access token de FCM");
  }

  const json = await tokenResp.json() as { access_token?: string };
  if (!json.access_token) {
    throw new Error("Respuesta FCM sin access_token");
  }

  return json.access_token;
}

serve(async (req) => {
  console.log("notify-new-activity: request", new Date().toISOString());

  if (req.method !== "POST") {
    return new Response("Only POST", { status: 405 });
  }

  try {

    const body = await req.json();
    console.log("notify-new-activity: body recibido:", body);

    const activityId = body.activity_id as string | undefined;

    if (!activityId) {
      console.warn("activity_id no enviado en el body");
      return new Response(
        JSON.stringify({ error: "activity_id requerido" }),
        { status: 400 },
      );
    }

    // 1) Obtener la actividad (ahora también sport_id)
    const { data: activity, error: activityError } = await supabase
      .from("actividades")
      .select(
        "id, title, date, region_id, comuna_id, sport_id, place_name, formatted_address, creator_id",
      )
      .eq("id", activityId)
      .single();

    console.log("Actividad cargada:", activity);

    if (activityError || !activity) {
      console.error("Error obteniendo actividad:", activityError);
      return new Response(
        JSON.stringify({ error: "Actividad no encontrada" }),
        { status: 404 },
      );
    }

    const regionId = activity.region_id as number | null | undefined;
    const comunaId = activity.comuna_id as number | null | undefined;
    const sportId = activity.sport_id as string | null | undefined;
    const creatorId = activity.creator_id as string | null | undefined;

    
    console.log("regionId/comunaId/sportId:", regionId, comunaId, sportId);

    if (!regionId && !comunaId) {
      console.warn("Actividad sin region_id ni comuna_id, no se notifica");
      return new Response(
        JSON.stringify({ error: "Actividad sin region_id/comuna_id" }),
        { status: 400 },
      );
    }

    if (!sportId) {
      console.warn("Actividad sin sport_id, no se puede filtrar por deporte");
      return new Response(
        JSON.stringify({ error: "Actividad sin sport_id" }),
        { status: 400 },
      );
    }
    let sportName: string | null = null;
    try {
      const { data: sport, error: sportError } = await supabase
        .from("deportes")
        .select("name")
        .eq("id", sportId)
        .maybeSingle();

      if (sportError) {
        console.error("Error obteniendo nombre de deporte:", sportError);
      } else if (sport) {
        sportName = (sport.name ?? null) as string | null;
      }
    } catch (e) {
      console.error("Excepción leyendo deportes:", e);
    }


    // 2) Usuarios candidatos por ubicación (user_preferred_locations)
    let uplQuery = supabase
      .from("user_preferred_locations")
      .select("user_id");

    if (comunaId != null) {
      uplQuery = uplQuery.eq("comuna_id", comunaId);
    } else if (regionId != null) {
      uplQuery = uplQuery.eq("region_id", regionId);
    }

    const { data: preferredRows, error: preferredError } = await uplQuery;

    console.log(
      "user_preferred_locations rows:",
      preferredRows?.length ?? 0,
    );

    if (preferredError) {
      console.error(
        "Error consultando user_preferred_locations:",
        preferredError,
      );
      return new Response(
        JSON.stringify({ error: "Error buscando preferencias de ubicación" }),
        { status: 500 },
      );
    }

    if (!preferredRows || preferredRows.length === 0) {
      console.log("No hay usuarios con preferencia para esta ubicación", {
        regionId,
        comunaId,
      });
      return new Response(
        JSON.stringify({ sentTo: 0 }),
        { status: 200 },
      );
    }

    const userIds = preferredRows.map((row: any) => row.user_id);

    // 3) Obtener perfiles de esos usuarios:
    //    - notify_new_activity = true
    //    - preferred_sport_ids contiene sportId
    const { data: profiles, error: profilesError } = await supabase
      .from("perfil")
      .select("id, fcm_token, preferred_sport_ids, notify_new_activity")
      .in("id", userIds)
      .eq("notify_new_activity", true);

    console.log("Perfiles encontrados:", profiles?.length ?? 0);

    if (profilesError) {
      console.error("Error obteniendo perfiles:", profilesError);
      return new Response(
        JSON.stringify({ error: "Error buscando perfiles" }),
        { status: 500 },
      );
    }

    // Filtrar por deporte preferido
    const profilesFiltered = (profiles ?? []).filter((p: any) => {
      const arr = p.preferred_sport_ids as string[] | null;

      // 1) Nunca notificar al creador
      if (creatorId && p.id === creatorId) {
        return false;
      }

      // 2) Si no tiene deportes preferidos, no lo notificamos
      if (!arr || arr.length === 0) {
        return false;
      }

      // 3) Solo si tiene como preferido el deporte de la actividad
      return arr.includes(sportId);
    });

    console.log(
      "Perfiles que cumplen ubicación + notificaciones ON + deporte preferido:",
      profilesFiltered.length,
    );

    const profilesByUser = new Map<string, any>();
    for (const p of profilesFiltered) {
      profilesByUser.set(p.id as string, p);
    }
    const uniqueProfiles = Array.from(profilesByUser.values());

    const tokens = uniqueProfiles
      .map((p: any) => p.fcm_token as string | null)
      .filter((t): t is string => !!t);

    console.log("Tokens FCM finales:", tokens.length);

    if (tokens.length === 0) {
      console.log(
        "No hay tokens FCM después de filtrar por deporte y notify_new_activity",
      );
      return new Response(
        JSON.stringify({ sentTo: 0 }),
        { status: 200 },
      );
    }

    // === NUEVO: evitar duplicados de alerts por user_id + activity_id ===
    const candidateUserIds = uniqueProfiles.map((p: any) => p.id as string);

    const { data: existingAlerts, error: existingAlertsError } = await supabase
      .from("alerts")
      .select("user_id")
      .eq("activity_id", activity.id as string)
      .in("user_id", candidateUserIds);

    if (existingAlertsError) {
      console.error("Error consultando alerts existentes:", existingAlertsError);
    }

    const existingUserIds = new Set(
      (existingAlerts ?? []).map((r: any) => r.user_id as string),
    );

    const profilesToInsert = uniqueProfiles.filter((p: any) => {
      const uid = p.id as string;
      return !existingUserIds.has(uid); // solo usuarios sin alerta previa
    });

    console.log(
      "Perfiles sin alerta previa para esta actividad:",
      profilesToInsert.length,
    );

    if (profilesToInsert.length > 0) {
      try {
        const alertsPayload = profilesToInsert.map((p: any) => ({
          user_id: p.id as string,
          activity_id: activity.id as string,
          activity_title: (activity.title ?? "") as string,
          activity_date: activity.date,
          place_name: (activity.place_name ?? null) as string | null,
          formatted_address: (activity.formatted_address ?? null) as string | null,
          sport_name: sportName,
          // is_read y created_at usan defaults
        }));

        const { error: alertsError } = await supabase
          .from("alerts")
          .insert(alertsPayload);

        if (alertsError) {
          console.error("Error insertando alerts:", alertsError);
        } else {
          console.log("alerts insertados (nuevos):", alertsPayload.length);
        }
      } catch (e) {
        console.error("Excepción creando alerts:", e);
      }
    } else {
      console.log(
        "Todos los usuarios candidatos ya tenían alerta para esta actividad, no se insertan nuevas.",
      );
    }

    // 4) Payload de la notificación
    const notification = {
      title: "Nueva actividad en tu zona",
      body: activity.title ?? "Se ha creado una nueva actividad",
    };

    const dataPayload = {
      activityId: String(activity.id),
      regionId: regionId != null ? String(regionId) : "",
      comunaId: comunaId != null ? String(comunaId) : "",
      sportId: sportId,
      date: String(activity.date ?? ""),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    };

    // 5) FCM HTTP v1
    const accessToken = await getAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id as string;
    const fcmEndpoint =
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    console.log("Enviando FCM a", tokens.length, "tokens");

    const results = await Promise.allSettled(
      tokens.map((token) =>
        fetch(fcmEndpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token,
              notification,
              data: dataPayload,
            },
          }),
        })
      ),
    );

    let successCount = 0;
    let errorCount = 0;

    for (const r of results) {
      if (r.status === "fulfilled") {
        if (r.value.ok) {
          successCount++;
        } else {
          errorCount++;
          const txt = await r.value.text();
          console.error("Error FCM para un token:", txt);
        }
      } else {
        errorCount++;
        console.error("Excepción al enviar a un token:", r.reason);
      }
    }

    console.log(
      "notify-new-activity terminado. OK:",
      successCount,
      "Errores:",
      errorCount,
    );

    return new Response(
      JSON.stringify({
        sentTo: successCount,
        failed: errorCount,
        totalTokens: tokens.length,
        alertsCreatedFor: uniqueProfiles.length,
      }),
      { status: 200 },
    );
  } catch (e) {
    console.error("Exception en notify-new-activity:", e);
    return new Response(
      JSON.stringify({ error: (e as Error).message ?? String(e) }),
      { status: 500 },
    );
  }
});
