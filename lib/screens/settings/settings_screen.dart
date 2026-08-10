import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_config.dart';
import '../../economy/player_service.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/game_ui.dart';
import '../../widgets/kd_button.dart';
import '../../widgets/kd_card.dart';

/// Settings.
///
/// Legal and support rows only appear once the corresponding URL is filled in
/// in [AppConfig] — a dead link in a shipped app is worse than no link, and
/// this project does not invent contact details.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen());

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    ServiceScope.read(context).analytics.screen('settings');
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      // Not fatal — the version row simply stays blank.
    }
  }

  Future<void> _restorePurchases() async {
    if (_restoring) return;
    setState(() => _restoring = true);

    final AppServices services = ServiceScope.read(context);
    final List<String> restored = await services.purchases.restorePurchases();
    if (!mounted) return;

    setState(() => _restoring = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored.isEmpty
              ? 'No previous purchases found for this account.'
              : 'Restored ${restored.length} purchase'
                    '${restored.length == 1 ? '' : 's'}.',
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Reset all progress?', style: AppTextStyles.title),
        content: Text(
          'This permanently deletes your kingdoms, crowns, coins, boosters, '
          'best score and achievements on this device. It cannot be undone.',
          style: AppTextStyles.body,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Reset everything',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final AppServices services = ServiceScope.read(context);
    await services.player.resetProgress();
    if (!mounted) return;

    services.applySettings();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Progress reset.')));
  }

  @override
  Widget build(BuildContext context) {
    final AppServices services = ServiceScope.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: StrokedText('SETTINGS', style: AppTextStyles.headline),
      ),
      extendBodyBehindAppBar: true,
      body: GameBackground(
        child: SafeArea(
          child: PlayerBuilder(
            builder: (BuildContext context, PlayerService player) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xxxl + AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  const KdSectionHeader(title: 'Audio & feedback'),
                  KdCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      children: <Widget>[
                        _SwitchRow(
                          icon: Icons.music_note_rounded,
                          label: 'Music',
                          value: player.settings.musicEnabled,
                          onChanged: (bool v) {
                            player.setMusicEnabled(v);
                            services.audio.setMusicEnabled(v);
                          },
                        ),
                        _SwitchRow(
                          icon: Icons.volume_up_rounded,
                          label: 'Sound effects',
                          value: player.settings.soundEnabled,
                          onChanged: (bool v) {
                            player.setSoundEnabled(v);
                            services.audio.setSoundEnabled(v);
                          },
                        ),
                        _SwitchRow(
                          icon: Icons.vibration_rounded,
                          label: 'Haptics',
                          value: player.settings.hapticsEnabled,
                          onChanged: (bool v) {
                            player.setHapticsEnabled(v);
                            services.haptics.enabled = v;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  const KdSectionHeader(title: 'Purchases'),
                  KdCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: <Widget>[
                        _ActionRow(
                          icon: Icons.restore_rounded,
                          label: _restoring
                              ? 'Restoring…'
                              : 'Restore purchases',
                          onTap: _restorePurchases,
                        ),
                        if (player.adsRemoved)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Row(
                              children: <Widget>[
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Ads removed — thank you',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  const KdSectionHeader(title: 'About'),
                  KdCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: <Widget>[
                        if (AppConfig.privacyPolicyUrl.isNotEmpty)
                          _ActionRow(
                            icon: Icons.privacy_tip_rounded,
                            label: 'Privacy Policy',
                            onTap: () => _openUrl(AppConfig.privacyPolicyUrl),
                          ),
                        if (AppConfig.termsOfServiceUrl.isNotEmpty)
                          _ActionRow(
                            icon: Icons.description_rounded,
                            label: 'Terms of Service',
                            onTap: () => _openUrl(AppConfig.termsOfServiceUrl),
                          ),
                        if (AppConfig.supportUrl.isNotEmpty ||
                            AppConfig.supportEmail.isNotEmpty)
                          _ActionRow(
                            icon: Icons.help_outline_rounded,
                            label: 'Support',
                            onTap: () => _openUrl(
                              AppConfig.supportUrl.isNotEmpty
                                  ? AppConfig.supportUrl
                                  : 'mailto:${AppConfig.supportEmail}',
                            ),
                          ),
                        if (AppConfig.privacyPolicyUrl.isEmpty &&
                            AppConfig.termsOfServiceUrl.isEmpty &&
                            AppConfig.supportUrl.isEmpty &&
                            AppConfig.supportEmail.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              'Privacy, terms and support links appear here '
                              'once they are configured in AppConfig.',
                              style: AppTextStyles.caption,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 20,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  'Version',
                                  style: AppTextStyles.body,
                                ),
                              ),
                              Text(
                                _version.isEmpty ? '—' : _version,
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),
                  KdButton.ghost(
                    label: 'RESET PROGRESS',
                    icon: Icons.delete_forever_rounded,
                    expand: true,
                    onPressed: _confirmReset,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Kingdom Drop keeps everything on this device. There is no '
                    'account, no login and no personal data collected.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openUrl(String url) {
    // No url_launcher dependency in the MVP: the rows are hidden entirely until
    // real URLs exist, and wiring the launcher is a one-line change then.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(url)));
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: Text(label, style: AppTextStyles.body)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: AppTextStyles.body)),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
