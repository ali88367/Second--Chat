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
      mainAxisSize: MainAxisSize.min,
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
        ValueListenableBuilder<bool>(
          valueListenable: categoryMenuOpen,
          builder: (context, menuOpen, _) {
            return AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.hardEdge,
              child: menuOpen && isEditing
                  ? Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: StreamCategoryDropdownPanel(
                        platformKey: platformKey,
                        selectedCategoryId: selectedCategoryId,
                        onPick: onCategoryPicked,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            );
          },
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
