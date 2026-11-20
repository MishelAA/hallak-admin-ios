# Hallak admin API – guide for the iPhone app

API version **1.2.0**: read everything, open dashboards signed in, and make the same changes as wp-admin. The exact description of every field is in **hallak-api.yaml** (OpenAPI 3.1). Give both files to Claude Code when you build the app.

## 1. Connect

| | |
|---|---|
| Base address | `https://hallak.online/wp-json/hallak/v1` |
| Login | HTTP Basic: `username:application-password` |
| Language | `Accept-Language: ar` or `en` (labels and error messages) |
| Format | JSON, UTF-8. Times in Lebanon time: `2026-11-17 22:45`. Days: `2026-11-17` |

1. wp-admin → Users → Profile → **Application Passwords** → name "Hallak iPhone" → **Add New Application Password**. Copy it (shown once).
2. Test from a computer:

```
curl -u "admin:abcd efgh ijkl mnop qrst uvwx" https://hallak.online/wp-json/hallak/v1/admin/ping
```

Answer: `{"ok":true,"user":"…","api":"1.0.0",…}`.

Only administrators can use the API. A salon owner or barber gets `403 smapi_forbidden`, even with a correct password. The normal wp-admin password does not work here: only Application Passwords.

## 2. Rules the app must follow

- **HTTPS only.** Refuse any address that does not start with `https://`.
- **Keychain** for the username and Application Password. Never UserDefaults, never logs.
- **Face ID** (LocalAuthentication) to open the app.
- **Every answer** has `generated_at` and `tz`. Show "Updated 22:45" from `generated_at`.
- **Lists** have `items`, `page`, `per_page`, `total`, `pages`. Ask with `?page=2&per_page=25` (max 100). Load the next page when the user scrolls to the end.
- **Money** is always an object: `{"amount": 25.5, "currency": "USD", "display": "$25.50"}`. Show `display`; use `amount` only to calculate or sort.
- **ETag:** every GET answer has an `ETag` header. Save it with the data; next time send `If-None-Match: <etag>`. A `304` (empty body) means "nothing changed": show the saved data.
- **Unknown fields:** ignore them (new fields may be added in 1.x; nothing is removed or renamed before `/v2`).
- **Missing sections:** in `/admin/overview` and `/admin/me`, a section is missing when its plugin is off (`site.plugins` in `/admin/me` says which). Hide that card/screen.

## 3. Errors

Always the same shape:

```json
{ "code": "smapi_not_found", "message": "Salon not found.", "data": { "status": 404 } }
```

Show `message` to the user (it is already in his language). React to `code`:

| HTTP | code | What the app does |
|---|---|---|
| 401 | `smapi_no_auth_header` | "The server removed the login. In wp-admin → Salons → iPhone app (API) press Fix the server." |
| 401 | `smapi_login` | Wrong username/password → back to the login screen |
| 403 | `smapi_forbidden` | This account is not an administrator |
| 403 | `smapi_https` | The site is not https |
| 404 | `smapi_not_found` | Show "not found", go back |
| 404 | `smapi_no_billing` / `smapi_no_site` / `smapi_no_whatsapp` / `smapi_no_ai` | That plugin is off: hide the screen |
| 429 | `smapi_slow_down` | More than 120 requests in a minute: wait and retry once |
| 429 | `smapi_locked` | 10 wrong passwords from this address: locked 15 minutes |
| 5xx | – | "Server problem, try again" + retry button |

## 4. Endpoints (1.0)

| Screen | Endpoint | Notes |
|---|---|---|
| First launch | `GET /admin/ping` | Test the login |
| Settings | `GET /admin/me` | User, language, active plugins, versions |
| Home | `GET /admin/overview` | All the cards in one call |
| Health | `GET /admin/health` | Plugins, versions, problems with the fix text |
| Activity | `GET /admin/activity` | `salon_id`, `type`, `action`, `from`, `to`, `search` |
| Salons | `GET /admin/salons` | `search`, `status`, `billing`, `owner_id`, `sort=new|name|until|activity` |
| Salon | `GET /admin/salons/{id}` | Details, features, links, last 5 invoices, this month, WhatsApp, AI |
| Salon → team | `GET /admin/salons/{id}/users` | Owner and staff logins (no passwords) |
| Salon → plan | `GET /admin/salons/{id}/subscription` | Plan, paid until, open invoice |
| Owners | `GET /admin/owners` | Owners with their salons (branches) |
| Money | `GET /admin/billing/summary` | MRR, paid this month, unpaid, due soon, payment methods |
| Money → plans | `GET /admin/plans` | `active=1` for active plans only |
| Money → invoices | `GET /admin/invoices` | `status`, `salon_id`, `from`, `to` |
| Invoice | `GET /admin/invoices/{id}` | |
| Requests | `GET /admin/leads` | `status=new|done`, `search`; each has a `whatsapp` link |
| More → WhatsApp | `GET /admin/whatsapp` | Model, limits, cost per salon (keys are never sent: `key_set`) |
| More → AI | `GET /admin/ai` | Same for the AI assistant |
| Salon switches | `GET /admin/features` | Names of all features (for the salon screen) |

**Billing status** (`billing.status`): `free` not billed · `trial` · `active` paid · `grace` payment due (still working) · `overdue` late. Use `status_label` for the text and `days_left` (negative = late).

**WhatsApp links** (`links.whatsapp`, `leads[].whatsapp`): open with `UIApplication.shared.open(url)`. One tap, as everywhere in Hallak.

## 4b. Open a salon dashboard (or wp-admin) without logging in — API 1.1

```
POST /admin/login-link        {"salon_id": 12, "tab": "appointments"}
→ 201 {"url": "https://hallak.online/?hallak_open=…", "expires_in": 120, "opens": "https://hallak.online/salon/…/appointments/"}
```

- Body: `salon_id` (+ optional `tab`: visits, customers, appointments, queue, staff, attendance, services, inventory, expenses, prepaid, loyalty, messages, mypage, analytics, reports, assistant, whatsapp, branches, subscription, activity, settings, account (only tabs the salon has switched on; empty = Overview); `to`: dashboard | page | booking), or without a salon `to`: wp-admin | salons | billing | check | site.
- The link works **once**, for **2 minutes**. Ask for a new one on every tap, open it right away, never save or share it.
- Open it in the in-app browser: `SFSafariViewController` (simplest; the login stays in Safari's cookies for that view) or a `WKWebView` with the default data store (the login stays inside the app). The website signs the super admin in there with a normal WordPress cookie, then shows the page.
- Expired / used link → a page "This link has expired or was already used" (403): just ask for a new link.
- Only administrators can get links. Each opening shows in wp-admin → Salons → iPhone app (API) as `OPEN`.


## 4c. Changes (API 1.2) — like wp-admin

| What | Request | Body (JSON) |
|---|---|---|
| New salon + owner | `POST /admin/salons` | `{"name","phone","address","currency":"USD","language":"ar","owner":{"username","email","name"},"features":{"wabot":true},"subscription":{"plan_id":2,"until":"2026-12-31","trial":true}}` |
| New branch of an owner | `POST /admin/salons` | `{"name","owner_id": 18}` |
| Change details | `PATCH /admin/salons/{id}` | only what changes: `{"phone":"…","owner":{"email":"…"}}` |
| Suspend / activate | `POST /admin/salons/{id}/suspend` · `/activate` | – |
| Move to another owner | `POST /admin/salons/{id}/move` | `{"owner_id": 18}` |
| Delete (all data!) | `DELETE /admin/salons/{id}` | `{"confirm": "<salon name>"}` |
| Features on/off | `PATCH /admin/salons/{id}/features` | `{"wabot": true, "queue": false}` |
| WhatsApp / AI monthly limit | `PATCH /admin/salons/{id}/limits` | `{"whatsapp": 500, "ai": null}` (null = default, 0 = no limit) |
| New password for a login | `POST /admin/users/{id}/reset-password` | – |
| Subscription | `PUT /admin/salons/{id}/subscription` | `{"plan_id":2,"cycle":"month","until":"2026-12-31","price":null,"trial":false,"apply_features":true}` |
| Invoice / record payment | `POST /admin/salons/{id}/invoices` | `{"months":1}` or `{"months":1,"paid":true,"method":"cash","amount":30}` |
| Mark paid / cancel | `POST /admin/invoices/{id}/pay` · `/void` | `{"method":"whish","note":"…"}` |
| Plans | `POST /admin/plans` · `PATCH /admin/plans/{id}` | `{"name","price_month","price_year","features":["page","wabot"],"active":true}` |
| Demo request | `PATCH /admin/leads/{id}` · `DELETE` · `POST …/convert` | `{"status":"done"}` · – · same body as new salon (missing parts come from the request) |

- The answer is the updated thing (a salon change returns the same as `GET /admin/salons/{id}`), so the app can refresh its screen from it.
- **Passwords** (new salon, convert, reset) come back **once** in `login.password` / `password`, with `whatsapp_link` (the login message, in the salon language). Show them with a "Send on WhatsApp" button and never store them.
- **Errors**: `400` wrong data, `409` conflict (username/email taken, invoice already paid, currency locked). `data.field` names the field to highlight (`name`, `owner.username`, `owner.email`, `owner.password`, `currency`, `plan_id`, `until`, `method`, `confirm`…).
- **Delete** needs the salon name in `confirm`: build a red screen where the user types it. It deletes the owner account too, unless he owns other branches.
- Every change shows in the salon's activity log with "(iPhone app)".

**Coming later:** inside a salon (today, appointments, visits, customers, reports), notifications list. **1.3:** push notifications.

## 5. Swift starter (for Claude Code)

```swift
struct HallakAPI {
    let base: URL            // https://hallak.online/wp-json/hallak/v1
    let user: String         // from Keychain
    let appPassword: String  // from Keychain
    var language = Locale.current.language.languageCode?.identifier == "ar" ? "ar" : "en"

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], etag: String? = nil) async throws -> (T?, String?) {
        var c = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { c.queryItems = query }
        var r = URLRequest(url: c.url!)
        let token = Data("\(user):\(appPassword)".utf8).base64EncodedString()
        r.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        r.setValue(language, forHTTPHeaderField: "Accept-Language")
        if let etag { r.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (data, resp) = try await URLSession.shared.data(for: r)
        let http = resp as! HTTPURLResponse
        if http.statusCode == 304 { return (nil, etag) }            // nothing changed
        guard (200..<300).contains(http.statusCode) else {
            throw try JSONDecoder().decode(APIError.self, from: data)
        }
        return (try JSONDecoder().decode(T.self, from: data), http.value(forHTTPHeaderField: "ETag"))
    }
}

struct APIError: Decodable, Error { let code: String; let message: String }
struct Money: Decodable { let amount: Double; let currency: String; let display: String }
struct Page<T: Decodable>: Decodable { let items: [T]; let page: Int; let per_page: Int; let total: Int; let pages: Int }
```

Prompt idea for Claude Code: *"Build a SwiftUI iPhone app (iOS 17+, English and Arabic with right-to-left) for the Hallak admin API described in hallak-api.yaml and API-GUIDE.md. Tabs: Home, Salons, Money, Requests, More. Store the login in the Keychain, lock with Face ID, use ETag caching, show `display` for money, ignore unknown fields."*

## 6. On the website

wp-admin → **Salons → iPhone app (API)** shows: HTTPS, Application Passwords, pretty links and the login-header fix (with a **Fix the server** button), how to connect, the last 50 requests (time, user, request, answer, IP — never passwords), and these two files.
