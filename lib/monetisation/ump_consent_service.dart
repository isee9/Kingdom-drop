import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'consent_service.dart';

/// The four UMP calls this app makes, behind an interface.
///
/// [ConsentInformation] and [ConsentForm] are static singletons that go
/// straight to a platform channel, so code written against them directly can
/// only be tested on a device. This is the seam that makes the sequencing and —
/// far more importantly — the failure handling testable on the VM.
abstract interface class UmpGateway {
  /// Wraps the callback-style `requestConsentInfoUpdate`. Completes normally on
  /// success and with a [FormError] on failure.
  Future<void> requestConsentInfoUpdate();

  /// Shows the consent form if this region and this player need it. Resolves to
  /// the error the platform reported, or null if all was well.
  Future<FormError?> loadAndShowConsentFormIfRequired();

  Future<bool> canRequestAds();

  Future<PrivacyOptionsRequirementStatus> privacyOptionsRequirementStatus();

  Future<FormError?> showPrivacyOptionsForm();
}

/// The real gateway, talking to the UMP SDK bundled with `google_mobile_ads`.
class PlatformUmpGateway implements UmpGateway {
  const PlatformUmpGateway();

  @override
  Future<void> requestConsentInfoUpdate() {
    final Completer<void> done = Completer<void>();

    // No tagForUnderAgeOfConsent: Kingdom Drop is listed for a general adult
    // audience, and claiming otherwise here would put the app under Families
    // Policy rules it is not built for. No ConsentDebugSettings either — those
    // force a fake geography and must never ship.
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!done.isCompleted) done.complete();
      },
      (FormError error) {
        if (!done.isCompleted) done.completeError(error);
      },
    );

    return done.future;
  }

  @override
  Future<FormError?> loadAndShowConsentFormIfRequired() {
    final Completer<FormError?> done = Completer<FormError?>();
    ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
      if (!done.isCompleted) done.complete(error);
    });
    return done.future;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<PrivacyOptionsRequirementStatus> privacyOptionsRequirementStatus() =>
      ConsentInformation.instance.getPrivacyOptionsRequirementStatus();

  @override
  Future<FormError?> showPrivacyOptionsForm() {
    final Completer<FormError?> done = Completer<FormError?>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (!done.isCompleted) done.complete(error);
    });
    return done.future;
  }
}

/// [ConsentService] backed by Google's User Messaging Platform.
///
/// The sequence per launch is fixed by Google and this follows it exactly:
/// request a consent info update, then load and show the form if it is
/// required, then read `canRequestAds`. Only then may the ad SDK be touched.
///
/// Everything here **fails closed**. If the update call errors, if the form
/// errors, if the network is down — the outcome is a game with no ads, never a
/// crash and never an ad request the player has not permitted. The one
/// deliberate exception is that a failed update still reads `canRequestAds`,
/// because UMP caches the previous session's answer: a player who consented
/// yesterday and opened the app on a train today should still see ads.
class UmpConsentService implements ConsentService {
  UmpConsentService({
    UmpGateway gateway = const PlatformUmpGateway(),
    this.updateTimeout = const Duration(seconds: 12),
  }) : _ump = gateway;

  final UmpGateway _ump;

  /// How long to wait for the consent info update before giving up on it.
  ///
  /// This is a network call made during app start. Without a bound, a captive
  /// portal or a dead connection would hold the splash screen indefinitely.
  /// Giving up here is safe: the cached status is read afterwards either way.
  final Duration updateTimeout;

  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;

  /// Guards against a second [gather] racing the first, which would show the
  /// form twice.
  Future<void>? _inFlight;

  @override
  bool get canRequestAds => _canRequestAds;

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<void> gather() {
    return _inFlight ??= _gather().whenComplete(() => _inFlight = null);
  }

  Future<void> _gather() async {
    try {
      await _ump.requestConsentInfoUpdate().timeout(updateTimeout);
    } on TimeoutException {
      debugPrint('[consent] info update timed out — using the cached status');
    } catch (error) {
      // FormError, or anything else the platform threw.
      debugPrint('[consent] info update failed: $error');
    }

    try {
      final FormError? error = await _ump.loadAndShowConsentFormIfRequired();
      if (error != null) {
        debugPrint('[consent] form error ${error.errorCode}: ${error.message}');
      }
    } catch (error) {
      debugPrint('[consent] form failed: $error');
    }

    await _refreshStatus();
  }

  /// Re-reads both flags from UMP. Either failing leaves ads switched off.
  Future<void> _refreshStatus() async {
    try {
      _canRequestAds = await _ump.canRequestAds();
    } catch (error) {
      debugPrint('[consent] canRequestAds failed, treating as no: $error');
      _canRequestAds = false;
    }

    try {
      _privacyOptionsRequired =
          await _ump.privacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (error) {
      debugPrint('[consent] privacy options status failed: $error');
      _privacyOptionsRequired = false;
    }

    debugPrint(
      '[consent] canRequestAds=$_canRequestAds '
      'privacyOptionsRequired=$_privacyOptionsRequired',
    );
  }

  @override
  Future<PrivacyOptionsResult> showPrivacyOptions() async {
    FormError? error;
    try {
      error = await _ump.showPrivacyOptionsForm();
    } catch (thrown) {
      debugPrint('[consent] privacy options form failed: $thrown');
      return PrivacyOptionsResult.failed;
    }

    // The player may have just granted or revoked consent, so both flags have
    // to be re-read before the caller decides what to do about ads.
    await _refreshStatus();

    if (error != null) {
      debugPrint(
        '[consent] privacy options error ${error.errorCode}: ${error.message}',
      );
      return PrivacyOptionsResult.failed;
    }
    return PrivacyOptionsResult.shown;
  }
}
