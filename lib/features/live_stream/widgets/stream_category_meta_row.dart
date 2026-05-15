import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../../controllers/platform_categories_controller.dart';
import '../../../core/constants/app_colors/app_colors.dart';
import '../../../core/themes/textstyles.dart';

/// Category row in the title panel (tap toggles inline dropdown below).
class StreamCategoryMetaRow extends StatelessWidget {
  const StreamCategoryMetaRow({
    super.key,
    required this.isEditing,
    required this.displayLabel,
    required this.categoryController,
    required this.menuOpen,
    required this.onMenuToggle,
  });

  final bool isEditing;
  final String displayLabel;
  final TextEditingController categoryController;
  final ValueNotifier<bool> menuOpen;
  final VoidCallback onMenuToggle;

  static const double dropdownMaxHeight = 248;

  @override
  Widget build(BuildContext context) {
    return _MetaShell(
      onTap: isEditing ? onMenuToggle : null,
      child: Row(
        children: [
          Expanded(
            child: Text(
              isEditing
                  ? (categoryController.text.trim().isNotEmpty
                      ? categoryController.text.trim()
                      : displayLabel)
                  : displayLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: sfProText600(13.sp, Colors.white),
            ),
          ),
          if (isEditing) ...[
            SizedBox(width: 8.w),
            ValueListenableBuilder<bool>(
              valueListenable: menuOpen,
              builder: (_, open, __) {
                return AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade400,
                    size: 22.sp,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaShell extends StatelessWidget {
  const _MetaShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
      decoration: BoxDecoration(
        color: greyy,
        borderRadius: BorderRadius.circular(28.r),
      ),
      child: child,
    );
    if (onTap == null) return inner;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: inner,
    );
  }
}

/// Inline category list shown inside the title panel when the menu is open.
class StreamCategoryDropdownPanel extends StatelessWidget {
  const StreamCategoryDropdownPanel({
    super.key,
    required this.platformKey,
    required this.selectedCategoryId,
    required this.onPick,
    this.maxHeight,
  });

  final String platformKey;
  final ValueNotifier<String?> selectedCategoryId;
  final void Function(String name, String id) onPick;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final categoriesCtrl = Get.find<PlatformCategoriesController>();
    final panelHeight = maxHeight ?? StreamCategoryMetaRow.dropdownMaxHeight.h;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20.r),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        height: panelHeight,
        decoration: BoxDecoration(
          color: black,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: const Color.fromRGBO(74, 74, 74, 1),
            width: 1,
          ),
        ),
        child: Obx(() {
          categoriesCtrl.categoriesByPlatform.keys;
          categoriesCtrl.loadingByPlatform.keys;
          final items = categoriesCtrl.categoriesFor(platformKey);
          if (items.isEmpty) {
            if (categoriesCtrl.isLoading(platformKey)) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: 28.h),
                child: Center(
                  child: SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white54,
                    ),
                  ),
                ),
              );
            }
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
              child: Text(
                'No categories loaded',
                style: sfProText400(12.sp, Colors.white54),
              ),
            );
          }

          return ValueListenableBuilder<String?>(
            valueListenable: selectedCategoryId,
            builder: (context, selectedId, _) {
              return ListView.separated(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                physics: const ClampingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final id = item['id'] ?? '';
                  final name = item['name'] ?? '';
                  final isSelected =
                      selectedId != null &&
                      selectedId.isNotEmpty &&
                      selectedId == id;

                  return InkWell(
                    onTap: () => onPick(name, id),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      color: isSelected
                          ? const Color.fromRGBO(49, 49, 49, 1)
                          : Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: sfProText500(
                                12.sp,
                                isSelected ? Colors.white : Colors.white70,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_rounded,
                              size: 18.sp,
                              color: Colors.white70,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        }),
      ),
    );
  }
}
