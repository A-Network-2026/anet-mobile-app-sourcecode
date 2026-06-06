// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'A-Network';

  @override
  String get authPageSubtitle =>
      'الوصول إلى التعدين النظيف على الويب 2 مع استمرارية المحفظة الآمنة.';

  @override
  String get loginTab => 'تسجيل الدخول';

  @override
  String get registerTab => 'تسجيل';

  @override
  String get emailHint => 'البريد الإلكتروني';

  @override
  String get passwordHint => 'كلمة المرور';

  @override
  String get antCodeHint => 'رمز النملة (اختياري)';

  @override
  String get continueLoginButton => 'متابعة تسجيل الدخول';

  @override
  String get continueRegisterButton => 'متابعة التسجيل';

  @override
  String get forgotPasswordButton => 'هل نسيت كلمة المرور؟';

  @override
  String get useExistingAccountButton => 'استخدام تسجيل دخول الحساب الموجود';

  @override
  String get restoreDeletedAccountButton => 'استعادة الحساب المحذوف';

  @override
  String get sessionModelTitle => 'نموذج الجلسة';

  @override
  String get sessionModelSubtitle =>
      'يعمل التعدين في دورات مدتها 6 ساعات ويتم مزامنة التقدم مع حساب محفظتك.';

  @override
  String get securityLayerTitle => 'طبقة الأمان';

  @override
  String get securityLayerSubtitle =>
      'عبارة البذرة وحماية PIN واستعادة الحساب مدمجة.';

  @override
  String get emailPasswordRequired => 'البريد الإلكتروني وكلمة المرور مطلوبان';

  @override
  String get deviceLimitError =>
      'وصل هذا الجهاز بالفعل إلى الحد الأقصى من الحسابات المرتبطة. سجل دخولك باستخدام حساب موجود أو استخدم جهاز مختلف للتسجيل.';

  @override
  String get accountRestorationEligible =>
      'الاستعادة متاحة. تم جدولة حسابك للحذف.';

  @override
  String get openEmailApp =>
      'فتح تطبيق البريد الإلكتروني لـ info@a-network.net';

  @override
  String get emailAppNotAvailable =>
      'تطبيق البريد الإلكتروني غير متاح، تم فتح صفحة الدعم';

  @override
  String get forgotPasswordTitle => 'هل نسيت كلمة المرور';

  @override
  String get forgotPasswordInstructions =>
      'أدخل بريدك الإلكتروني المسجل لتلقي رمز إعادة تعيين مكون من 6 أرقام.';

  @override
  String get sendCodeButton => 'إرسال الرمز';

  @override
  String get resendCodeButton => 'إعادة إرسال الرمز';

  @override
  String get sixDigitCodeHint => 'رمز مكون من 6 أرقام';

  @override
  String get newPasswordHint => 'كلمة مرور جديدة';

  @override
  String get confirmPasswordHint => 'تأكيد كلمة المرور الجديدة';

  @override
  String get resetPasswordButton => 'إعادة تعيين كلمة المرور';

  @override
  String get needHelpButton => 'هل تحتاج إلى مساعدة؟';

  @override
  String get verifyEmailTitle => 'التحقق من البريد الإلكتروني';

  @override
  String verifyEmailInstructions(String email) {
    return 'أدخل رمز 6 أرقام تم إرساله إلى $email';
  }

  @override
  String get otpCodeHint => 'رمز OTP';

  @override
  String get verifyButton => 'تحقق';

  @override
  String get cancelButton => 'إلغاء';

  @override
  String get emailVerificationCancelled =>
      'تم إلغاء التحقق من البريد الإلكتروني. أدخل الرمز الأخير لاحقاً أو انقر على إعادة إرسال الرمز للحصول على رمز جديد.';

  @override
  String get loginVerificationTitle => 'التحقق من تسجيل الدخول';

  @override
  String loginVerificationInstructions(String email) {
    return 'أدخل رمز تسجيل الدخول المكون من 6 أرقام المرسل إلى $email';
  }

  @override
  String get loginVerificationCancelled =>
      'تم إلغاء التحقق من تسجيل الدخول. أدخل الرمز الأخير لاحقاً أو اطلب رمزاً جديداً.';

  @override
  String get convertedDeepLink => 'تم تحويل الارتباط العميق لمتصفح ANTS';

  @override
  String blockedUnsupportedScheme(String scheme) {
    return 'تم حظر المخطط غير المدعوم: $scheme';
  }

  @override
  String get untrustedDomainTitle => 'مجال غير موثوق';

  @override
  String untrustedDomainMessage(String host, String url) {
    return 'هذا المجال ليس في قائمة dApp الموثوقة:\n\n$host\n\nURL:\n$url\n\nتابع فقط إذا كنت تثق في هذا الموقع.';
  }

  @override
  String get trustForSessionButton => 'ثق في هذه الجلسة';

  @override
  String get openDAppPageFirst => 'افتح أولاً صفحة dApp';

  @override
  String connectionBlockedUntrusted(String host) {
    return 'تم حظر الاتصال للمجال غير الموثوق: $host';
  }

  @override
  String get connectWalletTitle => 'ربط المحفظة';

  @override
  String connectWalletPrompt(String host, String network, String address) {
    return 'dApp: $host\nالشبكة: $network\nالمحفظة: $address\n\nهل يتم منح وصول الجلسة لقراءة عنوان محفظتك وإجراء طلبات التوقيع؟';
  }

  @override
  String get rejectButton => 'رفض';

  @override
  String get connectButton => 'ربط';

  @override
  String walletConnectedSnackbar(String host) {
    return 'تم ربط المحفظة بـ $host';
  }

  @override
  String get walletPINVerificationTitle => 'التحقق من PIN المحفظة';

  @override
  String get walletPINInstructions =>
      'أدخل رمز PIN الخاص بمحفظتك لتمكين طلبات التوقيع لمدة 5 دقائق.';

  @override
  String get pinMustBe => 'يجب أن يكون رمز PIN بين 4 و 8 أرقام';

  @override
  String get verifyingPIN => 'جاري التحقق...';

  @override
  String get connectWalletToDApp => 'قم بربط المحفظة بـ dApp أولاً';

  @override
  String get seedPhraseRequired =>
      'عبارة البذرة المحلية الآمنة مطلوبة للتوقيع EVM الحقيقي';

  @override
  String get signRequestTitle => 'طلب التوقيع';

  @override
  String signRequestContent(String host, String network) {
    return 'dApp: $host\nالشبكة: $network';
  }

  @override
  String get messageToSign => 'الرسالة المراد توقيعها';

  @override
  String get approveSignature => 'أوافق على طلب التوقيع هذا';

  @override
  String get signButton => 'وقّع';

  @override
  String get signatureApprovedTitle => 'تم الموافقة على التوقيع';

  @override
  String get copyButton => 'نسخ';

  @override
  String get closeButton => 'إغلاق';

  @override
  String get signaturePayloadCopied => 'تم نسخ حمولة التوقيع';

  @override
  String get antsBrowserTitle => 'متصفح ANTS';

  @override
  String get connectWalletTooltip => 'ربط المحفظة';

  @override
  String get disconnectTooltip => 'قطع الاتصال';

  @override
  String get approveSignTooltip => 'الموافقة على طلب التوقيع';

  @override
  String walletNotConnected(String host) {
    return 'المحفظة غير متصلة. المضيفون الموثوقون فقط. الحالي: $host';
  }

  @override
  String walletConnectedStatus(String host, String network) {
    return 'متصل: $host • $network';
  }

  @override
  String get enterURL => 'أدخل عنوان URL';

  @override
  String get goButton => 'انطلق';

  @override
  String get loadingAISupport => 'جاري تحميل دعم الذكاء الاصطناعي...';

  @override
  String get aiSupportConnectionError =>
      'لم يتمكن من الاتصال بدعم الذكاء الاصطناعي. يرجى التحقق من اتصال الإنترنت.';

  @override
  String get retryButton => 'إعادة المحاولة';

  @override
  String get autoRegion => 'تلقائي (المنطقة)';

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
  String get securityLockTitle => 'قفل الأمان مفعّل';

  @override
  String get securityLockMessage =>
      'اكتشفت هذه النسخة بيئة تشغيل عالية المخاطر وحظرت تسجيل الدخول و Ant Work والوصول إلى المحفظة لتقليل محاكي، جهاز جذر، واستغلال التلاعب.';

  @override
  String detectedFlags(String flags) {
    return 'الأعلام المكتشفة: $flags';
  }

  @override
  String platformRuntime(String platform, String runtime) {
    return 'النظام الأساسي: $platform  |  وقت التشغيل: $runtime';
  }

  @override
  String get securityOverrideInfo =>
      'استخدم نسخة رسمية على جهاز فعلي. للاختبار الداخلي فقط، يمكن للمطورين تجاوز هذا الكتل باستخدام --dart-define=ALLOW_INSECURE_DEVICE=true.';

  @override
  String get anetGlobal => 'A-Network العالمية';

  @override
  String get globalSubtitle =>
      'عرض الشبكة العام الاحترافي وحالة التعدين وظهور المحفظة.';

  @override
  String get profileSupport => 'الملف الشخصي والدعم';

  @override
  String get halvingAnnouncementTitle => 'تم بدء التخفيف';

  @override
  String get halvingAnnouncementBody =>
      'وصلت الشبكة إلى 500000 جلسة مليون. التخفيف الأول الآن نشط.';

  @override
  String get halvingAnnouncementNote =>
      'هناك تأخير تحقق مدته 6 ساعات قبل تطبيق السعر المحدث. يتحقق النظام من جميع الجلسات المعلقة أولاً. بعد الوصول إلى 500k مليون، سيتم تحديث الناتج المباشر الخاص بك تلقائياً بسعر التخفيف الجديد.';

  @override
  String get halvingActionSafe =>
      'لا يوجد إجراء مطلوب - الجلسات الجارية آمنة وستتلقى رصيد بالسعر الصحيح.';

  @override
  String get xAnnouncementTitle => 'آخر تحديث X';

  @override
  String get xAnnouncementBody =>
      'اتبع Mr_A_Awakening للحصول على أحدث تقديمات A-Network الرسمية.';

  @override
  String get xAnnouncementNote =>
      'تتناوب هذه الشريحة تلقائياً كل 60 ثانية مع بطاقة تحديث التخفيف.';

  @override
  String get xAnnouncementCTA => 'افتح آخر تحديثات X';

  @override
  String get liveStatus => 'مباشر';

  @override
  String get networkStatus => 'حالة الشبكة';

  @override
  String get totalAnts => 'إجمالي النمل';

  @override
  String get registered => 'مسجل';

  @override
  String get activeWorkers => 'العمال النشطون';

  @override
  String get completedWork => 'العمل المكتمل';

  @override
  String activeTerritories(String count) {
    return 'الأراضي النشطة ($count+)';
  }

  @override
  String get verifiedSessions => 'الجلسات المتحققة';

  @override
  String get networkThroughput => 'معدل نقل الشبكة';

  @override
  String get liveOutput => 'الإخراج المباشر';

  @override
  String get anetPerSession => 'ANET / جلسة';

  @override
  String get markets => 'الأسواق';

  @override
  String get activeTerritoriesCount => 'الأراضي النشطة';

  @override
  String get liveAntWork => 'Ant Work المباشر';

  @override
  String get startingAntWork => 'جاري بدء Ant Work...';

  @override
  String get antWorkActive => 'Ant Work نشط';

  @override
  String get readyToStart => 'جاهز للبدء';

  @override
  String sessionEndsIn(String time) {
    return 'تنتهي الجلسة في: $time';
  }

  @override
  String get startAnyTime => 'ابدأ في أي وقت. يبدأ مؤقت 6 ساعات من اللمس.';

  @override
  String get openAntWork => 'افتح Ant Work';

  @override
  String get startAntWork => 'بدء Ant Work';

  @override
  String get refreshActivity => 'تحديث النشاط';

  @override
  String get beginJourney => 'ابدأ رحلتك';

  @override
  String get startAntWorkInfo =>
      'ابدأ جلسة Ant Work المحققة لمدة 6 ساعات. يتم تتبع النشاط أولاً في ANTS، ثم يمكن المطالبة به في ANET بعد الوصول إلى حد الجلسات المكتملة المطلوب.';

  @override
  String get anetWalletAction => 'محفظة ANET';

  @override
  String get balanceWalletTools => 'الرصيد وأدوات المحفظة وظهور السلسلة';

  @override
  String get anetWalletInfo =>
      'افتح أدوات المحفظة ورسم خريطة الرصيد الحالي واللوحات الإضافية بدون الحفر في رؤية النظام البيئي العامة.';

  @override
  String get sessionOutput => 'إخراج الجلسة';

  @override
  String get anetPer6Hour => 'ANET لكل دورة 6 ساعات';

  @override
  String get portfolio => 'المحفظة';

  @override
  String get antsAccumulated => 'تم تجميع ANTS';

  @override
  String get typeWebsite => 'اكتب موقع ويب أو كلمة أساسية أولاً';

  @override
  String get createWalletFirst => 'أنشئ محفظتك أولاً';

  @override
  String get walletBalanceSynced => 'تتم مزامنة رصيد المحفظة من ANET المُعدَّل';

  @override
  String get noColonyMessage =>
      'المستعمرة جاهزة. لا يلزم upline. اختر اسم المستعمرة وادعو النملة برمز النملة الخاص بك.';

  @override
  String get noColonyMessagesYet => 'لا توجد رسائل مستعمرة حتى الآن.';

  @override
  String get myAntCodeTitle => 'ارتباط رمز النملة الخاص بي';

  @override
  String antCodeLabel(String code) {
    return 'رمز النملة: $code';
  }

  @override
  String get referralLinksLabel => 'روابط الإحالة';

  @override
  String get openGoogleLink => 'افتح ارتباط Google';

  @override
  String get openAPKLink => 'افتح ارتباط APK';

  @override
  String get copyShareText => 'نسخ نص المشاركة';

  @override
  String get colonyTrackerTitle => 'متتبع المستعمرة';

  @override
  String get colonyDescription =>
      'المستعمرة هي طبقة المجتمع Web5 في المستقبل. حالياً في الوضع الاستعراض فقط وتبقى منفصلة عن جلسات تعدين Web2 ومحاسبة ANTS و ANET صيغ العملات الوصول إليها والعروض.';

  @override
  String get operatingModel =>
      'نموذج التشغيل: Web2 = تعدين Ant Work ومحاسبة ANTS. Web3 = ظهور Binance Chain والعقود المرجعية. Web4 = اتفاقية سلسلة ANET وظهور نقل. Web5 = برنامج ANTS ونقاط المستعمرة مع تنسيق المجتمع. تعمل كل طبقة بشكل مستقل مع عدم وجود تداخل في الدفع أو المحاسبة.';

  @override
  String get futureAnetCoreNote =>
      'ملاحظة ANET Core في المستقبل: هذا الحساب جاهز لمحفظة Web3 للمشاركة المستقبلية. إذا تم تقديم قاعدة شراء مثل 10 USDT يعادل في Binance Chain في المستقبل، سيتم تطبيق التعدين بشكل منفصل ودرجات المستعمرة بشكل منفصل.';

  @override
  String get futureCorNoteNoWallet =>
      'ملاحظة ANET Core في المستقبل: قد تستخدم الشركاء المستقبليون متطلبات محفظة Web3 منفصلة، ولكن لا يتم تطبيق أي شراء أو بوابة مشتري في هذه النسخة.';

  @override
  String get yourAntCode => 'رمز النملة الخاص بك';

  @override
  String directColonyAnts(String count) {
    return 'النمل المستعمرة المباشر: $count';
  }

  @override
  String colonyCompleted1K(String count) {
    return 'جلسات المستعمرة النملة 1k المكتملة: $count';
  }

  @override
  String totalColonySessions(String count) {
    return 'إجمالي جلسات المستعمرة: $count';
  }

  @override
  String get communityVisibilityOnly =>
      'الحالة الحالية: رؤية المجتمع فقط. لا تشارك نقاط الشراء وترتيب اللقطات والمعاينات وأي توزيع مستقبلي محدود من الخارج عن أرصدة ANET وتبقى خارج محاسبة ANTS.';

  @override
  String get blockchainTransparency =>
      'شفافية Blockchain: يمكن للمستخدمين فحص نشاط Blockchain العام من خلال ANET-Chain. عرض Blockchain لأغراض الشفافية والعقود، في حين تبقى مقاييس المستعمرة عرض مجتمع Web5 منفصل.';

  @override
  String yourCompletedSessions(String sessions, String target) {
    return 'الجلسات المكتملة: $sessions / $target';
  }

  @override
  String remainingTo1K(String remaining) {
    return 'المتبقي إلى 1k: $remaining';
  }

  @override
  String get colonySessionProgress => 'تقدم جلسة المستعمرة';

  @override
  String get noColonyAnts => 'لا توجد نملة مستعمرة بعد.';

  @override
  String completedSessionsAnt(String sessions) {
    return 'الجلسات المكتملة: $sessions / 1000';
  }

  @override
  String get qualifiedFor1KMilestone => 'مؤهل لمعالم 1k';

  @override
  String get copyAntCode => 'نسخ الرمز';

  @override
  String get shareColony => 'شارك المستعمرة';

  @override
  String get copyGoogleLink => 'نسخ ارتباط Google';

  @override
  String get copyAPKLink => 'نسخ ارتباط APK';

  @override
  String get seedPhraseBackupTitle => 'نسخ احتياطي من عبارة البذرة';

  @override
  String get securityCheckRequired =>
      'مطلوب فحص أمان. أدخل رمز PIN الخاص بمحفظتك للمتابعة.';

  @override
  String get walletPINHint => 'PIN المحفظة';

  @override
  String get sendOTPButton => 'إرسال OTP';

  @override
  String get emailOTPHint => 'البريد الإلكتروني OTP';

  @override
  String get neverSharePhrase =>
      'لا تشارك هذه العبارة أبداً. أي شخص لديه هذه العبارة يمكنه التحكم في محفظتك.';

  @override
  String get revealButton => 'كشف';

  @override
  String get setWalletPINTitle => 'تعيين PIN المحفظة';

  @override
  String get changeWalletPINTitle => 'تغيير PIN المحفظة';

  @override
  String get changePINRequiresOTP =>
      'يتطلب تغيير PIN التحقق من OTP من بريدك الإلكتروني المسجل.';

  @override
  String get registeredEmail => 'البريد الإلكتروني المسجل';

  @override
  String get currentPIN => 'رمز PIN الحالي';

  @override
  String get newPINHint => 'PIN جديد (4-8 أرقام)';

  @override
  String get forgotPINButton => 'هل نسيت PIN؟';

  @override
  String get forgotWalletPINTitle => 'هل نسيت PIN المحفظة';

  @override
  String get forgotPINInstructions =>
      'أعد تعيين PIN محفظتك عبر التحقق من البريد الإلكتروني. سنرسل رمزاً مكوناً من 6 أرقام إلى بريدك الإلكتروني المسجل، ثم يمكنك إنشاء PIN جديد.';

  @override
  String get sixDigitVerificationCode => 'رمز التحقق المكون من 6 أرقام';

  @override
  String get pinResetSuccessful => 'تم إعادة تعيين PIN بنجاح';

  @override
  String get deleteAccountTitle => 'حذف الحساب';

  @override
  String get deleteAccountMessage =>
      'سيؤدي هذا إلى جدولة حذف حسابك بعد فترة أمان.';

  @override
  String get enterPINToConfirm => 'أدخل PIN لتأكيد';

  @override
  String get deleteButton => 'حذف';

  @override
  String get deletionRequested => 'تم طلب الحذف';

  @override
  String get welcomeTitle => 'مرحباً بك في A-Network';

  @override
  String get tutorialStep1 =>
      '1) ابدأ Ant Work وانتظر 6 ساعات لإكمال جلسة واحدة.';

  @override
  String get tutorialStep2 => '2) يتم جمع ANTS أولاً. 100000000 ANTS = 1 ANET.';

  @override
  String get tutorialStep3 =>
      '3) الوصول إلى 1000 جلسة للتأهل لميزات تحويل ANET الكاملة.';

  @override
  String get tutorialStep4 =>
      '4) حماية محفظتك: قم بتعيين PIN وكشف البذرة عند الحاجة فقط.';

  @override
  String get gotItButton => 'حسناً';

  @override
  String get accountProfileTitle => 'ملف تعريفي للحساب';

  @override
  String get levelEligible => 'أهلية المستوى: مؤهل';

  @override
  String levelNotEligible(String remaining) {
    return 'أهلية المستوى: غير مؤهل حتى الآن ($remaining جلسة متبقية)';
  }

  @override
  String get web4MigrationWalletTitle => 'محفظة ترحيل Web4';

  @override
  String get migrationWalletOptional =>
      'اختياري: ضع عنوان محفظة ترحيل Web4 المستقبلي الآن.';

  @override
  String get migrationWalletExample =>
      'مثال: ANET1A2B3C4D5E6F... (ANET + 36 حرف سادس عشر)';

  @override
  String get saveButton => 'حفظ';

  @override
  String get migrationWalletNotChanged => 'لم يتم تغيير عنوان محفظة الترحيل';

  @override
  String get migrationWalletSaved => 'تم حفظ عنوان محفظة الترحيل';

  @override
  String get changeEmailTitle => 'تغيير البريد الإلكتروني';

  @override
  String get newEmailHint => 'بريد إلكتروني جديد';

  @override
  String get currentPasswordHint => 'كلمة المرور الحالية';

  @override
  String get emailChangedSuccessfully => 'تم تغيير البريد الإلكتروني بنجاح';

  @override
  String get changePasswordTitle => 'تغيير كلمة المرور';

  @override
  String get newPasswordMin8 => 'كلمة مرور جديدة (8 أحرف بحد أدنى)';

  @override
  String get passwordChangedSuccessfully => 'تم تغيير كلمة المرور بنجاح';

  @override
  String get securityOwnershipTitle => 'الأمان والملكية';

  @override
  String get emailVerificationNote =>
      'يطبق A-Network حالياً التحقق من البريد الإلكتروني عبر OTP أثناء التسجيل.';

  @override
  String get otpVerificationOneTime =>
      'يحدث التحقق من OTP هذا مرة واحدة فقط لتنشيط الحساب.';

  @override
  String get emailLossWarning =>
      'إذا فقدت الوصول إلى بريدك الإلكتروني ولم تتمكن من استعادته، فستفقد الوصول إلى حسابك و ANET المُعدَّل.';

  @override
  String get ownershipModel =>
      'نموذج الملكية: البريد الإلكتروني + عنوان المحفظة الذي أنشأته = مفتاح الملكية المباشرة عبر النظام البيئي.';

  @override
  String get web4MigrationKeepSafe =>
      'لترحيل Web4، حافظ على بريدك الإلكتروني ومعلومات محفظتك آمنة.';

  @override
  String get notificationsTitle => 'إخطارات';

  @override
  String get antWorkAlertsActive =>
      'تنبيهات Ant Work نشطة لجلسة 6 ساعات الحالية.';

  @override
  String get startAntWorkNotifications =>
      'ابدأ Ant Work لجدولة تنبيه الإكمال التالي.';

  @override
  String get notificationsInfo =>
      'يتم استخدام الإخطارات لتذكيرات الجلسة المحققة وتوقيت الإكمال والتحديثات البيئية المهمة. للتسليم الموثوق، اسمح بالإخطارات لنظام Android وتعطيل قيود البطارية لـ A-Network.';

  @override
  String get sessionRunning =>
      'الحالة الحالية: تعمل الجلسة، تنبيه الإكمال قيد الانتظار.';

  @override
  String get noActiveSession =>
      'الحالة الحالية: لا توجد جلسة نشطة، لذلك لم يتم جدولة تنبيه الإكمال بعد.';

  @override
  String get refreshButton => 'تحديث';

  @override
  String get languageTitle => 'اللغة';

  @override
  String get languageHelp =>
      'اختر لغة التطبيق. يطابق الوضع التلقائي الإعدادات الإقليمية: الهند → الهندية، باكستان → الأردية، الصين → الصينية، إسبانيا / أمريكا اللاتينية → الإسبانية، فيتنام → الفيتنامية، والعودة الإنجليزية للمناطق الأخرى.';

  @override
  String get aboutTitle => 'حول A-Network';

  @override
  String get aboutContent =>
      'تم تشغيل A-Network بواسطة A Network LLC، كيان كاليفورنيا رقم 20260170159.\n\nيستخدم نموذج الإنتاج محاسبة أولاً ANTS، حيث 1 ANET = 100000000 ANTS. يعمل Ant Work في جلسات مختبرة لمدة 6 ساعات، ويصبح ANET قابل للمطالبة بعد الوصول إلى حد أهلية الجلسة، والتخفيف مدفوع بإجمالي الجلسات المتحققة عبر الشبكة.\n\nتربط رموز النملة الوصول إلى المستعمرة فقط. تنمو الإحالات شبكة المستعمرة الخاصة بك ولكن لا تمنح أي مكافآت عملات أو أرصدة جلسات أو عمولات بنسبة مئوية. نقاط المستعمرة (CP) عبارة عن مقاييس أداء يمكن عرضها فقط. لا تضمن شبكة A العوائد المالية.';

  @override
  String get openWeb4Button => 'افتح Web4';

  @override
  String get displayThemeTitle => 'موضوع العرض';

  @override
  String get classicTheme => 'موضوع Main الكلاسيكي';

  @override
  String get classicThemeDesc => 'عرض A-Network الأزرق السماوي الحالي.';

  @override
  String get antsTheme => 'موضوع نظام ANTS البيئي';

  @override
  String get antsThemeDesc =>
      'أسلوب المستثمر الأخضر والأزرق والذهبي مستوحى من Web4.';

  @override
  String get studioTheme => 'موضوع الاستوديو الخفيف';

  @override
  String get studioThemeDesc =>
      'خلفية خفيفة احترافية مع جزيئات متصلة وأكسنتات زرقاء رائعة.';

  @override
  String get executiveTheme => 'موضوع العامل المظلم';

  @override
  String get executiveThemeDesc =>
      'أسطح الجرافيت مع أكسنتات الشمبانيا لعرض مستثمر أكثر حدة.';

  @override
  String get paperTheme => 'موضوع الورق الخفيف';

  @override
  String get paperThemeDesc =>
      'أسلوب افتتاحي خفيف دافئ مع علامات زرقاء حبرية وحركة أكثر نعومة.';

  @override
  String get viewProfileDetails => 'عرض تفاصيل الملف الشخصي';

  @override
  String get changeEmail => 'تغيير البريد الإلكتروني';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get helpSupport => 'المساعدة والدعم';

  @override
  String get logoutButton => 'تسجيل الخروج';

  @override
  String get sixHourAntWorkComplete =>
      'تكملت جلسة عمل النملة لمدة 6 ساعات. جاري نشر رصيد جلسة ANET الخاص بك الآن...';

  @override
  String antWorkCompletedAccumulated(String reward) {
    return '✅ اكتمل Ant Work! لقد جمعت $reward ANET';
  }

  @override
  String antWorkAutoCompleted(String reward) {
    return '✅ اكتمل Ant Work تلقائياً. تم منح $reward ANET.';
  }

  @override
  String get antWorkStartedSuccessfully => 'بدأ Ant Work بنجاح';

  @override
  String completeAntWorkFailed(String error) {
    return 'فشل إكمال Ant Work: $error';
  }

  @override
  String startAntWorkFailed(String error) {
    return 'فشل بدء Ant Work: $error';
  }

  @override
  String get territoryOverview => 'نظرة عامة على الأراضي';

  @override
  String get totalAntsDialog => 'إجمالي النمل';

  @override
  String get networkShare => 'حصة الشبكة';

  @override
  String get activeWorkersDialog => 'العمال النشطون';

  @override
  String get sessionsInTerritory => 'الجلسات في الأراضي';

  @override
  String get liveBackendStats => 'المصدر: إحصائيات الدول الحية.';

  @override
  String get fallbackEstimate =>
      'المصدر: تقدير احتياطي. نقطة نهاية إحصائيات الدول غير متاحة.';

  @override
  String get web3AnetMarket => 'سوق ANET على الويب 3';

  @override
  String get marketImportance =>
      'مهم: ANET المُعدَّل في هذا التطبيق يتم تجميعه من خلال Ant Work. عقد ANET على Binance Chain أدناه هو طبقة رؤية Web3 منفصلة ولا يزيد مباشرة من رصيد عملة ANET في التطبيق للمستخدم.';

  @override
  String get bnbChainContract => 'عقد سوق Binance Chain';

  @override
  String get currentSeparation => 'الفصل الحالي';

  @override
  String get separationPoint1 =>
      '1. يتم تجميع عملات ANET في هذا التطبيق من خلال الجلسات المحققة.';

  @override
  String get separationPoint2 =>
      '2. عقد ANET على Binance Chain والمراجع DEX عبارة عن أدوات رؤية Web3 منفصلة وإشارات دخول الشركاء في المستقبل.';

  @override
  String get separationPoint3 =>
      '3. تبقى المستعمرة والعلاقات العامة والترتيب واللقطات والتوزيعات المستقبلية للشركاء خارج نموذج محاسبة ANET و ANTS.';

  @override
  String get separationPoint4 =>
      '4. تبقى الشفافية الكاملة للـ blockchain متاحة من خلال ANET-Chain للتسوية العامة وعرض المعاملات.';

  @override
  String get openMarketPair => 'فتح زوج السوق';

  @override
  String get viewLiveChart => 'عرض الرسم البياني المباشر';

  @override
  String get viewContract => 'عرض العقد';

  @override
  String get copyContractAddress => 'نسخ العقد';

  @override
  String get anetMarketContract => 'عقد سوق ANET';

  @override
  String get moreInfo => 'مزيد من المعلومات';

  @override
  String get createYourL1Wallet => 'أنشئ محفظة L1 الخاصة بك أولاً';

  @override
  String get createL1WalletMessage =>
      'البذرة BIP-44 الخاصة بك متوافقة مع جميع محافظ EVM.';

  @override
  String get generateWallet => 'إنشاء محفظة';

  @override
  String get walletLocked => 'المحفظة مقفلة';

  @override
  String get setPINToContinue => 'تعيين PIN للمتابعة';

  @override
  String get enterWalletPIN =>
      'أدخل PIN محفظتك للوصول إلى محفظة Web3 الخاصة بك.';

  @override
  String get setWalletPINAccess =>
      'قم بتعيين PIN لتأمين محفظتك قبل الوصول إليها.';

  @override
  String get unlockWallet => 'فتح المحفظة';

  @override
  String get setWalletPINButton => 'تعيين PIN المحفظة';

  @override
  String get mainnetWallet => 'محفظة Mainnet';

  @override
  String get homeTab => 'الصفحة الرئيسية';

  @override
  String get assetsTab => 'الأصول';

  @override
  String get activityTab => 'النشاط';

  @override
  String get sessionsTab => 'الجلسات';

  @override
  String get addToken => 'إضافة رمز';

  @override
  String get totalBalance => 'إجمالي الرصيد';

  @override
  String get send => 'إرسال';

  @override
  String get receive => 'تلقي';

  @override
  String get explorer => 'مستكشف';

  @override
  String get bridge => 'الجسر';

  @override
  String get miningProfile => 'ملف التعدين';

  @override
  String get joined => 'انضم';

  @override
  String get completedSessions => 'الجلسات المكتملة';

  @override
  String get anetBalance => 'رصيد ANET';

  @override
  String get currentRate => 'السعر الحالي';

  @override
  String get colonyJoined => 'المستعمرة المنضمة';

  @override
  String get notInColony => 'ليس في مستعمرة';

  @override
  String get sessionHistory => 'سجل الجلسة';

  @override
  String get credited => 'معتمد';

  @override
  String get inProgress => 'قيد التنفيذ';

  @override
  String get aiSupportTitle => 'A-Network ذكاء اصطناعي';

  @override
  String get trainButton => 'تدريب';

  @override
  String get web4MigrationPolicy => 'سياسة ترحيل Web4';

  @override
  String get anetVsAnts => 'ANET مقابل ANTS';

  @override
  String get securityWalletSafety => 'الأمان وسلامة المحفظة';

  @override
  String get trainAITitle => 'تدريب A-Network الذكاء الاصطناعي';

  @override
  String get knowledgeHint =>
      'المعرفة المراد تذكرها (الحقائق والسياسات وتفاصيل المنتج)';

  @override
  String get optionalTrainingPrompt => 'موجه التدريب الاختياري';

  @override
  String get optionalIdealResponse => 'استجابة مثالية اختيارية';

  @override
  String get addMemoryOrBoth =>
      'أضف نص الذاكرة أو كل من موجه التدريب والاستجابة المثالية.';

  @override
  String get aiTrainingSaved => 'تم حفظ تدريب الذكاء الاصطناعي';

  @override
  String get noAITokensLeft =>
      'لا توجد رموز ذكاء اصطناعي متبقية. شاهد إعلاناً لمزيد من الرموز أو انتظر إعادة التعبئة لمدة 6 ساعات.';

  @override
  String get voiceRecognitionUnavailable =>
      'التعرف على الصوت غير متاح على هذا الجهاز';

  @override
  String get noAssistantResponse =>
      'لا توجد استجابة مساعد متاحة للقراءة بصوت عالي';

  @override
  String get adNotCompleted =>
      'لم يتم إكمال الإعلان. لا توجد مكافأة رموز حتى الآن.';

  @override
  String aiTokensAdded(String tokens, String balance) {
    return 'تمت إضافة $tokens رموز الذكاء الاصطناعي. الرصيد: $balance';
  }

  @override
  String uploadedToMemory(String filename) {
    return 'تم تحميل $filename إلى ذاكرة الذكاء الاصطناعي';
  }

  @override
  String get copiedResponse => 'تم نسخ الاستجابة';

  @override
  String get listeningSpeak => 'الاستماع... تحدث سؤالك';

  @override
  String get askAIAnything => 'اسأل A-Network ذكاء اصطناعي عن أي شيء...';

  @override
  String get deepResearchEnabled => 'تم تمكين البحث العميق للرسائل التالية';

  @override
  String get deepResearchDisabled => 'تم تعطيل البحث العميق';

  @override
  String get uploadTxtTooltip => 'تحميل txt/md/pdf لتدريب الذكاء الاصطناعي';

  @override
  String get stopListeningTooltip => 'توقف عن الاستماع';

  @override
  String get startVoiceInputTooltip => 'ابدأ إدخال الصوت';

  @override
  String get stopReadAloudTooltip => 'توقف عن القراءة بصوت عالي';

  @override
  String get readLatestResponseTooltip => 'اقرأ أحدث استجابة بصوت عالي';

  @override
  String watchAdTokens(String tokens) {
    return 'شاهد الإعلان + $tokens رموز';
  }

  @override
  String tokenBalance(String balance) {
    return 'الرموز: $balance';
  }

  @override
  String get pickGroupName => 'اختر اسم مجموعتك';

  @override
  String get claimPermanentUpline => 'المطالبة بـ Upline الدائم';

  @override
  String get claimUplineInstructions =>
      'لا يلزم upline للاحتفاظ بمستعمرتك الخاصة. أدخل رمز النملة هنا فقط إذا كنت تريد الانضمام بشكل دائم إلى مستعمرة المالك بدلاً من ذلك.';

  @override
  String get enterAntCode => 'أدخل رمز النملة';

  @override
  String get claimButton => 'اطلب';

  @override
  String get antCodeLinked =>
      'رمز النملة المرتبط. الآن upline المستعمرة الخاصة بك دائم.';

  @override
  String get writeToColony => 'اكتب إلى مستعمرتك';

  @override
  String get writeToUplines => 'اكتب إلى uplines المستعمرة الخاصة بك';

  @override
  String get pickGroupNameTooltip => 'اختر اسم المجموعة';

  @override
  String get refreshChatTooltip => 'تحديث الدردشة';

  @override
  String get tabEcosystem => 'النظام البيئي';

  @override
  String get tabAntWork => 'Ant Work';

  @override
  String get tabWallet => 'المحفظة';

  @override
  String get tabColony => 'المستعمرة';

  @override
  String get tabMore => 'المزيد';

  @override
  String get pageTitleEcosystem => 'نظام Ant البيئي';

  @override
  String get pageTitleAntWork => 'Ant Work';

  @override
  String get pageTitleWallet => 'محفظة ANET';

  @override
  String get pageTitleWeb4 => 'Web4';

  @override
  String get pageTitleWhitepaper => 'الورقة البيضاء';

  @override
  String get pageTitleColony => 'المستعمرة (Web5)';

  @override
  String get pageTitleMore => 'المزيد';

  @override
  String get antWorkSectionLabel => 'Ant Work';

  @override
  String get morePageTitle => 'المزيد';

  @override
  String get morePageSubtitle =>
      'حساب والقانون والدعم وعناصر التحكم في العرض في مكان واحد أنظف.';

  @override
  String get walletMenuLabel => 'المحفظة';

  @override
  String get walletMenuSubtitle => 'الرصيد وأدوات Web3';

  @override
  String get antWorkHeroTitle => 'Ant Work';

  @override
  String get antWorkHeroSubtitle =>
      'راقب جلسة 6 ساعات المباشرة والإخراج الحالي والأحجار الكريمة للشبكة التي تهم.';
}
