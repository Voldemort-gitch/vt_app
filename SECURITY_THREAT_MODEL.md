# Threat Model: Visual Time - Smart Attendance Management System

## Version 1.0 — July 2026

---

## 1. System Overview

| Attribute | Value |
|-----------|-------|
| **Application** | Visual Time (vt_app) — Smart Attendance Management |
| **Platform** | Flutter 3.44.7 → Android (APK) + Web |
| **Backend** | Supabase (PostgreSQL, Auth, Edge Functions, REST API) |
| **Deployment** | Supabase-hosted, internet-facing. No CDN/WAF in front. |
| **Users** | 1 Admin + 10-15 employees (laborers). Future: 50-100+ |
| **Device Model** | BYOD (employee Android phones). No MDM. |
| **Tenancy** | Single-tenant currently. Future multi-company SaaS planned. |
| **Compliance** | None enforced. Should follow HR/financial data best practices. |
| **Offline** | Online-only. No offline sync. |

---

## 2. Architecture Diagram (Logical)

```
┌──────────────────────────────────────────────────────────────────┐
│                        Flutter App (Client)                       │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐ │
│  │ Auth UI  │  │  QR/GPS │  │ Dashboard│  │  Biometric       │ │
│  │ (Login/  │  │  Scanner │  │ (Admin/  │  │  (local_auth)    │ │
│  │ Biometric)│  │          │  │ Employee)│  │                  │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────────┬─────────┘ │
│       │              │              │                  │          │
│       └──────────────┴──────────────┴──────────────────┘          │
│                           │ HTTPS                                 │
└───────────────────────────┼──────────────────────────────────────┘
                            │
┌───────────────────────────┼──────────────────────────────────────┐
│                    Supabase (Backend)                             │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │                     API Gateway                           │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐   │    │
│  │  │ Auth     │  │ REST API │  │  Edge Functions       │   │    │
│  │  │ (GoTrue) │  │ (PostgREST│  │  ┌────────────────┐ │   │    │
│  │  │          │  │  + Realtime│  │  │  manage-pin    │ │   │    │
│  │  └────┬─────┘  └────┬─────┘  │  │  (Deno/TS)      │ │   │    │
│  │       │              │       │  └────────────────┘ │   │    │
│  │       └──────────────┴───────┴──────────────────────┘   │    │
│  └──────────────────────────────────────────────────────────┘    │
│                           │                                      │
│  ┌────────────────────────┼──────────────────────────────────┐   │
│  │              PostgreSQL (via service_role for Edge Fn)      │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │   │
│  │  │ profiles │  │attendance│  │  leave_  │  │company_  │  │   │
│  │  │          │  │          │  │ requests │  │ settings  │  │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │   │
│  │  │departments│  │ holidays │  │ auth.users│  │employee_ │  │   │
│  │  │          │  │          │  │ (managed) │  │  pins    │  │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 3. Trust Boundaries

| Boundary ID | From | To | Protocol | Auth | Notes |
|:-----------:|------|----|:--------:|:----:|-------|
| **T1** | Flutter App | Supabase Auth | HTTPS | Anon key + JWT | Anon key is public; JWT obtained after login |
| **T2** | Flutter App | Supabase REST API | HTTPS | JWT (user session) | RLS enforced per-user |
| **T3** | Flutter App | Supabase Edge Functions | HTTPS | JWT + Function URL | Edge Function verifies admin role internally |
| **T4** | Flutter App | Device Biometric Sensor | Platform API | OS-level | Fingerprint never leaves device |
| **T5** | Flutter App | Device GPS/Camera | Platform API | OS permissions | Runtime permission requests |
| **T6** | Edge Function | PostgreSQL | Internal | service_role key | FULL database access — never exposed to client |
| **T7** | Admin Browser | Supabase Dashboard | HTTPS | Supabase SSO | Separate admin surface |

---

## 4. Assets

| Asset ID | Asset | Location | Sensitivity | Impact if Compromised |
|:--------:|-------|----------|:-----------:|:---------------------:|
| **A1** | Supabase anon/publishable key | Flutter app (constants.dart) | Low | Public by design; only enables schema-exposed queries |
| **A2** | User JWT session token | Flutter app memory + Supabase client | High | Full account access for session duration |
| **A3** | Employee PIN | In transit (HTTPS), stored as Supabase password (bcrypt) | High | Account takeover. Reset required. |
| **A4** | Employee PII (name, phone, code) | profiles table | Medium | Privacy violation, HR data exposure |
| **A5** | Attendance records (timestamps + GPS) | attendance table | Medium-High | Payroll manipulation risk (future) |
| **A6** | GPS coordinates of check-in | attendance table | Low-Medium | Location tracking of employees |
| **A7** | Company settings (office GPS, hours) | company_settings table | Low | Less sensitive; public-readable by RLS |
| **A8** | Leave requests + reasons | leave_requests table | Medium | Medical/personal reason exposure |
| **A9** | Biometric preference | SharedPreferences on device | Low | Only boolean flag, not biometric data |
| **A10** | PIN lockout counter | SharedPreferences on device | Low | Bypassable by clearing app data |
| **A11** | Service role key (Edge Function) | Supabase environment variable | Critical | Full database access, auth admin |
| **A12** | Supabase Dashboard credentials | Admin's browser/password manager | Critical | Full project control |

---

## 5. Entry Points

| Entry Point | Method | Auth Required | Input | Risk |
|:-----------:|:------:|:-------------:|-------|:----:|
| **Login (admin)** | `signInWithPassword()` | No (public) | email, password | Brute force, credential stuffing |
| **Login (employee)** | Edge Function → `signInWithPassword()` | No (public) | employee_code, PIN | PIN brute force (4-digit), code guessing |
| **QR scan check-in** | REST API → attendance table | JWT required | QR data, GPS coordinates | QR replay, GPS spoofing, token theft |
| **Admin CRUD** | REST API → profiles table | JWT required (admin role) | name, code, phone | Privilege escalation, unauthorized modifications |
| **Leave request** | REST API → leave_requests table | JWT required (employee) | dates, reason | Data integrity, unauthorized requests |
| **Leave approval** | REST API → leave_requests table | JWT required (admin role) | status (approve/reject) | Unauthorized approval |
| **Settings update** | REST API → company_settings table | JWT required (admin role) | GPS, hours, radius | Business disruption |
| **PIN reset** | Edge Function → `manage-pin` | JWT required (admin role) | user_id, new_pin | Admin account compromise → all PINs compromised |
| **Biometric** | Device `local_auth` | OS biometric enrollment | Fingerprint/face | Bypassable on rooted/jailbroken devices |

---

## 6. Attack Paths — Prioritized

### 🔴 Critical

#### PATH-C01: Admin Account Takeover → Full System Compromise

| Step | Description | Asset |
|:----:|-------------|:-----:|
| 1 | Attacker obtains admin credentials (phishing, credential stuffing, weak password) | A2 |
| 2 | Attacker logs in as admin → accesses all employee records, attendance, settings | A3, A4, A5 |
| 3 | Attacker resets all employee PINs via Edge Function | A3 |
| 4 | Attacker modifies attendance records to manipulate payroll | A5 (future payroll) |
| 5 | Attacker changes office GPS coordinates to disrupt check-ins | A7 |

**Likelihood:** Medium | **Impact:** Critical | **Priority: CRITICAL**

**Existing Controls:**
- Supabase Auth with JWT
- Edge Function verifies admin role server-side

**Gaps:**
- No MFA on admin accounts
- No brute-force protection on admin login (beyond Supabase defaults)
- No audit log of admin actions (who reset whose PIN)
- No anomaly detection on admin behavior

---

#### PATH-C02: Service Role Key Exposure → Complete Database Compromise

| Step | Description | Asset |
|:----:|-------------|:-----:|
| 1 | Attacker gains access to Supabase project (phishing of Supabase dashboard credentials) | A11, A12 |
| 2 | Copies service_role key from Settings → API | A11 |
| 3 | Makes direct API calls → reads/writes all tables, auth.users | A3, A4, A5, A6, A8 |
| 4 | Modifies auth users, resets passwords, deletes attendance records | A3, A5 |

**Likelihood:** Low | **Impact:** Critical | **Priority: CRITICAL**

**Existing Controls:**
- No service_role key in client code (server-side only in Edge Function)
- Supabase dashboard access limited to project owner

**Gaps:**
- No alerting on service_role API usage
- No audit logging of admin dashboard access

---

### 🟠 High

#### PATH-H01: PIN Brute Force (Bypassing Client Lockout)

| Step | Description | Asset |
|:----:|-------------|:-----:|
| 1 | Attacker obtains employee code (printed on ID card, observed) | A4 |
| 2 | 4-digit PIN → 10,000 combinations | A3 |
| 3 | Client-side lockout (SharedPreferences) → attacker clears app data | A10 |
| 4 | Brute forces PIN via repeated HTTP calls | A3, A2 |

**Likelihood:** Medium | **Impact:** High | **Priority: HIGH**

**Existing Controls:**
- Client-side lockout after 5 attempts (30 min)
- Lockout stored in SharedPreferences

**Gaps:**
- **Lockout is client-side only** — clearing app data resets the counter
- No server-side rate limiting on `/auth/v1/token` for PIN-based logins
- No CAPTCHA or progressive delay on auth endpoint

---

#### PATH-H02: QR Code Replay / GPS Spoofing

| Step | Description | Asset |
|:----:|-------------|:-----:|
| 1 | Employee takes photo of office QR code | QR data |
| 2 | Employee scans QR photo from home | A5 |
| 3 | GPS check fails (not at office) | Blocked by design |
| 3b | GPS spoofing app installed → fake GPS to office coordinates | A5 (bypassed) |
| 4 | Check-in recorded as if at office | A5 |

**Likelihood:** Medium | **Impact:** Medium | **Priority: HIGH**

**Existing Controls:**
- GPS verification prevents QR photo scanning
- QR contains office coordinates that must match device GPS

**Gaps:**
- **GPS can be spoofed** on rooted devices or with mock location apps
- No additional verification (WiFi SSID, BLE beacon, photo selfie)
- GPS tolerance radius (configurable) could be too large

---

#### PATH-H03: Privilege Escalation — Employee Accesses Admin Functions

| Step | Description | Asset |
|:----:|-------------|:-----:|
| 1 | Attacker obtains another user's JWT (token theft, device access) | A2 |
| 2 | Checks role claim in JWT | A2 |
| 3 | If employee tries to access admin endpoints → RLS blocks | Blocked |
| 3b | Employee modifies their `role` claim → RLS may not check | A4 |

**Likelihood:** Low | **Impact:** High | **Priority: HIGH**

**Existing Controls:**
- RLS policies enforce `role = 'admin'` checks on admin operations
- JWT is signed by Supabase (cannot modify without service_role)
- Edge Function verifies admin role server-side

**Gaps:**
- Role is stored in `profiles` table, not in JWT claims — requires DB query for each RLS check (acceptable, but latency)
- No explicit claim-based role in JWT for faster verification

---

### 🟡 Medium

#### PATH-M01: Attendance Record Manipulation

| Step | Description | Asset |
|:----:|-------------|:-----:|
| 1 | Employee checks in late → system marks "late" | A5 |
| 2 | Employee modifies `status` field via intercepted/modified API call | A5 |
| 3 | Attendance shows "present" instead of "late" | A5 |

**Likelihood:** Low | **Impact:** Medium | **Priority: MEDIUM**

**Existing Controls:**
- RLS: employees can only update their own attendance
- RLS: no direct check preventing status modification (depends on policy)
- Attendance status is calculated on check-in; not re-verified on check-out

**Gaps:**
- `status` is sent from client; not re-calculated server-side on check-out
- No checksum or digital signature on attendance records
- No immutable audit trail (records can be updated)

---

#### PATH-M02: Edge Function Abuse by Malicious Admin

| Step | Description | Asset |
|:----:|-------------|:-----:|
| 1 | Admin account compromised (PATH-C01) | A2 |
| 2 | Attacker calls `set-pin` on all employees | A3 |
| 3 | Sets PINs to known value → logs in as any employee | A2 |
| 4 | Alters attendance records | A5 |

**Likelihood:** Low | **Impact:** High | **Priority: MEDIUM**

**Existing Controls:**
- Edge Function requires valid admin JWT + `role = 'admin'` check

**Gaps:**
- **No audit log of admin PIN resets** — who reset which employee's PIN and when
- No notification sent to employee when PIN is reset
- No secondary approval required for PIN resets

---

#### PATH-M03: Employee Data Privacy — Device Theft

| Step | Description | Asset |
|:----:|-------------|:-----:|
| 1 | Employee's phone lost/stolen | A2, A9 |
| 2 | Attacker opens app → biometric required | Blocked |
| 2b | Biometric can be bypassed on some devices | A9, A2 |
| 3 | Attacker views employee dashboard, attendance history, name, code | A4 |
| 4 | If biometric bypassed + session active → check-in/out | A5 |

**Likelihood:** Medium | **Impact:** Low-Medium | **Priority: MEDIUM**

**Existing Controls:**
- Biometric required to open app
- JWT session expires over time

**Gaps:**
- No remote session invalidation
- No geo-fencing on app access
- No PIN fallback on biometric screen (redirects to full login)
- Biometric can be bypassed on rooted/unlocked devices

---

### 🟢 Low

#### PATH-L01: Leave Request Data Leakage

| Step | Description | Asset |
|:----:|-------------|:-----:|
| 1 | Employee submits leave with detailed personal/medical reason | A8 |
| 2 | RLS allows admins to view all leave requests | A8 |
| 3 | Admin with legitimate access sees sensitive information | A8 |

**Likelihood:** High (normal operation) | **Impact:** Low | **Priority: LOW**

**Existing Controls:**
- Employee views own leaves; Admin views all
- No unnecessary data exposure

**Gaps:**
- Reasons are free-text — employees may overshare personal details
- No data classification or redaction

---

#### PATH-L02: Static API Key in Client

| Step | Description | Asset |
|:----:|-------------|:-----:|
| 1 | Attacker decompiles APK | A1 |
| 2 | Extracts `sb_publishable_...` key | A1 |
| 3 | Uses key to query Supabase public endpoints | A1 |

**Likelihood:** High | **Impact:** Low | **Priority: LOW**

**Existing Controls:**
- Anon key is designed to be public (Supabase architecture)
- RLS policies limit what unauthenticated/anonymous requests can access
- PostgREST rejects queries without valid JWT for protected tables

**Gaps:**
- Key rotation would require app update
- No key scoping to specific IPs or referrers

---

## 7. Authentication & Authorization Review

### Current Implementation

| Mechanism | Strength | Notes |
|-----------|:--------:|-------|
| **Admin email/password** | 🟡 Moderate | Supabase Auth handles hashing. No MFA. |
| **Employee code + PIN** | 🟡 Moderate | 4-digit PIN (10k combos). Padded to 6+ chars for Supabase. |
| **Biometric (local_auth)** | 🟢 Strong | Fingerprint on device. OS-level security. |
| **JWT session** | 🟢 Strong | Standard JWT. Supabase-managed. |
| **RLS policies** | 🟢 Strong | Row-level on all tables. Role-checked. |
| **Edge Function auth** | 🟢 Strong | Admin role verified server-side. |

### Gaps

| Gap | Priority | Recommendation |
|-----|:--------:|---------------|
| **No MFA for admin** | 🔴 Critical | Enable MFA in Supabase Auth settings |
| **PIN is 4 digits** | 🟡 Medium | Increase to 6 digits (still easy for laborers) |
| **Lockout is client-only** | 🔴 Critical | Add server-side rate limiting (Edge Function tracks IP/user) |
| **No session revocation** | 🟡 Medium | Implement "sign out all devices" feature |

---

## 8. QR Attendance Security Review

| Threat | Existing Control | Gap | Priority |
|--------|-----------------|:---:|:--------:|
| QR photo scanning | GPS verification prevents | GPS spoofing bypasses | 🟠 **HIGH** |
| QR reuse (static QR) | GPS verification + database coords | Same QR printed once — GPS is only barrier | 🟡 **MEDIUM** |
| QR interception (MITM) | HTTPS | — | 🟢 **LOW** |
| QR tampering | QR contains JSON with office ID + coords | Tampered QR would cause GPS mismatch | 🟢 **LOW** |

### Recommendation
- **Short-term:** Keep current QR + GPS dual verification (functional for 10-15 employees)
- **Medium-term:** Add photo selfie during check-in as additional verification layer
- **Long-term:** Consider time-limited QR tokens if scale increases

---

## 9. GPS Verification Review

| Threat | Existing Control | Gap | Priority |
|--------|-----------------|:---:|:--------:|
| GPS spoofing | — | No checks on mock location settings | 🟠 **HIGH** |
| GPS drift indoors | Configurable allowed_radius | Radius may be too large | 🟡 **MEDIUM** |
| No GPS signal (basement) | — | Check-in may fail | 🟡 **MEDIUM** |
| GPS accuracy on cheap phones | — | May produce inaccurate coordinates | 🟡 **MEDIUM** |

### Recommendation
- **Short-term:** Check `LocationService.isFromMockProvider()` to detect spoofing
- **Medium-term:** Use WiFi SSID as additional verification
- **Long-term:** Add BLE beacon at office entrance

---

## 10. Biometric Authentication Review

| Threat | Existing Control | Gap | Priority |
|--------|-----------------|:---:|:--------:|
| Fingerprint bypass (rooted) | — | local_auth can be bypassed on compromised devices | 🟡 **MEDIUM** |
| Biometric not enrolled | Fallback to PIN login | Employee must have PIN to fall back | 🟢 **LOW** |
| Biometric data theft | — | Fingerprint never leaves device — OS manages | 🟢 **LOW** |
| Auto biometric prompt removed (user's choice) | — | Tap icon → dialog → sensor (current flow) | 🟢 **LOW** |

### Recommendation
- Check `stickyAuth: true` is already set (native dialog stays open)
- Flow: Open app → pulsing icon → **tap icon** → native dialog → sensor → dashboard
- No changes recommended for current implementation

---

## 11. Supabase RLS & Edge Functions Review

### RLS Coverage

| Table | Select | Insert | Update | Delete |
|-------|:------:|:------:|:------:|:------:|
| `profiles` | Own + Admin all | Admin only | Own + Admin all | — |
| `attendance` | Own + Admin all | Own | Own | — |
| `company_settings` | All (public) | — | Admin only | — |
| `leave_requests` | Own + Admin all | Own | Admin only | — |
| `departments` | All | — | — | — |
| `holidays` | All | — | — | — |

**Status: ✅ Policies cover all tables. Role-based access enforced.**

### Edge Function: `manage-pin`

| Aspect | Status |
|--------|:------:|
| Admin role verification | ✅ Server-side `role = 'admin'` check |
| PIN hashing | ✅ SHA-256 on client side before sending |
| Password update | ✅ Via `auth.admin.updateUserById()` |
| `service_role` exposure | ✅ Never in client code |
| Error handling | ⚠️ Generic error messages returned |
| Rate limiting | ❌ None on the Edge Function itself |
| Audit logging | ❌ No logging of actions |

### Edge Function Gap — Priority: HIGH

The Edge Function has no rate limiting. An attacker with compromised admin credentials could call `set-pin` for all 15 employees in seconds. **Recommendation:** Add rate limiting within the Edge Function (track requests per admin_id, limit to 10 `set-pin` calls per hour).

---

## 12. Secure Storage & Secrets Handling

| Secret | Location | Storage Method | Risk |
|--------|----------|:--------------:|:----:|
| Supabase anon key | Flutter `constants.dart` | Hardcoded string | **Low** (public by design) |
| Supabase URL | Flutter `constants.dart` | Hardcoded string | **Low** (public) |
| JWT session | Supabase client memory | Managed by SDK | **Medium** — in app memory |
| Employee PIN | In transit + Supabase Auth (bcrypt) | HTTPS + bcrypt | **Low** (properly hashed) |
| Biometric preference | `SharedPreferences` | Unencrypted | **Low** (boolean only) |
| PIN lockout counter | `SharedPreferences` | Unencrypted | **Low** (bypassable anyway) |
| `service_role` key | Edge Function env variables | Supabase-managed | **Low** (never in app) |
| Supabase Dashboard creds | Admin's password manager | Varies | **High** — depends on admin's security |

### Gaps

| Gap | Priority | Recommendation |
|-----|:--------:|---------------|
| SharedPreferences are unencrypted | 🟢 LOW | Not critical — no sensitive data stored |
| Anon key rotation requires app update | 🟢 LOW | Acceptable for current scale |
| No secret rotation policy | 🟡 MEDIUM | Plan for periodic key rotation as company grows |

---

## 13. Risk Summary

| Priority | Count | Key Items |
|:--------:|:-----:|-----------|
| 🔴 **CRITICAL** | 2 | Admin account takeover (no MFA), PIN brute force (no server-side lockout) |
| 🟠 **HIGH** | 3 | GPS spoofing, QR replay, employee privilege escalation via token |
| 🟡 **MEDIUM** | 4 | Attendance record manipulation, Edge Function audit logging, leave data exposure, device theft |
| 🟢 **LOW** | 2 | Static API key in client, auto biometric removal |

---

## 14. Mitigation Recommendations (Prioritized)

### 🔴 Immediate (Before Production)

| # | Recommendation | Area | Effort |
|:-:|---------------|------|:------:|
| R1 | **Enable MFA on admin Supabase account** — go to Supabase Dashboard → Authentication → MFA → enable | Admin auth | 2 min |
| R2 | **Add server-side PIN attempt tracking** via Edge Function. Track failed attempts in a simple in-memory map or DB, reject after 5 attempts within 30 min. | PIN login | 1 hour |
| R3 | **Change employee lockout from SharedPreferences to Edge Function-based** — call Edge Function `check-login-attempt` before allowing login. | PIN login | 30 min |
| R4 | **Add `isFromMockProvider()` check** in GPS verification to detect spoofing | GPS | 15 min |

### 🟡 This Week

| # | Recommendation | Area | Effort |
|:-:|---------------|------|:------:|
| R5 | **Add audit logging** to Edge Function — log each `set-pin` call to a new `admin_audit_log` table (admin_id, action, target, timestamp) | Edge Function | 30 min |
| R6 | **Add rate limiting** to Edge Function — max 10 PIN resets per admin per hour | Edge Function | 15 min |
| R7 | **Re-evaluate attendance status server-side on check-out** — don't trust client-sent status | Attendance | 20 min |
| R8 | **Add "Sign out all devices" feature** in admin settings | Auth | 1 hour |

### 🟢 This Month

| # | Recommendation | Area | Effort |
|:-:|---------------|------|:------:|
| R9 | **Consider increasing PIN to 6 digits** for future employees | Auth | 10 min |
| R10 | **Add WiFi SSID verification** as secondary location check | GPS | 2 hours |
| R11 | **Plan for employee code randomization** — use UUIDs if scaling to 100+ | Auth | 30 min |
| R12 | **Document incident response** for stolen phone, compromised admin | Operations | 1 hour |

---

## 15. Key Assumptions

| # | Assumption | If Wrong → Impact |
|:-:|-----------|:-----------------:|
| 1 | Admin uses strong, unique password + enables MFA | Admin account takeover becomes much easier |
| 2 | Employee phones are not rooted/jailbroken | Biometric bypass, GPS spoofing become trivial |
| 3 | GPS accuracy is within 10-50m indoors | Check-ins may fail in large buildings |
| 4 | Employee codes are not publicly posted | Code guessing becomes easier |
| 5 | Static QR at office is physically protected | QR photo attack becomes trivial (but GPS still blocks) |

---

## 16. Questions for System Owner

These assumptions should be validated:

1. **Is the admin currently using MFA on Supabase?** (If not — treat R1 as critical)
2. **Are employee phones company-issued or BYOD?** (BYOD → assume some devices may be rooted)
3. **Is the QR code printed in a publicly accessible area?** (If yes → higher QR tampering risk)
4. **Are there plans to integrate payroll before these security improvements?** (If yes → accelerate R7)

---

*Report generated by security-threat-model skill. Review all recommendations with system owner before implementation.*
