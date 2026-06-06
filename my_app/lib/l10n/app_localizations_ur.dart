// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Urdu (`ur`).
class AppLocalizationsUr extends AppLocalizations {
  AppLocalizationsUr([String locale = 'ur']) : super(locale);

  @override
  String get appName => 'A-Network';

  @override
  String get authPageSubtitle =>
      'محفوظ والیٹ تسلسل کے ساتھ صاف Web2 مائننگ رسائی۔';

  @override
  String get loginTab => 'لاگ ان';

  @override
  String get registerTab => 'رجسٹر';

  @override
  String get emailHint => 'ای میل';

  @override
  String get passwordHint => 'پاس ورڈ';

  @override
  String get antCodeHint => 'Ant Code (اختیاری)';

  @override
  String get continueLoginButton => 'لاگ ان جاری رکھیں';

  @override
  String get continueRegisterButton => 'رجسٹریشن جاری رکھیں';

  @override
  String get forgotPasswordButton => 'پاس ورڈ بھول گئے؟';

  @override
  String get useExistingAccountButton => 'موجودہ اکاؤنٹ سے لاگ ان کریں';

  @override
  String get restoreDeletedAccountButton => 'حذف شدہ اکاؤنٹ بحال کریں';

  @override
  String get sessionModelTitle => 'سیشن ماڈل';

  @override
  String get sessionModelSubtitle =>
      'مائننگ 6 گھنٹے کے چکروں میں کام کرتی ہے اور پیشرفت آپ کے والیٹ اکاؤنٹ میں مطابقت پذیر ہوتی ہے۔';

  @override
  String get securityLayerTitle => 'سیکیورٹی پرت';

  @override
  String get securityLayerSubtitle =>
      'سیڈ فریز، PIN، اور اکاؤنٹ بحالی کے تحفظات شامل ہیں۔';

  @override
  String get emailPasswordRequired => 'ای میل اور پاس ورڈ ضروری ہیں';

  @override
  String get deviceLimitError =>
      'اس ڈیوائس پر زیادہ سے زیادہ منسلک اکاؤنٹس پہنچ گئے ہیں۔ موجودہ اکاؤنٹ سے لاگ ان کریں، یا رجسٹر کرنے کے لیے مختلف ڈیوائس استعمال کریں۔';

  @override
  String get accountRestorationEligible =>
      'بحالی دستیاب ہے۔ آپ کا اکاؤنٹ حذف کرنے کے لیے شیڈول کیا گیا تھا۔';

  @override
  String get openEmailApp => 'info@a-network.net کے لیے ای میل ایپ کھل رہی ہے';

  @override
  String get emailAppNotAvailable =>
      'ای میل ایپ دستیاب نہیں، سپورٹ صفحہ کھولا گیا';

  @override
  String get forgotPasswordTitle => 'پاس ورڈ بھول گئے';

  @override
  String get forgotPasswordInstructions =>
      '6 ہندسہ ری سیٹ کوڈ حاصل کرنے کے لیے اپنی رجسٹرڈ ای میل درج کریں۔';

  @override
  String get sendCodeButton => 'کوڈ بھیجیں';

  @override
  String get resendCodeButton => 'کوڈ دوبارہ بھیجیں';

  @override
  String get sixDigitCodeHint => '6 ہندسہ کوڈ';

  @override
  String get newPasswordHint => 'نیا پاس ورڈ';

  @override
  String get confirmPasswordHint => 'نئے پاس ورڈ کی تصدیق کریں';

  @override
  String get resetPasswordButton => 'پاس ورڈ ری سیٹ کریں';

  @override
  String get needHelpButton => 'مدد چاہیے؟';

  @override
  String get verifyEmailTitle => 'ای میل تصدیق کریں';

  @override
  String verifyEmailInstructions(String email) {
    return '$email پر بھیجا گیا 6 ہندسہ کوڈ درج کریں';
  }

  @override
  String get otpCodeHint => 'OTP کوڈ';

  @override
  String get verifyButton => 'تصدیق کریں';

  @override
  String get cancelButton => 'منسوخ کریں';

  @override
  String get emailVerificationCancelled =>
      'ای میل تصدیق منسوخ ہوئی۔ بعد میں اپنا آخری کوڈ درج کریں یا نئے کے لیے کوڈ دوبارہ بھیجیں پر ٹیپ کریں۔';

  @override
  String get loginVerificationTitle => 'لاگ ان تصدیق';

  @override
  String loginVerificationInstructions(String email) {
    return '$email پر بھیجا گیا 6 ہندسہ لاگ ان کوڈ درج کریں';
  }

  @override
  String get loginVerificationCancelled =>
      'لاگ ان تصدیق منسوخ ہوئی۔ بعد میں اپنا تازہ ترین کوڈ درج کریں یا نیا درخواست کریں۔';

  @override
  String get convertedDeepLink => 'ANTS Browser کے لیے ڈیپ لنک تبدیل کیا گیا';

  @override
  String blockedUnsupportedScheme(String scheme) {
    return 'غیر تعاون یافتہ اسکیم بلاک ہوئی: $scheme';
  }

  @override
  String get untrustedDomainTitle => 'غیر قابل اعتماد ڈومین';

  @override
  String untrustedDomainMessage(String host, String url) {
    return 'یہ ڈومین قابل اعتماد dApp فہرست میں نہیں ہے:\n\n$host\n\nURL:\n$url\n\nصرف اسی صورت میں جاری رکھیں جب آپ اس سائٹ پر بھروسہ کرتے ہیں۔';
  }

  @override
  String get trustForSessionButton => 'سیشن کے لیے بھروسہ کریں';

  @override
  String get openDAppPageFirst => 'پہلے ایک dApp صفحہ کھولیں';

  @override
  String connectionBlockedUntrusted(String host) {
    return 'غیر قابل اعتماد ڈومین کے لیے کنکشن بلاک ہوا: $host';
  }

  @override
  String get connectWalletTitle => 'والیٹ کنیکٹ کریں';

  @override
  String connectWalletPrompt(String host, String network, String address) {
    return 'dApp: $host\nنیٹ ورک: $network\nوالیٹ: $address\n\nاپنا والیٹ پتہ پڑھنے اور دستخط درخواستوں کے لیے سیشن رسائی دیں؟';
  }

  @override
  String get rejectButton => 'مسترد کریں';

  @override
  String get connectButton => 'کنیکٹ';

  @override
  String walletConnectedSnackbar(String host) {
    return '$host سے والیٹ کنیکٹ ہوا';
  }

  @override
  String get walletPINVerificationTitle => 'والیٹ PIN تصدیق';

  @override
  String get walletPINInstructions =>
      '5 منٹ کے لیے دستخط درخواستوں کو فعال کرنے کے لیے اپنا والیٹ PIN درج کریں۔';

  @override
  String get pinMustBe => 'PIN 4 سے 8 ہندسوں کا ہونا چاہیے';

  @override
  String get verifyingPIN => 'تصدیق ہو رہی ہے...';

  @override
  String get connectWalletToDApp => 'پہلے والیٹ کو dApp سے کنیکٹ کریں';

  @override
  String get seedPhraseRequired =>
      'اصل EVM دستخط کے لیے مقامی سیڈ فریز ضروری ہے';

  @override
  String get signRequestTitle => 'دستخط درخواست';

  @override
  String signRequestContent(String host, String network) {
    return 'dApp: $host\nنیٹ ورک: $network';
  }

  @override
  String get messageToSign => 'دستخط کرنے کا پیغام';

  @override
  String get approveSignature =>
      'میں اس دستخط کی درخواست کی منظوری دیتا/دیتی ہوں';

  @override
  String get signButton => 'دستخط کریں';

  @override
  String get signatureApprovedTitle => 'دستخط منظور';

  @override
  String get copyButton => 'کاپی';

  @override
  String get closeButton => 'بند کریں';

  @override
  String get signaturePayloadCopied => 'دستخط پے لوڈ کاپی ہوا';

  @override
  String get antsBrowserTitle => 'ANTS براؤزر';

  @override
  String get connectWalletTooltip => 'والیٹ کنیکٹ کریں';

  @override
  String get disconnectTooltip => 'منقطع کریں';

  @override
  String get approveSignTooltip => 'دستخط کی درخواست منظور کریں';

  @override
  String walletNotConnected(String host) {
    return 'والیٹ کنیکٹ نہیں۔ صرف قابل اعتماد ہوسٹس۔ موجودہ: $host';
  }

  @override
  String walletConnectedStatus(String host, String network) {
    return 'کنیکٹڈ: $host • $network';
  }

  @override
  String get enterURL => 'URL درج کریں';

  @override
  String get goButton => 'جائیں';

  @override
  String get loadingAISupport => 'AI سپورٹ لوڈ ہو رہی ہے...';

  @override
  String get aiSupportConnectionError =>
      'AI سپورٹ سے کنیکٹ نہیں ہو سکا۔ براہ کرم اپنا انٹرنیٹ کنکشن چیک کریں۔';

  @override
  String get retryButton => 'دوبارہ کوشش کریں';

  @override
  String get autoRegion => 'خودکار (علاقہ)';

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
  String get securityLockTitle => 'سیکیورٹی لاک فعال';

  @override
  String get securityLockMessage =>
      'اس بلڈ نے ہائی رسک رن ٹائم کا پتہ لگایا اور ایمولیٹر، روٹڈ ڈیوائس، اور چھیڑ چھاڑ کے غلط استعمال کو کم کرنے کے لیے لاگ ان، Ant Work، اور والیٹ رسائی کو بلاک کیا۔';

  @override
  String detectedFlags(String flags) {
    return 'پتہ چلے فلیگز: $flags';
  }

  @override
  String platformRuntime(String platform, String runtime) {
    return 'پلیٹ فارم: $platform  |  رن ٹائم: $runtime';
  }

  @override
  String get securityOverrideInfo =>
      'جسمانی ڈیوائس پر سرکاری ریلیز استعمال کریں۔ صرف اندرونی جانچ کے لیے، ڈویلپرز --dart-define=ALLOW_INSECURE_DEVICE=true سے اس بلاک کو اوور رائڈ کر سکتے ہیں۔';

  @override
  String get anetGlobal => 'A-Network گلوبل';

  @override
  String get globalSubtitle =>
      'پیشہ ورانہ نیٹ ورک جائزہ، مائننگ اسٹیٹس، اور والیٹ مرئیت۔';

  @override
  String get profileSupport => 'پروفائل اور سپورٹ';

  @override
  String get halvingAnnouncementTitle => 'ہاونگ شروع ہو گئی ہے';

  @override
  String get halvingAnnouncementBody =>
      'نیٹ ورک 5,00,000 سیشن سنگ میل تک پہنچ گیا ہے۔ پہلی ہاونگ اب نافذ ہے۔';

  @override
  String get halvingAnnouncementNote =>
      'اپ ڈیٹ شدہ شرح لاگو ہونے سے پہلے 6 گھنٹے کی تصدیق تاخیر ہے۔';

  @override
  String get halvingActionSafe =>
      'کوئی کارروائی ضروری نہیں - جاری سیشن محفوظ ہیں اور درست شرح پر کریڈٹ ہوں گے۔';

  @override
  String get xAnnouncementTitle => 'تازہ ترین X اپ ڈیٹ';

  @override
  String get xAnnouncementBody =>
      'تازہ ترین سرکاری A-Network پوسٹس کے لیے Mr_A_Awakening کو فالو کریں۔';

  @override
  String get xAnnouncementNote =>
      'یہ سلائیڈ ہاونگ اپ ڈیٹ کارڈ کے ساتھ ہر 60 سیکنڈ میں خودبخود گھومتی ہے۔';

  @override
  String get xAnnouncementCTA => 'تازہ ترین X اپ ڈیٹس کھولیں';

  @override
  String get liveStatus => 'لائیو';

  @override
  String get networkStatus => 'نیٹ ورک اسٹیٹس';

  @override
  String get totalAnts => 'کل Ants';

  @override
  String get registered => 'رجسٹرڈ';

  @override
  String get activeWorkers => 'فعال کارکن';

  @override
  String get completedWork => 'مکمل کام';

  @override
  String activeTerritories(String count) {
    return 'فعال علاقے ($count+)';
  }

  @override
  String get verifiedSessions => 'تصدیق شدہ سیشنز';

  @override
  String get networkThroughput => 'نیٹ ورک تھروپٹ';

  @override
  String get liveOutput => 'لائیو آؤٹ پٹ';

  @override
  String get anetPerSession => 'ANET / سیشن';

  @override
  String get markets => 'مارکیٹس';

  @override
  String get activeTerritoriesCount => 'فعال علاقے';

  @override
  String get liveAntWork => 'لائیو Ant Work';

  @override
  String get startingAntWork => 'ant work شروع ہو رہا ہے...';

  @override
  String get antWorkActive => 'Ant Work فعال';

  @override
  String get readyToStart => 'شروع کرنے کے لیے تیار';

  @override
  String sessionEndsIn(String time) {
    return 'سیشن $time میں ختم ہوگا';
  }

  @override
  String get startAnyTime =>
      'کبھی بھی شروع کریں۔ 6 گھنٹے کا ٹائمر آپ کے ٹیپ سے شروع ہوتا ہے۔';

  @override
  String get openAntWork => 'Ant Work کھولیں';

  @override
  String get startAntWork => 'Ant Work شروع کریں';

  @override
  String get refreshActivity => 'سرگرمی ریفریش کریں';

  @override
  String get beginJourney => 'اپنا سفر شروع کریں';

  @override
  String get startAntWorkInfo =>
      'ایک تصدیق شدہ 6 گھنٹے کا Ant Work سیشن شروع کریں۔';

  @override
  String get anetWalletAction => 'ANET والیٹ';

  @override
  String get balanceWalletTools => 'بیلنس، والیٹ ٹولز، چین مرئیت';

  @override
  String get anetWalletInfo =>
      'والیٹ ٹولز، موجودہ بیلنس میپنگ، اور عوامی ایکو سسٹم مرئیت کھولیں۔';

  @override
  String get sessionOutput => 'سیشن آؤٹ پٹ';

  @override
  String get anetPer6Hour => 'ANET فی 6 گھنٹے کا چکر';

  @override
  String get portfolio => 'پورٹ فولیو';

  @override
  String get antsAccumulated => 'ANTS جمع';

  @override
  String get typeWebsite => 'پہلے کوئی ویب سائٹ یا کی ورڈ ٹائپ کریں';

  @override
  String get createWalletFirst => 'پہلے اپنا والیٹ بنائیں';

  @override
  String get walletBalanceSynced =>
      'مائن کیے گئے ANET سے والیٹ بیلنس مطابقت پذیر ہوا';

  @override
  String get noColonyMessage =>
      'آپ کی کالونی تیار ہے۔ کوئی اپ لائن ضروری نہیں۔ کالونی کا نام چنیں اور اپنے Ant Code سے ants کو مدعو کریں۔';

  @override
  String get noColonyMessagesYet => 'ابھی تک کوئی کالونی پیغامات نہیں۔';

  @override
  String get myAntCodeTitle => 'میرا Ant Code لنک';

  @override
  String antCodeLabel(String code) {
    return 'Ant Code: $code';
  }

  @override
  String get referralLinksLabel => 'ریفرل لنکس';

  @override
  String get openGoogleLink => 'Google لنک کھولیں';

  @override
  String get openAPKLink => 'APK لنک کھولیں';

  @override
  String get copyShareText => 'شیئر ٹیکسٹ کاپی کریں';

  @override
  String get colonyTrackerTitle => 'کالونی ٹریکر';

  @override
  String get colonyDescription =>
      'کالونی مستقبل کی Web5 کمیونٹی پرت ہے۔ ابھی کے لیے صرف دیکھنے کے قابل ہے۔';

  @override
  String get operatingModel =>
      'آپریٹنگ ماڈل: Web2 = Ant Work مائننگ۔ Web3 = BNB Chain مرئیت۔ Web4 = ANET-Chain سیٹلمنٹ۔ Web5 = ANTS Program کے ساتھ کمیونٹی۔';

  @override
  String get futureAnetCoreNote =>
      'مستقبل کا ANET Core نوٹ: اس اکاؤنٹ میں بعد کے پارٹنر آن بورڈنگ کے لیے پہلے سے Web3 والیٹ تیار ہے۔';

  @override
  String get futureCorNoteNoWallet =>
      'مستقبل کا ANET Core نوٹ: بعد کی پارٹنر آن بورڈنگ میں الگ Web3 والیٹ کی ضرورت ہو سکتی ہے، لیکن اس بلڈ میں کوئی buy-in نافذ نہیں ہے۔';

  @override
  String get yourAntCode => 'آپ کا Ant Code';

  @override
  String directColonyAnts(String count) {
    return 'براہ راست کالونی Ants: $count';
  }

  @override
  String colonyCompleted1K(String count) {
    return 'کالونی Ants نے 1k سیشنز مکمل کیے: $count';
  }

  @override
  String totalColonySessions(String count) {
    return 'کل کالونی سیشنز: $count';
  }

  @override
  String get communityVisibilityOnly =>
      'موجودہ اسٹیٹس: صرف کمیونٹی مرئیت۔ CP، رینک، سنیپ شاٹس ANET بیلنس سے الگ ہیں۔';

  @override
  String get blockchainTransparency =>
      'بلاک چین شفافیت: صارفین ANET-Chain کے ذریعے عوامی چین سرگرمی دیکھ سکتے ہیں۔';

  @override
  String yourCompletedSessions(String sessions, String target) {
    return 'آپ کے مکمل سیشنز: $sessions / $target';
  }

  @override
  String remainingTo1K(String remaining) {
    return '1k تک باقی: $remaining';
  }

  @override
  String get colonySessionProgress => 'کالونی سیشن پیشرفت';

  @override
  String get noColonyAnts => 'ابھی تک کوئی کالونی ants نہیں۔';

  @override
  String completedSessionsAnt(String sessions) {
    return 'مکمل سیشنز: $sessions / 1000';
  }

  @override
  String get qualifiedFor1KMilestone => '1k سنگ میل کے لیے اہل';

  @override
  String get copyAntCode => 'کوڈ کاپی کریں';

  @override
  String get shareColony => 'کالونی شیئر کریں';

  @override
  String get copyGoogleLink => 'Google لنک کاپی کریں';

  @override
  String get copyAPKLink => 'APK لنک کاپی کریں';

  @override
  String get seedPhraseBackupTitle => 'سیڈ فریز بیک اپ';

  @override
  String get securityCheckRequired =>
      'سیکیورٹی چیک ضروری۔ جاری رکھنے کے لیے اپنا والیٹ PIN درج کریں۔';

  @override
  String get walletPINHint => 'والیٹ PIN';

  @override
  String get sendOTPButton => 'OTP بھیجیں';

  @override
  String get emailOTPHint => 'ای میل OTP';

  @override
  String get neverSharePhrase =>
      'یہ فریز کبھی شیئر نہ کریں۔ اس فریز والا کوئی بھی آپ کے والیٹ کو کنٹرول کر سکتا ہے۔';

  @override
  String get revealButton => 'ظاہر کریں';

  @override
  String get setWalletPINTitle => 'والیٹ PIN سیٹ کریں';

  @override
  String get changeWalletPINTitle => 'والیٹ PIN تبدیل کریں';

  @override
  String get changePINRequiresOTP =>
      'PIN تبدیل کرنے کے لیے آپ کی رجسٹرڈ ای میل سے OTP تصدیق ضروری ہے۔';

  @override
  String get registeredEmail => 'رجسٹرڈ ای میل';

  @override
  String get currentPIN => 'موجودہ PIN';

  @override
  String get newPINHint => 'نیا PIN (4-8 ہندسے)';

  @override
  String get forgotPINButton => 'PIN بھول گئے؟';

  @override
  String get forgotWalletPINTitle => 'والیٹ PIN بھول گئے';

  @override
  String get forgotPINInstructions =>
      'ای میل تصدیق کے ذریعے اپنا والیٹ PIN ری سیٹ کریں۔ ہم آپ کی رجسٹرڈ ای میل پر 6 ہندسہ کوڈ بھیجیں گے۔';

  @override
  String get sixDigitVerificationCode => '6 ہندسہ تصدیقی کوڈ';

  @override
  String get pinResetSuccessful => 'PIN کامیابی سے ری سیٹ ہوا';

  @override
  String get deleteAccountTitle => 'اکاؤنٹ حذف کریں';

  @override
  String get deleteAccountMessage =>
      'یہ حفاظتی مدت کے بعد آپ کے اکاؤنٹ کو حذف کرنے کے لیے شیڈول کرے گا۔';

  @override
  String get enterPINToConfirm => 'تصدیق کے لیے PIN درج کریں';

  @override
  String get deleteButton => 'حذف کریں';

  @override
  String get deletionRequested => 'حذف کرنے کی درخواست کی گئی';

  @override
  String get welcomeTitle => 'A-Network میں خوش آمدید';

  @override
  String get tutorialStep1 =>
      '1) Ant Work شروع کریں اور ایک سیشن مکمل کرنے کے لیے 6 گھنٹے انتظار کریں۔';

  @override
  String get tutorialStep2 =>
      '2) آپ پہلے ANTS جمع کرتے ہیں۔ 100,000,000 ANTS = 1 ANET۔';

  @override
  String get tutorialStep3 =>
      '3) مکمل ANET تبدیلی خصوصیات کے لیے اہل ہونے کے لیے 1,000 سیشنز تک پہنچیں۔';

  @override
  String get tutorialStep4 =>
      '4) اپنے والیٹ کی حفاظت کریں: PIN سیٹ کریں اور صرف ضرورت پر سیڈ ظاہر کریں۔';

  @override
  String get gotItButton => 'سمجھ گیا';

  @override
  String get accountProfileTitle => 'اکاؤنٹ پروفائل';

  @override
  String get levelEligible => 'لیول اہلیت: اہل';

  @override
  String levelNotEligible(String remaining) {
    return 'لیول اہلیت: ابھی اہل نہیں ($remaining سیشنز باقی)';
  }

  @override
  String get web4MigrationWalletTitle => 'Web4 مائیگریشن والیٹ';

  @override
  String get migrationWalletOptional =>
      'اختیاری: ابھی اپنا مستقبل کا Web4 مائیگریشن والیٹ پتہ ڈالیں۔';

  @override
  String get migrationWalletExample =>
      'مثال: ANET1A2B3C4D5E6F... (ANET + 36 hex حروف)';

  @override
  String get saveButton => 'محفوظ کریں';

  @override
  String get migrationWalletNotChanged => 'مائیگریشن والیٹ پتہ تبدیل نہیں ہوا';

  @override
  String get migrationWalletSaved => 'مائیگریشن والیٹ پتہ محفوظ ہوا';

  @override
  String get changeEmailTitle => 'ای میل تبدیل کریں';

  @override
  String get newEmailHint => 'نئی ای میل';

  @override
  String get currentPasswordHint => 'موجودہ پاس ورڈ';

  @override
  String get emailChangedSuccessfully => 'ای میل کامیابی سے تبدیل ہوئی';

  @override
  String get changePasswordTitle => 'پاس ورڈ تبدیل کریں';

  @override
  String get newPasswordMin8 => 'نیا پاس ورڈ (کم از کم 8 حروف)';

  @override
  String get passwordChangedSuccessfully => 'پاس ورڈ کامیابی سے تبدیل ہوا';

  @override
  String get securityOwnershipTitle => 'سیکیورٹی اور ملکیت';

  @override
  String get emailVerificationNote =>
      'A-Network فی الحال رجسٹریشن کے دوران OTP کے ذریعے ای میل تصدیق نافذ کرتا ہے۔';

  @override
  String get otpVerificationOneTime =>
      'یہ OTP تصدیق صرف اکاؤنٹ ایکٹیویشن کے لیے ایک بار ہے۔';

  @override
  String get emailLossWarning =>
      'اگر آپ اپنی ای میل تک رسائی کھو دیتے ہیں اور اسے بازیاب نہیں کر سکتے، تو آپ اپنے اکاؤنٹ اور مائن کیے گئے ANET تک رسائی کھو دیتے ہیں۔';

  @override
  String get ownershipModel =>
      'ملکیت ماڈل: آپ کی ای میل + آپ کا بنایا گیا والیٹ پتہ = ایکو سسٹم میں آپ کی براہ راست ملکیت کلید۔';

  @override
  String get web4MigrationKeepSafe =>
      'Web4 مائیگریشن کے لیے، اپنی ای میل اور والیٹ تفصیلات دونوں محفوظ رکھیں۔';

  @override
  String get notificationsTitle => 'اطلاعات';

  @override
  String get antWorkAlertsActive =>
      'موجودہ 6 گھنٹے کے سیشن کے لیے Ant Work الرٹس فعال ہیں۔';

  @override
  String get startAntWorkNotifications =>
      'اگلے تکمیلی الرٹ کو شیڈول کرنے کے لیے Ant Work شروع کریں۔';

  @override
  String get notificationsInfo =>
      'اطلاعات تصدیق شدہ سیشن یاد دہانیوں، تکمیل کے وقت اور اہم ایکو سسٹم اپ ڈیٹس کے لیے استعمال ہوتی ہیں۔';

  @override
  String get sessionRunning =>
      'موجودہ اسٹیٹس: سیشن چل رہا ہے، تکمیلی یاد دہانی زیر التواء۔';

  @override
  String get noActiveSession =>
      'موجودہ اسٹیٹس: کوئی فعال سیشن نہیں، اس لیے ابھی تک کوئی تکمیلی یاد دہانی شیڈول نہیں ہے۔';

  @override
  String get refreshButton => 'ریفریش';

  @override
  String get languageTitle => 'زبان';

  @override
  String get languageHelp =>
      'اپنی ایپ زبان منتخب کریں۔ خودکار موڈ علاقائی پہلے سے طے شدہ زبانیں ترتیب دیتا ہے: بھارت → ہندی، پاکستان → اردو۔';

  @override
  String get aboutTitle => 'A-Network کے بارے میں';

  @override
  String get aboutContent =>
      'A-Network کا آپریشن A Network LLC، California Entity No. 20260170159 کرتا ہے۔\n\nپروڈکشن ماڈل ANTS-پہلے اکاؤنٹنگ استعمال کرتا ہے، جہاں 1 ANET = 100,000,000 ANTS۔';

  @override
  String get openWeb4Button => 'Web4 کھولیں';

  @override
  String get displayThemeTitle => 'ڈسپلے تھیم';

  @override
  String get classicTheme => 'کلاسک مین تھیم';

  @override
  String get classicThemeDesc => 'موجودہ A-Network cyan پریزنٹیشن۔';

  @override
  String get antsTheme => 'ANTS ایکو سسٹم تھیم';

  @override
  String get antsThemeDesc =>
      'Web4 سے متاثر سبز، cyan، اور سونا سرمایہ کار اسٹائلنگ۔';

  @override
  String get studioTheme => 'اسٹوڈیو لائٹ تھیم';

  @override
  String get studioThemeDesc =>
      'کنیکٹڈ پارٹیکلز کے ساتھ پیشہ ورانہ لائٹ بیک ڈراپ۔';

  @override
  String get executiveTheme => 'ایگزیکٹو ڈارک تھیم';

  @override
  String get executiveThemeDesc =>
      'شارپ سرمایہ کار پریزنٹیشن کے لیے شیمپین ایکسنٹس کے ساتھ گریفائٹ سرفیسز۔';

  @override
  String get paperTheme => 'پیپر لائٹ تھیم';

  @override
  String get paperThemeDesc =>
      'انک-بلیو لیبلز کے ساتھ گرم ایڈیٹوریل لائٹ اسٹائلنگ۔';

  @override
  String get viewProfileDetails => 'پروفائل تفصیلات دیکھیں';

  @override
  String get changeEmail => 'ای میل تبدیل کریں';

  @override
  String get changePassword => 'پاس ورڈ تبدیل کریں';

  @override
  String get helpSupport => 'مدد اور سپورٹ';

  @override
  String get logoutButton => 'لاگ آؤٹ';

  @override
  String get sixHourAntWorkComplete =>
      '6 گھنٹے کا ant work سیشن مکمل ہوا۔ آپ کا ANET سیشن کریڈٹ پوسٹ ہو رہا ہے...';

  @override
  String antWorkCompletedAccumulated(String reward) {
    return '✅ Ant Work مکمل ہوا! آپ نے $reward ANET جمع کیے';
  }

  @override
  String antWorkAutoCompleted(String reward) {
    return '✅ Ant Work خودبخود مکمل ہوا۔ $reward ANET کریڈٹ ہوا۔';
  }

  @override
  String get antWorkStartedSuccessfully => 'Ant Work کامیابی سے شروع ہوا';

  @override
  String completeAntWorkFailed(String error) {
    return 'Ant Work مکمل کرنے میں ناکامی: $error';
  }

  @override
  String startAntWorkFailed(String error) {
    return 'Ant Work شروع کرنے میں ناکامی: $error';
  }

  @override
  String get territoryOverview => 'علاقے کا جائزہ';

  @override
  String get totalAntsDialog => 'کل Ants';

  @override
  String get networkShare => 'نیٹ ورک حصہ';

  @override
  String get activeWorkersDialog => 'فعال کارکن';

  @override
  String get sessionsInTerritory => 'علاقے میں سیشنز';

  @override
  String get liveBackendStats => 'ماخذ: لائیو بیک اینڈ ملک اعداد و شمار۔';

  @override
  String get fallbackEstimate =>
      'ماخذ: فال بیک تخمینہ۔ ملک اعداد و شمار اینڈ پوائنٹ دستیاب نہیں۔';

  @override
  String get web3AnetMarket => 'Web3 ANET مارکیٹ';

  @override
  String get marketImportance =>
      'اہم: اس ایپ میں مائن کیا گیا ANET Ant Work کے ذریعے جمع ہوتا ہے۔ BNB Chain ANET معاہدہ الگ Web3 مرئیت پرت ہے۔';

  @override
  String get bnbChainContract => 'BNB Chain مارکیٹ معاہدہ';

  @override
  String get currentSeparation => 'موجودہ علیحدگی';

  @override
  String get separationPoint1 =>
      '1. اس ایپ میں ANET coins تصدیق شدہ سیشنز کے ذریعے جمع ہوتے ہیں۔';

  @override
  String get separationPoint2 =>
      '2. BNB Chain ANET معاہدہ اور DEX حوالہ جات الگ Web3 مرئیت ٹولز ہیں۔';

  @override
  String get separationPoint3 =>
      '3. Colony، CP، رینک، سنیپ شاٹس ANET اور ANTS اکاؤنٹنگ ماڈل سے باہر ہیں۔';

  @override
  String get separationPoint4 =>
      '4. مکمل بلاک چین شفافیت ANET-Chain کے ذریعے دستیاب ہے۔';

  @override
  String get openMarketPair => 'مارکیٹ پیئر کھولیں';

  @override
  String get viewLiveChart => 'لائیو چارٹ دیکھیں';

  @override
  String get viewContract => 'معاہدہ دیکھیں';

  @override
  String get copyContractAddress => 'معاہدہ کاپی کریں';

  @override
  String get anetMarketContract => 'ANET مارکیٹ معاہدہ';

  @override
  String get moreInfo => 'مزید معلومات';

  @override
  String get createYourL1Wallet => 'پہلے اپنا L1 والیٹ بنائیں';

  @override
  String get createL1WalletMessage =>
      'آپ کا BIP-44 سیڈ تمام EVM والیٹس کے ساتھ مطابقت رکھتا ہے۔';

  @override
  String get generateWallet => 'والیٹ جنریٹ کریں';

  @override
  String get walletLocked => 'والیٹ مقفل ہے';

  @override
  String get setPINToContinue => 'جاری رکھنے کے لیے PIN سیٹ کریں';

  @override
  String get enterWalletPIN =>
      'اپنے Web3 والیٹ تک رسائی کے لیے اپنا والیٹ PIN درج کریں۔';

  @override
  String get setWalletPINAccess =>
      'رسائی کرنے سے پہلے اپنے والیٹ کو محفوظ کرنے کے لیے PIN سیٹ کریں۔';

  @override
  String get unlockWallet => 'والیٹ انلاک کریں';

  @override
  String get setWalletPINButton => 'والیٹ PIN سیٹ کریں';

  @override
  String get mainnetWallet => 'Mainnet والیٹ';

  @override
  String get homeTab => 'ہوم';

  @override
  String get assetsTab => 'اثاثے';

  @override
  String get activityTab => 'سرگرمی';

  @override
  String get sessionsTab => 'سیشنز';

  @override
  String get addToken => 'ٹوکن شامل کریں';

  @override
  String get totalBalance => 'کل بیلنس';

  @override
  String get send => 'بھیجیں';

  @override
  String get receive => 'وصول کریں';

  @override
  String get explorer => 'ایکسپلورر';

  @override
  String get bridge => 'برج';

  @override
  String get miningProfile => 'مائننگ پروفائل';

  @override
  String get joined => 'شامل ہوئے';

  @override
  String get completedSessions => 'مکمل سیشنز';

  @override
  String get anetBalance => 'ANET بیلنس';

  @override
  String get currentRate => 'موجودہ شرح';

  @override
  String get colonyJoined => 'کالونی میں شامل';

  @override
  String get notInColony => 'کسی کالونی میں نہیں';

  @override
  String get sessionHistory => 'سیشن ہسٹری';

  @override
  String get credited => 'کریڈٹ ہوا';

  @override
  String get inProgress => 'پیشرفت میں';

  @override
  String get aiSupportTitle => 'A-Network AI';

  @override
  String get trainButton => 'تربیت دیں';

  @override
  String get web4MigrationPolicy => 'Web4 مائیگریشن پالیسی';

  @override
  String get anetVsAnts => 'ANET بمقابلہ ANTS';

  @override
  String get securityWalletSafety => 'سیکیورٹی اور والیٹ حفاظت';

  @override
  String get trainAITitle => 'A-Network AI کو تربیت دیں';

  @override
  String get knowledgeHint =>
      'یاد رکھنے کے لیے علم (حقائق، پالیسیاں، پروڈکٹ تفصیلات)';

  @override
  String get optionalTrainingPrompt => 'اختیاری تربیتی پرامپٹ';

  @override
  String get optionalIdealResponse => 'اختیاری مثالی جواب';

  @override
  String get addMemoryOrBoth =>
      'میموری ٹیکسٹ، یا تربیتی پرامپٹ اور مثالی جواب دونوں شامل کریں۔';

  @override
  String get aiTrainingSaved => 'AI تربیت محفوظ ہوئی';

  @override
  String get noAITokensLeft =>
      'کوئی AI ٹوکن نہیں بچے۔ مزید ٹوکن کے لیے اشتہار دیکھیں یا 6 گھنٹے کی ری فل کا انتظار کریں۔';

  @override
  String get voiceRecognitionUnavailable =>
      'اس ڈیوائس پر وائس پہچان دستیاب نہیں ہے';

  @override
  String get noAssistantResponse =>
      'زور سے پڑھنے کے لیے کوئی معاون جواب دستیاب نہیں';

  @override
  String get adNotCompleted =>
      'اشتہار مکمل نہیں ہوا۔ ابھی تک کوئی ٹوکن انعام نہیں۔';

  @override
  String aiTokensAdded(String tokens, String balance) {
    return '$tokens AI ٹوکن شامل ہوئے۔ بیلنس: $balance';
  }

  @override
  String uploadedToMemory(String filename) {
    return '$filename AI میموری میں اپلوڈ ہوا';
  }

  @override
  String get copiedResponse => 'جواب کاپی ہوا';

  @override
  String get listeningSpeak => 'سن رہے ہیں... اپنا سوال بولیں';

  @override
  String get askAIAnything => 'A-Network AI سے کچھ بھی پوچھیں...';

  @override
  String get deepResearchEnabled => 'اگلے پیغامات کے لیے گہری تحقیق فعال';

  @override
  String get deepResearchDisabled => 'گہری تحقیق غیر فعال';

  @override
  String get uploadTxtTooltip =>
      'AI کو تربیت دینے کے لیے txt/md/pdf اپلوڈ کریں';

  @override
  String get stopListeningTooltip => 'سننا بند کریں';

  @override
  String get startVoiceInputTooltip => 'وائس ان پٹ شروع کریں';

  @override
  String get stopReadAloudTooltip => 'زور سے پڑھنا بند کریں';

  @override
  String get readLatestResponseTooltip => 'تازہ ترین جواب زور سے پڑھیں';

  @override
  String watchAdTokens(String tokens) {
    return 'اشتہار دیکھیں + $tokens ٹوکن';
  }

  @override
  String tokenBalance(String balance) {
    return 'ٹوکن: $balance';
  }

  @override
  String get pickGroupName => 'اپنا گروپ نام چنیں';

  @override
  String get claimPermanentUpline => 'مستقل اپ لائن کا دعوی کریں';

  @override
  String get claimUplineInstructions =>
      'اپنی کالونی رکھنے کے لیے کوئی اپ لائن ضروری نہیں ہے۔ Ant Code یہاں صرف اسی صورت میں درج کریں جب آپ اس مالک کی کالونی میں مستقل طور پر شامل ہونا چاہتے ہیں۔';

  @override
  String get enterAntCode => 'Ant Code درج کریں';

  @override
  String get claimButton => 'دعوی کریں';

  @override
  String get antCodeLinked =>
      'Ant Code لنک ہوا۔ آپ کی کالونی اپ لائن اب مستقل ہے۔';

  @override
  String get writeToColony => 'اپنی کالونی کو لکھیں';

  @override
  String get writeToUplines => 'اپنے کالونی اپ لائنز کو لکھیں';

  @override
  String get pickGroupNameTooltip => 'گروپ نام چنیں';

  @override
  String get refreshChatTooltip => 'چیٹ ریفریش کریں';

  @override
  String get tabEcosystem => 'ایکوسسٹم';

  @override
  String get tabAntWork => 'انٹ ورک';

  @override
  String get tabWallet => 'والیٹ';

  @override
  String get tabColony => 'کالونی';

  @override
  String get tabMore => 'مزید';

  @override
  String get pageTitleEcosystem => 'انٹ ایکوسسٹم';

  @override
  String get pageTitleAntWork => 'انٹ ورک';

  @override
  String get pageTitleWallet => 'ANET والیٹ';

  @override
  String get pageTitleWeb4 => 'Web4';

  @override
  String get pageTitleWhitepaper => 'وائٹ پیپر';

  @override
  String get pageTitleColony => 'کالونی (Web5)';

  @override
  String get pageTitleMore => 'مزید';

  @override
  String get antWorkSectionLabel => 'انٹ ورک';

  @override
  String get morePageTitle => 'مزید';

  @override
  String get morePageSubtitle =>
      'اکاؤنٹ، قانونی، سپورٹ اور ڈسپلے کنٹرولز ایک جگہ۔';

  @override
  String get walletMenuLabel => 'والیٹ';

  @override
  String get walletMenuSubtitle => 'بیلنس اور Web3 ٹولز';

  @override
  String get antWorkHeroTitle => 'انٹ ورک';

  @override
  String get antWorkHeroSubtitle =>
      'لائیو 6 گھنٹے کے سیشن، موجودہ آؤٹ پٹ اور نیٹ ورک سنگ میل مانیٹر کریں۔';
}
