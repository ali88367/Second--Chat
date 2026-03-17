import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/streak_controller.dart';
import 'package:second_chat/features/intro/intro_screen1.dart';
import 'package:second_chat/controllers/auth_controller.dart';
import 'package:second_chat/controllers/platform_connect_controller.dart';
import 'package:second_chat/features/main_section/main/HomeScreen2.dart';

import 'controllers/Main Section Controllers/settings_controller.dart';
import 'core/constants/app_colors/app_colors.dart';
import 'core/constants/constants.dart';

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
  Get.put(PlatformConnectController(), permanent: true);

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

  runApp(MyApp(introVideoController: introVideoController));

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
              page: () => StartupGate(
                introVideoController: introVideoController,
              ),
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

          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
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
  late final Future<bool> _hasTokensFuture;

  @override
  void initState() {
    super.initState();
    _hasTokensFuture = _hasStoredTokens();
  }

  Future<bool> _hasStoredTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = prefs.getString('second_chat.access_token') ?? '';
    final refreshToken = prefs.getString('second_chat.refresh_token') ?? '';
    return accessToken.isNotEmpty && refreshToken.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasTokensFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFF0A0A0A),
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final hasTokens = snapshot.data == true;
        if (hasTokens) {
          return const HomeScreen2();
        }

        return IntroScreen1(initialController: widget.introVideoController);
      },
    );
  }
}
