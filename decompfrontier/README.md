# Frontier Offline — DecompFrontier Pivot

This branch pivots FrontierOffline away from the from-scratch Godot recreation and toward the preserved/decompiled Brave Frontier Android client and offline server ecosystem.

## Upstream projects

- `decompfrontier/client` — experimental Android client decompilation. Current Android project reports Brave Frontier v2.19.6.0 in Gradle while the repository README describes the decompilation work as experimental/incomplete.
- `decompfrontier/offline-diff` — patches that enable offline mode, redirect the game server to `127.0.0.1:9960`, disable HTTPS verification for the local server path, and support offline assets.
- `decompfrontier/server` — experimental C++ emulator for the Brave Frontier v2.19.6.0 server protocol/data.

## Goal

Produce a non-commercial, single-player Android build that behaves like the original client while requiring no external service from the player.

Target UX:

1. Install one APK.
2. Launch Brave Frontier Offline.
3. Local game service starts automatically inside the app/process environment.
4. Client talks only to localhost/on-device state.
5. Saves, quests, units, summons, items, progression, battle results, and other supported systems persist locally.
6. Online-only features are disabled or replaced with deterministic/local equivalents.

## Migration strategy

### Phase A — prove the real client can build

- Clone the upstream client at a pinned commit.
- Turn `BFConfig.OFFLINE_MODE` on.
- Remove/neutralize Firebase, billing, analytics, ads, social login, and other services that are not required for offline play.
- Apply the offline native patches expected by `offline-diff`.
- Produce a signed Android test APK in GitHub Actions.

### Phase B — prove local server compatibility

- Build the DecompFrontier server unchanged on Linux first and run protocol/API smoke tests against its supplied deploy data.
- Inventory which endpoints are implemented and which are required for login, player bootstrap, quest selection, battle result submission, inventory, evolution/fusion, and gacha.
- Make a minimal offline profile that never needs a remote account.

### Phase C — make it one-install Android

Preferred route: compile the server core as an Android-native library/service and start it from the app before the client begins network bootstrap. The existing client already expects localhost in offline mode, so the external behavior remains the same while the server becomes invisible to the player.

Fallback route: port only the required server handlers/data store into an embedded Android service if the full server has dependencies that are impractical on Android.

### Phase D — single-player conversion

- Local automatic account creation.
- Local save database.
- Remove purchases/ads.
- Gem testing controls can remain in a developer menu.
- Duplicate summon behavior can be customized later.
- Arena/social/raid systems become disabled, simulated, or local PvE where practical.
- Preserve the original combat renderer, sprites, BB behavior, menu UI, sounds, animations, and content pipeline wherever available.

## Important architecture findings

The upstream Android client contains `sg.gumi.util.BFConfig` with an explicit `OFFLINE_MODE` boolean. The offline-diff project documents the native patches that redirect the game to `127.0.0.1:9960`. This means the cleanest path is not to rewrite Brave Frontier networking; it is to make the expected localhost service live inside the same Android installation.

The current upstream Android Gradle project uses application id `sg.gumi.bravefrontier`, compile SDK 29, target SDK 30, min SDK 16, NDK 21, CMake, and several legacy online SDK dependencies. Those online dependencies are expected to be one of the first build-cleanup targets.

## Current Godot prototype

The existing Godot implementation remains on `main` and is intentionally preserved. It can still serve as a test harness/reference for custom single-player rules, but it is no longer the preferred path for reproducing the original game's presentation.
