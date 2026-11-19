=== Salon Manager – App Login ===
Version: 1.0.0

Lets the Hallak Admin iPhone app open any salon dashboard signed in as you.

Install: wp-admin → Plugins → Add New → Upload Plugin → salon-manager-app-login-1.0.0.zip → Activate.
Nothing to set up. Needs Salon Manager Core and the Hallak admin API (Application Password login).

How it works:
1. In the app, Salon → Dashboard asks POST /wp-json/hallak/v1/admin/salons/{id}/web-login.
2. The site answers with a one-time link (works once, for 60 seconds; only a hash is stored).
3. The in-app page opens the link: you are signed in with a normal WordPress login and sent to that salon's dashboard.

Safety: administrators only, HTTPS only, only with an Application Password (never from a browser),
and every opening is written to the salon's activity log ("Dashboard opened from the iPhone app").
Revoking the "Hallak iPhone" Application Password stops it at once.
