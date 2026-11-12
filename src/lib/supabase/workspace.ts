import type { SupabaseClient } from "@supabase/supabase-js"

type SupabaseLikeError = {
  code?: string
  message?: string
} | null | undefined

/**
 * Returns true when PostgREST or Postgres reports a missing column.
 */
export function isMissingColumnError(error: SupabaseLikeError): boolean {
  if (!error) return false
  return error.code === "PGRST204" || error.code === "42703"
}

/**
 * Returns true when real Supabase environment credentials are configured.
 */
export function isSupabaseConfigured(): boolean {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
  return Boolean(
    url &&
      anonKey &&
      !url.includes("dummy.supabase.co") &&
      anonKey !== "dummy-anon-key"
  )
}

/**
 * Returns true when an error was caused by offline/network connectivity failure.
 */
export function isNetworkError(error: unknown): boolean {
  if (!error) return false
  const message =
    typeof error === "object" && "message" in error
      ? String((error as { message?: unknown }).message || "")
      : String(error)
  return /fetch failed|failed to fetch|networkerror|network request failed|load failed/i.test(
    message
  )
}

/**
 * Ensures a workspace row exists in Supabase, falling back to the base schema
 * columns if owner_id/plan_tier have not been migrated yet.
 */
export async function ensureWorkspaceExists(
  supabase: SupabaseClient,
  workspaceId: string,
  workspaceName: string
): Promise<{ error: SupabaseLikeError }> {
  const { data: existingWs } = await supabase
    .from("workspaces")
    .select("id")
    .eq("id", workspaceId)
    .maybeSingle()

  if (existingWs?.id) {
    return { error: null }
  }

  const nowIso = new Date().toISOString()

  let { error } = await supabase.from("workspaces").upsert(
    {
      id: workspaceId,
      owner_id: workspaceId,
      name: workspaceName,
      plan_tier: "free",
      created_at: nowIso,
      updated_at: nowIso,
    },
    { onConflict: "id", ignoreDuplicates: true }
  )

  if (isMissingColumnError(error)) {
    const fallbackRes = await supabase.from("workspaces").upsert(
      {
        id: workspaceId,
        name: workspaceName,
        created_at: nowIso,
        updated_at: nowIso,
      },
      { onConflict: "id", ignoreDuplicates: true }
    )
    error = fallbackRes.error
  }

  if (error?.code === "23505") {
    return { error: null }
  }

  return { error: error || null }
}

