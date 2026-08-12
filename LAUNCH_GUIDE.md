# Getting Kingdom Drop onto the Google Play Store

This guide assumes you have never published an app before. It explains what
every step is *for*, not just what to click, because the reason usually tells
you what to do when a screen looks slightly different from the one described
here.

Work through it in order. **Nothing here is optional except Part 7 (money).**

> **The one thing to be careful about:** in Part 2 you create a file called a
> *keystore*. If you lose it you can never update your app again — not "it's
> difficult", it is genuinely impossible, and you would have to publish a new
> app under a new name and lose all your users. Back it up in two places before
> you go any further. Everything else on this page is fixable.

---

## What is already done

You do not need to do any of this — it is finished and in the repository.

- The game itself: rules, screens, art, sound, saving, progression.
- App icons at every size Android and iOS ask for.
- Store listing text (`STORE_LISTING.md`) and graphics (`store/`).
- The code for real ads and real in-app purchases. It is switched **off** and
  waits for your accounts.
- 228 automated tests, all passing.

## What only you can do

Anything that needs your identity, your bank account, or a decision about your
business. That is Parts 1–8 below.

---

## Part 1 — Get a computer set up (about an hour, mostly waiting)

You need a computer that can build Android apps. Windows, Mac or Linux all
work.

**1.1 Install Flutter.** Follow <https://docs.flutter.dev/get-started/install>
and pick your operating system. Flutter is the toolkit the game is written in.

**1.2 Install Android Studio.** The Flutter page links to it. You are not going
to write code in it — you need it because it installs the *Android SDK*, which
is the set of tools that turns the project into an installable app.

**1.3 Accept the licences.** Open a terminal (Command Prompt on Windows,
Terminal on Mac) and run:

```
flutter doctor --android-licenses
```

Press `y` at each prompt. Then run:

```
flutter doctor
```

You want a tick next to "Flutter" and a tick next to "Android toolchain". A
cross next to Xcode is fine unless you are also publishing to the iPhone App
Store. A cross next to Chrome is fine.

**1.4 Get the project and check it runs.** Download the repository, open a
terminal *inside the project folder*, and run:

```
flutter pub get
flutter test
```

You should see `All tests passed!`. If you do, the project is healthy on your
machine.

> **Note:** this has never been built for Android in the environment the game
> was developed in — that machine could not reach Google's servers to download
> the Android SDK. Everything is configured for it, but you are the first
> person to run it. If `flutter build appbundle --release` fails in Part 4, that
> is where it will show up, and the error message will name the problem.

---

## Part 2 — Create your signing key (15 minutes) ⚠️

Google will not accept an app unless it is *signed* — stamped with a private
key that proves later updates come from the same person. You create that key
once and keep it forever.

**2.1 Create the key.** In a terminal, run this as a single command. Change
`~/kingdom-drop-key.jks` if you want it somewhere else.

On Mac or Linux:

```
keytool -genkey -v -keystore ~/kingdom-drop-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

On Windows (Command Prompt):

```
keytool -genkey -v -keystore %USERPROFILE%\kingdom-drop-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

It asks for a password (choose a strong one and write it down), then your name,
organisation and country. Those answers are not shown to anyone; they are
recorded inside the key.

**2.2 Back it up.** Copy `kingdom-drop-key.jks` and the password to two places
that are not this computer — a password manager and an encrypted cloud folder,
for example. **Do not put it in the project folder and do not commit it to
GitHub.**

**2.3 Tell the project where it is.** Create a new file at
`android/key.properties` containing four lines:

```
storePassword=the password you chose
keyPassword=the same password
keyAlias=upload
storeFile=/full/path/to/kingdom-drop-key.jks
```

On Windows the path uses forward slashes: `C:/Users/you/kingdom-drop-key.jks`.

This file is already in `.gitignore`, so it will not be uploaded anywhere by
accident.

> **How to tell it worked:** when you build in Part 4, you should *not* see the
> warning `key.properties not found — release builds will be signed with the
> DEBUG key`. If you see that warning, the path in `storeFile` is wrong.

---

## Part 3 — Choose your app's permanent ID (10 minutes) ⚠️

Every Android app has an ID like `com.mycompany.kingdomdrop`. It is never shown
to players, but it is **permanent** — once you upload an app with an ID, that ID
is yours forever and can never be changed for that app.

Convention is a domain you own, reversed. If you own `sutherlandgames.co.uk`,
use `uk.co.sutherlandgames.kingdomdrop`. If you own no domain, something unique
like `com.rsutheran.kingdomdrop` is fine.

Right now the project uses the placeholder `com.yourcompany.kingdomdrop`.
Change it in these four places:

| File | What to change |
| --- | --- |
| `android/app/build.gradle.kts` | `namespace = "..."` and `applicationId = "..."` |
| `lib/core/config/app_config.dart` | `bundleId` |
| `android/app/src/main/kotlin/com/yourcompany/kingdomdrop/MainActivity.kt` | the `package` line, **and** the folder path must match it |
| iOS only — `ios/Runner.xcodeproj` | `PRODUCT_BUNDLE_IDENTIFIER` (three places; Xcode's find-and-replace handles it) |

Also move the `MainActivity.kt` file so its folder path matches the new package
name. If that sounds fiddly, it is — search the web for "Flutter change package
name" and use the `change_app_package_name` tool, which does all of the above
in one command.

---

## Part 4 — Build the app (10 minutes)

Google Play wants a file called an **App Bundle** (`.aab`). Build it:

```
flutter build appbundle --release
```

If it succeeds you will find the file at
`build/app/outputs/bundle/release/app-release.aab`. That single file is what you
upload.

**Test it on a real phone first — always.** A release build is not the same
program as the one you have been running. It is shrunk and obfuscated by a tool
called R8, which debug builds skip entirely, and that alone has already made
this app crash on launch once while every test and every debug run stayed
green. Nothing catches that except starting a real release build on a real
phone.

There is a script that does the whole check for you. Plug the phone in, then:

```
powershell -ExecutionPolicy Bypass -File tool\release_smoke_test.ps1
```

It builds the release APK, installs it fresh, launches it, and tells you plainly
whether the app crashed, died quietly, or never reached its first screen. Run it
**before every upload**.

If it passes, **play a few rounds** by hand. Check that sound works, that the
shop opens, and that closing and reopening the app keeps your progress. The
script only proves the app starts, not that it is any good.

---

## Part 5 — Legal bits you must write (1–2 hours)

Google requires these before your listing can go live. There is no way around
them.

**5.1 A privacy policy, on a public web page.** It must say what data the app
collects. Kingdom Drop is unusually simple here: it has no accounts, no login,
no analytics service and no servers — everything stays on the player's phone.
If you turn ads on, Google's ad system does collect an advertising identifier,
and your policy must say so.

Free generators exist (search "app privacy policy generator"); a free GitHub
Pages site or a Notion page is enough to host it. Once it has a web address, put
that address in `lib/core/config/app_config.dart` as `privacyPolicyUrl`.

**5.2 A support contact.** An email address is enough. Put it in the same file
as `supportEmail`.

> The Settings screen currently hides its Privacy and Support rows because
> those fields are blank. Fill them in and the rows appear automatically.

---

## Part 6 — Set up Google Play (2–3 hours, plus waiting)

**6.1 Create a developer account** at
<https://play.google.com/console>. It costs a one-off **$25**. Google will
verify your identity, which can take a couple of days — start this early.

**6.2 Create the app.** In the Console: *Create app*. Give it the name
**Kingdom Drop**, choose *Game*, choose *Free*, and confirm it follows the
policies.

**6.3 Fill in the listing.** Everything you need is already written:

- **Short and full description** — copy from `STORE_LISTING.md`.
- **App icon** — upload `store/app_icon_512.png`.
- **Feature graphic** — upload `store/feature_graphic.png`.
- **Phone screenshots** — upload all six from `store/screenshots/`, in
  filename order.
- **Category** — Games → Puzzle.

**6.4 Answer the questionnaires.** Play will not let you publish until these
are done. They are forms, not tasks — you just answer honestly:

- **Content rating.** Say there is no violence, no sexual content, no gambling.
  Kingdom Drop should come out rated for everyone.
- **Target audience.** Choose an adult age bracket. Do **not** aim it at
  children — it triggers a much stricter set of rules called Families Policy,
  and the ad rules change too.
- **Data safety.** This is the one people get wrong. With ads switched off, the
  app collects nothing: no data collected, no data shared. With ads on, you must
  declare that an advertising ID is collected for advertising. Google's own
  AdMob help page tells you exactly which boxes to tick.
- **Ads declaration.** Say whether the app contains ads. Answer truthfully for
  the build you actually upload.

**6.5 Upload to a test track first — do not publish straight to production.**
In the Console, go to *Testing → Internal testing*, create a release, upload the
`.aab`, and add your own email as a tester. You get a link that installs the app
from the Play Store onto your phone.

Why bother: this is the only way to test in-app purchases (Part 7), and it is
your chance to spot a mistake before strangers see it.

**6.6 Then promote to production.** When you are happy, create a production
release with the same bundle. The first review usually takes a few days.

---

## Part 7 — Money (optional, but decide before you publish) ⚠️

**Read this even if you skip the rest of the part.**

Right now the game's shop is in *practice mode*. It shows prices like "£1.99",
and when tapped it hands over the coins **without charging anything**. That is
correct for development and wrong to publish: it earns nothing, and a shop that
displays a price and then does not charge could reasonably be called
misleading.

So you must pick one of these two before you go to production.

### Option A — Launch free, no shop, no ads

Simplest by a distance, and a perfectly normal way to launch a first game.
Nothing to configure: just do not turn ads or billing on. The shop is still in
the app though, so ask for the shop button to be removed before you publish.

### Option B — Launch with purchases and ads

More work, and it needs a bank account attached to both Google and AdMob.

**7.1 Set up payments.** In Play Console, add a payments profile with your bank
and tax details. Google will not show any product until this is complete.

**7.2 Create the products.** Play Console → *Monetise → In-app products*. Create
these seven, with these exact IDs — the app looks for them by name and will
show nothing if an ID is misspelled:

| Product ID | Type | Suggested price |
| --- | --- | --- |
| `coins_500` | Consumable | £0.99 |
| `coins_1200` | Consumable | £1.99 |
| `coins_3000` | Consumable | £3.99 |
| `coins_8000` | Consumable | £7.99 |
| `coins_25000` | Consumable | £19.99 |
| `starter_pack` | Non-consumable | £1.99 |
| `remove_ads` | Non-consumable | £3.99 |

"Consumable" means it can be bought over and over (coins). "Non-consumable"
means it is bought once and kept forever. Activate each one.

**7.3 Set up ads.** Create a free AdMob account at
<https://admob.google.com>, add Kingdom Drop as an app, and create two ad units:
one **rewarded** and one **interstitial**. AdMob gives you an *app ID* (with a
`~` in it) and an *ad unit ID* for each (with a `/`).

Put the app ID into two files, replacing the sample values already there. Both
files have a `CHANGE ME` comment marking the spot:

- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`

**7.3b Publish your consent message.** In AdMob, go to **Privacy & messaging →
European regulations** and publish a message targeting the EEA, the UK and
Switzerland. This is a legal requirement, not a nicety: in those regions you may
not request an ad until the player has been asked.

The app already does its half. On every launch it asks Google whether this
player needs to be asked, shows your message if so, and refuses to start the ad
system at all until Google says it may. If a player declines, they still get the
game — just no ads. And in the regions that require it, a **Privacy choices**
row appears in Settings by itself so they can change their mind later.

Nothing to configure for any of that. But if you never publish the message,
players in Europe see no ads at all, and you will spend a while wondering why.

**7.4 Build with money switched on.** The ad unit IDs are *not* stored in the
project — they are passed in when you build, so they never end up on GitHub:

```
flutter build appbundle --release \
  --dart-define=BILLING_ENABLED=true \
  --dart-define=ADS_ENABLED=true \
  --dart-define=ADMOB_REWARDED_ANDROID=your-rewarded-unit-id \
  --dart-define=ADMOB_INTERSTITIAL_ANDROID=your-interstitial-unit-id
```

(On Windows Command Prompt, put it all on one line and drop the `\` marks.)

**7.5 Test the purchases for real.** Purchases only work through a build
installed *from Play*, never one copied across by hand — so upload this bundle
to your internal test track and install it from the tester link. Add your own
email under *Setup → License testing* in Play Console and your test purchases
will not be charged.

Buy one coin pack and check the coins arrive. Buy Remove Ads, delete the app,
reinstall it, and press *Restore purchases* in Settings — the entitlement should
come back. If it does, billing is working.

---

## Part 8 — After you press publish

- **Watch the crash reports.** Play Console → *Quality → Android vitals*. If
  crashes appear on a particular phone model, that is where you will see it.
- **Reply to reviews.** Early reviews carry a lot of weight.
- **Every update needs a new build number.** Open `pubspec.yaml` and change
  `version: 1.0.0+2` to `+3`, then `+4`, and so on. Google rejects an upload
  that reuses a number — including replacing a build that crashed. The part
  before the `+` is what players see; the part after it is just a counter.

---

## Quick reference

| I want to… | Do this |
| --- | --- |
| Check the project is healthy | `flutter test` |
| Build for Play | `flutter build appbundle --release` |
| Build to sideload onto a phone | `flutter build apk --release` |
| Play it in a browser right now | <https://isee9.github.io/Kingdom-drop/> |
| Change prices, rewards or costs | `lib/core/config/economy_config.dart` |
| Change the listing text | `STORE_LISTING.md` |
| Rebuild the store graphics | `python3 tool/generate_feature_graphic.py` |
| Rebuild the artwork or sound | `python3 tool/slice_art.py`, `python3 tool/generate_audio.py` |

## Realistic order and effort

1. Part 6.1 — start the developer account today; verification takes days.
2. Parts 1–4 — one focused evening.
3. Part 5 — one evening.
4. Part 7 — decide free or paid. Free adds nothing; paid adds a day.
5. Parts 6.5–6.6 — internal test for a few days, then production.

First review is usually a few days. Budget two weeks from starting to being
live, most of which is waiting rather than working.
