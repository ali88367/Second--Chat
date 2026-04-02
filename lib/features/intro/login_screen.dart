import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:second_chat/api/auth/oauth_provider.dart';
import 'package:second_chat/controllers/platform_connect_controller.dart';
import 'package:second_chat/core/constants/app_colors/app_colors.dart';
import 'package:second_chat/core/constants/constants.dart';
import 'package:second_chat/core/localization/l10n.dart';
import 'package:second_chat/core/themes/textstyles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'intro_screen2.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late _LanguageItem selectedLanguage = _languages[0];

  final List<_LanguageItem> _languages = [
    _LanguageItem('en', 'Eng', 'https://flagcdn.com/w160/us.png'),
    _LanguageItem('es', 'Spa', 'https://flagcdn.com/w160/es.png'),
    _LanguageItem('ar', 'Ara', 'https://flagcdn.com/w160/sa.png'),
    _LanguageItem('pt', 'Por', 'https://flagcdn.com/w160/pt.png'),
    _LanguageItem('de', 'Ger', 'https://flagcdn.com/w160/de.png'),
    _LanguageItem('fr', 'Fre', 'https://flagcdn.com/w160/fr.png'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadImages(context);
    });
  }

  void _preloadImages(BuildContext context) {
    precacheImage(const AssetImage('assets/images/bunny.png'), context);
  }

  Future<void> _connectGoogleAndContinue() async {
    final ctrl = Get.find<PlatformConnectController>();
    if (ctrl.connectingProvider.value != null) return;
    final ok = await ctrl.connect(OAuthProvider.youtube);
    if (!mounted) return;
    if (ok) {
      Get.to(
        () => const IntroScreen2(),
        transition: Transition.cupertino,
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  void _showAppleComingSoon() {
    Get.snackbar(
      'Apple Sign In',
      'Coming soon',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF2C2C2E),
      colorText: Colors.white,
      margin: EdgeInsets.all(12.w),
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _persistLanguage(_LanguageItem lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyLanguage, lang.code);
    } catch (_) {}
    Get.updateLocale(Locale(lang.code));
  }

  @override
  Widget build(BuildContext context) {
    final connectCtrl = Get.find<PlatformConnectController>();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          Positioned(
            top: 40.h,
            right: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                ),
                child: PopupMenuButton<_LanguageItem>(
                  offset: const Offset(0, 45),
                  color: const Color.fromRGBO(48, 48, 48, 0.95),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onSelected: (lang) {
                    setState(() {
                      selectedLanguage = lang;
                    });
                    _persistLanguage(lang);
                  },
                  itemBuilder: (context) {
                    return _languages.map((lang) {
                      return PopupMenuItem<_LanguageItem>(
                        value: lang,
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: NetworkImage(lang.flag),
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              lang.label,
                              style: sfProText400(15.sp, Colors.white),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(48, 48, 48, 0.5),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: NetworkImage(selectedLanguage.flag),
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedLanguage.label,
                          style: sfProText400(17.sp, Colors.white),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, color: grey, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 100.h,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Center(
                child: Container(
                  width: 320.w * 0.8,
                  height: 320.w * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: goldeffect.withOpacity(0.4),
                        blurRadius: 144,
                        spreadRadius: 48,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 60.h,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Image.asset('assets/images/bunny.png', height: 300.h),
            ),
          ),
          Positioned(
            top: 380.h,
            left: 0.w,
            right: 0.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  context.l10n.allInOne,
                  style: sfProDisplay600(34.sp, Colors.white),
                ),
                _ShimmerText(
                  text: context.l10n.multichat,
                  style: sfProDisplay600(34.sp, Colors.white),
                  gradientColors: const [Color(0xFFFFD966), Color(0xFFFF7A18)],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 32.h,
            left: 16.w,
            right: 16.w,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                  decoration: BoxDecoration(
                    color: blackbox,
                    borderRadius: BorderRadius.circular(22.r),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Log in', style: sfProDisplay700(22.sp, Colors.white)),
                      SizedBox(height: 4.h),
                      Text(
                        'For synchronising and managing subscriptions',
                        textAlign: TextAlign.center,
                        style: sfProText400(15.sp, const Color(0xFF6E6E73)),
                      ),
                      SizedBox(height: 14.h),
                      _LoginActionButton(
                        label: 'Sign In with Apple',
                        backgroundColor: const Color(0xFF1A1C22),
                        textColor: Colors.white,
                        leading: Icon(
                          Icons.apple,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                        onPressed: _showAppleComingSoon,
                      ),
                      SizedBox(height: 10.h),
                      Obx(() {
                        final isLoading =
                            connectCtrl.connectingProvider.value ==
                            OAuthProvider.youtube;
                        return _LoginActionButton(
                          label: 'Sign in with Google',
                          backgroundColor: Colors.white,
                          textColor: const Color(0xFF1E1D20),
                          leading:Image.asset('assets/images/googleicon.png',height: 22.h,width: 22.w,),
                          isLoading: isLoading,
                          loadingColor: const Color(0xFF1E1D20),
                          onPressed: _connectGoogleAndContinue,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginActionButton extends StatelessWidget {
  const _LoginActionButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.leading,
    required this.onPressed,
    this.isLoading = false,
    this.loadingColor = Colors.white,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Widget leading;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color loadingColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        height: 56.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(36.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            leading,
            SizedBox(width: 8.w),
            Text(label, style: sfProText600(17.sp, textColor)),
            if (isLoading) ...[
              SizedBox(width: 10.w),
              SizedBox(
                width: 16.w,
                height: 16.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(loadingColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoogleGIcon extends StatelessWidget {
  const _GoogleGIcon();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        colors: [
          Color(0xFF4285F4),
          Color(0xFFEA4335),
          Color(0xFFFBBC05),
          Color(0xFF34A853),
        ],
      ).createShader(rect),
      child: Text(
        'G',
        style: sfProText600(18.sp, Colors.white),
      ),
    );
  }
}

class _LanguageItem {
  final String code;
  final String label;
  final String flag;

  _LanguageItem(this.code, this.label, this.flag);
}

class _ShimmerText extends StatefulWidget {
  const _ShimmerText({
    required this.text,
    required this.style,
    required this.gradientColors,
  });

  final String text;
  final TextStyle style;
  final List<Color> gradientColors;

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  late final Animation<double> _glowAnimation = Tween<double>(
    begin: 0.3,
    end: 0.8,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height));
          },
          child: Text(
            widget.text,
            style: widget.style.copyWith(
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 12,
                  color: Colors.white.withOpacity(_glowAnimation.value),
                  offset: const Offset(0, 0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
