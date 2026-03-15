---
title: "How I Built Encrypted Bluetooth Team Sync in Flutter — AES-256-GCM, ECDH, CRDTs, Zero Servers"
published: false
tags: flutter, bluetooth, encryption, mobile
description: "I built an encrypted peer-to-peer team coordination app using Flutter, BLE, and WiFi Direct. Here's the technical deep dive into the distributed systems challenges."
---

There are plenty of places where cell towers don't exist. Mountains, forests, remote wilderness where the only infrastructure is what you carry. When your team spreads out across a few kilometers, knowing where everyone is isn't a nice-to-have — it's a safety issue.

So I built Red Grid Link: an encrypted peer-to-peer team coordination app that syncs positions over Bluetooth and WiFi Direct. No servers, no subscriptions to a mesh network, no extra hardware. Just the phones already in everyone's pocket.

This is the technical story of how it works under the hood.

---

## Part 1: The Problem

Military and SAR teams need to share positions in the field. The gold standard is ATAK — the Android Team Awareness Kit. It's powerful, battle-proven, and used across the DoD. But ATAK requires a TAK Server for team sync, it's Android-only, and the learning curve is steep. You're not handing it to a volunteer search-and-rescue member and saying "figure it out."

Hardware solutions exist too. goTenna mesh radios and Garmin inReach devices both enable off-grid position sharing. But you're looking at $200-400 per device, and every team member needs one. For a hunting party or a backcountry hiking group, that's a non-starter.

What I wanted was simple: phones talking directly to phones. No server, no extra hardware, no internet dependency. BLE is on every modern smartphone. WiFi Direct is on every Android. Apple has AWDL (Apple Wireless Direct Link) via Multipeer Connectivity. The radios are already there — I just needed to make them talk.

The catch? Building a distributed system on top of unreliable short-range radio links, with encryption, conflict resolution, and a UX that doesn't require a networking degree. Easy, right?

---

## Part 2: The Transport Layer — BLE + WiFi Direct

The transport layer is a three-headed beast. Each platform has its own preferred high-bandwidth direct communication protocol, but BLE is the universal fallback that works everywhere.

**BLE (Both Platforms):** I use `flutter_blue_plus` for Bluetooth Low Energy. Every device advertises a custom service UUID and continuously scans for peers advertising the same UUID. When a peer is discovered, GATT characteristics handle the data exchange. BLE is reliable, low-power, and cross-platform — but bandwidth-limited. Position updates are small enough that this doesn't matter.

**Android — Nearby Connections API:** For higher throughput (like syncing map annotations or longer state), Android devices upgrade to Google's Nearby Connections API via platform channels. This uses a combination of BLE, WiFi Direct, and WiFi hotspot under the hood — Google abstracts away the messy parts. I wrote Kotlin platform channel handlers that bridge Nearby Connections events back to Dart.

**iOS — Multipeer Connectivity:** Apple's equivalent is Multipeer Connectivity, which runs over AWDL (the same protocol that powers AirDrop). Swift platform channel handlers mirror the Android side, exposing the same Dart interface. One Dart API, two native implementations.

**The Cross-Platform Problem:** Here's the thing nobody tells you — an Android device using Nearby Connections can't directly talk to an iOS device using Multipeer Connectivity. They're completely different protocols. BLE is the bridge. When the group is mixed-platform, everything falls back to BLE, which works universally but at lower bandwidth. For position updates at 10-30 second intervals, BLE is more than sufficient.

**Connection Management:** Wireless links drop. A lot. Someone walks behind a ridge, a vehicle drives between two peers, or BLE just decides to be BLE. The reconnection logic uses exponential backoff starting at 2 seconds, doubling up to a 30-second ceiling, with a maximum of 5 retry attempts before marking a peer as lost. The connection state machine tracks `connected`, `reconnecting`, and `lost` states, and the UI reflects each one.

**Battery — The Silent Killer:** Nothing ends a field operation faster than a dead phone. I built two power modes:

- **Expedition Mode:** BLE-only transport, 30-second update intervals, aggressive scan duty cycling. Measured drain: under 3% per hour.
- **Ultra Expedition Mode:** 60-second intervals, minimal scanning windows, everything non-essential suspended. Under 2% per hour.

Battery profiling on actual devices in the field was one of the most important things I did. Lab numbers mean nothing when it's 20 degrees and your battery capacity is already halved.

---

## Part 3: The Encryption — AES-256-GCM + ECDH P-256

"It's just Bluetooth, who's going to sniff it?" — famous last words. BLE range extends farther than people think, especially with directional antennas. If you're sharing team positions, those positions should be encrypted. Period.

The encryption stack uses two well-established primitives: ECDH for key exchange and AES-256-GCM for payload encryption. Both are implemented using the `pointycastle` Dart library — no native dependencies, no platform-specific crypto.

Here's the flow:

```
┌─────────┐                        ┌─────────┐
│ Device A │                        │ Device B │
└────┬─────┘                        └────┬─────┘
     │  Generate ephemeral ECDH P-256 keypair  │
     │──────── Send public key ────────────────>│
     │<──────── Send public key ────────────────│
     │                                          │
     │  ECDH shared secret = A_priv * B_pub     │
     │  Session key = HKDF(shared_secret)       │
     │                                          │
     │  All payloads: AES-256-GCM(key, nonce,   │
     │    plaintext) → ciphertext + auth tag     │
     └──────────────────────────────────────────┘
```

**Ephemeral Keys:** Every session generates fresh ECDH keypairs. When the session ends, the keys are gone. No key storage, no key management, no persistent secrets on the device. This is deliberate — the threat model is proximity-based. If someone is close enough and motivated enough to perform a real-time MITM attack on your BLE connection while you're in the backcountry, you have bigger problems.

**Tiered Session Security:** Not every use case needs the same security posture:

- **Open:** Devices auto-join the session. ECDH exchange still happens (encryption is always on), but there's no authentication. Good for casual hiking groups.
- **PIN:** A 4-digit shared secret is fed into key derivation alongside the ECDH output. Both sides must know the PIN before the session key is derived. Simple, memorable, good enough for most field use.
- **QR Code:** Full key material is encoded in a QR code. One device generates, the others scan. Maximum security — no brute-forceable PIN, no trust-on-first-use.

**Authenticated Encryption:** AES-256-GCM provides both confidentiality and integrity. Every encrypted payload includes an authentication tag. If a single bit is tampered with in transit, decryption fails and the payload is discarded. This isn't just theoretical — BLE is noisy, and being able to distinguish corruption from tampering matters.

No certificates. No PKI. No certificate authorities. The entire trust model is "we are physically near each other and we agreed on a session credential." For a team standing in a parking lot before heading into the field, that's the right model.

---

## Part 4: The Sync Engine — CRDTs for Conflict-Free State

Here's where it gets interesting from a distributed systems perspective. With no central server, there's no single source of truth. Two devices might update the same marker while temporarily disconnected. When they reconnect, whose version wins?

The answer is CRDTs — Conflict-free Replicated Data Types. Specifically:

- **LWW Register (Last-Writer-Wins):** Used for position data and marker state. Every update carries a logical timestamp. When two conflicting updates arrive, the one with the higher timestamp wins. For position data, this is always correct — the latest position is the most accurate.
- **G-Counter:** Used for event ordering. A grow-only counter where each device maintains its own monotonically increasing count. The merged counter is the element-wise maximum across all devices.

**Delta Sync:** Sending the full state on every update would be wasteful and slow. Instead, only deltas are transmitted — the minimum set of changes since the last acknowledged sync point. A typical position update delta looks like this:

```json
{
  "v": 1,
  "src": "a3f8",
  "seq": 47,
  "ts": 1710400000,
  "ops": [
    {
      "type": "pos",
      "lat": 35.7796,
      "lon": -78.6382,
      "alt": 132.4,
      "hdg": 47,
      "spd": 1.2,
      "acc": 4.5
    }
  ]
}
```

That's under 200 bytes. Over BLE with a 20-byte MTU (after negotiation, usually 185-512 bytes), a single position update fits in one or two packets. The `src` field is a truncated device ID, `seq` is the monotonic sequence number, and `ts` is the logical timestamp for LWW resolution.

For marker operations — dropping a waypoint, annotating the map — the delta includes the operation type and the marker state:

```json
{
  "v": 1,
  "src": "a3f8",
  "seq": 48,
  "ts": 1710400005,
  "ops": [
    {
      "type": "mkr",
      "id": "m-a3f8-12",
      "act": "upsert",
      "lat": 35.7801,
      "lon": -78.6390,
      "label": "Rally Point",
      "icon": "flag"
    }
  ]
}
```

**Convergence:** The mathematical property that makes CRDTs work is that merge is commutative, associative, and idempotent. In plain English: it doesn't matter what order messages arrive in, it doesn't matter if messages arrive multiple times, and it doesn't matter which device merges with which — everyone converges to the same state. No coordination required. No consensus protocol. No leader election. It just works.

This is critical over BLE where message ordering is not guaranteed, packets can be duplicated, and topology changes constantly as devices move in and out of range.

---

## Part 5: The UX Challenges

The hardest problems weren't in the protocol layer — they were in making the system feel intuitive when peers appear, disappear, and reappear unpredictably.

**Ghost Markers:** When a teammate walks behind a ridge and drops off BLE, their icon doesn't just vanish. That would be useless and alarming. Instead, the map shows their last-known position as a "ghost" — a dimmed marker at the coordinates of their final update.

**Time-Decay Visualization:** The ghost marker's opacity decays linearly from 100% to a faint outline over 30 minutes. A solid ghost means "they were just here." A faint outline means "this position is getting stale, don't trust it." After 30 minutes with no update, the marker switches to an outline-only ring — clearly present but clearly old data.

**Velocity Vectors:** At the moment a peer disconnects, the app captures their last known heading and speed. A small projected vector extends from the ghost marker in their direction of travel. It's not GPS — it's a best guess. But knowing "they were heading northwest at walking pace" is vastly more useful than a dot that could mean anything.

**Snap-to-Live:** When a lost peer reconnects, their ghost marker doesn't just teleport to the new position. It animates smoothly from the last-known position to the current one. This brief animation (about 300ms) provides visual continuity — your brain tracks the movement and maintains spatial awareness of the team.

**Peer HUD Overlay:** Each connected peer gets a heads-up display element on the map showing distance and magnetic bearing from your position. "BRAVO — 340m — 047°" — the same format you'd hear on a radio. No mental math, no map-reading skills required.

---

## Part 6: What I'd Do Differently

**BLE Cross-Platform Quirks:** Android and iOS handle BLE scanning fundamentally differently. Android lets you scan continuously in the foreground. iOS throttles background scanning aggressively and filters duplicate advertisements. The same discovery logic that works instantly on Android takes 10-15 seconds on iOS. I spent weeks tuning scan windows and duty cycles per platform. If I started over, I'd abstract the platform differences earlier and test on both platforms from day one.

**Testing Distributed Systems:** I have 783 tests, and I'm proud of the coverage. But the honest truth is that most of them are unit tests. Testing actual multi-device BLE behavior requires physical devices — you can't simulate real radio conditions in a test harness. I built mock transport layers that simulate latency, packet loss, and disconnection, which catches logic bugs. But the nastiest bugs only showed up with real phones at real distances. Integration testing in a parking lot became a regular part of my development cycle.

**Battery Profiling:** I cannot overstate how important this was. My first prototype drained 15% per hour. Users in the field might be out for 8-12 hours with no way to charge. Every BLE scan window, every GPS poll interval, every screen wake — I measured and optimized. The final numbers (under 3% per hour in Expedition Mode) only happened after dozens of profiling sessions on multiple device models.

**CRDTs — Were They Overkill?** For position updates alone, a simple "latest timestamp wins" without the formal CRDT machinery would have been fine. But once I added map markers, annotations, and shared state that could be edited by multiple peers simultaneously, the CRDT foundation paid for itself completely. Markers can be created, moved, and deleted by any peer, and the state converges correctly without any conflict resolution UI. Users never see a "conflict detected" dialog. It just merges.

---

## Ship It

Red Grid Link is live on the App Store. It supports SAR, backcountry, hunting, and training modes — each tuned for the typical team size, update frequency, and operational tempo of that use case.

The core technical bet — that you can build a meaningful team coordination tool using only the radios already in everyone's phones — turned out to be right. BLE range isn't unlimited, but for a team spread across a valley or a search grid, it's enough. And when it's not, the ghost markers and velocity vectors bridge the gap.

No servers to maintain. No subscription to a mesh network. No extra hardware to buy, charge, and lose. Just phones talking to phones, encrypted end-to-end, converging on shared truth without a single central authority.

That's the kind of system anyone working off-grid can appreciate.

[Red Grid Link on the App Store](https://apps.apple.com/app/id6760084718)
