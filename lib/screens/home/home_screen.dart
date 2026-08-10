import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/config/kingdom_config.dart';
import '../../core/utils/formatters.dart';
import '../../economy/player_service.dart';
import '../../models/daily_state.dart';
import '../../progression/daily_service.dart';
import '../../services/service_locator.dart';
import '../../theme/app_art.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_icons.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/currency_pill.dart';
import '../../widgets/kd_button.dart';
import '../../widgets/kd_card.dart';
import '../../widgets/kingdom_logo.dart';
import '../debug/debug_menu.dart';
import '../game/game_screen.dart';
import '../kingdom/kingdom_screen.dart';
import '../kingdom/kingdom_view.dart';
import '../more/daily_reward_sheet.dart';
import '../more/more_screen.dart';
import '../shop/shop_screen.dart';

/// The home screen.
///
/// The current kingdom is the hero, PLAY is the loudest control on the screen,
/// and everything else — daily reward, challenge, shop, kingdom — is a single
/// tap away without competing for attention.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final AppServices _services;

  @override
  void initState() {
    super.initState();
    _services = ServiceScope.read(context);
    _services.analytics.screen('home');
    WidgetsBinding.instance.addObserver(this);

    // Show the daily reward as soon as it is available, once per launch.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDaily());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _dailyPromptedThisSession = false;

  /// Offers the daily reward once per launch, but only when Home is genuinely
  /// the screen in front of the player.
  ///
  /// Two guards matter here. On a first launch the intro pushes the game
  /// straight on top of Home, so without the route check this sheet would
  /// appear over the tutorial. And a brand-new player should finish learning
  /// the game before being handed a rewards panel at all.
  Future<void> _maybeShowDaily() async {
    if (!mounted || _dailyPromptedThisSession) return;
    if (!_services.player.tutorialCompleted) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    if (!_services.daily.canClaimDailyReward()) return;

    _dailyPromptedThisSession = true;
    await showDailyRewardSheet(context, services: _services);
    if (mounted) setState(() {});
  }

  void _play() {
    _services.audio.playTap();
    Navigator.of(context).push(GameScreen.route()).then((_) {
      if (!mounted) return;
      setState(() {});
      // Coming back from a first run is the natural moment to offer the daily
      // reward the tutorial guard skipped.
      _maybeShowDaily();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameBackground(
        scene: ArtScene.home,
        child: SafeArea(
          child: PlayerBuilder(
            builder: (BuildContext context, PlayerService player) {
              final KingdomDefinition kingdom = player.currentKingdom;
              final int done = player.currentKingdomUpgradesDone;

              return Column(
                children: <Widget>[
                  _Header(player: player, onShop: _openShop),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        children: <Widget>[
                          // The lockup carries the wordmark and the tagline, so
                          // the home screen needs no title text of its own.
                          const KingdomLogoArt(width: 176),
                          const SizedBox(height: AppSpacing.xs),
                          _KingdomHero(
                            kingdom: kingdom,
                            upgradesDone: done,
                            onTap: _openKingdom,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _DailyStrip(
                            services: _services,
                            onChanged: () => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _BestScoreRow(bestScore: player.bestScore),
                          if (player.starterPackAvailable()) ...<Widget>[
                            const SizedBox(height: AppSpacing.lg),
                            _StarterOfferBanner(
                              remaining: player.starterPackRemaining(),
                              onTap: _openShop,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _BottomBar(
                    onPlay: _play,
                    onKingdom: _openKingdom,
                    onShop: _openShop,
                    onMore: _openMore,
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: AppConfig.debugMenuEnabled
          ? FloatingActionButton.small(
              backgroundColor: AppColors.danger,
              tooltip: 'Developer menu',
              onPressed: () => showDebugMenu(context, services: _services),
              child: const Icon(Icons.bug_report_rounded),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  void _openKingdom() {
    Navigator.of(context).push(KingdomScreen.route()).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openShop() {
    Navigator.of(context).push(ShopScreen.route()).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openMore() {
    Navigator.of(context).push(MoreScreen.route()).then((_) {
      if (mounted) setState(() {});
    });
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.player, required this.onShop});

  final PlayerService player;
  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          _LevelBadge(level: player.level, progress: player.levelProgress),
          const Spacer(),
          CurrencyPill(
            kind: CurrencyKind.crowns,
            amount: player.crowns,
            compact: true,
          ),
          const SizedBox(width: AppSpacing.sm),
          CurrencyPill(
            kind: CurrencyKind.coins,
            amount: player.coins,
            compact: true,
            showAdd: true,
            onTap: onShop,
          ),
        ],
      ),
    );
  }
}

/// Circular level indicator with the XP ring around it.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.progress});

  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Level $level, ${(progress * 100).round()} percent to next level',
      child: SizedBox(
        width: 46,
        height: 46,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            SizedBox(
              width: 46,
              height: 46,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: AppDurations.slow,
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double v, _) =>
                    CircularProgressIndicator(
                      value: v,
                      strokeWidth: 3.5,
                      backgroundColor: AppColors.surfaceLow,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryLight,
                      ),
                    ),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$level',
                style: AppTextStyles.currency.copyWith(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KingdomHero extends StatelessWidget {
  const _KingdomHero({
    required this.kingdom,
    required this.upgradesDone,
    required this.onTap,
  });

  final KingdomDefinition kingdom;
  final int upgradesDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool complete = upgradesDone >= kingdom.upgradeCount;

    return KdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        children: <Widget>[
          GamePanel(
            padding: const EdgeInsets.all(5),
            child: KingdomView(kingdom: kingdom, upgradesDone: upgradesDone),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    StrokedText(
                      kingdom.name.toUpperCase(),
                      textAlign: TextAlign.left,
                      strokeWidth: 3.5,
                      style: AppTextStyles.title.copyWith(letterSpacing: 1),
                      fillGradient: AppColors.goldGradient,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      complete
                          ? 'Restored — well done'
                          : '$upgradesDone / ${kingdom.upgradeCount} upgrades',
                      style: AppTextStyles.caption.copyWith(
                        color: complete
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                complete ? Icons.verified_rounded : Icons.chevron_right_rounded,
                color: complete ? AppColors.success : AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          KdProgressBar(value: upgradesDone / kingdom.upgradeCount),
        ],
      ),
    );
  }
}

/// Daily reward and daily challenge, side by side.
class _DailyStrip extends StatelessWidget {
  const _DailyStrip({required this.services, required this.onChanged});

  final AppServices services;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final bool rewardReady = services.daily.canClaimDailyReward();
    final DailyChallengeState challenge = services.daily.challengeFor();
    final bool challengeClaimable = challenge.complete && !challenge.claimed;

    return Row(
      children: <Widget>[
        Expanded(
          child: KdCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            borderColor: rewardReady
                ? AppColors.gold.withValues(alpha: 0.6)
                : null,
            onTap: () async {
              await showDailyRewardSheet(context, services: services);
              onChanged();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const CalendarIcon(size: 22),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'DAILY',
                        style: AppTextStyles.label.copyWith(fontSize: 12),
                      ),
                    ),
                    if (rewardReady) const _ReadyDot(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  rewardReady ? 'Reward ready' : 'Come back tomorrow',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: KdCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            borderColor: challengeClaimable
                ? AppColors.success.withValues(alpha: 0.6)
                : null,
            onTap: () {
              if (challengeClaimable) {
                services.daily.claimChallenge();
                services.haptics.reward();
              }
              onChanged();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.flag_rounded,
                      color: AppColors.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'CHALLENGE',
                        style: AppTextStyles.label.copyWith(fontSize: 12),
                      ),
                    ),
                    if (challengeClaimable) const _ReadyDot(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  challengeClaimable
                      ? 'Tap to claim'
                      : DailyService.describe(challenge),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: AppSpacing.xs),
                KdProgressBar(
                  value: challenge.fraction,
                  height: 6,
                  gradient: const LinearGradient(
                    colors: <Color>[
                      AppColors.secondary,
                      AppColors.secondaryDark,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadyDot extends StatelessWidget {
  const _ReadyDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: AppColors.danger,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BestScoreRow extends StatelessWidget {
  const _BestScoreRow({required this.bestScore});

  final int bestScore;

  @override
  Widget build(BuildContext context) {
    return KdCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.gold,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text('Best score', style: AppTextStyles.body)),
          Text(Formatters.number(bestScore), style: AppTextStyles.title),
        ],
      ),
    );
  }
}

/// The new-player offer.
///
/// Only shown while the offer is genuinely live. The countdown is derived from
/// the player's real first-open timestamp and never restarts — when it runs
/// out, the banner disappears for good.
class _StarterOfferBanner extends StatelessWidget {
  const _StarterOfferBanner({required this.remaining, required this.onTap});

  final Duration remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[Color(0xFF4B3FC4), Color(0xFF7C3F9E)],
      ),
      borderColor: AppColors.gold.withValues(alpha: 0.5),
      child: Row(
        children: <Widget>[
          const Icon(Icons.redeem_rounded, color: AppColors.gold, size: 30),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('NEW PLAYER PACK', style: AppTextStyles.bodyStrong),
                Text(
                  'Ends in ${Formatters.countdown(remaining)}',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white70),
        ],
      ),
    );
  }
}

/// PLAY dominates; the other destinations sit either side of it.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onPlay,
    required this.onKingdom,
    required this.onShop,
    required this.onMore,
  });

  final VoidCallback onPlay;
  final VoidCallback onKingdom;
  final VoidCallback onShop;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow.withValues(alpha: 0.7),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: <Widget>[
          KdButton(
            label: 'PLAY',
            gradient: AppColors.playGradient,
            size: KdButtonSize.hero,
            expand: true,
            onPressed: onPlay,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _NavItem(
                icon: Icons.castle_rounded,
                label: 'Kingdom',
                onTap: onKingdom,
              ),
              _NavItem(
                icon: Icons.storefront_rounded,
                label: 'Shop',
                onTap: onShop,
              ),
              _NavItem(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                onTap: onMore,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: AppColors.textSecondary, size: 24),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ),
      ),
    );
  }
}
