// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'A-Network';

  @override
  String get authPageSubtitle => '安全钱包持续性的清洁Web2挖矿访问。';

  @override
  String get loginTab => '登录';

  @override
  String get registerTab => '注册';

  @override
  String get emailHint => '电子邮件';

  @override
  String get passwordHint => '密码';

  @override
  String get antCodeHint => '蚂蚁码（可选）';

  @override
  String get continueLoginButton => '继续登录';

  @override
  String get continueRegisterButton => '继续注册';

  @override
  String get forgotPasswordButton => '忘记密码？';

  @override
  String get useExistingAccountButton => '使用现有账户登录';

  @override
  String get restoreDeletedAccountButton => '恢复已删除账户';

  @override
  String get sessionModelTitle => '会话模型';

  @override
  String get sessionModelSubtitle => '挖矿以6小时为周期运行，进度与您的钱包账户同步。';

  @override
  String get securityLayerTitle => '安全层';

  @override
  String get securityLayerSubtitle => '内置助记词、PIN和账户恢复保护。';

  @override
  String get emailPasswordRequired => '电子邮件和密码是必填项';

  @override
  String get deviceLimitError => '此设备已达到最大关联账户数。请使用现有账户登录，或使用不同设备注册。';

  @override
  String get accountRestorationEligible => '可以恢复。您的账户已被安排删除。';

  @override
  String get openEmailApp => '正在为 info@a-network.net 打开邮件应用';

  @override
  String get emailAppNotAvailable => '邮件应用不可用，已打开支持页面';

  @override
  String get forgotPasswordTitle => '忘记密码';

  @override
  String get forgotPasswordInstructions => '输入您的注册邮箱以接收6位重置码。';

  @override
  String get sendCodeButton => '发送验证码';

  @override
  String get resendCodeButton => '重新发送验证码';

  @override
  String get sixDigitCodeHint => '6位验证码';

  @override
  String get newPasswordHint => '新密码';

  @override
  String get confirmPasswordHint => '确认新密码';

  @override
  String get resetPasswordButton => '重置密码';

  @override
  String get needHelpButton => '需要帮助？';

  @override
  String get verifyEmailTitle => '验证邮箱';

  @override
  String verifyEmailInstructions(String email) {
    return '输入发送至 $email 的6位验证码';
  }

  @override
  String get otpCodeHint => 'OTP验证码';

  @override
  String get verifyButton => '验证';

  @override
  String get cancelButton => '取消';

  @override
  String get emailVerificationCancelled =>
      '邮箱验证已取消。稍后输入您的最后一个验证码，或点击重新发送验证码获取新码。';

  @override
  String get loginVerificationTitle => '登录验证';

  @override
  String loginVerificationInstructions(String email) {
    return '输入发送至 $email 的6位登录验证码';
  }

  @override
  String get loginVerificationCancelled => '登录验证已取消。稍后输入您的最新验证码或请求新码。';

  @override
  String get convertedDeepLink => '已为ANTS浏览器转换深度链接';

  @override
  String blockedUnsupportedScheme(String scheme) {
    return '已阻止不支持的协议：$scheme';
  }

  @override
  String get untrustedDomainTitle => '不受信任的域名';

  @override
  String untrustedDomainMessage(String host, String url) {
    return '此域名不在受信任的dApp列表中：\n\n$host\n\nURL：\n$url\n\n只有在您信任此网站时才继续。';
  }

  @override
  String get trustForSessionButton => '本次会话信任';

  @override
  String get openDAppPageFirst => '请先打开dApp页面';

  @override
  String connectionBlockedUntrusted(String host) {
    return '已阻止不受信任域名的连接：$host';
  }

  @override
  String get connectWalletTitle => '连接钱包';

  @override
  String connectWalletPrompt(String host, String network, String address) {
    return 'dApp: $host\n网络: $network\n钱包: $address\n\n授权会话访问以读取您的钱包地址并请求签名？';
  }

  @override
  String get rejectButton => '拒绝';

  @override
  String get connectButton => '连接';

  @override
  String walletConnectedSnackbar(String host) {
    return '钱包已连接至 $host';
  }

  @override
  String get walletPINVerificationTitle => '钱包PIN验证';

  @override
  String get walletPINInstructions => '输入您的钱包PIN以启用5分钟的签名请求。';

  @override
  String get pinMustBe => 'PIN必须为4到8位数字';

  @override
  String get verifyingPIN => '正在验证...';

  @override
  String get connectWalletToDApp => '请先将钱包连接到dApp';

  @override
  String get seedPhraseRequired => '真实EVM签名需要本地助记词';

  @override
  String get signRequestTitle => '签名请求';

  @override
  String signRequestContent(String host, String network) {
    return 'dApp: $host\n网络: $network';
  }

  @override
  String get messageToSign => '待签名消息';

  @override
  String get approveSignature => '我批准此签名请求';

  @override
  String get signButton => '签名';

  @override
  String get signatureApprovedTitle => '签名已批准';

  @override
  String get copyButton => '复制';

  @override
  String get closeButton => '关闭';

  @override
  String get signaturePayloadCopied => '签名内容已复制';

  @override
  String get antsBrowserTitle => 'ANTS浏览器';

  @override
  String get connectWalletTooltip => '连接钱包';

  @override
  String get disconnectTooltip => '断开连接';

  @override
  String get approveSignTooltip => '批准签名请求';

  @override
  String walletNotConnected(String host) {
    return '钱包未连接。仅限受信任主机。当前：$host';
  }

  @override
  String walletConnectedStatus(String host, String network) {
    return '已连接：$host • $network';
  }

  @override
  String get enterURL => '输入URL';

  @override
  String get goButton => '前往';

  @override
  String get loadingAISupport => '正在加载AI支持...';

  @override
  String get aiSupportConnectionError => '无法连接到AI支持。请检查您的网络连接。';

  @override
  String get retryButton => '重试';

  @override
  String get autoRegion => '自动（地区）';

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
  String get securityLockTitle => '安全锁已激活';

  @override
  String get securityLockMessage =>
      '此版本检测到高风险运行环境，已阻止登录、Ant Work和钱包访问，以防止模拟器、Root设备和篡改滥用。';

  @override
  String detectedFlags(String flags) {
    return '检测到的标志：$flags';
  }

  @override
  String platformRuntime(String platform, String runtime) {
    return '平台：$platform  |  运行环境：$runtime';
  }

  @override
  String get securityOverrideInfo =>
      '请在实体设备上使用官方版本。仅限内部测试，开发者可通过 --dart-define=ALLOW_INSECURE_DEVICE=true 覆盖此阻止。';

  @override
  String get anetGlobal => 'A-Network全球';

  @override
  String get globalSubtitle => '专业网络概览、挖矿状态和钱包可见性。';

  @override
  String get profileSupport => '个人资料和支持';

  @override
  String get halvingAnnouncementTitle => '减半已开始';

  @override
  String get halvingAnnouncementBody => '网络已达到50万会话里程碑。第一次减半现已生效。';

  @override
  String get halvingAnnouncementNote =>
      '更新后的费率生效前有6小时的验证延迟。系统首先验证所有待处理的会话。一旦确认50万里程碑，您的实时产出将自动更新为新的减半费率。';

  @override
  String get halvingActionSafe => '无需任何操作 - 正在进行中的会话是安全的，将以正确的费率记入。';

  @override
  String get xAnnouncementTitle => '最新X动态';

  @override
  String get xAnnouncementBody => '关注 Mr_A_Awakening 获取最新官方A-Network帖子。';

  @override
  String get xAnnouncementNote => '此幻灯片每60秒与减半更新卡片自动轮换。';

  @override
  String get xAnnouncementCTA => '打开最新X动态';

  @override
  String get liveStatus => '直播';

  @override
  String get networkStatus => '网络状态';

  @override
  String get totalAnts => '蚂蚁总数';

  @override
  String get registered => '已注册';

  @override
  String get activeWorkers => '活跃工作者';

  @override
  String get completedWork => '已完成工作';

  @override
  String activeTerritories(String count) {
    return '活跃地区（$count+）';
  }

  @override
  String get verifiedSessions => '已验证会话';

  @override
  String get networkThroughput => '网络吞吐量';

  @override
  String get liveOutput => '实时产出';

  @override
  String get anetPerSession => 'ANET / 会话';

  @override
  String get markets => '市场';

  @override
  String get activeTerritoriesCount => '活跃地区';

  @override
  String get liveAntWork => '实时蚂蚁工作';

  @override
  String get startingAntWork => '蚂蚁工作正在启动...';

  @override
  String get antWorkActive => '蚂蚁工作进行中';

  @override
  String get readyToStart => '准备开始';

  @override
  String sessionEndsIn(String time) {
    return '会话将在 $time 后结束';
  }

  @override
  String get startAnyTime => '随时开始。6小时计时器从您点击时开始。';

  @override
  String get openAntWork => '打开蚂蚁工作';

  @override
  String get startAntWork => '开始蚂蚁工作';

  @override
  String get refreshActivity => '刷新活动';

  @override
  String get beginJourney => '开始您的旅程';

  @override
  String get startAntWorkInfo =>
      '开始一个经过验证的6小时蚂蚁工作会话。活动首先在ANTS中追踪，然后在达到所需完成会话阈值后在ANET中可认领。';

  @override
  String get anetWalletAction => 'ANET钱包';

  @override
  String get balanceWalletTools => '余额、钱包工具、链可见性';

  @override
  String get anetWalletInfo => '打开钱包工具、当前余额映射和公共生态系统可见性。';

  @override
  String get sessionOutput => '会话产出';

  @override
  String get anetPer6Hour => 'ANET每6小时周期';

  @override
  String get portfolio => '投资组合';

  @override
  String get antsAccumulated => '已累积ANTS';

  @override
  String get typeWebsite => '请先输入网站或关键词';

  @override
  String get createWalletFirst => '请先创建您的钱包';

  @override
  String get walletBalanceSynced => '钱包余额已从挖矿的ANET同步';

  @override
  String get noColonyMessage => '您的殖民地已准备好。不需要上线。选择一个殖民地名称并用您的蚂蚁码邀请蚂蚁。';

  @override
  String get noColonyMessagesYet => '还没有殖民地消息。';

  @override
  String get myAntCodeTitle => '我的蚂蚁码链接';

  @override
  String antCodeLabel(String code) {
    return '蚂蚁码：$code';
  }

  @override
  String get referralLinksLabel => '推荐链接';

  @override
  String get openGoogleLink => '打开Google链接';

  @override
  String get openAPKLink => '打开APK链接';

  @override
  String get copyShareText => '复制分享文本';

  @override
  String get colonyTrackerTitle => '殖民地追踪器';

  @override
  String get colonyDescription =>
      '殖民地是未来的Web5社区层。目前仅供查看，与Web2挖矿会话、ANTS账户、ANET余额分开。';

  @override
  String get operatingModel =>
      '运营模型：Web2 = 蚂蚁工作挖矿和ANTS记账。Web3 = BNB链可见性。Web4 = ANET链结算。Web5 = ANTS项目社区协调。';

  @override
  String get futureAnetCoreNote => '未来ANET Core说明：此账户已准备好Web3钱包用于后续合伙人入驻。';

  @override
  String get futureCorNoteNoWallet =>
      '未来ANET Core说明：后续合伙人入驻可能需要单独的Web3钱包，但此版本不执行任何购买门槛。';

  @override
  String get yourAntCode => '您的蚂蚁码';

  @override
  String directColonyAnts(String count) {
    return '直接殖民地蚂蚁：$count';
  }

  @override
  String colonyCompleted1K(String count) {
    return '殖民地蚂蚁完成1k会话：$count';
  }

  @override
  String totalColonySessions(String count) {
    return '殖民地总会话：$count';
  }

  @override
  String get communityVisibilityOnly => '当前状态：仅社区可见性。CP、排名、快照与ANET余额分开。';

  @override
  String get blockchainTransparency => '区块链透明度：用户可通过ANET链检查公共链活动。';

  @override
  String yourCompletedSessions(String sessions, String target) {
    return '您已完成的会话：$sessions / $target';
  }

  @override
  String remainingTo1K(String remaining) {
    return '距1k剩余：$remaining';
  }

  @override
  String get colonySessionProgress => '殖民地会话进度';

  @override
  String get noColonyAnts => '还没有殖民地蚂蚁。';

  @override
  String completedSessionsAnt(String sessions) {
    return '已完成会话：$sessions / 1000';
  }

  @override
  String get qualifiedFor1KMilestone => '已达到1k里程碑资格';

  @override
  String get copyAntCode => '复制代码';

  @override
  String get shareColony => '分享殖民地';

  @override
  String get copyGoogleLink => '复制Google链接';

  @override
  String get copyAPKLink => '复制APK链接';

  @override
  String get seedPhraseBackupTitle => '助记词备份';

  @override
  String get securityCheckRequired => '需要安全检查。请输入您的钱包PIN以继续。';

  @override
  String get walletPINHint => '钱包PIN';

  @override
  String get sendOTPButton => '发送OTP';

  @override
  String get emailOTPHint => '邮箱OTP';

  @override
  String get neverSharePhrase => '切勿分享此助记词。拥有此助记词的任何人都可以控制您的钱包。';

  @override
  String get revealButton => '显示';

  @override
  String get setWalletPINTitle => '设置钱包PIN';

  @override
  String get changeWalletPINTitle => '更改钱包PIN';

  @override
  String get changePINRequiresOTP => '更改PIN需要您注册邮箱的OTP验证。';

  @override
  String get registeredEmail => '注册邮箱';

  @override
  String get currentPIN => '当前PIN';

  @override
  String get newPINHint => '新PIN（4-8位）';

  @override
  String get forgotPINButton => '忘记PIN？';

  @override
  String get forgotWalletPINTitle => '忘记钱包PIN';

  @override
  String get forgotPINInstructions => '通过邮箱验证重置您的钱包PIN。我们将向您的注册邮箱发送6位验证码。';

  @override
  String get sixDigitVerificationCode => '6位验证码';

  @override
  String get pinResetSuccessful => 'PIN重置成功';

  @override
  String get deleteAccountTitle => '删除账户';

  @override
  String get deleteAccountMessage => '这将在安全期后安排删除您的账户。';

  @override
  String get enterPINToConfirm => '输入PIN以确认';

  @override
  String get deleteButton => '删除';

  @override
  String get deletionRequested => '已提交删除请求';

  @override
  String get welcomeTitle => '欢迎来到A-Network';

  @override
  String get tutorialStep1 => '1）开始蚂蚁工作，等待6小时完成一个会话。';

  @override
  String get tutorialStep2 => '2）您首先积累ANTS。100,000,000 ANTS = 1 ANET。';

  @override
  String get tutorialStep3 => '3）达到1,000个会话以获得完整ANET转换功能的资格。';

  @override
  String get tutorialStep4 => '4）保护您的钱包：设置PIN，仅在需要时显示您的助记词。';

  @override
  String get gotItButton => '明白了';

  @override
  String get accountProfileTitle => '账户资料';

  @override
  String get levelEligible => '等级资格：符合资格';

  @override
  String levelNotEligible(String remaining) {
    return '等级资格：尚不符合资格（还差$remaining个会话）';
  }

  @override
  String get web4MigrationWalletTitle => 'Web4迁移钱包';

  @override
  String get migrationWalletOptional => '可选：现在输入您未来的Web4迁移钱包地址。';

  @override
  String get migrationWalletExample =>
      '示例：ANET1A2B3C4D5E6F...（ANET + 36个十六进制字符）';

  @override
  String get saveButton => '保存';

  @override
  String get migrationWalletNotChanged => '迁移钱包地址未更改';

  @override
  String get migrationWalletSaved => '迁移钱包地址已保存';

  @override
  String get changeEmailTitle => '更改邮箱';

  @override
  String get newEmailHint => '新邮箱';

  @override
  String get currentPasswordHint => '当前密码';

  @override
  String get emailChangedSuccessfully => '邮箱已成功更改';

  @override
  String get changePasswordTitle => '更改密码';

  @override
  String get newPasswordMin8 => '新密码（最少8个字符）';

  @override
  String get passwordChangedSuccessfully => '密码已成功更改';

  @override
  String get securityOwnershipTitle => '安全与所有权';

  @override
  String get emailVerificationNote => 'A-Network目前在注册时通过OTP强制执行邮箱验证。';

  @override
  String get otpVerificationOneTime => '此OTP验证仅用于账户激活的一次性操作。';

  @override
  String get emailLossWarning => '如果您失去对邮箱的访问权限且无法恢复，您将失去对账户和已挖ANET的访问权限。';

  @override
  String get ownershipModel => '所有权模型：您的邮箱 + 您创建的钱包地址 = 您在生态系统中的直接所有权密钥。';

  @override
  String get web4MigrationKeepSafe => '对于Web4迁移，请妥善保管您的邮箱和钱包详情。';

  @override
  String get notificationsTitle => '通知';

  @override
  String get antWorkAlertsActive => '当前6小时会话的蚂蚁工作提醒已激活。';

  @override
  String get startAntWorkNotifications => '开始蚂蚁工作以安排下次完成提醒。';

  @override
  String get notificationsInfo => '通知用于验证会话提醒、完成时间和重要生态系统更新。';

  @override
  String get sessionRunning => '当前状态：会话进行中，完成提醒待发。';

  @override
  String get noActiveSession => '当前状态：没有活跃会话，因此尚未安排完成提醒。';

  @override
  String get refreshButton => '刷新';

  @override
  String get languageTitle => '语言';

  @override
  String get languageHelp =>
      '选择您的应用语言。自动模式映射地区默认：印度→印地语，巴基斯坦→乌尔都语，中国→中文，西班牙/拉美→西班牙语，越南→越南语。';

  @override
  String get aboutTitle => '关于A-Network';

  @override
  String get aboutContent =>
      'A-Network由A Network LLC（加利福尼亚实体编号20260170159）运营。\n\n生产模型采用ANTS优先记账，其中1 ANET = 100,000,000 ANTS。';

  @override
  String get openWeb4Button => '打开Web4';

  @override
  String get displayThemeTitle => '显示主题';

  @override
  String get classicTheme => '经典主题';

  @override
  String get classicThemeDesc => '现有A-Network青色演示。';

  @override
  String get antsTheme => 'ANTS生态系统主题';

  @override
  String get antsThemeDesc => 'Web4风格的绿色、青色和金色投资者样式。';

  @override
  String get studioTheme => '工作室浅色主题';

  @override
  String get studioThemeDesc => '带连接粒子和酷蓝强调色的专业浅色背景。';

  @override
  String get executiveTheme => '高管深色主题';

  @override
  String get executiveThemeDesc => '带香槟强调色的石墨表面，提供更清晰的投资者演示。';

  @override
  String get paperTheme => '纸张浅色主题';

  @override
  String get paperThemeDesc => '带墨蓝标签的温暖编辑浅色样式。';

  @override
  String get viewProfileDetails => '查看资料详情';

  @override
  String get changeEmail => '更改邮箱';

  @override
  String get changePassword => '更改密码';

  @override
  String get helpSupport => '帮助和支持';

  @override
  String get logoutButton => '退出登录';

  @override
  String get sixHourAntWorkComplete => '6小时蚂蚁工作会话完成。正在发布您的ANET会话积分...';

  @override
  String antWorkCompletedAccumulated(String reward) {
    return '✅ 蚂蚁工作完成！您积累了 $reward ANET';
  }

  @override
  String antWorkAutoCompleted(String reward) {
    return '✅ 蚂蚁工作自动完成。$reward ANET已记入。';
  }

  @override
  String get antWorkStartedSuccessfully => '蚂蚁工作已成功启动';

  @override
  String completeAntWorkFailed(String error) {
    return '完成蚂蚁工作失败：$error';
  }

  @override
  String startAntWorkFailed(String error) {
    return '启动蚂蚁工作失败：$error';
  }

  @override
  String get territoryOverview => '地区概览';

  @override
  String get totalAntsDialog => '蚂蚁总数';

  @override
  String get networkShare => '网络份额';

  @override
  String get activeWorkersDialog => '活跃工作者';

  @override
  String get sessionsInTerritory => '地区内会话';

  @override
  String get liveBackendStats => '来源：实时后端国家统计数据。';

  @override
  String get fallbackEstimate => '来源：备用估算。国家统计端点不可用。';

  @override
  String get web3AnetMarket => 'Web3 ANET市场';

  @override
  String get marketImportance =>
      '重要：此应用中挖矿的ANET通过蚂蚁工作积累。BNB链ANET合约是独立的Web3可见性层。';

  @override
  String get bnbChainContract => 'BNB链市场合约';

  @override
  String get currentSeparation => '当前分离';

  @override
  String get separationPoint1 => '1. 此应用中的ANET代币通过验证会话积累。';

  @override
  String get separationPoint2 => '2. BNB链ANET合约和DEX参考是独立的Web3可见性工具。';

  @override
  String get separationPoint3 => '3. 殖民地、CP、排名、快照和未来合伙人分配不在ANET和ANTS记账模型之内。';

  @override
  String get separationPoint4 => '4. 通过ANET链可获得完整的区块链透明度。';

  @override
  String get openMarketPair => '打开市场交易对';

  @override
  String get viewLiveChart => '查看实时图表';

  @override
  String get viewContract => '查看合约';

  @override
  String get copyContractAddress => '复制合约';

  @override
  String get anetMarketContract => 'ANET市场合约';

  @override
  String get moreInfo => '更多信息';

  @override
  String get createYourL1Wallet => '请先创建您的L1钱包';

  @override
  String get createL1WalletMessage => '您的BIP-44助记词与所有EVM钱包兼容。';

  @override
  String get generateWallet => '生成钱包';

  @override
  String get walletLocked => '钱包已锁定';

  @override
  String get setPINToContinue => '设置PIN以继续';

  @override
  String get enterWalletPIN => '输入您的钱包PIN以访问Web3钱包。';

  @override
  String get setWalletPINAccess => '访问前设置PIN以保护您的钱包。';

  @override
  String get unlockWallet => '解锁钱包';

  @override
  String get setWalletPINButton => '设置钱包PIN';

  @override
  String get mainnetWallet => '主网钱包';

  @override
  String get homeTab => '首页';

  @override
  String get assetsTab => '资产';

  @override
  String get activityTab => '活动';

  @override
  String get sessionsTab => '会话';

  @override
  String get addToken => '添加代币';

  @override
  String get totalBalance => '总余额';

  @override
  String get send => '发送';

  @override
  String get receive => '接收';

  @override
  String get explorer => '浏览器';

  @override
  String get bridge => '桥接';

  @override
  String get miningProfile => '挖矿资料';

  @override
  String get joined => '加入时间';

  @override
  String get completedSessions => '已完成会话';

  @override
  String get anetBalance => 'ANET余额';

  @override
  String get currentRate => '当前费率';

  @override
  String get colonyJoined => '已加入殖民地';

  @override
  String get notInColony => '未加入任何殖民地';

  @override
  String get sessionHistory => '会话历史';

  @override
  String get credited => '已记入';

  @override
  String get inProgress => '进行中';

  @override
  String get aiSupportTitle => 'A-Network AI';

  @override
  String get trainButton => '训练';

  @override
  String get web4MigrationPolicy => 'Web4迁移政策';

  @override
  String get anetVsAnts => 'ANET与ANTS对比';

  @override
  String get securityWalletSafety => '安全与钱包安全';

  @override
  String get trainAITitle => '训练A-Network AI';

  @override
  String get knowledgeHint => '要记住的知识（事实、政策、产品详情）';

  @override
  String get optionalTrainingPrompt => '可选训练提示';

  @override
  String get optionalIdealResponse => '可选理想回复';

  @override
  String get addMemoryOrBoth => '添加记忆文本，或同时添加训练提示和理想回复。';

  @override
  String get aiTrainingSaved => 'AI训练已保存';

  @override
  String get noAITokensLeft => '没有剩余AI令牌。观看广告获取更多令牌或等待6小时补充。';

  @override
  String get voiceRecognitionUnavailable => '此设备不支持语音识别';

  @override
  String get noAssistantResponse => '没有可朗读的助手回复';

  @override
  String get adNotCompleted => '广告未完成。暂无令牌奖励。';

  @override
  String aiTokensAdded(String tokens, String balance) {
    return '已添加 $tokens 个AI令牌。余额：$balance';
  }

  @override
  String uploadedToMemory(String filename) {
    return '已将 $filename 上传至AI记忆';
  }

  @override
  String get copiedResponse => '已复制回复';

  @override
  String get listeningSpeak => '正在聆听...请说出您的问题';

  @override
  String get askAIAnything => '向A-Network AI提问...';

  @override
  String get deepResearchEnabled => '已为后续消息启用深度研究';

  @override
  String get deepResearchDisabled => '深度研究已禁用';

  @override
  String get uploadTxtTooltip => '上传txt/md/pdf以训练AI';

  @override
  String get stopListeningTooltip => '停止聆听';

  @override
  String get startVoiceInputTooltip => '开始语音输入';

  @override
  String get stopReadAloudTooltip => '停止朗读';

  @override
  String get readLatestResponseTooltip => '朗读最新回复';

  @override
  String watchAdTokens(String tokens) {
    return '观看广告 + $tokens 令牌';
  }

  @override
  String tokenBalance(String balance) {
    return '令牌：$balance';
  }

  @override
  String get pickGroupName => '选择您的群组名称';

  @override
  String get claimPermanentUpline => '认领永久上线';

  @override
  String get claimUplineInstructions =>
      '保留自己的殖民地不需要上线。只有当您想永久加入该所有者的殖民地时，才在此输入蚂蚁码。';

  @override
  String get enterAntCode => '输入蚂蚁码';

  @override
  String get claimButton => '认领';

  @override
  String get antCodeLinked => '蚂蚁码已关联。您的殖民地上线现在是永久性的。';

  @override
  String get writeToColony => '向您的殖民地写信';

  @override
  String get writeToUplines => '向您的殖民地上线写信';

  @override
  String get pickGroupNameTooltip => '选择群组名称';

  @override
  String get refreshChatTooltip => '刷新聊天';

  @override
  String get tabEcosystem => '生态系统';

  @override
  String get tabAntWork => '蚂蚁工作';

  @override
  String get tabWallet => '钱包';

  @override
  String get tabColony => '殖民地';

  @override
  String get tabMore => '更多';

  @override
  String get pageTitleEcosystem => '蚂蚁生态系统';

  @override
  String get pageTitleAntWork => '蚂蚁工作';

  @override
  String get pageTitleWallet => 'ANET 钱包';

  @override
  String get pageTitleWeb4 => 'Web4';

  @override
  String get pageTitleWhitepaper => '白皮书';

  @override
  String get pageTitleColony => '殖民地 (Web5)';

  @override
  String get pageTitleMore => '更多';

  @override
  String get antWorkSectionLabel => '蚂蚁工作';

  @override
  String get morePageTitle => '更多';

  @override
  String get morePageSubtitle => '帐户、法律、支持和显示控件集中一处。';

  @override
  String get walletMenuLabel => '钱包';

  @override
  String get walletMenuSubtitle => '余额和 Web3 工具';

  @override
  String get antWorkHeroTitle => '蚂蚁工作';

  @override
  String get antWorkHeroSubtitle => '监控实时 6 小时会话、当前输出和重要网络里程碑。';
}
