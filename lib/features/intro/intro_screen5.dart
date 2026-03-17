import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:second_chat/features/main_section/main/HomeScreen2.dart';

import '../../api/config/api_config.dart';
import '../../core/constants/app_colors/app_colors.dart';
import '../../core/localization/get_l10n.dart';
import '../../core/localization/l10n.dart';
import '../../core/themes/textstyles.dart';

class IntroScreen5 extends StatelessWidget {
  const IntroScreen5({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final IntroScreen5Controller controller = Get.put(IntroScreen5Controller());
    controller.loadPlansIfNeeded();
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),

      body: Stack(
        children: [
          // Background Image
          // Positioned.fill(
          //   child: Image.asset(
          //     'assets/images/Background.png',
          //     fit: BoxFit.cover,
          //   ),
          // ),
          Image.asset('assets/images/topbarshade.png', fit: BoxFit.cover),
          // Bottom rotated shade
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Transform.rotate(
              angle: 3.14159, // 180 degrees
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Color(0x80F6F692), // F6F692 with 50% opacity
                  BlendMode.srcATop,
                ),
                child: Image.asset(
                  'assets/images/topbarshade.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Close Button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 10.h,
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: blackbox.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 1.h),

                // Title
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.w),
                  child: Image.asset('assets/images/trialInfo.png'),
                ),

                SizedBox(height: 10.h),

                // -----------------------------------------------------
                // 1. SMOOTH SLIDING SECTION (Images)
                // -----------------------------------------------------
                Expanded(
                  child: PageView(
                    controller: controller.pageController,
                    scrollDirection: Axis.horizontal, // Enables vertical slide
                    physics:
                        const BouncingScrollPhysics(), // Native smooth feel
                    onPageChanged: controller.onPageChanged,
                    children: [
                      // Page 0 Image
                      Container(
                        alignment: Alignment.bottomCenter,
                        // padding: EdgeInsets.only(bottom: 20.h),
                        child: OverflowBox(
                          maxHeight: 300.h,
                          maxWidth: 420.w,
                          child: Image.asset(
                            'assets/images/secondGlow.png',
                            width: 420.w,
                            height: 360.h,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (_, __, ___) =>
                                    SizedBox(width: 280.w, height: 200.h),
                          ),
                        ),
                      ),
                      // Page 1 Image
                      Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.only(bottom: 20.h),
                        child: Image.asset(
                          'assets/images/bunnyGlow.png',
                          width: 280.w,
                          height: 280.h,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) => Container(
                                width: 280.w,
                                height: 280.h,
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Icon(
                                  Icons.pets,
                                  size: 100.sp,
                                  color: Colors.orange.withOpacity(0.5),
                                ),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                // -----------------------------------------------------
                // 2. BOTTOM CARD (Static position, animates content)
                // -----------------------------------------------------
                GestureDetector(
                  onHorizontalDragStart: controller.onHorizontalDragStart,
                  onHorizontalDragUpdate: controller.onHorizontalDragUpdate,
                  onHorizontalDragEnd: controller.onHorizontalDragEnd,

                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 16.w),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 20.h,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(30, 29, 32, 1),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Page Indicators
                        Obx(
                          () => Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildDot(controller.currentPage.value == 0),
                              SizedBox(width: 8.w),
                              _buildDot(controller.currentPage.value == 1),
                            ],
                          ),
                        ),

                        SizedBox(height: 16.h),

                        // Animated Content (Subscription vs Referral)
                        Obx(
                          () => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.1),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child:
                                controller.currentPage.value == 0
                                    ? _buildSubscriptionContent(context, controller)
                                    : _buildReferralContent(context, controller),
                          ),
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => print('Terms of Service tapped'),
                              child: Text(
                                context.l10n.termsOfService,
                                style: sfProText400(
                                  12.sp,
                                  const Color.fromRGBO(235, 235, 245, 0.6),
                                ),
                              ),
                            ),
                            SizedBox(width: 20.w),
                            GestureDetector(
                              onTap: () => print('Restore Purchase tapped'),
                              child: Text(
                                context.l10n.restorePurchase,
                                style: sfProText400(
                                  12.sp,
                                  const Color.fromRGBO(235, 235, 245, 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20.h + bottomInset),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32.w,
      height: 6.h,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2.r),
      ),
    );
  }

  Widget _buildSubscriptionContent(BuildContext context, IntroScreen5Controller c) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: const ValueKey('subscription'),
      children: [
        Obx(
          () => c.plansLoading.value
              ? Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: SizedBox(
                    height: 4.h,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Monthly Plan
        GestureDetector(
          onTap: () => c.selectPlan(0),
          child: Obx(
            () => _planCard(
              isSelected: c.selectedPlan.value == 0,
              title: context.l10n.monthly,
              price: c.monthlyPriceLabel.value,
            ),
          ),
        ),

        SizedBox(height: 13.h),

        // Yearly Plan
        GestureDetector(
          onTap: () => c.selectPlan(1),
          child: Obx(
            () => Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.only(
                    left: 16.w,
                    top: 35.h,
                    right: 16.w,
                    bottom: 20.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(47, 46, 51, 1),
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 21.h,
                        width: 21.w,
                        child: Image.asset(
                          c.selectedPlan.value == 1
                              ? 'assets/images/tick.png'
                              : 'assets/icons/loader_icon.png',
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        context.l10n.year,
                        style: sfProText600(17.sp, Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        c.yearlyPriceLabel.value,
                        style: sfProText600(17.sp, Colors.white),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -2.h,
                  child: SizedBox(
                    height: 29.h,
                    width: 110.w,
                    child: Image.asset('assets/images/mostPopular.png'),
                  ),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 14.h),

        // Start Trial Button
        Obx(
          () => GestureDetector(
            onTap: c.isLoading.value ? null : c.startTrial,
            child: Container(
              width: double.infinity,
              height: 52.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8B87E), Color(0xFFD4A574)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(36.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC107).withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Center(
                child:
                    c.isLoading.value
                        ? SizedBox(
                          width: 24.w,
                          height: 24.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : RichText(
                          textAlign: TextAlign.center,
                              text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${context.l10n.startFreeTrial}\n',
                                style: sfProText600(17.sp, Colors.white),
                              ),
                              TextSpan(
                                text: c.selectedPlan.value == 1
                                    ? c.yearlyAfterTrialLabel.value
                                    : c.monthlyAfterTrialLabel.value,
                                style: sfProText400(
                                  12.sp,
                                  const Color.fromRGBO(0, 0, 0, 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Obx(
          () => GestureDetector(
            onTap: c.isLoading.value ? null : c.skipTrial,
            child: Container(
              width: double.infinity,
              height: 52.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30.r),
              ),
              alignment: Alignment.center,
              child: Text(
                context.l10n.skip,
                style: sfProText600(17.sp, Colors.black),
              ),
            ),
          ),
        ),
        SizedBox(height: 13.h),
      ],
    );
  }

  Widget _planCard({
    required bool isSelected,
    required String title,
    required String price,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(47, 46, 51, 1),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 21.h,
            width: 21.w,
            child: Image.asset(
              isSelected
                  ? 'assets/images/tick.png'
                  : 'assets/icons/loader_icon.png',
            ),
          ),
          SizedBox(width: 12.w),
          Text(title, style: sfProText600(17.sp, Colors.white)),
          const Spacer(),
          Text(price, style: sfProText600(17.sp, Colors.white)),
        ],
      ),
    );
  }

  Widget _buildReferralContent(BuildContext context, IntroScreen5Controller c) {
    return Padding(
      key: const ValueKey('referral'),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.inviteFriendAndReceive,
            style: sfProText600(17.sp, Colors.white),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          Container(height: 1.h, color: const Color(0xFF2C2C2E)),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              SizedBox(
                height: 20.h,
                child: Image.asset('assets/images/clap.png'),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${context.l10n.get} ',
                        style: sfProText500(18.sp, Colors.white),
                      ),
                      ShaderMask(
                        shaderCallback:
                            (bounds) => const LinearGradient(
                              colors: [Color(0xFFE8B87E), Color(0xFFE89B7E)],
                            ).createShader(bounds),
                        child: Text(
                          context.l10n.oneMonthFree,
                          style: sfProText600(18.sp, Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                context.l10n.oneTime,
                style: sfProText600(
                  17.sp,
                  const Color.fromRGBO(235, 235, 245, 0.3),
                ),
              ),
            ],
          ),
          SizedBox(height: 30.h),
          GestureDetector(
            onTap: c.copyLink,
            child: Container(
              width: double.infinity,
              height: 52.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE8B87E), Color(0xFFD4A574)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(36.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFC107).withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 16.h,
                    width: 16.w,
                    child: Image.asset('assets/images/copyIcon.png'),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    context.l10n.copyLink,
                    style: sfProText600(17.sp, Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IntroScreen5Controller extends GetxController {
  var isLoading = false.obs;
  var plansLoading = false.obs;
  final RxnString plansError = RxnString();
  var selectedPlan = 1.obs; // 0 = Monthly, 1 = Yearly
  var currentPage = 0.obs;
  final RxString monthlyPriceLabel = '£4.99/month'.obs;
  final RxString yearlyPriceLabel = '£2.99/year'.obs;
  final RxString monthlyAfterTrialLabel = '£4.99/month'.obs;
  final RxString yearlyAfterTrialLabel = '£2.99/year'.obs;
  bool _plansRequested = false;

  final PageController pageController = PageController(initialPage: 0);
  // Track Horizontal Drag Distance
  double _dragDistance = 0.0;

  @override
  void onInit() {
    super.onInit();
    loadPlansIfNeeded();
  }

  void loadPlansIfNeeded({bool force = false}) {
    if (_plansRequested && !force) return;
    _plansRequested = true;
    loadPlans();
  }

  Future<void> loadPlans() async {
    try {
      plansLoading.value = true;
      plansError.value = null;
      final dio = _buildDio();
      print('SUBSCRIPTION PLANS REQUEST: GET /api/v1/subscriptions/plans');
      final res = await dio.get<dynamic>(
        '/api/v1/subscriptions/plans',
      );
      final data = res.data;
      print('SUBSCRIPTION PLANS RESPONSE RAW: $data');
      _applyPlans(data);
      print(
        'SUBSCRIPTION PLANS PARSED: monthly=${monthlyPriceLabel.value}, yearly=${yearlyPriceLabel.value}, '
        'afterMonthly=${monthlyAfterTrialLabel.value}, afterYearly=${yearlyAfterTrialLabel.value}',
      );
    } catch (e) {
      plansError.value = 'Failed to load plans';
      print('SUBSCRIPTION PLANS ERROR: $e');
      if (e is DioException) {
        print('SUBSCRIPTION PLANS ERROR RESPONSE: ${e.response?.data}');
      }
    } finally {
      plansLoading.value = false;
    }
  }

  void _applyPlans(dynamic payload) {
    dynamic data = payload;
    if (data is Map && data['data'] != null) {
      data = data['data'];
    }

    if (data is Map) {
      if (data['plans'] is List) {
        _applyPlansFromList(data['plans'] as List);
        return;
      }
      _applyPlanFromMap('monthly', data['monthly']);
      _applyPlanFromMap('yearly', data['yearly'] ?? data['annual']);
      return;
    }

    if (data is List) {
      _applyPlansFromList(data);
    }
  }

  void _applyPlansFromList(List plans) {
    for (final item in plans) {
      if (item is! Map) continue;
      final planType = _pickString(item, const [
        'id',
        'name',
        'planType',
        'plan_type',
        'type',
        'billingPeriod',
        'billing_period',
        'interval',
        'period',
      ]);
      if (planType == null) continue;
      final price = _extractCardPrice(item, planType);
      if (price != null) {
        _setPlanPrice(planType, price);
      }
      final afterTrial = _extractAfterTrialLabel(item, planType);
      if (afterTrial != null) {
        _setAfterTrialLabel(planType, afterTrial);
      }
    }
  }

  void _applyPlanFromMap(String planType, dynamic plan) {
    if (plan is String) {
      _setPlanPrice(planType, plan);
      _setAfterTrialLabel(planType, plan);
      return;
    }
    if (plan is! Map) return;
    final price = _extractCardPrice(plan, planType);
    if (price != null) _setPlanPrice(planType, price);
    final afterTrial = _extractAfterTrialLabel(plan, planType);
    if (afterTrial != null) _setAfterTrialLabel(planType, afterTrial);
  }

  void _setPlanPrice(String planType, String price) {
    final normalized = _normalizeInterval(planType);
    if (normalized == 'month') {
      monthlyPriceLabel.value = price;
    } else if (normalized == 'year') {
      yearlyPriceLabel.value = price;
    }
  }

  void _setAfterTrialLabel(String planType, String price) {
    final normalized = _normalizeInterval(planType);
    if (normalized == 'month') {
      monthlyAfterTrialLabel.value = price;
    } else if (normalized == 'year') {
      yearlyAfterTrialLabel.value = price;
    }
  }

  String? _extractCardPrice(Map plan, String fallbackType) {
    final description = _pickString(plan, const [
      'description',
      'priceLabel',
      'price_text',
      'priceText',
      'displayPrice',
      'display_price',
    ]);

    if (description != null) {
      return description.trim();
    }

    return _extractPriceLabel(plan, fallbackType);
  }

  String? _extractAfterTrialLabel(Map plan, String fallbackType) {
    final fullDescription = _pickString(plan, const [
      'fullDescription',
      'full_description',
      'afterTrialText',
      'after_trial_text',
    ]);
    if (fullDescription != null) {
      return fullDescription.trim();
    }

    final description = _pickString(plan, const [
      'description',
    ]);
    if (description != null) {
      return description.trim();
    }

    final totalPrice = _pickNum(plan, const [
      'totalPrice',
      'total_price',
    ]);
    if (totalPrice != null) {
      final currency = _pickString(plan, const [
            'currencySymbol',
            'currency_symbol',
          ]) ??
          _currencySymbolFromCode(
            _pickString(plan, const [
              'currency',
              'currencyCode',
              'currency_code',
            ]),
          ) ??
          '£';
      final formatted = totalPrice % 1 == 0
          ? totalPrice.toStringAsFixed(0)
          : totalPrice.toStringAsFixed(2);
      final base = '$currency$formatted';
      final interval = _pickString(plan, const [
            'billingPeriod',
            'billing_period',
          ]) ??
          'year';
      return _appendIntervalIfMissing(base, interval);
    }

    return _extractCardPrice(plan, fallbackType) ??
        _extractPriceLabel(plan, fallbackType);
  }

  String? _extractPriceLabel(Map plan, String fallbackType) {
    final raw = _pickString(plan, const [
      'priceLabel',
      'price_text',
      'priceText',
      'displayPrice',
      'display_price',
      'price',
      'amountFormatted',
      'amount_formatted',
      'pricePerMonth',
      'price_per_month',
      'pricePerYear',
      'price_per_year',
    ]);
    final interval = _pickString(plan, const [
      'interval',
      'period',
      'billingPeriod',
      'billing_period',
      'planType',
      'plan_type',
      'type',
    ]);

    if (raw != null) {
      return _appendIntervalIfMissing(raw, interval ?? fallbackType);
    }

    final amount = _pickNum(plan, const [
      'amount',
      'priceAmount',
      'price_amount',
      'value',
    ]);
    if (amount == null) return null;

    final currency = _pickString(plan, const [
          'currencySymbol',
          'currency_symbol',
        ]) ??
        _currencySymbolFromCode(
          _pickString(plan, const [
            'currency',
            'currencyCode',
            'currency_code',
          ]),
        ) ??
        '£';
    final formatted = amount % 1 == 0
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    final base = '$currency$formatted';
    return _appendIntervalIfMissing(base, interval ?? fallbackType);
  }

  String _appendIntervalIfMissing(String price, String intervalRaw) {
    final trimmed = price.trim();
    if (trimmed.contains('/') || trimmed.contains('per ')) {
      return trimmed;
    }
    final interval = _normalizeInterval(intervalRaw);
    if (interval.isEmpty) return trimmed;
    return '$trimmed/$interval';
  }

  String _normalizeInterval(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('year') || v.contains('annual')) return 'year';
    if (v.contains('month')) return 'month';
    return v;
  }

  String? _currencySymbolFromCode(String? code) {
    if (code == null) return null;
    switch (code.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'EUR':
        return 'â‚¬';
      default:
        return null;
    }
  }

  String? _pickString(Map map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final str = value.toString().trim();
      if (str.isNotEmpty) return str;
    }
    return null;
  }

  double? _pickNum(Map map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  Future<String?> _readAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('second_chat.access_token')?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  void onHorizontalDragStart(DragStartDetails details) {
    _dragDistance = 0.0; // Reset distance
  }

  void onHorizontalDragUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.dx; // Track horizontal movement
  }

  void onHorizontalDragEnd(DragEndDetails details) {
    double velocity = details.primaryVelocity ?? 0;
    double distance = _dragDistance;

    // Thresholds
    double velocityThreshold = 300.0; // Fast swipe speed
    double distanceThreshold = 50.0; // Slow drag distance

    // LOGIC:
    // 1. Swipe LEFT (Negative values) -> Next Page (Page 1)
    if (velocity < -velocityThreshold || distance < -distanceThreshold) {
      switchPage(1);
    }
    // 2. Swipe RIGHT (Positive values) -> Previous Page (Page 0)
    else if (velocity > velocityThreshold || distance > distanceThreshold) {
      switchPage(0);
    }
  }

  void switchPage(int index) {
    if (currentPage.value != index) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutQuart,
      );
    }
  }

  void startTrial() async {
    if (isLoading.value) return;
    isLoading(true);
    try {
      final token = await _readAccessToken();
      if (token == null) {
        final l10n = getAppL10n();
        Get.snackbar(
          l10n?.sessionMissing ?? 'Session missing',
          l10n?.sessionMissingMessage ??
              'Please log in again to start your free trial.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(20),
          backgroundColor: Colors.black.withOpacity(0.7),
          colorText: Colors.white,
        );
        return;
      }
      final dio = _buildDio();
      final res = await dio.post<dynamic>(
        '/api/v1/subscriptions/trial/start',
        data: const {'planType': 'monthly'},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      final data = res.data;
      print('TRIAL START RESPONSE RAW: $data');
      if (data is Map) {
        print('TRIAL START RESPONSE DATA: ${data['data']}');
      }

      final isActive = data is Map &&
          data['success'] == true &&
          data['data'] is Map &&
          data['data']['status']?.toString() == 'active';
      if (isActive) {
        _goToHome();
      } else {
        final l10n = getAppL10n();
        Get.snackbar(
          l10n?.trialNotActive ?? 'Trial not active',
          l10n?.trialNotActiveMessage ??
              'We could not start your free trial. Please try again.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(20),
          backgroundColor: Colors.black.withOpacity(0.7),
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('TRIAL START ERROR: $e');
      if (e is DioException) {
        print('TRIAL START ERROR RESPONSE: ${e.response?.data}');
      }
      final l10n = getAppL10n();
      Get.snackbar(
        l10n?.trialFailed ?? 'Trial failed',
        l10n?.trialFailedMessage ??
            'Unable to start the free trial. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(20),
        backgroundColor: Colors.black.withOpacity(0.7),
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

  void skipTrial() {
    if (isLoading.value) return;
    _goToHome();
  }

  void _goToHome() {
    Get.offAll(
      () => const HomeScreen2(),
      transition: Transition.cupertino,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
    );
  }

  void copyLink() {
    final l10n = getAppL10n();
    Get.snackbar(
      l10n?.success ?? 'Success',
      l10n?.linkCopiedToClipboard ?? 'Link copied to clipboard!',
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(20),
      backgroundColor: Colors.black.withOpacity(0.7),
      colorText: Colors.white,
    );
  }

  void selectPlan(int plan) {
    selectedPlan.value = plan;
  }

  void onPageChanged(int index) {
    currentPage.value = index;
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}

