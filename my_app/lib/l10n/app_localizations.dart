import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('es'),
    Locale('hi'),
    Locale('tr'),
    Locale('ur'),
    Locale('vi'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'A-Network'**
  String get appName;

  /// No description provided for @authPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clean Web2 mining access with secure wallet continuity.'**
  String get authPageSubtitle;

  /// No description provided for @loginTab.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get loginTab;

  /// No description provided for @registerTab.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get registerTab;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailHint;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @antCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Ant Code (Optional)'**
  String get antCodeHint;

  /// No description provided for @continueLoginButton.
  ///
  /// In en, this message translates to:
  /// **'Continue to Login'**
  String get continueLoginButton;

  /// No description provided for @continueRegisterButton.
  ///
  /// In en, this message translates to:
  /// **'Continue to Register'**
  String get continueRegisterButton;

  /// No description provided for @forgotPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPasswordButton;

  /// No description provided for @useExistingAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Use Existing Account Login'**
  String get useExistingAccountButton;

  /// No description provided for @restoreDeletedAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Restore Deleted Account'**
  String get restoreDeletedAccountButton;

  /// No description provided for @sessionModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Session Model'**
  String get sessionModelTitle;

  /// No description provided for @sessionModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mining works in 6-hour cycles and progress syncs to your wallet account.'**
  String get sessionModelSubtitle;

  /// No description provided for @securityLayerTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Layer'**
  String get securityLayerTitle;

  /// No description provided for @securityLayerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Seed phrase, PIN, and account restore protections are built in.'**
  String get securityLayerSubtitle;

  /// No description provided for @emailPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Email and password are required'**
  String get emailPasswordRequired;

  /// No description provided for @deviceLimitError.
  ///
  /// In en, this message translates to:
  /// **'This device already reached the maximum linked accounts. Log in with an existing account, or use a different device to register.'**
  String get deviceLimitError;

  /// No description provided for @accountRestorationEligible.
  ///
  /// In en, this message translates to:
  /// **'Restoration available. Your account was scheduled for deletion.'**
  String get accountRestorationEligible;

  /// No description provided for @openEmailApp.
  ///
  /// In en, this message translates to:
  /// **'Opening email app for info@a-network.net'**
  String get openEmailApp;

  /// No description provided for @emailAppNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Email app not available, support page opened'**
  String get emailAppNotAvailable;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email to receive a 6-digit reset code.'**
  String get forgotPasswordInstructions;

  /// No description provided for @sendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Send Code'**
  String get sendCodeButton;

  /// No description provided for @resendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCodeButton;

  /// No description provided for @sixDigitCodeHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get sixDigitCodeHint;

  /// No description provided for @newPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordHint;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPasswordHint;

  /// No description provided for @resetPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordButton;

  /// No description provided for @needHelpButton.
  ///
  /// In en, this message translates to:
  /// **'Need Help?'**
  String get needHelpButton;

  /// No description provided for @verifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verifyEmailTitle;

  /// No description provided for @verifyEmailInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {email}'**
  String verifyEmailInstructions(String email);

  /// No description provided for @otpCodeHint.
  ///
  /// In en, this message translates to:
  /// **'OTP Code'**
  String get otpCodeHint;

  /// No description provided for @verifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @emailVerificationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Email verification cancelled. Enter your last code later or tap Resend Code for a new one.'**
  String get emailVerificationCancelled;

  /// No description provided for @loginVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Login Verification'**
  String get loginVerificationTitle;

  /// No description provided for @loginVerificationInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit login code sent to {email}'**
  String loginVerificationInstructions(String email);

  /// No description provided for @loginVerificationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Login verification cancelled. Enter your latest code later or request a new one.'**
  String get loginVerificationCancelled;

  /// No description provided for @convertedDeepLink.
  ///
  /// In en, this message translates to:
  /// **'Converted deep link for ANTS Browser'**
  String get convertedDeepLink;

  /// No description provided for @blockedUnsupportedScheme.
  ///
  /// In en, this message translates to:
  /// **'Blocked unsupported scheme: {scheme}'**
  String blockedUnsupportedScheme(String scheme);

  /// No description provided for @untrustedDomainTitle.
  ///
  /// In en, this message translates to:
  /// **'Untrusted Domain'**
  String get untrustedDomainTitle;

  /// No description provided for @untrustedDomainMessage.
  ///
  /// In en, this message translates to:
  /// **'This domain is not on the trusted dApp list:\n\n{host}\n\nURL:\n{url}\n\nOnly continue if you trust this site.'**
  String untrustedDomainMessage(String host, String url);

  /// No description provided for @trustForSessionButton.
  ///
  /// In en, this message translates to:
  /// **'Trust for Session'**
  String get trustForSessionButton;

  /// No description provided for @openDAppPageFirst.
  ///
  /// In en, this message translates to:
  /// **'Open a dApp page first'**
  String get openDAppPageFirst;

  /// No description provided for @connectionBlockedUntrusted.
  ///
  /// In en, this message translates to:
  /// **'Connection blocked for untrusted domain: {host}'**
  String connectionBlockedUntrusted(String host);

  /// No description provided for @connectWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Wallet'**
  String get connectWalletTitle;

  /// No description provided for @connectWalletPrompt.
  ///
  /// In en, this message translates to:
  /// **'dApp: {host}\nNetwork: {network}\nWallet: {address}\n\nGrant session access to read your wallet address and request signatures?'**
  String connectWalletPrompt(String host, String network, String address);

  /// No description provided for @rejectButton.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectButton;

  /// No description provided for @connectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connectButton;

  /// No description provided for @walletConnectedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Wallet connected to {host}'**
  String walletConnectedSnackbar(String host);

  /// No description provided for @walletPINVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet PIN Verification'**
  String get walletPINVerificationTitle;

  /// No description provided for @walletPINInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter your wallet PIN to enable signature requests for 5 minutes.'**
  String get walletPINInstructions;

  /// No description provided for @pinMustBe.
  ///
  /// In en, this message translates to:
  /// **'PIN must be 4 to 8 digits'**
  String get pinMustBe;

  /// No description provided for @verifyingPIN.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifyingPIN;

  /// No description provided for @connectWalletToDApp.
  ///
  /// In en, this message translates to:
  /// **'Connect wallet to a dApp first'**
  String get connectWalletToDApp;

  /// No description provided for @seedPhraseRequired.
  ///
  /// In en, this message translates to:
  /// **'Secure local seed phrase is required for real EVM signing'**
  String get seedPhraseRequired;

  /// No description provided for @signRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Request'**
  String get signRequestTitle;

  /// No description provided for @signRequestContent.
  ///
  /// In en, this message translates to:
  /// **'dApp: {host}\nNetwork: {network}'**
  String signRequestContent(String host, String network);

  /// No description provided for @messageToSign.
  ///
  /// In en, this message translates to:
  /// **'Message to sign'**
  String get messageToSign;

  /// No description provided for @approveSignature.
  ///
  /// In en, this message translates to:
  /// **'I approve this signature request'**
  String get approveSignature;

  /// No description provided for @signButton.
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get signButton;

  /// No description provided for @signatureApprovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Signature Approved'**
  String get signatureApprovedTitle;

  /// No description provided for @copyButton.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyButton;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeButton;

  /// No description provided for @signaturePayloadCopied.
  ///
  /// In en, this message translates to:
  /// **'Signature payload copied'**
  String get signaturePayloadCopied;

  /// No description provided for @antsBrowserTitle.
  ///
  /// In en, this message translates to:
  /// **'ANTS Browser'**
  String get antsBrowserTitle;

  /// No description provided for @connectWalletTooltip.
  ///
  /// In en, this message translates to:
  /// **'Connect wallet'**
  String get connectWalletTooltip;

  /// No description provided for @disconnectTooltip.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectTooltip;

  /// No description provided for @approveSignTooltip.
  ///
  /// In en, this message translates to:
  /// **'Approve sign request'**
  String get approveSignTooltip;

  /// No description provided for @walletNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Wallet not connected. Trusted hosts only. Current: {host}'**
  String walletNotConnected(String host);

  /// No description provided for @walletConnectedStatus.
  ///
  /// In en, this message translates to:
  /// **'Connected: {host} • {network}'**
  String walletConnectedStatus(String host, String network);

  /// No description provided for @enterURL.
  ///
  /// In en, this message translates to:
  /// **'Enter URL'**
  String get enterURL;

  /// No description provided for @goButton.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get goButton;

  /// No description provided for @loadingAISupport.
  ///
  /// In en, this message translates to:
  /// **'Loading AI Support...'**
  String get loadingAISupport;

  /// No description provided for @aiSupportConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to AI Support. Please check your internet connection.'**
  String get aiSupportConnectionError;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @autoRegion.
  ///
  /// In en, this message translates to:
  /// **'Auto (Region)'**
  String get autoRegion;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @hindiLanguage.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get hindiLanguage;

  /// No description provided for @urduLanguage.
  ///
  /// In en, this message translates to:
  /// **'اردو'**
  String get urduLanguage;

  /// No description provided for @chineseLanguage.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get chineseLanguage;

  /// No description provided for @spanishLanguage.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get spanishLanguage;

  /// No description provided for @vietnameseLanguage.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get vietnameseLanguage;

  /// No description provided for @securityLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Security Lock Active'**
  String get securityLockTitle;

  /// No description provided for @securityLockMessage.
  ///
  /// In en, this message translates to:
  /// **'This build detected a high-risk runtime and blocked login, Ant Work, and wallet access to reduce emulator, rooted-device, and tampering abuse.'**
  String get securityLockMessage;

  /// No description provided for @detectedFlags.
  ///
  /// In en, this message translates to:
  /// **'Detected flags: {flags}'**
  String detectedFlags(String flags);

  /// No description provided for @platformRuntime.
  ///
  /// In en, this message translates to:
  /// **'Platform: {platform}  |  Runtime: {runtime}'**
  String platformRuntime(String platform, String runtime);

  /// No description provided for @securityOverrideInfo.
  ///
  /// In en, this message translates to:
  /// **'Use an official release on a physical device. For internal testing only, developers can override this block with --dart-define=ALLOW_INSECURE_DEVICE=true.'**
  String get securityOverrideInfo;

  /// No description provided for @anetGlobal.
  ///
  /// In en, this message translates to:
  /// **'A-Network Global'**
  String get anetGlobal;

  /// No description provided for @globalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Professional network overview, mining status, and wallet visibility.'**
  String get globalSubtitle;

  /// No description provided for @profileSupport.
  ///
  /// In en, this message translates to:
  /// **'Profile & Support'**
  String get profileSupport;

  /// No description provided for @halvingAnnouncementTitle.
  ///
  /// In en, this message translates to:
  /// **'HALVING HAS STARTED'**
  String get halvingAnnouncementTitle;

  /// No description provided for @halvingAnnouncementBody.
  ///
  /// In en, this message translates to:
  /// **'The network has reached the 500,000-session milestone. The first halving is now in effect.'**
  String get halvingAnnouncementBody;

  /// No description provided for @halvingAnnouncementNote.
  ///
  /// In en, this message translates to:
  /// **'There is a 6-hour validation delay before the updated rate is applied. The system validates all pending sessions first. Once the 500k milestone is confirmed, your Live Output will update to the new halving rate automatically.'**
  String get halvingAnnouncementNote;

  /// No description provided for @halvingActionSafe.
  ///
  /// In en, this message translates to:
  /// **'No action required - sessions in progress are safe and will credit at the correct rate.'**
  String get halvingActionSafe;

  /// No description provided for @xAnnouncementTitle.
  ///
  /// In en, this message translates to:
  /// **'LATEST X UPDATE'**
  String get xAnnouncementTitle;

  /// No description provided for @xAnnouncementBody.
  ///
  /// In en, this message translates to:
  /// **'Follow Mr_A_Awakening for the latest official A-Network posts.'**
  String get xAnnouncementBody;

  /// No description provided for @xAnnouncementNote.
  ///
  /// In en, this message translates to:
  /// **'This slide rotates automatically every 60 seconds with the halving update card.'**
  String get xAnnouncementNote;

  /// No description provided for @xAnnouncementCTA.
  ///
  /// In en, this message translates to:
  /// **'Open latest X updates'**
  String get xAnnouncementCTA;

  /// No description provided for @liveStatus.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveStatus;

  /// No description provided for @networkStatus.
  ///
  /// In en, this message translates to:
  /// **'Network Status'**
  String get networkStatus;

  /// No description provided for @totalAnts.
  ///
  /// In en, this message translates to:
  /// **'Total Ants'**
  String get totalAnts;

  /// No description provided for @registered.
  ///
  /// In en, this message translates to:
  /// **'registered'**
  String get registered;

  /// No description provided for @activeWorkers.
  ///
  /// In en, this message translates to:
  /// **'Active Workers'**
  String get activeWorkers;

  /// No description provided for @completedWork.
  ///
  /// In en, this message translates to:
  /// **'completed work'**
  String get completedWork;

  /// No description provided for @activeTerritories.
  ///
  /// In en, this message translates to:
  /// **'Active Territories ({count}+)'**
  String activeTerritories(String count);

  /// No description provided for @verifiedSessions.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED SESSIONS'**
  String get verifiedSessions;

  /// No description provided for @networkThroughput.
  ///
  /// In en, this message translates to:
  /// **'Network throughput'**
  String get networkThroughput;

  /// No description provided for @liveOutput.
  ///
  /// In en, this message translates to:
  /// **'LIVE OUTPUT'**
  String get liveOutput;

  /// No description provided for @anetPerSession.
  ///
  /// In en, this message translates to:
  /// **'ANET / session'**
  String get anetPerSession;

  /// No description provided for @markets.
  ///
  /// In en, this message translates to:
  /// **'MARKETS'**
  String get markets;

  /// No description provided for @activeTerritoriesCount.
  ///
  /// In en, this message translates to:
  /// **'Active territories'**
  String get activeTerritoriesCount;

  /// No description provided for @liveAntWork.
  ///
  /// In en, this message translates to:
  /// **'Live Ant Work'**
  String get liveAntWork;

  /// No description provided for @startingAntWork.
  ///
  /// In en, this message translates to:
  /// **'Starting ant work...'**
  String get startingAntWork;

  /// No description provided for @antWorkActive.
  ///
  /// In en, this message translates to:
  /// **'Ant Work Active'**
  String get antWorkActive;

  /// No description provided for @readyToStart.
  ///
  /// In en, this message translates to:
  /// **'Ready To Start'**
  String get readyToStart;

  /// No description provided for @sessionEndsIn.
  ///
  /// In en, this message translates to:
  /// **'Session ends in {time}'**
  String sessionEndsIn(String time);

  /// No description provided for @startAnyTime.
  ///
  /// In en, this message translates to:
  /// **'Start anytime. The 6-hour timer begins from your tap.'**
  String get startAnyTime;

  /// No description provided for @openAntWork.
  ///
  /// In en, this message translates to:
  /// **'Open Ant Work'**
  String get openAntWork;

  /// No description provided for @startAntWork.
  ///
  /// In en, this message translates to:
  /// **'Start Ant Work'**
  String get startAntWork;

  /// No description provided for @refreshActivity.
  ///
  /// In en, this message translates to:
  /// **'Refresh Activity'**
  String get refreshActivity;

  /// No description provided for @beginJourney.
  ///
  /// In en, this message translates to:
  /// **'Begin your journey'**
  String get beginJourney;

  /// No description provided for @startAntWorkInfo.
  ///
  /// In en, this message translates to:
  /// **'Start a verified 6-hour Ant Work session. Activity is tracked in ANTS first, then becomes claimable in ANET after the required completed-session threshold is reached.'**
  String get startAntWorkInfo;

  /// No description provided for @anetWalletAction.
  ///
  /// In en, this message translates to:
  /// **'ANET Wallet'**
  String get anetWalletAction;

  /// No description provided for @balanceWalletTools.
  ///
  /// In en, this message translates to:
  /// **'Balance, wallet tools, chain visibility'**
  String get balanceWalletTools;

  /// No description provided for @anetWalletInfo.
  ///
  /// In en, this message translates to:
  /// **'Open wallet tools, current balance mapping, and public ecosystem visibility without digging through extra panels.'**
  String get anetWalletInfo;

  /// No description provided for @sessionOutput.
  ///
  /// In en, this message translates to:
  /// **'SESSION OUTPUT'**
  String get sessionOutput;

  /// No description provided for @anetPer6Hour.
  ///
  /// In en, this message translates to:
  /// **'ANET per 6-hour cycle'**
  String get anetPer6Hour;

  /// No description provided for @portfolio.
  ///
  /// In en, this message translates to:
  /// **'PORTFOLIO'**
  String get portfolio;

  /// No description provided for @antsAccumulated.
  ///
  /// In en, this message translates to:
  /// **'ANTS accumulated'**
  String get antsAccumulated;

  /// No description provided for @typeWebsite.
  ///
  /// In en, this message translates to:
  /// **'Type a website or keyword first'**
  String get typeWebsite;

  /// No description provided for @createWalletFirst.
  ///
  /// In en, this message translates to:
  /// **'Create your wallet first'**
  String get createWalletFirst;

  /// No description provided for @walletBalanceSynced.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance synced from mined ANET'**
  String get walletBalanceSynced;

  /// No description provided for @noColonyMessage.
  ///
  /// In en, this message translates to:
  /// **'Your colony is ready. No upline is needed. Pick a colony name and invite ants with your Ant Code.'**
  String get noColonyMessage;

  /// No description provided for @noColonyMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No colony messages yet.'**
  String get noColonyMessagesYet;

  /// No description provided for @myAntCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'My Ant Code Link'**
  String get myAntCodeTitle;

  /// No description provided for @antCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Ant Code: {code}'**
  String antCodeLabel(String code);

  /// No description provided for @referralLinksLabel.
  ///
  /// In en, this message translates to:
  /// **'Referral Links'**
  String get referralLinksLabel;

  /// No description provided for @openGoogleLink.
  ///
  /// In en, this message translates to:
  /// **'Open Google Link'**
  String get openGoogleLink;

  /// No description provided for @openAPKLink.
  ///
  /// In en, this message translates to:
  /// **'Open APK Link'**
  String get openAPKLink;

  /// No description provided for @copyShareText.
  ///
  /// In en, this message translates to:
  /// **'Copy Share Text'**
  String get copyShareText;

  /// No description provided for @colonyTrackerTitle.
  ///
  /// In en, this message translates to:
  /// **'Colony Tracker'**
  String get colonyTrackerTitle;

  /// No description provided for @colonyDescription.
  ///
  /// In en, this message translates to:
  /// **'Colony is the future Web5 community layer. It is view-only for now and stays separate from Web2 mining sessions, ANTS accounting, ANET coin balances, and transfer eligibility.'**
  String get colonyDescription;

  /// No description provided for @operatingModel.
  ///
  /// In en, this message translates to:
  /// **'Operating model: Web2 = Ant Work mining and ANTS accounting. Web3 = BNB Chain visibility and contract references. Web4 = ANET-Chain settlement and transfer visibility. Web5 = community coordination with the ANTS Program and Colony Points. Each layer operates independently and does not overlap in payouts or accounting.'**
  String get operatingModel;

  /// No description provided for @futureAnetCoreNote.
  ///
  /// In en, this message translates to:
  /// **'Future ANET Core note: this account already has a Web3 wallet ready for later partner onboarding. If a future BNB Chain buy-in rule such as 10 USDT equivalent is introduced, it will be enforced separately from mining and separately from colony scoring.'**
  String get futureAnetCoreNote;

  /// No description provided for @futureCorNoteNoWallet.
  ///
  /// In en, this message translates to:
  /// **'Future ANET Core note: later partner onboarding may use a separate Web3 wallet requirement, but no buy-in or buyer gate is enforced in this build.'**
  String get futureCorNoteNoWallet;

  /// No description provided for @yourAntCode.
  ///
  /// In en, this message translates to:
  /// **'Your Ant Code'**
  String get yourAntCode;

  /// No description provided for @directColonyAnts.
  ///
  /// In en, this message translates to:
  /// **'Direct Colony Ants: {count}'**
  String directColonyAnts(String count);

  /// No description provided for @colonyCompleted1K.
  ///
  /// In en, this message translates to:
  /// **'Colony Ants Completed 1k Sessions: {count}'**
  String colonyCompleted1K(String count);

  /// No description provided for @totalColonySessions.
  ///
  /// In en, this message translates to:
  /// **'Total Colony Sessions: {count}'**
  String totalColonySessions(String count);

  /// No description provided for @communityVisibilityOnly.
  ///
  /// In en, this message translates to:
  /// **'Current status: community visibility only. CP, rank, snapshots, and any future controlled distribution previews are separate from ANET coin balances and separate from ANTS accounting.'**
  String get communityVisibilityOnly;

  /// No description provided for @blockchainTransparency.
  ///
  /// In en, this message translates to:
  /// **'Blockchain transparency: users can inspect public chain activity through ANET-Chain. The blockchain view is for transparency and settlement visibility, while colony metrics remain a separate Web5 community view.'**
  String get blockchainTransparency;

  /// No description provided for @yourCompletedSessions.
  ///
  /// In en, this message translates to:
  /// **'Your Completed Sessions: {sessions} / {target}'**
  String yourCompletedSessions(String sessions, String target);

  /// No description provided for @remainingTo1K.
  ///
  /// In en, this message translates to:
  /// **'Remaining to 1k: {remaining}'**
  String remainingTo1K(String remaining);

  /// No description provided for @colonySessionProgress.
  ///
  /// In en, this message translates to:
  /// **'Colony Session Progress'**
  String get colonySessionProgress;

  /// No description provided for @noColonyAnts.
  ///
  /// In en, this message translates to:
  /// **'No colony ants yet.'**
  String get noColonyAnts;

  /// No description provided for @completedSessionsAnt.
  ///
  /// In en, this message translates to:
  /// **'Completed Sessions: {sessions} / 1000'**
  String completedSessionsAnt(String sessions);

  /// No description provided for @qualifiedFor1KMilestone.
  ///
  /// In en, this message translates to:
  /// **'Qualified for 1k milestone'**
  String get qualifiedFor1KMilestone;

  /// No description provided for @copyAntCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get copyAntCode;

  /// No description provided for @shareColony.
  ///
  /// In en, this message translates to:
  /// **'Share Colony'**
  String get shareColony;

  /// No description provided for @copyGoogleLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Google Link'**
  String get copyGoogleLink;

  /// No description provided for @copyAPKLink.
  ///
  /// In en, this message translates to:
  /// **'Copy APK Link'**
  String get copyAPKLink;

  /// No description provided for @seedPhraseBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Seed Phrase Backup'**
  String get seedPhraseBackupTitle;

  /// No description provided for @securityCheckRequired.
  ///
  /// In en, this message translates to:
  /// **'Security check required. Enter your wallet PIN to continue.'**
  String get securityCheckRequired;

  /// No description provided for @walletPINHint.
  ///
  /// In en, this message translates to:
  /// **'Wallet PIN'**
  String get walletPINHint;

  /// No description provided for @sendOTPButton.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOTPButton;

  /// No description provided for @emailOTPHint.
  ///
  /// In en, this message translates to:
  /// **'Email OTP'**
  String get emailOTPHint;

  /// No description provided for @neverSharePhrase.
  ///
  /// In en, this message translates to:
  /// **'Never share this phrase. Anyone with this phrase can control your wallet.'**
  String get neverSharePhrase;

  /// No description provided for @revealButton.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get revealButton;

  /// No description provided for @setWalletPINTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Wallet PIN'**
  String get setWalletPINTitle;

  /// No description provided for @changeWalletPINTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Wallet PIN'**
  String get changeWalletPINTitle;

  /// No description provided for @changePINRequiresOTP.
  ///
  /// In en, this message translates to:
  /// **'Changing PIN requires OTP verification from your registered email.'**
  String get changePINRequiresOTP;

  /// No description provided for @registeredEmail.
  ///
  /// In en, this message translates to:
  /// **'Registered email'**
  String get registeredEmail;

  /// No description provided for @currentPIN.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get currentPIN;

  /// No description provided for @newPINHint.
  ///
  /// In en, this message translates to:
  /// **'New PIN (4-8 digits)'**
  String get newPINHint;

  /// No description provided for @forgotPINButton.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get forgotPINButton;

  /// No description provided for @forgotWalletPINTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Wallet PIN'**
  String get forgotWalletPINTitle;

  /// No description provided for @forgotPINInstructions.
  ///
  /// In en, this message translates to:
  /// **'Reset your wallet PIN through email verification. We will send a 6-digit code to your registered email, then you can create a new PIN.'**
  String get forgotPINInstructions;

  /// No description provided for @sixDigitVerificationCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit verification code'**
  String get sixDigitVerificationCode;

  /// No description provided for @pinResetSuccessful.
  ///
  /// In en, this message translates to:
  /// **'PIN reset successful'**
  String get pinResetSuccessful;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'This will schedule your account for deletion after a safety period.'**
  String get deleteAccountMessage;

  /// No description provided for @enterPINToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN to confirm'**
  String get enterPINToConfirm;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @deletionRequested.
  ///
  /// In en, this message translates to:
  /// **'Deletion requested'**
  String get deletionRequested;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to A-Network'**
  String get welcomeTitle;

  /// No description provided for @tutorialStep1.
  ///
  /// In en, this message translates to:
  /// **'1) Start Ant Work and wait 6 hours to complete one session.'**
  String get tutorialStep1;

  /// No description provided for @tutorialStep2.
  ///
  /// In en, this message translates to:
  /// **'2) You accumulate ANTS first. 100,000,000 ANTS = 1 ANET.'**
  String get tutorialStep2;

  /// No description provided for @tutorialStep3.
  ///
  /// In en, this message translates to:
  /// **'3) Reach 1,000 sessions to become eligible for full ANET conversion features.'**
  String get tutorialStep3;

  /// No description provided for @tutorialStep4.
  ///
  /// In en, this message translates to:
  /// **'4) Protect your wallet: set a PIN and only reveal your seed when needed.'**
  String get tutorialStep4;

  /// No description provided for @gotItButton.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotItButton;

  /// No description provided for @accountProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Profile'**
  String get accountProfileTitle;

  /// No description provided for @levelEligible.
  ///
  /// In en, this message translates to:
  /// **'Level eligibility: Eligible'**
  String get levelEligible;

  /// No description provided for @levelNotEligible.
  ///
  /// In en, this message translates to:
  /// **'Level eligibility: Not yet eligible ({remaining} sessions remaining)'**
  String levelNotEligible(String remaining);

  /// No description provided for @web4MigrationWalletTitle.
  ///
  /// In en, this message translates to:
  /// **'Web4 Migration Wallet'**
  String get web4MigrationWalletTitle;

  /// No description provided for @migrationWalletOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional: put your future Web4 migration wallet address now.'**
  String get migrationWalletOptional;

  /// No description provided for @migrationWalletExample.
  ///
  /// In en, this message translates to:
  /// **'Example: ANET1A2B3C4D5E6F... (ANET + 36 hex chars)'**
  String get migrationWalletExample;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @migrationWalletNotChanged.
  ///
  /// In en, this message translates to:
  /// **'Migration wallet address was not changed'**
  String get migrationWalletNotChanged;

  /// No description provided for @migrationWalletSaved.
  ///
  /// In en, this message translates to:
  /// **'Migration wallet address saved'**
  String get migrationWalletSaved;

  /// No description provided for @changeEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Email'**
  String get changeEmailTitle;

  /// No description provided for @newEmailHint.
  ///
  /// In en, this message translates to:
  /// **'New email'**
  String get newEmailHint;

  /// No description provided for @currentPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPasswordHint;

  /// No description provided for @emailChangedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Email changed successfully'**
  String get emailChangedSuccessfully;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @newPasswordMin8.
  ///
  /// In en, this message translates to:
  /// **'New password (min 8 chars)'**
  String get newPasswordMin8;

  /// No description provided for @passwordChangedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChangedSuccessfully;

  /// No description provided for @securityOwnershipTitle.
  ///
  /// In en, this message translates to:
  /// **'Security & Ownership'**
  String get securityOwnershipTitle;

  /// No description provided for @emailVerificationNote.
  ///
  /// In en, this message translates to:
  /// **'A-Network currently enforces email verification via OTP during registration.'**
  String get emailVerificationNote;

  /// No description provided for @otpVerificationOneTime.
  ///
  /// In en, this message translates to:
  /// **'This OTP verification is one-time only for account activation.'**
  String get otpVerificationOneTime;

  /// No description provided for @emailLossWarning.
  ///
  /// In en, this message translates to:
  /// **'If you lose access to your email and cannot recover it, you lose access to your account and mined ANET.'**
  String get emailLossWarning;

  /// No description provided for @ownershipModel.
  ///
  /// In en, this message translates to:
  /// **'Ownership model: your Email + your created Wallet address = your direct ownership key across the ecosystem.'**
  String get ownershipModel;

  /// No description provided for @web4MigrationKeepSafe.
  ///
  /// In en, this message translates to:
  /// **'For Web4 migration, keep both your email and wallet details safe.'**
  String get web4MigrationKeepSafe;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @antWorkAlertsActive.
  ///
  /// In en, this message translates to:
  /// **'Ant Work alerts are active for the current 6-hour session.'**
  String get antWorkAlertsActive;

  /// No description provided for @startAntWorkNotifications.
  ///
  /// In en, this message translates to:
  /// **'Start Ant Work to schedule the next completion alert.'**
  String get startAntWorkNotifications;

  /// No description provided for @notificationsInfo.
  ///
  /// In en, this message translates to:
  /// **'Notifications are used for verified session reminders, completion timing, and important ecosystem updates. For reliable delivery, keep Android notifications allowed and battery restrictions disabled for A-Network.'**
  String get notificationsInfo;

  /// No description provided for @sessionRunning.
  ///
  /// In en, this message translates to:
  /// **'Current status: session running, completion reminder pending.'**
  String get sessionRunning;

  /// No description provided for @noActiveSession.
  ///
  /// In en, this message translates to:
  /// **'Current status: no active session, so no completion reminder is scheduled yet.'**
  String get noActiveSession;

  /// No description provided for @refreshButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshButton;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose your app language. Auto mode maps region defaults: India → Hindi, Pakistan → Urdu, China → Chinese, Spain/Latin America → Español, Vietnam → Vietnamese, and English fallback for other regions.'**
  String get languageHelp;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About A-Network'**
  String get aboutTitle;

  /// No description provided for @aboutContent.
  ///
  /// In en, this message translates to:
  /// **'A-Network is operated by A Network LLC, California Entity No. 20260170159.\n\nThe production model uses ANTS-first accounting, where 1 ANET = 100,000,000 ANTS. Ant Work runs in validated 6-hour sessions, ANET becomes claimable after the eligibility session threshold is reached, and halving is driven by total verified sessions across the network.\n\nAnt Codes link colony access only. Referrals grow your colony network but do not grant any coin bonuses, session credits, or percentage commissions. Colony Points (CP) are view-only performance metrics. A Network does not guarantee financial returns.'**
  String get aboutContent;

  /// No description provided for @openWeb4Button.
  ///
  /// In en, this message translates to:
  /// **'Open Web4'**
  String get openWeb4Button;

  /// No description provided for @displayThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Display Theme'**
  String get displayThemeTitle;

  /// No description provided for @classicTheme.
  ///
  /// In en, this message translates to:
  /// **'Classic Main Theme'**
  String get classicTheme;

  /// No description provided for @classicThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Existing A-Network cyan presentation.'**
  String get classicThemeDesc;

  /// No description provided for @antsTheme.
  ///
  /// In en, this message translates to:
  /// **'ANTS Ecosystem Theme'**
  String get antsTheme;

  /// No description provided for @antsThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Web4-inspired green, cyan, and gold investor styling.'**
  String get antsThemeDesc;

  /// No description provided for @studioTheme.
  ///
  /// In en, this message translates to:
  /// **'Studio Light Theme'**
  String get studioTheme;

  /// No description provided for @studioThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Professional light backdrop with connected particles and cool blue accents.'**
  String get studioThemeDesc;

  /// No description provided for @executiveTheme.
  ///
  /// In en, this message translates to:
  /// **'Executive Dark Theme'**
  String get executiveTheme;

  /// No description provided for @executiveThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Graphite surfaces with champagne accents for a sharper investor presentation.'**
  String get executiveThemeDesc;

  /// No description provided for @paperTheme.
  ///
  /// In en, this message translates to:
  /// **'Paper Light Theme'**
  String get paperTheme;

  /// No description provided for @paperThemeDesc.
  ///
  /// In en, this message translates to:
  /// **'Warm editorial light styling with ink-blue labels and softer motion.'**
  String get paperThemeDesc;

  /// No description provided for @viewProfileDetails.
  ///
  /// In en, this message translates to:
  /// **'View Profile Details'**
  String get viewProfileDetails;

  /// No description provided for @changeEmail.
  ///
  /// In en, this message translates to:
  /// **'Change Email'**
  String get changeEmail;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logoutButton;

  /// No description provided for @sixHourAntWorkComplete.
  ///
  /// In en, this message translates to:
  /// **'6-hour ant work session complete. Posting your ANET session credit now...'**
  String get sixHourAntWorkComplete;

  /// No description provided for @antWorkCompletedAccumulated.
  ///
  /// In en, this message translates to:
  /// **'✅ Ant Work Completed! You accumulated {reward} ANET'**
  String antWorkCompletedAccumulated(String reward);

  /// No description provided for @antWorkAutoCompleted.
  ///
  /// In en, this message translates to:
  /// **'✅ Ant Work auto-completed. {reward} ANET credited.'**
  String antWorkAutoCompleted(String reward);

  /// No description provided for @antWorkStartedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Ant Work started successfully'**
  String get antWorkStartedSuccessfully;

  /// No description provided for @completeAntWorkFailed.
  ///
  /// In en, this message translates to:
  /// **'Complete Ant Work failed: {error}'**
  String completeAntWorkFailed(String error);

  /// No description provided for @startAntWorkFailed.
  ///
  /// In en, this message translates to:
  /// **'Start Ant Work failed: {error}'**
  String startAntWorkFailed(String error);

  /// No description provided for @territoryOverview.
  ///
  /// In en, this message translates to:
  /// **'Territory Overview'**
  String get territoryOverview;

  /// No description provided for @totalAntsDialog.
  ///
  /// In en, this message translates to:
  /// **'Total Ants'**
  String get totalAntsDialog;

  /// No description provided for @networkShare.
  ///
  /// In en, this message translates to:
  /// **'Network Share'**
  String get networkShare;

  /// No description provided for @activeWorkersDialog.
  ///
  /// In en, this message translates to:
  /// **'Active Workers'**
  String get activeWorkersDialog;

  /// No description provided for @sessionsInTerritory.
  ///
  /// In en, this message translates to:
  /// **'Sessions in Territory'**
  String get sessionsInTerritory;

  /// No description provided for @liveBackendStats.
  ///
  /// In en, this message translates to:
  /// **'Source: live backend country stats.'**
  String get liveBackendStats;

  /// No description provided for @fallbackEstimate.
  ///
  /// In en, this message translates to:
  /// **'Source: fallback estimate. Country stats endpoint unavailable.'**
  String get fallbackEstimate;

  /// No description provided for @web3AnetMarket.
  ///
  /// In en, this message translates to:
  /// **'Web3 ANET Market'**
  String get web3AnetMarket;

  /// No description provided for @marketImportance.
  ///
  /// In en, this message translates to:
  /// **'Important: mined ANET in this app is accumulated through Ant Work. The BNB Chain ANET contract below is the separate Web3 visibility layer and does not directly increase a user\'s in-app ANET coin balance.'**
  String get marketImportance;

  /// No description provided for @bnbChainContract.
  ///
  /// In en, this message translates to:
  /// **'BNB Chain market contract'**
  String get bnbChainContract;

  /// No description provided for @currentSeparation.
  ///
  /// In en, this message translates to:
  /// **'Current separation'**
  String get currentSeparation;

  /// No description provided for @separationPoint1.
  ///
  /// In en, this message translates to:
  /// **'1. ANET coins in this app are accumulated through verified sessions.'**
  String get separationPoint1;

  /// No description provided for @separationPoint2.
  ///
  /// In en, this message translates to:
  /// **'2. The BNB Chain ANET contract and DEX references are separate Web3 visibility tools and future partner-entry references.'**
  String get separationPoint2;

  /// No description provided for @separationPoint3.
  ///
  /// In en, this message translates to:
  /// **'3. Colony, CP, rank, snapshots, and future partner distributions stay outside the ANET and ANTS accounting model.'**
  String get separationPoint3;

  /// No description provided for @separationPoint4.
  ///
  /// In en, this message translates to:
  /// **'4. Full blockchain transparency remains available through ANET-Chain for public settlement and transaction viewing.'**
  String get separationPoint4;

  /// No description provided for @openMarketPair.
  ///
  /// In en, this message translates to:
  /// **'Open Market Pair'**
  String get openMarketPair;

  /// No description provided for @viewLiveChart.
  ///
  /// In en, this message translates to:
  /// **'View Live Chart'**
  String get viewLiveChart;

  /// No description provided for @viewContract.
  ///
  /// In en, this message translates to:
  /// **'View Contract'**
  String get viewContract;

  /// No description provided for @copyContractAddress.
  ///
  /// In en, this message translates to:
  /// **'Copy Contract'**
  String get copyContractAddress;

  /// No description provided for @anetMarketContract.
  ///
  /// In en, this message translates to:
  /// **'ANET market contract'**
  String get anetMarketContract;

  /// No description provided for @moreInfo.
  ///
  /// In en, this message translates to:
  /// **'More info'**
  String get moreInfo;

  /// No description provided for @createYourL1Wallet.
  ///
  /// In en, this message translates to:
  /// **'Create your L1 wallet first'**
  String get createYourL1Wallet;

  /// No description provided for @createL1WalletMessage.
  ///
  /// In en, this message translates to:
  /// **'Your BIP-44 seed is compatible with all EVM wallets.'**
  String get createL1WalletMessage;

  /// No description provided for @generateWallet.
  ///
  /// In en, this message translates to:
  /// **'Generate Wallet'**
  String get generateWallet;

  /// No description provided for @walletLocked.
  ///
  /// In en, this message translates to:
  /// **'Wallet Locked'**
  String get walletLocked;

  /// No description provided for @setPINToContinue.
  ///
  /// In en, this message translates to:
  /// **'Set PIN to Continue'**
  String get setPINToContinue;

  /// No description provided for @enterWalletPIN.
  ///
  /// In en, this message translates to:
  /// **'Enter your wallet PIN to access your Web3 wallet.'**
  String get enterWalletPIN;

  /// No description provided for @setWalletPINAccess.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN to secure your wallet before accessing it.'**
  String get setWalletPINAccess;

  /// No description provided for @unlockWallet.
  ///
  /// In en, this message translates to:
  /// **'Unlock Wallet'**
  String get unlockWallet;

  /// No description provided for @setWalletPINButton.
  ///
  /// In en, this message translates to:
  /// **'Set Wallet PIN'**
  String get setWalletPINButton;

  /// No description provided for @mainnetWallet.
  ///
  /// In en, this message translates to:
  /// **'Mainnet Wallet'**
  String get mainnetWallet;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @assetsTab.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get assetsTab;

  /// No description provided for @activityTab.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTab;

  /// No description provided for @sessionsTab.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessionsTab;

  /// No description provided for @addToken.
  ///
  /// In en, this message translates to:
  /// **'Add Token'**
  String get addToken;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get totalBalance;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In en, this message translates to:
  /// **'Receive'**
  String get receive;

  /// No description provided for @explorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get explorer;

  /// No description provided for @bridge.
  ///
  /// In en, this message translates to:
  /// **'Bridge'**
  String get bridge;

  /// No description provided for @miningProfile.
  ///
  /// In en, this message translates to:
  /// **'Mining Profile'**
  String get miningProfile;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @completedSessions.
  ///
  /// In en, this message translates to:
  /// **'Completed Sessions'**
  String get completedSessions;

  /// No description provided for @anetBalance.
  ///
  /// In en, this message translates to:
  /// **'ANET Balance'**
  String get anetBalance;

  /// No description provided for @currentRate.
  ///
  /// In en, this message translates to:
  /// **'Current Rate'**
  String get currentRate;

  /// No description provided for @colonyJoined.
  ///
  /// In en, this message translates to:
  /// **'Colony Joined'**
  String get colonyJoined;

  /// No description provided for @notInColony.
  ///
  /// In en, this message translates to:
  /// **'Not in a colony'**
  String get notInColony;

  /// No description provided for @sessionHistory.
  ///
  /// In en, this message translates to:
  /// **'Session History'**
  String get sessionHistory;

  /// No description provided for @credited.
  ///
  /// In en, this message translates to:
  /// **'Credited'**
  String get credited;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @aiSupportTitle.
  ///
  /// In en, this message translates to:
  /// **'A-Network AI'**
  String get aiSupportTitle;

  /// No description provided for @trainButton.
  ///
  /// In en, this message translates to:
  /// **'Train'**
  String get trainButton;

  /// No description provided for @web4MigrationPolicy.
  ///
  /// In en, this message translates to:
  /// **'Web4 migration policy'**
  String get web4MigrationPolicy;

  /// No description provided for @anetVsAnts.
  ///
  /// In en, this message translates to:
  /// **'ANET vs ANTS'**
  String get anetVsAnts;

  /// No description provided for @securityWalletSafety.
  ///
  /// In en, this message translates to:
  /// **'Security and wallet safety'**
  String get securityWalletSafety;

  /// No description provided for @trainAITitle.
  ///
  /// In en, this message translates to:
  /// **'Train A-Network AI'**
  String get trainAITitle;

  /// No description provided for @knowledgeHint.
  ///
  /// In en, this message translates to:
  /// **'Knowledge to remember (facts, policies, product details)'**
  String get knowledgeHint;

  /// No description provided for @optionalTrainingPrompt.
  ///
  /// In en, this message translates to:
  /// **'Optional training prompt'**
  String get optionalTrainingPrompt;

  /// No description provided for @optionalIdealResponse.
  ///
  /// In en, this message translates to:
  /// **'Optional ideal response'**
  String get optionalIdealResponse;

  /// No description provided for @addMemoryOrBoth.
  ///
  /// In en, this message translates to:
  /// **'Add memory text, or both training prompt and ideal response.'**
  String get addMemoryOrBoth;

  /// No description provided for @aiTrainingSaved.
  ///
  /// In en, this message translates to:
  /// **'AI training saved'**
  String get aiTrainingSaved;

  /// No description provided for @noAITokensLeft.
  ///
  /// In en, this message translates to:
  /// **'No AI tokens left. Watch an ad for more tokens or wait for 6-hour refill.'**
  String get noAITokensLeft;

  /// No description provided for @voiceRecognitionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice recognition is unavailable on this device'**
  String get voiceRecognitionUnavailable;

  /// No description provided for @noAssistantResponse.
  ///
  /// In en, this message translates to:
  /// **'No assistant response available to read out loud'**
  String get noAssistantResponse;

  /// No description provided for @adNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Ad was not completed. No token reward yet.'**
  String get adNotCompleted;

  /// No description provided for @aiTokensAdded.
  ///
  /// In en, this message translates to:
  /// **'{tokens} AI tokens added. Balance: {balance}'**
  String aiTokensAdded(String tokens, String balance);

  /// No description provided for @uploadedToMemory.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {filename} to AI memory'**
  String uploadedToMemory(String filename);

  /// No description provided for @copiedResponse.
  ///
  /// In en, this message translates to:
  /// **'Copied response'**
  String get copiedResponse;

  /// No description provided for @listeningSpeak.
  ///
  /// In en, this message translates to:
  /// **'Listening... speak your question'**
  String get listeningSpeak;

  /// No description provided for @askAIAnything.
  ///
  /// In en, this message translates to:
  /// **'Ask A-Network AI anything...'**
  String get askAIAnything;

  /// No description provided for @deepResearchEnabled.
  ///
  /// In en, this message translates to:
  /// **'Deep research enabled for next messages'**
  String get deepResearchEnabled;

  /// No description provided for @deepResearchDisabled.
  ///
  /// In en, this message translates to:
  /// **'Deep research disabled'**
  String get deepResearchDisabled;

  /// No description provided for @uploadTxtTooltip.
  ///
  /// In en, this message translates to:
  /// **'Upload txt/md/pdf to train AI'**
  String get uploadTxtTooltip;

  /// No description provided for @stopListeningTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get stopListeningTooltip;

  /// No description provided for @startVoiceInputTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start voice input'**
  String get startVoiceInputTooltip;

  /// No description provided for @stopReadAloudTooltip.
  ///
  /// In en, this message translates to:
  /// **'Stop read aloud'**
  String get stopReadAloudTooltip;

  /// No description provided for @readLatestResponseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Read latest response aloud'**
  String get readLatestResponseTooltip;

  /// No description provided for @watchAdTokens.
  ///
  /// In en, this message translates to:
  /// **'Watch ad + {tokens} tokens'**
  String watchAdTokens(String tokens);

  /// No description provided for @tokenBalance.
  ///
  /// In en, this message translates to:
  /// **'Tokens: {balance}'**
  String tokenBalance(String balance);

  /// No description provided for @pickGroupName.
  ///
  /// In en, this message translates to:
  /// **'Pick Your Group Name'**
  String get pickGroupName;

  /// No description provided for @claimPermanentUpline.
  ///
  /// In en, this message translates to:
  /// **'Claim Permanent Upline'**
  String get claimPermanentUpline;

  /// No description provided for @claimUplineInstructions.
  ///
  /// In en, this message translates to:
  /// **'No upline is required to keep your own colony. Enter an Ant Code here only if you want to permanently join that owner\'s colony instead.'**
  String get claimUplineInstructions;

  /// No description provided for @enterAntCode.
  ///
  /// In en, this message translates to:
  /// **'Enter Ant Code'**
  String get enterAntCode;

  /// No description provided for @claimButton.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claimButton;

  /// No description provided for @antCodeLinked.
  ///
  /// In en, this message translates to:
  /// **'Ant Code linked. Your colony upline is now permanent.'**
  String get antCodeLinked;

  /// No description provided for @writeToColony.
  ///
  /// In en, this message translates to:
  /// **'Write to your colony'**
  String get writeToColony;

  /// No description provided for @writeToUplines.
  ///
  /// In en, this message translates to:
  /// **'Write to your colony uplines'**
  String get writeToUplines;

  /// No description provided for @pickGroupNameTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pick group name'**
  String get pickGroupNameTooltip;

  /// No description provided for @refreshChatTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh chat'**
  String get refreshChatTooltip;

  /// No description provided for @tabEcosystem.
  ///
  /// In en, this message translates to:
  /// **'Ecosystem'**
  String get tabEcosystem;

  /// No description provided for @tabAntWork.
  ///
  /// In en, this message translates to:
  /// **'Ant Work'**
  String get tabAntWork;

  /// No description provided for @tabWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get tabWallet;

  /// No description provided for @tabColony.
  ///
  /// In en, this message translates to:
  /// **'Colony'**
  String get tabColony;

  /// No description provided for @tabMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get tabMore;

  /// No description provided for @pageTitleEcosystem.
  ///
  /// In en, this message translates to:
  /// **'Ant Ecosystem'**
  String get pageTitleEcosystem;

  /// No description provided for @pageTitleAntWork.
  ///
  /// In en, this message translates to:
  /// **'Ant Work'**
  String get pageTitleAntWork;

  /// No description provided for @pageTitleWallet.
  ///
  /// In en, this message translates to:
  /// **'ANET Wallet'**
  String get pageTitleWallet;

  /// No description provided for @pageTitleWeb4.
  ///
  /// In en, this message translates to:
  /// **'Web4'**
  String get pageTitleWeb4;

  /// No description provided for @pageTitleWhitepaper.
  ///
  /// In en, this message translates to:
  /// **'Whitepaper'**
  String get pageTitleWhitepaper;

  /// No description provided for @pageTitleColony.
  ///
  /// In en, this message translates to:
  /// **'Colony (Web5)'**
  String get pageTitleColony;

  /// No description provided for @pageTitleMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get pageTitleMore;

  /// No description provided for @antWorkSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Ant Work'**
  String get antWorkSectionLabel;

  /// No description provided for @morePageTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get morePageTitle;

  /// No description provided for @morePageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Account, legal, support, and display controls in one cleaner place.'**
  String get morePageSubtitle;

  /// No description provided for @walletMenuLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get walletMenuLabel;

  /// No description provided for @walletMenuSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Balance and Web3 tools'**
  String get walletMenuSubtitle;

  /// No description provided for @antWorkHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Ant Work'**
  String get antWorkHeroTitle;

  /// No description provided for @antWorkHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Monitor the live 6-hour session, current output, and the network milestones that matter.'**
  String get antWorkHeroSubtitle;
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
    'en',
    'es',
    'hi',
    'tr',
    'ur',
    'vi',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hi':
      return AppLocalizationsHi();
    case 'tr':
      return AppLocalizationsTr();
    case 'ur':
      return AppLocalizationsUr();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
