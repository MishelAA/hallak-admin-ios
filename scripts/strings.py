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
    # Salons list
    "All": "الكل",
    "Active": "شغّال",
    "Suspended": "موقوف",
    "Not billed": "بدون اشتراك",
    "Newest": "الأحدث",
    "Name": "الاسم",
    "Paid until": "مدفوع حتى",
    "Last activity": "آخر نشاط",
    "No salons yet": "لا يوجد صالونات بعد",
    "No salon matches": "لا يوجد صالون مطابق",
    "Try another search or filter.": "جرّب بحثًا أو فلترًا آخر.",
    "%lld salons": "%lld صالون",
    "Name, phone or owner": "الاسم، الهاتف أو المالك",
    "Sort": "الترتيب",
    "%lld late payments": "%lld دفعات متأخرة",
    # Salon details
    "Notes": "ملاحظات",
    "Call": "اتصال",
    "WhatsApp": "واتساب",
    "Email": "البريد",
    "Phone": "الهاتف",
    "Language": "اللغة",
    "Currency": "العملة",
    "Created": "تاريخ الإنشاء",
    "Owner": "المالك",
    "Last login": "آخر دخول",
    "Never": "أبدًا",
    "Subscription": "الاشتراك",
    "Status": "الحالة",
    "Plan": "الباقة",
    "Cycle": "الدورة",
    "Price": "السعر",
    "Per month": "بالشهر",
    "Days left": "الأيام الباقية",
    "Payment due until": "الدفع مستحق حتى",
    "Yes": "نعم",
    "Open invoice": "فاتورة غير مدفوعة",
    "This month": "هذا الشهر",
    "Visits": "الزيارات",
    "Revenue": "المدخول",
    "Customers": "الزبائن",
    "Features": "الميزات",
    "Read only in this version.": "للقراءة فقط في هذه النسخة.",
    "Feature": "الميزة",
    "Bot": "البوت",
    "Number linked": "الرقم مربوط",
    "Replies this month": "ردود هذا الشهر",
    "Chats waiting for the team": "محادثات تنتظر الفريق",
    "Cost this month": "كلفة هذا الشهر",
    "Questions this month": "أسئلة هذا الشهر",
    "Last invoices": "آخر الفواتير",
    "All %lld logins": "كل الحسابات (%lld)",
    "Team logins": "حسابات الفريق",
    "Links": "الروابط",
    "Dashboard": "لوحة التحكم",
    "Salon page": "صفحة الصالون",
    "Booking page": "صفحة الحجز",
    "Arabic": "العربية",
    "English": "الإنجليزية",
    "Monthly": "شهري",
    "Yearly": "سنوي",
    "This salon has its own limit.": "لهذا الصالون حدّ خاص.",
    "No limit": "بدون حدّ",
    "Never logged in": "لم يدخل أبدًا",
    "Staff": "موظف",
    "Other": "آخر",
    "On": "شغّال",
    "Off": "مطفأ",
    # Invoices
    "Unpaid": "غير مدفوعة",
    "Cancelled": "ملغاة",
    "months": "أشهر",
    "Salon": "الصالون",
    "Period": "الفترة",
    "Months": "الأشهر",
    "Method": "طريقة الدفع",
    "Paid at": "تاريخ الدفع",
    "Note": "ملاحظة",
    "Invoice": "الفاتورة",
    "Share": "مشاركة",
    # Activity
    "No activity yet": "لا يوجد نشاط بعد",
    "Search the activity": "ابحث في النشاط",
    # Money
    "Billing is off": "الاشتراكات مطفأة",
    "The Hallak Billing plugin is not active on the site.": "إضافة Hallak Billing غير مفعّلة على الموقع.",
    "Invoices": "الفواتير",
    "Plans": "الباقات",
    "%lld invoices": "%lld فاتورة",
    "Due soon / late": "مستحق قريبًا / متأخر",
    "Salons keep working %lld days after the date.": "تبقى الصالونات تعمل %lld أيام بعد التاريخ.",
    "Show": "عرض",
    "Nothing unpaid": "لا شيء غير مدفوع",
    "No invoices": "لا يوجد فواتير",
    "Not active": "غير مفعّل",
    # Requests
    "New": "جديد",
    "No new requests": "لا يوجد طلبات جديدة",
    "No requests": "لا يوجد طلبات",
    "New “Book a free demo” requests from the website show here.": "طلبات «احجز تجربة مجانية» من الموقع تظهر هنا.",
    "%lld requests": "%lld طلب",
    "Name, salon, phone or email": "الاسم، الصالون، الهاتف أو البريد",
    "Plan wanted": "الباقة المطلوبة",
    "Number of barbers": "عدد الحلاقين",
    "Sent": "أُرسل",
    "Message": "الرسالة",
    "Changing the status and “Create salon from request” come with the next API version.":
        "تغيير الحالة و«إنشاء صالون من الطلب» يأتيان مع نسخة الـ API القادمة.",
    "Demo request": "طلب تجربة",
    # Settings
    "Settings": "الإعدادات",
    "Same as iPhone": "مثل الآيفون",
    "Some texts change after you close and open the app again.": "بعض النصوص تتغير بعد إغلاق التطبيق وفتحه من جديد.",
    # Health
    "The Hallak check plugin is not active": "إضافة Hallak check غير مفعّلة",
    "Problems": "المشاكل",
    "No problems": "لا يوجد مشاكل",
    "Up to date": "محدّث",
    "Update": "تحديث متوفر",
    "Plugins": "الإضافات",
    "Hallak check %@": "Hallak check %@",
    "Environment": "البيئة",
    "Error": "خطأ",
    "Warning": "تنبيه",
    "Info": "معلومة",
    # Owners
    "No owners": "لا يوجد مالكون",
    "No salon": "لا يوجد صالون",
    "Name, login or email": "الاسم، اسم الدخول أو البريد",
    # WhatsApp bot / AI
    "Month": "الشهر",
    "Model": "النموذج",
    "Monthly limit per salon": "الحدّ الشهري لكل صالون",
    "Key set": "المفتاح موجود",
    "Price in / out": "السعر دخول / خروج",
    "Last error": "آخر خطأ",
    "When": "متى",
    "Replies": "الردود",
    "Bot on": "البوت شغّال",
    "Bot off": "البوت مطفأ",
    "Number not linked": "الرقم غير مربوط",
    "%lld chats waiting": "%lld محادثات تنتظر",
    "Limit per salon": "الحدّ لكل صالون",
    "Limit counted": "يُحسب الحدّ",
    "Every week": "كل أسبوع",
    "Every month": "كل شهر",
    "Questions": "الأسئلة",
    "%lld summaries": "%lld ملخصات",
    "This plugin is off": "هذه الإضافة مطفأة",
    "Turn it on in wp-admin to see it here.": "فعّلها في wp-admin لتظهر هنا.",
    # Activity filters
    "All types": "كل الأنواع",
    "Appointments": "المواعيد",
    "Any time": "أي وقت",
    "Last 7 days": "آخر ٧ أيام",
    "Try another filter.": "جرّب فلترًا آخر.",
    "Type": "النوع",
    "Filter": "فلتر",
    # In-app web page
    "The page did not open.": "لم تُفتح الصفحة.",
    "Back": "رجوع",
    "Forward": "تقدّم",
    "Reload": "إعادة تحميل",
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
