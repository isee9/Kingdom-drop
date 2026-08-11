import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/config/app_config.dart';
import '../core/utils/stage_log.dart';
import 'consent_service.dart';

/// The UMP calls this app makes, behind an interface.
///
/// [ConsentInformation] and [ConsentForm] are static singletons that go
/// straight to a platform channel, so code written against them directly can
/// only be tested on a device. This is the seam that makes the sequencing and —
/// far more importantly — the failure handling testable on the VM.
abstract interface class UmpGateway {
  /// Clears the stored consent state. Development only; see [AppConfig.umpReset].
  Future<void> reset();

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
  PlatformUmpGateway({StageLog? log}) : _log = log ?? StageLog('ump');

  final StageLog _log;

  /// Parameters for the consent request.
  ///
  /// No `tagForUnderAgeOfConsent`: Kingdom Drop is listed for a general adult
  /// audience, and claiming otherwise would put the app under Families Policy
  /// rules it is not built for.
  ///
  /// Debug settings are attached only when [AppConfig.umpDebug] is set at build
  /// time. They force the SDK to behave as though the device were in the EEA,
  /// which is the only way to see the consent form from outside it.
  ConsentRequestParameters _parameters() {
    if (!AppConfig.umpDebug) return ConsentRequestParameters();

    if (AppConfig.umpTestDeviceId.isEmpty) {
      // Worth shouting about: debug settings without a test identifier are
      // silently ignored by the SDK, so the form would not appear and the
      // reason would not be obvious.
      _log.stage('debug.WARNING', <String, Object?>{
        'reason': 'UMP_DEBUG is set but UMP_TEST_DEVICE_ID is empty',
        'effect': 'debug settings will be ignored by the SDK',
      });
    }

    _log.stage('debug.enabled', <String, Object?>{
      'geography': 'EEA',
      // Never the value itself: it is a device fingerprint and belongs in the
      // build command, not in a log someone might paste into an issue.
      'testDeviceId': AppConfig.umpTestDeviceId.isEmpty
          ? '<missing>'
          : '<supplied>',
    });

    return ConsentRequestParameters(
      consentDebugSettings: ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyEea,
        testIdentifiers: <String>[AppConfig.umpTestDeviceId],
      ),
    );
  }

  @override
  Future<void> reset() => ConsentInformation.instance.reset();

  @override
  Future<void> requestConsentInfoUpdate() {
    final Completer<void> done = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      _parameters(),
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
///
/// **Every await here is bounded.** A UMP callback that never fires is not
/// hypothetical — it has been observed on real hardware, where the form
/// reported `load_complete ok` and then never reported dismissal. Nothing in
/// this class may wait forever, and nothing in the app may wait on this class
/// to start; see `AppServices.startMonetisation`.
class UmpConsentService implements ConsentService {
  UmpConsentService({
    UmpGateway? gateway,
    StageLog? log,
    this.updateTimeout = const Duration(seconds: 12),
    this.formTimeout = const Duration(seconds: 60),
    this.gatherDeadline = const Duration(seconds: 90),
  }) : _log = log ?? StageLog('consent'),
       _ump = gateway ?? PlatformUmpGateway();

  final UmpGateway _ump;
  final StageLog _log;

  /// How long to wait for the consent info update. A network call made at
  /// startup; without a bound a captive portal holds it open indefinitely.
  final Duration updateTimeout;

  /// How long to wait for the form to be dismissed.
  ///
  /// Generous, because a real player is reading it. Its job is not to hurry
  /// anyone along — it is to notice when the form was never actually presented
  /// and the callback is never coming.
  final Duration formTimeout;

  /// Backstop around the whole sequence, in case a stage that is not supposed
  /// to be able to hang does.
  final Duration gatherDeadline;

  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;

  /// True once a gather has finished, however it finished. Lets callers tell
  /// "not asked yet" from "asked, and the answer was no".
  bool _resolved = false;

  bool get isResolved => _resolved;

  /// The deadline-wrapped future callers await. Cleared when the *inner*
  /// sequence finishes, not when the deadline trips, so a stuck gather is not
  /// restarted underneath itself.
  Future<void>? _inFlight;

  @override
  bool get canRequestAds => _canRequestAds;

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<void> gather() {
    final Future<void>? existing = _inFlight;
    if (existing != null) return existing;

    final Future<void> inner = _gather();
    inner.whenComplete(() => _inFlight = null);

    // The caller's view is bounded even if the inner sequence somehow is not.
    // The inner future keeps running; it just stops being anyone's problem.
    return _inFlight = inner.timeout(
      gatherDeadline,
      onTimeout: () => _log.stage('gather.DEADLINE', <String, Object?>{
        'after': gatherDeadline.inSeconds,
        'ads': 'stay disabled for this session',
      }),
    );
  }

  Future<void> _gather() async {
    _log.stage('gather.start', <String, Object?>{
      'umpDebug': AppConfig.umpDebug,
      'umpReset': AppConfig.umpResetAllowed,
    });

    if (AppConfig.umpResetAllowed) {
      try {
        await _ump.reset();
        _log.stage('reset.ok');
      } catch (error) {
        _log.stage('reset.failed', <String, Object?>{'error': error});
      }
    }

    _log.stage('update.begin');
    try {
      await _ump.requestConsentInfoUpdate().timeout(updateTimeout);
      _log.stage('update.ok');
    } on TimeoutException {
      _log.stage('update.TIMEOUT', <String, Object?>{
        'after': updateTimeout.inSeconds,
        'action': 'falling back to the cached status',
      });
    } catch (error) {
      _log.stage('update.failed', <String, Object?>{
        'error': error,
        'code': error is FormError ? error.errorCode : null,
      });
    }

    _log.stage('form.begin');
    try {
      final FormError? error = await _ump
          .loadAndShowConsentFormIfRequired()
          .timeout(formTimeout);
      if (error == null) {
        _log.stage('form.ok');
      } else {
        _log.stage('form.error', <String, Object?>{
          'code': error.errorCode,
          'message': error.message,
        });
      }
    } on TimeoutException {
      // The observed failure on real hardware. If this line appears, the form
      // never told us it was dismissed — the game carries on without ads.
      _log.stage('form.TIMEOUT', <String, Object?>{
        'after': formTimeout.inSeconds,
        'meaning': 'the form never reported dismissal',
      });
    } catch (error) {
      _log.stage('form.threw', <String, Object?>{'error': error});
    }

    await _refreshStatus();
    _resolved = true;
    _log.stage('gather.complete', <String, Object?>{
      'canRequestAds': _canRequestAds,
      'privacyOptionsRequired': _privacyOptionsRequired,
    });
  }

  /// Re-reads both flags from UMP. Either failing leaves ads switched off.
  Future<void> _refreshStatus() async {
    try {
      _canRequestAds = await _ump.canRequestAds().timeout(updateTimeout);
      _log.stage('canRequestAds', <String, Object?>{'value': _canRequestAds});
    } catch (error) {
      _log.stage('canRequestAds.failed', <String, Object?>{
        'error': error,
        'action': 'treating as NO',
      });
      _canRequestAds = false;
    }

    try {
      final PrivacyOptionsRequirementStatus status = await _ump
          .privacyOptionsRequirementStatus()
          .timeout(updateTimeout);
      _privacyOptionsRequired =
          status == PrivacyOptionsRequirementStatus.required;
      _log.stage('privacyOptions', <String, Object?>{'status': status.name});
    } catch (error) {
      _log.stage('privacyOptions.failed', <String, Object?>{'error': error});
      _privacyOptionsRequired = false;
    }
  }

  @override
  Future<PrivacyOptionsResult> showPrivacyOptions() async {
    _log.stage('privacyForm.begin');

    FormError? error;
    try {
      error = await _ump.showPrivacyOptionsForm().timeout(formTimeout);
    } on TimeoutException {
      _log.stage('privacyForm.TIMEOUT');
      return PrivacyOptionsResult.failed;
    } catch (thrown) {
      _log.stage('privacyForm.threw', <String, Object?>{'error': thrown});
      return PrivacyOptionsResult.failed;
    }

    // The player may have just granted or revoked consent, so both flags have
    // to be re-read before the caller decides what to do about ads.
    await _refreshStatus();

    if (error != null) {
      _log.stage('privacyForm.error', <String, Object?>{
        'code': error.errorCode,
        'message': error.message,
      });
      return PrivacyOptionsResult.failed;
    }

    _log.stage('privacyForm.ok');
    return PrivacyOptionsResult.shown;
  }
}
