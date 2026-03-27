import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:second_chat/l10n/app_localizations.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/streak_controller.dart';
import 'package:second_chat/features/intro/intro_screen1.dart';
import 'package:second_chat/controllers/auth_controller.dart';
import 'package:second_chat/controllers/chat_controller.dart';
import 'package:second_chat/controllers/platform_connect_controller.dart';
import 'package:second_chat/features/main_section/main/HomeScreen2.dart';

import 'controllers/Main Section Controllers/settings_controller.dart';
import 'core/constants/app_colors/app_colors.dart';
import 'core/constants/constants.dart';
import 'core/localization/l10n.dart';
import 'core/utils/debug_tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  VideoPlayerController? introVideoController;

  // Lock orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // System UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Global controllers
  Get.put(SettingsController());
  Get.put(StreamStreaksController());
  Get.put(AuthController(), permanent: true);
  Get.put(ChatController(), permanent: true);
  Get.put(PlatformConnectController(), permanent: true);

  // Load persisted locale (if any) before building the app.
  try {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(AppConstants.keyLanguage)?.trim();
    if (code != null && code.isNotEmpty) {
      Get.updateLocale(Locale(code));
    }
    final fs = prefs.getString(AppConstants.keyFontSize)?.trim();
    if (fs != null && fs.isNotEmpty) {
      try {
        Get.find<SettingsController>().fontSize.value = fs.toUpperCase();
      } catch (_) {}
    }
  } catch (_) {}

  await debugPrintTokensOnce();

  // Pre-initialize intro video so first screen does not show a loader.
  try {
    introVideoController = VideoPlayerController.asset('assets/intro.mp4');
    await introVideoController.initialize();
    introVideoController
      ..setLooping(true)
      ..setVolume(0);
  } catch (_) {
    await introVideoController?.dispose();
    introVideoController = null;
  }

  runZonedGuarded(() {
    runApp(MyApp(introVideoController: introVideoController));
  }, (Object error, StackTrace stack) {
    // Ignore known WebView teardown race:
    // "Unable to establish connection on channel: PigeonInternalInstanceManager.removeStrongReference"
    // and similar WKWebView plugin channel messages.
    if (error is PlatformException &&
        error.message != null &&
        (error.message!.contains(
                'PigeonInternalInstanceManager.removeStrongReference') ||
            error.message!.contains('PigeonInternalInstanceManager.clear') ||
            error.message!.contains('WKWebViewConfiguration'))) {
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.introVideoController});

  final VideoPlayerController? introVideoController;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      useInheritedMediaQuery: true, // important
      builder: (context, child) {
        // Global fix: correct MediaQuery for insets (nav bar, gesture, safe area) app-wide
        return MediaQuery(
          data: MediaQueryData.fromView(View.of(context)),
          child: GetMaterialApp(
            debugShowCheckedModeBanner: false,
            title: AppConstants.appName,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // Force the entire app to remain LTR even for RTL locales (e.g., Arabic).
            builder: (context, child) {
              final settings = Get.find<SettingsController>();
              return Obx(() {
                final scale = settings.textScaleFactor;
                final media = MediaQuery.of(context);
                return MediaQuery(
                  data: media.copyWith(textScaler: TextScaler.linear(scale)),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: child ?? const SizedBox.shrink(),
                  ),
                );
              });
            },

            // THEME
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: primary,
                primary: primary,
                secondary: secondary,
                error: error,
                surface: surface,
              ),
              scaffoldBackgroundColor: surface,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 16.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary, width: 1.5),
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 16.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
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

            // DARK THEME
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: primary,
                brightness: Brightness.dark,
                primary: primary,
                secondary: secondary,
                error: error,
                surface: surfaceDark,
              ),
              scaffoldBackgroundColor: surfaceDark,
            ),

            // Handles deep links like `/auth/callback` without crashing routing.
            getPages: [
              GetPage(
                name: '/',
                page:
                    () =>
                        StartupGate(introVideoController: introVideoController),
              ),
              GetPage(
                name: '/auth/callback',
                page: () => const _OAuthCallbackPlaceholder(),
              ),
            ],
            unknownRoute: GetPage(
              name: '/unknown',
              page: () => IntroScreen1(initialController: introVideoController),
            ),
            initialRoute: '/',
            home: StartupGate(introVideoController: introVideoController),

            defaultTransition: Transition.cupertino,
            transitionDuration: const Duration(milliseconds: 250),

            fallbackLocale: const Locale('en'),
          ),
        );
      },
    );
  }
}

class _OAuthCallbackPlaceholder extends StatelessWidget {
  const _OAuthCallbackPlaceholder();

  @override
  Widget build(BuildContext context) {
    // OAuth result is handled by `app_links` stream in `OAuthFlow`.
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.shrink(),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key, this.introVideoController});

  final VideoPlayerController? introVideoController;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      if (!auth.isReady.value) {
        return const _SessionCheckLoader();
      }

      if (auth.isAuthenticated.value) {
        return const HomeScreen2();
      }

      return IntroScreen1(initialController: widget.introVideoController);
    });
  }
}

class _SessionCheckLoader extends StatefulWidget {
  const _SessionCheckLoader();

  @override
  State<_SessionCheckLoader> createState() => _SessionCheckLoaderState();
}

class _SessionCheckLoaderState extends State<_SessionCheckLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  late final Animation<double> _rotate = CurvedAnimation(
    parent: _controller,
    curve: Curves.linear,
  );

  late final Animation<double> _pulse = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.1,
            colors: [
              Color(0xFF1B1B25),
              Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 160.w,
                  height: 160.w,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.9, end: 1.1).animate(
                          _pulse,
                        ),
                        child: Container(
                          width: 140.w,
                          height: 140.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFFFFE6A7).withOpacity(0.25),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 90.w,
                        height: 90.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFFE6A7),
                            width: 3.w,
                          ),
                        ),
                      ),
                      RotationTransition(
                        turns: _rotate,
                        child: SizedBox(
                          width: 90.w,
                          height: 90.w,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              width: 7.w,
                              height: 7.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFFE6A7),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFE6A7)
                                        .withOpacity(0.7),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 58.w,
                        height: 58.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: goldGradient,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFE6A7).withOpacity(0.5),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(12.w),
                          child: Image.asset('assets/icons/loader_icon.png'),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  context.l10n.checkingSession,
                  style: TextStyle(
                    color: textInverse.withOpacity(0.78),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
