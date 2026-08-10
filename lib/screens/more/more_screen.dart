import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../economy/player_service.dart';
import '../../models/achievement.dart';
import '../../progression/level_service.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/kd_card.dart';
import '../settings/settings_screen.dart';
import 'achievements_screen.dart';
import 'daily_reward_sheet.dart';

/// The "More" hub: profile, achievements, daily reward and settings.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const MoreScreen());

  @override
  Widget build(BuildContext context) {
    final AppServices services = ServiceScope.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('MORE', style: AppTextStyles.headline),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: PlayerBuilder(
            builder: (BuildContext context, PlayerService player) {
              final int unlocked = player.data.achievements.values
                  .where((AchievementProgress p) => p.unlocked)
                  .length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xxxl + AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  _ProfileCard(player: player),
                  const SizedBox(height: AppSpacing.lg),

                  const KdSectionHeader(title: 'Progress'),
                  _MenuRow(
                    icon: Icons.military_tech_rounded,
                    iconColor: AppColors.gold,
                    title: 'Achievements',
                    subtitle:
                        '$unlocked of ${AchievementCatalog.all.length} unlocked',
                    badge: player.unseenAchievementCount > 0
                        ? '${player.unseenAchievementCount}'
                        : null,
                    onTap: () => Navigator.of(
                      context,
                    ).push(AchievementsScreen.route()),
                  ),
                  _MenuRow(
                    icon: Icons.card_giftcard_rounded,
                    iconColor: AppColors.secondary,
                    title: 'Daily Reward',
                    subtitle: services.daily.canClaimDailyReward()
                        ? 'Ready to claim'
                        : 'Claimed for today',
                    onTap: () =>
                        showDailyRewardSheet(context, services: services),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  const KdSectionHeader(title: 'Lifetime stats'),
                  _StatsCard(player: player),

                  const SizedBox(height: AppSpacing.lg),
                  const KdSectionHeader(title: 'App'),
                  _MenuRow(
                    icon: Icons.settings_rounded,
                    iconColor: AppColors.textSecondary,
                    title: 'Settings',
                    subtitle: 'Sound, haptics, privacy, support',
                    onTap: () =>
                        Navigator.of(context).push(SettingsScreen.route()),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.player});

  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    final int needed = LevelService.xpForNextLevel(player.level);

    return KdCard(
      gradient: AppColors.primaryGradient,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${player.level}',
                  style: AppTextStyles.headline,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('LEVEL ${player.level}', style: AppTextStyles.title),
                    Text(
                      '${Formatters.number(player.xp)} / '
                      '${Formatters.number(needed)} XP',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          KdProgressBar(
            value: player.levelProgress,
            gradient: const LinearGradient(
              colors: <Color>[Colors.white, Color(0xFFD9D2FF)],
            ),
            background: Colors.black26,
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.player});

  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> rows = <(String, String)>[
      ('Best score', Formatters.number(player.bestScore)),
      ('Games played', Formatters.number(player.stats.gamesPlayed)),
      ('Lines cleared', Formatters.number(player.stats.linesCleared)),
      ('Pieces placed', Formatters.number(player.stats.piecesPlaced)),
      ('Best combo', 'x${player.stats.bestCombo}'),
      ('Kingdoms restored', '${player.stats.kingdomsCompleted}'),
      ('Upgrades bought', '${player.stats.kingdomUpgradesBought}'),
    ];

    return KdCard(
      child: Column(
        children: <Widget>[
          for (final (String label, String value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(label, style: AppTextStyles.body),
                  Text(value, style: AppTextStyles.bodyStrong),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return KdCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppTextStyles.bodyStrong),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                badge!,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
