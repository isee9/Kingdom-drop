# Kingdom Drop ProGuard/R8 rules.
#
# The Flutter Gradle plugin already supplies the engine's own keep rules, so
# this file only needs to cover the plugins this app uses.

# audioplayers -> ExoPlayer/Media3 reflection.
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**

# Keep annotations used for reflection by plugins.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses

# Line numbers make Play Console crash reports readable. Renaming the source
# file to a placeholder keeps the obfuscation benefit.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---------------------------------------------------------------------------
# Google Mobile Ads and Play Billing. Both are reflected into by their SDKs, so
# R8 must not rename or strip them.
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

-keep class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**

# ---------------------------------------------------------------------------
# Room databases, for WorkManager's WorkDatabase.
#
# Room instantiates its generated implementation reflectively — it takes the
# database class name, appends "_Impl", looks the class up by name and calls the
# no-argument constructor. Nothing references that class statically, so under
# R8 full mode (default since AGP 8; this project is on AGP 9) it is a prime
# candidate for removal, and losing it produces a fatal crash at process start:
#
#     Unable to get provider androidx.startup.InitializationProvider
#     Caused by: Failed to create an instance of androidx.work.impl.WorkDatabase
#
# Current Room ships this exact rule as a consumer rule, so pinning
# androidx.work in app/build.gradle.kts should already cover it. It is repeated
# here deliberately: the crash only reproduces in a signed release build, the
# feedback loop for getting that wrong is a rejected upload, and the rule costs
# one constructor on one class hierarchy. Narrow on purpose — a subclass of one
# specific base, and a single member — not a package wildcard.
#
# Safe to delete once a release build has been verified without it.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
