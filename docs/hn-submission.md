# HN Submissions — Red Grid Link

Three submission options, ordered by likely HN resonance. Stagger these — don't post more than one per week. Best times: Tuesday-Thursday 9-11am ET.

---

## Option A: Dev.to Article Link Post (RECOMMENDED FIRST)

### Title
Encrypted Bluetooth Team Sync in Flutter — AES-256-GCM, ECDH, CRDTs, No Servers

### URL
[Dev.to article URL once published]

### Why this works on HN
Distributed systems + cryptography + protocol engineering. This is the technical deep-dive that HN readers want to dissect. The article covers BLE transport, AES-256-GCM encryption, ECDH key exchange, CRDT-based conflict resolution, and the UX of unreliable radio links. Every paragraph has something a systems engineer can argue about.

---

## Option B: Show HN Post

### Title
Show HN: Red Grid Link — encrypted peer-to-peer team tracking over BLE, no servers

### URL
https://github.com/RedGridTactical/RedGridLink

### Text

I built an encrypted peer-to-peer team coordination app that syncs GPS positions over Bluetooth and WiFi Direct. No server, no internet, no extra hardware. Phones talk directly to phones.

The technical architecture:

- Transport: BLE (universal fallback) + Android Nearby Connections + iOS Multipeer Connectivity via platform channels
- Encryption: AES-256-GCM with ECDH P-256 key exchange. Every peer pair negotiates a unique session key
- Sync engine: Custom CRDT (Last-Write-Wins Register + G-Counter) with delta encoding — each update is <200 bytes
- Conflict resolution: CRDTs make merge conflicts mathematically impossible, even with intermittent connectivity
- Security tiers: Open (discovery), PIN (shared secret), QR (visual key exchange)

The hardest problem wasn't the crypto or the BLE — it was building a distributed system on top of radio links that drop every time someone walks behind a truck. Exponential backoff (2s-30s, max 5 retries), heartbeat detection, and graceful peer demotion (connected → reconnecting → ghost) make it work in practice.

Built with Flutter. 180+ Dart source files, 780+ tests, 5 native files (Kotlin/Swift for platform channel bridges). MIT licensed.

Use cases: backcountry hiking groups, search and rescue teams, hunting parties, field training exercises — anywhere you need to know where your team is and there's no cell signal.

App Store: https://apps.apple.com/app/id6760084718
GitHub: https://github.com/RedGridTactical/RedGridLink

---

## Option C: Privacy/Architecture Angle

### Title
Zero-server team tracking: How we built encrypted peer-to-peer sync without any cloud

### URL
https://github.com/RedGridTactical/RedGridLink

### Why this works on HN
HN has a strong privacy-conscious audience. "No servers" is a design constraint that forces interesting architectural choices. The discussion bait is: "Can you build real-time multi-user coordination without any server?" The answer involves CRDTs, BLE mesh topology, and local-only encryption — all topics HN loves to debate.

---

## Submission Strategy

1. **First (this week):** Post Option A (Dev.to article link) after publishing the article on Tuesday
2. **If Option A doesn't gain traction:** Wait 7+ days, post Option B as Show HN
3. **Option C:** Reserve for a follow-up article specifically about the zero-server architecture

### HN Anti-Gaming Rules
- Never ask anyone to upvote — HN detects coordinated voting from as few as 5-6 people
- One upvote per IP — same-network votes get collapsed
- "Please upvote" on social media triggers auto-filtering
- Posts with more comments than upvotes get a flamewar penalty
- Show HN posts get a 0.4 ranking penalty — need ~2x upvotes to rank equal to link posts

### If It Hits the Front Page
- Monitor and reply to every comment within minutes
- Be technical and specific — HN rewards depth over marketing
- Acknowledge limitations honestly (BLE range, iOS background restrictions)
- Don't be defensive about criticism — engage with it
- Have the GitHub repo clean and README polished before posting
