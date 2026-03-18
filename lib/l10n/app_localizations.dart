import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
  ];

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @addNewStreamService.
  ///
  /// In en, this message translates to:
  /// **'Add new stream service'**
  String get addNewStreamService;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @allSubscribers.
  ///
  /// In en, this message translates to:
  /// **'All Subscribers'**
  String get allSubscribers;

  /// No description provided for @allInOne.
  ///
  /// In en, this message translates to:
  /// **'All-In-One'**
  String get allInOne;

  /// No description provided for @multichat.
  ///
  /// In en, this message translates to:
  /// **'Multichat'**
  String get multichat;

  /// No description provided for @andASmootherExperience.
  ///
  /// In en, this message translates to:
  /// **'And a smoother experience'**
  String get andASmootherExperience;

  /// No description provided for @buildALongTermHabit.
  ///
  /// In en, this message translates to:
  /// **'Build a long-term habit'**
  String get buildALongTermHabit;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @claimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get claimed;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @colours.
  ///
  /// In en, this message translates to:
  /// **'Colours'**
  String get colours;

  /// No description provided for @connectPlatform.
  ///
  /// In en, this message translates to:
  /// **'Connect Platform'**
  String get connectPlatform;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @codeCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Code copied to clipboard'**
  String get codeCopiedToClipboard;

  /// No description provided for @linkCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard!'**
  String get linkCopiedToClipboard;

  /// No description provided for @customisableStreaks.
  ///
  /// In en, this message translates to:
  /// **'Customisable streaks'**
  String get customisableStreaks;

  /// No description provided for @dayStreak.
  ///
  /// In en, this message translates to:
  /// **'Day Streak'**
  String get dayStreak;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @disconnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Disconnect failed'**
  String get disconnectFailed;

  /// No description provided for @disconnectPlatform.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Platform'**
  String get disconnectPlatform;

  /// No description provided for @disconnectPlatformQuestion.
  ///
  /// In en, this message translates to:
  /// **'Do you want to disconnect this platform?'**
  String get disconnectPlatformQuestion;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @emoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get emoji;

  /// No description provided for @emotesYouUseWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Emotes you use will appear here'**
  String get emotesYouUseWillAppearHere;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get enableNotifications;

  /// No description provided for @newFollowers.
  ///
  /// In en, this message translates to:
  /// **'New Followers'**
  String get newFollowers;

  /// No description provided for @milestoneSubscribers.
  ///
  /// In en, this message translates to:
  /// **'Milestone Subscribers'**
  String get milestoneSubscribers;

  /// No description provided for @enjoyBetterStreaming.
  ///
  /// In en, this message translates to:
  /// **'Enjoy Better Streaming'**
  String get enjoyBetterStreaming;

  /// No description provided for @failedToLoadEmotes.
  ///
  /// In en, this message translates to:
  /// **'Failed to load emotes'**
  String get failedToLoadEmotes;

  /// No description provided for @failedToLoadSettings.
  ///
  /// In en, this message translates to:
  /// **'Failed to load settings'**
  String get failedToLoadSettings;

  /// No description provided for @features.
  ///
  /// In en, this message translates to:
  /// **'Features'**
  String get features;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @get.
  ///
  /// In en, this message translates to:
  /// **'Get'**
  String get get;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @gettingStarted.
  ///
  /// In en, this message translates to:
  /// **'Getting Started'**
  String get gettingStarted;

  /// No description provided for @freezeTagline.
  ///
  /// In en, this message translates to:
  /// **'Go ahead, freeze it. Commitment is overrated anyway.'**
  String get freezeTagline;

  /// No description provided for @ignore.
  ///
  /// In en, this message translates to:
  /// **'Ignore'**
  String get ignore;

  /// No description provided for @invites.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get invites;

  /// No description provided for @invitesLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} invites left'**
  String invitesLeft(Object count);

  /// No description provided for @shareInviteCodesReward.
  ///
  /// In en, this message translates to:
  /// **'Share invite codes with your friends and you will receive:'**
  String get shareInviteCodesReward;

  /// No description provided for @inviteFriendAndReceive.
  ///
  /// In en, this message translates to:
  /// **'Invite a friend and receive'**
  String get inviteFriendAndReceive;

  /// No description provided for @ledSettings.
  ///
  /// In en, this message translates to:
  /// **'LED settings'**
  String get ledSettings;

  /// No description provided for @letsGo.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go'**
  String get letsGo;

  /// No description provided for @loadingEmotes.
  ///
  /// In en, this message translates to:
  /// **'Loading emotes...'**
  String get loadingEmotes;

  /// No description provided for @loadingSettings.
  ///
  /// In en, this message translates to:
  /// **'Loading settings...'**
  String get loadingSettings;

  /// No description provided for @connectionIssue.
  ///
  /// In en, this message translates to:
  /// **'Connection issue'**
  String get connectionIssue;

  /// No description provided for @couldntConnectPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t connect. Please try again.'**
  String get couldntConnectPleaseTryAgain;

  /// No description provided for @couldntOpenLoginPagePleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t open the login page. Please try again.'**
  String get couldntOpenLoginPagePleaseTryAgain;

  /// No description provided for @loginTimedOutPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Login timed out. Please try again.'**
  String get loginTimedOutPleaseTryAgain;

  /// No description provided for @missingAccessToken.
  ///
  /// In en, this message translates to:
  /// **'Missing access token'**
  String get missingAccessToken;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @nameCategory.
  ///
  /// In en, this message translates to:
  /// **'Name Category'**
  String get nameCategory;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noEmotesFound.
  ///
  /// In en, this message translates to:
  /// **'No emotes found'**
  String get noEmotesFound;

  /// No description provided for @noInvitesAvailableRightNow.
  ///
  /// In en, this message translates to:
  /// **'No invites available right now.'**
  String get noInvitesAvailableRightNow;

  /// No description provided for @noRecentEmotes.
  ///
  /// In en, this message translates to:
  /// **'No recent emotes'**
  String get noRecentEmotes;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'⭐ Recent'**
  String get recent;

  /// No description provided for @unexpectedResponseFormat.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response format'**
  String get unexpectedResponseFormat;

  /// No description provided for @oauthHandledInBrowser.
  ///
  /// In en, this message translates to:
  /// **'OAuth is handled in your browser.'**
  String get oauthHandledInBrowser;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @premium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premium;

  /// No description provided for @platformColours.
  ///
  /// In en, this message translates to:
  /// **'Platform Colours'**
  String get platformColours;

  /// No description provided for @platformDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Platform disconnected'**
  String get platformDisconnected;

  /// No description provided for @pleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get pleaseTryAgain;

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchase'**
  String get restorePurchase;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @sessionMissing.
  ///
  /// In en, this message translates to:
  /// **'Session missing'**
  String get sessionMissing;

  /// No description provided for @sessionMissingMessage.
  ///
  /// In en, this message translates to:
  /// **'Please log in again to start your free trial.'**
  String get sessionMissingMessage;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchEmotes.
  ///
  /// In en, this message translates to:
  /// **'Search emotes...'**
  String get searchEmotes;

  /// No description provided for @settingStreakGoalsHelpsYouStayConsistent.
  ///
  /// In en, this message translates to:
  /// **'Setting streak goals helps you stay consistent'**
  String get settingStreakGoalsHelpsYouStayConsistent;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsSectionChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get settingsSectionChat;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsSectionNotifications;

  /// No description provided for @settingsSectionOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get settingsSectionOther;

  /// No description provided for @settingsTitleAnimations.
  ///
  /// In en, this message translates to:
  /// **'Animations'**
  String get settingsTitleAnimations;

  /// No description provided for @settingsTitleAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsTitleAppLanguage;

  /// No description provided for @settingsTitleClock.
  ///
  /// In en, this message translates to:
  /// **'Clock'**
  String get settingsTitleClock;

  /// No description provided for @settingsTitleConnectOtherPlatforms.
  ///
  /// In en, this message translates to:
  /// **'Connect Other Platforms'**
  String get settingsTitleConnectOtherPlatforms;

  /// No description provided for @settingsTitleFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get settingsTitleFontSize;

  /// No description provided for @settingsTitleFullActivityFilters.
  ///
  /// In en, this message translates to:
  /// **'Full Activity Filters'**
  String get settingsTitleFullActivityFilters;

  /// No description provided for @settingsTitleHideViewerNames.
  ///
  /// In en, this message translates to:
  /// **'Hide Viewer Names'**
  String get settingsTitleHideViewerNames;

  /// No description provided for @settingsTitleLedNotifications.
  ///
  /// In en, this message translates to:
  /// **'LED Notifications'**
  String get settingsTitleLedNotifications;

  /// No description provided for @settingsTitleLowPowerMode.
  ///
  /// In en, this message translates to:
  /// **'Low Power Mode'**
  String get settingsTitleLowPowerMode;

  /// No description provided for @settingsTitleMultiChatMergedMode.
  ///
  /// In en, this message translates to:
  /// **'Multi-Chat Merged Mode'**
  String get settingsTitleMultiChatMergedMode;

  /// No description provided for @settingsTitleMultiScreenPreview.
  ///
  /// In en, this message translates to:
  /// **'Multi-Screen Preview'**
  String get settingsTitleMultiScreenPreview;

  /// No description provided for @settingsTitleNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsTitleNotifications;

  /// No description provided for @settingsTitlePlatformColour.
  ///
  /// In en, this message translates to:
  /// **'Platform Colour'**
  String get settingsTitlePlatformColour;

  /// No description provided for @settingsTitleShowSubscribersOnly.
  ///
  /// In en, this message translates to:
  /// **'Show Subscribers Only'**
  String get settingsTitleShowSubscribersOnly;

  /// No description provided for @settingsTitleShowVipModsOnly.
  ///
  /// In en, this message translates to:
  /// **'Show VIP/Mods Only'**
  String get settingsTitleShowVipModsOnly;

  /// No description provided for @settingsTitleTimeZoneDetection.
  ///
  /// In en, this message translates to:
  /// **'Time Zone Detection'**
  String get settingsTitleTimeZoneDetection;

  /// No description provided for @settingsTitleTtsAdvancedSettings.
  ///
  /// In en, this message translates to:
  /// **'TTS Advanced settings'**
  String get settingsTitleTtsAdvancedSettings;

  /// No description provided for @settingsTitleViewerCount.
  ///
  /// In en, this message translates to:
  /// **'Viewer Count'**
  String get settingsTitleViewerCount;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @startMy14DayFreeTrial.
  ///
  /// In en, this message translates to:
  /// **'Start My 14 Day Free Trial'**
  String get startMy14DayFreeTrial;

  /// No description provided for @streakInDangerHitFreezeButton.
  ///
  /// In en, this message translates to:
  /// **'Streak in danger? Hit the freeze button!'**
  String get streakInDangerHitFreezeButton;

  /// No description provided for @streamStreaks.
  ///
  /// In en, this message translates to:
  /// **'Stream Streaks'**
  String get streamStreaks;

  /// No description provided for @streamStreak.
  ///
  /// In en, this message translates to:
  /// **'Stream Streak'**
  String get streamStreak;

  /// No description provided for @subscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe'**
  String get subscribe;

  /// No description provided for @subscribed.
  ///
  /// In en, this message translates to:
  /// **'Subscribed'**
  String get subscribed;

  /// No description provided for @superFanSentYouAMessage.
  ///
  /// In en, this message translates to:
  /// **'SuperFan sent you a message'**
  String get superFanSentYouAMessage;

  /// No description provided for @tapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Tap to retry'**
  String get tapToRetry;

  /// No description provided for @tapToSelectColours.
  ///
  /// In en, this message translates to:
  /// **'Tap to select colours'**
  String get tapToSelectColours;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get text;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @updateAll.
  ///
  /// In en, this message translates to:
  /// **'Update All'**
  String get updateAll;

  /// No description provided for @useOne.
  ///
  /// In en, this message translates to:
  /// **'Use 1'**
  String get useOne;

  /// No description provided for @oneMonthFree.
  ///
  /// In en, this message translates to:
  /// **'1 month Free'**
  String get oneMonthFree;

  /// No description provided for @oneTime.
  ///
  /// In en, this message translates to:
  /// **'1 time'**
  String get oneTime;

  /// No description provided for @threeTimesAWeek.
  ///
  /// In en, this message translates to:
  /// **'3-times a week'**
  String get threeTimesAWeek;

  /// No description provided for @timesAWeek.
  ///
  /// In en, this message translates to:
  /// **'{displayCount}-times a week'**
  String timesAWeek(Object displayCount);

  /// No description provided for @videoFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Video failed to load'**
  String get videoFailedToLoad;

  /// No description provided for @writeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Write a message...'**
  String get writeAMessage;

  /// No description provided for @featureAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get featureAnalytics;

  /// No description provided for @featureAnimatedElements.
  ///
  /// In en, this message translates to:
  /// **'Animated Elements'**
  String get featureAnimatedElements;

  /// No description provided for @featureAdvancedChatFilters.
  ///
  /// In en, this message translates to:
  /// **'Advanced Chat Filters'**
  String get featureAdvancedChatFilters;

  /// No description provided for @featureAdFree.
  ///
  /// In en, this message translates to:
  /// **'Ad Free'**
  String get featureAdFree;

  /// No description provided for @featureActivityFeed.
  ///
  /// In en, this message translates to:
  /// **'Activity Feed'**
  String get featureActivityFeed;

  /// No description provided for @featureAllTitleCategory.
  ///
  /// In en, this message translates to:
  /// **'All Title/Category'**
  String get featureAllTitleCategory;

  /// No description provided for @featureCustomNotification.
  ///
  /// In en, this message translates to:
  /// **'Custom Notification'**
  String get featureCustomNotification;

  /// No description provided for @featureEdgeLedNotification.
  ///
  /// In en, this message translates to:
  /// **'Edge LED Notification'**
  String get featureEdgeLedNotification;

  /// No description provided for @featureEarlyAccessUpdates.
  ///
  /// In en, this message translates to:
  /// **'Early Access Updates'**
  String get featureEarlyAccessUpdates;

  /// No description provided for @featureMultiPlatformChat.
  ///
  /// In en, this message translates to:
  /// **'Multi-Platform Chat'**
  String get featureMultiPlatformChat;

  /// No description provided for @featureMultiStreamMonitor.
  ///
  /// In en, this message translates to:
  /// **'Multi-Stream Monitor'**
  String get featureMultiStreamMonitor;

  /// No description provided for @featureTitleCategoryManage.
  ///
  /// In en, this message translates to:
  /// **'Title/Category Manage'**
  String get featureTitleCategoryManage;

  /// No description provided for @featureMultiChat.
  ///
  /// In en, this message translates to:
  /// **'MultiChat'**
  String get featureMultiChat;

  /// No description provided for @featureReferAFriendRewards.
  ///
  /// In en, this message translates to:
  /// **'Refer a Friend Rewards'**
  String get featureReferAFriendRewards;

  /// No description provided for @featureSupportLevel.
  ///
  /// In en, this message translates to:
  /// **'Support Level'**
  String get featureSupportLevel;

  /// No description provided for @trialFailed.
  ///
  /// In en, this message translates to:
  /// **'Trial failed'**
  String get trialFailed;

  /// No description provided for @trialFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to start the free trial. Please try again.'**
  String get trialFailedMessage;

  /// No description provided for @trialNotActive.
  ///
  /// In en, this message translates to:
  /// **'Trial not active'**
  String get trialNotActive;

  /// No description provided for @trialNotActiveMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not start your free trial. Please try again.'**
  String get trialNotActiveMessage;

  /// No description provided for @pickYourDays.
  ///
  /// In en, this message translates to:
  /// **'Pick your days'**
  String get pickYourDays;

  /// No description provided for @selectExactlyDaysBeforeContinuing.
  ///
  /// In en, this message translates to:
  /// **'Select exactly {count} days before continuing.'**
  String selectExactlyDaysBeforeContinuing(Object count);

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @youVeNeverBeenHotterKeepStreakBurning.
  ///
  /// In en, this message translates to:
  /// **'You’ve never been hotter, keep the streak burning!'**
  String get youVeNeverBeenHotterKeepStreakBurning;

  /// No description provided for @yourPlan.
  ///
  /// In en, this message translates to:
  /// **'Your Plan'**
  String get yourPlan;

  /// No description provided for @freeTrialWorks.
  ///
  /// In en, this message translates to:
  /// **'free trial works'**
  String get freeTrialWorks;

  /// No description provided for @seeMore.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get seeMore;

  /// No description provided for @seeLess.
  ///
  /// In en, this message translates to:
  /// **'See less'**
  String get seeLess;

  /// No description provided for @newFollower.
  ///
  /// In en, this message translates to:
  /// **'New follower'**
  String get newFollower;

  /// No description provided for @megaSupporter.
  ///
  /// In en, this message translates to:
  /// **'Mega supporter'**
  String get megaSupporter;

  /// No description provided for @superFan.
  ///
  /// In en, this message translates to:
  /// **'SuperFan'**
  String get superFan;

  /// No description provided for @titleExample.
  ///
  /// In en, this message translates to:
  /// **'Title example'**
  String get titleExample;

  /// No description provided for @availableLabel.
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get availableLabel;

  /// No description provided for @freezesPerMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'freezes per month'**
  String get freezesPerMonthLabel;

  /// No description provided for @oneMonthFreePremium.
  ///
  /// In en, this message translates to:
  /// **'1 month free Premium'**
  String get oneMonthFreePremium;

  /// No description provided for @homeStreamNotStartedMessage.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t started the\\nstream yet, but in the\\nmeantime you can'**
  String get homeStreamNotStartedMessage;

  /// No description provided for @startFreeTrial.
  ///
  /// In en, this message translates to:
  /// **'Start Free Trial'**
  String get startFreeTrial;

  /// No description provided for @unlockTheFullExperienceWith.
  ///
  /// In en, this message translates to:
  /// **'Unlock the full experience with {premium}'**
  String unlockTheFullExperienceWith(Object premium);

  /// No description provided for @howYourPremiumFreeTrialWorks.
  ///
  /// In en, this message translates to:
  /// **'How your {premium}\\nfree trial works'**
  String howYourPremiumFreeTrialWorks(Object premium);

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Second Chat'**
  String get appName;

  /// No description provided for @notificationCardMessage.
  ///
  /// In en, this message translates to:
  /// **'New features available!'**
  String get notificationCardMessage;

  /// No description provided for @notificationCardTime.
  ///
  /// In en, this message translates to:
  /// **'9:41 AM'**
  String get notificationCardTime;

  /// No description provided for @notificationPermissionDisabledBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications are disabled. You can enable them in system settings.'**
  String get notificationPermissionDisabledBody;

  /// No description provided for @notificationPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification permission not granted.'**
  String get notificationPermissionDenied;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @notificationScreenAnotherTime.
  ///
  /// In en, this message translates to:
  /// **'Another time'**
  String get notificationScreenAnotherTime;

  /// No description provided for @turnOnNotifications.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get turnOnNotifications;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'pt',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
