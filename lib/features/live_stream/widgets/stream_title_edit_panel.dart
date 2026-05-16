import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/themes/textstyles.dart';
import 'stream_category_meta_row.dart';

/// Title + category fields and inline category picker for one platform.
class StreamTitleEditPanel extends StatelessWidget {
  const StreamTitleEditPanel({
    super.key,
    required this.platformKey,
    required this.isEditing,
    required this.isSaving,
    required this.titleDisplay,
    required this.categoryDisplay,
    required this.titleField,
    required this.categoryController,
    required this.categoryMenuOpen,
    required this.selectedCategoryId,
    required this.onEditOrSave,
    required this.onToggleCategoryMenu,
    required this.onCategoryPicked,
    required this.metaRowBuilder,
  });

  final String platformKey;
  final bool isEditing;
  final bool isSaving;
  final String titleDisplay;
  final String categoryDisplay;
  final Widget titleField;
  final TextEditingController categoryController;
  final ValueNotifier<bool> categoryMenuOpen;
  final ValueNotifier<String?> selectedCategoryId;
  final VoidCallback onEditOrSave;
  final VoidCallback onToggleCategoryMenu;
  final void Function(String name, String id) onCategoryPicked;
  final Widget Function(Widget content) metaRowBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        metaRowBuilder(titleField),
        SizedBox(height: 12.h),
        StreamCategoryMetaRow(
          isEditing: isEditing,
          displayLabel: categoryDisplay,
          categoryController: categoryController,
          menuOpen: categoryMenuOpen,
          onMenuToggle: isEditing ? onToggleCategoryMenu : () {},
        ),
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: categoryMenuOpen,
            builder: (context, menuOpen, _) {
              if (!menuOpen || !isEditing) {
                return const SizedBox.shrink();
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final cap = math.min(
                    StreamCategoryMetaRow.dropdownMaxHeight.h,
                    math.max(0.0, constraints.maxHeight - 8.h),
                  );
                  if (cap <= 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: cap,
                        width: double.infinity,
                        child: StreamCategoryDropdownPanel(
                          platformKey: platformKey,
                          maxHeight: cap,
                          selectedCategoryId: selectedCategoryId,
                          onPick: onCategoryPicked,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        SizedBox(height: 8.h),
        Align(
          alignment: Alignment.bottomRight,
          child: GestureDetector(
            onTap: isSaving ? null : onEditOrSave,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                isEditing ? (isSaving ? 'Saving...' : 'Save') : 'Edit',
                style: sfProText500(11.sp, Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
