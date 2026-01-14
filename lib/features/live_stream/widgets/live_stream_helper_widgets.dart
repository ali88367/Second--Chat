import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/themes/textstyles.dart';

Widget serviceRow({
  required String asset,
  required String title,
  required String subtitle,
  VoidCallback? onTap,
}) {
  final row = Container(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
    decoration: BoxDecoration(
      color: Color.fromRGBO(30, 29, 32, 1),
      borderRadius: BorderRadius.circular(32.r),
    ),
    child: Row(
      children: [
        Center(
          child: Image.asset(asset, width: 23.w, height: 23.h),
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: sfProText600(12.sp, Colors.white)),
            Text(subtitle, style: sfProText400(10.sp, Colors.grey.shade500)),
          ],
        ),
        const Spacer(),
        Container(
          width: 30.w,
          height: 30.w,
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(18.r),
          ),
          child: Icon(
            Icons.arrow_forward_ios,
            color: Colors.white,
            size: 16.sp,
          ),
        ),
      ],
    ),
  );

  if (onTap != null) {
    return GestureDetector(onTap: onTap, child: row);
  }

  return row;
}

Widget counterPill({
  required String asset,
  required String count,
  required Color color,
  required Color bgColor,
}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 15.w),
    height: 38.5.h,
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(70.4.r),
    ),
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, color: color, width: 12.1.w, height: 12.1.h),
          SizedBox(width: 4.4.w),
          Text(count, style: sfProText400(14.3.sp, color)),
        ],
      ),
    ),
  );
}

Widget panelRow(String text, {bool showChevron = false, VoidCallback? onTap}) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
    decoration: BoxDecoration(
      color: Color.fromRGBO(30, 29, 32, 1),
      borderRadius: BorderRadius.circular(28.r),
    ),
    child: Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Text(text, style: sfProText600(13.sp, Colors.white)),
                const Spacer(),
                if (showChevron)
                  Container(
                    height: 20,
                    width: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(18.r),
                    ),
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(1.2, 0), // shift left
                        child: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 13.sp,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget activityRow(String asset, String name, String time, String message) {
  final Color nameColor = asset.contains('kick')
      ? Color.fromRGBO(83, 252, 24, 1)
      : asset.contains('twitch')
      ? Color.fromRGBO(185, 80, 239, 1)
      : asset.contains('youtube')
      ? Color.fromRGBO(221, 44, 40, 1)
      : Colors.white;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Image.asset(asset, width: 16.w, height: 16.h),
          SizedBox(width: 8.w),
          Text(name, style: sfProText600(14.sp, nameColor)),
          Spacer(),
          Text(time, style: sfProText400(12.sp, Colors.grey.shade400)),
        ],
      ),
      if (message.isNotEmpty) ...[
        SizedBox(height: 6.h),
        Text(message, style: sfProText600(15.sp, Colors.white)),
      ],
    ],
  );
}

Widget pillButton(String text, {required bool isActive, String? assetPath}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
    decoration: BoxDecoration(
      color: isActive ? const Color(0xFF1E1E1E) : Colors.transparent,
      borderRadius: BorderRadius.circular(20.r),
      border: Border.all(
        color: isActive ? Colors.yellow : Colors.grey.shade800,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assetPath != null) ...[
          Image.asset(
            assetPath,
            width: 16.w,
            height: 16.h,
            color: isActive ? Colors.yellow : Colors.grey.shade600,
          ),
          SizedBox(width: 6.w),
        ],
        Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.yellow : Colors.grey.shade600,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

Widget buildImageButton(
  String assetPath, {
  required double width,
  required double height,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: Image.asset(assetPath, fit: BoxFit.contain),
  );
}
