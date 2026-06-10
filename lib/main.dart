import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:second_chat/l10n/app_localizations.dart';
import 'package:second_chat/controllers/Main%20Section%20Controllers/streak_controller.dart';
import 'package:second_chat/features/intro/Intro_notification.dart';
import 'package:second_chat/features/intro/intro_screen1.dart';
import 'package:second_chat/features/intro/login_screen.dart';
import 'package:second_chat/controllers/auth_controller.dart';
import 'package:second_chat/controllers/chat_controller.dart';
import 'package:second_chat/core/utils/platform_token_provider.dart';
import 'package:second_chat/data/services/live_stream_service.dart';
import 'package:second_chat/data/services/socket_firebase_mirror_service.dart';
import 'package:second_chat/controllers/edge_glow_notification_controller.dart';
import 'package:second_chat/controllers/platform_categories_controller.dart';
import 'package:second_chat/controllers/platform_connect_controller.dart';
import 'package:second_chat/features/live_stream/live_stream_screen.dart';
import 'package:second_chat/features/main_section/main/HomeScreen2.dart';
import 'package:second_chat/notifications.dart';
import 'package:second_chat/core/widgets/global_edge_glow_overlay.dart';
import 'package:second_chat/features/Invite/Invite_screen.dart';
import 'package:second_chat/services/push_notification_service.dart';
import 'package:second_chat/core/utils/notification_permission_gate.dart';

import 'controllers/Main Section Controllers/settings_controller.dart';
import 'core/constants/app_colors/app_colors.dart';
import 'core/constants/constants.dart';
import 'core/bootstrap/app_prefetch.dart';
import 'core/utils/debug_tokens.dart';

bool _isIgnorableKnownWebViewRace(Object error) {
  final msg = error.toString();
  if (error is PlatformException && error.message != null) {
    final em = error.message!;
    if (em.contains('PigeonInternalInstanceManager.removeStrongReference') ||
        em.contains('PigeonInternalInstanceManager.clear') ||
        em.contains('WKWebViewConfiguration')) {
      return true;
    }
  }
  // Android WebView plugin teardown race:
  // "Argument for ... WebViewClient.onLoadResource was null, expected non-null WebViewClient."
  if (msg.contains('WebViewClient.onLoadResource was null') &&
      msg.contains('expected non-null WebViewClient')) {
    return true;
  }
  if (msg.contains("arg_pigeon_instance != null") &&
      msg.contains('android_webkit.g.dart')) {
    return true;
  }
  return false;
}

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (FlutterErrorDetails details) {
        if (_isIgnorableKnownWebViewRace(details.exception)) return;
        FlutterError.presentError(details);
      };
      try {
        await Firebase.initializeApp();
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'Firebase.initializeApp skipped (add Firebase config / flutterfire configure): $e',
          );
        }
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
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
      Get.put(PlatformCategoriesController(), permanent: true);
      await PushNotificationService.initialize();

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
      if (_isIgnorableKnownWebViewRace(error)) {
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
                      clipBehavior: Clip.none,
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
    return _SplashScreen(introVideoController: widget.introVideoController);
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen({this.introVideoController});

  static const String splashVideoAsset = 'assets/updatedsplash.mp4';

  final VideoPlayerController? introVideoController;

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  static const String _kHome2SettingsOpenedKey =
      'second_chat.home2.settings_opened_done';
  bool _startupInProgress = false;
  String? _startupError;

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _splashVideoReleased = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initSplashVideo());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_routeAfterSessionCheck());
    });
  }

  void _onVideoTick() {
    if (!mounted || _splashVideoReleased) return;
    setState(() {});
  }

  Future<void> _disposeSplashVideo() async {
    if (_splashVideoReleased) return;
    _splashVideoReleased = true;

    final controller = _videoController;
    _videoController = null;
    _videoInitialized = false;

    if (controller == null) return;

    controller.removeListener(_onVideoTick);
    try {
      if (controller.value.isInitialized && controller.value.isPlaying) {
        await controller.pause();
      }
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _navigateFromSplash(Widget Function() page) async {
    await _disposeSplashVideo();
    if (!mounted) return;
    Get.offAll(page);
  }

  Future<void> _initSplashVideo() async {
    _splashVideoReleased = false;
    final controller = VideoPlayerController.asset(
      _SplashScreen.splashVideoAsset,
    );
    try {
      await controller.initialize().timeout(const Duration(seconds: 10));
      if (!mounted) {
        await controller.dispose();
        return;
      }
      if (kDebugMode) {
        debugPrint('SPLASH VIDEO LOADED: ${_SplashScreen.splashVideoAsset}');
      }

      controller
        ..setLooping(false)
        ..setVolume(1.0)
        ..addListener(_onVideoTick);

      _videoController = controller;
      _videoInitialized = true;
      setState(() {});

      unawaited(controller.play());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SPLASH VIDEO ERROR: $e');
      }
      try {
        controller.removeListener(_onVideoTick);
        await controller.dispose();
      } catch (_) {}
      _splashVideoReleased = true;
      _videoController = null;
      _videoInitialized = false;
      if (!mounted) return;
      setState(() {
        _startupError = 'Could not load splash video. Tap retry to try again.';
      });
    }
  }

  Future<void> _waitForVideoReady() async {
    final deadline = DateTime.now().add(const Duration(seconds: 12));
    while (!_videoInitialized && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 40));
      if (!mounted) return;
    }
  }

  Future<void> _waitForSplashVideoToFinish() async {
    await _waitForVideoReady();

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final duration = controller.value.duration;
    final maxWait =
        duration > Duration.zero
            ? duration + const Duration(milliseconds: 800)
            : const Duration(seconds: 4);
    final finished = Completer<void>();

    void onEnd() {
      if (_splashVideoReleased) return;
      try {
        final value = controller.value;
        if (!value.isInitialized || value.duration <= Duration.zero) return;
        final nearEnd =
            value.position >=
            value.duration - const Duration(milliseconds: 300);
        if (nearEnd && !finished.isCompleted) {
          finished.complete();
        }
      } catch (_) {}
    }

    controller.addListener(onEnd);
    try {
      await Future.any([finished.future, Future.delayed(maxWait)]);
    } finally {
      controller.removeListener(onEnd);
    }
  }

  Future<void> _retrySplashVideo() async {
    await _disposeSplashVideo();
    if (mounted) {
      setState(() => _startupError = null);
    }
    await _initSplashVideo();
    if (!mounted) return;
    await _routeAfterSessionCheck();
  }

  @override
  void dispose() {
    unawaited(_disposeSplashVideo());
    super.dispose();
  }

  Future<bool> _prefetchEssentialData() async {
    return AppPrefetch.prefetchAfterAuth();
  }

  Future<bool> _shouldShowNotificationIntro(AuthController auth) async {
    final introComplete = await auth.isIntroOnboardingPreferenceComplete();
    if (introComplete) return false;
    final permissionAllowed = await NotificationPermissionGate.isAllowed();
    if (permissionAllowed) return false;
    final enabled = await auth.isNotificationEnabledOnServer(
      refresh: true,
      defaultValue: false,
    );
    return !enabled;
  }

  Future<bool> _consumeFirstLaunchFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstLaunch =
          prefs.getBool(AppConstants.keyIsFirstLaunch) ?? true;
      if (isFirstLaunch) {
        await prefs.setBool(AppConstants.keyIsFirstLaunch, false);
      }
      return isFirstLaunch;
    } catch (_) {
      return false;
    }
  }

  Future<void> _routeAfterSessionCheck() async {
    if (_startupInProgress) return;
    _startupInProgress = true;
    try {
      if (!Get.isRegistered<AuthController>()) return;
      final auth = Get.find<AuthController>();

      while (!auth.isReady.value) {
        await Future.delayed(const Duration(milliseconds: 60));
        if (!mounted) return;
      }

      // Start warm-up work as early as possible so it overlaps with the splash
      // animation. This reduces time-to-home on slower networks/devices.
      final startAuthenticated = auth.isAuthenticated.value;
      Future<bool>? prefetchFuture;
      Future<void>? chatBootstrapFuture;
      if (startAuthenticated) {
        prefetchFuture = _prefetchEssentialData().catchError((_) => false);
        if (Get.isRegistered<ChatController>()) {
          final chat = Get.find<ChatController>();
          chatBootstrapFuture = chat.ensureStreamRealtimeBootstrap().catchError(
            (_) {},
          );
        }
      }

      await _waitForSplashVideoToFinish();
      if (!mounted) return;

      if (_videoController == null || !_videoInitialized) {
        if (_startupError == null && mounted) {
          setState(() {
            _startupError =
                'Could not load splash video. Tap retry to try again.';
          });
        }
        return;
      }

      if (!auth.isAuthenticated.value) {
        final isFirstLaunch = await _consumeFirstLaunchFlag();
        if (isFirstLaunch) {
          if (!mounted) return;
          await _navigateFromSplash(
            () => IntroScreen1(initialController: widget.introVideoController),
          );
          return;
        }
        if (!mounted) return;
        await _navigateFromSplash(() => const LoginScreen());
        return;
      }

      final prefetchOk = await (prefetchFuture ?? _prefetchEssentialData());
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
        try {
          if (await _shouldShowNotificationIntro(auth)) {
            await _navigateFromSplash(() => const NotficationScreens());
            return;
          }
        } catch (_) {}
        await _navigateFromSplash(() => const HomeScreen2());
        return;
      }

      final chat = Get.find<ChatController>();
      if (chatBootstrapFuture != null) {
        await chatBootstrapFuture;
      } else {
        try {
          await chat.ensureStreamRealtimeBootstrap();
        } catch (_) {}
      }
      if (!mounted) return;

      try {
        if (await _shouldShowNotificationIntro(auth)) {
          await _navigateFromSplash(() => const NotficationScreens());
          return;
        }
      } catch (_) {}

      if (await _areHome2StepsCompleted()) {
        await _navigateFromSplash(() => const Livestreaming());
        return;
      }

      final anyLive = await _hasAnyConnectedLivePlatform(chat);
      if (anyLive) {
        await _navigateFromSplash(() => const Livestreaming());
        return;
      }

      await _navigateFromSplash(() => const HomeScreen2());
    } finally {
      _startupInProgress = false;
    }
  }

  Future<bool> _hasAnyConnectedLivePlatform(ChatController chat) async {
    try {
      final connected = await PlatformTokenProvider().getConnectedPlatforms();
      final connectedKeys =
          connected
              .map((p) => p.toLowerCase().trim())
              .where((p) => p.isNotEmpty)
              .toSet();
      if (connectedKeys.isEmpty) return false;

      // Overview API is the startup source of truth (socket may not be connected yet).
      await chat.refreshOverviewsForPlatforms(
        connectedKeys.toList(growable: false),
      );
      return chat.isAnyStreamLive;
    } catch (_) {
      return chat.isAnyStreamLive;
    }
  }

  String _normalizePlatformKey(String raw) {
    final value = raw.toLowerCase().trim();
    if (value.contains('youtube') || value.contains('google')) return 'youtube';
    if (value.contains('twitch')) return 'twitch';
    if (value.contains('kick')) return 'kick';
    return value;
  }

  bool _allCorePlatformsConnectedFromSettings(SettingsController settingsCtrl) {
    final raw = settingsCtrl.settingsPayload.value?['connectPlatforms'];
    if (raw is! List) return false;
    final connected = <String>{};
    for (final item in raw) {
      if (item is String) {
        connected.add(_normalizePlatformKey(item));
        continue;
      }
      if (item is! Map) continue;
      final row = Map<String, dynamic>.from(item);
      final platform =
          (row['platform'] ?? row['platformName'] ?? '').toString();
      final isConnected =
          row['connected'] == true ||
          row['is_active'] == true ||
          row['isConnected'] == true;
      if (!isConnected) continue;
      connected.add(_normalizePlatformKey(platform));
    }
    return connected.contains('twitch') &&
        connected.contains('kick') &&
        connected.contains('youtube');
  }

  bool _allCorePlatformsConnectedFromController(
    PlatformConnectController platformCtrl,
  ) {
    final connected = <String>{};
    for (final entry in platformCtrl.isConnected.entries) {
      if (entry.value != true) continue;
      connected.add(_normalizePlatformKey(entry.key.toString()));
    }
    return connected.contains('twitch') &&
        connected.contains('kick') &&
        connected.contains('youtube');
  }

  Future<bool> _areHome2StepsCompleted() async {
    try {
      final settingsCtrl = Get.find<SettingsController>();
      final platformCtrl = Get.find<PlatformConnectController>();
      final streakCtrl = Get.find<StreamStreaksController>();
      final prefs = await SharedPreferences.getInstance();

      final notificationsEnabled = settingsCtrl.notifications.value;
      final allPlatformsConnected =
          _allCorePlatformsConnectedFromController(platformCtrl) ||
          _allCorePlatformsConnectedFromSettings(settingsCtrl);
      final settingsOpened = prefs.getBool(_kHome2SettingsOpenedKey) == true;
      final streaksCustomized = streakCtrl.hasStreak;

      return notificationsEnabled &&
          allPlatformsConnected &&
          settingsOpened &&
          streaksCustomized;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoInitialized &&
              controller != null &&
              controller.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              ),
            )
          else
            const ColoredBox(color: Colors.black),
          if (_startupError != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                    onPressed:
                        _videoInitialized
                            ? _routeAfterSessionCheck
                            : _retrySplashVideo,
                    style: TextButton.styleFrom(foregroundColor: twitchPurple),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
