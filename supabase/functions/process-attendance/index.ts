import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.21.0'

const EARTH_RADIUS_M = 6_371_000

function toRad(deg: number): number {
  return (deg * Math.PI) / 180
}

function haversineDistance(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const dLat = toRad(lat2 - lat1)
  const dLng = toRad(lng2 - lng1)
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2
  return EARTH_RADIUS_M * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

function isWithinRadius(
  userLat: number, userLng: number,
  officeLat: number, officeLng: number,
  allowedRadius: number,
): boolean {
  return haversineDistance(userLat, userLng, officeLat, officeLng) <= allowedRadius
}

function determineStatus(
  officeStartTime: string,
  lateAfterMinutes: number,
): string {
  const now = new Date()
  const [h, m] = officeStartTime.split(':').map(Number)
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), h, m)
  const diffMs = now.getTime() - start.getTime()
  if (diffMs > lateAfterMinutes * 60_000) return 'late'
  return 'present'
}

function calculateWorkingMinutes(checkInIso: string): number {
  const checkIn = new Date(checkInIso)
  const checkOut = new Date()
  return Math.round((checkOut.getTime() - checkIn.getTime()) / 60_000)
}

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const authHeader = req.headers.get('authorization') || ''
  const token = authHeader.replace('Bearer ', '')
  const { data: { user } } = await supabase.auth.getUser(token)
  if (!user) {
    return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), { status: 401 })
  }

  const { action, employee_id, latitude, longitude, company_id } = await req.json()

  if (user.id !== employee_id) {
    return new Response(JSON.stringify({ success: false, error: 'Employee ID mismatch' }), { status: 403 })
  }

  // Fetch company settings for GPS validation and company ID check
  const { data: settings } = await supabase.from('company_settings').select('*').limit(1).maybeSingle()
  if (!settings) {
    return new Response(JSON.stringify({ success: false, error: 'Company settings not found' }), { status: 500 })
  }

  // Validate company ID if provided (from QR scan)
  if (company_id) {
    const expectedId = settings.company_name.replace(/\s+/g, '_').toLowerCase()
    if (company_id !== expectedId) {
      return new Response(JSON.stringify({ success: false, error: 'Invalid QR code for this office' }), { status: 403 })
    }
  }

  const officeLat = Number(settings.office_latitude)
  const officeLng = Number(settings.office_longitude)
  const allowedRadius = Number(settings.allowed_radius)

  if (officeLat === 0 && officeLng === 0) {
    return new Response(JSON.stringify({ success: false, error: 'Office coordinates not configured' }), { status: 400 })
  }

  // Server-side geofence validation
  if (!isWithinRadius(latitude, longitude, officeLat, officeLng, allowedRadius)) {
    return new Response(JSON.stringify({ success: false, error: 'You are not within the office premises.' }), { status: 403 })
  }

  const today = new Date().toISOString().split('T')[0]

  if (action === 'check-in') {
    const status = determineStatus(settings.office_start_time, Number(settings.late_after_minutes))

    const { error: insertError } = await supabase.from('attendance').upsert({
      employee_id,
      attendance_date: today,
      check_in: new Date().toISOString(),
      check_in_latitude: latitude,
      check_in_longitude: longitude,
      status,
    }, { onConflict: 'employee_id,attendance_date' })

    if (insertError) {
      return new Response(JSON.stringify({ success: false, error: insertError.message }), { status: 500 })
    }

    return new Response(JSON.stringify({
      success: true,
      status,
      message: status === 'late' ? 'Checked in (Late)' : 'Checked in successfully!',
    }))
  }

  if (action === 'check-out') {
    // Get today's attendance to find check_in time
    const { data: attendance } = await supabase
      .from('attendance')
      .select('check_in')
      .eq('employee_id', employee_id)
      .eq('attendance_date', today)
      .maybeSingle()

    if (!attendance?.check_in) {
      return new Response(JSON.stringify({ success: false, error: 'No check-in record found.' }), { status: 400 })
    }

    const workingMinutes = calculateWorkingMinutes(attendance.check_in)

    const { error: updateError } = await supabase
      .from('attendance')
      .update({
        check_out: new Date().toISOString(),
        check_out_latitude: latitude,
        check_out_longitude: longitude,
        working_minutes: workingMinutes,
      })
      .eq('employee_id', employee_id)
      .eq('attendance_date', today)

    if (updateError) {
      return new Response(JSON.stringify({ success: false, error: updateError.message }), { status: 500 })
    }

    return new Response(JSON.stringify({
      success: true,
      working_minutes: workingMinutes,
      message: `Checked out successfully! Working: ${Math.floor(workingMinutes / 60)}h ${workingMinutes % 60}m`,
    }))
  }

  return new Response(JSON.stringify({ error: 'Unknown action' }), { status: 400 })
})
