// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appName => 'A-Network';

  @override
  String get authPageSubtitle =>
      'Güvenli cüzdan sürekliliği ile temiz Web2 madencilik erişimi.';

  @override
  String get loginTab => 'Giriş Yap';

  @override
  String get registerTab => 'Kaydol';

  @override
  String get emailHint => 'E-posta';

  @override
  String get passwordHint => 'Şifre';

  @override
  String get antCodeHint => 'Ant Kodu (İsteğe bağlı)';

  @override
  String get continueLoginButton => 'Girişe Devam Et';

  @override
  String get continueRegisterButton => 'Kayda Devam Et';

  @override
  String get forgotPasswordButton => 'Şifremi Unuttum?';

  @override
  String get useExistingAccountButton => 'Mevcut Hesap Girişini Kullan';

  @override
  String get restoreDeletedAccountButton => 'Silinen Hesabı Geri Yükle';

  @override
  String get sessionModelTitle => 'Oturum Modeli';

  @override
  String get sessionModelSubtitle =>
      'Madencilik 6 saatlik döngülerde çalışır ve ilerleme cüzdan hesabınıza senkronize olur.';

  @override
  String get securityLayerTitle => 'Güvenlik Katmanı';

  @override
  String get securityLayerSubtitle =>
      'Tohum ifadesi, PIN ve hesap geri yükleme korumaları yerleşiktir.';

  @override
  String get emailPasswordRequired => 'E-posta ve şifre gereklidir';

  @override
  String get deviceLimitError =>
      'Bu cihaz zaten maksimum bağlı hesaplara ulaştı. Mevcut bir hesapla giriş yapın veya kaydolmak için farklı bir cihaz kullanın.';

  @override
  String get accountRestorationEligible =>
      'Geri yükleme mevcut. Hesabınız silme için planlanmıştı.';

  @override
  String get openEmailApp =>
      'E-posta uygulaması info@a-network.net için açılıyor';

  @override
  String get emailAppNotAvailable =>
      'E-posta uygulaması kullanılamıyor, destek sayfası açıldı';

  @override
  String get forgotPasswordTitle => 'Şifremi Unuttum';

  @override
  String get forgotPasswordInstructions =>
      'Sıfırlama kodu almak için kayıtlı e-postanızı girin.';

  @override
  String get sendCodeButton => 'Kodu Gönder';

  @override
  String get resendCodeButton => 'Kodu Yeniden Gönder';

  @override
  String get sixDigitCodeHint => '6 haneli kod';

  @override
  String get newPasswordHint => 'Yeni şifre';

  @override
  String get confirmPasswordHint => 'Yeni şifreyi onayla';

  @override
  String get resetPasswordButton => 'Şifreyi Sıfırla';

  @override
  String get needHelpButton => 'Yardıma mı ihtiyacınız var?';

  @override
  String get verifyEmailTitle => 'E-postayı Doğrula';

  @override
  String verifyEmailInstructions(String email) {
    return '$email adresine gönderilen 6 haneli kodu girin';
  }

  @override
  String get otpCodeHint => 'OTP Kodu';

  @override
  String get verifyButton => 'Doğrula';

  @override
  String get cancelButton => 'İptal';

  @override
  String get emailVerificationCancelled =>
      'E-posta doğrulaması iptal edildi. Son kodunuzu daha sonra girin veya yeni bir kod almak için Kodu Yeniden Gönder\'e dokunun.';

  @override
  String get loginVerificationTitle => 'Giriş Doğrulaması';

  @override
  String loginVerificationInstructions(String email) {
    return '$email adresine gönderilen 6 haneli giriş kodunu girin';
  }

  @override
  String get loginVerificationCancelled =>
      'Giriş doğrulaması iptal edildi. Son kodunuzu daha sonra girin veya yeni bir kod isteyin.';

  @override
  String get convertedDeepLink =>
      'ANTS Tarayıcı için dönüştürülen derin bağlantı';

  @override
  String blockedUnsupportedScheme(String scheme) {
    return 'Desteklenmeyen şema engellendi: $scheme';
  }

  @override
  String get untrustedDomainTitle => 'Güvenilmeyen Etki Alanı';

  @override
  String untrustedDomainMessage(String host, String url) {
    return 'Bu etki alanı güvenilir dApp listesinde değil:\n\n$host\n\nURL:\n$url\n\nSadece bu siteye güveniyorsanız devam edin.';
  }

  @override
  String get trustForSessionButton => 'Bu Oturum İçin Güven';

  @override
  String get openDAppPageFirst => 'Önce bir dApp sayfası açın';

  @override
  String connectionBlockedUntrusted(String host) {
    return 'Güvenilmeyen etki alanı için bağlantı engellendi: $host';
  }

  @override
  String get connectWalletTitle => 'Cüzdanı Bağla';

  @override
  String connectWalletPrompt(String host, String network, String address) {
    return 'dApp: $host\nAğ: $network\nCüzdan: $address\n\nCüzdan adresinizi okumak ve imza isteklerinde bulunmak için oturum erişimi verilsin mi?';
  }

  @override
  String get rejectButton => 'Reddet';

  @override
  String get connectButton => 'Bağla';

  @override
  String walletConnectedSnackbar(String host) {
    return 'Cüzdan $host ile bağlandı';
  }

  @override
  String get walletPINVerificationTitle => 'Cüzdan PIN Doğrulaması';

  @override
  String get walletPINInstructions =>
      'İmza isteklerini 5 dakika boyunca etkinleştirmek için cüzdan PIN\'inizi girin.';

  @override
  String get pinMustBe => 'PIN 4 ile 8 basamak arasında olmalıdır';

  @override
  String get verifyingPIN => 'Doğrulanıyor...';

  @override
  String get connectWalletToDApp => 'Önce cüzdanı bir dApp\'e bağlayın';

  @override
  String get seedPhraseRequired =>
      'Gerçek EVM imzalamak için güvenli yerel tohum ifadesi gereklidir';

  @override
  String get signRequestTitle => 'İmza İsteği';

  @override
  String signRequestContent(String host, String network) {
    return 'dApp: $host\nAğ: $network';
  }

  @override
  String get messageToSign => 'İmzalanacak mesaj';

  @override
  String get approveSignature => 'Bu imza isteğini onaylıyorum';

  @override
  String get signButton => 'İmzala';

  @override
  String get signatureApprovedTitle => 'İmza Onaylandı';

  @override
  String get copyButton => 'Kopyala';

  @override
  String get closeButton => 'Kapat';

  @override
  String get signaturePayloadCopied => 'İmza yükü kopyalandı';

  @override
  String get antsBrowserTitle => 'ANTS Tarayıcı';

  @override
  String get connectWalletTooltip => 'Cüzdanı bağla';

  @override
  String get disconnectTooltip => 'Bağlantıyı kes';

  @override
  String get approveSignTooltip => 'İmza isteğini onayla';

  @override
  String walletNotConnected(String host) {
    return 'Cüzdan bağlı değil. Sadece güvenilir konaklar. Mevcut: $host';
  }

  @override
  String walletConnectedStatus(String host, String network) {
    return 'Bağlı: $host • $network';
  }

  @override
  String get enterURL => 'URL girin';

  @override
  String get goButton => 'Git';

  @override
  String get loadingAISupport => 'Yapay Zeka Desteği Yükleniyor...';

  @override
  String get aiSupportConnectionError =>
      'Yapay Zeka Desteğine bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.';

  @override
  String get retryButton => 'Tekrar Dene';

  @override
  String get autoRegion => 'Otomatik (Bölge)';

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
  String get securityLockTitle => 'Güvenlik Kilidi Etkin';

  @override
  String get securityLockMessage =>
      'Bu derleme yüksek riskli bir çalışma zamanı algıladı ve öykünücü, köklü cihaz ve kurcalama istismarını azaltmak için girişi, Ant Work\'ü ve cüzdan erişimini engelledi.';

  @override
  String detectedFlags(String flags) {
    return 'Algılanan bayraklar: $flags';
  }

  @override
  String platformRuntime(String platform, String runtime) {
    return 'Platform: $platform  |  Çalışma Zamanı: $runtime';
  }

  @override
  String get securityOverrideInfo =>
      'Fiziksel bir cihazda resmi bir sürüm kullanın. Yalnızca dahili test için, geliştiriciler bu bloğu --dart-define=ALLOW_INSECURE_DEVICE=true ile geçersiz kılabilir.';

  @override
  String get anetGlobal => 'A-Network Global';

  @override
  String get globalSubtitle =>
      'Profesyonel ağ genel görünümü, madencilik durumu ve cüzdan görünürlüğü.';

  @override
  String get profileSupport => 'Profil ve Destek';

  @override
  String get halvingAnnouncementTitle => 'YARILAMA BAŞLADI';

  @override
  String get halvingAnnouncementBody =>
      'Ağ 500.000 oturum miline ulaştı. İlk yarılama şimdi etkindir.';

  @override
  String get halvingAnnouncementNote =>
      'Güncellenen oran uygulanmadan önce 6 saatlik bir doğrulama gecikmesi vardır. Sistem önce tüm bekleyen oturumları doğrular. 500k miline ulaşıldıktan sonra, Canlı Çıktınız yeni yarılama oranına otomatik olarak güncellenecektir.';

  @override
  String get halvingActionSafe =>
      'İşlem gerekmez - devam eden oturumlar güvenlidir ve doğru oranda kredi alacaktır.';

  @override
  String get xAnnouncementTitle => 'SON X GÜNCELLEMESI';

  @override
  String get xAnnouncementBody =>
      'En son resmi A-Network gönderimleri için Mr_A_Awakening\'i takip edin.';

  @override
  String get xAnnouncementNote =>
      'Bu slayt, halving güncelleme kartı ile her 60 saniyede bir otomatik olarak döner.';

  @override
  String get xAnnouncementCTA => 'En son X güncellemelerini açın';

  @override
  String get liveStatus => 'CANLI';

  @override
  String get networkStatus => 'Ağ Durumu';

  @override
  String get totalAnts => 'Toplam Karıncalar';

  @override
  String get registered => 'kayıtlı';

  @override
  String get activeWorkers => 'Etkin İşçiler';

  @override
  String get completedWork => 'tamamlanan iş';

  @override
  String activeTerritories(String count) {
    return 'Etkin Bölgeler ($count+)';
  }

  @override
  String get verifiedSessions => 'DOĞRULANAN OTURUMLAR';

  @override
  String get networkThroughput => 'Ağ verimi';

  @override
  String get liveOutput => 'CANLI ÇIKTI';

  @override
  String get anetPerSession => 'ANET / oturum';

  @override
  String get markets => 'PAZARLAR';

  @override
  String get activeTerritoriesCount => 'Etkin bölgeler';

  @override
  String get liveAntWork => 'Canlı Ant Work';

  @override
  String get startingAntWork => 'Ant work başlatılıyor...';

  @override
  String get antWorkActive => 'Ant Work Etkin';

  @override
  String get readyToStart => 'Başlamaya Hazır';

  @override
  String sessionEndsIn(String time) {
    return 'Oturum şu kadar sürede sona eriyor: $time';
  }

  @override
  String get startAnyTime =>
      'Herhangi bir zaman başlayın. 6 saatlik zamanlayıcı dokunuşunuzdan başlar.';

  @override
  String get openAntWork => 'Ant Work\'ü Aç';

  @override
  String get startAntWork => 'Ant Work Başlat';

  @override
  String get refreshActivity => 'Aktiviteyi Yenile';

  @override
  String get beginJourney => 'Yolculuğunuza başlayın';

  @override
  String get startAntWorkInfo =>
      'Doğrulanan 6 saatlik Ant Work oturumu başlatın. Aktivite önce ANTS\'te takip edilir, daha sonra gerekli tamamlanan oturum eşiğine ulaşıldıktan sonra ANET\'te talep edilebilir hale gelir.';

  @override
  String get anetWalletAction => 'ANET Cüzdanı';

  @override
  String get balanceWalletTools =>
      'Bakiye, cüzdan araçları, zincir görünürlüğü';

  @override
  String get anetWalletInfo =>
      'Cüzdan araçlarını, güncel bakiye eşlemesini ve ekstra panelleri kazmadan genel ekosistem görünürlüğünü açın.';

  @override
  String get sessionOutput => 'OTURUM ÇIKTI';

  @override
  String get anetPer6Hour => '6 saatlik döngü başına ANET';

  @override
  String get portfolio => 'PORTFÖY';

  @override
  String get antsAccumulated => 'Biriktirilmiş ANTS';

  @override
  String get typeWebsite => 'Önce bir website veya anahtar kelime yazın';

  @override
  String get createWalletFirst => 'Önce cüzdanınızı oluşturun';

  @override
  String get walletBalanceSynced =>
      'Cüzdan bakiyesi kazılan ANET\'ten senkronize edildi';

  @override
  String get noColonyMessage =>
      'Koloni hazır. Yukarı akış gerekmez. Koloni adı seçin ve Ant Kodunuzla karınca davet edin.';

  @override
  String get noColonyMessagesYet => 'Henüz koloni mesajı yok.';

  @override
  String get myAntCodeTitle => 'Benim Ant Kod Bağlantısı';

  @override
  String antCodeLabel(String code) {
    return 'Ant Kodu: $code';
  }

  @override
  String get referralLinksLabel => 'Referral Bağlantıları';

  @override
  String get openGoogleLink => 'Google Bağlantısını Aç';

  @override
  String get openAPKLink => 'APK Bağlantısını Aç';

  @override
  String get copyShareText => 'Paylaş Metni Kopyala';

  @override
  String get colonyTrackerTitle => 'Koloni Takipçisi';

  @override
  String get colonyDescription =>
      'Koloni gelecekteki Web5 topluluk katmanıdır. Şu anda yalnızca görüntüleme modundadır ve Web2 madencilik oturumlarından, ANTS muhasebesi, ANET madeni para bakiyeleri ve transfer uygunluğundan ayrı kalır.';

  @override
  String get operatingModel =>
      'İşletme modeli: Web2 = Ant Work madenciliği ve ANTS muhasebesi. Web3 = BNB Zincir görünürlüğü ve sözleşme referansları. Web4 = ANET-Zincir anlaşması ve transfer görünürlüğü. Web5 = ANTS Programı ve Koloni Noktaları ile topluluk koordinasyonu. Her katman bağımsız olarak çalışır ve ödeme veya muhasebede çakışma yoktur.';

  @override
  String get futureAnetCoreNote =>
      'Gelecekteki ANET Core notu: bu hesap, daha sonraki ortak katılımı için Web3 cüzdanı hazırdır. 10 USDT muadili gibi gelecekteki BNB Zincir satın alma kuralı tanıtılırsa, madencilik ayrı olarak ve koloni puanlaması ayrı olarak uygulanacaktır.';

  @override
  String get futureCorNoteNoWallet =>
      'Gelecekteki ANET Core notu: daha sonraki ortakların katılımı ayrı Web3 cüzdanı gereksinimi kullanabilir, ancak bu derlemede satın alma veya alıcı kapısı uygulanmaz.';

  @override
  String get yourAntCode => 'Sizin Ant Kodunuz';

  @override
  String directColonyAnts(String count) {
    return 'Doğrudan Koloni Karıncaları: $count';
  }

  @override
  String colonyCompleted1K(String count) {
    return 'Koloni Karıncaları 1k Oturumları Tamamladı: $count';
  }

  @override
  String totalColonySessions(String count) {
    return 'Toplam Koloni Oturumları: $count';
  }

  @override
  String get communityVisibilityOnly =>
      'Mevcut durum: yalnızca topluluk görünürlüğü. CP, sıra, anlık görüntüler ve herhangi bir gelecekteki kontrollü dağıtım ön izlemeleri ANET madeni para bakiyelerinden ayrıdır ve ANTS muhasebesi dışında kalır.';

  @override
  String get blockchainTransparency =>
      'Blokzincir şeffaflığı: kullanıcılar ANET-Zincir aracılığıyla genel zincir aktivitesini inceleyebilir. Blokzincir görünümü şeffaflık ve anlaşma görünürlüğü içindir, koloni metrikleri ise ayrı Web5 topluluk görünümü kalır.';

  @override
  String yourCompletedSessions(String sessions, String target) {
    return 'Tamamladığınız Oturumlar: $sessions / $target';
  }

  @override
  String remainingTo1K(String remaining) {
    return '1k\'ya kalan: $remaining';
  }

  @override
  String get colonySessionProgress => 'Koloni Oturum İlerleme';

  @override
  String get noColonyAnts => 'Henüz koloni karıncası yok.';

  @override
  String completedSessionsAnt(String sessions) {
    return 'Tamamlanan Oturumlar: $sessions / 1000';
  }

  @override
  String get qualifiedFor1KMilestone => '1k kilometre taşı için uygun';

  @override
  String get copyAntCode => 'Kodu Kopyala';

  @override
  String get shareColony => 'Koloniyi Paylaş';

  @override
  String get copyGoogleLink => 'Google Bağlantısını Kopyala';

  @override
  String get copyAPKLink => 'APK Bağlantısını Kopyala';

  @override
  String get seedPhraseBackupTitle => 'Tohum İfadesi Yedeklemesi';

  @override
  String get securityCheckRequired =>
      'Güvenlik kontrolü gerekli. Devam etmek için cüzdan PIN\'inizi girin.';

  @override
  String get walletPINHint => 'Cüzdan PIN\'i';

  @override
  String get sendOTPButton => 'OTP Gönder';

  @override
  String get emailOTPHint => 'E-posta OTP';

  @override
  String get neverSharePhrase =>
      'Bu ifadeyi asla paylaşmayın. Bu ifadeye sahip olan herkes cüzdanınızı kontrol edebilir.';

  @override
  String get revealButton => 'Ortaya Çıkar';

  @override
  String get setWalletPINTitle => 'Cüzdan PIN\'i Ayarla';

  @override
  String get changeWalletPINTitle => 'Cüzdan PIN\'i Değiştir';

  @override
  String get changePINRequiresOTP =>
      'PIN\'i değiştirmek kayıtlı e-postanızdan OTP doğrulaması gerektirir.';

  @override
  String get registeredEmail => 'Kayıtlı e-posta';

  @override
  String get currentPIN => 'Mevcut PIN';

  @override
  String get newPINHint => 'Yeni PIN (4-8 basamak)';

  @override
  String get forgotPINButton => 'PIN\'i Unuttum?';

  @override
  String get forgotWalletPINTitle => 'Cüzdan PIN\'i Unuttum';

  @override
  String get forgotPINInstructions =>
      'E-posta doğrulaması aracılığıyla cüzdan PIN\'inizi sıfırlayın. Kayıtlı e-postanıza 6 haneli bir kod göndereceğiz, ardından yeni bir PIN oluşturabilirsiniz.';

  @override
  String get sixDigitVerificationCode => '6 haneli doğrulama kodu';

  @override
  String get pinResetSuccessful => 'PIN sıfırlaması başarılı';

  @override
  String get deleteAccountTitle => 'Hesabı Sil';

  @override
  String get deleteAccountMessage =>
      'Bu, güvenlik döneminden sonra hesabınızın silinmesi için zamanlayacaktır.';

  @override
  String get enterPINToConfirm => 'Onaylamak için PIN girin';

  @override
  String get deleteButton => 'Sil';

  @override
  String get deletionRequested => 'Silme istendi';

  @override
  String get welcomeTitle => 'A-Network\'e Hoş Geldiniz';

  @override
  String get tutorialStep1 =>
      '1) Ant Work\'ü başlatın ve bir oturumu tamamlamak için 6 saat bekleyin.';

  @override
  String get tutorialStep2 =>
      '2) Önce ANTS biriktirilir. 100.000.000 ANTS = 1 ANET.';

  @override
  String get tutorialStep3 =>
      '3) Tam ANET dönüştürme özelliklerine uygun olmak için 1.000 oturuma ulaşın.';

  @override
  String get tutorialStep4 =>
      '4) Cüzdanınızı koruyun: PIN ayarlayın ve tohumu yalnızca gerektiğinde ortaya çıkarın.';

  @override
  String get gotItButton => 'Anladım';

  @override
  String get accountProfileTitle => 'Hesap Profili';

  @override
  String get levelEligible => 'Seviye uygunluğu: Uygun';

  @override
  String levelNotEligible(String remaining) {
    return 'Seviye uygunluğu: Henüz uygun değil ($remaining oturum kaldı)';
  }

  @override
  String get web4MigrationWalletTitle => 'Web4 Göç Cüzdanı';

  @override
  String get migrationWalletOptional =>
      'İsteğe bağlı: gelecekteki Web4 göç cüzdan adresinizi şimdi koyun.';

  @override
  String get migrationWalletExample =>
      'Örnek: ANET1A2B3C4D5E6F... (ANET + 36 heks karakter)';

  @override
  String get saveButton => 'Kaydet';

  @override
  String get migrationWalletNotChanged => 'Göç cüzdan adresi değiştirilmedi';

  @override
  String get migrationWalletSaved => 'Göç cüzdan adresi kaydedildi';

  @override
  String get changeEmailTitle => 'E-postayı Değiştir';

  @override
  String get newEmailHint => 'Yeni e-posta';

  @override
  String get currentPasswordHint => 'Mevcut şifre';

  @override
  String get emailChangedSuccessfully => 'E-posta başarıyla değiştirildi';

  @override
  String get changePasswordTitle => 'Şifreyi Değiştir';

  @override
  String get newPasswordMin8 => 'Yeni şifre (min 8 karakter)';

  @override
  String get passwordChangedSuccessfully => 'Şifre başarıyla değiştirildi';

  @override
  String get securityOwnershipTitle => 'Güvenlik ve Sahiplik';

  @override
  String get emailVerificationNote =>
      'A-Network şu anda kayıt sırasında OTP aracılığıyla e-posta doğrulaması uygular.';

  @override
  String get otpVerificationOneTime =>
      'Bu OTP doğrulaması hesap aktivasyonu için sadece bir defalık olur.';

  @override
  String get emailLossWarning =>
      'E-postanıza erişimi kaybederseniz ve kurtaramazsanız, hesabınıza ve kazılan ANET\'e erişimi kaybedersiniz.';

  @override
  String get ownershipModel =>
      'Sahiplik modeli: E-postanız + oluşturduğunuz Cüzdan adresi = ekosistem genelinde doğrudan sahiplik anahtarınız.';

  @override
  String get web4MigrationKeepSafe =>
      'Web4 göçü için hem e-postanızı hem de cüzdan bilgilerinizi güvenli tutun.';

  @override
  String get notificationsTitle => 'Bildirimler';

  @override
  String get antWorkAlertsActive =>
      'Ant Work uyarıları mevcut 6 saatlik oturum için etkindir.';

  @override
  String get startAntWorkNotifications =>
      'Sonraki tamamlama uyarısını zamanlamak için Ant Work\'ü başlatın.';

  @override
  String get notificationsInfo =>
      'Bildirimler doğrulanan oturum anımsatıcıları, tamamlama zamanlaması ve önemli ekosistem güncellemeleri için kullanılır. Güvenilir teslimat için, Android bildirimlerine izin verin ve A-Network için pil kısıtlamalarını devre dışı bırakın.';

  @override
  String get sessionRunning =>
      'Mevcut durum: oturum çalışıyor, tamamlama anımsatıcısı beklemede.';

  @override
  String get noActiveSession =>
      'Mevcut durum: etkin oturum yok, bu nedenle henüz tamamlama anımsatıcısı planlanmadı.';

  @override
  String get refreshButton => 'Yenile';

  @override
  String get languageTitle => 'Dil';

  @override
  String get languageHelp =>
      'Uygulama dilinizi seçin. Otomatik mod bölge varsayılanlarını eşleştirir: Hindistan → Hintçe, Pakistan → Urduca, Çin → Çince, İspanya/Latin Amerika → İspanyolca, Vietnam → Vietnamca ve diğer bölgeler için İngilizce yedek.';

  @override
  String get aboutTitle => 'A-Network Hakkında';

  @override
  String get aboutContent =>
      'A-Network, California Kuruluşu No. 20260170159 olan A Network LLC tarafından işletilir.\n\nÜretim modeli ANTS-ilk muhasebesi kullanır; burada 1 ANET = 100.000.000 ANTS. Ant Work doğrulanan 6 saatlik oturumlarda çalışır, ANET uygunluk oturum eşiğine ulaşıldıktan sonra talep edilebilir hale gelir ve yarılama, ağ genelinde toplam doğrulanan oturumlar tarafından yapılır.\n\nAnt Kodları yalnızca koloni erişimini bağlar. Referanslar koloni ağınızı büyütür ancak madeni para bonusu, oturum kredileri veya yüzde komisyonları vermez. Koloni Noktaları (CP) yalnızca görüntüleme performans metrikleridir. A Network finansal getiri garantisi vermez.';

  @override
  String get openWeb4Button => 'Web4\'ü Aç';

  @override
  String get displayThemeTitle => 'Ekran Teması';

  @override
  String get classicTheme => 'Klasik Ana Tema';

  @override
  String get classicThemeDesc => 'Mevcut A-Network siyan sunumu.';

  @override
  String get antsTheme => 'ANTS Ekosistem Teması';

  @override
  String get antsThemeDesc =>
      'Web4 esinli yeşil, siyan ve altın yatırımcı stili.';

  @override
  String get studioTheme => 'Studio Açık Tema';

  @override
  String get studioThemeDesc =>
      'Bağlantılı parçacıklar ve cool mavi aksanlar ile profesyonel ışık arka plan.';

  @override
  String get executiveTheme => 'Yönetici Koyu Tema';

  @override
  String get executiveThemeDesc =>
      'Daha keskin yatırımcı sunumu için şampanya aksanları ile grafit yüzeyler.';

  @override
  String get paperTheme => 'Kağıt Açık Tema';

  @override
  String get paperThemeDesc =>
      'Mürekkep mavi etiketler ve daha yumuşak hareket ile sıcak editoryal ışık stili.';

  @override
  String get viewProfileDetails => 'Profil Ayrıntılarını Görüntüle';

  @override
  String get changeEmail => 'E-postayı Değiştir';

  @override
  String get changePassword => 'Şifreyi Değiştir';

  @override
  String get helpSupport => 'Yardım ve Destek';

  @override
  String get logoutButton => 'Çıkış Yap';

  @override
  String get sixHourAntWorkComplete =>
      '6 saatlik ant work oturumu tamamlandı. ANET oturum kredisi şimdi gönderiliyor...';

  @override
  String antWorkCompletedAccumulated(String reward) {
    return '✅ Ant Work Tamamlandı! $reward ANET birikttirdiniz';
  }

  @override
  String antWorkAutoCompleted(String reward) {
    return '✅ Ant Work otomatik olarak tamamlandı. $reward ANET kredi verildi.';
  }

  @override
  String get antWorkStartedSuccessfully => 'Ant Work başarıyla başlatıldı';

  @override
  String completeAntWorkFailed(String error) {
    return 'Ant Work tamamlaması başarısız oldu: $error';
  }

  @override
  String startAntWorkFailed(String error) {
    return 'Ant Work başlatması başarısız oldu: $error';
  }

  @override
  String get territoryOverview => 'Bölge Genel Görünümü';

  @override
  String get totalAntsDialog => 'Toplam Karıncalar';

  @override
  String get networkShare => 'Ağ Payı';

  @override
  String get activeWorkersDialog => 'Etkin İşçiler';

  @override
  String get sessionsInTerritory => 'Bölgedeki Oturumlar';

  @override
  String get liveBackendStats => 'Kaynak: canlı arka uç ülke istatistikleri.';

  @override
  String get fallbackEstimate =>
      'Kaynak: yedek tahmin. Ülke istatistikleri uç noktası kullanılamıyor.';

  @override
  String get web3AnetMarket => 'Web3 ANET Pazar';

  @override
  String get marketImportance =>
      'Önemli: bu uygulamadaki kazınan ANET, Ant Work aracılığıyla biriktirilen şeydir. Aşağıdaki BNB Zincir ANET sözleşmesi ayrı Web3 görünürlük katmanıdır ve bir kullanıcının uygulama içi ANET madeni para bakiyesini doğrudan artırmaz.';

  @override
  String get bnbChainContract => 'BNB Zincir pazar sözleşmesi';

  @override
  String get currentSeparation => 'Mevcut ayrım';

  @override
  String get separationPoint1 =>
      '1. Bu uygulamadaki ANET madeni paraları doğrulanan oturumlar aracılığıyla biriktirilir.';

  @override
  String get separationPoint2 =>
      '2. BNB Zincir ANET sözleşmesi ve DEX referansları ayrı Web3 görünürlük araçları ve gelecekteki ortak girişi referanslarıdır.';

  @override
  String get separationPoint3 =>
      '3. Koloni, CP, sıra, anlık görüntüler ve gelecekteki ortak dağıtımlar ANET ve ANTS muhasebe modelinin dışında kalır.';

  @override
  String get separationPoint4 =>
      '4. Tam blokzincir şeffaflığı, genel anlaşma ve işlem görüntüleme için ANET-Zincir aracılığıyla kullanılabilir.';

  @override
  String get openMarketPair => 'Pazar Çiftini Aç';

  @override
  String get viewLiveChart => 'Canlı Grafiği Görüntüle';

  @override
  String get viewContract => 'Sözleşmeyi Görüntüle';

  @override
  String get copyContractAddress => 'Sözleşmeyi Kopyala';

  @override
  String get anetMarketContract => 'ANET pazar sözleşmesi';

  @override
  String get moreInfo => 'Daha fazla bilgi';

  @override
  String get createYourL1Wallet => 'Önce L1 cüzdanınızı oluşturun';

  @override
  String get createL1WalletMessage =>
      'BIP-44 tohumunuz tüm EVM cüzdanları ile uyumludur.';

  @override
  String get generateWallet => 'Cüzdan Oluştur';

  @override
  String get walletLocked => 'Cüzdan Kilitli';

  @override
  String get setPINToContinue => 'Devam Etmek İçin PIN Ayarla';

  @override
  String get enterWalletPIN =>
      'Web3 cüzdanınıza erişmek için cüzdan PIN\'inizi girin.';

  @override
  String get setWalletPINAccess =>
      'Erişmeden önce cüzdanınızı güvence altına almak için PIN ayarlayın.';

  @override
  String get unlockWallet => 'Cüzdanı Kilidi Aç';

  @override
  String get setWalletPINButton => 'Cüzdan PIN\'i Ayarla';

  @override
  String get mainnetWallet => 'Mainnet Cüzdanı';

  @override
  String get homeTab => 'Ana Sayfa';

  @override
  String get assetsTab => 'Varlıklar';

  @override
  String get activityTab => 'Aktivite';

  @override
  String get sessionsTab => 'Oturumlar';

  @override
  String get addToken => 'Token Ekle';

  @override
  String get totalBalance => 'Toplam Bakiye';

  @override
  String get send => 'Gönder';

  @override
  String get receive => 'Al';

  @override
  String get explorer => 'Kaşif';

  @override
  String get bridge => 'Köprü';

  @override
  String get miningProfile => 'Madencilik Profili';

  @override
  String get joined => 'Katıldı';

  @override
  String get completedSessions => 'Tamamlanan Oturumlar';

  @override
  String get anetBalance => 'ANET Bakiyesi';

  @override
  String get currentRate => 'Mevcut Oran';

  @override
  String get colonyJoined => 'Koloni Katıldı';

  @override
  String get notInColony => 'Bir kolonide değil';

  @override
  String get sessionHistory => 'Oturum Geçmişi';

  @override
  String get credited => 'Alacaklandırılmış';

  @override
  String get inProgress => 'Devam Ediyor';

  @override
  String get aiSupportTitle => 'A-Network Yapay Zekası';

  @override
  String get trainButton => 'Eğit';

  @override
  String get web4MigrationPolicy => 'Web4 göç politikası';

  @override
  String get anetVsAnts => 'ANET vs ANTS';

  @override
  String get securityWalletSafety => 'Güvenlik ve cüzdan güvenliği';

  @override
  String get trainAITitle => 'A-Network Yapay Zekasını Eğit';

  @override
  String get knowledgeHint =>
      'Hatırlanacak bilgiler (gerçekler, politikalar, ürün ayrıntıları)';

  @override
  String get optionalTrainingPrompt => 'İsteğe bağlı eğitim istemi';

  @override
  String get optionalIdealResponse => 'İsteğe bağlı ideal yanıt';

  @override
  String get addMemoryOrBoth =>
      'Hafıza metni ekleyin veya hem eğitim istemi hem de ideal yanıtı ekleyin.';

  @override
  String get aiTrainingSaved => 'Yapay Zeka eğitimi kaydedildi';

  @override
  String get noAITokensLeft =>
      'Hiç Yapay Zeka tokeni kalmadı. Daha fazla token için reklam izleyin veya 6 saatlik yenilemeyi bekleyin.';

  @override
  String get voiceRecognitionUnavailable =>
      'Sesli tanıma bu cihazda kullanılamıyor';

  @override
  String get noAssistantResponse => 'Yüksek sesle okunacak asistan yanıtı yok';

  @override
  String get adNotCompleted => 'Reklam tamamlanmadı. Henüz token ödülü yok.';

  @override
  String aiTokensAdded(String tokens, String balance) {
    return '$tokens Yapay Zeka tokeni eklendi. Bakiye: $balance';
  }

  @override
  String uploadedToMemory(String filename) {
    return '$filename Yapay Zeka hafızasına yüklendi';
  }

  @override
  String get copiedResponse => 'Yanıt kopyalandı';

  @override
  String get listeningSpeak => 'Dinleniyor... sorunuzu söyleyin';

  @override
  String get askAIAnything =>
      'A-Network Yapay Zekasına herhangi bir şey sorun...';

  @override
  String get deepResearchEnabled =>
      'Sonraki mesajlar için derin araştırma etkinleştirildi';

  @override
  String get deepResearchDisabled => 'Derin araştırma devre dışı bırakıldı';

  @override
  String get uploadTxtTooltip =>
      'Yapay Zekayı eğitmek için txt/md/pdf yükleyin';

  @override
  String get stopListeningTooltip => 'Dinlemeyi durdur';

  @override
  String get startVoiceInputTooltip => 'Sesli girişi başlat';

  @override
  String get stopReadAloudTooltip => 'Yüksek sesle okumayı durdur';

  @override
  String get readLatestResponseTooltip => 'En son yanıtı yüksek sesle oku';

  @override
  String watchAdTokens(String tokens) {
    return 'Reklam izle + $tokens token';
  }

  @override
  String tokenBalance(String balance) {
    return 'Tokenler: $balance';
  }

  @override
  String get pickGroupName => 'Grup Adınızı Seçin';

  @override
  String get claimPermanentUpline => 'Kalıcı Yukarı Akış Talep Et';

  @override
  String get claimUplineInstructions =>
      'Kendi koloninizi tutmak için yukarı akış gerekli değildir. Bunun yerine bu sahibinin kolonisine kalıcı olarak katılmak istiyorsanız, buraya bir Ant Kodu girin.';

  @override
  String get enterAntCode => 'Ant Kodunu Girin';

  @override
  String get claimButton => 'Talep Et';

  @override
  String get antCodeLinked =>
      'Ant Kodu bağlandı. Koloni yukarı akış artık kalıcı.';

  @override
  String get writeToColony => 'Koloninize yazın';

  @override
  String get writeToUplines => 'Koloni yukarı akışınıza yazın';

  @override
  String get pickGroupNameTooltip => 'Grup adını seç';

  @override
  String get refreshChatTooltip => 'Sohbeti yenile';

  @override
  String get tabEcosystem => 'Ekosistem';

  @override
  String get tabAntWork => 'Ant Work';

  @override
  String get tabWallet => 'Cüzdan';

  @override
  String get tabColony => 'Koloni';

  @override
  String get tabMore => 'Daha Fazla';

  @override
  String get pageTitleEcosystem => 'Ant Ekosistemi';

  @override
  String get pageTitleAntWork => 'Ant Work';

  @override
  String get pageTitleWallet => 'ANET Cüzdanı';

  @override
  String get pageTitleWeb4 => 'Web4';

  @override
  String get pageTitleWhitepaper => 'Beyaz Kitap';

  @override
  String get pageTitleColony => 'Koloni (Web5)';

  @override
  String get pageTitleMore => 'Daha Fazla';

  @override
  String get antWorkSectionLabel => 'Ant Work';

  @override
  String get morePageTitle => 'Daha Fazla';

  @override
  String get morePageSubtitle =>
      'Hesap, yasal, destek ve görüntü kontrolleri tek bir daha temiz yerde.';

  @override
  String get walletMenuLabel => 'Cüzdan';

  @override
  String get walletMenuSubtitle => 'Bakiye ve Web3 araçları';

  @override
  String get antWorkHeroTitle => 'Ant Work';

  @override
  String get antWorkHeroSubtitle =>
      'Canlı 6 saatlik oturumu, mevcut çıktıyı ve önemli ağ kilometre taşlarını izleyin.';
}
