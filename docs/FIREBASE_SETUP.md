# DHAV — Firebase + Backend Wiring Setup

Manual steps you need to do **once** before the wired Phase 3 store app will run end-to-end.

---

## 1. Firebase console — store_app

You already have a Firebase project from Phase 1. Add an Android app to it:

1. Firebase Console → your DHAV project → **⚙ Project settings**
2. **Your apps → Add app → Android**
3. **Android package name:** `com.dhav.store_app`
   (must match `applicationId` in `store_app/android/app/build.gradle.kts`)
4. **App nickname:** "DHAV Store"
5. **Debug signing certificate SHA-1** — run this and paste the output:
   ```powershell
   cd $env:USERPROFILE\.android
   keytool -list -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android | Select-String SHA1
   ```
   (Required for Google Sign-In on Android.)
6. **Download `google-services.json`** → place at:
   ```
   store_app/android/app/google-services.json
   ```
7. Already enabled in Phase 1, just verify:
   - Authentication → Sign-in method → **Google** is enabled
   - Authentication → Sign-in method → **Email/Password** is enabled (for admin-created store-owner accounts)
   - Realtime Database is enabled (Mumbai region)
   - Cloud Messaging is enabled

---

## 2. Backend service account

The backend needs `firebase-service-account.json` to verify Firebase ID tokens
and send FCM messages:

1. Firebase Console → ⚙ Project settings → **Service accounts** tab
2. **Generate new private key** → confirm → it downloads a JSON file
3. Rename it to `firebase-service-account.json` and place at:
   ```
   backend/firebase-service-account.json
   ```
4. Confirm `backend/.gitignore` already excludes it (it does — added in Phase 0).

---

## 3. Onboarding a store

There are now two ways to create a store:

### 3a. Self-onboarding (new — default flow)

A first-time user signs in to the store app and is routed automatically to the
**Register Your Store** screen. They fill the form, pin their location on the
map, and submit. Backend creates the store with `is_verified=false` and flips
their role to `store_owner`. They can set up inventory immediately, but the
backend will **block toggling the store open** until an admin verifies it.

Endpoint behind the scenes:
```
POST http://localhost:8000/stores/register
Authorization: Bearer <user_id_token>
Body (JSON):
{
  "owner_name": "Raj Patel",
  "shop_name": "Raj Kirana Store",
  "phone": "+919876543210",
  "address": "Shop 4, Laxmi Complex, Kothrud",
  "lat": 18.5074,
  "lng": 73.8077,
  "operating_hours": {"open": "08:00", "close": "22:00"}
}
```

Then an admin marks the store verified via the admin panel (or `PATCH /admin/stores/{id}/verify`).

### 3b. Admin-created (legacy)

An admin can still create a store directly via `POST /stores` (admin-only,
takes `owner_uid` in the body). Useful for bulk onboarding from a spreadsheet.

To make yourself admin (one time, via Firebase Console → Realtime DB):
- Find or create the node `users/{your_uid}`
- Set `role: "admin"`, `is_active: true`

---

## 3.5. Google Maps API key (for store registration screen)

The registration screen uses Google Maps to let owners pin their location.
You need a Maps API key:

1. Google Cloud Console → **APIs & Services → Library** → enable **Maps SDK for Android**
2. **Credentials → Create credentials → API key**
3. Restrict the key (recommended): Application restrictions → Android apps →
   add package `com.dhav.store_app` with your debug SHA-1 from step 1
4. Paste the key into `store_app/android/app/src/main/AndroidManifest.xml`,
   replacing `YOUR_GOOGLE_MAPS_API_KEY_HERE` in the `com.google.android.geo.API_KEY`
   meta-data tag.

---

## 4. Sounds asset

The FCM service plays `assets/sounds/order_alert.mp3` on incoming orders. Until you
add a real sound file, the player will silently fail (alert still surfaces via the
local notification). To add one:

1. Create folder `store_app/assets/sounds/`
2. Drop in any short MP3 named `order_alert.mp3` (≤2s, loud).
3. Asset path is already declared in `pubspec.yaml`.

---

## 5. Running the store app

```powershell
cd store_app
flutter pub get
flutter run
```

Default API base URL is `http://10.0.2.2:8000` (Android emulator → host machine).
Override for a physical device or deployed backend:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.42:8000 --dart-define=WS_BASE_URL=ws://192.168.1.42:8000
```

---

## 6. Postman: smoke test the new wiring

After completing steps 1–3, hit each of these to confirm:

| Endpoint | Method | Auth role | What to expect |
|---|---|---|---|
| `/auth/verify-token` | POST | any signed-in | returns `{uid, role, email, display_name, is_active}` |
| `/stores/me` | GET | store_owner | returns the store doc |
| `/stores/me/toggle` | PATCH | store_owner | body `{"is_open": true}` flips status & re-indexes geofence |
| `/stores/me/orders` | GET | store_owner | returns `{orders: [...]}` (filter by `?status=accepted`) |
| `/stores/me/delivery-boys` | GET | store_owner | list of delivery boys for this store |
| `/stores/me/delivery-boys` | POST | store_owner | body `{name, phone, google_account_email}` creates one |
| `/stores/me/inventory` | PATCH | store_owner | body `{"available_item_ids": [...]}` |
| `/settlements/store/current` | GET | store_owner | current week's settlement (or null) |
| `/orders/delivery/me` | GET | delivery | a delivery boy's assigned orders |
| `/catalog/categories` | GET | public | list of catalog categories |
| `/catalog/items` | GET | public | full catalog (used by inventory screen) |

---

## 7. FCM end-to-end test

Once the store owner signs into the app:

1. The app calls `PATCH /stores/me/fcm-token` automatically (in `SplashScreen` and
   on `onTokenRefresh`).
2. To simulate an incoming order without going through a customer app, send a
   data-only FCM message to that token (Postman with FCM HTTP v1, or the Firebase
   Console → Cloud Messaging → "Send test message"):
   ```json
   {
     "message": {
       "token": "<the FCM token from /stores/me/fcm-token>",
       "android": {"priority": "HIGH"},
       "data": {
         "type": "new_order",
         "order_id": "<a real order_id in broadcasting state>",
         "item_count": "3",
         "distance_km": "0.8",
         "earning": "42.50"
       },
       "notification": {
         "title": "New Order!",
         "body": "3 items · 0.8 km"
       }
     }
   }
   ```
3. The app should:
   - Play the alert sound
   - Vibrate (pattern: 500/200/500/200/500ms)
   - Show a HIGH-priority full-screen notification
   - Auto-push the `IncomingOrderScreen` with the order's real data
   - Start the 45s auto-reject countdown

---

## 8. Known gaps to revisit

- **`google-services.json` not committed** — that's correct (it's per-developer).
- **Sound asset placeholder** — see step 4.
- **Active store-open switch** does not auto-sync the FCM token; we only sync on
  login + token refresh. That's fine.
- **Background-handler in `fcm_service.dart`** does no work other than letting
  the OS show the system notification. When the user taps the notification,
  `getInitialMessage()` will fire `onIncomingOrder` and push the screen.
- **Delivery boy availability toggle** is currently local-only — no backend
  endpoint exists for `delivery_boys/{id}/availability` yet. Add when you wire
  this from the admin side.
- **Maps** — `Open in Google Maps` deep-link works via `url_launcher`. We have
  not embedded an in-app `google_maps_flutter` view in the delivery screen — the
  external launch is sufficient for MVP.

---

## 9. Troubleshooting

- **"Sign in with Google" returns immediately** → SHA-1 not registered in Firebase Console.
- **`PlatformException(sign_in_failed, ...)`** → `google-services.json` missing or `applicationId` mismatch.
- **Backend 401** → ID token expired (lasts 1 hour) — sign out / back in, or just relaunch the app (it forces a new token).
- **`ApiException(404): User profile not found`** → call `POST /auth/verify-token` first (the app does this automatically on login).
- **`flutter run` fails on Gradle** → ensure `compileSdk` ≥ 34. The `flutter` block uses `flutter.compileSdkVersion`, which should be fine on Flutter 3.13+.
