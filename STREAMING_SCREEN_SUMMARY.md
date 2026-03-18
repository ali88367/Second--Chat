# Streaming screen summary

This document describes how the **Streaming screen** works in this project (stream playback + realtime chat), and which files own which responsibilities.

## Key files

- **Screen**: `lib/features/live_stream/live_stream_screen.dart`
- **Chat UI**: `lib/features/live_stream/widgets/chat_bottom_section.dart`
- **Stream renderer**: `lib/features/live_stream/widgets/stream_webview.dart`
- **Controller**: `lib/controllers/chat_controller.dart`
- **Overview API**: `lib/data/services/streaming_service.dart`
- **Chat APIs**: `lib/data/services/chat_service.dart`
- **Socket.IO realtime**: `lib/core/socket/chat_socket_service.dart`
- **Settings used by streaming**: `lib/controllers/Main Section Controllers/settings_controller.dart`

## High-level flow

1. App starts and registers `ChatController` globally in `lib/main.dart`.
2. `ChatController` loads the platform access token from SharedPreferences key `second_chat.platform_tokens` (currently uses the `twitch` entry by default).
3. It loads initial chat history via `GET /api/v1/chat/history`.
4. It loads stream + socket metadata via `GET /api/v1/streaming/overview`.
5. If `chatSocketUrl` + `chatSocketPath` exist, it connects Socket.IO and emits `chat:start`.
6. Streaming UI reads reactive state from `ChatController` and renders:
   - a WebView stream tile (or multi-tile layout), and
   - chat list filtered by platform/live status.

## `/api/v1/streaming/overview` parsing

Owned by `lib/data/services/streaming_service.dart`.

Expected response shape (current backend):

- Top-level: `data.chatSocketUrl`, `data.chatSocketPath`
- Platforms array: `data.platforms[]` with fields like:
  - `platform` (twitch/kick/youtube)
  - `live` (bool)
  - `viewerCount`
  - `player.embedUrl`, `player.watchUrl`

**Playback URL choice**:

- Prefer `player.embedUrl` for WebView playback.
- Fall back to `player.watchUrl` if `embedUrl` is missing.

The service builds multi-platform maps:

- `viewerCountsByPlatform`: `{ platform -> int }`
- `liveByPlatform`: `{ platform -> bool }`
- `embedUrlByPlatform`: `{ platform -> String? }` (embed/watch URL as above)

## Platform switching (viewer chips / swipe)

Owned by `lib/features/live_stream/live_stream_screen.dart`.

When a user selects a platform (tap a chip) or swipes platforms:

- The screen updates `_chatFilter`
- It calls `Get.find<ChatController>().refreshOverviewForPlatform(selected)`

This triggers a fresh `/streaming/overview` fetch and updates:

- selected stream URL (WebView)
- per-platform live flags
- per-platform viewer counts

## Multi-platform preview (segmented layout)

Owned by `lib/features/live_stream/live_stream_screen.dart`.

The “multi platform preview” flag is:

- `SettingsController.multiScreenPreview`

When `multiScreenPreview == true`, the stream container renders a **segmented 3-tile layout** (always shows all platforms):

- Column
  - Top row: 2 tiles (Twitch + Kick)
    - left tile: only `topLeft` rounded
    - right tile: only `topRight` rounded
  - Gap
  - Bottom tile: 1 tile (YouTube)
    - only bottom corners rounded

All tiles have spacing between them to create a “segmented rounded box” look.

**Live/offline tile behavior**:

- If the platform is live: WebView is loaded with its embed URL.
- If the platform is offline: the tile receives `url: ''` and shows the “No stream at the moment” placeholder.

When `multiScreenPreview == false`, the stream container shows only the selected platform stream.

## Stream WebView behavior (offline placeholder + navigation lock)

Owned by `lib/features/live_stream/widgets/stream_webview.dart`.

- If `url` is empty: it shows an in-container placeholder: “No stream at the moment”.
- If `url` is set: it loads the URL into a `WebViewWidget`.

**Navigation lock (don’t leave the embedded player)**:

The WebView uses a `NavigationDelegate` that prevents navigation away from:

- the initial embed URL, and
- `player.twitch.tv` navigations

All other navigations are blocked.

## Chat visibility rules (offline behavior)

Owned by `lib/features/live_stream/widgets/chat_bottom_section.dart`.

Chat list source is `ChatController.messages` (socket-driven), then filtered:

- If **no platform is live**, the chat list is hidden (empty list).
- If a **specific platform is selected** and that platform is **offline**, chat is hidden for that platform.
- When “All” is selected and live-status is known, chat shows messages only for platforms that are currently live.

## Realtime events (Socket.IO)

Owned by `lib/core/socket/chat_socket_service.dart`.

Connection:

- Uses Socket.IO with:
  - transports: `websocket`
  - path: provided by backend (typically `/socket.io`)
  - auth: `{ token: accessToken }`
- On connect emits `chat:start`
- On disconnect emits `chat:stop`

Events supported (backend spec):

- `connected`
- `settings:update`
- `activity:sync`
- `activity:event`
- `chat:message`
- `viewer_count:update`
- `stream:status`
- `stream:info:update`
- `led:notification`
- `stream:settings:applied`
- `error` + socket `onError`

These are exposed as GetX `Rx` fields on `ChatSocketService` so controllers/screens can consume them without changing UI layout.

## Keeping live/viewer state in sync

Owned by `lib/controllers/chat_controller.dart`.

`ChatController`:

- populates `platformLive`, `platformViewerCounts`, `platformEmbedUrls` from `/streaming/overview`
- then keeps them updated from realtime socket:
  - `viewerCountsByPlatform`
  - `liveByPlatform`

This lets UI immediately react (hide chat / show offline placeholder) when a stream ends, without waiting for a manual API refresh.

