import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_radius.dart';
import '../../core/design_system/app_spacing.dart';
import '../../core/design_system/app_text_styles.dart';

/// A filter option in a [SearchFilterBar]. When [value] is null the option is
/// the default (All) selection.
class SearchFilterOption {
  const SearchFilterOption({required this.label, this.value});

  final String label;
  final Object? value;
}

/// Compact search field + filter chip row used across roster and review
/// surfaces. Selection state uses the ink/marigold brand treatment.
class SearchFilterBar extends StatefulWidget {
  const SearchFilterBar({
    super.key,
    required this.hintText,
    this.onQueryChanged,
    this.initialQuery = '',
    this.filters = const [],
    this.selected,
    this.onFilterSelected,
  });

  final String hintText;
  final ValueChanged<String>? onQueryChanged;
  final String initialQuery;
  final List<SearchFilterOption> filters;
  final Object? selected;
  final ValueChanged<Object?>? onFilterSelected;

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 18, color: AppColors.slate),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: widget.onQueryChanged,
                  style: AppTextStyles.bodyMedium,
                  decoration: const InputDecoration(
                    hintText: '',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.filters.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final f in widget.filters)
                _FilterPill(
                  label: f.label,
                  selected: widget.selected == f.value,
                  onTap: () => widget.onFilterSelected?.call(f.value),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ink : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        side: BorderSide(
          color: selected ? AppColors.ink : AppColors.divider,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 6,
          ),
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: selected ? AppColors.surface : AppColors.inkSoft,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}