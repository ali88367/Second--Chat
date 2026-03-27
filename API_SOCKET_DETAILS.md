# Second Chat Backend - REST API + WebSocket Reference

Last updated: 2026-03-27

This file documents every REST API and Socket.IO event exposed by this backend:
- Purpose
- Header requirements
- JSON request/response structures
- WebSocket event behavior ("event changing") and payloads
- Common exceptions (status codes / error formats)

---

## 1) Base URLs, Versioning, Content Types

### REST base path
- Base API prefix: `/api/<API_VERSION>`
- Default version: `v1` (env: `API_VERSION`, default `v1`)

Examples:
- `https://<host>/api/v1/...`
- `http://localhost:3000/api/v1/...`

### Content-Type
- Normal REST with a body: `Content-Type: application/json`
- Twitch webhook: raw JSON body (special route mounted before JSON parser)

### Rate limiting
- All `/api/*` routes: `100 requests / 15 minutes / IP`
- If exceeded: HTTP `429` with plain-text message:
  - `Too many requests from this IP, please try again later.`

---

## 2) Authentication & Headers

### JWT authentication (most endpoints)
Most endpoints require:
- `Authorization: Bearer <accessToken>`

If missing/invalid/revoked, server responds with `401`.

### Refresh tokens
Refresh token is sent in JSON body to `/auth/refresh` (not as an HTTP header).

### Admin authorization
Admin routes require:
- `Authorization: Bearer <accessToken>` and `user.role === "admin"`

If role is not allowed, this backend responds with `401` and an error message.

### WebSocket authentication (Socket.IO)
Socket.IO auth accepts either:
- `socket.handshake.auth.token = "<accessToken>"`, OR
- Header: `Authorization: Bearer <accessToken>`

If missing/invalid: the connection fails (client typically sees `connect_error`).

---

## 3) Common JSON Response Formats

### Success (common pattern)
Most endpoints return:
```json
{ "success": true, "data": {} }
```

Some success responses include a message:
```json
{ "success": true, "message": "..." }
```

### Error (global error handler)
Most errors return:
```json
{ "success": false, "error": "Human readable message" }
```

In development mode only, response may include `stack`.

### Common HTTP status codes
- `200` OK
- `201` Created (e.g., register, streak create)
- `204` No Content (e.g., Twitch webhook notification)
- `400` Validation errors (bad inputs)
- `401` Unauthorized (missing/invalid token; also used for insufficient permissions)
- `403` Forbidden (webhook auth/signature failures; some testing endpoints)
- `404` Not found (routes/resources; also "Platform disabled" in some auth routes)
- `409` Conflict (streak already exists)
- `429` Too many requests (rate limit)
- `501` Not implemented (TikTok stream metadata update / categories list)
- `500` Server errors (usually returned as standard error JSON)

---

## 4) REST APIs (All Endpoints)

Notation:
- Full path is shown with the version prefix: `/api/v1/...`
- "Auth required" means `Authorization: Bearer <accessToken>` is required.

### 4.1 Health + Public Pages (no auth)

#### GET `/health`
Purpose: health check.
Response:
```json
{
  "status": "ok",
  "timestamp": "ISO-8601",
  "uptime": 123.45
}
```

#### GET `/`, `/privacy`, `/terms` (HTML)
Purpose: basic informational pages and OAuth verification hosting.
Response: HTML (not JSON).

#### GET `/auth/callback` (HTML)
Purpose: browser test callback page that displays query params (`token`, `refreshToken`, `linked`, `success`, `error`).
Response: HTML.

---

### 4.2 Auth (`/api/v1/auth`)

#### POST `/auth/register`
Purpose: create account with email/password and return JWT tokens.
Headers: `Content-Type: application/json`
Body:
```json
{ "email": "user@example.com", "password": "Min 8 chars, A-z + a-z + number" }
```
Success (201):
```json
{
  "success": true,
  "data": {
    "user": { "id": "uuid", "email": "string", "username": "string", "role": "string", "is_premium": false },
    "accessToken": "jwt",
    "refreshToken": "jwt"
  }
}
```
Exceptions:
- `400` invalid email/password format
- `400` email already registered

#### POST `/auth/login`
Purpose: login and return JWT tokens.
Body:
```json
{ "email": "user@example.com", "password": "string" }
```
Success (200): same structure as register.
Exceptions:
- `401` invalid credentials

#### POST `/auth/refresh`
Purpose: exchange refresh token for a new access token.
Body:
```json
{ "refreshToken": "jwt" }
```
Success (200):
```json
{ "success": true, "data": { "accessToken": "jwt" } }
```
Exceptions:
- `401` invalid refresh token (missing in Redis / mismatch)

#### POST `/auth/logout` (auth required)
Purpose: revoke refresh token + blacklist the current access token until it expires.
Success (200):
```json
{ "success": true, "message": "Logged out successfully" }
```
Exceptions:
- `401` missing/invalid token

#### POST `/auth/password/reset`
Purpose: request password reset email (does not reveal whether email exists).
Body:
```json
{ "email": "user@example.com" }
```
Success (200):
```json
{ "success": true, "message": "If the email exists, a password reset link has been sent" }
```

#### POST `/auth/password/reset/confirm`
Purpose: confirm password reset using reset token.
Body:
```json
{ "token": "uuid", "newPassword": "Min 8 chars, A-z + a-z + number" }
```
Success (200):
```json
{ "success": true, "message": "Password reset successfully" }
```
Exceptions:
- `400` invalid/expired reset token

#### GET `/auth/verify-email?token=<uuid>`
Purpose: verify email using a verification token.
Success (200):
```json
{ "success": true, "message": "Email verified successfully" }
```
Exceptions:
- `400` invalid verification token

---

### 4.2.1 OAuth URL Helpers (Twitch/YouTube/Kick/TikTok/Google)

These endpoints return an OAuth authorization URL that your app should open in a WebView/browser.

Important note about the response format:
- These endpoints return `{ "url": "..." }` (no `success` wrapper).

#### GET `/auth/twitch/url`
Purpose: generate Twitch OAuth URL for login/link flows.
Query:
- Optional: `redirectUri` (used by backend to decide where to deep-link after callback)
Response:
```json
{ "url": "https://id.twitch.tv/oauth2/authorize?..." }
```

Same pattern for:
- GET `/auth/youtube/url`
- GET `/auth/kick/url`
- GET `/auth/tiktok/url`
- GET `/auth/google/url`

Exceptions:
- If a platform is disabled (via `ENABLED_PLATFORMS`): `404 { "success": false, "error": "Platform disabled" }`

---

### 4.2.2 OAuth Callbacks (redirect endpoints used by providers)

These are called by Twitch/Google/Kick/TikTok after the user authorizes. They usually return an HTTP redirect (302)
to your app deep-link URL (example: `secondchat://auth/callback?...`).

#### GET `/auth/twitch/callback`
#### GET `/auth/youtube/callback`
#### GET `/auth/kick/callback`
#### GET `/auth/tiktok/callback`
#### GET `/auth/google/callback`
Purpose: finish provider OAuth, store tokens/connection, then redirect.

Redirect query parameters (common):
- `token`: backend access token (JWT) for this app
- `refreshToken`: backend refresh token (JWT)
- Sometimes also: `linked=<platform>` and `success=true`

Exceptions:
- `400` missing OAuth `code` (Google explicitly returns this)

---

### 4.2.3 Link OAuth Accounts (auth required)

Purpose: same as `/auth/<platform>/url`, but intended for linking after login.

#### GET `/auth/twitch/link` (auth required)
#### GET `/auth/youtube/link` (auth required)
#### GET `/auth/kick/link` (auth required)
#### GET `/auth/tiktok/link` (auth required)
#### GET `/auth/google/link` (auth required)
Response:
```json
{ "url": "https://provider/.../authorize?..." }
```

---

### 4.2.4 Google Token Login (no OAuth redirect required)

#### POST `/auth/google/token`
#### POST `/auth/google/mobile` (alias)
Purpose: social login/signup using a Google ID token from the client.
Body (supported fields):
```json
{
  "idToken": "google_id_token",
  "accessToken": "optional_google_access_token",
  "refreshToken": "optional_google_refresh_token"
}
```
Also accepted for `idToken`: `token` or `credential`.

Success (200):
```json
{
  "success": true,
  "data": {
    "user": { "id": "uuid", "email": "string", "username": "string", "role": "string", "is_premium": false },
    "accessToken": "jwt",
    "refreshToken": "jwt"
  },
  "message": "Authentication successful"
}
```
Exceptions:
- `400` missing token fields
- `400` invalid Google token / audience mismatch / issuer invalid / expired

---

### 4.2.5 OAuth Redirect URI Helper

#### GET `/auth/oauth/redirect-uris`
Purpose: return backend-configured redirect URIs and route paths (useful for mobile clients).
Success (200):
```json
{
  "success": true,
  "redirectUris": { "twitch": "string", "youtube": "string", "kick": "string", "tiktok": "string", "google": "string" },
  "routes": { "twitch": { "callback": "string", "authUrl": "string", "link": "string" }, "google": { "...": "..." } }
}
```

---

### 4.3 Users (`/api/v1/users`) (auth required)

#### GET `/users/me`
Purpose: current user profile.
Success (200):
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "email": "string",
    "username": "string",
    "role": "string",
    "is_premium": true,
    "premium_expires_at": "date|null",
    "led_notifications_enabled": true,
    "created_at": "date"
  }
}
```
Exceptions:
- `404` user not found

#### PATCH `/users/me`
Purpose: update user fields.
Body (any subset):
```json
{ "username": "string", "led_notifications_enabled": true }
```
Success (200):
```json
{ "success": true, "data": { "updatedUserRow": "db shape" } }
```
Note: this endpoint returns the updated DB user row directly as `data` (not wrapped in an extra `user` object).

---

### 4.4 Platforms (`/api/v1/platforms`) (auth required)

#### GET `/platforms`
Purpose: list platform connection records for the user.
Success (200):
```json
{
  "success": true,
  "data": [
    { "id": "uuid", "platform": "twitch|youtube|kick|tiktok|google", "platform_username": "string|null", "is_active": true, "last_sync_at": "date|null" }
  ]
}
```

#### GET `/platforms/status`
Purpose: connection status + authUrl for each enabled platform (when not connected).
Success (200):
```json
{
  "success": true,
  "data": {
    "platforms": [
      {
        "platform": "twitch|youtube|kick|tiktok",
        "platformName": "string",
        "connected": true,
        "username": "string|null",
        "last_sync_at": "date|null",
        "authUrl": "string|null",
        "connectEndpoint": "/api/v1/auth/<platform>/link"
      }
    ],
    "message": "Platform connection status with OAuth URLs"
  }
}
```

#### PATCH `/platforms/stream`
Purpose: bulk stream title/category update across connected platforms (twitch/youtube/kick).
Body (any one of these is required):
```json
{
  "title": "string (optional)",
  "category": "string (optional)",
  "categoryId": "string (optional)",
  "platforms": ["twitch","youtube","kick"],
  "overrides": {
    "twitch": { "title": "string", "category": "string", "categoryId": "string" },
    "youtube": { "title": "string", "category": "string", "categoryId": "string" },
    "kick": { "title": "string", "category": "string", "categoryId": "string" }
  }
}
```
Success (200):
```json
{
  "success": true,
  "data": {
    "requestedPlatforms": ["twitch","youtube","kick"],
    "updates": {
      "twitch": { "applied": true, "result": {} },
      "youtube": { "applied": false, "skipped": true, "reason": "platform not connected/active" }
    }
  }
}
```
Exceptions:
- `400` when no update fields are provided

#### GET `/platforms/diagnostics/live`
Purpose: quick live + viewer count snapshot across enabled/connected platforms.
Success (200):
```json
{
  "success": true,
  "data": {
    "platforms": [
      { "platform": "string", "connected": true, "live": true, "viewerCount": 123, "error": "optional" }
    ],
    "enabledPlatforms": ["twitch","youtube","kick","tiktok"]
  }
}
```

#### GET `/platforms/:platform/info`
Purpose: fetch stream info + viewer count for a single platform.
Path params:
- `platform`: `twitch|youtube|kick|tiktok`
Success (200):
```json
{ "success": true, "data": { "...streamInfoFields": "provider specific", "viewer_count": 123 } }
```
Exceptions:
- `400` invalid platform

#### GET `/platforms/:platform/categories`
Purpose: help the client search/list categories for stream metadata updates.
Behavior:
- Twitch: requires `query`; supports `first` (1..50, default 20)
- Kick: requires `query`; supports `limit` (1..50, default 20)
- YouTube: supports `region` (default `US`)
- TikTok: not supported (501)

Success example:
```json
{ "success": true, "data": { "items": [ { "id": "string", "name": "string" } ] } }
```
YouTube response includes region:
```json
{ "success": true, "data": { "region": "US", "items": [ { "id": "string", "title": "string" } ] } }
```
Exceptions:
- `400` invalid platform
- `501` TikTok categories not supported

#### PATCH `/platforms/:platform/stream`
Purpose: update stream title/category for exactly one platform (twitch/youtube/kick).
Body (at least one field required):
```json
{ "title": "string (optional)", "category": "string (optional)", "categoryId": "string (optional)" }
```
Success (200):
```json
{ "success": true, "data": { "providerResponse": "varies" } }
```
Exceptions:
- `400` no fields provided / invalid platform
- `501` TikTok stream metadata updates not supported

#### PATCH `/platforms/:platform/toggle`
Purpose: enable/disable a connected platform connection.
Body:
```json
{ "is_active": true }
```
Success (200):
```json
{ "success": true, "message": "Platform enabled|disabled", "data": { "platform": "string", "is_active": true } }
```
Exceptions:
- `404` connection not found (not linked yet)

#### DELETE `/platforms/:platform`
Purpose: disconnect a platform (sets the connection inactive).
Success (200):
```json
{ "success": true, "message": "Platform disconnected" }
```

#### GET `/platforms/home/overview`
Purpose: offline dashboard card data (live/offline, viewer counts, actions, and preferences).
Response includes:
- `status` (`live|offline`)
- `viewerCount` (number)
- `platforms` array of `{ platform, connected, live, viewerCount }`
- `schedulePrompt`, `reactions`, `notificationsEnabled`, etc.

#### PATCH `/platforms/home/preferences`
Purpose: update offline home card preferences.
Body (any subset):
```json
{ "scheduleChangePrompt": "yes|no|null", "hearted": true }
```
Success (200):
```json
{ "success": true, "data": { "scheduleChangePrompt": "yes|no|null", "hearted": true }, "message": "Home preferences updated" }
```

---

### 4.5 Chat (`/api/v1/chat`) (auth required)

#### GET `/chat/history`
Purpose: fetch stored chat messages for the user (optionally by platform).
Query:
- `platform` (optional): `twitch|youtube|kick|tiktok`
- `limit` (optional, default 100)
- `offset` (optional, default 0; used only when platform is not provided)
Success (200):
```json
{
  "success": true,
  "data": [ { "chatMessageRow": "db shape" } ],
  "context": { "settings": { "settingsSnapshot": "object" } }
}
```

#### POST `/chat/send`
Purpose: send a message to a platform chat (twitch/youtube/kick only).
Body:
```json
{ "platform": "twitch|youtube|kick", "message": "string (1..500 chars)" }
```
Success (200):
```json
{ "success": true }
```
Exceptions:
- `400` invalid platform or empty/too-long message

---

### 4.6 Main Screen (`/api/v1/main`) (auth required)

#### GET `/main/overview`
Purpose: home/main tab data combining recent chat + activity + viewer counters + settings snapshot.
Query:
- `platform`: `all|twitch|youtube|kick|tiktok` (default `all`)
- `tab`: `activity|title` (default `activity`)
Success (200): returns a UI-shaped object including:
- `settings`, `selectedPlatform`, `selectedTab`, `counters`, `tabs`, `platformSwitch`
- `feed` (chat items), `activity` (activity items)
- `switchingHint`, `reactions`, etc.

#### PATCH `/main/preferences`
Purpose: update main screen preference values stored in user preferences.
Body (any subset):
```json
{
  "selectedPlatform": "all|twitch|youtube|kick|tiktok",
  "selectedTab": "activity|title",
  "swipeSwitchingHintSeen": true,
  "hearted": true
}
```
Success (200):
```json
{
  "success": true,
  "message": "Main screen preferences updated",
  "data": { "selectedPlatform": "string", "selectedTab": "string", "swipeSwitchingHintSeen": true, "hearted": true }
}
```
Exceptions:
- `400` invalid values / wrong types

---

### 4.7 Settings (`/api/v1/settings`) (auth required)

#### GET `/settings`
Purpose: return settings + account plan details + connected platform list.
Success (200):
```json
{
  "success": true,
  "data": {
    "account": {
      "isPremium": true,
      "yourPlan": "free|monthly|yearly|trial",
      "planType": "monthly|yearly|null",
      "isTrial": true,
      "trialEndsAt": "date|null",
      "premiumEndsAt": "date|null"
    },
    "connectPlatforms": [ { "platform": "string", "connected": true, "username": "string|null" } ],
    "settings": { "notifications": {}, "chat": {}, "appearance": {}, "language": {}, "other": {}, "stream": {} }
  }
}
```

#### PATCH `/settings`
Purpose: deep-merge settings into existing settings and broadcast changes to active sockets.
Body:
```json
{ "settings": { "...anySubsetOfSettings": "object" } }
```
Success (200):
```json
{
  "success": true,
  "message": "Settings updated successfully",
  "data": { "settings": { "mergedSettings": "object" }, "platformStreamUpdates": { "optional": "object" } }
}
```
Event changing (live effects):
- Pushes WebSocket `settings:update` to all active sockets for the user.
- If `settings.stream` is included, backend may auto-apply stream title/category updates and then emits:
  - WebSocket `stream:settings:applied`
Exceptions:
- `400` when `settings` is missing or not an object

---

### 4.8 Notifications (`/api/v1/notifications`) (auth required)

#### POST `/notifications/led/toggle`
Purpose: enable/disable LED notifications.
Body:
```json
{ "enabled": true }
```
Success (200):
```json
{ "success": true, "message": "LED notifications enabled|disabled" }
```

#### POST `/notifications/led/test`
Purpose: trigger a test LED pulse.
Body (optional fields shown with defaults):
```json
{ "platform": "twitch", "color": "#9146FF", "duration": 3 }
```
Success (200):
```json
{ "success": true, "message": "LED test triggered" }
```

---

### 4.9 Streaming (`/api/v1/streaming`) (auth required)

#### GET `/streaming/overview`
Purpose: multi-platform stream snapshot and client connection info (WebSocket URL/path).
Success (200): returns:
- `chatSocketUrl` (ws/wss)
- `chatSocketPath` (`/socket.io`)
- `settings`
- `platforms[]` (per platform: live, viewerCount, streamInfo, meta, player links)

---

### 4.10 Subscriptions (`/api/v1/subscriptions`)

Auth:
- All subscription endpoints require auth **except** `GET /subscriptions/plans`.

#### POST `/subscriptions/ios/validate` (auth required)
Purpose: validate an iOS receipt directly with Apple.
Body:
```json
{ "receiptData": "string", "isSandbox": false }
```
Success (200):
```json
{ "success": true, "data": { "status": "active", "expires_date": "date" } }
```
Exceptions:
- `400` validation failed (generic: `Failed to validate subscription`)

#### POST `/subscriptions/android/validate` (auth required)
Purpose: validate an Android purchase token with Google Play.
Body:
```json
{ "purchaseToken": "string", "productId": "string" }
```
Success (200):
```json
{ "success": true, "data": { "status": "active|expired", "expires_date": "date", "is_trial": true } }
```
Exceptions:
- `400` missing/invalid Google configuration or validation failures

#### GET `/subscriptions` (auth required)
Purpose: list subscription records for the user.
Success (200):
```json
{ "success": true, "data": [ { "subscriptionRow": "db shape" } ] }
```

#### GET `/subscriptions/payments` (auth required)
Purpose: payment history (RevenueCat webhook events stored in DB).
Query:
- `limit` (max 200, default 100)
- `offset` (default 0)
Success (200):
```json
{ "success": true, "data": [ { "revenueCatEventRow": "db shape" } ] }
```

#### POST `/subscriptions/:id/cancel` (auth required)
Purpose: cancel a subscription record (sets status cancelled).
Success (200):
```json
{ "success": true, "message": "Subscription cancelled" }
```
Exceptions:
- `400` subscription not found or not owned by user

#### GET `/subscriptions/plans` (no auth)
Purpose: pricing plans + referral summary.
Success (200): returns an object with:
- `freeTrialDays`
- `plans[]` (monthly/yearly)
- `referral` summary

#### POST `/subscriptions/trial/start` (auth required)
Purpose: create a 14-day free trial subscription record.
Body:
```json
{ "planType": "monthly|yearly" }
```
Success (200): returns `data` including:
- `status`, `is_trial`, `expires_date`
- `referral` (code + inviteLink)
- `subscription` (db row)
Exceptions:
- `400` invalid planType / trial already used / premium already active

#### POST `/subscriptions/trial/testing/cancel` (auth required)
Purpose: cancel an active free trial immediately (testing/ops).
Headers:
- Optional `x-testing-key: <value>` (required if `SUBSCRIPTION_TESTING_CANCEL_KEY` is set)
Body (optional):
```json
{ "userId": "uuid (optional; defaults to current user)" }
```
Exceptions:
- `403` disabled in production (unless explicitly allowed)
- `403` invalid testing key
- `400` invalid userId

#### POST `/subscriptions/referral/apply` (auth required)
Purpose: apply referral reward (adds 1 month premium to the referrer).
Body:
```json
{ "code": "7 chars (A-Z0-9)", "referrerId": "uuid (fallback)" }
```
Exceptions:
- `400` invalid/used code, no invites remaining, self-use, etc.

#### GET `/subscriptions/referral/invites` (auth required)
Purpose: invite screen data (invite codes and claimed state).

#### POST `/subscriptions/restore` (auth required)
Purpose: restore premium state from existing active subscriptions.
Body:
```json
{ "platform": "ios|android" }
```
Exceptions:
- `400` invalid platform

#### GET `/subscriptions/premium/overview` (auth required)
Purpose: premium paywall + trial timeline + referral + legal.
Success (200): returns a UI-shaped object including:
- `premiumBanner`, `plans`, `featureComparison`, `trial`, `referral`, `notifications`, `legal`, `accountStatus`

#### GET `/subscriptions/premium/reminders` (auth required)
Purpose: get trial reminder settings.
Success (200):
```json
{ "success": true, "data": { "enabled": true, "day10Reminder": true, "day14Reminder": true } }
```

#### PATCH `/subscriptions/premium/reminders` (auth required)
Purpose: update trial reminder settings.
Body (at least one field required):
```json
{ "enabled": true, "day10Reminder": true, "day14Reminder": true }
```
Exceptions:
- `400` wrong types or missing all fields

---

### 4.11 Streaks (Simple) (`/api/v1/streaks`) (auth required)

This "streaks" feature stores check-ins by date (`YYYY-MM-DD`) plus monthly freeze allowances.

#### GET `/streaks/overview`
Purpose: streak overview (weekly view, danger state, counts).
Success (200): returns an overview object that includes:
- `week[]` items with `label`, `date`, `completed`, `frozen`, `isToday`
- `currentStreak`, `bestStreak`, `freezesAvailable`, and "danger" indicators

#### GET `/streaks/settings`
Purpose: fetch streak settings values and options.
Success (200):
```json
{
  "success": true,
  "data": { "weeklyGoal": 3, "freezeAllowancePerMonth": 3, "options": [1,2,3,4,5,6,7], "freezeOptions": [0,1,2,3,4,5] }
}
```

#### PATCH `/streaks/settings`
Purpose: update streak settings.
Body (any subset):
```json
{ "weeklyGoal": 3, "freezeAllowancePerMonth": 3 }
```
Exceptions:
- `400` weeklyGoal out of range (1..7)
- `400` freezeAllowancePerMonth out of range (0..5)

#### POST `/streaks/check-in`
Purpose: mark a date as checked in.
Body (optional; defaults to today):
```json
{ "date": "YYYY-MM-DD" }
```
Exceptions:
- `400` invalid date format
- `400` date earlier than last check-in date

#### POST `/streaks/freeze/use`
Purpose: spend a freeze token on a date.
Body (optional; defaults to today):
```json
{ "date": "YYYY-MM-DD" }
```
Exceptions:
- `400` no freezes available / date already checked-in / already frozen

---

### 4.12 Streak (Weekly Selected Days) (`/api/v1/streak`) (auth required)

This is a separate weekly model:
- User selects allowed days (`mon..sun`)
- Completions only allowed on selected days
- Weekly target awards a streak increment
- Has "freeze tokens" for freezing a week

#### GET `/streak`
Purpose: get current streak configuration + current-week state.
Success (200): returns a payload including:
- `currentStreak`, `longestStreak`
- `selectedDays`, `targetDaysPerWeek`
- `completedThisWeek`, `remainingThisWeek`
- `freezeTokens`, `status`, `weekStartDate`

#### POST `/streak`
Purpose: initialize streak settings (one-time creation).
Body:
```json
{ "selectedDays": ["mon","wed"], "targetDaysPerWeek": 2 }
```
Exceptions:
- `400` invalid selectedDays / targetDaysPerWeek (1..7)
- `409` already initialized

#### PATCH `/streak`
Purpose: update selectedDays and/or targetDaysPerWeek.
Body (at least one field required):
```json
{ "selectedDays": ["mon","wed"], "targetDaysPerWeek": 2 }
```
Exceptions:
- `400` invalid values or missing all fields
- `404` streak not created yet

#### POST `/streak/complete`
Purpose: mark a selected day as completed (defaults to today).
Body (optional):
```json
{ "date": "YYYY-MM-DD" }
```
Exceptions:
- `400` invalid date format
- `400` completion allowed only on selectedDays
- `404` streak not created yet

#### POST `/streak/freeze`
Purpose: freeze the current week (spends 1 freeze token).
Exceptions:
- `400` no freeze tokens remaining / current week already frozen
- `404` streak not created yet

#### GET `/streak/history`
Purpose: weekly history list.
Success (200):
```json
{ "success": true, "data": { "weeks": [ { "weekStart": "YYYY-MM-DD", "completedDays": ["mon","wed"], "status": "success|failed|frozen|in_progress" } ] } }
```

---

### 4.13 Admin (`/api/v1/admin`) (admin only)

Headers:
- `Authorization: Bearer <accessToken>` (role must be `admin`)

#### GET `/admin/stats`
Purpose: system stats (user counts, subscriptions, platforms).

#### GET `/admin/users`
Purpose: list users.
Query: `limit` (default 50), `offset` (default 0)

#### GET `/admin/logs`
Purpose: list system logs.
Query: `level` (optional), `limit` (default 100)

#### GET `/admin/websocket/stats`
Purpose: placeholder websocket stats (currently returns `active_connections: 0`).

---

### 4.14 Webhooks (`/api/v1/webhooks`) (no app auth token)

#### POST `/webhooks/twitch`
Purpose: receive Twitch EventSub events (raw-body signature verification).
Required headers:
- `Twitch-Eventsub-Message-Id`
- `Twitch-Eventsub-Message-Timestamp`
- `Twitch-Eventsub-Message-Type`
- `Twitch-Eventsub-Message-Signature`

Body:
- Raw JSON bytes (server validates signature using raw body string)

Behaviors:
- `webhook_callback_verification`: returns `challenge` string (200, plain text)
- `notification`: processes and returns `204 No Content`
- `revocation`: logs and returns `204 No Content`

Exceptions:
- `400` missing required headers
- `403` invalid signature
- `400` invalid JSON body
- `500` failed to process notification

#### POST `/webhooks/revenuecat`
Purpose: receive RevenueCat webhook events and update subscription state.
Headers:
- `Authorization: <value>` (required if env `REVENUECAT_WEBHOOK_AUTH` is set; supports token-only or `Bearer <token>`)
Body:
- RevenueCat JSON payload (provider-defined)
Success (200):
```json
{ "success": true }
```
Exceptions:
- `403` invalid authorization (when configured)
- `400` invalid payload

---

## 5) WebSocket (Socket.IO) - Events & Payloads

### Connection
- Transport: Socket.IO (`/socket.io`) with transports `websocket` and `polling`.
- URL: same host as REST (example: `wss://<host>`).

Auth requirements:
- Provide backend `accessToken` (JWT) as:
  - handshake auth: `auth: { "token": "<accessToken>" }`, OR
  - header: `Authorization: Bearer <accessToken>`

### 5.1 Client -> Server events

#### `chat:start`
Purpose: start the chat session:
- Server sends `settings:update`
- Server sends one-time `activity:sync` (latest ~50 activity events)
- Server starts platform listeners based on current settings (selected platforms + connections)
- Server starts viewer polling (every ~15 seconds)
Payload: none

#### `chat:stop`
Purpose: stop all platform listeners + stop viewer polling.
Payload: none

#### `chat:filter`
Purpose: update server-side live filters (does not persist to DB settings).
Payload (any subset):
```json
{ "subsOnly": true, "vipOnly": true, "blockedUsers": ["username1"] }
```

### 5.2 Server -> Client events

#### `connected`
Purpose: confirms connection after auth succeeds.
Payload:
```json
{ "userId": "uuid", "timestamp": "ISO-8601" }
```

#### `settings:update`
Purpose: settings snapshot.
Payload:
```json
{ "settings": { "settingsSnapshot": "object" }, "timestamp": "ISO-8601" }
```
Event changing:
- Emitted on connect.
- Emitted on `chat:start`.
- Emitted after REST `PATCH /api/v1/settings` (to all active sockets for that user).

#### `chat:message`
Purpose: normalized live chat message.
Payload:
```json
{
  "id": "string",
  "platform": "twitch|youtube|kick|tiktok",
  "username": "string",
  "message": "string",
  "timestamp": "ISO-8601",
  "type": "normal|subscription|superchat|gifted_sub|raid",
  "priority": 0,
  "metadata": { "platformSpecific": "object" },
  "context": { "settings": { "settingsSnapshot": "object|null" } }
}
```
Event changing:
- If settings `chat.hideViewerNames === true`, server emits `username: ""`.

#### `led:notification`
Purpose: LED effect request (subscriptions/gifts and manual tests).
Payload:
- Varies; commonly includes: `platform`, `color`, `duration`, `eventType`, `messageId`.

#### `activity:sync`
Purpose: one-time batch of recent activity events (sent on `chat:start`).
Payload:
```json
{
  "events": [ { "id": "uuid", "platform": "string", "type": "string", "metadata": {}, "created_at": "date", "timestamp": "ISO-8601" } ],
  "timestamp": "ISO-8601"
}
```

#### `activity:event`
Purpose: real-time single activity event (emitted whenever a new activity event is recorded).
Payload:
```json
{ "id": "uuid", "platform": "string", "type": "string", "metadata": {}, "created_at": "date", "timestamp": "ISO-8601" }
```

#### `viewer_count:update`
Purpose: periodic viewer count updates.
Payload:
```json
{
  "platform": "twitch|youtube|kick|tiktok",
  "viewer_count": 0,
  "timestamp": "ISO-8601",
  "context": { "settings": { "settingsSnapshot": "object|null" } }
}
```
Event changing:
- Emitted every ~15 seconds while session is running.
- If settings `chat.viewerCount` is disabled, this event is not emitted.
- TikTok currently emits `viewer_count: 0` (no consistent endpoint in this integration).

#### `stream:status`
Purpose: live status transitions (initial + started/ended).
Payload:
```json
{
  "platform": "twitch|youtube|kick",
  "live": true,
  "ended": false,
  "started": true,
  "initial": false,
  "timestamp": "ISO-8601",
  "streamInfo": { "providerSpecific": "object|null" },
  "meta": { "title": "string|null", "category": "string|null" },
  "viewer_count": 0,
  "player": { "watchUrl": "string|null", "embedUrl": "string|null", "chatUrl": "string|null" },
  "context": { "settings": { "settingsSnapshot": "object|null" } }
}
```
Event changing:
- `initial: true` is sent the first time a platform is polled after the session starts.
- `started: true` when transitioning `live=false -> live=true`.
- `ended: true` when transitioning `live=true -> live=false`.

#### `stream:live`
Purpose: convenience event emitted whenever a stream is live (initial-live or transitioned to live).
Payload: similar to `stream:status` but emitted only when `live === true`.

#### `stream:info:update`
Purpose: emitted while live when title/category changes.
Payload:
```json
{
  "platform": "twitch|youtube|kick",
  "live": true,
  "meta": { "title": "string|null", "category": "string|null" },
  "viewer_count": 0,
  "player": { "watchUrl": "string|null", "embedUrl": "string|null", "chatUrl": "string|null" },
  "timestamp": "ISO-8601",
  "context": { "settings": { "settingsSnapshot": "object|null" } }
}
```

#### `stream:settings:applied`
Purpose: emitted after `PATCH /api/v1/settings` when stream auto-apply ran.
Payload:
```json
{
  "updates": { "twitch": { "applied": true }, "youtube": { "applied": false, "error": "string" } },
  "timestamp": "ISO-8601"
}
```

#### `error`
Purpose: generic runtime error event (used if `chat:start` fails).
Payload:
```json
{ "message": "string" }
```

### 5.3 WebSocket exceptions

Typical cases:
- Missing token: unauthorized ("Authentication token required")
- Invalid token: unauthorized ("Invalid authentication token")
- Session start failure: emits `error` with `{ "message": "Failed to start chat aggregation" }`

---

## 6) Quick Headers Checklist

REST (protected):
- `Authorization: Bearer <accessToken>`
- `Content-Type: application/json` (for POST/PATCH bodies)

RevenueCat webhook:
- `Authorization: <value>` (required if `REVENUECAT_WEBHOOK_AUTH` is configured)
- `Content-Type: application/json`

Twitch EventSub webhook:
- `Content-Type: application/json` (raw body)
- `Twitch-Eventsub-Message-Id`
- `Twitch-Eventsub-Message-Timestamp`
- `Twitch-Eventsub-Message-Type`
- `Twitch-Eventsub-Message-Signature`

WebSocket:
- Handshake auth token (`auth.token`) OR header `Authorization: Bearer ...`
