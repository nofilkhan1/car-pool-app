import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.0'

const ADMIN_USER_ID = Deno.env.get('FAST_CARPOOL_ADMIN_USER_ID') ?? 'REPLACE_WITH_ADMIN_USER_ID'
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' }

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const authHeader = request.headers.get('Authorization')
    if (!authHeader) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } })
    const userClient = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user || user.id !== ADMIN_USER_ID) return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } })
    const { verificationId, decision } = await request.json()
    if (!verificationId || !['verified', 'rejected'].includes(decision)) throw new Error('Invalid review request')
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const { data: verification, error: readError } = await admin.from('fast_id_verifications').select('id,user_id,id_card_image_url').eq('id', verificationId).single()
    if (readError) throw readError
    const { error: storageError } = await admin.storage.from('fast-id-cards').remove([verification.id_card_image_url])
    if (storageError) throw storageError
    const { error: profileError } = await admin.from('profiles').update({ fast_id_status: decision }).eq('id', verification.user_id)
    if (profileError) throw profileError
    const { error: deleteError } = await admin.from('fast_id_verifications').delete().eq('id', verificationId)
    if (deleteError) throw deleteError
    return new Response(JSON.stringify({ ok: true }), { headers: { ...cors, 'Content-Type': 'application/json' } })
  } catch (error) { return new Response(JSON.stringify({ error: error instanceof Error ? error.message : 'Review failed' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } }) }
})
