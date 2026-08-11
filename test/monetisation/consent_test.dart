import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kingdom_drop/monetisation/consent_service.dart';
import 'package:kingdom_drop/monetisation/ump_consent_service.dart';

/// Tests for the UMP consent gate.
///
/// The happy path barely needs testing — it is four sequential calls. What
/// needs testing is everything that goes wrong, because the consequences are
/// asymmetric: fail one way and the game is briefly ad-free, fail the other
/// and it requests ads for a player who was never asked. Every test below is
/// about which way a given failure falls.
class FakeUmpGateway implements UmpGateway {
  FakeUmpGateway({
    this.updateError,
    this.updateDelay = Duration.zero,
    this.formError,
    this.formThrows = false,
    this.canRequestAdsResult = true,
    this.canRequestAdsThrows = false,
    this.privacyStatus = PrivacyOptionsRequirementStatus.notRequired,
    this.privacyStatusThrows = false,
    this.privacyFormError,
    this.privacyFormThrows = false,
  });

  Object? updateError;
  Duration updateDelay;
  FormError? formError;
  bool formThrows;
  bool canRequestAdsResult;
  bool canRequestAdsThrows;
  PrivacyOptionsRequirementStatus privacyStatus;
  bool privacyStatusThrows;
  FormError? privacyFormError;
  bool privacyFormThrows;

  /// Call log, so ordering can be asserted rather than assumed.
  final List<String> calls = <String>[];

  @override
  Future<void> requestConsentInfoUpdate() async {
    calls.add('update');
    if (updateDelay > Duration.zero) await Future<void>.delayed(updateDelay);
    if (updateError != null) throw updateError!;
  }

  @override
  Future<FormError?> loadAndShowConsentFormIfRequired() async {
    calls.add('form');
    if (formThrows) throw StateError('form blew up');
    return formError;
  }

  @override
  Future<bool> canRequestAds() async {
    calls.add('canRequestAds');
    if (canRequestAdsThrows) throw StateError('channel gone');
    return canRequestAdsResult;
  }

  @override
  Future<PrivacyOptionsRequirementStatus>
  privacyOptionsRequirementStatus() async {
    calls.add('privacyStatus');
    if (privacyStatusThrows) throw StateError('channel gone');
    return privacyStatus;
  }

  @override
  Future<FormError?> showPrivacyOptionsForm() async {
    calls.add('showPrivacyOptions');
    if (privacyFormThrows) throw StateError('form blew up');
    return privacyFormError;
  }
}

void main() {
  group('The happy path', () {
    test('asks in the order Google requires', () async {
      final FakeUmpGateway ump = FakeUmpGateway();
      await UmpConsentService(gateway: ump).gather();

      // Update, then form, then read the result. Reading canRequestAds before
      // the form would answer the question the player has not been asked yet.
      expect(ump.calls, <String>[
        'update',
        'form',
        'canRequestAds',
        'privacyStatus',
      ]);
    });

    test('opens the gate when UMP permits ads', () async {
      final UmpConsentService consent = UmpConsentService(
        gateway: FakeUmpGateway(canRequestAdsResult: true),
      );
      await consent.gather();

      expect(consent.canRequestAds, isTrue);
    });

    test('keeps the gate shut when UMP refuses', () async {
      final UmpConsentService consent = UmpConsentService(
        gateway: FakeUmpGateway(canRequestAdsResult: false),
      );
      await consent.gather();

      expect(consent.canRequestAds, isFalse);
    });

    test('starts shut, before anything has been gathered', () {
      // Matters because the ad service reads this synchronously. A default of
      // true would open a window where ads could be requested unasked.
      expect(
        UmpConsentService(gateway: FakeUmpGateway()).canRequestAds,
        isFalse,
      );
    });
  });

  group('When the network or the platform misbehaves', () {
    test('a failed info update still consults the cached answer', () async {
      // The deliberate exception to failing closed: UMP caches consent across
      // sessions, so a player who consented yesterday and opened the app on a
      // train today should still see ads.
      final FakeUmpGateway ump = FakeUmpGateway(
        updateError: FormError(errorCode: 1, message: 'no network'),
        canRequestAdsResult: true,
      );
      final UmpConsentService consent = UmpConsentService(gateway: ump);

      await consent.gather();

      expect(consent.canRequestAds, isTrue);
      expect(ump.calls, contains('canRequestAds'));
    });

    test(
      'a slow info update times out instead of hanging the launch',
      () async {
        final UmpConsentService consent = UmpConsentService(
          gateway: FakeUmpGateway(updateDelay: const Duration(seconds: 30)),
          updateTimeout: const Duration(milliseconds: 40),
        );

        await consent.gather().timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail('gather() hung past its own timeout'),
        );

        expect(
          consent.canRequestAds,
          isTrue,
          reason: 'the cached status is still read after a timeout',
        );
      },
    );

    test('a form error does not stop the status being read', () async {
      final FakeUmpGateway ump = FakeUmpGateway(
        formError: FormError(errorCode: 3, message: 'form unavailable'),
        canRequestAdsResult: false,
      );
      final UmpConsentService consent = UmpConsentService(gateway: ump);

      await consent.gather();

      expect(ump.calls, contains('canRequestAds'));
      expect(consent.canRequestAds, isFalse);
    });

    test('a thrown form is caught rather than crashing the game', () async {
      final UmpConsentService consent = UmpConsentService(
        gateway: FakeUmpGateway(formThrows: true),
      );

      await expectLater(consent.gather(), completes);
    });

    test('an unreadable canRequestAds falls closed', () async {
      // The single most important assertion here. If the platform channel is
      // unreachable we cannot know whether the player consented, and the only
      // safe assumption is that they did not.
      final UmpConsentService consent = UmpConsentService(
        gateway: FakeUmpGateway(canRequestAdsThrows: true),
      );

      await consent.gather();

      expect(consent.canRequestAds, isFalse);
    });

    test('an unreadable privacy status hides the button', () async {
      // Showing an entry point to a form that may not exist is worse than
      // omitting it, so this one falls closed too.
      final UmpConsentService consent = UmpConsentService(
        gateway: FakeUmpGateway(privacyStatusThrows: true),
      );

      await consent.gather();

      expect(consent.privacyOptionsRequired, isFalse);
    });
  });

  group('Privacy options', () {
    test('are required only when UMP says so', () async {
      final UmpConsentService required = UmpConsentService(
        gateway: FakeUmpGateway(
          privacyStatus: PrivacyOptionsRequirementStatus.required,
        ),
      );
      await required.gather();
      expect(required.privacyOptionsRequired, isTrue);

      for (final PrivacyOptionsRequirementStatus status
          in <PrivacyOptionsRequirementStatus>[
            PrivacyOptionsRequirementStatus.notRequired,
            PrivacyOptionsRequirementStatus.unknown,
          ]) {
        final UmpConsentService consent = UmpConsentService(
          gateway: FakeUmpGateway(privacyStatus: status),
        );
        await consent.gather();
        expect(consent.privacyOptionsRequired, isFalse, reason: '$status');
      }
    });

    test('re-read the gate after the form closes', () async {
      // A player can revoke consent in that form. If the flags were not
      // re-read, the app would keep serving ads for the rest of the session.
      final FakeUmpGateway ump = FakeUmpGateway(canRequestAdsResult: true);
      final UmpConsentService consent = UmpConsentService(gateway: ump);
      await consent.gather();
      expect(consent.canRequestAds, isTrue);

      ump.canRequestAdsResult = false;
      final PrivacyOptionsResult result = await consent.showPrivacyOptions();

      expect(result, PrivacyOptionsResult.shown);
      expect(consent.canRequestAds, isFalse);
    });

    test('report failure when the form errors', () async {
      final UmpConsentService consent = UmpConsentService(
        gateway: FakeUmpGateway(
          privacyFormError: FormError(errorCode: 2, message: 'nope'),
        ),
      );

      expect(await consent.showPrivacyOptions(), PrivacyOptionsResult.failed);
    });

    test('report failure when the form throws', () async {
      final UmpConsentService consent = UmpConsentService(
        gateway: FakeUmpGateway(privacyFormThrows: true),
      );

      expect(await consent.showPrivacyOptions(), PrivacyOptionsResult.failed);
    });
  });

  group('Concurrency', () {
    test('two gathers in flight only show the form once', () async {
      // Two callers racing would otherwise put two consent forms on screen.
      final FakeUmpGateway ump = FakeUmpGateway(
        updateDelay: const Duration(milliseconds: 30),
      );
      final UmpConsentService consent = UmpConsentService(gateway: ump);

      await Future.wait(<Future<void>>[consent.gather(), consent.gather()]);

      expect(ump.calls.where((String c) => c == 'form').length, 1);
    });

    test('a later gather runs again, because consent can change', () async {
      final FakeUmpGateway ump = FakeUmpGateway();
      final UmpConsentService consent = UmpConsentService(gateway: ump);

      await consent.gather();
      await consent.gather();

      expect(ump.calls.where((String c) => c == 'update').length, 2);
    });
  });

  group('With ads compiled out', () {
    test('the permissive gate touches no platform channel', () async {
      // What a build with ADS_ENABLED=false gets, and what the widget tests
      // use. It must never reach for UMP, because there is nothing there.
      const PermissiveConsentService consent = PermissiveConsentService();

      await expectLater(consent.gather(), completes);
      expect(consent.canRequestAds, isTrue);
      expect(consent.privacyOptionsRequired, isFalse);
      expect(
        await consent.showPrivacyOptions(),
        PrivacyOptionsResult.unavailable,
      );
    });

    test('createConsentService returns the permissive gate', () {
      // AppConfig.adsEnabled is a compile-time constant and is false in tests,
      // so this pins the "ads off means UMP stays out of the way" contract.
      expect(createConsentService(), isA<PermissiveConsentService>());
    });
  });
}
