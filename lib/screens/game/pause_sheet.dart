import 'package:flutter/material.dart';

import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/kd_button.dart';
import 'game_screen.dart';

enum PauseChoice { resume, restart, quit }

/// Pause menu, with the sound and haptic toggles inline so the player does not
/// have to abandon a run to silence the game.
Future<PauseChoice?> showPauseSheet(
  BuildContext context, {
  required AppServices services,
}) {
  return showModalBottomSheet<PauseChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _PauseSheet(services: services),
  );
}

class _PauseSheet extends StatefulWidget {
  const _PauseSheet({required this.services});

  final AppServices services;

  @override
  State<_PauseSheet> createState() => _PauseSheetState();
}

class _PauseSheetState extends State<_PauseSheet> {
  @override
  Widget build(BuildContext context) {
    final AppServices services = widget.services;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const GameSheetHeader(title: 'PAUSED'),
          const SizedBox(height: AppSpacing.xl),

          _ToggleRow(
            icon: Icons.music_note_rounded,
            label: 'Music',
            value: services.player.settings.musicEnabled,
            onChanged: (bool v) {
              services.player.setMusicEnabled(v);
              services.audio.setMusicEnabled(v);
              setState(() {});
            },
          ),
          _ToggleRow(
            icon: Icons.volume_up_rounded,
            label: 'Sound',
            value: services.player.settings.soundEnabled,
            onChanged: (bool v) {
              services.player.setSoundEnabled(v);
              services.audio.setSoundEnabled(v);
              setState(() {});
            },
          ),
          _ToggleRow(
            icon: Icons.vibration_rounded,
            label: 'Haptics',
            value: services.player.settings.hapticsEnabled,
            onChanged: (bool v) {
              services.player.setHapticsEnabled(v);
              services.haptics.enabled = v;
              setState(() {});
            },
          ),

          const SizedBox(height: AppSpacing.xl),
          KdButton(
            label: 'RESUME',
            gradient: AppColors.playGradient,
            size: KdButtonSize.large,
            expand: true,
            onPressed: () => Navigator.of(context).pop(PauseChoice.resume),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: KdButton.ghost(
                  label: 'RESTART',
                  onPressed: () =>
                      Navigator.of(context).pop(PauseChoice.restart),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: KdButton.ghost(
                  label: 'END RUN',
                  onPressed: () => Navigator.of(context).pop(PauseChoice.quit),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: AppTextStyles.bodyStrong)),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
