import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingdom_drop/core/config/app_config.dart';
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
    /// Every distinct string the screen is currently showing.
    ///
    /// A set, because `StrokedText` legitimately renders the same string twice
    /// — once stroked, once filled.
    Set<String> visibleText(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((Text text) => text.data)
        .whereType<String>()
        .toSet();

    testWidgets('are untouched by adding the Privacy choices row', (
      WidgetTester tester,
    ) async {
      // Written as a diff between the two consent states rather than against a
      // list of expected labels, because which About rows appear depends on
      // which URLs the owner has filled into AppConfig — and filling them in is
      // a normal thing to have done. Asserting one particular configuration
      // makes this test fail for the wrong reason the moment Part 5 of the
      // launch guide is followed.
      //
      // Tall enough for the whole screen at once. Settings is a ListView, so on
      // a phone-sized surface the rows below the fold are never built, and the
      // extra row would push the last one out of the comparison and read as a
      // deletion.
      tester.view
        ..physicalSize = const Size(600, 2600)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpSettings(tester, consent: _StubConsent());
      final Set<String> before = visibleText(tester);

      await pumpSettings(
        tester,
        consent: _StubConsent(privacyOptionsRequired: true),
      );
      final Set<String> after = visibleText(tester);

      expect(
        after.difference(before),
        <String>{'Privacy choices'},
        reason: 'the consent row is the only thing the gate should add',
      );
      expect(
        before.difference(after),
        isEmpty,
        reason: 'and it should displace nothing',
      );
    });

    testWidgets('reflect whatever AppConfig is configured with', (
      WidgetTester tester,
    ) async {
      // Holds both before and after the owner supplies their real URLs.
      await pumpSettings(
        tester,
        consent: _StubConsent(privacyOptionsRequired: true),
      );

      expect(
        find.text('Privacy Policy'),
        AppConfig.privacyPolicyUrl.isEmpty ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Terms of Service'),
        AppConfig.termsOfServiceUrl.isEmpty ? findsNothing : findsOneWidget,
      );
      expect(
        find.text('Support'),
        AppConfig.supportUrl.isEmpty && AppConfig.supportEmail.isEmpty
            ? findsNothing
            : findsOneWidget,
      );

      // The placeholder is the fallback for a build with nothing configured at
      // all, and must disappear the moment anything is.
      final bool anythingConfigured =
          AppConfig.privacyPolicyUrl.isNotEmpty ||
          AppConfig.termsOfServiceUrl.isNotEmpty ||
          AppConfig.supportUrl.isNotEmpty ||
          AppConfig.supportEmail.isNotEmpty;
      expect(
        find.textContaining('Privacy, terms and support links appear here'),
        anythingConfigured ? findsNothing : findsOneWidget,
      );
    });

    testWidgets('keep the purchase controls', (WidgetTester tester) async {
      // Independent of any URL configuration, so it is asserted flatly.
      await pumpSettings(
        tester,
        consent: _StubConsent(privacyOptionsRequired: true),
      );

      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Privacy choices'), findsOneWidget);
    });
  });
}
