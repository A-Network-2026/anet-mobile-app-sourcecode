// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'A-Network';

  @override
  String get authPageSubtitle =>
      'सुरक्षित वॉलेट निरंतरता के साथ स्वच्छ Web2 माइनिंग पहुंच।';

  @override
  String get loginTab => 'लॉग इन';

  @override
  String get registerTab => 'रजिस्टर';

  @override
  String get emailHint => 'ईमेल';

  @override
  String get passwordHint => 'पासवर्ड';

  @override
  String get antCodeHint => 'Ant Code (वैकल्पिक)';

  @override
  String get continueLoginButton => 'लॉगिन जारी रखें';

  @override
  String get continueRegisterButton => 'रजिस्ट्रेशन जारी रखें';

  @override
  String get forgotPasswordButton => 'पासवर्ड भूल गए?';

  @override
  String get useExistingAccountButton => 'मौजूदा खाते से लॉगिन करें';

  @override
  String get restoreDeletedAccountButton => 'हटाया गया खाता पुनर्स्थापित करें';

  @override
  String get sessionModelTitle => 'सत्र मॉडल';

  @override
  String get sessionModelSubtitle =>
      'माइनिंग 6-घंटे के चक्रों में काम करती है और प्रगति आपके वॉलेट खाते में सिंक होती है।';

  @override
  String get securityLayerTitle => 'सुरक्षा परत';

  @override
  String get securityLayerSubtitle =>
      'सीड फ्रेज, PIN, और खाता पुनर्स्थापना सुरक्षाएं अंतर्निहित हैं।';

  @override
  String get emailPasswordRequired => 'ईमेल और पासवर्ड आवश्यक हैं';

  @override
  String get deviceLimitError =>
      'इस डिवाइस पर अधिकतम लिंक किए गए खाते पहुंच गए हैं। मौजूदा खाते से लॉगिन करें, या रजिस्टर करने के लिए एक अलग डिवाइस का उपयोग करें।';

  @override
  String get accountRestorationEligible =>
      'पुनर्स्थापना उपलब्ध है। आपका खाता हटाने के लिए शेड्यूल किया गया था।';

  @override
  String get openEmailApp => 'info@a-network.net के लिए ईमेल ऐप खोल रहे हैं';

  @override
  String get emailAppNotAvailable =>
      'ईमेल ऐप उपलब्ध नहीं, सहायता पृष्ठ खोला गया';

  @override
  String get forgotPasswordTitle => 'पासवर्ड भूल गए';

  @override
  String get forgotPasswordInstructions =>
      '6-अंकीय रीसेट कोड प्राप्त करने के लिए अपना पंजीकृत ईमेल दर्ज करें।';

  @override
  String get sendCodeButton => 'कोड भेजें';

  @override
  String get resendCodeButton => 'कोड दोबारा भेजें';

  @override
  String get sixDigitCodeHint => '6-अंकीय कोड';

  @override
  String get newPasswordHint => 'नया पासवर्ड';

  @override
  String get confirmPasswordHint => 'नया पासवर्ड पुष्टि करें';

  @override
  String get resetPasswordButton => 'पासवर्ड रीसेट करें';

  @override
  String get needHelpButton => 'सहायता चाहिए?';

  @override
  String get verifyEmailTitle => 'ईमेल सत्यापित करें';

  @override
  String verifyEmailInstructions(String email) {
    return '$email पर भेजा गया 6-अंकीय कोड दर्ज करें';
  }

  @override
  String get otpCodeHint => 'OTP कोड';

  @override
  String get verifyButton => 'सत्यापित करें';

  @override
  String get cancelButton => 'रद्द करें';

  @override
  String get emailVerificationCancelled =>
      'ईमेल सत्यापन रद्द किया गया। बाद में अपना अंतिम कोड दर्ज करें या नए के लिए कोड दोबारा भेजें पर टैप करें।';

  @override
  String get loginVerificationTitle => 'लॉगिन सत्यापन';

  @override
  String loginVerificationInstructions(String email) {
    return '$email पर भेजा गया 6-अंकीय लॉगिन कोड दर्ज करें';
  }

  @override
  String get loginVerificationCancelled =>
      'लॉगिन सत्यापन रद्द किया गया। बाद में अपना नवीनतम कोड दर्ज करें या नया अनुरोध करें।';

  @override
  String get convertedDeepLink =>
      'ANTS Browser के लिए डीप लिंक परिवर्तित किया गया';

  @override
  String blockedUnsupportedScheme(String scheme) {
    return 'असमर्थित स्कीम अवरुद्ध: $scheme';
  }

  @override
  String get untrustedDomainTitle => 'अविश्वसनीय डोमेन';

  @override
  String untrustedDomainMessage(String host, String url) {
    return 'यह डोमेन विश्वसनीय dApp सूची में नहीं है:\n\n$host\n\nURL:\n$url\n\nकेवल तभी जारी रखें जब आप इस साइट पर भरोसा करते हैं।';
  }

  @override
  String get trustForSessionButton => 'सत्र के लिए भरोसा करें';

  @override
  String get openDAppPageFirst => 'पहले एक dApp पृष्ठ खोलें';

  @override
  String connectionBlockedUntrusted(String host) {
    return 'अविश्वसनीय डोमेन के लिए कनेक्शन अवरुद्ध: $host';
  }

  @override
  String get connectWalletTitle => 'वॉलेट कनेक्ट करें';

  @override
  String connectWalletPrompt(String host, String network, String address) {
    return 'dApp: $host\nनेटवर्क: $network\nवॉलेट: $address\n\nअपना वॉलेट पता पढ़ने और हस्ताक्षर अनुरोध करने के लिए सत्र पहुंच दें?';
  }

  @override
  String get rejectButton => 'अस्वीकार करें';

  @override
  String get connectButton => 'कनेक्ट';

  @override
  String walletConnectedSnackbar(String host) {
    return '$host से वॉलेट कनेक्ट हुआ';
  }

  @override
  String get walletPINVerificationTitle => 'वॉलेट PIN सत्यापन';

  @override
  String get walletPINInstructions =>
      '5 मिनट के लिए हस्ताक्षर अनुरोध सक्षम करने के लिए अपना वॉलेट PIN दर्ज करें।';

  @override
  String get pinMustBe => 'PIN 4 से 8 अंकों का होना चाहिए';

  @override
  String get verifyingPIN => 'सत्यापित हो रहा है...';

  @override
  String get connectWalletToDApp => 'पहले वॉलेट को एक dApp से कनेक्ट करें';

  @override
  String get seedPhraseRequired =>
      'वास्तविक EVM हस्ताक्षर के लिए स्थानीय सीड फ्रेज आवश्यक है';

  @override
  String get signRequestTitle => 'हस्ताक्षर अनुरोध';

  @override
  String signRequestContent(String host, String network) {
    return 'dApp: $host\nनेटवर्क: $network';
  }

  @override
  String get messageToSign => 'हस्ताक्षर करने का संदेश';

  @override
  String get approveSignature =>
      'मैं इस हस्ताक्षर अनुरोध को मंजूरी देता/देती हूं';

  @override
  String get signButton => 'हस्ताक्षर करें';

  @override
  String get signatureApprovedTitle => 'हस्ताक्षर स्वीकृत';

  @override
  String get copyButton => 'कॉपी';

  @override
  String get closeButton => 'बंद करें';

  @override
  String get signaturePayloadCopied => 'हस्ताक्षर पेलोड कॉपी किया गया';

  @override
  String get antsBrowserTitle => 'ANTS ब्राउज़र';

  @override
  String get connectWalletTooltip => 'वॉलेट कनेक्ट करें';

  @override
  String get disconnectTooltip => 'डिस्कनेक्ट';

  @override
  String get approveSignTooltip => 'हस्ताक्षर अनुरोध स्वीकृत करें';

  @override
  String walletNotConnected(String host) {
    return 'वॉलेट कनेक्ट नहीं है। केवल विश्वसनीय होस्ट। वर्तमान: $host';
  }

  @override
  String walletConnectedStatus(String host, String network) {
    return 'कनेक्टेड: $host • $network';
  }

  @override
  String get enterURL => 'URL दर्ज करें';

  @override
  String get goButton => 'जाएं';

  @override
  String get loadingAISupport => 'AI सहायता लोड हो रही है...';

  @override
  String get aiSupportConnectionError =>
      'AI सहायता से कनेक्ट नहीं हो सका। कृपया अपना इंटरनेट कनेक्शन जांचें।';

  @override
  String get retryButton => 'पुनः प्रयास';

  @override
  String get autoRegion => 'स्वचालित (क्षेत्र)';

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
  String get securityLockTitle => 'सुरक्षा लॉक सक्रिय';

  @override
  String get securityLockMessage =>
      'इस बिल्ड ने उच्च-जोखिम रनटाइम का पता लगाया और एमुलेटर, रूटेड-डिवाइस, और छेड़छाड़ के दुरुपयोग को कम करने के लिए लॉगिन, Ant Work, और वॉलेट पहुंच को अवरुद्ध किया।';

  @override
  String detectedFlags(String flags) {
    return 'पता लगाए गए फ्लैग: $flags';
  }

  @override
  String platformRuntime(String platform, String runtime) {
    return 'प्लेटफॉर्म: $platform  |  रनटाइम: $runtime';
  }

  @override
  String get securityOverrideInfo =>
      'एक भौतिक डिवाइस पर आधिकारिक रिलीज़ का उपयोग करें। केवल आंतरिक परीक्षण के लिए, डेवलपर --dart-define=ALLOW_INSECURE_DEVICE=true के साथ इस ब्लॉक को ओवरराइड कर सकते हैं।';

  @override
  String get anetGlobal => 'A-Network ग्लोबल';

  @override
  String get globalSubtitle =>
      'पेशेवर नेटवर्क अवलोकन, माइनिंग स्थिति, और वॉलेट दृश्यता।';

  @override
  String get profileSupport => 'प्रोफ़ाइल और सहायता';

  @override
  String get halvingAnnouncementTitle => 'हाल्विंग शुरू हो गई है';

  @override
  String get halvingAnnouncementBody =>
      'नेटवर्क 5,00,000-सत्र मील के पत्थर तक पहुंच गया है। पहली हाल्विंग अब प्रभाव में है।';

  @override
  String get halvingAnnouncementNote =>
      'अपडेट की गई दर लागू होने से पहले 6-घंटे की सत्यापन देरी है। सिस्टम पहले सभी लंबित सत्रों को सत्यापित करता है। एक बार 500k मील के पत्थर की पुष्टि होने के बाद, आपका लाइव आउटपुट स्वचालित रूप से नई हाल्विंग दर पर अपडेट होगा।';

  @override
  String get halvingActionSafe =>
      'कोई कार्रवाई आवश्यक नहीं - प्रगति में सत्र सुरक्षित हैं और सही दर पर क्रेडिट होंगे।';

  @override
  String get xAnnouncementTitle => 'नवीनतम X अपडेट';

  @override
  String get xAnnouncementBody =>
      'नवीनतम आधिकारिक A-Network पोस्ट के लिए Mr_A_Awakening को फॉलो करें।';

  @override
  String get xAnnouncementNote =>
      'यह स्लाइड हाल्विंग अपडेट कार्ड के साथ हर 60 सेकंड में स्वचालित रूप से बदलती है।';

  @override
  String get xAnnouncementCTA => 'नवीनतम X अपडेट खोलें';

  @override
  String get liveStatus => 'लाइव';

  @override
  String get networkStatus => 'नेटवर्क स्थिति';

  @override
  String get totalAnts => 'कुल Ants';

  @override
  String get registered => 'पंजीकृत';

  @override
  String get activeWorkers => 'सक्रिय कार्यकर्ता';

  @override
  String get completedWork => 'पूर्ण कार्य';

  @override
  String activeTerritories(String count) {
    return 'सक्रिय क्षेत्र ($count+)';
  }

  @override
  String get verifiedSessions => 'सत्यापित सत्र';

  @override
  String get networkThroughput => 'नेटवर्क थ्रूपुट';

  @override
  String get liveOutput => 'लाइव आउटपुट';

  @override
  String get anetPerSession => 'ANET / सत्र';

  @override
  String get markets => 'बाजार';

  @override
  String get activeTerritoriesCount => 'सक्रिय क्षेत्र';

  @override
  String get liveAntWork => 'लाइव Ant Work';

  @override
  String get startingAntWork => 'ant work शुरू हो रहा है...';

  @override
  String get antWorkActive => 'Ant Work सक्रिय';

  @override
  String get readyToStart => 'शुरू करने के लिए तैयार';

  @override
  String sessionEndsIn(String time) {
    return 'सत्र $time में समाप्त होगा';
  }

  @override
  String get startAnyTime =>
      'कभी भी शुरू करें। 6-घंटे का टाइमर आपके टैप से शुरू होता है।';

  @override
  String get openAntWork => 'Ant Work खोलें';

  @override
  String get startAntWork => 'Ant Work शुरू करें';

  @override
  String get refreshActivity => 'गतिविधि रीफ्रेश करें';

  @override
  String get beginJourney => 'अपनी यात्रा शुरू करें';

  @override
  String get startAntWorkInfo =>
      'एक सत्यापित 6-घंटे का Ant Work सत्र शुरू करें। गतिविधि पहले ANTS में ट्रैक की जाती है, फिर ANET में दावा योग्य बन जाती है।';

  @override
  String get anetWalletAction => 'ANET वॉलेट';

  @override
  String get balanceWalletTools => 'बैलेंस, वॉलेट टूल्स, चेन दृश्यता';

  @override
  String get anetWalletInfo =>
      'वॉलेट टूल्स, वर्तमान बैलेंस मैपिंग, और सार्वजनिक इकोसिस्टम दृश्यता खोलें।';

  @override
  String get sessionOutput => 'सत्र आउटपुट';

  @override
  String get anetPer6Hour => 'ANET प्रति 6-घंटे चक्र';

  @override
  String get portfolio => 'पोर्टफोलियो';

  @override
  String get antsAccumulated => 'ANTS संचित';

  @override
  String get typeWebsite => 'पहले एक वेबसाइट या कीवर्ड टाइप करें';

  @override
  String get createWalletFirst => 'पहले अपना वॉलेट बनाएं';

  @override
  String get walletBalanceSynced => 'माइन किए गए ANET से वॉलेट बैलेंस सिंक हुआ';

  @override
  String get noColonyMessage =>
      'आपकी कॉलोनी तैयार है। कोई अपलाइन आवश्यक नहीं। एक कॉलोनी नाम चुनें और अपने Ant Code से ants को आमंत्रित करें।';

  @override
  String get noColonyMessagesYet => 'अभी तक कोई कॉलोनी संदेश नहीं।';

  @override
  String get myAntCodeTitle => 'मेरा Ant Code लिंक';

  @override
  String antCodeLabel(String code) {
    return 'Ant Code: $code';
  }

  @override
  String get referralLinksLabel => 'रेफरल लिंक';

  @override
  String get openGoogleLink => 'Google लिंक खोलें';

  @override
  String get openAPKLink => 'APK लिंक खोलें';

  @override
  String get copyShareText => 'शेयर टेक्स्ट कॉपी करें';

  @override
  String get colonyTrackerTitle => 'कॉलोनी ट्रैकर';

  @override
  String get colonyDescription =>
      'कॉलोनी भविष्य की Web5 समुदाय परत है। यह अभी के लिए केवल देखने योग्य है।';

  @override
  String get operatingModel =>
      'ऑपरेटिंग मॉडल: Web2 = Ant Work माइनिंग और ANTS अकाउंटिंग। Web3 = BNB Chain दृश्यता। Web4 = ANET-Chain सेटलमेंट। Web5 = ANTS Program के साथ समुदाय समन्वय।';

  @override
  String get futureAnetCoreNote =>
      'भविष्य का ANET Core नोट: इस खाते में बाद के पार्टनर ऑनबोर्डिंग के लिए पहले से ही Web3 वॉलेट तैयार है।';

  @override
  String get futureCorNoteNoWallet =>
      'भविष्य का ANET Core नोट: बाद के पार्टनर ऑनबोर्डिंग में अलग Web3 वॉलेट आवश्यकता हो सकती है, लेकिन इस बिल्ड में कोई buy-in लागू नहीं है।';

  @override
  String get yourAntCode => 'आपका Ant Code';

  @override
  String directColonyAnts(String count) {
    return 'प्रत्यक्ष कॉलोनी Ants: $count';
  }

  @override
  String colonyCompleted1K(String count) {
    return 'कॉलोनी Ants ने 1k सत्र पूरे किए: $count';
  }

  @override
  String totalColonySessions(String count) {
    return 'कुल कॉलोनी सत्र: $count';
  }

  @override
  String get communityVisibilityOnly =>
      'वर्तमान स्थिति: केवल समुदाय दृश्यता। CP, रैंक, स्नैपशॉट ANET बैलेंस से अलग हैं।';

  @override
  String get blockchainTransparency =>
      'ब्लॉकचेन पारदर्शिता: उपयोगकर्ता ANET-Chain के माध्यम से सार्वजनिक चेन गतिविधि निरीक्षण कर सकते हैं।';

  @override
  String yourCompletedSessions(String sessions, String target) {
    return 'आपके पूर्ण सत्र: $sessions / $target';
  }

  @override
  String remainingTo1K(String remaining) {
    return '1k तक शेष: $remaining';
  }

  @override
  String get colonySessionProgress => 'कॉलोनी सत्र प्रगति';

  @override
  String get noColonyAnts => 'अभी तक कोई कॉलोनी ants नहीं।';

  @override
  String completedSessionsAnt(String sessions) {
    return 'पूर्ण सत्र: $sessions / 1000';
  }

  @override
  String get qualifiedFor1KMilestone => '1k मील के पत्थर के लिए योग्य';

  @override
  String get copyAntCode => 'कोड कॉपी करें';

  @override
  String get shareColony => 'कॉलोनी शेयर करें';

  @override
  String get copyGoogleLink => 'Google लिंक कॉपी करें';

  @override
  String get copyAPKLink => 'APK लिंक कॉपी करें';

  @override
  String get seedPhraseBackupTitle => 'सीड फ्रेज बैकअप';

  @override
  String get securityCheckRequired =>
      'सुरक्षा जांच आवश्यक। जारी रखने के लिए अपना वॉलेट PIN दर्ज करें।';

  @override
  String get walletPINHint => 'वॉलेट PIN';

  @override
  String get sendOTPButton => 'OTP भेजें';

  @override
  String get emailOTPHint => 'ईमेल OTP';

  @override
  String get neverSharePhrase =>
      'यह फ्रेज कभी शेयर न करें। इस फ्रेज वाला कोई भी आपके वॉलेट को नियंत्रित कर सकता है।';

  @override
  String get revealButton => 'प्रकट करें';

  @override
  String get setWalletPINTitle => 'वॉलेट PIN सेट करें';

  @override
  String get changeWalletPINTitle => 'वॉलेट PIN बदलें';

  @override
  String get changePINRequiresOTP =>
      'PIN बदलने के लिए आपके पंजीकृत ईमेल से OTP सत्यापन आवश्यक है।';

  @override
  String get registeredEmail => 'पंजीकृत ईमेल';

  @override
  String get currentPIN => 'वर्तमान PIN';

  @override
  String get newPINHint => 'नया PIN (4-8 अंक)';

  @override
  String get forgotPINButton => 'PIN भूल गए?';

  @override
  String get forgotWalletPINTitle => 'वॉलेट PIN भूल गए';

  @override
  String get forgotPINInstructions =>
      'ईमेल सत्यापन के माध्यम से अपना वॉलेट PIN रीसेट करें। हम आपके पंजीकृत ईमेल पर 6-अंकीय कोड भेजेंगे।';

  @override
  String get sixDigitVerificationCode => '6-अंकीय सत्यापन कोड';

  @override
  String get pinResetSuccessful => 'PIN सफलतापूर्वक रीसेट हुआ';

  @override
  String get deleteAccountTitle => 'खाता हटाएं';

  @override
  String get deleteAccountMessage =>
      'यह सुरक्षा अवधि के बाद आपके खाते को हटाने के लिए शेड्यूल करेगा।';

  @override
  String get enterPINToConfirm => 'पुष्टि करने के लिए PIN दर्ज करें';

  @override
  String get deleteButton => 'हटाएं';

  @override
  String get deletionRequested => 'हटाने का अनुरोध किया गया';

  @override
  String get welcomeTitle => 'A-Network में आपका स्वागत है';

  @override
  String get tutorialStep1 =>
      '1) Ant Work शुरू करें और एक सत्र पूरा करने के लिए 6 घंटे प्रतीक्षा करें।';

  @override
  String get tutorialStep2 =>
      '2) आप पहले ANTS जमा करते हैं। 100,000,000 ANTS = 1 ANET।';

  @override
  String get tutorialStep3 =>
      '3) पूर्ण ANET रूपांतरण सुविधाओं के लिए पात्र होने के लिए 1,000 सत्र तक पहुंचें।';

  @override
  String get tutorialStep4 =>
      '4) अपने वॉलेट की रक्षा करें: PIN सेट करें और केवल जरूरत पड़ने पर अपना सीड प्रकट करें।';

  @override
  String get gotItButton => 'समझ गया';

  @override
  String get accountProfileTitle => 'खाता प्रोफ़ाइल';

  @override
  String get levelEligible => 'स्तर पात्रता: पात्र';

  @override
  String levelNotEligible(String remaining) {
    return 'स्तर पात्रता: अभी पात्र नहीं ($remaining सत्र शेष)';
  }

  @override
  String get web4MigrationWalletTitle => 'Web4 माइग्रेशन वॉलेट';

  @override
  String get migrationWalletOptional =>
      'वैकल्पिक: अभी अपना भविष्य का Web4 माइग्रेशन वॉलेट पता दर्ज करें।';

  @override
  String get migrationWalletExample =>
      'उदाहरण: ANET1A2B3C4D5E6F... (ANET + 36 hex अक्षर)';

  @override
  String get saveButton => 'सहेजें';

  @override
  String get migrationWalletNotChanged => 'माइग्रेशन वॉलेट पता नहीं बदला';

  @override
  String get migrationWalletSaved => 'माइग्रेशन वॉलेट पता सहेजा गया';

  @override
  String get changeEmailTitle => 'ईमेल बदलें';

  @override
  String get newEmailHint => 'नया ईमेल';

  @override
  String get currentPasswordHint => 'वर्तमान पासवर्ड';

  @override
  String get emailChangedSuccessfully => 'ईमेल सफलतापूर्वक बदला गया';

  @override
  String get changePasswordTitle => 'पासवर्ड बदलें';

  @override
  String get newPasswordMin8 => 'नया पासवर्ड (न्यूनतम 8 अक्षर)';

  @override
  String get passwordChangedSuccessfully => 'पासवर्ड सफलतापूर्वक बदला गया';

  @override
  String get securityOwnershipTitle => 'सुरक्षा और स्वामित्व';

  @override
  String get emailVerificationNote =>
      'A-Network वर्तमान में पंजीकरण के दौरान OTP के माध्यम से ईमेल सत्यापन लागू करता है।';

  @override
  String get otpVerificationOneTime =>
      'यह OTP सत्यापन केवल खाता सक्रियण के लिए एक बार है।';

  @override
  String get emailLossWarning =>
      'यदि आप अपने ईमेल तक पहुंच खो देते हैं और इसे पुनर्प्राप्त नहीं कर सकते, तो आप अपने खाते और माइन किए गए ANET तक पहुंच खो देते हैं।';

  @override
  String get ownershipModel =>
      'स्वामित्व मॉडल: आपका ईमेल + आपका बनाया गया वॉलेट पता = इकोसिस्टम में आपकी प्रत्यक्ष स्वामित्व कुंजी।';

  @override
  String get web4MigrationKeepSafe =>
      'Web4 माइग्रेशन के लिए, अपने ईमेल और वॉलेट विवरण दोनों को सुरक्षित रखें।';

  @override
  String get notificationsTitle => 'अधिसूचनाएं';

  @override
  String get antWorkAlertsActive =>
      'वर्तमान 6-घंटे के सत्र के लिए Ant Work अलर्ट सक्रिय हैं।';

  @override
  String get startAntWorkNotifications =>
      'अगले समापन अलर्ट को शेड्यूल करने के लिए Ant Work शुरू करें।';

  @override
  String get notificationsInfo =>
      'अधिसूचनाएं सत्यापित सत्र अनुस्मारक, समापन समय और महत्वपूर्ण इकोसिस्टम अपडेट के लिए उपयोग की जाती हैं।';

  @override
  String get sessionRunning =>
      'वर्तमान स्थिति: सत्र चल रहा है, समापन अनुस्मारक लंबित।';

  @override
  String get noActiveSession =>
      'वर्तमान स्थिति: कोई सक्रिय सत्र नहीं, इसलिए अभी तक कोई समापन अनुस्मारक शेड्यूल नहीं है।';

  @override
  String get refreshButton => 'रीफ्रेश';

  @override
  String get languageTitle => 'भाषा';

  @override
  String get languageHelp =>
      'अपनी ऐप भाषा चुनें। स्वचालित मोड क्षेत्र डिफ़ॉल्ट मैप करता है: भारत → हिन्दी, पाकिस्तान → उर्दू, चीन → चीनी, स्पेन/लातिन अमेरिका → Español, वियतनाम → Vietnamese।';

  @override
  String get aboutTitle => 'A-Network के बारे में';

  @override
  String get aboutContent =>
      'A-Network का संचालन A Network LLC, California Entity No. 20260170159 द्वारा किया जाता है।\n\nउत्पादन मॉडल ANTS-प्रथम अकाउंटिंग का उपयोग करता है, जहाँ 1 ANET = 100,000,000 ANTS।';

  @override
  String get openWeb4Button => 'Web4 खोलें';

  @override
  String get displayThemeTitle => 'डिस्प्ले थीम';

  @override
  String get classicTheme => 'क्लासिक मुख्य थीम';

  @override
  String get classicThemeDesc => 'मौजूदा A-Network cyan प्रस्तुति।';

  @override
  String get antsTheme => 'ANTS इकोसिस्टम थीम';

  @override
  String get antsThemeDesc =>
      'Web4-प्रेरित हरा, cyan, और सोना निवेशक स्टाइलिंग।';

  @override
  String get studioTheme => 'स्टूडियो लाइट थीम';

  @override
  String get studioThemeDesc =>
      'कनेक्टेड पार्टिकल्स और कूल ब्लू एक्सेंट के साथ पेशेवर लाइट बैकड्रॉप।';

  @override
  String get executiveTheme => 'एग्जीक्यूटिव डार्क थीम';

  @override
  String get executiveThemeDesc =>
      'तेज निवेशक प्रस्तुति के लिए शैंपेन एक्सेंट के साथ ग्रेफाइट सरफेस।';

  @override
  String get paperTheme => 'पेपर लाइट थीम';

  @override
  String get paperThemeDesc =>
      'इंक-ब्लू लेबल के साथ गर्म संपादकीय लाइट स्टाइलिंग।';

  @override
  String get viewProfileDetails => 'प्रोफ़ाइल विवरण देखें';

  @override
  String get changeEmail => 'ईमेल बदलें';

  @override
  String get changePassword => 'पासवर्ड बदलें';

  @override
  String get helpSupport => 'सहायता और समर्थन';

  @override
  String get logoutButton => 'लॉग आउट';

  @override
  String get sixHourAntWorkComplete =>
      '6-घंटे का ant work सत्र पूरा हुआ। आपका ANET सत्र क्रेडिट पोस्ट हो रहा है...';

  @override
  String antWorkCompletedAccumulated(String reward) {
    return '✅ Ant Work पूरा हुआ! आपने $reward ANET जमा किए';
  }

  @override
  String antWorkAutoCompleted(String reward) {
    return '✅ Ant Work स्वतः पूरा हुआ। $reward ANET क्रेडिट हुआ।';
  }

  @override
  String get antWorkStartedSuccessfully => 'Ant Work सफलतापूर्वक शुरू हुआ';

  @override
  String completeAntWorkFailed(String error) {
    return 'Ant Work पूर्ण करने में विफल: $error';
  }

  @override
  String startAntWorkFailed(String error) {
    return 'Ant Work शुरू करने में विफल: $error';
  }

  @override
  String get territoryOverview => 'क्षेत्र अवलोकन';

  @override
  String get totalAntsDialog => 'कुल Ants';

  @override
  String get networkShare => 'नेटवर्क हिस्सा';

  @override
  String get activeWorkersDialog => 'सक्रिय कार्यकर्ता';

  @override
  String get sessionsInTerritory => 'क्षेत्र में सत्र';

  @override
  String get liveBackendStats => 'स्रोत: लाइव बैकएंड देश आँकड़े।';

  @override
  String get fallbackEstimate =>
      'स्रोत: फॉलबैक अनुमान। देश आँकड़े एंडपॉइंट अनुपलब्ध।';

  @override
  String get web3AnetMarket => 'Web3 ANET बाजार';

  @override
  String get marketImportance =>
      'महत्वपूर्ण: इस ऐप में माइन किया गया ANET Ant Work के माध्यम से संचित होता है। BNB Chain ANET अनुबंध अलग Web3 दृश्यता परत है।';

  @override
  String get bnbChainContract => 'BNB Chain बाजार अनुबंध';

  @override
  String get currentSeparation => 'वर्तमान पृथक्करण';

  @override
  String get separationPoint1 =>
      '1. इस ऐप में ANET coins सत्यापित सत्रों के माध्यम से संचित होते हैं।';

  @override
  String get separationPoint2 =>
      '2. BNB Chain ANET अनुबंध और DEX संदर्भ अलग Web3 दृश्यता उपकरण हैं।';

  @override
  String get separationPoint3 =>
      '3. Colony, CP, रैंक, स्नैपशॉट ANET और ANTS अकाउंटिंग मॉडल से बाहर हैं।';

  @override
  String get separationPoint4 =>
      '4. पूर्ण ब्लॉकचेन पारदर्शिता ANET-Chain के माध्यम से उपलब्ध है।';

  @override
  String get openMarketPair => 'मार्केट पेयर खोलें';

  @override
  String get viewLiveChart => 'लाइव चार्ट देखें';

  @override
  String get viewContract => 'अनुबंध देखें';

  @override
  String get copyContractAddress => 'अनुबंध कॉपी करें';

  @override
  String get anetMarketContract => 'ANET बाजार अनुबंध';

  @override
  String get moreInfo => 'अधिक जानकारी';

  @override
  String get createYourL1Wallet => 'पहले अपना L1 वॉलेट बनाएं';

  @override
  String get createL1WalletMessage =>
      'आपका BIP-44 सीड सभी EVM वॉलेट के साथ संगत है।';

  @override
  String get generateWallet => 'वॉलेट जनरेट करें';

  @override
  String get walletLocked => 'वॉलेट लॉक है';

  @override
  String get setPINToContinue => 'जारी रखने के लिए PIN सेट करें';

  @override
  String get enterWalletPIN =>
      'अपने Web3 वॉलेट तक पहुंचने के लिए अपना वॉलेट PIN दर्ज करें।';

  @override
  String get setWalletPINAccess =>
      'एक्सेस करने से पहले अपने वॉलेट को सुरक्षित करने के लिए PIN सेट करें।';

  @override
  String get unlockWallet => 'वॉलेट अनलॉक करें';

  @override
  String get setWalletPINButton => 'वॉलेट PIN सेट करें';

  @override
  String get mainnetWallet => 'Mainnet वॉलेट';

  @override
  String get homeTab => 'होम';

  @override
  String get assetsTab => 'संपत्ति';

  @override
  String get activityTab => 'गतिविधि';

  @override
  String get sessionsTab => 'सत्र';

  @override
  String get addToken => 'टोकन जोड़ें';

  @override
  String get totalBalance => 'कुल बैलेंस';

  @override
  String get send => 'भेजें';

  @override
  String get receive => 'प्राप्त करें';

  @override
  String get explorer => 'एक्सप्लोरर';

  @override
  String get bridge => 'ब्रिज';

  @override
  String get miningProfile => 'माइनिंग प्रोफ़ाइल';

  @override
  String get joined => 'शामिल हुए';

  @override
  String get completedSessions => 'पूर्ण सत्र';

  @override
  String get anetBalance => 'ANET बैलेंस';

  @override
  String get currentRate => 'वर्तमान दर';

  @override
  String get colonyJoined => 'कॉलोनी में शामिल';

  @override
  String get notInColony => 'किसी कॉलोनी में नहीं';

  @override
  String get sessionHistory => 'सत्र इतिहास';

  @override
  String get credited => 'क्रेडिट हुआ';

  @override
  String get inProgress => 'प्रगति में';

  @override
  String get aiSupportTitle => 'A-Network AI';

  @override
  String get trainButton => 'प्रशिक्षित करें';

  @override
  String get web4MigrationPolicy => 'Web4 माइग्रेशन नीति';

  @override
  String get anetVsAnts => 'ANET बनाम ANTS';

  @override
  String get securityWalletSafety => 'सुरक्षा और वॉलेट सुरक्षा';

  @override
  String get trainAITitle => 'A-Network AI को प्रशिक्षित करें';

  @override
  String get knowledgeHint =>
      'याद रखने के लिए ज्ञान (तथ्य, नीतियां, उत्पाद विवरण)';

  @override
  String get optionalTrainingPrompt => 'वैकल्पिक प्रशिक्षण प्रॉम्प्ट';

  @override
  String get optionalIdealResponse => 'वैकल्पिक आदर्श प्रतिक्रिया';

  @override
  String get addMemoryOrBoth =>
      'मेमोरी टेक्स्ट, या प्रशिक्षण प्रॉम्प्ट और आदर्श प्रतिक्रिया दोनों जोड़ें।';

  @override
  String get aiTrainingSaved => 'AI प्रशिक्षण सहेजा गया';

  @override
  String get noAITokensLeft =>
      'कोई AI टोकन नहीं बचे। अधिक टोकन के लिए एक विज्ञापन देखें या 6-घंटे की रिफिल का इंतजार करें।';

  @override
  String get voiceRecognitionUnavailable =>
      'इस डिवाइस पर वॉयस पहचान उपलब्ध नहीं है';

  @override
  String get noAssistantResponse =>
      'जोर से पढ़ने के लिए कोई सहायक प्रतिक्रिया उपलब्ध नहीं';

  @override
  String get adNotCompleted =>
      'विज्ञापन पूरा नहीं हुआ। अभी तक कोई टोकन पुरस्कार नहीं।';

  @override
  String aiTokensAdded(String tokens, String balance) {
    return '$tokens AI टोकन जोड़े गए। बैलेंस: $balance';
  }

  @override
  String uploadedToMemory(String filename) {
    return '$filename AI मेमोरी में अपलोड किया गया';
  }

  @override
  String get copiedResponse => 'प्रतिक्रिया कॉपी की गई';

  @override
  String get listeningSpeak => 'सुन रहे हैं... अपना प्रश्न बोलें';

  @override
  String get askAIAnything => 'A-Network AI से कुछ भी पूछें...';

  @override
  String get deepResearchEnabled => 'अगले संदेशों के लिए गहन शोध सक्षम';

  @override
  String get deepResearchDisabled => 'गहन शोध अक्षम';

  @override
  String get uploadTxtTooltip =>
      'AI को प्रशिक्षित करने के लिए txt/md/pdf अपलोड करें';

  @override
  String get stopListeningTooltip => 'सुनना बंद करें';

  @override
  String get startVoiceInputTooltip => 'वॉयस इनपुट शुरू करें';

  @override
  String get stopReadAloudTooltip => 'जोर से पढ़ना बंद करें';

  @override
  String get readLatestResponseTooltip => 'नवीनतम प्रतिक्रिया जोर से पढ़ें';

  @override
  String watchAdTokens(String tokens) {
    return 'विज्ञापन देखें + $tokens टोकन';
  }

  @override
  String tokenBalance(String balance) {
    return 'टोकन: $balance';
  }

  @override
  String get pickGroupName => 'अपना समूह नाम चुनें';

  @override
  String get claimPermanentUpline => 'स्थायी अपलाइन का दावा करें';

  @override
  String get claimUplineInstructions =>
      'अपनी कॉलोनी रखने के लिए कोई अपलाइन आवश्यक नहीं है। Ant Code यहाँ केवल तभी दर्ज करें जब आप उस मालिक की कॉलोनी में स्थायी रूप से शामिल होना चाहते हैं।';

  @override
  String get enterAntCode => 'Ant Code दर्ज करें';

  @override
  String get claimButton => 'दावा करें';

  @override
  String get antCodeLinked =>
      'Ant Code लिंक हुआ। आपकी कॉलोनी अपलाइन अब स्थायी है।';

  @override
  String get writeToColony => 'अपनी कॉलोनी को लिखें';

  @override
  String get writeToUplines => 'अपने कॉलोनी अपलाइन को लिखें';

  @override
  String get pickGroupNameTooltip => 'समूह नाम चुनें';

  @override
  String get refreshChatTooltip => 'चैट रीफ्रेश करें';

  @override
  String get tabEcosystem => 'पारिस्थितिकी तंत्र';

  @override
  String get tabAntWork => 'एंट वर्क';

  @override
  String get tabWallet => 'वॉलेट';

  @override
  String get tabColony => 'कॉलोनी';

  @override
  String get tabMore => 'अधिक';

  @override
  String get pageTitleEcosystem => 'एंट इकोसिस्टम';

  @override
  String get pageTitleAntWork => 'एंट वर्क';

  @override
  String get pageTitleWallet => 'ANET वॉलेट';

  @override
  String get pageTitleWeb4 => 'Web4';

  @override
  String get pageTitleWhitepaper => 'श्वेत पत्र';

  @override
  String get pageTitleColony => 'कॉलोनी (Web5)';

  @override
  String get pageTitleMore => 'अधिक';

  @override
  String get antWorkSectionLabel => 'एंट वर्क';

  @override
  String get morePageTitle => 'अधिक';

  @override
  String get morePageSubtitle =>
      'खाता, कानूनी, सहायता और प्रदर्शन नियंत्रण एक जगह।';

  @override
  String get walletMenuLabel => 'वॉलेट';

  @override
  String get walletMenuSubtitle => 'बैलेंस और Web3 टूल्स';

  @override
  String get antWorkHeroTitle => 'एंट वर्क';

  @override
  String get antWorkHeroSubtitle =>
      'लाइव 6-घंटे के सत्र, वर्तमान आउटपुट और नेटवर्क माइलस्टोन की निगरानी करें।';
}
