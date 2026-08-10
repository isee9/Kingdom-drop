import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../economy/player_service.dart';
import '../../models/achievement.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/game_icons.dart';
import '../../widgets/kd_card.dart';

/// Achievement list.
///
/// Rewards are granted the moment an achievement unlocks, so this screen is a
/// record rather than a collection chore. Opening it clears the "new" badges.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const AchievementsScreen());

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  void initState() {
    super.initState();
    final AppServices services = ServiceScope.read(context);
    services.analytics.screen('achievements');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final Achievement a in AchievementCatalog.all) {
        final AchievementProgress p = services.player.data.achievementProgress(
          a.id,
        );
        if (p.unlocked && !p.claimed) services.player.markAchievementSeen(a.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: StrokedText('ACHIEVEMENTS', style: AppTextStyles.headline),
      ),
      extendBodyBehindAppBar: true,
      body: GameBackground(
        child: SafeArea(
          child: PlayerBuilder(
            builder: (BuildContext context, PlayerService player) {
              final List<Achievement> sorted =
                  <Achievement>[...AchievementCatalog.all]
                    ..sort((Achievement a, Achievement b) {
                      final bool au = player.data
                          .achievementProgress(a.id)
                          .unlocked;
                      final bool bu = player.data
                          .achievementProgress(b.id)
                          .unlocked;
                      if (au == bu) return 0;
                      return au ? 1 : -1; // Unlocked ones drop to the bottom.
                    });

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xxxl + AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  for (final Achievement achievement in sorted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _AchievementRow(
                        achievement: achievement,
                        progress: player.data.achievementProgress(
                          achievement.id,
                        ),
                      ),
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

class _AchievementRow extends StatelessWidget {
  const _AchievementRow({required this.achievement, required this.progress});

  final Achievement achievement;
  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final bool unlocked = progress.unlocked;
    final double fraction = (progress.progress / achievement.target).clamp(
      0.0,
      1.0,
    );

    return KdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      color: unlocked ? AppColors.surfaceHigh : AppColors.surface,
      borderColor: unlocked ? AppColors.gold.withValues(alpha: 0.45) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unlocked
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              unlocked ? Icons.military_tech_rounded : Icons.lock_rounded,
              color: unlocked ? AppColors.gold : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(achievement.title, style: AppTextStyles.bodyStrong),
                Text(achievement.description, style: AppTextStyles.caption),
                const SizedBox(height: AppSpacing.sm),
                if (!unlocked) ...<Widget>[
                  KdProgressBar(value: fraction, height: 6),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${Formatters.number(progress.progress)} / '
                    '${Formatters.number(achievement.target)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                ] else
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Unlocked',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            children: <Widget>[
              if (achievement.rewardCoins > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CoinIcon(size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '${achievement.rewardCoins}',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              if (achievement.rewardCrowns > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CrownIcon(size: 13),
                    const SizedBox(width: 3),
                    Text(
                      '${achievement.rewardCrowns}',
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
