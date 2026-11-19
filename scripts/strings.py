"""Writes HallakAdmin/Resources/Localizable.xcstrings and InfoPlist.xcstrings (English + Arabic).

Keys are the English text exactly as written in Swift (%lld = a number, %@ = text).
Add new strings here, then run:  python scripts/strings.py
"""
import json
import pathlib

RES = pathlib.Path(__file__).resolve().parent.parent / "HallakAdmin" / "Resources"

AR = {
    # Errors (APIError)
    "Server problem, try again.": "مشكلة في الخادم، حاول مرة أخرى.",
    "No connection.": "لا يوجد اتصال.",
    "The site must use https.": "يجب أن يستخدم الموقع https.",
    "The server sent an answer the app does not understand.": "أرسل الخادم ردًا لا يفهمه التطبيق.",
    "The server did not receive the login. In wp-admin → Salons → iPhone app (API) press Fix the server.":
        "لم يصل تسجيل الدخول إلى الخادم. في wp-admin ← Salons ← iPhone app (API) اضغط Fix the server.",
    "Unknown username.": "اسم المستخدم غير معروف.",
    "This is not an Application Password.": "هذه ليست كلمة مرور تطبيق (Application Password).",
    "This account is not an administrator.": "هذا الحساب ليس مديرًا.",
    "Not found.": "غير موجود.",
    "Too many requests, wait a minute.": "طلبات كثيرة، انتظر دقيقة.",
    "Locked for 15 minutes after wrong passwords.": "مقفل لمدة ١٥ دقيقة بعد كلمات مرور خاطئة.",
    "Something went wrong.": "حدث خطأ ما.",
    "The site refused the login.": "رفض الموقع تسجيل الدخول.",
    # Dates
    "Today": "اليوم",
    "%lld days left": "باقي %lld يوم",
    "%lld days late": "متأخر %lld يوم",
    # Lock
    "Turn on Face ID for Hallak Admin": "تفعيل Face ID لتطبيق حلّاق",
    "Open Hallak Admin": "افتح حلّاق - الإدارة",
    "Passcode": "رمز الدخول",
    "Cancel": "إلغاء",
    "Hallak Admin is locked": "التطبيق مقفل",
    "Unlock with %@": "افتح بـ %@",
    # Common
    "Hallak": "حلّاق",
    "Hallak Admin": "حلّاق - الإدارة",
    "Offline – showing data from %@": "بدون اتصال – بيانات الساعة %@",
    "Retry": "إعادة",
    "Updated %@": "تحديث %@",
    "Try again": "حاول مرة أخرى",
    "This screen comes in the next builds.": "هذه الشاشة تأتي في النسخ القادمة.",
    "Done": "تم",
    # Login
    "Super admin": "المدير العام",
    "Site address": "عنوان الموقع",
    "Username": "اسم المستخدم",
    "Application Password": "كلمة مرور التطبيق",
    "How do I get an Application Password?": "كيف أحصل على كلمة مرور التطبيق؟",
    "Details": "التفاصيل",
    "Connecting…": "جارٍ الاتصال…",
    "Connect": "اتصال",
    "In wp-admin, open Users → Profile.": "في wp-admin، افتح Users ← Profile.",
    "Under Application Passwords, type the name “Hallak iPhone” and press Add.":
        "تحت Application Passwords، اكتب الاسم «Hallak iPhone» واضغط Add.",
    "Copy the password that appears (spaces are fine) and paste it in the app.":
        "انسخ كلمة المرور التي تظهر (المسافات لا مشكلة) والصقها في التطبيق.",
    "Your normal wp-admin password does not work here. If you lose the phone, revoke this Application Password in the same place: the app stops working at once.":
        "كلمة مرور wp-admin العادية لا تعمل هنا. إذا أضعت الهاتف، ألغِ كلمة مرور التطبيق من نفس المكان: يتوقف التطبيق فورًا.",
    "Connected": "تم الاتصال",
    "Site": "الموقع",
    "WordPress": "WordPress",
    "Hallak core": "نواة حلّاق",
    "API": "API",
    "Lock the app with %@? It asks again after 5 minutes in the background.":
        "قفل التطبيق بـ %@؟ يطلبه مجددًا بعد ٥ دقائق في الخلفية.",
    "Use %@": "استخدم %@",
    "Not now": "ليس الآن",
    # Tabs
    "Home": "الرئيسية",
    "Salons": "الصالونات",
    "Money": "المال",
    "Requests": "الطلبات",
    "More": "المزيد",
    # Home
    "%lld active · %lld suspended": "%lld شغّال · %lld موقوف",
    "Demo requests": "طلبات التجربة",
    "new request": "طلب جديد",
    "new requests": "طلبات جديدة",
    "Billing": "الاشتراكات",
    "Trial": "تجربة",
    "Paid": "مدفوع",
    "Payment due": "الدفع مستحق",
    "Overdue": "متأخر",
    "Money this month": "مال هذا الشهر",
    "Expected every month (MRR)": "المتوقع كل شهر (MRR)",
    "Paid this month": "مدفوع هذا الشهر",
    "Unpaid: %lld": "غير مدفوع: %lld",
    "WhatsApp bot": "بوت واتساب",
    "replies this month": "ردود هذا الشهر",
    "Cost": "الكلفة",
    "%lld chats wait for a salon team": "%lld محادثات تنتظر فريق الصالون",
    "AI assistant": "المساعد الذكي",
    "questions this month": "أسئلة هذا الشهر",
    "Health": "الصحة",
    "All plugins OK": "كل الإضافات سليمة",
    "%lld errors · %lld warnings": "%lld أخطاء · %lld تنبيهات",
    "Activity today": "النشاط اليوم",
    "changes in all salons": "تغييرات في كل الصالونات",
    # More
    "Coming next": "قريبًا",
    "Activity": "النشاط",
    "Owners": "المالكون",
    "User": "المستخدم",
    "App": "التطبيق",
    "Lock with %@": "القفل بـ %@",
    "Asks again after 5 minutes in the background.": "يطلبه مجددًا بعد ٥ دقائق في الخلفية.",
    "Log out": "تسجيل الخروج",
    "Lost phone? In wp-admin → Users → Profile → Application Passwords, revoke “Hallak iPhone”. The app stops working at once.":
        "أضعت الهاتف؟ في wp-admin ← Users ← Profile ← Application Passwords ألغِ «Hallak iPhone». يتوقف التطبيق فورًا.",
    "Log out of Hallak Admin?": "تسجيل الخروج من حلّاق؟",
    "The login and the saved data are removed from this iPhone.": "يُحذف تسجيل الدخول والبيانات المحفوظة من هذا الآيفون.",
}

INFOPLIST_AR = {
    "CFBundleDisplayName": "حلّاق أدمن",
    "NSFaceIDUsageDescription": "Face ID يُبقي تطبيق حلّاق مقفلًا عندما لا تستخدمه.",
}


def catalog(entries, with_en):
    strings = {}
    for key in sorted(entries):
        loc = {"ar": {"stringUnit": {"state": "translated", "value": entries[key]}}}
        if with_en:
            loc["en"] = {"stringUnit": {"state": "translated", "value": key}}
        strings[key] = {"localizations": loc}
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def main():
    (RES / "Localizable.xcstrings").write_text(
        json.dumps(catalog(AR, with_en=False), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    info = catalog(INFOPLIST_AR, with_en=False)
    info["strings"]["CFBundleDisplayName"]["localizations"]["en"] = {"stringUnit": {"state": "translated", "value": "Hallak Admin"}}
    info["strings"]["NSFaceIDUsageDescription"]["localizations"]["en"] = {"stringUnit": {"state": "translated", "value": "Face ID keeps the Hallak admin app locked when you are not using it."}}
    (RES / "InfoPlist.xcstrings").write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{len(AR)} app strings, {len(INFOPLIST_AR)} Info.plist strings")


if __name__ == "__main__":
    main()
