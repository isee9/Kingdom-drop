// The package here MUST match `namespace` in android/app/build.gradle.kts.
// AndroidManifest.xml declares the activity as ".MainActivity", which Android
// resolves relative to that namespace — so a mismatch is not a style problem,
// it is a ClassNotFoundException the moment the app launches. If you change the
// application ID, change this package and this file's folder path with it.
package com.yourcompany.kingdomdrop

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
