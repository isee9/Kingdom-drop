import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
// Chosen at compile time: the io version returns the UMP-backed service on
// Android and iOS, the stub returns null everywhere else. Same seam the ad and
// purchase services use, and the reason google_mobile_ads never reaches the
// browser or desktop build.
import 'live_services_stub.dart' if (dart.library.io) 'live_services_io.dart';

/// What happened when the privacy options form was asked for.
enum PrivacyOptionsResult {
  /// The form was presented and the player dismissed it.
  shown,

  /// There is no form to show on this build or in this region.
  unavailable,

  /// The platform reported an error.
  failed,
}

/// The consent gate in front of advertising.
///
/// Google's User Messaging Platform decides, per region, whether a player has
/// to be asked before any ad request is made. In the EEA, the UK and
/// Switzerland they do; almost everywhere else they do not. This wraps that
/// decision so the rest of the app only ever has to ask one question:
/// [canRequestAds].
///
/// The important invariant is that **nothing touches the ad SDK until
/// [gather] has completed and [canRequestAds] is true.** Initialising Google
/// Mobile Ads is itself an ad-related data operation, so it is gated too, not
/// just the individual ad loads.
abstract interface class ConsentService {
  /// Refreshes consent state and, if the region requires it, shows the form.
  ///
  /// Called once per launch, before ads are initialised. Never throws: a
  /// network failure or a platform error leaves the player with a game and no
  /// ads, which is the safe direction to fail in.
  Future<void> gather();

  /// True when the ad SDK may be initialised and asked for ads.
  ///
  /// Read *after* [gather]. Note this is not the same as "the player accepted
  /// personalised ads" — UMP also returns true when the player declined
  /// personalisation but non-personalised ads are still permitted. Google
  /// decides which of the two to serve; the app does not, and must not try to.
  bool get canRequestAds;

  /// True when the store rules require a permanent, reachable control that
  /// reopens the consent form.
  ///
  /// Only ever true in regions that mandate it. Where it is false, showing a
  /// "Privacy choices" row would open a form that does not exist.
  bool get privacyOptionsRequired;

  /// Reopens the UMP privacy options form, so a player can change their mind.
  Future<PrivacyOptionsResult> showPrivacyOptions();
}

/// The consent service for every build that has no UMP to consult.
///
/// Used when ads are compiled out, and on platforms with no Google Mobile Ads
/// at all — the browser build, desktop. It reports that ads may be requested,
/// which sounds alarming and is not: in every case this is selected, there is
/// no ad SDK present to request anything. Nothing here talks to a network or a
/// platform channel, which is also what lets the widget tests use it.
class PermissiveConsentService implements ConsentService {
  const PermissiveConsentService();

  @override
  Future<void> gather() async {}

  @override
  bool get canRequestAds => true;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<PrivacyOptionsResult> showPrivacyOptions() async =>
      PrivacyOptionsResult.unavailable;
}

/// Builds the consent service for this build.
///
/// With `ADS_ENABLED=false` this is always the permissive one: no consent
/// request is made, no form can appear, and UMP is entirely out of the way —
/// which is the whole point of the flag. Live UMP only runs when ads are on
/// *and* the platform supports them.
ConsentService createConsentService() {
  if (AppConfig.adsEnabled) {
    final ConsentService? live = createLiveConsentService();
    if (live != null) return live;
  }
  debugPrint('[consent] ads are off — UMP is not consulted');
  return const PermissiveConsentService();
}
