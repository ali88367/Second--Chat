import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:second_chat/LiveStreaming.dart';
import 'package:second_chat/features/intro/intro_screen1.dart';
import 'package:second_chat/features/intro/intro_screen3.dart';
import 'package:second_chat/features/intro/intro_screen4.dart';
import 'package:second_chat/features/intro/intro_screen5.dart';
import 'package:second_chat/features/main_section/main/HomeScreen2.dart';
import 'package:second_chat/features/main_section/stream/StreamStreak1.dart';
import 'controllers/Main Section Controllers/settings_controller.dart';
import 'core/constants/app_colors/app_colors.dart';
import 'core/constants/constants.dart';
import 'notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations (optional)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  Get.put(SettingsController());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852), // Design size from Figma
      minTextAdapt: true,
      splitScreenMode: true,
      useInheritedMediaQuery: true,
      builder: (context, child) {
        return GetMaterialApp(
          debugShowCheckedModeBanner: false,
          title: AppConstants.appName,

          // Theme Configuration
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primary,
              primary: primary,
              secondary: secondary,
              error: error,
              surface: surface,
              background: background,
            ),
            scaffoldBackgroundColor: background,
            appBarTheme: AppBarTheme(
              backgroundColor: background,
              elevation: 0,
              iconTheme: IconThemeData(color: textPrimary),
              centerTitle: true,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: textInverse,
                elevation: 2,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: BorderSide(color: primary, width: 1.5),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: primary,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: greyScale50,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 16.h,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: primary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: error, width: 2),
              ),
            ),
            cardTheme: CardThemeData(
              color: card,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            dividerTheme: DividerThemeData(
              color: divider,
              thickness: 1,
              space: 1,
            ),
          ),

          // Dark Theme (optional - can be implemented later)
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primary,
              brightness: Brightness.dark,
              primary: primary,
              secondary: secondary,
              error: error,
              surface: surfaceDark,
              background: backgroundDark,
            ),
            scaffoldBackgroundColor: backgroundDark,
          ),

          // Use Get.to(), Get.off(), Get.offAll() with direct widget references for navigation
          home: IntroScreen1(),

          // Navigation settings
          defaultTransition: Transition.cupertino,
          transitionDuration: const Duration(milliseconds: 300),

          // Locale settings (optional)
          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
        );
      },
    );
  }
}
