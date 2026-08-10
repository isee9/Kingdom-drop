import 'package:flutter/material.dart';

import '../../core/config/kingdom_config.dart';
import '../../services/service_locator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/kd_button.dart';
import 'kingdom_view.dart';

/// The celebration shown when the last upgrade of a kingdom lands.
Future<void> showKingdomCompleteSheet(
  BuildContext context, {
  required KingdomDefinition kingdom,
  required AppServices services,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) =>
        _KingdomCompleteSheet(kingdom: kingdom, services: services),
  );
}

class _KingdomCompleteSheet extends StatefulWidget {
  const _KingdomCompleteSheet({required this.kingdom, required this.services});

  final KingdomDefinition kingdom;
  final AppServices services;

  @override
  State<_KingdomCompleteSheet> createState() => _KingdomCompleteSheetState();
}

class _KingdomCompleteSheetState extends State<_KingdomCompleteSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLast =
        widget.kingdom.index >= KingdomConfig.kingdomCount - 1;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _controller,
              curve: const Interval(0, 0.5, curve: Curves.easeOutBack),
            ),
            child: Text(
              'KINGDOM COMPLETE',
              textAlign: TextAlign.center,
              style: AppTextStyles.headline.copyWith(color: AppColors.gold),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          KingdomView(
            kingdom: widget.kingdom,
            upgradesDone: widget.kingdom.upgradeCount,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            widget.kingdom.name,
            style: AppTextStyles.title,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isLast
                ? 'Every realm on the map is yours. More are on the way.'
                : 'Fully restored. A new realm is waiting.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          KdButton(
            label: 'OPEN KINGDOM CHEST',
            gradient: AppColors.goldGradient,
            size: KdButtonSize.large,
            expand: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
