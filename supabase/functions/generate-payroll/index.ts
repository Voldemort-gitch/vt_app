import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.21.0'

serve(async (req) => {
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const { month, year } = await req.json()

  const authHeader = req.headers.get('authorization') || ''
  const token = authHeader.replace('Bearer ', '')
  const { data: { user } } = await supabase.auth.getUser(token)
  if (!user) return new Response(JSON.stringify({ success: false }), { status: 401 })

  const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).single()
  if (profile?.role !== 'admin') return new Response(JSON.stringify({ success: false }), { status: 403 })

  const { data: employees } = await supabase.from('profiles').select('id, name, employee_code').eq('is_active', true).eq('role', 'employee')
  if (!employees || employees.length === 0) return new Response(JSON.stringify({ success: false, error: 'No employees' }))

  const startDate = `${year}-${String(month).padStart(2, '0')}-01`
  const lastDay = new Date(year, month, 0).getDate()
  const endDate = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`

  // Get approved advances for the month
  const { data: advances } = await supabase.from('advance_requests').select('employee_id, amount').eq('status', 'approved').eq('month', month).eq('year', year)
  const advanceMap: Record<string, number> = {}
  if (advances) for (const a of advances) { advanceMap[a.employee_id] = Number(a.amount) }

  let generated = 0
  let errors: string[] = []

  for (const emp of employees) {
    try {
      const { data: salaryRec } = await supabase.from('employee_salary_history').select('*').eq('employee_id', emp.id).lte('effective_from', endDate).order('effective_from', { ascending: false }).order('created_at', { ascending: false }).limit(1)
      const salary = salaryRec && salaryRec.length > 0 ? salaryRec[0] : null
      if (!salary) { errors.push(`${emp.name}: No salary`); continue }

      // Get salary components
      const { data: comp } = await supabase.from('salary_components').select('*').eq('employee_id', emp.id).maybeSingle()
      const monthlySalary = Number(salary.monthly_salary)
      const workingDaysNum = salary.working_days || 30
      const allowedLeaves = salary.allowed_leaves || 4

      // Gross salary = monthly salary (components define percentage split for display only)
      let grossSalary = monthlySalary

      // Get attendance
      const { data: attendance } = await supabase.from('attendance').select('status').eq('employee_id', emp.id).gte('attendance_date', startDate).lte('attendance_date', endDate)
      let present = 0, leave = 0, late = 0
      if (attendance) for (const a of attendance) {
        if (a.status === 'present') present++
        else if (a.status === 'late') { present++; late++ }
        else if (a.status === 'on_leave') leave++
      }

      const dailySalary = Math.round((monthlySalary / workingDaysNum) * 100) / 100
      const extraLeave = Math.max(0, leave - allowedLeaves)
      const leaveDeduction = Math.round(extraLeave * dailySalary * 100) / 100

      // Fixed deductions from components
      let healthIns = 0, profTax = 0, tdsAmt = 0
      if (comp) {
        healthIns = Number(comp.health_insurance) || 0
        profTax = Number(comp.professional_tax) || 0
        tdsAmt = Number(comp.tds) || 0
      }

      // Advance deduction
      const advanceAmount = advanceMap[emp.id] || 0

      const fixedDeductions = healthIns + profTax + tdsAmt + leaveDeduction + advanceAmount
      const finalSalary = Math.round((monthlySalary - fixedDeductions) * 100) / 100

      await supabase.from('monthly_attendance_summary').upsert({
        employee_id: emp.id, month, year, total_days: workingDaysNum,
        present_days: present, late_days: late, leave_days: leave,
        absent_days: Math.max(0, workingDaysNum - present - leave),
      }, { onConflict: 'employee_id,month,year' })

      await supabase.from('payroll_records').upsert({
        employee_id: emp.id, month, year,
        basic_salary: monthlySalary,
        daily_salary: dailySalary,
        allowed_leave: allowedLeaves,
        used_leave: leave,
        extra_leave: extraLeave,
        deduction_amount: leaveDeduction,
        advance_amount: advanceAmount,
        gross_salary: grossSalary,
        final_salary: finalSalary,
        status: 'draft',
        generated_by: user.id,
      }, { onConflict: 'employee_id,month,year' })

      generated++
    } catch (e) { errors.push(`${emp.name}: ${e.message}`) }
  }

  return new Response(JSON.stringify({ success: true, generated, total: employees.length, errors: errors.length > 0 ? errors : undefined }))
})
