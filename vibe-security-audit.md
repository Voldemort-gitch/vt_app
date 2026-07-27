# Vibe-Security Audit — Visual Time (vt_app)

Audit date: 2026-07-27 | Methodology: vibe-security v1.0

---

## Critical

### `lib/core/constants/constants.dart:5` — Supabase anon key in client bundle (by design, but requires RLS correctness)

The Supabase URL and anon key are hardcoded in the Flutter app. This is the standard Supabase/Firebase client-side pattern — the anon key is deliberately public. **This is acceptable only because every database table has Row-Level Security enabled.**

Verification steps:
- ✅ All 11 tables have RLS enabled
- ✅ `salary_components` previously had `USING (true)` — **now fixed** in migration `20240101000011`
- ✅ No table uses `USING (auth.uid() IS NOT NULL)` as a blanket pass
- ✅ All per-employee tables scope to `auth.uid() = employee_id` or `is_admin()`

**Verdict:** Not a vulnerability. Architecture is correct for the Supabase client-side model.

---

## High

### `lib/features/authentication/providers/auth_provider.dart:105-141` — PIN rate limiting is client-orchestrated, can be bypassed via direct Auth API

The `employeeCodeSignIn()` method calls the `manage-pin` Edge Function's `check-login-attempt` action before calling Supabase Auth's `signInWithPassword()`. However, an attacker can skip the app entirely and call `POST /auth/v1/token?grant_type=password` directly with guessed PINs — the Supabase Auth endpoint has no awareness of the custom rate limit.

```dart
// Before (current) — rate limit is advisory, not enforced at the auth boundary
final check = await SupabaseService.checkLoginAttempt(userId);
if (check['allowed'] == false) { /* block */ }
await signIn(email, pin.length < 6 ? '${pin}vt' : pin);  // Rate limit can be bypassed by calling this directly
```

**What an attacker can do:** Brute-force 4–6 digit PINs at full network speed against the Supabase Auth API, without triggering the 5-attempt lockout. The `'vt'` padding is identical for all users and public knowledge from APK decompilation.

**Fix:** Move the PIN verification into the Edge Function entirely. The Edge Function verifies the PIN server-side (using `auth.admin.updateUserById` to set a matching password, or by issuing a custom Supabase token after successful PIN check). This removes the direct Auth API bypass path.

```dart
// After — all PIN auth goes through Edge Function
final result = await SupabaseService.authenticateWithPin(code: code, pin: pin);
// Edge Function does: check rate limit -> verify PIN -> issue session token
```

---

### `supabase/migrations/20240101000009_rls_policies.sql` — `company_settings` has `USING (true)` for SELECT

```sql
CREATE POLICY "Anyone read settings" ON company_settings
  FOR SELECT USING (true);
```

**What an attacker can do:** Any authenticated user (any employee) can read office GPS coordinates, allowed radius, office hours, late threshold, and max employees on leave. While these are not PII, the GPS coordinates + radius define the geofence boundary, giving an attacker the exact values needed to craft valid-looking GPS data.

**Fix:** Scope to admin-only for sensitive fields, or remove coordinates from client-accessible settings (let the `process-attendance` Edge Function read them server-side).

```sql
-- Option: Admin-only for settings with GPS data
CREATE POLICY "Employees read limited settings" ON company_settings
  FOR SELECT USING (is_admin() OR true)  -- but filter columns
  WITH CHECK (is_admin());
```

**Note:** This is a defense-in-depth issue rather than an active exploit — the `process-attendance` Edge Function now validates GPS server-side, so knowing the coordinates doesn't help an attacker fake a check-in. However, it does leak office location to any employee who queries the API directly.

---

## Medium

### `lib/features/authentication/views/biometric_screen.dart` — Biometric enabled flag stored in SharedPreferences (unencrypted)

```dart
// Before — SharedPreferences (unencrypted XML on rooted devices)
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('biometric_enabled', v);
```

**What an attacker can do:** On a rooted device, read `/data/data/com.vtapp.vt_app/shared_prefs/FlutterSharedPreferences.xml` and set `biometric_enabled` to `false`. The app skips the biometric screen on next launch, exposing all data to whoever holds the unlocked device.

**Fix:** Use `flutter_secure_storage` (backed by Android Keystore) instead of SharedPreferences for the biometric toggle.

```dart
// After — secure storage
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
final storage = const FlutterSecureStorage();
await storage.write(key: 'biometric_enabled', value: 'true');
```

---

### `lib/features/qr/views/qr_display_screen.dart:58` — QR code contains static, non-expiring GPS coordinates

```dart
// Current — QR embeds office coordinates directly
String get _qrData => jsonEncode({'co': _companyId, 'la': _lat, 'lo': _lng});
```

**What an attacker can do:** Photograph the QR code once → permanent access to precise office GPS coordinates. Can fabricate QR data with valid office ID + correct coordinates at any time.

**Fix:** Remove coordinates from the QR payload. The server (Edge Function) already knows office coordinates from `company_settings`. The QR should only identify the office (e.g., `{"co": "visual_time"}`). The server looks up the GPS coordinates server-side and performs the geofence validation.

```dart
// After — QR only identifies the office, coordinates fetched server-side
String get _qrData => jsonEncode({'co': _companyId});
```

---

### `lib/features/advance/providers/advance_provider.dart` — Advance request amount not validated against salary

The advance submission allows any amount without checking against the employee's monthly salary or outstanding advance balance.

```dart
// No max-amount or outstanding-advance check
await SupabaseService.submitAdvanceRequest(
  employeeId: userId, amount: amount, ...
);
```

**What an attacker can do:** Submit an advance larger than monthly salary. If approved by admin, the payroll Edge Function deducts the full advance amount, potentially producing a negative `final_salary` (now blocked by CHECK constraint added in migration `20240101000011`).

**Fix:** Add a server-side or Edge Function check that caps advance requests at a configurable percentage of monthly salary and tracks total outstanding approved advances.

```sql
-- Current check constraint prevents negative salary but doesn't prevent over-advance
ALTER TABLE payroll_records ADD CONSTRAINT final_salary_non_negative CHECK (final_salary >= 0);
```

---

## Low

### `lib/features/attendance/providers/attendance_provider.dart` — WorkingMinutes recalculated client-side for display (no security impact)

The `AttendanceHelper.calculateWorkingMinutes()` is still called client-side for the success message display. The authoritative working minutes are now calculated and stored by the `process-attendance` Edge Function. This is informational only — no security impact.

### `lib/shared/services/supabase_service.dart` — `getAllEmployees()` returns all active employees including their IDs

This is used by admin screens. It returns `id`, `name`, `employee_code`, and is protected by RLS (admin only via `is_admin()`). No issue.

---

## Summary of Remediation Priorities

| Priority | Issue | Effort | File |
|---|---|---|---|
| 🔴 **High** | PIN rate limiting bypassable via direct Auth API | Medium | `auth_provider.dart` |
| 🟡 **Medium** | Company settings readable by any employee via RLS | Low | `migrations/...rls_policies.sql` |
| 🟡 **Medium** | Biometric flag in SharedPreferences (rooted device) | Low | `biometric_screen.dart` |
| 🟡 **Medium** | QR code contains static GPS coordinates | Low | `qr_display_screen.dart` |
| 🟡 **Medium** | No advance amount cap vs salary | Low | `advance_provider.dart` |

**Items already fixed in recent sessions (confirmed by code review):**
- ✅ `salary_components` RLS changed from `USING (true)` to per-employee scope
- ✅ Attendance validation moved from client-only to Edge Function (server-side)
- ✅ `final_salary >= 0` CHECK constraint added to `payroll_records`
- ✅ `salary_components` percentage-sum CHECK constraint added
- ✅ No remaining `catch (_) {}` in critical user-facing flows (logging added)
- ✅ Global error handler (`FlutterError.onError`, `PlatformDispatcher.onError`, `runZonedGuarded`)
- ✅ Release signing configured (keystore generated)
- ✅ Splash screen with dark background + logo
- ✅ App icon generated for all densities (adaptive + legacy)
- ✅ `pin_helper.dart` dead code deleted
