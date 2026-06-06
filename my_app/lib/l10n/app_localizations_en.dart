// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'A-Network';

  @override
  String get authPageSubtitle =>
      'Clean Web2 mining access with secure wallet continuity.';

  @override
  String get loginTab => 'Log In';

  @override
  String get registerTab => 'Register';

  @override
  String get emailHint => 'Email';

  @override
  String get passwordHint => 'Password';

  @override
  String get antCodeHint => 'Ant Code (Optional)';

  @override
  String get continueLoginButton => 'Continue to Login';

  @override
  String get continueRegisterButton => 'Continue to Register';

  @override
  String get forgotPasswordButton => 'Forgot Password?';

  @override
  String get useExistingAccountButton => 'Use Existing Account Login';

  @override
  String get restoreDeletedAccountButton => 'Restore Deleted Account';

  @override
  String get sessionModelTitle => 'Session Model';

  @override
  String get sessionModelSubtitle =>
      'Mining works in 6-hour cycles and progress syncs to your wallet account.';

  @override
  String get securityLayerTitle => 'Security Layer';

  @override
  String get securityLayerSubtitle =>
      'Seed phrase, PIN, and account restore protections are built in.';

  @override
  String get emailPasswordRequired => 'Email and password are required';

  @override
  String get deviceLimitError =>
      'This device already reached the maximum linked accounts. Log in with an existing account, or use a different device to register.';

  @override
  String get accountRestorationEligible =>
      'Restoration available. Your account was scheduled for deletion.';

  @override
  String get openEmailApp => 'Opening email app for info@a-network.net';

  @override
  String get emailAppNotAvailable =>
      'Email app not available, support page opened';

  @override
  String get forgotPasswordTitle => 'Forgot Password';

  @override
  String get forgotPasswordInstructions =>
      'Enter your registered email to receive a 6-digit reset code.';

  @override
  String get sendCodeButton => 'Send Code';

  @override
  String get resendCodeButton => 'Resend Code';

  @override
  String get sixDigitCodeHint => '6-digit code';

  @override
  String get newPasswordHint => 'New password';

  @override
  String get confirmPasswordHint => 'Confirm new password';

  @override
  String get resetPasswordButton => 'Reset Password';

  @override
  String get needHelpButton => 'Need Help?';

  @override
  String get verifyEmailTitle => 'Verify Email';

  @override
  String verifyEmailInstructions(String email) {
    return 'Enter the 6-digit code sent to $email';
  }

  @override
  String get otpCodeHint => 'OTP Code';

  @override
  String get verifyButton => 'Verify';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get emailVerificationCancelled =>
      'Email verification cancelled. Enter your last code later or tap Resend Code for a new one.';

  @override
  String get loginVerificationTitle => 'Login Verification';

  @override
  String loginVerificationInstructions(String email) {
    return 'Enter the 6-digit login code sent to $email';
  }

  @override
  String get loginVerificationCancelled =>
      'Login verification cancelled. Enter your latest code later or request a new one.';

  @override
  String get convertedDeepLink => 'Converted deep link for ANTS Browser';

  @override
  String blockedUnsupportedScheme(String scheme) {
    return 'Blocked unsupported scheme: $scheme';
  }

  @override
  String get untrustedDomainTitle => 'Untrusted Domain';

  @override
  String untrustedDomainMessage(String host, String url) {
    return 'This domain is not on the trusted dApp list:\n\n$host\n\nURL:\n$url\n\nOnly continue if you trust this site.';
  }

  @override
  String get trustForSessionButton => 'Trust for Session';

  @override
  String get openDAppPageFirst => 'Open a dApp page first';

  @override
  String connectionBlockedUntrusted(String host) {
    return 'Connection blocked for untrusted domain: $host';
  }

  @override
  String get connectWalletTitle => 'Connect Wallet';

  @override
  String connectWalletPrompt(String host, String network, String address) {
    return 'dApp: $host\nNetwork: $network\nWallet: $address\n\nGrant session access to read your wallet address and request signatures?';
  }

  @override
  String get rejectButton => 'Reject';

  @override
  String get connectButton => 'Connect';

  @override
  String walletConnectedSnackbar(String host) {
    return 'Wallet connected to $host';
  }

  @override
  String get walletPINVerificationTitle => 'Wallet PIN Verification';

  @override
  String get walletPINInstructions =>
      'Enter your wallet PIN to enable signature requests for 5 minutes.';

  @override
  String get pinMustBe => 'PIN must be 4 to 8 digits';

  @override
  String get verifyingPIN => 'Verifying...';

  @override
  String get connectWalletToDApp => 'Connect wallet to a dApp first';

  @override
  String get seedPhraseRequired =>
      'Secure local seed phrase is required for real EVM signing';

  @override
  String get signRequestTitle => 'Sign Request';

  @override
  String signRequestContent(String host, String network) {
    return 'dApp: $host\nNetwork: $network';
  }

  @override
  String get messageToSign => 'Message to sign';

  @override
  String get approveSignature => 'I approve this signature request';

  @override
  String get signButton => 'Sign';

  @override
  String get signatureApprovedTitle => 'Signature Approved';

  @override
  String get copyButton => 'Copy';

  @override
  String get closeButton => 'Close';

  @override
  String get signaturePayloadCopied => 'Signature payload copied';

  @override
  String get antsBrowserTitle => 'ANTS Browser';

  @override
  String get connectWalletTooltip => 'Connect wallet';

  @override
  String get disconnectTooltip => 'Disconnect';

  @override
  String get approveSignTooltip => 'Approve sign request';

  @override
  String walletNotConnected(String host) {
    return 'Wallet not connected. Trusted hosts only. Current: $host';
  }

  @override
  String walletConnectedStatus(String host, String network) {
    return 'Connected: $host • $network';
  }

  @override
  String get enterURL => 'Enter URL';

  @override
  String get goButton => 'Go';

  @override
  String get loadingAISupport => 'Loading AI Support...';

  @override
  String get aiSupportConnectionError =>
      'Could not connect to AI Support. Please check your internet connection.';

  @override
  String get retryButton => 'Retry';

  @override
  String get autoRegion => 'Auto (Region)';

  @override
  String get englishLanguage => 'English';

  @override
  String get hindiLanguage => 'हिन्दी';

  @override
  String get urduLanguage => 'اردو';

  @override
  String get chineseLanguage => '中文';

  @override
  String get spanishLanguage => 'Español';

  @override
  String get vietnameseLanguage => 'Tiếng Việt';

  @override
  String get securityLockTitle => 'Security Lock Active';

  @override
  String get securityLockMessage =>
      'This build detected a high-risk runtime and blocked login, Ant Work, and wallet access to reduce emulator, rooted-device, and tampering abuse.';

  @override
  String detectedFlags(String flags) {
    return 'Detected flags: $flags';
  }

  @override
  String platformRuntime(String platform, String runtime) {
    return 'Platform: $platform  |  Runtime: $runtime';
  }

  @override
  String get securityOverrideInfo =>
      'Use an official release on a physical device. For internal testing only, developers can override this block with --dart-define=ALLOW_INSECURE_DEVICE=true.';

  @override
  String get anetGlobal => 'A-Network Global';

  @override
  String get globalSubtitle =>
      'Professional network overview, mining status, and wallet visibility.';

  @override
  String get profileSupport => 'Profile & Support';

  @override
  String get halvingAnnouncementTitle => 'HALVING HAS STARTED';

  @override
  String get halvingAnnouncementBody =>
      'The network has reached the 500,000-session milestone. The first halving is now in effect.';

  @override
  String get halvingAnnouncementNote =>
      'There is a 6-hour validation delay before the updated rate is applied. The system validates all pending sessions first. Once the 500k milestone is confirmed, your Live Output will update to the new halving rate automatically.';

  @override
  String get halvingActionSafe =>
      'No action required - sessions in progress are safe and will credit at the correct rate.';

  @override
  String get xAnnouncementTitle => 'LATEST X UPDATE';

  @override
  String get xAnnouncementBody =>
      'Follow Mr_A_Awakening for the latest official A-Network posts.';

  @override
  String get xAnnouncementNote =>
      'This slide rotates automatically every 60 seconds with the halving update card.';

  @override
  String get xAnnouncementCTA => 'Open latest X updates';

  @override
  String get liveStatus => 'LIVE';

  @override
  String get networkStatus => 'Network Status';

  @override
  String get totalAnts => 'Total Ants';

  @override
  String get registered => 'registered';

  @override
  String get activeWorkers => 'Active Workers';

  @override
  String get completedWork => 'completed work';

  @override
  String activeTerritories(String count) {
    return 'Active Territories ($count+)';
  }

  @override
  String get verifiedSessions => 'VERIFIED SESSIONS';

  @override
  String get networkThroughput => 'Network throughput';

  @override
  String get liveOutput => 'LIVE OUTPUT';

  @override
  String get anetPerSession => 'ANET / session';

  @override
  String get markets => 'MARKETS';

  @override
  String get activeTerritoriesCount => 'Active territories';

  @override
  String get liveAntWork => 'Live Ant Work';

  @override
  String get startingAntWork => 'Starting ant work...';

  @override
  String get antWorkActive => 'Ant Work Active';

  @override
  String get readyToStart => 'Ready To Start';

  @override
  String sessionEndsIn(String time) {
    return 'Session ends in $time';
  }

  @override
  String get startAnyTime =>
      'Start anytime. The 6-hour timer begins from your tap.';

  @override
  String get openAntWork => 'Open Ant Work';

  @override
  String get startAntWork => 'Start Ant Work';

  @override
  String get refreshActivity => 'Refresh Activity';

  @override
  String get beginJourney => 'Begin your journey';

  @override
  String get startAntWorkInfo =>
      'Start a verified 6-hour Ant Work session. Activity is tracked in ANTS first, then becomes claimable in ANET after the required completed-session threshold is reached.';

  @override
  String get anetWalletAction => 'ANET Wallet';

  @override
  String get balanceWalletTools => 'Balance, wallet tools, chain visibility';

  @override
  String get anetWalletInfo =>
      'Open wallet tools, current balance mapping, and public ecosystem visibility without digging through extra panels.';

  @override
  String get sessionOutput => 'SESSION OUTPUT';

  @override
  String get anetPer6Hour => 'ANET per 6-hour cycle';

  @override
  String get portfolio => 'PORTFOLIO';

  @override
  String get antsAccumulated => 'ANTS accumulated';

  @override
  String get typeWebsite => 'Type a website or keyword first';

  @override
  String get createWalletFirst => 'Create your wallet first';

  @override
  String get walletBalanceSynced => 'Wallet balance synced from mined ANET';

  @override
  String get noColonyMessage =>
      'Your colony is ready. No upline is needed. Pick a colony name and invite ants with your Ant Code.';

  @override
  String get noColonyMessagesYet => 'No colony messages yet.';

  @override
  String get myAntCodeTitle => 'My Ant Code Link';

  @override
  String antCodeLabel(String code) {
    return 'Ant Code: $code';
  }

  @override
  String get referralLinksLabel => 'Referral Links';

  @override
  String get openGoogleLink => 'Open Google Link';

  @override
  String get openAPKLink => 'Open APK Link';

  @override
  String get copyShareText => 'Copy Share Text';

  @override
  String get colonyTrackerTitle => 'Colony Tracker';

  @override
  String get colonyDescription =>
      'Colony is the future Web5 community layer. It is view-only for now and stays separate from Web2 mining sessions, ANTS accounting, ANET coin balances, and transfer eligibility.';

  @override
  String get operatingModel =>
      'Operating model: Web2 = Ant Work mining and ANTS accounting. Web3 = BNB Chain visibility and contract references. Web4 = ANET-Chain settlement and transfer visibility. Web5 = community coordination with the ANTS Program and Colony Points. Each layer operates independently and does not overlap in payouts or accounting.';

  @override
  String get futureAnetCoreNote =>
      'Future ANET Core note: this account already has a Web3 wallet ready for later partner onboarding. If a future BNB Chain buy-in rule such as 10 USDT equivalent is introduced, it will be enforced separately from mining and separately from colony scoring.';

  @override
  String get futureCorNoteNoWallet =>
      'Future ANET Core note: later partner onboarding may use a separate Web3 wallet requirement, but no buy-in or buyer gate is enforced in this build.';

  @override
  String get yourAntCode => 'Your Ant Code';

  @override
  String directColonyAnts(String count) {
    return 'Direct Colony Ants: $count';
  }

  @override
  String colonyCompleted1K(String count) {
    return 'Colony Ants Completed 1k Sessions: $count';
  }

  @override
  String totalColonySessions(String count) {
    return 'Total Colony Sessions: $count';
  }

  @override
  String get communityVisibilityOnly =>
      'Current status: community visibility only. CP, rank, snapshots, and any future controlled distribution previews are separate from ANET coin balances and separate from ANTS accounting.';

  @override
  String get blockchainTransparency =>
      'Blockchain transparency: users can inspect public chain activity through ANET-Chain. The blockchain view is for transparency and settlement visibility, while colony metrics remain a separate Web5 community view.';

  @override
  String yourCompletedSessions(String sessions, String target) {
    return 'Your Completed Sessions: $sessions / $target';
  }

  @override
  String remainingTo1K(String remaining) {
    return 'Remaining to 1k: $remaining';
  }

  @override
  String get colonySessionProgress => 'Colony Session Progress';

  @override
  String get noColonyAnts => 'No colony ants yet.';

  @override
  String completedSessionsAnt(String sessions) {
    return 'Completed Sessions: $sessions / 1000';
  }

  @override
  String get qualifiedFor1KMilestone => 'Qualified for 1k milestone';

  @override
  String get copyAntCode => 'Copy Code';

  @override
  String get shareColony => 'Share Colony';

  @override
  String get copyGoogleLink => 'Copy Google Link';

  @override
  String get copyAPKLink => 'Copy APK Link';

  @override
  String get seedPhraseBackupTitle => 'Seed Phrase Backup';

  @override
  String get securityCheckRequired =>
      'Security check required. Enter your wallet PIN to continue.';

  @override
  String get walletPINHint => 'Wallet PIN';

  @override
  String get sendOTPButton => 'Send OTP';

  @override
  String get emailOTPHint => 'Email OTP';

  @override
  String get neverSharePhrase =>
      'Never share this phrase. Anyone with this phrase can control your wallet.';

  @override
  String get revealButton => 'Reveal';

  @override
  String get setWalletPINTitle => 'Set Wallet PIN';

  @override
  String get changeWalletPINTitle => 'Change Wallet PIN';

  @override
  String get changePINRequiresOTP =>
      'Changing PIN requires OTP verification from your registered email.';

  @override
  String get registeredEmail => 'Registered email';

  @override
  String get currentPIN => 'Current PIN';

  @override
  String get newPINHint => 'New PIN (4-8 digits)';

  @override
  String get forgotPINButton => 'Forgot PIN?';

  @override
  String get forgotWalletPINTitle => 'Forgot Wallet PIN';

  @override
  String get forgotPINInstructions =>
      'Reset your wallet PIN through email verification. We will send a 6-digit code to your registered email, then you can create a new PIN.';

  @override
  String get sixDigitVerificationCode => '6-digit verification code';

  @override
  String get pinResetSuccessful => 'PIN reset successful';

  @override
  String get deleteAccountTitle => 'Delete Account';

  @override
  String get deleteAccountMessage =>
      'This will schedule your account for deletion after a safety period.';

  @override
  String get enterPINToConfirm => 'Enter PIN to confirm';

  @override
  String get deleteButton => 'Delete';

  @override
  String get deletionRequested => 'Deletion requested';

  @override
  String get welcomeTitle => 'Welcome to A-Network';

  @override
  String get tutorialStep1 =>
      '1) Start Ant Work and wait 6 hours to complete one session.';

  @override
  String get tutorialStep2 =>
      '2) You accumulate ANTS first. 100,000,000 ANTS = 1 ANET.';

  @override
  String get tutorialStep3 =>
      '3) Reach 1,000 sessions to become eligible for full ANET conversion features.';

  @override
  String get tutorialStep4 =>
      '4) Protect your wallet: set a PIN and only reveal your seed when needed.';

  @override
  String get gotItButton => 'Got it';

  @override
  String get accountProfileTitle => 'Account Profile';

  @override
  String get levelEligible => 'Level eligibility: Eligible';

  @override
  String levelNotEligible(String remaining) {
    return 'Level eligibility: Not yet eligible ($remaining sessions remaining)';
  }

  @override
  String get web4MigrationWalletTitle => 'Web4 Migration Wallet';

  @override
  String get migrationWalletOptional =>
      'Optional: put your future Web4 migration wallet address now.';

  @override
  String get migrationWalletExample =>
      'Example: ANET1A2B3C4D5E6F... (ANET + 36 hex chars)';

  @override
  String get saveButton => 'Save';

  @override
  String get migrationWalletNotChanged =>
      'Migration wallet address was not changed';

  @override
  String get migrationWalletSaved => 'Migration wallet address saved';

  @override
  String get changeEmailTitle => 'Change Email';

  @override
  String get newEmailHint => 'New email';

  @override
  String get currentPasswordHint => 'Current password';

  @override
  String get emailChangedSuccessfully => 'Email changed successfully';

  @override
  String get changePasswordTitle => 'Change Password';

  @override
  String get newPasswordMin8 => 'New password (min 8 chars)';

  @override
  String get passwordChangedSuccessfully => 'Password changed successfully';

  @override
  String get securityOwnershipTitle => 'Security & Ownership';

  @override
  String get emailVerificationNote =>
      'A-Network currently enforces email verification via OTP during registration.';

  @override
  String get otpVerificationOneTime =>
      'This OTP verification is one-time only for account activation.';

  @override
  String get emailLossWarning =>
      'If you lose access to your email and cannot recover it, you lose access to your account and mined ANET.';

  @override
  String get ownershipModel =>
      'Ownership model: your Email + your created Wallet address = your direct ownership key across the ecosystem.';

  @override
  String get web4MigrationKeepSafe =>
      'For Web4 migration, keep both your email and wallet details safe.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get antWorkAlertsActive =>
      'Ant Work alerts are active for the current 6-hour session.';

  @override
  String get startAntWorkNotifications =>
      'Start Ant Work to schedule the next completion alert.';

  @override
  String get notificationsInfo =>
      'Notifications are used for verified session reminders, completion timing, and important ecosystem updates. For reliable delivery, keep Android notifications allowed and battery restrictions disabled for A-Network.';

  @override
  String get sessionRunning =>
      'Current status: session running, completion reminder pending.';

  @override
  String get noActiveSession =>
      'Current status: no active session, so no completion reminder is scheduled yet.';

  @override
  String get refreshButton => 'Refresh';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageHelp =>
      'Choose your app language. Auto mode maps region defaults: India → Hindi, Pakistan → Urdu, China → Chinese, Spain/Latin America → Español, Vietnam → Vietnamese, and English fallback for other regions.';

  @override
  String get aboutTitle => 'About A-Network';

  @override
  String get aboutContent =>
      'A-Network is operated by A Network LLC, California Entity No. 20260170159.\n\nThe production model uses ANTS-first accounting, where 1 ANET = 100,000,000 ANTS. Ant Work runs in validated 6-hour sessions, ANET becomes claimable after the eligibility session threshold is reached, and halving is driven by total verified sessions across the network.\n\nAnt Codes link colony access only. Referrals grow your colony network but do not grant any coin bonuses, session credits, or percentage commissions. Colony Points (CP) are view-only performance metrics. A Network does not guarantee financial returns.';

  @override
  String get openWeb4Button => 'Open Web4';

  @override
  String get displayThemeTitle => 'Display Theme';

  @override
  String get classicTheme => 'Classic Main Theme';

  @override
  String get classicThemeDesc => 'Existing A-Network cyan presentation.';

  @override
  String get antsTheme => 'ANTS Ecosystem Theme';

  @override
  String get antsThemeDesc =>
      'Web4-inspired green, cyan, and gold investor styling.';

  @override
  String get studioTheme => 'Studio Light Theme';

  @override
  String get studioThemeDesc =>
      'Professional light backdrop with connected particles and cool blue accents.';

  @override
  String get executiveTheme => 'Executive Dark Theme';

  @override
  String get executiveThemeDesc =>
      'Graphite surfaces with champagne accents for a sharper investor presentation.';

  @override
  String get paperTheme => 'Paper Light Theme';

  @override
  String get paperThemeDesc =>
      'Warm editorial light styling with ink-blue labels and softer motion.';

  @override
  String get viewProfileDetails => 'View Profile Details';

  @override
  String get changeEmail => 'Change Email';

  @override
  String get changePassword => 'Change Password';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get logoutButton => 'Log out';

  @override
  String get sixHourAntWorkComplete =>
      '6-hour ant work session complete. Posting your ANET session credit now...';

  @override
  String antWorkCompletedAccumulated(String reward) {
    return '✅ Ant Work Completed! You accumulated $reward ANET';
  }

  @override
  String antWorkAutoCompleted(String reward) {
    return '✅ Ant Work auto-completed. $reward ANET credited.';
  }

  @override
  String get antWorkStartedSuccessfully => 'Ant Work started successfully';

  @override
  String completeAntWorkFailed(String error) {
    return 'Complete Ant Work failed: $error';
  }

  @override
  String startAntWorkFailed(String error) {
    return 'Start Ant Work failed: $error';
  }

  @override
  String get territoryOverview => 'Territory Overview';

  @override
  String get totalAntsDialog => 'Total Ants';

  @override
  String get networkShare => 'Network Share';

  @override
  String get activeWorkersDialog => 'Active Workers';

  @override
  String get sessionsInTerritory => 'Sessions in Territory';

  @override
  String get liveBackendStats => 'Source: live backend country stats.';

  @override
  String get fallbackEstimate =>
      'Source: fallback estimate. Country stats endpoint unavailable.';

  @override
  String get web3AnetMarket => 'Web3 ANET Market';

  @override
  String get marketImportance =>
      'Important: mined ANET in this app is accumulated through Ant Work. The BNB Chain ANET contract below is the separate Web3 visibility layer and does not directly increase a user\'s in-app ANET coin balance.';

  @override
  String get bnbChainContract => 'BNB Chain market contract';

  @override
  String get currentSeparation => 'Current separation';

  @override
  String get separationPoint1 =>
      '1. ANET coins in this app are accumulated through verified sessions.';

  @override
  String get separationPoint2 =>
      '2. The BNB Chain ANET contract and DEX references are separate Web3 visibility tools and future partner-entry references.';

  @override
  String get separationPoint3 =>
      '3. Colony, CP, rank, snapshots, and future partner distributions stay outside the ANET and ANTS accounting model.';

  @override
  String get separationPoint4 =>
      '4. Full blockchain transparency remains available through ANET-Chain for public settlement and transaction viewing.';

  @override
  String get openMarketPair => 'Open Market Pair';

  @override
  String get viewLiveChart => 'View Live Chart';

  @override
  String get viewContract => 'View Contract';

  @override
  String get copyContractAddress => 'Copy Contract';

  @override
  String get anetMarketContract => 'ANET market contract';

  @override
  String get moreInfo => 'More info';

  @override
  String get createYourL1Wallet => 'Create your L1 wallet first';

  @override
  String get createL1WalletMessage =>
      'Your BIP-44 seed is compatible with all EVM wallets.';

  @override
  String get generateWallet => 'Generate Wallet';

  @override
  String get walletLocked => 'Wallet Locked';

  @override
  String get setPINToContinue => 'Set PIN to Continue';

  @override
  String get enterWalletPIN =>
      'Enter your wallet PIN to access your Web3 wallet.';

  @override
  String get setWalletPINAccess =>
      'Set a PIN to secure your wallet before accessing it.';

  @override
  String get unlockWallet => 'Unlock Wallet';

  @override
  String get setWalletPINButton => 'Set Wallet PIN';

  @override
  String get mainnetWallet => 'Mainnet Wallet';

  @override
  String get homeTab => 'Home';

  @override
  String get assetsTab => 'Assets';

  @override
  String get activityTab => 'Activity';

  @override
  String get sessionsTab => 'Sessions';

  @override
  String get addToken => 'Add Token';

  @override
  String get totalBalance => 'Total Balance';

  @override
  String get send => 'Send';

  @override
  String get receive => 'Receive';

  @override
  String get explorer => 'Explorer';

  @override
  String get bridge => 'Bridge';

  @override
  String get miningProfile => 'Mining Profile';

  @override
  String get joined => 'Joined';

  @override
  String get completedSessions => 'Completed Sessions';

  @override
  String get anetBalance => 'ANET Balance';

  @override
  String get currentRate => 'Current Rate';

  @override
  String get colonyJoined => 'Colony Joined';

  @override
  String get notInColony => 'Not in a colony';

  @override
  String get sessionHistory => 'Session History';

  @override
  String get credited => 'Credited';

  @override
  String get inProgress => 'In Progress';

  @override
  String get aiSupportTitle => 'A-Network AI';

  @override
  String get trainButton => 'Train';

  @override
  String get web4MigrationPolicy => 'Web4 migration policy';

  @override
  String get anetVsAnts => 'ANET vs ANTS';

  @override
  String get securityWalletSafety => 'Security and wallet safety';

  @override
  String get trainAITitle => 'Train A-Network AI';

  @override
  String get knowledgeHint =>
      'Knowledge to remember (facts, policies, product details)';

  @override
  String get optionalTrainingPrompt => 'Optional training prompt';

  @override
  String get optionalIdealResponse => 'Optional ideal response';

  @override
  String get addMemoryOrBoth =>
      'Add memory text, or both training prompt and ideal response.';

  @override
  String get aiTrainingSaved => 'AI training saved';

  @override
  String get noAITokensLeft =>
      'No AI tokens left. Watch an ad for more tokens or wait for 6-hour refill.';

  @override
  String get voiceRecognitionUnavailable =>
      'Voice recognition is unavailable on this device';

  @override
  String get noAssistantResponse =>
      'No assistant response available to read out loud';

  @override
  String get adNotCompleted => 'Ad was not completed. No token reward yet.';

  @override
  String aiTokensAdded(String tokens, String balance) {
    return '$tokens AI tokens added. Balance: $balance';
  }

  @override
  String uploadedToMemory(String filename) {
    return 'Uploaded $filename to AI memory';
  }

  @override
  String get copiedResponse => 'Copied response';

  @override
  String get listeningSpeak => 'Listening... speak your question';

  @override
  String get askAIAnything => 'Ask A-Network AI anything...';

  @override
  String get deepResearchEnabled => 'Deep research enabled for next messages';

  @override
  String get deepResearchDisabled => 'Deep research disabled';

  @override
  String get uploadTxtTooltip => 'Upload txt/md/pdf to train AI';

  @override
  String get stopListeningTooltip => 'Stop listening';

  @override
  String get startVoiceInputTooltip => 'Start voice input';

  @override
  String get stopReadAloudTooltip => 'Stop read aloud';

  @override
  String get readLatestResponseTooltip => 'Read latest response aloud';

  @override
  String watchAdTokens(String tokens) {
    return 'Watch ad + $tokens tokens';
  }

  @override
  String tokenBalance(String balance) {
    return 'Tokens: $balance';
  }

  @override
  String get pickGroupName => 'Pick Your Group Name';

  @override
  String get claimPermanentUpline => 'Claim Permanent Upline';

  @override
  String get claimUplineInstructions =>
      'No upline is required to keep your own colony. Enter an Ant Code here only if you want to permanently join that owner\'s colony instead.';

  @override
  String get enterAntCode => 'Enter Ant Code';

  @override
  String get claimButton => 'Claim';

  @override
  String get antCodeLinked =>
      'Ant Code linked. Your colony upline is now permanent.';

  @override
  String get writeToColony => 'Write to your colony';

  @override
  String get writeToUplines => 'Write to your colony uplines';

  @override
  String get pickGroupNameTooltip => 'Pick group name';

  @override
  String get refreshChatTooltip => 'Refresh chat';

  @override
  String get tabEcosystem => 'Ecosystem';

  @override
  String get tabAntWork => 'Ant Work';

  @override
  String get tabWallet => 'Wallet';

  @override
  String get tabColony => 'Colony';

  @override
  String get tabMore => 'More';

  @override
  String get pageTitleEcosystem => 'Ant Ecosystem';

  @override
  String get pageTitleAntWork => 'Ant Work';

  @override
  String get pageTitleWallet => 'ANET Wallet';

  @override
  String get pageTitleWeb4 => 'Web4';

  @override
  String get pageTitleWhitepaper => 'Whitepaper';

  @override
  String get pageTitleColony => 'Colony (Web5)';

  @override
  String get pageTitleMore => 'More';

  @override
  String get antWorkSectionLabel => 'Ant Work';

  @override
  String get morePageTitle => 'More';

  @override
  String get morePageSubtitle =>
      'Account, legal, support, and display controls in one cleaner place.';

  @override
  String get walletMenuLabel => 'Wallet';

  @override
  String get walletMenuSubtitle => 'Balance and Web3 tools';

  @override
  String get antWorkHeroTitle => 'Ant Work';

  @override
  String get antWorkHeroSubtitle =>
      'Monitor the live 6-hour session, current output, and the network milestones that matter.';
}
