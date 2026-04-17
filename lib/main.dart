import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:second_chat/l10n/app_localizations.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/streak_controller.dart';
import 'package:second_chat/features/intro/intro_screen1.dart';
import 'package:second_chat/features/intro/login_screen.dart';
import 'package:second_chat/controllers/auth_controller.dart';
import 'package:second_chat/controllers/chat_controller.dart';
import 'package:second_chat/core/utils/platform_token_provider.dart';
import 'package:second_chat/data/services/live_stream_service.dart';
import 'package:second_chat/data/services/socket_firebase_mirror_service.dart';
import 'package:second_chat/controllers/edge_glow_notification_controller.dart';
import 'package:second_chat/controllers/platform_connect_controller.dart';
import 'package:second_chat/features/live_stream/live_stream_screen.dart';
import 'package:second_chat/features/main_section/main/HomeScreen2.dart';
import 'package:second_chat/notifications.dart';
import 'package:second_chat/core/widgets/global_edge_glow_overlay.dart';
import 'package:second_chat/features/Invite/Invite_screen.dart';

import 'controllers/Main Section Controllers/settings_controller.dart';
import 'core/constants/app_colors/app_colors.dart';
import 'core/constants/constants.dart';
import 'core/bootstrap/app_prefetch.dart';
import 'core/utils/debug_tokens.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      try {
        await Firebase.initializeApp();
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'Firebase.initializeApp skipped (add Firebase config / flutterfire configure): $e',
          );
        }
      }
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
      Get.put(EdgeGlowNotificationController(), permanent: true);
      Get.put(StreamStreaksController());
      Get.put(AuthController(), permanent: true);
      Get.put(InviteController(), permanent: true);
      Get.put(SocketFirebaseMirrorService(), permanent: true);
      Get.put(
        ChatController(
          liveStreamService: LiveStreamService(
            api: Get.find<AuthController>().api,
            tokenProvider: PlatformTokenProvider(),
          ),
        ),
        permanent: true,
      );
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

      runApp(MyApp(introVideoController: introVideoController));
    },
    (Object error, StackTrace stack) {
      // Ignore known WebView teardown race:
      // "Unable to establish connection on channel: PigeonInternalInstanceManager.removeStrongReference"
      // and similar WKWebView plugin channel messages.
      if (error is PlatformException &&
          error.message != null &&
          (error.message!.contains(
                'PigeonInternalInstanceManager.removeStrongReference',
              ) ||
              error.message!.contains('PigeonInternalInstanceManager.clear') ||
              error.message!.contains('WKWebViewConfiguration'))) {
        return;
      }
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    },
  );
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        child ?? const SizedBox.shrink(),
                        const GlobalEdgeGlowOverlay(),
                      ],
                    ),
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
              GetPage(
                name: '/edge-glow-demo',
                page: () => const EdgeGlowNotificationPage(),
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
    return const _SplashScreen();
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with TickerProviderStateMixin {
  bool _startupInProgress = false;
  String? _startupError;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final TickerFuture _animForward;
  late final AnimationController _loaderAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _fadeIn = CurvedAnimation(
    parent: _anim,
    curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
  );
  late final Animation<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.82,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 70,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.08,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 30,
    ),
  ]).animate(_anim);
  late final Animation<double> _logoScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.9,
        end: 1.04,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 70,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.04,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 30,
    ),
  ]).animate(CurvedAnimation(parent: _anim, curve: const Interval(0.15, 1.0)));
  late final Animation<Offset> _logoSlide = Tween<Offset>(
    begin: const Offset(0, 0.2),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  late final Animation<double> _glow = Tween<double>(
    begin: 0.0,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
  @override
  void initState() {
    super.initState();
    _animForward = _anim.forward();
    _loaderAnim.repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeAfterSessionCheck();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _loaderAnim.dispose();
    super.dispose();
  }

  Future<bool> _prefetchEssentialData() async {
    return AppPrefetch.prefetchAfterAuth();
  }

  Future<void> _routeAfterSessionCheck() async {
    if (_startupInProgress) return;
    _startupInProgress = true;
    if (mounted && _startupError != null) {
      setState(() => _startupError = null);
    }
    try {
      if (!Get.isRegistered<AuthController>()) return;
      final auth = Get.find<AuthController>();

      while (!auth.isReady.value) {
        await Future.delayed(const Duration(milliseconds: 60));
        if (!mounted) return;
      }

      // Let the splash animation finish (no explicit timer).
      try {
        await _animForward.orCancel;
      } catch (_) {}
      if (!mounted) return;

      if (!auth.isAuthenticated.value) {
        if (!mounted) return;
        Get.offAll(() => const LoginScreen());
        return;
      }

      final prefetchOk = await _prefetchEssentialData();
      if (!prefetchOk) {
        if (!mounted) return;
        setState(() {
          _startupError =
              'Could not prepare your data. Check your connection and try again.';
        });
        return;
      }

      if (!Get.isRegistered<ChatController>()) {
        if (!mounted) return;
        Get.offAll(() => const HomeScreen2());
        return;
      }

      final chat = Get.find<ChatController>();
      try {
        await chat.ensureStreamRealtimeBootstrap();
      } catch (_) {}
      if (!mounted) return;

      final anyLive =
          chat.platformLive.values.any((v) => v == true) ||
          (chat.overview.value?.live == true);
      if (anyLive) {
        Get.offAll(() => const Livestreaming());
        return;
      }

      Get.offAll(() => const HomeScreen2());
    } finally {
      _startupInProgress = false;
    }
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
            colors: [Color(0xFF1B1B25), Color(0xFF0A0A0A)],
          ),
        ),
        child: Stack(
          children: [
            // Soft ambient blobs (no spinners/loader; splash doubles as warm-up).
            AnimatedBuilder(
              animation: _anim,
              builder: (context, child) {
                final t = _glow.value;
                return Stack(
                  children: [
                    Positioned(
                      top: -120.h,
                      left: -90.w,
                      child: Opacity(
                        opacity: 0.30 * t,
                        child: Container(
                          width: 320.w,
                          height: 320.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Color(0xFF8A5CFF), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -160.h,
                      right: -120.w,
                      child: Opacity(
                        opacity: 0.26 * t,
                        child: Container(
                          width: 380.w,
                          height: 380.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Color(0xFFFFE6A7), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 120.h,
                      left: -140.w,
                      child: Opacity(
                        opacity: 0.18 * t,
                        child: Container(
                          width: 420.w,
                          height: 420.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Color(0xFF00E5FF), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _fadeIn,
                      child: AnimatedBuilder(
                        animation: _anim,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _popScale.value,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFFE6A7,
                                    ).withOpacity(0.18 * _glow.value),
                                    blurRadius: 28 * _glow.value,
                                    spreadRadius: 6 * _glow.value,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: Image.asset(
                          'assets/images/bunnyGlow.png',
                          width: 260.w,
                          height: 260.w,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(height: 18.h),
                    FadeTransition(
                      opacity: _fadeIn,
                      child: SlideTransition(
                        position: _logoSlide,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 110.w,
                            height: 110.w,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    if (_startupError == null)
                      FadeTransition(
                        opacity: _fadeIn,
                        child: _SplashDotsLoader(animation: _loaderAnim),
                      ),
                    if (_startupError != null) ...[
                      SizedBox(height: 14.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22.w),
                        child: Text(
                          _startupError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: const Color.fromRGBO(235, 235, 245, 0.86),
                            height: 1.25,
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      TextButton(
                        onPressed: _routeAfterSessionCheck,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFFE6A7),
                        ),
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashDotsLoader extends StatelessWidget {
  const _SplashDotsLoader({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        Widget dot(int index, Color color) {
          final phase = ((t + (index * 0.18)) % 1.0);
          final pulse = Curves.easeInOut.transform(
            (phase < 0.5) ? (phase / 0.5) : ((1.0 - phase) / 0.5),
          );
          final scale = 0.78 + (0.42 * pulse);
          final opacity = 0.35 + (0.55 * pulse);
          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.35 * opacity),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.only(top: 6.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              dot(0, const Color(0xFFFFE6A7)),
              SizedBox(width: 10.w),
              dot(1, const Color(0xFF00E5FF)),
              SizedBox(width: 10.w),
              dot(2, const Color(0xFF8A5CFF)),
            ],
          ),
        );
      },
    );
  }
}
