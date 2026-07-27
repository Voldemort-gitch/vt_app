import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.21.0'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const { action, admin_id, target_user_id, pin, code } = await req.json()
  const ip = req.headers.get('x-forwarded-for') || 'unknown'

  // Simple in-memory rate limiting (resets on function cold start)
  const rateLimitMap = new Map<string, { count: number; resetAt: number }>()

  async function checkRateLimit(key: string, maxPerHour: number): Promise<boolean> {
    const now = Date.now()
    const entry = rateLimitMap.get(key)
    if (entry && now < entry.resetAt) {
      if (entry.count >= maxPerHour) return false
      entry.count++
    } else {
      rateLimitMap.set(key, { count: 1, resetAt: now + 3600000 })
    }
    return true
  }

  async function logAudit(adminId: string, actionType: string, details: string) {
    try {
      await supabase.from('admin_audit_log').insert({
        admin_id: adminId,
        action: actionType,
        details: details,
        ip_address: ip,
      })
    } catch {
      // Table may not exist — silently skip audit logging
    }
  }

  if (action === 'get-email') {
    const { data, error } = await supabase.from('profiles').select('id, name').eq('employee_code', code).single()
    if (error || !data) {
      return new Response(JSON.stringify({ email: null, user_id: null, error: 'Employee not found' }))
    }
    const { data: user } = await supabase.auth.admin.getUserById(data.id)
    return new Response(JSON.stringify({ email: user?.user?.email || null, user_id: data.id }))
  }

  if (action === 'set-pin') {
    // Verify caller's JWT
    const authHeader = req.headers.get('authorization') || ''
    const token = authHeader.replace('Bearer ', '')
    const { data: { user } } = await supabase.auth.getUser(token)
    if (!user) {
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), { status: 401 })
    }
    if (user.id !== admin_id) {
      return new Response(JSON.stringify({ success: false, error: 'Token user does not match admin_id' }), { status: 403 })
    }

    // Rate limit: max 10 PIN resets per admin per hour
    if (!await checkRateLimit(`set-pin:${admin_id}`, 10)) {
      return new Response(JSON.stringify({ success: false, error: 'Rate limited. Max 10 PIN resets per hour.' }), { status: 429 })
    }

    const { data: admin } = await supabase.from('profiles').select('role').eq('id', admin_id).single()
    if (admin?.role !== 'admin') {
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), { status: 403 })
    }

    const paddedPin = pin.length < 6 ? pin + 'vt' : pin
    const { error } = await supabase.auth.admin.updateUserById(target_user_id, { password: paddedPin })

    // Audit log
    if (!error) {
      await logAudit(admin_id, 'pin_reset', `Reset PIN for user ${target_user_id}`)
    }

    return new Response(JSON.stringify({ success: !error, error: error?.message }))
  }

  if (action === 'check-login-attempt') {
    const { data: user } = await supabase.auth.admin.getUserById(target_user_id)
    const attempts = user?.user?.user_metadata?.login_attempts || 0
    const lockUntil = user?.user?.user_metadata?.lock_until || 0
    const now = Date.now()

    if (now < lockUntil) {
      const remaining = Math.ceil((lockUntil - now) / 60000)
      return new Response(JSON.stringify({ allowed: false, message: `Try again in ${remaining} min` }))
    }

    return new Response(JSON.stringify({ allowed: true, attempts, lockUntil }))
  }

  if (action === 'record-login-failure') {
    const { data: user } = await supabase.auth.admin.getUserById(target_user_id)
    const attempts = (user?.user?.user_metadata?.login_attempts || 0) + 1
    const metadata: Record<string, unknown> = { login_attempts: attempts }

    if (attempts >= 5) {
      metadata.lock_until = Date.now() + 1800000 // 30 min
    }

    await supabase.auth.admin.updateUserById(target_user_id, { user_metadata: metadata })
    return new Response(JSON.stringify({ success: true }))
  }

  if (action === 'clear-login-attempts') {
    await supabase.auth.admin.updateUserById(target_user_id, {
      user_metadata: { login_attempts: 0, lock_until: 0 }
    })
    return new Response(JSON.stringify({ success: true }))
  }

  if (action === 'create-user') {
    const authHeader = req.headers.get('authorization') || ''
    const token = authHeader.replace('Bearer ', '')
    const { data: { user } } = await supabase.auth.getUser(token)
    if (!user) return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), { status: 401 })
    const { data: admin } = await supabase.from('profiles').select('role').eq('id', user.id).single()
    if (admin?.role !== 'admin') return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), { status: 403 })

    const { email, password, name, employeeCode, phone } = await req.json()
    if (!email || !password || !name || !employeeCode) {
      return new Response(JSON.stringify({ success: false, error: 'Missing required fields' }))
    }

    const { data: newUser, error: createError } = await supabase.auth.admin.createUser({
      email, password, email_confirm: true
    })
    if (createError || !newUser.user) {
      return new Response(JSON.stringify({ success: false, error: createError?.message || 'Failed to create user' }))
    }

    const { error: profileError } = await supabase.from('profiles').insert({
      id: newUser.user.id, name, employee_code: employeeCode, phone: phone || null, role: 'employee', is_active: true
    })
    if (profileError) {
      // Rollback: delete the auth user if profile insert fails
      await supabase.auth.admin.deleteUser(newUser.user.id)
      return new Response(JSON.stringify({ success: false, error: profileError.message }))
    }

    return new Response(JSON.stringify({ success: true, user_id: newUser.user.id }))
  }

  return new Response(JSON.stringify({ error: 'Unknown action' }), { status: 400 })
})
