# Reddit Posts — Red Grid Link Launch Day

Copy-paste these into each subreddit. Each is tailored to the audience.

---

## 1. r/FlutterDev

**Title:** I built an encrypted BLE mesh sync engine in Flutter — CRDT replication, ECDH key exchange, 783 tests, shipping on the App Store

**Body:**

Last year I shipped Red Grid MGRS — a solo land navigation app built in React Native. It did well in a niche market, but the #1 feature request was always "let me see my team on the map." That meant peer-to-peer sync over Bluetooth with no internet, which meant rebuilding from scratch. I chose Flutter for the rewrite, and I want to share what the architecture looks like after ~180 Dart source files and 783 passing tests.

**The app:** Red Grid Link — encrypted team coordination over BLE + WiFi Direct. Think lightweight ATAK (military blue force tracker) for small teams, completely offline. Devices discover each other via Bluetooth, establish encrypted sessions, and share positions/markers in real time.

**The interesting Flutter/Dart bits:**

- **BLE transport layer** built on `flutter_blue_plus`. Handles device discovery, connection management, MTU negotiation, and characteristic-based data exchange. Separate WiFi Direct transport via platform channels (Android Nearby Connections API, iOS Multipeer Connectivity via AWDL). Transport is abstracted so the sync engine doesn't care which radio carries the bytes.

- **CRDT sync engine** using LWW (Last-Writer-Wins) Registers for position data and G-Counters for event tracking. Delta payloads are compact JSON under 200 bytes per update. No central authority, no conflict resolution server — convergence is guaranteed by the CRDT properties. Reconnecting peers catch up via delta exchange.

- **Real cryptography** with `pointycastle`: ECDH P-256 key exchange to establish per-session shared secrets, then AES-256-GCM for all sync traffic. Ephemeral keys — nothing persists after the session ends. Tiered auth: Open (auto-join), PIN (4-digit), or QR code.

- **State management** is all Riverpod. The BLE connection lifecycle, sync state, peer list, and map overlays are all reactive streams. Drift (SQLite) for persistence, `flutter_map` + `flutter_map_mbtiles` for offline maps with a custom MGRS grid overlay.

- **Platform channels** for native functionality: `com.redgrid.link/nearby_connections` (Android WiFi Direct), `com.redgrid.link/battery` (battery optimization), and an Android foreground service in Kotlin for background BLE sync.

- **Testing:** 783 tests covering the CRDT convergence properties, encryption round-trips, BLE state machine transitions, coordinate math, and widget rendering. Every PR must pass all 783 before merge.

The hardest part was the BLE connection lifecycle on iOS vs Android. They behave differently in background mode, have different MTU defaults, and iOS doesn't expose MAC addresses. I ended up building a platform-agnostic peer identity system on top of service UUIDs.

App Store: https://apps.apple.com/app/id6760084718

Not open source (unlike Red Grid MGRS), but happy to go deep on any of the architecture — CRDT design, BLE gotchas, Riverpod patterns for hardware state, or the ECDH handshake flow.

---

## 2. r/army

**Title:** I built the Red Grid MGRS app last year — now it does team tracking over Bluetooth. No TAK Server, no NIPR, no accounts. Free for 2 devices.

**Body:**

Some of you may have seen Red Grid MGRS — the DAGR replacement app I built and posted here last year. The #1 request was always "this is great for solo nav, but I need to see my team."

So I rebuilt it from the ground up as Red Grid Link. Same MGRS engine, same land nav tools, but now with Field Link — encrypted peer-to-peer team tracking over Bluetooth and WiFi Direct. No cell service, no TAK Server, no NIPR, no IT shop involvement.

**What it does:**

- Everyone in your element opens the app, starts a session, and devices auto-discover each other via Bluetooth
- You see your team's positions on the map in real time, with MGRS grids overlaid on offline topo maps
- When someone moves out of BLE range, you get a ghost marker showing their last known position with a velocity vector showing which direction they were heading
- All sync traffic is AES-256 encrypted with ephemeral session keys
- Session security: Open (auto-join for speed), PIN (4-digit), or QR code
- Expedition mode for extended ops — under 3% battery per hour

**How this compares to ATAK:**

ATAK is powerful but it's a heavy lift. You need Android devices, a TAK Server for anything beyond line-of-sight, and someone who knows how to configure it. Red Grid Link is the other end of the spectrum — zero configuration, works on both iPhone and Android, and the entire sync layer runs over Bluetooth. No infrastructure.

It's not trying to replace ATAK for a full-scale operation. It's for the squad leader running a training lane, the recon team doing a route recon, the LT who wants to track his platoon during a ruck without setting up a TAK Server.

**The tools are still there:** Dead reckoning, resection, pace count, bearing calculator, coordinate converter, range estimation, slope calculator, mag declination — 11 tools total. Plus after-action report PDF export.

**4 modes:** SAR, Backcountry, Hunting, Training. Training mode gives you rally points, phase lines, and exercise objectives.

**Pricing:** Free for 2 devices, 1 map region, and the Red Light theme. Pro+Link ($5.99/mo or $44.99/yr) unlocks 8-device Field Link and all themes. Lifetime unlock is $99.99. No tracking, no accounts, no data collection.

App Store: https://apps.apple.com/app/id6760084718

Android is supported — it's cross-platform. Built this for the team leader who wants to run a better training exercise without a 6-month equipment request.

---

## 3. r/searchandrescue

**Title:** I built a SAR team coordination app that works without cell service — Bluetooth mesh sync, offline topo maps, ghost markers for lost-signal teammates

**Body:**

I built this originally for military-style land navigation. But as I talked to SAR teams, I realized the core problem is the same: you need to know where your team is, you're usually beyond cell coverage, and the existing solutions either require infrastructure you don't have or cost more than your annual budget.

**Red Grid Link** is an offline-first team coordination app with a dedicated SAR mode. Here's what matters for search operations:

**Field Link — team tracking without cell towers:**
- Devices within Bluetooth/WiFi Direct range (~30-100m in terrain) auto-discover and share encrypted position data
- You see your entire team on the map in real time
- When a teammate moves out of range, you get a ghost marker at their last known position that fades over 30 minutes — so you always know where people were, even when comms drop
- Velocity vectors show the direction each person was heading at disconnect
- Auto-reconnect when people come back in range

**Offline maps:**
- Download USGS Topo and OpenTopoMap tiles before deployment — stored locally as MBTiles
- MGRS grid overlay at all zoom levels (the same coordinate system used in ICS forms)
- Works identically with no cell service, no WiFi, no internet

**SAR mode features:**
- Sector assignments and clue markers
- Search pattern tracking
- Session history for reviewing past operations
- After-action report PDF export with map snapshot, timeline, track data, team roster, and markers — one tap to generate, share via AirDrop or file transfer

**11 navigation tools:** Dead reckoning, resection, pace count, bearing calculator, coordinate converter, range estimation, slope calculator, ETA/speed, magnetic declination, celestial nav reference, MGRS precision reference.

**Privacy:** No accounts, no cloud, no tracking. Position data stays on device. Field Link sessions are ephemeral — encrypted with AES-256, nothing persists after the session ends.

**Pricing:** Free tier gives you 2-device Field Link, 1 map region, and all tools. Pro+Link ($5.99/mo or $44.99/yr) scales to 8 devices with unlimited map downloads. Team plan ($199.99/yr) covers 8 seats. Lifetime is $99.99.

I know SAR teams use everything from onX to SARTopo to handheld radios. Red Grid Link isn't trying to replace your radio net — it's the visual layer that shows you where everyone is without requiring a repeater, a server, or cell coverage.

App Store: https://apps.apple.com/app/id6760084718

Works on both iPhone and Android. Happy to answer questions about how the Bluetooth sync works in real terrain.

---

## 4. r/hunting

**Title:** Built an app that lets your hunting party see each other on topo maps via Bluetooth — no cell service needed, no accounts, no subscriptions required

**Body:**

I built Red Grid Link because I was tired of the "where are you?" text that never sends because there's no service at the trailhead.

The core feature is Field Link: everyone in your group opens the app, starts a session, and your phones sync positions over Bluetooth. You see your whole party on a topographic map in real time. No cell towers, no internet, no accounts to create.

**How it works for a hunt:**

- Download your area's topo maps at home on WiFi (USGS Topo or OpenTopoMap — cached offline)
- At the property, everyone opens the app and joins a session. Devices discover each other automatically over Bluetooth
- You see each person's position on the map, updated in real time
- Mark stand locations, game sightings, or property boundaries as shared waypoints
- When someone is out of Bluetooth range, you get a ghost marker showing their last known position and which direction they were heading
- When they come back in range, positions snap back to live

**Hunting mode** adapts the UI for hunting — stand locations, game sighting markers, property boundary tools.

**What makes it different from onX or HuntStand:**
- Works without cell service. Period. The sync runs over Bluetooth and WiFi Direct.
- No account. No login. No email. You open the app and it works.
- No one is tracking where you hunt. Position data never leaves your phone. The Bluetooth sync is encrypted and ephemeral — nothing persists after you end the session.
- See your whole party's positions, not just your own pin on a map.

**Practical range:** Bluetooth Low Energy carries about 30-100 meters in wooded terrain, farther in open fields. If your party spreads out beyond that, the ghost markers keep you oriented on where everyone was. Positions update immediately when you're back in range. You can also use WiFi Direct for longer range between Android devices.

**Pricing:** The free tier gives you 2-device sync, 1 offline map region, and all 11 navigation tools. That covers a two-person party. Pro+Link ($5.99/mo or $44.99/yr) scales to 8 devices with unlimited map downloads. Or $99.99 lifetime — one purchase, done forever. No recurring fees required for the base experience.

**4 tactical display themes:** Red Light for dawn/dusk (free), plus NVG Green, Day White, and Blue Force with Pro.

App Store: https://apps.apple.com/app/id6760084718

Works on both iPhone and Android. Built by someone who got tired of not knowing where the team was in the woods.

---

## 5. r/privacy

**Title:** I built a team GPS tracker with zero-cloud architecture — AES-256-GCM encryption, ECDH ephemeral keys, no accounts, no analytics, no servers. Position data never touches the internet.

**Body:**

Last year I posted about Red Grid MGRS — a solo GPS navigator with zero-network architecture. The follow-up app, Red Grid Link, adds team coordination, which creates a much harder privacy problem: how do you share real-time position data between devices without a server, without accounts, and without any data leaving the local radio layer?

**The architecture:**

Red Grid Link syncs position data between nearby devices using Bluetooth Low Energy and WiFi Direct. The data path is: your GPS sensor -> your device's memory -> encrypted BLE/WiFi Direct packet -> teammate's device. That's it. No server, no relay, no cloud, no internet connection involved at any point.

**Cryptographic design:**

- **Key exchange:** ECDH on P-256 (NIST curve). Each session generates ephemeral key pairs. The shared secret is derived via ECDH and never stored — it exists in memory only for the session duration.
- **Encryption:** AES-256-GCM for all sync traffic. Every position update, every marker, every piece of shared data is authenticated and encrypted before it hits the radio.
- **Session authentication:** Three tiers — Open (auto-join, convenience for trusted environments), PIN (4-digit shared secret), or QR code (out-of-band key exchange).
- **Ephemeral sessions:** When a Field Link session ends, all shared state is discarded. No position history, no peer identifiers, no session logs are retained from the sync layer.

**What the app never does:**

- No accounts. No sign-up. No login. No email. No phone number.
- No cloud sync. No backend. No API calls. No server of any kind.
- No analytics SDK. No crash reporting that includes location data (Sentry is used in release builds but location data is explicitly stripped).
- No third-party data SDKs. No ad networks.
- No device fingerprinting. No identifier collection.
- GPS coordinates exist in memory during use. Waypoints you explicitly save are stored locally via SQLite. Nothing is ever transmitted beyond the local Bluetooth/WiFi Direct radius.

**The tradeoff:** Bluetooth range is limited (~30-100m in terrain). You don't get city-wide tracking or cloud-based coordination. That's a feature, not a bug. The radio range is your privacy boundary — your position is only shared with devices physically near you.

**For the skeptics:** The app is not open source (the previous version, Red Grid MGRS, is — MIT + Commons Clause). I understand that limits verifiability. What I can tell you is: there is no backend to send data to. The app has no network permissions beyond what BLE and WiFi Direct require. You can verify the network behavior with a packet sniffer — there is no outbound internet traffic during normal operation.

**Business model:** Free tier (2 devices, 1 map region) with paid upgrades for more devices and map downloads. In-app purchases processed through Apple/Google only. No server-side receipt validation — the unlock flag is stored locally.

App Store: https://apps.apple.com/app/id6760084718

The original zero-network app: https://github.com/RedGridTactical/RedGridMGRS (open source, MIT + Commons Clause)

Happy to discuss the ECDH handshake flow, the threat model, or the design decisions around ephemeral sessions.

---

## 6. r/SideProject

**Title:** From solo GPS app to encrypted team tracker — I rebuilt my side project from React Native to Flutter, added BLE mesh sync, and it costs me $0/month to run

**Body:**

**The backstory:** Last year I launched Red Grid MGRS — a $3.99 military GPS navigator built with React Native. It did well in a tiny niche (military, SAR, backcountry). The #1 feature request was always team tracking: "I can see my grid, but I need to see my team's grid."

Adding peer-to-peer sync to a React Native app is painful. BLE libraries in RN are brittle, platform channel support is limited, and I needed native Android foreground services for background Bluetooth. So I rewrote the entire thing in Flutter as Red Grid Link.

**What changed:**

| | Red Grid MGRS | Red Grid Link |
|---|---|---|
| Framework | React Native + Expo | Flutter (Dart) |
| Lines of code | ~15,000 JS | ~180 Dart files |
| Tests | ~50 | 783 |
| Key feature | Solo MGRS navigation | Encrypted team sync over BLE |
| Source | Open source (MIT) | Closed source |
| Price | $3.99 + $9.99 Pro | Free + subscription tiers |

**Field Link** is the feature that justified the rewrite. Devices discover each other over Bluetooth, negotiate an ECDH key exchange, and start sharing encrypted position data. No server, no internet, no configuration. You see your team on the map. It uses CRDTs (conflict-free replicated data types) for sync, so there's no central authority and reconnecting peers converge automatically.

**The $0/month infrastructure story continues:**

Red Grid MGRS had zero backend. Red Grid Link still has zero backend — the sync runs over Bluetooth and WiFi Direct between devices in proximity. My monthly costs are:
- Hosting: $0 (no server)
- Database: $0 (SQLite on device)
- Analytics: $0 (no analytics)
- Auth: $0 (no accounts)
- CDN: $0 (maps downloaded from public USGS/OSM tile servers)

Revenue is purely App Store/Play Store sales minus platform cut.

**Pricing evolution:** Red Grid MGRS was $3.99 + $9.99 one-time Pro. Red Grid Link moved to subscriptions because the team sync feature has ongoing value and I wanted a free tier to lower the barrier. Free gets you 2-device sync and 1 map region. Pro+Link at $5.99/mo or $44.99/yr unlocks 8-device sync. Lifetime option at $99.99 for people who hate subscriptions (I get it).

**What I learned:**

- Flutter's platform channel system is dramatically better than RN's bridge for native hardware access. Writing the BLE and WiFi Direct layers was actually pleasant.
- 783 tests sounds like a lot, but CRDT convergence properties and encryption round-trips demand thorough coverage. One off-by-one in the vector clock and sync breaks silently.
- The niche is small but loyal. Military, SAR, hunting, backcountry. These people operate without cell service and currently have no good team coordination tool that doesn't require infrastructure.
- Subscriptions on a niche app are a gamble. The lifetime option exists as a hedge.

App Store: https://apps.apple.com/app/id6760084718
The original open source app: https://github.com/RedGridTactical/RedGridMGRS
