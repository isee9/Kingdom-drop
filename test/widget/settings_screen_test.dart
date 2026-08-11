import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/monetisation/consent_service.dart';
import 'package:kingdom_drop/screens/settings/settings_screen.dart';
import 'package:kingdom_drop/services/service_locator.dart';

import 'test_services.dart';

/// A consent gate whose answers the test controls.
class _StubConsent implements ConsentService {
  _StubConsent({
    this.privacyOptionsRequired = false,
    this.result = PrivacyOptionsResult.shown,
  });

  @override
  final bool privacyOptionsRequired;

  final PrivacyOptionsResult result;

  int showCount = 0;

  @override
  bool get canRequestAds => true;

  @override
  Future<void> gather() async {}

  @override
  Future<PrivacyOptionsResult> showPrivacyOptions() async {
    showCount++;
    return result;
  }
}

void main() {
  setUp(TestWidgetsFlutterBinding.ensureInitialized);

  Future<AppServices> pumpSettings(
    WidgetTester tester, {
    ConsentService? consent,
  }) async {
    final AppServices services = createTestServices(consent: consent);
    await tester.pumpWidget(
      wrapForTest(child: const SettingsScreen(), services: services),
    );
    await tester.pump();
    return services;
  }

  group('Privacy choices row', () {
    testWidgets('is hidden when UMP does not require it', (
      WidgetTester tester,
    ) async {
      // The common case: outside the EEA, the UK and Switzerland there is no
      // privacy options form, so an entry point would lead nowhere.
      await pumpSettings(tester, consent: _StubConsent());

      expect(find.text('Privacy choices'), findsNothing);
    });

    testWidgets('is shown when UMP requires it', (WidgetTester tester) async {
      await pumpSettings(
        tester,
        consent: _StubConsent(privacyOptionsRequired: true),
      );

      expect(find.text('Privacy choices'), findsOneWidget);
    });

    testWidgets('opens the UMP form when tapped', (WidgetTester tester) async {
      final _StubConsent consent = _StubConsent(privacyOptionsRequired: true);
      await pumpSettings(tester, consent: consent);

      await tester.tap(find.text('Privacy choices'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(consent.showCount, 1);
    });

    testWidgets('explains itself when the form cannot be shown', (
      WidgetTester tester,
    ) async {
      // A failure here must not look like a dead button.
      await pumpSettings(
        tester,
        consent: _StubConsent(
          privacyOptionsRequired: true,
          result: PrivacyOptionsResult.failed,
        ),
      );

      await tester.tap(find.text('Privacy choices'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('Privacy choices are unavailable'),
        findsOneWidget,
      );
    });
  });

  group('The existing About rows', () {
    testWidgets('survive alongside the new one', (WidgetTester tester) async {
      // AppConfig's legal URLs are blank in this build, so the screen shows its
      // placeholder instead. The point of the test is that adding the consent
      // row did not displace that behaviour.
      await pumpSettings(
        tester,
        consent: _StubConsent(privacyOptionsRequired: true),
      );

      expect(find.text('Privacy choices'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(
        find.textContaining('Privacy, terms and support links appear here'),
        findsOneWidget,
      );
    });
  });
}
