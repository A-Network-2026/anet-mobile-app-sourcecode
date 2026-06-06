package com.anetwork.app

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		// Opt into edge-to-edge for Android 15 (SDK 35) compatibility.
		// Flutter's PlatformPlugin handles status/nav bar coloring internally; remaining
		// Play Console warnings about setStatusBarColor/setNavigationBarColor originate
		// inside the Flutter engine and resolve with future Flutter SDK upgrades.
		WindowCompat.setDecorFitsSystemWindows(window, false)
	}
}
