# Kingdom Drop — store listing draft

Copy for Google Play and the App Store. Everything here describes features
that are actually implemented; nothing claims a leaderboard, a multiplayer
mode or a content volume that does not exist.

**Before publishing:** replace every `[BRACKETED]` placeholder, and check the
character counts against the console — both stores truncate silently.

---

## App title

**Google Play** (30 characters max)

```
Kingdom Drop
```

Alternatives if the name is taken, all within 30 characters:

- `Kingdom Drop: Block Puzzle` (26)
- `Kingdom Drop — Block Puzzle` (27)

**App Store** (30 characters max)

```
Kingdom Drop
```

---

## Subtitle / short description

**App Store subtitle** (30 characters max)

```
Build. Clear. Conquer.
```

Alternatives:

- `Block puzzle, rebuild realms` (28)
- `Drop blocks, rebuild kingdoms` (29)

**Google Play short description** (80 characters max)

```
Drop blocks, clear lines, and rebuild ten fallen kingdoms one puzzle at a time.
```

(78 characters.)

---

## Google Play full description

*(4000 characters max; this draft is around 2,200.)*

```
Build. Clear. Conquer.

Your kingdom has fallen. Every puzzle helps rebuild it.

Kingdom Drop is a block puzzle you can learn in ten seconds and keep playing
for months. Drag shapes onto a 7x7 board. Fill a row, a column or a 3x3 block
and it clears away. Clear several at once and the combo multiplier starts
climbing.

There is no timer and no pressure — just you, the board, and the question of
where that next awkward piece is going to go.

REBUILD TEN KINGDOMS
Every run earns crowns, and crowns rebuild your realm. Start with the ruined
Forgotten Keep: repair the gate, rebuild the bridge, raise the market, restore
the tower, and crown the castle. Finish it and a new kingdom opens up.

Ten realms to restore, each with its own look and its own five repairs:
Forgotten Keep, Greenwood Village, Storm Harbour, Desert Citadel, Frozen
Kingdom, Haunted Realm, Sky Kingdom, Volcanic Fortress, Crystal Empire and
Star Kingdom.

SIMPLE TO PLAY, HARD TO MASTER
- One-handed play. Drag, drop, done.
- No timer. Take as long as you like on every move.
- Pieces cannot be rotated, so every placement is a real decision.
- The board never deals you a set with nothing that fits.

POWERFUL BOOSTERS
- Hammer: remove any single block.
- Bomb: blast a 3x3 area clear.
- Shuffle: swap your three pieces for new ones.
- Second Chance: clear space and keep a great run alive.

COME BACK FOR MORE
- A seven-day reward streak, with a mystery chest on day seven.
- A fresh daily challenge every day.
- Player levels, achievements and chests.
- Chase your best score, then beat it.

FREE TO PLAY, FAIR TO PLAY
The full puzzle is free. Purchases are for convenience — coins, boosters and
continues — and the base game never gates you behind them. Rewarded ads are
always your choice, never forced. If you would rather not see ads between
games at all, a single Remove Ads purchase takes care of it, and rewarded ads
stay available if you want them.

No account. No login. No personal data collected. Your progress is saved on
your device.

Build. Clear. Conquer.
```

---

## Apple promotional text

*(170 characters max. Can be updated without a new app review — use it for
seasonal messages.)*

```
Ten fallen kingdoms are waiting to be rebuilt. Drop blocks, clear lines, earn
crowns, and bring every realm back one puzzle at a time. No timer, no pressure.
```

(155 characters.)

---

## Apple description

*(4000 characters max.)*

```
Build. Clear. Conquer.

Your kingdom has fallen. Every puzzle helps rebuild it.

Kingdom Drop is a block puzzle you can learn in ten seconds and keep playing
for months. Drag shapes onto a 7x7 board. Fill a row, a column or a 3x3 block
and it clears away. Clear several at once and the combo multiplier climbs.

There is no timer and no pressure — just you, the board, and the question of
where that next awkward piece is going to go.

REBUILD TEN KINGDOMS
Every run earns crowns, and crowns rebuild your realm. Start with the ruined
Forgotten Keep and work through ten kingdoms, each with its own look and its
own five repairs. Watch the gate close, the lanterns light and the banners go
up as you go.

SIMPLE TO PLAY, HARD TO MASTER
• One-handed play — drag, drop, done
• No timer, so every move can take as long as you like
• Pieces cannot be rotated, so every placement matters
• You are never dealt a set of pieces with nothing that fits

BOOSTERS FOR THE TIGHT SPOTS
• Hammer — remove any single block
• Bomb — blast a 3x3 area clear
• Shuffle — swap your three pieces
• Second Chance — clear space and keep a great run going

REASONS TO COME BACK
• A seven-day reward streak with a mystery chest at the end
• A new daily challenge every day
• Player levels, achievements and chests
• A best score that is always worth beating

FAIR BY DESIGN
The full puzzle is free to play. Purchases are for convenience — coins,
boosters and continues — and nothing in the core game is locked behind them.
Rewarded ads are always opt-in. A single Remove Ads purchase clears the
between-game ads and leaves the rewarded ones available if you want them.

No account. No login. No personal data collected. Your progress is stored on
your device.

Build. Clear. Conquer.
```

---

## Keywords

**Apple keyword field** (100 characters max, comma-separated, no spaces after
commas, do not repeat words already in the title or subtitle):

```
block,puzzle,blast,brain,tile,grid,logic,offline,relax,casual,match,kingdom,castle,build,jigsaw
```

(95 characters.)

Notes:
- Apple already indexes the title and subtitle, so "Kingdom" and "Drop" are
  arguably wasted here — drop them if you need room for something better.
- Do not use competitors' trademarked names. Apple rejects for this and it is
  not worth the risk.

**Google Play** has no keyword field — it indexes the title, short description
and full description. The draft above already works in: block puzzle, clear
lines, combo, kingdom, castle, boosters, daily challenge, offline, free to
play.

---

## Screenshots

Six screenshots, in this order. The first two do most of the work — most people
never swipe past them.

| # | Caption | What to show |
| --- | --- | --- |
| 1 | **DRAG. DROP. CLEAR.** | The board mid-game, a piece under the finger with the green landing preview visible and a row highlighted for clearing. |
| 2 | **BUILD YOUR KINGDOM** | The Kingdom screen with a partly restored realm — some repairs ticked, the next one highlighted with its crown cost. |
| 3 | **CREATE MASSIVE COMBOS** | The moment of a multi-line clear: particles flying, the combo badge lit at x2 or better, a big floating score. |
| 4 | **UNLOCK POWERFUL BOOSTERS** | The booster bar with a bomb armed and the 3x3 targeting highlight on the board. |
| 5 | **RETURN EVERY DAY** | The daily reward sheet with several days claimed and the day-seven chest visible. |
| 6 | **HOW HIGH CAN YOU SCORE?** | The summary screen showing NEW BEST SCORE with a strong number and the crowns earned. |

### Capturing them

There is a **screenshot mode** in the debug menu that loads a good-looking
profile — a part-built kingdom, a healthy wallet, boosters in stock and a
strong best score — so the shots do not have to be earned by hand:

```bash
flutter run --profile --dart-define=FORCE_DEBUG_MENU=true
```

Tap the red bug button on Home → **Screenshot mode** → *Set up screenshot
state*. The debug menu is compiled out of release builds entirely.

### Sizes required

**Google Play**
- Phone: minimum 2, maximum 8. 1080×1920 or larger, 16:9 or 9:16.
- Feature graphic: 1024×500, **required**. No screenshot substitutes for this;
  it needs designing separately.
- App icon: 512×512 PNG.

**App Store**
- 6.7" iPhone (1290×2796) — required.
- 6.5" iPhone (1242×2688) — required if you support older devices.
- 13" iPad (2064×2752) — required only if the app is offered on iPad.
- App icon is taken from the binary; nothing to upload.

Captions can be burned into the image (common for games and usually converts
better) or left off. If you burn them in, keep the text in the top third — the
store UI can crop the bottom in some placements.

---

## Category

**Google Play**
- Category: **Games → Puzzle**
- Tags: Puzzle, Casual, Brain Games, Offline

**App Store**
- Primary: **Games → Puzzle**
- Secondary: **Games → Casual**

---

## Age rating

The game contains no violence, no sexual content, no profanity, no gambling,
no user-generated content and no social features. It does contain advertising
and in-app purchases, which both stores treat as disclosures rather than
content ratings.

**Expected outcomes**

| Board | Rating |
| --- | --- |
| Apple | 4+ |
| Google Play / IARC | Everyone (ESRB), PEGI 3, USK 0 |

**Answer honestly on the questionnaires:**

- Does the app contain ads? **Yes** — rewarded and interstitial.
- Does the app contain in-app purchases? **Yes.**
- Does the app share user data? **No.**
- Does the app collect personal information? **No.**
- Does the app contain user-generated content? **No.**
- Does the app contain gambling or simulated gambling? **No.** Chests award
  cosmetic-free in-game currency and boosters, cost no real money directly, and
  cannot be bought as loot boxes. If you later sell chests for money, this
  answer changes and some territories will require odds disclosure.

**Data safety / App Privacy:** as shipped, the app collects nothing — no
account, no analytics SDK, no advertising identifier. **This changes the moment
you enable AdMob**, which collects device and advertising identifiers for ad
personalisation. Update both forms when you turn ads on, and make sure your
privacy policy covers it. Getting this wrong is one of the most common reasons
for rejection.

---

## What is deliberately not claimed

Do not add these to the copy — they are not in the build:

- Leaderboards or any comparison against other players
- Cloud save, or progress that survives switching device
- Multiplayer, friends or social features
- A specific level count (the puzzle is endless, not levelled)
- Daily tournaments or events
- Any language other than English
