// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appName => 'A-Network';

  @override
  String get authPageSubtitle =>
      'Truy cập khai thác Web2 sạch với ví liên tục bảo mật.';

  @override
  String get loginTab => 'Đăng nhập';

  @override
  String get registerTab => 'Đăng ký';

  @override
  String get emailHint => 'Email';

  @override
  String get passwordHint => 'Mật khẩu';

  @override
  String get antCodeHint => 'Mã Ant (Tùy chọn)';

  @override
  String get continueLoginButton => 'Tiếp tục đăng nhập';

  @override
  String get continueRegisterButton => 'Tiếp tục đăng ký';

  @override
  String get forgotPasswordButton => 'Quên mật khẩu?';

  @override
  String get useExistingAccountButton => 'Đăng nhập tài khoản hiện có';

  @override
  String get restoreDeletedAccountButton => 'Khôi phục tài khoản đã xóa';

  @override
  String get sessionModelTitle => 'Mô hình phiên';

  @override
  String get sessionModelSubtitle =>
      'Khai thác hoạt động theo chu kỳ 6 giờ và tiến trình được đồng bộ với tài khoản ví của bạn.';

  @override
  String get securityLayerTitle => 'Lớp bảo mật';

  @override
  String get securityLayerSubtitle =>
      'Bảo vệ cụm từ hạt giống, PIN và khôi phục tài khoản được tích hợp sẵn.';

  @override
  String get emailPasswordRequired => 'Email và mật khẩu là bắt buộc';

  @override
  String get deviceLimitError =>
      'Thiết bị này đã đạt số tài khoản liên kết tối đa. Đăng nhập bằng tài khoản hiện có hoặc sử dụng thiết bị khác để đăng ký.';

  @override
  String get accountRestorationEligible =>
      'Có thể khôi phục. Tài khoản của bạn đã được lên lịch xóa.';

  @override
  String get openEmailApp => 'Đang mở ứng dụng email cho info@a-network.net';

  @override
  String get emailAppNotAvailable =>
      'Ứng dụng email không khả dụng, đã mở trang hỗ trợ';

  @override
  String get forgotPasswordTitle => 'Quên mật khẩu';

  @override
  String get forgotPasswordInstructions =>
      'Nhập email đã đăng ký để nhận mã đặt lại 6 chữ số.';

  @override
  String get sendCodeButton => 'Gửi mã';

  @override
  String get resendCodeButton => 'Gửi lại mã';

  @override
  String get sixDigitCodeHint => 'Mã 6 chữ số';

  @override
  String get newPasswordHint => 'Mật khẩu mới';

  @override
  String get confirmPasswordHint => 'Xác nhận mật khẩu mới';

  @override
  String get resetPasswordButton => 'Đặt lại mật khẩu';

  @override
  String get needHelpButton => 'Cần trợ giúp?';

  @override
  String get verifyEmailTitle => 'Xác minh email';

  @override
  String verifyEmailInstructions(String email) {
    return 'Nhập mã 6 chữ số được gửi đến $email';
  }

  @override
  String get otpCodeHint => 'Mã OTP';

  @override
  String get verifyButton => 'Xác minh';

  @override
  String get cancelButton => 'Hủy';

  @override
  String get emailVerificationCancelled =>
      'Xác minh email đã bị hủy. Nhập mã cuối cùng của bạn sau hoặc nhấn Gửi lại mã để nhận mã mới.';

  @override
  String get loginVerificationTitle => 'Xác minh đăng nhập';

  @override
  String loginVerificationInstructions(String email) {
    return 'Nhập mã đăng nhập 6 chữ số được gửi đến $email';
  }

  @override
  String get loginVerificationCancelled =>
      'Xác minh đăng nhập đã bị hủy. Nhập mã mới nhất của bạn sau hoặc yêu cầu mã mới.';

  @override
  String get convertedDeepLink =>
      'Đã chuyển đổi liên kết sâu cho trình duyệt ANTS';

  @override
  String blockedUnsupportedScheme(String scheme) {
    return 'Đã chặn giao thức không được hỗ trợ: $scheme';
  }

  @override
  String get untrustedDomainTitle => 'Tên miền không đáng tin cậy';

  @override
  String untrustedDomainMessage(String host, String url) {
    return 'Tên miền này không có trong danh sách dApp đáng tin cậy:\n\n$host\n\nURL:\n$url\n\nChỉ tiếp tục nếu bạn tin tưởng trang web này.';
  }

  @override
  String get trustForSessionButton => 'Tin tưởng trong phiên này';

  @override
  String get openDAppPageFirst => 'Mở trang dApp trước';

  @override
  String connectionBlockedUntrusted(String host) {
    return 'Kết nối bị chặn cho tên miền không đáng tin cậy: $host';
  }

  @override
  String get connectWalletTitle => 'Kết nối ví';

  @override
  String connectWalletPrompt(String host, String network, String address) {
    return 'dApp: $host\nMạng: $network\nVí: $address\n\nCấp quyền truy cập phiên để đọc địa chỉ ví và yêu cầu chữ ký của bạn?';
  }

  @override
  String get rejectButton => 'Từ chối';

  @override
  String get connectButton => 'Kết nối';

  @override
  String walletConnectedSnackbar(String host) {
    return 'Ví đã kết nối với $host';
  }

  @override
  String get walletPINVerificationTitle => 'Xác minh PIN ví';

  @override
  String get walletPINInstructions =>
      'Nhập PIN ví của bạn để kích hoạt yêu cầu chữ ký trong 5 phút.';

  @override
  String get pinMustBe => 'PIN phải từ 4 đến 8 chữ số';

  @override
  String get verifyingPIN => 'Đang xác minh...';

  @override
  String get connectWalletToDApp => 'Kết nối ví với dApp trước';

  @override
  String get seedPhraseRequired =>
      'Cần cụm từ hạt giống cục bộ an toàn để ký EVM thực';

  @override
  String get signRequestTitle => 'Yêu cầu chữ ký';

  @override
  String signRequestContent(String host, String network) {
    return 'dApp: $host\nMạng: $network';
  }

  @override
  String get messageToSign => 'Tin nhắn cần ký';

  @override
  String get approveSignature => 'Tôi chấp thuận yêu cầu chữ ký này';

  @override
  String get signButton => 'Ký';

  @override
  String get signatureApprovedTitle => 'Chữ ký được chấp thuận';

  @override
  String get copyButton => 'Sao chép';

  @override
  String get closeButton => 'Đóng';

  @override
  String get signaturePayloadCopied => 'Đã sao chép nội dung chữ ký';

  @override
  String get antsBrowserTitle => 'Trình duyệt ANTS';

  @override
  String get connectWalletTooltip => 'Kết nối ví';

  @override
  String get disconnectTooltip => 'Ngắt kết nối';

  @override
  String get approveSignTooltip => 'Chấp thuận yêu cầu chữ ký';

  @override
  String walletNotConnected(String host) {
    return 'Ví chưa kết nối. Chỉ các máy chủ đáng tin cậy. Hiện tại: $host';
  }

  @override
  String walletConnectedStatus(String host, String network) {
    return 'Đã kết nối: $host • $network';
  }

  @override
  String get enterURL => 'Nhập URL';

  @override
  String get goButton => 'Đi';

  @override
  String get loadingAISupport => 'Đang tải hỗ trợ AI...';

  @override
  String get aiSupportConnectionError =>
      'Không thể kết nối với hỗ trợ AI. Vui lòng kiểm tra kết nối internet của bạn.';

  @override
  String get retryButton => 'Thử lại';

  @override
  String get autoRegion => 'Tự động (Khu vực)';

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
  String get securityLockTitle => 'Khóa bảo mật đang hoạt động';

  @override
  String get securityLockMessage =>
      'Bản dựng này đã phát hiện môi trường thực thi nguy hiểm cao và chặn đăng nhập, Ant Work và truy cập ví để giảm lạm dụng trình giả lập, thiết bị root và giả mạo.';

  @override
  String detectedFlags(String flags) {
    return 'Cờ đã phát hiện: $flags';
  }

  @override
  String platformRuntime(String platform, String runtime) {
    return 'Nền tảng: $platform  |  Thời gian chạy: $runtime';
  }

  @override
  String get securityOverrideInfo =>
      'Sử dụng bản phát hành chính thức trên thiết bị thực. Chỉ để kiểm tra nội bộ, nhà phát triển có thể ghi đè khối này bằng --dart-define=ALLOW_INSECURE_DEVICE=true.';

  @override
  String get anetGlobal => 'A-Network Toàn cầu';

  @override
  String get globalSubtitle =>
      'Tổng quan mạng chuyên nghiệp, trạng thái khai thác và khả năng hiển thị ví.';

  @override
  String get profileSupport => 'Hồ sơ & Hỗ trợ';

  @override
  String get halvingAnnouncementTitle => 'GIẢM NỬA ĐÃ BẮT ĐẦU';

  @override
  String get halvingAnnouncementBody =>
      'Mạng đã đạt mốc 500.000 phiên. Lần giảm nửa đầu tiên hiện đang có hiệu lực.';

  @override
  String get halvingAnnouncementNote =>
      'Có độ trễ xác thực 6 giờ trước khi tỷ lệ cập nhật được áp dụng.';

  @override
  String get halvingActionSafe =>
      'Không cần hành động - các phiên đang tiến hành an toàn và sẽ được ghi có với tỷ lệ đúng.';

  @override
  String get xAnnouncementTitle => 'CẬP NHẬT X MỚI NHẤT';

  @override
  String get xAnnouncementBody =>
      'Theo dõi Mr_A_Awakening để xem các bài đăng chính thức mới nhất của A-Network.';

  @override
  String get xAnnouncementNote =>
      'Slide này tự động xoay mỗi 60 giây với thẻ cập nhật giảm nửa.';

  @override
  String get xAnnouncementCTA => 'Mở cập nhật X mới nhất';

  @override
  String get liveStatus => 'TRỰC TIẾP';

  @override
  String get networkStatus => 'Trạng thái mạng';

  @override
  String get totalAnts => 'Tổng số Ant';

  @override
  String get registered => 'đã đăng ký';

  @override
  String get activeWorkers => 'Người làm việc đang hoạt động';

  @override
  String get completedWork => 'công việc đã hoàn thành';

  @override
  String activeTerritories(String count) {
    return 'Lãnh thổ đang hoạt động ($count+)';
  }

  @override
  String get verifiedSessions => 'PHIÊN ĐÃ XÁC MINH';

  @override
  String get networkThroughput => 'Thông lượng mạng';

  @override
  String get liveOutput => 'ĐẦU RA TRỰC TIẾP';

  @override
  String get anetPerSession => 'ANET / phiên';

  @override
  String get markets => 'THỊ TRƯỜNG';

  @override
  String get activeTerritoriesCount => 'Lãnh thổ đang hoạt động';

  @override
  String get liveAntWork => 'Công việc Ant trực tiếp';

  @override
  String get startingAntWork => 'Đang khởi động công việc ant...';

  @override
  String get antWorkActive => 'Công việc Ant đang hoạt động';

  @override
  String get readyToStart => 'Sẵn sàng bắt đầu';

  @override
  String sessionEndsIn(String time) {
    return 'Phiên kết thúc sau $time';
  }

  @override
  String get startAnyTime =>
      'Bắt đầu bất cứ lúc nào. Bộ đếm 6 giờ bắt đầu từ khi bạn chạm.';

  @override
  String get openAntWork => 'Mở công việc Ant';

  @override
  String get startAntWork => 'Bắt đầu công việc Ant';

  @override
  String get refreshActivity => 'Làm mới hoạt động';

  @override
  String get beginJourney => 'Bắt đầu hành trình của bạn';

  @override
  String get startAntWorkInfo =>
      'Bắt đầu phiên làm việc Ant được xác minh 6 giờ. Hoạt động được theo dõi trong ANTS trước, sau đó có thể nhận trong ANET.';

  @override
  String get anetWalletAction => 'Ví ANET';

  @override
  String get balanceWalletTools => 'Số dư, công cụ ví, khả năng hiển thị chuỗi';

  @override
  String get anetWalletInfo =>
      'Mở công cụ ví, ánh xạ số dư hiện tại và khả năng hiển thị hệ sinh thái công khai.';

  @override
  String get sessionOutput => 'ĐẦU RA PHIÊN';

  @override
  String get anetPer6Hour => 'ANET mỗi chu kỳ 6 giờ';

  @override
  String get portfolio => 'DANH MỤC';

  @override
  String get antsAccumulated => 'ANTS đã tích lũy';

  @override
  String get typeWebsite => 'Nhập trang web hoặc từ khóa trước';

  @override
  String get createWalletFirst => 'Tạo ví của bạn trước';

  @override
  String get walletBalanceSynced =>
      'Số dư ví đã được đồng bộ từ ANET đã khai thác';

  @override
  String get noColonyMessage =>
      'Thuộc địa của bạn đã sẵn sàng. Không cần tuyến trên. Chọn tên thuộc địa và mời ant bằng mã Ant của bạn.';

  @override
  String get noColonyMessagesYet => 'Chưa có tin nhắn thuộc địa.';

  @override
  String get myAntCodeTitle => 'Liên kết mã Ant của tôi';

  @override
  String antCodeLabel(String code) {
    return 'Mã Ant: $code';
  }

  @override
  String get referralLinksLabel => 'Liên kết giới thiệu';

  @override
  String get openGoogleLink => 'Mở liên kết Google';

  @override
  String get openAPKLink => 'Mở liên kết APK';

  @override
  String get copyShareText => 'Sao chép văn bản chia sẻ';

  @override
  String get colonyTrackerTitle => 'Trình theo dõi thuộc địa';

  @override
  String get colonyDescription =>
      'Thuộc địa là lớp cộng đồng Web5 trong tương lai. Hiện chỉ xem và tách biệt với các phiên khai thác Web2.';

  @override
  String get operatingModel =>
      'Mô hình hoạt động: Web2 = Khai thác Ant Work và kế toán ANTS. Web3 = Khả năng hiển thị BNB Chain. Web4 = Thanh toán ANET-Chain. Web5 = Phối hợp cộng đồng.';

  @override
  String get futureAnetCoreNote =>
      'Ghi chú ANET Core tương lai: tài khoản này đã có ví Web3 sẵn sàng cho việc tích hợp đối tác sau này.';

  @override
  String get futureCorNoteNoWallet =>
      'Ghi chú ANET Core tương lai: việc tích hợp đối tác sau có thể yêu cầu ví Web3 riêng, nhưng không có yêu cầu mua trong bản dựng này.';

  @override
  String get yourAntCode => 'Mã Ant của bạn';

  @override
  String directColonyAnts(String count) {
    return 'Ant thuộc địa trực tiếp: $count';
  }

  @override
  String colonyCompleted1K(String count) {
    return 'Ant thuộc địa đã hoàn thành 1k phiên: $count';
  }

  @override
  String totalColonySessions(String count) {
    return 'Tổng phiên thuộc địa: $count';
  }

  @override
  String get communityVisibilityOnly =>
      'Trạng thái hiện tại: chỉ khả năng hiển thị cộng đồng. CP, hạng, ảnh chụp nhanh tách biệt với số dư ANET.';

  @override
  String get blockchainTransparency =>
      'Tính minh bạch blockchain: người dùng có thể kiểm tra hoạt động chuỗi công khai qua ANET-Chain.';

  @override
  String yourCompletedSessions(String sessions, String target) {
    return 'Phiên đã hoàn thành của bạn: $sessions / $target';
  }

  @override
  String remainingTo1K(String remaining) {
    return 'Còn lại đến 1k: $remaining';
  }

  @override
  String get colonySessionProgress => 'Tiến trình phiên thuộc địa';

  @override
  String get noColonyAnts => 'Chưa có ant thuộc địa.';

  @override
  String completedSessionsAnt(String sessions) {
    return 'Phiên đã hoàn thành: $sessions / 1000';
  }

  @override
  String get qualifiedFor1KMilestone => 'Đủ điều kiện cho mốc 1k';

  @override
  String get copyAntCode => 'Sao chép mã';

  @override
  String get shareColony => 'Chia sẻ thuộc địa';

  @override
  String get copyGoogleLink => 'Sao chép liên kết Google';

  @override
  String get copyAPKLink => 'Sao chép liên kết APK';

  @override
  String get seedPhraseBackupTitle => 'Sao lưu cụm từ hạt giống';

  @override
  String get securityCheckRequired =>
      'Yêu cầu kiểm tra bảo mật. Nhập PIN ví để tiếp tục.';

  @override
  String get walletPINHint => 'PIN ví';

  @override
  String get sendOTPButton => 'Gửi OTP';

  @override
  String get emailOTPHint => 'OTP email';

  @override
  String get neverSharePhrase =>
      'Không bao giờ chia sẻ cụm từ này. Bất kỳ ai có cụm từ này đều có thể kiểm soát ví của bạn.';

  @override
  String get revealButton => 'Tiết lộ';

  @override
  String get setWalletPINTitle => 'Đặt PIN ví';

  @override
  String get changeWalletPINTitle => 'Thay đổi PIN ví';

  @override
  String get changePINRequiresOTP =>
      'Thay đổi PIN yêu cầu xác minh OTP từ email đã đăng ký của bạn.';

  @override
  String get registeredEmail => 'Email đã đăng ký';

  @override
  String get currentPIN => 'PIN hiện tại';

  @override
  String get newPINHint => 'PIN mới (4-8 chữ số)';

  @override
  String get forgotPINButton => 'Quên PIN?';

  @override
  String get forgotWalletPINTitle => 'Quên PIN ví';

  @override
  String get forgotPINInstructions =>
      'Đặt lại PIN ví qua xác minh email. Chúng tôi sẽ gửi mã 6 chữ số đến email đã đăng ký của bạn.';

  @override
  String get sixDigitVerificationCode => 'Mã xác minh 6 chữ số';

  @override
  String get pinResetSuccessful => 'Đặt lại PIN thành công';

  @override
  String get deleteAccountTitle => 'Xóa tài khoản';

  @override
  String get deleteAccountMessage =>
      'Điều này sẽ lên lịch xóa tài khoản của bạn sau thời gian an toàn.';

  @override
  String get enterPINToConfirm => 'Nhập PIN để xác nhận';

  @override
  String get deleteButton => 'Xóa';

  @override
  String get deletionRequested => 'Đã yêu cầu xóa';

  @override
  String get welcomeTitle => 'Chào mừng đến A-Network';

  @override
  String get tutorialStep1 =>
      '1) Bắt đầu Ant Work và chờ 6 giờ để hoàn thành một phiên.';

  @override
  String get tutorialStep2 =>
      '2) Bạn tích lũy ANTS trước. 100.000.000 ANTS = 1 ANET.';

  @override
  String get tutorialStep3 =>
      '3) Đạt 1.000 phiên để đủ điều kiện cho các tính năng chuyển đổi ANET đầy đủ.';

  @override
  String get tutorialStep4 =>
      '4) Bảo vệ ví: đặt PIN và chỉ tiết lộ hạt giống khi cần thiết.';

  @override
  String get gotItButton => 'Đã hiểu';

  @override
  String get accountProfileTitle => 'Hồ sơ tài khoản';

  @override
  String get levelEligible => 'Đủ điều kiện cấp độ: Đủ điều kiện';

  @override
  String levelNotEligible(String remaining) {
    return 'Đủ điều kiện cấp độ: Chưa đủ điều kiện (còn $remaining phiên)';
  }

  @override
  String get web4MigrationWalletTitle => 'Ví di chuyển Web4';

  @override
  String get migrationWalletOptional =>
      'Tùy chọn: nhập địa chỉ ví di chuyển Web4 trong tương lai của bạn ngay bây giờ.';

  @override
  String get migrationWalletExample =>
      'Ví dụ: ANET1A2B3C4D5E6F... (ANET + 36 ký tự hex)';

  @override
  String get saveButton => 'Lưu';

  @override
  String get migrationWalletNotChanged => 'Địa chỉ ví di chuyển không thay đổi';

  @override
  String get migrationWalletSaved => 'Địa chỉ ví di chuyển đã được lưu';

  @override
  String get changeEmailTitle => 'Thay đổi email';

  @override
  String get newEmailHint => 'Email mới';

  @override
  String get currentPasswordHint => 'Mật khẩu hiện tại';

  @override
  String get emailChangedSuccessfully => 'Email đã được thay đổi thành công';

  @override
  String get changePasswordTitle => 'Thay đổi mật khẩu';

  @override
  String get newPasswordMin8 => 'Mật khẩu mới (tối thiểu 8 ký tự)';

  @override
  String get passwordChangedSuccessfully =>
      'Mật khẩu đã được thay đổi thành công';

  @override
  String get securityOwnershipTitle => 'Bảo mật và quyền sở hữu';

  @override
  String get emailVerificationNote =>
      'A-Network hiện thực thi xác minh email qua OTP trong quá trình đăng ký.';

  @override
  String get otpVerificationOneTime =>
      'Xác minh OTP này chỉ dùng một lần để kích hoạt tài khoản.';

  @override
  String get emailLossWarning =>
      'Nếu bạn mất quyền truy cập email và không thể khôi phục, bạn sẽ mất quyền truy cập tài khoản và ANET đã khai thác.';

  @override
  String get ownershipModel =>
      'Mô hình quyền sở hữu: Email + địa chỉ ví bạn tạo = khóa quyền sở hữu trực tiếp trong hệ sinh thái.';

  @override
  String get web4MigrationKeepSafe =>
      'Đối với di chuyển Web4, hãy bảo quản cả email và chi tiết ví của bạn.';

  @override
  String get notificationsTitle => 'Thông báo';

  @override
  String get antWorkAlertsActive =>
      'Cảnh báo Ant Work đang hoạt động cho phiên 6 giờ hiện tại.';

  @override
  String get startAntWorkNotifications =>
      'Bắt đầu Ant Work để lên lịch cảnh báo hoàn thành tiếp theo.';

  @override
  String get notificationsInfo =>
      'Thông báo được sử dụng cho nhắc nhở phiên đã xác minh, thời gian hoàn thành và cập nhật hệ sinh thái quan trọng.';

  @override
  String get sessionRunning =>
      'Trạng thái hiện tại: phiên đang chạy, nhắc nhở hoàn thành đang chờ xử lý.';

  @override
  String get noActiveSession =>
      'Trạng thái hiện tại: không có phiên đang hoạt động, vì vậy chưa có nhắc nhở hoàn thành nào được lên lịch.';

  @override
  String get refreshButton => 'Làm mới';

  @override
  String get languageTitle => 'Ngôn ngữ';

  @override
  String get languageHelp =>
      'Chọn ngôn ngữ ứng dụng. Chế độ tự động ánh xạ mặc định khu vực: Ấn Độ → Hindi, Pakistan → Urdu, Trung Quốc → Tiếng Trung, Tây Ban Nha/Mỹ Latinh → Tiếng Tây Ban Nha, Việt Nam → Tiếng Việt.';

  @override
  String get aboutTitle => 'Giới thiệu về A-Network';

  @override
  String get aboutContent =>
      'A-Network được vận hành bởi A Network LLC, Số thực thể California 20260170159.\n\nMô hình sản xuất sử dụng kế toán ưu tiên ANTS, trong đó 1 ANET = 100.000.000 ANTS.';

  @override
  String get openWeb4Button => 'Mở Web4';

  @override
  String get displayThemeTitle => 'Chủ đề hiển thị';

  @override
  String get classicTheme => 'Chủ đề chính cổ điển';

  @override
  String get classicThemeDesc => 'Trình bày A-Network cyan hiện có.';

  @override
  String get antsTheme => 'Chủ đề hệ sinh thái ANTS';

  @override
  String get antsThemeDesc =>
      'Phong cách nhà đầu tư màu xanh lá, cyan và vàng lấy cảm hứng từ Web4.';

  @override
  String get studioTheme => 'Chủ đề sáng studio';

  @override
  String get studioThemeDesc =>
      'Nền sáng chuyên nghiệp với các hạt kết nối và điểm nhấn xanh mát.';

  @override
  String get executiveTheme => 'Chủ đề tối điều hành';

  @override
  String get executiveThemeDesc =>
      'Bề mặt graphite với điểm nhấn champagne cho trình bày nhà đầu tư sắc nét hơn.';

  @override
  String get paperTheme => 'Chủ đề sáng giấy';

  @override
  String get paperThemeDesc =>
      'Phong cách sáng biên tập ấm áp với nhãn xanh mực và chuyển động mềm mại hơn.';

  @override
  String get viewProfileDetails => 'Xem chi tiết hồ sơ';

  @override
  String get changeEmail => 'Thay đổi email';

  @override
  String get changePassword => 'Thay đổi mật khẩu';

  @override
  String get helpSupport => 'Trợ giúp & Hỗ trợ';

  @override
  String get logoutButton => 'Đăng xuất';

  @override
  String get sixHourAntWorkComplete =>
      'Phiên làm việc ant 6 giờ hoàn thành. Đang đăng tín dụng phiên ANET của bạn...';

  @override
  String antWorkCompletedAccumulated(String reward) {
    return '✅ Ant Work hoàn thành! Bạn đã tích lũy $reward ANET';
  }

  @override
  String antWorkAutoCompleted(String reward) {
    return '✅ Ant Work tự động hoàn thành. $reward ANET đã được ghi có.';
  }

  @override
  String get antWorkStartedSuccessfully => 'Ant Work đã bắt đầu thành công';

  @override
  String completeAntWorkFailed(String error) {
    return 'Hoàn thành Ant Work thất bại: $error';
  }

  @override
  String startAntWorkFailed(String error) {
    return 'Bắt đầu Ant Work thất bại: $error';
  }

  @override
  String get territoryOverview => 'Tổng quan lãnh thổ';

  @override
  String get totalAntsDialog => 'Tổng số Ant';

  @override
  String get networkShare => 'Thị phần mạng';

  @override
  String get activeWorkersDialog => 'Người làm việc đang hoạt động';

  @override
  String get sessionsInTerritory => 'Phiên trong lãnh thổ';

  @override
  String get liveBackendStats =>
      'Nguồn: số liệu thống kê quốc gia backend trực tiếp.';

  @override
  String get fallbackEstimate =>
      'Nguồn: ước tính dự phòng. Điểm cuối thống kê quốc gia không khả dụng.';

  @override
  String get web3AnetMarket => 'Thị trường ANET Web3';

  @override
  String get marketImportance =>
      'Quan trọng: ANET được khai thác trong ứng dụng này được tích lũy qua Ant Work. Hợp đồng ANET BNB Chain là lớp khả năng hiển thị Web3 riêng biệt.';

  @override
  String get bnbChainContract => 'Hợp đồng thị trường BNB Chain';

  @override
  String get currentSeparation => 'Sự tách biệt hiện tại';

  @override
  String get separationPoint1 =>
      '1. Token ANET trong ứng dụng này được tích lũy qua các phiên đã xác minh.';

  @override
  String get separationPoint2 =>
      '2. Hợp đồng ANET BNB Chain và tham chiếu DEX là các công cụ khả năng hiển thị Web3 riêng biệt.';

  @override
  String get separationPoint3 =>
      '3. Colony, CP, hạng, ảnh chụp nhanh và phân phối đối tác tương lai nằm ngoài mô hình kế toán ANET và ANTS.';

  @override
  String get separationPoint4 =>
      '4. Tính minh bạch blockchain đầy đủ vẫn có sẵn qua ANET-Chain.';

  @override
  String get openMarketPair => 'Mở cặp thị trường';

  @override
  String get viewLiveChart => 'Xem biểu đồ trực tiếp';

  @override
  String get viewContract => 'Xem hợp đồng';

  @override
  String get copyContractAddress => 'Sao chép hợp đồng';

  @override
  String get anetMarketContract => 'Hợp đồng thị trường ANET';

  @override
  String get moreInfo => 'Thông tin thêm';

  @override
  String get createYourL1Wallet => 'Tạo ví L1 của bạn trước';

  @override
  String get createL1WalletMessage =>
      'Hạt giống BIP-44 của bạn tương thích với tất cả ví EVM.';

  @override
  String get generateWallet => 'Tạo ví';

  @override
  String get walletLocked => 'Ví đã bị khóa';

  @override
  String get setPINToContinue => 'Đặt PIN để tiếp tục';

  @override
  String get enterWalletPIN => 'Nhập PIN ví để truy cập ví Web3 của bạn.';

  @override
  String get setWalletPINAccess => 'Đặt PIN để bảo mật ví trước khi truy cập.';

  @override
  String get unlockWallet => 'Mở khóa ví';

  @override
  String get setWalletPINButton => 'Đặt PIN ví';

  @override
  String get mainnetWallet => 'Ví Mainnet';

  @override
  String get homeTab => 'Trang chủ';

  @override
  String get assetsTab => 'Tài sản';

  @override
  String get activityTab => 'Hoạt động';

  @override
  String get sessionsTab => 'Phiên';

  @override
  String get addToken => 'Thêm token';

  @override
  String get totalBalance => 'Tổng số dư';

  @override
  String get send => 'Gửi';

  @override
  String get receive => 'Nhận';

  @override
  String get explorer => 'Khám phá';

  @override
  String get bridge => 'Cầu nối';

  @override
  String get miningProfile => 'Hồ sơ khai thác';

  @override
  String get joined => 'Đã tham gia';

  @override
  String get completedSessions => 'Phiên đã hoàn thành';

  @override
  String get anetBalance => 'Số dư ANET';

  @override
  String get currentRate => 'Tỷ lệ hiện tại';

  @override
  String get colonyJoined => 'Đã tham gia thuộc địa';

  @override
  String get notInColony => 'Không thuộc thuộc địa nào';

  @override
  String get sessionHistory => 'Lịch sử phiên';

  @override
  String get credited => 'Đã ghi có';

  @override
  String get inProgress => 'Đang tiến hành';

  @override
  String get aiSupportTitle => 'A-Network AI';

  @override
  String get trainButton => 'Huấn luyện';

  @override
  String get web4MigrationPolicy => 'Chính sách di chuyển Web4';

  @override
  String get anetVsAnts => 'ANET so với ANTS';

  @override
  String get securityWalletSafety => 'Bảo mật và an toàn ví';

  @override
  String get trainAITitle => 'Huấn luyện AI A-Network';

  @override
  String get knowledgeHint =>
      'Kiến thức cần nhớ (sự kiện, chính sách, chi tiết sản phẩm)';

  @override
  String get optionalTrainingPrompt => 'Lời nhắc huấn luyện tùy chọn';

  @override
  String get optionalIdealResponse => 'Phản hồi lý tưởng tùy chọn';

  @override
  String get addMemoryOrBoth =>
      'Thêm văn bản bộ nhớ, hoặc cả lời nhắc huấn luyện và phản hồi lý tưởng.';

  @override
  String get aiTrainingSaved => 'Đã lưu huấn luyện AI';

  @override
  String get noAITokensLeft =>
      'Không còn token AI. Xem quảng cáo để nhận thêm token hoặc chờ nạp lại sau 6 giờ.';

  @override
  String get voiceRecognitionUnavailable =>
      'Nhận dạng giọng nói không khả dụng trên thiết bị này';

  @override
  String get noAssistantResponse => 'Không có phản hồi trợ lý để đọc to';

  @override
  String get adNotCompleted =>
      'Quảng cáo chưa hoàn thành. Chưa có phần thưởng token.';

  @override
  String aiTokensAdded(String tokens, String balance) {
    return 'Đã thêm $tokens token AI. Số dư: $balance';
  }

  @override
  String uploadedToMemory(String filename) {
    return 'Đã tải $filename lên bộ nhớ AI';
  }

  @override
  String get copiedResponse => 'Đã sao chép phản hồi';

  @override
  String get listeningSpeak => 'Đang nghe... hãy nói câu hỏi của bạn';

  @override
  String get askAIAnything => 'Hỏi AI A-Network bất cứ điều gì...';

  @override
  String get deepResearchEnabled =>
      'Đã bật nghiên cứu sâu cho các tin nhắn tiếp theo';

  @override
  String get deepResearchDisabled => 'Đã tắt nghiên cứu sâu';

  @override
  String get uploadTxtTooltip => 'Tải lên txt/md/pdf để huấn luyện AI';

  @override
  String get stopListeningTooltip => 'Dừng nghe';

  @override
  String get startVoiceInputTooltip => 'Bắt đầu nhập giọng nói';

  @override
  String get stopReadAloudTooltip => 'Dừng đọc to';

  @override
  String get readLatestResponseTooltip => 'Đọc to phản hồi mới nhất';

  @override
  String watchAdTokens(String tokens) {
    return 'Xem quảng cáo + $tokens token';
  }

  @override
  String tokenBalance(String balance) {
    return 'Token: $balance';
  }

  @override
  String get pickGroupName => 'Chọn tên nhóm của bạn';

  @override
  String get claimPermanentUpline => 'Nhận tuyến trên vĩnh viễn';

  @override
  String get claimUplineInstructions =>
      'Không cần tuyến trên để giữ thuộc địa của riêng bạn. Chỉ nhập mã Ant ở đây nếu bạn muốn tham gia vĩnh viễn vào thuộc địa của chủ sở hữu đó.';

  @override
  String get enterAntCode => 'Nhập mã Ant';

  @override
  String get claimButton => 'Nhận';

  @override
  String get antCodeLinked =>
      'Mã Ant đã được liên kết. Tuyến trên thuộc địa của bạn hiện là vĩnh viễn.';

  @override
  String get writeToColony => 'Viết cho thuộc địa của bạn';

  @override
  String get writeToUplines => 'Viết cho các tuyến trên thuộc địa của bạn';

  @override
  String get pickGroupNameTooltip => 'Chọn tên nhóm';

  @override
  String get refreshChatTooltip => 'Làm mới chat';

  @override
  String get tabEcosystem => 'Hệ sinh thái';

  @override
  String get tabAntWork => 'Công việc Ant';

  @override
  String get tabWallet => 'Ví';

  @override
  String get tabColony => 'Thuộc địa';

  @override
  String get tabMore => 'Thêm';

  @override
  String get pageTitleEcosystem => 'Hệ sinh thái Ant';

  @override
  String get pageTitleAntWork => 'Công việc Ant';

  @override
  String get pageTitleWallet => 'Ví ANET';

  @override
  String get pageTitleWeb4 => 'Web4';

  @override
  String get pageTitleWhitepaper => 'Sách trắng';

  @override
  String get pageTitleColony => 'Thuộc địa (Web5)';

  @override
  String get pageTitleMore => 'Thêm';

  @override
  String get antWorkSectionLabel => 'Công việc Ant';

  @override
  String get morePageTitle => 'Thêm';

  @override
  String get morePageSubtitle =>
      'Tài khoản, pháp lý, hỗ trợ và điều khiển hiển thị trong một nơi.';

  @override
  String get walletMenuLabel => 'Ví';

  @override
  String get walletMenuSubtitle => 'Số dư và công cụ Web3';

  @override
  String get antWorkHeroTitle => 'Công việc Ant';

  @override
  String get antWorkHeroSubtitle =>
      'Theo dõi phiên làm việc 6 giờ trực tiếp, đầu ra hiện tại và các mốc quan trọng của mạng.';
}
