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
