"""Writes the JSON fixtures used by the unit tests (one per endpoint of API 1.4.0).

Values are realistic but invented: no real passwords, tokens or customer data.
Run:  python scripts/make_fixtures.py
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "HallakAdminTests" / "Fixtures"
# Same answers for the Debug-only demo mode (left out of Release builds).
DEMO = ROOT / "HallakAdmin" / "DemoData"
META = {"generated_at": "2026-11-19 13:13", "tz": "Asia/Beirut"}


def usd(a):
    return {"amount": a, "currency": "USD", "display": f"${a:,.2f}".replace(".00", "")}


def lbp(a):
    return {"amount": a, "currency": "LBP", "display": f"{a:,} LBP"}


def page(items, total=None, pages=1, p=1, per_page=25):
    return {"items": items, "page": p, "per_page": per_page, "total": total if total is not None else len(items), "pages": pages}


BILLING_ACTIVE = {
    "status": "active", "status_label": "Paid", "plan_id": 2, "plan": "Pro", "cycle": "month",
    "price": usd(30), "monthly": usd(30), "own_price": False,
    "until": "2026-12-07", "days_left": 18, "grace_end": None, "trial": False,
    "type": "paid", "type_label": "Paid",
}
BILLING_GRACE = {
    "status": "grace", "status_label": "Payment due", "plan_id": 1, "plan": "Basic", "cycle": "year",
    "price": usd(240), "monthly": usd(20), "own_price": True,
    "until": "2026-11-16", "days_left": -3, "grace_end": "2026-11-23", "trial": False,
    "type": "paid", "type_label": "Paid",
}

SALON_1 = {
    "id": 1, "slug": "emmanuel-hairstyle", "name": "Emmanuel Hairstyle", "phone": "+961 70 123 456",
    "address": "Jounieh, main road", "currency": "USD", "language": "ar", "status": "active",
    "created_at": "2026-09-02 10:15", "last_activity": "2026-11-19 12:40",
    "owner": {"id": 118, "username": "gio", "name": "Gio Emmanuel", "email": "gio@example.com"},
    "billing": BILLING_ACTIVE,
}
SALON_2 = {
    "id": 7, "slug": "studio-7", "name": "Studio 7", "phone": "+961 3 555 777", "address": "Zahle",
    "currency": "LBP", "language": "en", "status": "suspended", "created_at": "2026-10-01 09:00",
    "last_activity": None, "owner": None, "billing": BILLING_GRACE,
    "unknown_future_field": {"ignored": True},
}

INVOICE_PAID = {
    "id": 12, "number": "HL-2026-0012", "salon_id": 1, "salon_name": "Emmanuel Hairstyle", "plan": "Pro",
    "period_from": "2026-11-07", "period_to": "2026-12-07", "months": 1, "amount": usd(30),
    "status": "paid", "method": "whish", "method_label": "Whish", "paid_at": "2026-11-07 18:02",
    "note": "", "created_at": "2026-11-07 17:55",
}
INVOICE_UNPAID = {
    "id": 15, "number": "HL-2026-0015", "salon_id": 7, "salon_name": "Studio 7", "plan": "Basic",
    "period_from": "2026-11-16", "period_to": "2027-11-16", "months": 12, "amount": usd(240),
    "status": "unpaid", "method": None, "method_label": None, "paid_at": None,
    "note": "Asked to pay by OMT", "created_at": "2026-11-16 09:00",
}

PLAN_META = {"generated_at": "2027-03-14 10:00", "tz": "Asia/Beirut"}


def checklist(month, contacts=12, followups=True):
    items = [
        {"slug": "contacts", "label": "Salons contacted", "type": "count", "target": 25, "value": contacts,
         "done": contacts >= 25, "hint": None},
        {"slug": "demos", "label": "Demos given", "type": "count", "target": 4, "value": 4, "done": True,
         "hint": "2 demo requests came from the website this month."},
        {"slug": "offers", "label": "Offers sent", "type": "count", "target": None, "value": 1, "done": None, "hint": None},
        {"slug": "posts", "label": "Posts on Instagram", "type": "count", "target": 8, "value": 3, "done": False, "hint": None},
        {"slug": "followups", "label": "Followed up every trial", "type": "check", "target": None, "value": followups,
         "done": followups, "hint": None},
        {"slug": "renewals", "label": "Called salons to renew", "type": "check", "target": None, "value": False,
         "done": False, "hint": "1 salon ends its paid time within 60 days."},
    ]
    goal = [i for i in items if i["done"] is not None]
    return {"month": month, "done": sum(1 for i in goal if i["done"]), "of": len(goal), "items": items}


def plan_year(y, name, new, renewed, total, current, status, actual=None, quarters=None):
    q = quarters or [
        {"q": i + 1, "new_target": n, "cumulative_target": c, "actions": None, "new": None, "cumulative": None}
        for i, (n, c) in enumerate(zip([4, 4, 5, 4], [12, 16, 21, total]))
    ]
    return {
        "year": y, "name": name, "objective": "Paying salons at $300 a year, renewed every year.",
        "priorities": ["Sign the first salons in Jounieh and Byblos", "Answer every demo request the same day"],
        "success": "10 salons pay for the whole year" if y == 2027 else None,
        "targets": {"new": new, "renewed": renewed, "total": total, "price": usd(300), "revenue": usd(total * 300),
                    "monthly": usd(total * 25)},
        "actual": actual, "quarters": q,
        "progress": {"status": status, "expected_now": 3 if current else 0, "total_pct": 30 if current else None,
                     "revenue_pct": 30 if current else None},
        "current": current,
    }


PLAN = {
    "title": "Business plan 2027-2029", "subtitle": "From 10 to 45 paying salons",
    "summary": "Hallak grows from Mount Lebanon to the whole country, one salon at a time.",
    "assumptions": ["$300 a year per salon", "80% of salons renew"],
    "currency": "USD", "billing_active": True, "renewal_target": 80,
    "customized": True, "changed": {"at": "2027-02-01 18:20", "by": "Mishel"},
    "years": [
        plan_year(2027, "Launch and establish the business", 10, 0, 10, True, "on_track",
                  actual={"started": True, "new": 3, "renewed": 0, "total_paying": 3, "revenue": usd(900),
                          "monthly": usd(75), "renewal_rate": None, "renewal_of": None},
                  quarters=[
                      {"q": 1, "new_target": 2, "cumulative_target": 2, "actions": "Visit 25 salons, 4 demos a month",
                       "new": 3, "cumulative": 3},
                      {"q": 2, "new_target": 3, "cumulative_target": 5, "actions": None, "new": None, "cumulative": None},
                      {"q": 3, "new_target": 3, "cumulative_target": 8, "actions": None, "new": None, "cumulative": None},
                      {"q": 4, "new_target": 2, "cumulative_target": 10, "actions": "Renewal calls", "new": None,
                       "cumulative": None},
                  ]),
        plan_year(2028, "Grow in Mount Lebanon", 17, 8, 25, False, "not_started"),
        plan_year(2029, "Cover all of Lebanon", 24, 21, 45, False, "not_started"),
    ],
    "three_year": {"target_revenue": usd(24000), "actual_revenue": usd(900)},
    "kpis": [
        {"slug": "paying", "label": "Paying salons", "what": "Salons with paid time running today.", "value": 3},
        {"slug": "new", "label": "New salons", "what": "First payment this month / quarter.",
         "value": {"month": 1, "quarter": 3}},
        {"slug": "renewal", "label": "Renewal rate", "what": "Of last year's paying salons, how many paid again.",
         "value": None},
        {"slug": "pipeline", "label": "Sales pipeline", "what": "This month.",
         "value": {"contacted": 12, "demos": 4, "offers": 1, "website_requests": 2}},
        {"slug": "cash", "label": "Cash collected", "what": "From paid invoices.",
         "value": {"month": usd(300), "year": usd(900), "unpaid": {"count": 1, "amount": usd(300)}}},
        {"slug": "satisfaction", "label": "Salon satisfaction", "what": "Ask each salon once a quarter.", "value": None},
    ],
    "renewals_due": [
        {"salon_id": 1, "salon_name": "Emmanuel Hairstyle", "status": "active", "until": "2027-04-20", "days_left": 37,
         "amount": usd(300), "phone": "+961 70 123 456", "whatsapp_link": "https://wa.me/96170123456?text=Renewal"},
        {"salon_id": 7, "salon_name": "Studio 7", "status": "grace", "until": "2027-03-10", "days_left": -4,
         "amount": usd(300), "phone": None, "whatsapp_link": None},
    ],
    "checklist": checklist("2027-03"),
    "roadmap": [
        {"priority": "critical", "capability": "Appointments and visits", "timing": 2027, "status": "ready",
         "plugins": ["salon-manager-core"]},
        {"priority": "high", "capability": "WhatsApp bot", "timing": 2027, "status": "partial", "plugins": ["hallak-whatsapp"]},
        {"priority": "medium", "capability": "Online payments", "timing": 2028, "status": "planned", "plugins": []},
    ],
    "budget": {
        "year": 2027, "base": usd(900), "base_target": usd(3000), "note": "Shares of the cash collected this year.",
        "items": [
            {"slug": sl, "label": lb, "share": sh, "amount": usd(9 * sh), "amount_target": usd(30 * sh)}
            for sl, lb, sh in [("hosting", "Hosting", 15), ("marketing", "Marketing", 30), ("development", "Development", 25),
                               ("unexpected", "Unexpected", 10), ("reserve", "Reserve", 20)]
        ],
    },
    "tiers": {"items": [
        {"name": "Basic", "price": usd(240), "positioning": "One barber, appointments and visits."},
        {"name": "Pro", "price": usd(300), "positioning": "The whole team, WhatsApp bot, reports."},
    ], "note": "Ideas only: prices are set in Billing."},
    "recommendation": "Keep one price in 2027; add tiers when 10 salons pay.",
    "note": "Real numbers come from paid invoices in Billing.",
    **PLAN_META,
}

BILLING_TRIAL = {
    "status": "trial", "status_label": "Trial", "plan_id": 2, "plan": "Pro", "cycle": "month",
    "price": usd(30), "monthly": usd(30), "own_price": False,
    "until": "2026-11-24", "days_left": 5, "grace_end": None, "trial": True,
    "type": "trial", "type_label": "Free trial",
}


def demo(key, name, lang, public, nightly, main, salon_id):
    n = "" if key == "1" else key
    d = {
        "key": key, "name": name, "built": True, "salon_id": salon_id, "language": lang,
        "public": public, "nightly": nightly, "main": main, "built_at": "2026-11-20 03:00",
        "owner_login": "demo" + n, "barber_login": "demo" + n + "-barber",
        "password": "demo1234", "barber_password": "barber1234",
        "links": None, "dashboard": "https://hallak.online/salon/demo" + n + "/",
    }
    if public:
        d["links"] = {"owner": "https://hallak.online/?hallak_demo=" + key + "&as=owner",
                      "barber": "https://hallak.online/?hallak_demo=" + key + "&as=barber"}
    return d


DEMO_1 = demo("1", "Hallak demo (English)", "en", True, True, True, 90)
DEMO_2 = demo("2", "Karim Barber Shop (demo)", "ar", True, False, False, 91)

FIXTURES = {
    "ping": {
        "ok": True, "user": "mishel-app", "site": "https://hallak.online", "wordpress": "6.8.3",
        "hallak_core": "1.12.4", "api": "1.4.0", "https": True, **META,
    },
    "me": {
        "user": {"id": 2, "username": "mishel-app", "name": "Mishel", "email": "admin@example.com", "last_login": "2026-11-19 13:00"},
        "language": "en", "can": {"read": True, "write": True, "open_links": True, "plan": True, "demos": True},
        "site": {
            "name": "Hallak", "url": "https://hallak.online", "wordpress": "6.8.3", "hallak_core": "1.4.2", "api": "1.0.1",
            "plugins": {"billing": True, "site": True, "whatsapp": True, "ai": False, "check": True},
        },
        **META,
    },
    "overview": {
        "salons": {"total": 23, "active": 22, "suspended": 1},
        "billing": {"free": 2, "demo": 2, "trial": 3, "active": 16, "grace": 1, "overdue": 1},
        "types": {"paid": 18, "trial": 3, "free": 2, "demo": 2},
        "money": {"mrr": usd(690), "paid_this_month": usd(520), "unpaid": {"count": 4, "amount": usd(170)}},
        "leads": {"new": 2},
        "whatsapp": {"replies_month": 1840, "cost_month": usd(6.4), "chats_need_team": 3},
        "health": {"errors": 0, "warnings": 2},
        "activity_today": 57,
        **META,
    },
    "health": {
        "available": True, "check_version": "1.0.6",
        "environment": {"wordpress": "6.8.3", "php": "8.2.27", "memory_limit": "512M", "https": True},
        "plugins": [
            {"number": 1, "folder": "salon-manager", "name": "Hallak Core", "installed": "1.4.2", "latest": "1.4.2", "active": True, "up_to_date": True},
            {"number": 2, "folder": "salon-manager-billing", "name": "Hallak Billing", "installed": "1.1.0", "latest": "1.2.0", "active": True, "up_to_date": False},
            {"number": 9, "folder": "salon-manager-ai", "name": "Hallak AI", "installed": None, "latest": "1.0.3", "active": False, "up_to_date": None},
        ],
        "problems": [
            {"level": "info", "text": "Hallak AI is not installed."},
            {"level": "warn", "text": "Hallak Billing 1.1.0 is old: upload 1.2.0."},
            {"level": "error", "text": "WP-Cron is off: reminders are not sent. Turn it on in wp-config.php."},
        ],
        **META,
    },
    "activity": {
        **page([
            {"id": 9001, "salon_id": 1, "salon_name": "Emmanuel Hairstyle", "action": "appointment_online",
             "summary": "New online booking: Karim, haircut, 20 Nov 16:00", "object_type": "appointment", "object_id": 551,
             "by": None, "details": {"service": "Haircut", "price": 10, "online": True}, "at": "2026-11-19 12:40"},
            {"id": 9000, "salon_id": 7, "salon_name": None, "action": "billing_invoice_created",
             "summary": "Invoice HL-2026-0015 created", "object_type": "billing", "object_id": 15,
             "by": {"id": 2, "name": "Mishel"}, "details": {"nested": {"a": 1}}, "at": "2026-11-16 09:00"},
        ], total=57, pages=29, per_page=2),
        **META,
    },
    "features": {
        "items": [
            {"slug": "appointments", "label": "Appointments", "help": "Online booking and the calendar.", "default": True},
            {"slug": "wabot", "label": "WhatsApp bot", "help": "Answers customers on WhatsApp.", "default": False},
            {"slug": "loyalty", "label": "Loyalty", "help": "Points and free visits.", "default": False},
        ],
        **META,
    },
    "salons": {**page([SALON_1, SALON_2], total=23, pages=12, per_page=2), **META},
    "salon": {
        "salon": {**SALON_1, "notes": "Pays on the 7th.", "fx": {"second": "LBP", "rate": 89500}},
        "features": [
            {"slug": "appointments", "label": "Appointments", "on": True},
            {"slug": "wabot", "label": "WhatsApp bot", "on": True},
            {"slug": "loyalty", "label": "Loyalty", "on": False},
        ],
        "links": {
            "dashboard": "https://hallak.online/salon/emmanuel-hairstyle/",
            "page": "https://hallak.online/s/emmanuel-hairstyle/",
            "booking": "https://hallak.online/booking/emmanuel-hairstyle/",
            "whatsapp": "https://wa.me/96170123456",
        },
        "invoices": [INVOICE_PAID],
        "month": {"visits": 312, "revenue": usd(3120.5), "customers": 201},
        "whatsapp": {"feature_on": True, "bot_on": True, "number_linked": True, "replies_month": 640,
                     "limit": 1000, "own_limit": False, "chats_need_team": 1, "cost_month": usd(2.1)},
        "ai": {"feature_on": False, "questions_month": 0, "limit": 0, "own_limit": False, "cost_month": usd(0)},
        **META,
    },
    "salon_users": {
        "items": [
            {"id": 118, "username": "gio", "name": "Gio Emmanuel", "email": "gio@example.com", "last_login": "2026-11-19 09:12", "role": "owner"},
            {"id": 131, "username": "tony", "name": "Tony", "email": "", "last_login": None, "role": "staff"},
        ],
        **META,
    },
    "subscription": {"salon_id": 7, "subscription": BILLING_GRACE, "open_invoice": INVOICE_UNPAID, **META},
    "subscription_none": {"salon_id": 3, "subscription": None, "open_invoice": None, **META},
    "owners": {
        **page([
            {"id": 118, "username": "gio", "name": "Gio Emmanuel", "email": "gio@example.com", "last_login": "2026-11-19 09:12",
             "salons": [{"id": 1, "name": "Emmanuel Hairstyle", "status": "active"}, {"id": 4, "name": "Emmanuel Kaslik", "status": "active"}]},
            {"id": 140, "username": "rami", "name": "", "email": "rami@example.com", "last_login": None, "salons": []},
        ]),
        **META,
    },
    "billing_summary": {
        "currency": "USD", "mrr": usd(690), "paid_this_month": usd(520),
        "unpaid": {"count": 4, "amount": usd(170)},
        "salons": {"free": 2, "demo": 2, "trial": 3, "active": 16, "grace": 1, "overdue": 1},
        "due_soon": [
            {"salon_id": 7, "salon_name": "Studio 7", "status": "grace", "until": "2026-11-16", "days_left": -3},
            {"salon_id": 1, "salon_name": "Emmanuel Hairstyle", "status": "active", "until": "2026-12-07", "days_left": 18},
            {"salon_id": 9, "salon_name": "Rami Cuts", "status": "trial", "until": None, "days_left": None},
        ],
        "grace_days": 7,
        "methods": [
            {"slug": "cash", "label": "Cash"}, {"slug": "whish", "label": "Whish"}, {"slug": "omt", "label": "OMT"},
            {"slug": "bank", "label": "Bank transfer"}, {"slug": "other", "label": "Other"},
        ],
        **META,
    },
    "plans": {
        "items": [
            {"id": 1, "name": "Basic", "price_month": usd(20), "price_year": usd(200), "features": ["appointments", "page"], "note": "", "active": True},
            {"id": 2, "name": "Pro", "price_month": usd(30), "price_year": usd(300), "features": ["appointments", "page", "loyalty", "wabot"], "note": "Most salons", "active": True},
            {"id": 3, "name": "Old Lira plan", "price_month": lbp(1800000), "price_year": lbp(18000000), "features": [], "note": "", "active": False},
        ],
        **META,
    },
    "invoices": {**page([INVOICE_UNPAID, INVOICE_PAID]), **META},
    "invoice": {"invoice": INVOICE_UNPAID, **META},
    "leads": {
        **page([
            {"id": 31, "name": "Karim", "salon": "Karim Barbershop", "phone": "+961 76 123 456", "email": "karim@example.com",
             "plan": "Pro", "barbers": "3", "message": "I want to try online booking.", "status": "new",
             "created_at": "2026-11-19 11:02", "whatsapp": "https://wa.me/96176123456"},
            {"id": 30, "name": "Elie", "salon": "Elie Style", "phone": 96103111222, "email": "",
             "plan": "", "barbers": 2, "message": "", "status": "done", "created_at": "2026-11-12 16:40", "whatsapp": None},
        ]),
        "new": 1,
        **META,
    },
    "whatsapp": {
        "month": "2026-11", "model": "claude-haiku-5-5", "limit": 1000, "key_set": True,
        "prices": {"in": 1.0, "out": 5.0},
        "last_error": {"at": "2026-11-18 22:10", "text": "Whapi: number not connected (Studio 7)"},
        "totals": {"replies": 1840, "cost": usd(6.4)},
        "salons": [
            {"salon_id": 1, "salon_name": "Emmanuel Hairstyle", "feature_on": True, "tokens": {"in": 820000, "out": 160000},
             "cost": usd(2.1), "limit": 1000, "own_limit": None, "bot_on": True, "number_linked": True, "replies": 640, "chats_need_team": 1},
            {"salon_id": 7, "salon_name": "Studio 7", "feature_on": True, "tokens": {"in": 0, "out": 0},
             "cost": usd(0), "limit": 300, "own_limit": 300, "bot_on": False, "number_linked": False, "replies": 0, "chats_need_team": 2},
        ],
        **META,
    },
    "ai": {
        "month": "2026-11", "model": "claude-sonnet-5-5", "limit": 200, "weekly": True, "key_set": False,
        "prices": {"in": 3.0, "out": 15.0},
        "totals": {"questions": 212, "cost": usd(1.9)},
        "salons": [
            {"salon_id": 1, "salon_name": "Emmanuel Hairstyle", "feature_on": True, "tokens": {"in": 120000, "out": 30000},
             "cost": usd(0.81), "limit": 200, "own_limit": None, "questions": 140, "summaries": 4},
        ],
        **META,
    },
    "login-link": {
        "url": "https://hallak.online/?hallak_open=" + "0" * 64, "expires_in": 120,
        "opens": "https://hallak.online/salon/emmanuel-hairstyle/appointments/", **META,
    },
    "salon_created": {
        "salon": {**SALON_1, "id": 41, "slug": "postman-test", "name": "Postman Test", "notes": "", "fx": None},
        "features": [{"slug": "wabot", "label": "WhatsApp bot", "on": True}, {"slug": "queue", "label": "Queue", "on": False}],
        "links": {"dashboard": "https://hallak.online/salon/postman-test/", "page": None, "booking": None,
                  "whatsapp": "https://wa.me/96170000000"},
        "invoices": [], "month": {"visits": 0, "revenue": usd(0), "customers": 0},
        "login": {"username": "postman123", "password": "Xk7pQ2m9wLeT", "login_url": "https://hallak.online/login/",
                  "whatsapp_link": "https://wa.me/96170000000?text=Hallak%20login"},
        "warnings": ["The plan has no features: the features you chose were kept."],
        **META,
    },
    "password_reset": {
        "user": {"id": 118, "username": "gio", "name": "Gio Emmanuel", "email": "gio@example.com", "last_login": None},
        "password": "Np4vR8sK2wQa", "login_url": "https://hallak.online/login/",
        "whatsapp_link": "https://wa.me/96170123456?text=New%20password", **META,
    },
    "invoice_paid": {
        "invoice": {**INVOICE_UNPAID, "status": "paid", "method": "whish", "method_label": "Whish", "paid_at": "2026-11-20 10:05"},
        "subscription": {**BILLING_GRACE, "status": "active", "status_label": "Paid", "until": "2027-11-16", "days_left": 361},
        **META,
    },
    "salon_deleted": {"deleted": True, "id": 41, "name": "Postman Test", "rows": 37, "message": "Salon deleted.", **META},
    "lead_done": {"lead": {"id": 31, "name": "Karim", "salon": "Karim Barbershop", "phone": "+961 76 123 456",
                           "email": "karim@example.com", "plan": "Pro", "barbers": "3", "message": "", "status": "done",
                           "created_at": "2026-11-19 11:02", "whatsapp": "https://wa.me/96176123456"}, "new": 0, **META},
    "plan": PLAN,
    "plan_checklist": {**checklist("2027-02", contacts=25, followups=False), **PLAN_META},
    "error_budget": {"code": "smapi_budget", "message": "The budget shares must add up to 100.",
                     "data": {"status": 400, "field": "budget"}},
    "demos": {"items": [DEMO_1, DEMO_2], "max": 10, "can_add": True, "missing": [], "languages": ["en", "ar"], **META},
    "demo_one": {"demo": DEMO_2, **META},
    "subscription_trial": {"salon_id": 41, "subscription": BILLING_TRIAL, "open_invoice": None, **META},
    "error_plan": {"code": "smb_plan", "message": "A paid account needs a plan.", "data": {"status": 400, "field": "plan_id"}},
    "error_conflict": {"code": "sm_user", "message": "This username is already used.",
                       "data": {"status": 409, "field": "owner.username"}},
    "error_not_found": {"code": "smapi_not_found", "message": "Salon not found.", "data": {"status": 404}},
    "error_login": {
        "code": "smapi_login", "message": "Wrong username or Application Password.",
        "data": {"status": 401, "check": {"user_exists": "yes", "app_passwords_on": True, "header_received": "yes"}},
    },
}


def main():
    for folder in (OUT, DEMO):
        folder.mkdir(parents=True, exist_ok=True)
        for name, body in FIXTURES.items():
            (folder / f"{name}.json").write_text(json.dumps(body, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(FIXTURES)} fixtures in {OUT} and {DEMO}")


if __name__ == "__main__":
    main()
