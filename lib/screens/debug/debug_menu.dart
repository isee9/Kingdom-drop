import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../models/booster.dart';
import '../../monetisation/ad_service.dart';
import '../../monetisation/purchase_service.dart';
import '../../progression/chest_service.dart';
import '../../services/analytics_service.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/kd_card.dart';
import '../more/chest_sheet.dart';

/// Developer menu.
///
/// Reachable only when [AppConfig.debugMenuEnabled] is true, which is debug
/// builds plus a profile build started with `--dart-define=FORCE_DEBUG_MENU=true`
/// for capturing store screenshots. Release builds fold the flag to a constant
/// false and tree-shake the whole screen away.
Future<void> showDebugMenu(
  BuildContext context, {
  required AppServices services,
}) {
  assert(
    AppConfig.debugMenuEnabled,
    'The debug menu must never be reachable in a release build',
  );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _DebugMenu(services: services),
  );
}

class _DebugMenu extends StatefulWidget {
  const _DebugMenu({required this.services});

  final AppServices services;

  @override
  State<_DebugMenu> createState() => _DebugMenuState();
}

class _DebugMenuState extends State<_DebugMenu> {
  AppServices get _s => widget.services;

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final MockAdService? mockAds = _s.ads is MockAdService
        ? _s.ads as MockAdService
        : null;
    final MockPurchaseService? mockIap = _s.purchases is MockPurchaseService
        ? _s.purchases as MockPurchaseService
        : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.bug_report_rounded, color: AppColors.danger),
                  const SizedBox(width: AppSpacing.sm),
                  Text('DEVELOPER MENU', style: AppTextStyles.headline),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Debug builds only. Not compiled into release.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.lg),

              const KdSectionHeader(title: 'Currency'),
              _Grid(
                children: <Widget>[
                  _DebugButton(
                    label: '+1,000 coins',
                    onTap: () {
                      _s.player.debugAddCoins(1000);
                      _toast('Added 1,000 coins');
                    },
                  ),
                  _DebugButton(
                    label: '+500 crowns',
                    onTap: () {
                      _s.player.debugAddCrowns(500);
                      _toast('Added 500 crowns');
                    },
                  ),
                  _DebugButton(
                    label: '+500 XP',
                    onTap: () {
                      _s.player.addXp(500);
                      _toast('Added 500 XP');
                    },
                  ),
                  _DebugButton(
                    label: 'Give boosters',
                    onTap: () {
                      for (final BoosterType t in BoosterType.values) {
                        _s.player.grantBooster(t, 5);
                      }
                      _toast('Added 5 of every booster');
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              const KdSectionHeader(title: 'Progression'),
              _Grid(
                children: <Widget>[
                  _DebugButton(
                    label: 'Unlock next kingdom',
                    onTap: () {
                      _s.player.debugUnlockNextKingdom();
                      _toast('Advanced to ${_s.player.currentKingdom.name}');
                    },
                  ),
                  _DebugButton(
                    label: 'Reset daily reward',
                    onTap: () {
                      _s.daily.debugResetDailyReward();
                      _toast('Daily reward is claimable again');
                    },
                  ),
                  _DebugButton(
                    label: 'Complete challenge',
                    onTap: () {
                      _s.daily.debugCompleteChallenge();
                      _toast('Daily challenge marked complete');
                    },
                  ),
                  _DebugButton(
                    label: 'Set best 25,000',
                    onTap: () {
                      _s.player.debugSetBestScore(25000);
                      _toast('Best score set');
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              const KdSectionHeader(title: 'Chests'),
              _Grid(
                children: <Widget>[
                  for (final ChestTier tier in ChestTier.values)
                    _DebugButton(
                      label: tier.displayName,
                      onTap: () => showChestSheet(
                        context,
                        tier: tier,
                        services: _s,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              const KdSectionHeader(title: 'Ads & purchases (mock)'),
              if (mockAds != null) ...<Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Simulate no ad fill', style: AppTextStyles.body),
                  value: mockAds.simulateNoFill,
                  onChanged: (bool v) =>
                      setState(() => mockAds.simulateNoFill = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Simulate ad closed early',
                    style: AppTextStyles.body,
                  ),
                  value: mockAds.simulateDismissal,
                  onChanged: (bool v) =>
                      setState(() => mockAds.simulateDismissal = v),
                ),
              ],
              if (mockIap != null) ...<Widget>[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Simulate purchase failure',
                    style: AppTextStyles.body,
                  ),
                  value: mockIap.simulateFailure,
                  onChanged: (bool v) =>
                      setState(() => mockIap.simulateFailure = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Simulate purchase cancelled',
                    style: AppTextStyles.body,
                  ),
                  value: mockIap.simulateCancellation,
                  onChanged: (bool v) =>
                      setState(() => mockIap.simulateCancellation = v),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              const KdSectionHeader(title: 'Screenshot mode'),
              Text(
                'Loads a profile that looks good in store screenshots: a '
                'part-built kingdom, a healthy wallet and a strong best score.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.sm),
              _DebugButton(
                label: 'Set up screenshot state',
                wide: true,
                onTap: () {
                  _s.player
                    ..debugAddCoins(12500)
                    ..debugAddCrowns(420)
                    ..debugSetBestScore(28640)
                    ..addXp(2200);
                  for (final BoosterType t in BoosterType.values) {
                    _s.player.grantBooster(t, 5);
                  }
                  _toast('Screenshot state ready');
                },
              ),

              const SizedBox(height: AppSpacing.lg),
              const KdSectionHeader(title: 'Analytics log'),
              _AnalyticsLog(analytics: _s.analytics),

              const SizedBox(height: AppSpacing.lg),
              const KdSectionHeader(title: 'Danger zone'),
              _DebugButton(
                label: 'Reset all progress',
                wide: true,
                danger: true,
                onTap: () async {
                  await _s.player.resetProgress();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: children,
    );
  }
}

class _DebugButton extends StatelessWidget {
  const _DebugButton({
    required this.label,
    required this.onTap,
    this.wide = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool wide;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? double.infinity : null,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: danger ? AppColors.danger : AppColors.textPrimary,
          side: BorderSide(
            color: danger ? AppColors.danger : AppColors.borderStrong,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Shows the most recent analytics events so the event stream can be verified
/// without any vendor SDK attached.
class _AnalyticsLog extends StatelessWidget {
  const _AnalyticsLog({required this.analytics});

  final AnalyticsService analytics;

  @override
  Widget build(BuildContext context) {
    if (analytics is! DebugAnalyticsService) {
      return Text(
        'Analytics is not running the debug implementation.',
        style: AppTextStyles.caption,
      );
    }

    final List<AnalyticsRecord> records =
        (analytics as DebugAnalyticsService).records.take(15).toList();

    if (records.isEmpty) {
      return Text('No events yet.', style: AppTextStyles.caption);
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final AnalyticsRecord record in records)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                record.toString(),
                style: AppTextStyles.caption.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 10.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
