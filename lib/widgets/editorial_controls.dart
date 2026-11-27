import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EditorialHeavyRule extends StatelessWidget {
  const EditorialHeavyRule({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      height: 2,
      child: ColoredBox(color: KlipFetchTheme.lightInk),
    );
  }
}

class EditorialHairline extends StatelessWidget {
  const EditorialHairline({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: double.infinity,
      height: 1,
      child: ColoredBox(color: KlipFetchTheme.lightBorder),
    );
  }
}

class EditorialMasthead extends StatelessWidget {
  const EditorialMasthead({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.titleSize = 26,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 12),
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final double titleSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: KlipFetchTheme.displayStyle(
                    size: titleSize,
                    wdth: titleSize >= 25 ? 75 : 78,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
        const EditorialHeavyRule(),
      ],
    );
  }
}

class EditorialWell extends StatelessWidget {
  const EditorialWell({
    super.key,
    required this.child,
    this.fillColor = KlipFetchTheme.lightSurfaceSubtle,
    this.borderColor = KlipFetchTheme.lightBorder,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final Color fillColor;
  final Color borderColor;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}

class EditorialSegmentOption<T> {
  const EditorialSegmentOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class EditorialSegmentedControl<T> extends StatelessWidget {
  const EditorialSegmentedControl({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.compact = false,
    this.locked = false,
    this.tabular = false,
  });

  final List<EditorialSegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool compact;
  final bool locked;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final trackHeight = compact ? 30.0 : 38.0;
    final horizontalPad = compact ? 10.0 : 12.0;

    return Container(
      height: trackHeight,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: KlipFetchTheme.lightSurfaceSubtle,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: KlipFetchTheme.lightBorder),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (final option in options)
            _buildSegment(
              option: option,
              isSelected: option.value == selected,
              horizontalPad: horizontalPad,
            ),
        ],
      ),
    );
  }

  Widget _buildSegment({
    required EditorialSegmentOption<T> option,
    required bool isSelected,
    required double horizontalPad,
  }) {
    final textColor = isSelected
        ? KlipFetchTheme.lightOnPrimary
        : (locked
            ? KlipFetchTheme.lightMutedInk
            : KlipFetchTheme.inkSecondary);

    final segmentChild = Container(
      height: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: horizontalPad),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? KlipFetchTheme.lightInk : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        option.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: KlipFetchTheme.bodyFontFamily,
          fontSize: compact ? 11.5 : 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color: textColor,
          fontFeatures:
              tabular ? const [FontFeature.tabularFigures()] : null,
        ),
      ),
    );

    final interactive = Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: () => onSelected(option.value),
        child: segmentChild,
      ),
    );

    return compact ? interactive : Expanded(child: interactive);
  }
}

class EditorialSpecChip extends StatelessWidget {
  const EditorialSpecChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final chip = Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: EdgeInsets.symmetric(horizontal: expand ? 4 : 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? KlipFetchTheme.lightInk
                : KlipFetchTheme.lightSurface,
            borderRadius: BorderRadius.circular(4),
            border: selected
                ? null
                : Border.all(color: KlipFetchTheme.lightControlOutline),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: KlipFetchTheme.bodyFontFamily,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? KlipFetchTheme.lightOnPrimary
                  : KlipFetchTheme.lightInk,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );

    return expand ? Expanded(child: chip) : chip;
  }
}

class EditorialSwitchRow extends StatelessWidget {
  const EditorialSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.showBottomHairline = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showBottomHairline;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: showBottomHairline
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: KlipFetchTheme.lightBorder),
                  ),
                )
              : null,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: KlipFetchTheme.bodyFontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: KlipFetchTheme.lightInk,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontFamily: KlipFetchTheme.bodyFontFamily,
                          fontSize: 11.5,
                          color: KlipFetchTheme.lightMutedInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _EditorialSwitchIndicator(value: value),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorialSwitchIndicator extends StatelessWidget {
  const _EditorialSwitchIndicator({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 24,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value
            ? KlipFetchTheme.brandAccent
            : KlipFetchTheme.lightSurfaceSubtle,
        borderRadius: BorderRadius.circular(4),
        border: value
            ? null
            : Border.all(color: KlipFetchTheme.lightControlOutline),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: value
                ? KlipFetchTheme.lightOnPrimary
                : KlipFetchTheme.lightMutedInk,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
