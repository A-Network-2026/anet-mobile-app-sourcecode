// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'A-Network';

  @override
  String get authPageSubtitle =>
      'Acceso limpio a minería Web2 con continuidad segura de billetera.';

  @override
  String get loginTab => 'Iniciar sesión';

  @override
  String get registerTab => 'Registrarse';

  @override
  String get emailHint => 'Correo electrónico';

  @override
  String get passwordHint => 'Contraseña';

  @override
  String get antCodeHint => 'Código Ant (Opcional)';

  @override
  String get continueLoginButton => 'Continuar al inicio de sesión';

  @override
  String get continueRegisterButton => 'Continuar al registro';

  @override
  String get forgotPasswordButton => '¿Olvidaste la contraseña?';

  @override
  String get useExistingAccountButton =>
      'Usar inicio de sesión de cuenta existente';

  @override
  String get restoreDeletedAccountButton => 'Restaurar cuenta eliminada';

  @override
  String get sessionModelTitle => 'Modelo de sesión';

  @override
  String get sessionModelSubtitle =>
      'La minería funciona en ciclos de 6 horas y el progreso se sincroniza con tu cuenta de billetera.';

  @override
  String get securityLayerTitle => 'Capa de seguridad';

  @override
  String get securityLayerSubtitle =>
      'Las protecciones de frase semilla, PIN y restauración de cuenta están integradas.';

  @override
  String get emailPasswordRequired =>
      'El correo electrónico y la contraseña son obligatorios';

  @override
  String get deviceLimitError =>
      'Este dispositivo ya alcanzó el máximo de cuentas vinculadas. Inicia sesión con una cuenta existente o usa un dispositivo diferente para registrarte.';

  @override
  String get accountRestorationEligible =>
      'Restauración disponible. Tu cuenta estaba programada para eliminación.';

  @override
  String get openEmailApp =>
      'Abriendo aplicación de correo para info@a-network.net';

  @override
  String get emailAppNotAvailable =>
      'Aplicación de correo no disponible, página de soporte abierta';

  @override
  String get forgotPasswordTitle => 'Olvidé mi contraseña';

  @override
  String get forgotPasswordInstructions =>
      'Ingresa tu correo registrado para recibir un código de restablecimiento de 6 dígitos.';

  @override
  String get sendCodeButton => 'Enviar código';

  @override
  String get resendCodeButton => 'Reenviar código';

  @override
  String get sixDigitCodeHint => 'Código de 6 dígitos';

  @override
  String get newPasswordHint => 'Nueva contraseña';

  @override
  String get confirmPasswordHint => 'Confirmar nueva contraseña';

  @override
  String get resetPasswordButton => 'Restablecer contraseña';

  @override
  String get needHelpButton => '¿Necesitas ayuda?';

  @override
  String get verifyEmailTitle => 'Verificar correo electrónico';

  @override
  String verifyEmailInstructions(String email) {
    return 'Ingresa el código de 6 dígitos enviado a $email';
  }

  @override
  String get otpCodeHint => 'Código OTP';

  @override
  String get verifyButton => 'Verificar';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get emailVerificationCancelled =>
      'Verificación de correo cancelada. Ingresa tu último código más tarde o toca Reenviar código para obtener uno nuevo.';

  @override
  String get loginVerificationTitle => 'Verificación de inicio de sesión';

  @override
  String loginVerificationInstructions(String email) {
    return 'Ingresa el código de inicio de sesión de 6 dígitos enviado a $email';
  }

  @override
  String get loginVerificationCancelled =>
      'Verificación de inicio de sesión cancelada. Ingresa tu código más reciente más tarde o solicita uno nuevo.';

  @override
  String get convertedDeepLink =>
      'Enlace profundo convertido para el navegador ANTS';

  @override
  String blockedUnsupportedScheme(String scheme) {
    return 'Esquema no compatible bloqueado: $scheme';
  }

  @override
  String get untrustedDomainTitle => 'Dominio no confiable';

  @override
  String untrustedDomainMessage(String host, String url) {
    return 'Este dominio no está en la lista de dApps de confianza:\n\n$host\n\nURL:\n$url\n\nContinúa solo si confías en este sitio.';
  }

  @override
  String get trustForSessionButton => 'Confiar en esta sesión';

  @override
  String get openDAppPageFirst => 'Primero abre una página dApp';

  @override
  String connectionBlockedUntrusted(String host) {
    return 'Conexión bloqueada para dominio no confiable: $host';
  }

  @override
  String get connectWalletTitle => 'Conectar billetera';

  @override
  String connectWalletPrompt(String host, String network, String address) {
    return 'dApp: $host\nRed: $network\nBilletera: $address\n\n¿Otorgar acceso de sesión para leer tu dirección de billetera y solicitar firmas?';
  }

  @override
  String get rejectButton => 'Rechazar';

  @override
  String get connectButton => 'Conectar';

  @override
  String walletConnectedSnackbar(String host) {
    return 'Billetera conectada a $host';
  }

  @override
  String get walletPINVerificationTitle => 'Verificación de PIN de billetera';

  @override
  String get walletPINInstructions =>
      'Ingresa tu PIN de billetera para habilitar solicitudes de firma durante 5 minutos.';

  @override
  String get pinMustBe => 'El PIN debe tener entre 4 y 8 dígitos';

  @override
  String get verifyingPIN => 'Verificando...';

  @override
  String get connectWalletToDApp => 'Primero conecta la billetera a una dApp';

  @override
  String get seedPhraseRequired =>
      'Se requiere frase semilla local segura para la firma EVM real';

  @override
  String get signRequestTitle => 'Solicitud de firma';

  @override
  String signRequestContent(String host, String network) {
    return 'dApp: $host\nRed: $network';
  }

  @override
  String get messageToSign => 'Mensaje a firmar';

  @override
  String get approveSignature => 'Apruebo esta solicitud de firma';

  @override
  String get signButton => 'Firmar';

  @override
  String get signatureApprovedTitle => 'Firma aprobada';

  @override
  String get copyButton => 'Copiar';

  @override
  String get closeButton => 'Cerrar';

  @override
  String get signaturePayloadCopied => 'Carga de firma copiada';

  @override
  String get antsBrowserTitle => 'Navegador ANTS';

  @override
  String get connectWalletTooltip => 'Conectar billetera';

  @override
  String get disconnectTooltip => 'Desconectar';

  @override
  String get approveSignTooltip => 'Aprobar solicitud de firma';

  @override
  String walletNotConnected(String host) {
    return 'Billetera no conectada. Solo hosts de confianza. Actual: $host';
  }

  @override
  String walletConnectedStatus(String host, String network) {
    return 'Conectado: $host • $network';
  }

  @override
  String get enterURL => 'Ingresar URL';

  @override
  String get goButton => 'Ir';

  @override
  String get loadingAISupport => 'Cargando soporte de IA...';

  @override
  String get aiSupportConnectionError =>
      'No se pudo conectar al soporte de IA. Por favor verifica tu conexión a internet.';

  @override
  String get retryButton => 'Reintentar';

  @override
  String get autoRegion => 'Automático (Región)';

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
  String get securityLockTitle => 'Bloqueo de seguridad activo';

  @override
  String get securityLockMessage =>
      'Esta compilación detectó un entorno de ejecución de alto riesgo y bloqueó el inicio de sesión, Ant Work y el acceso a la billetera para reducir el abuso de emuladores, dispositivos con root y manipulación.';

  @override
  String detectedFlags(String flags) {
    return 'Indicadores detectados: $flags';
  }

  @override
  String platformRuntime(String platform, String runtime) {
    return 'Plataforma: $platform  |  Entorno: $runtime';
  }

  @override
  String get securityOverrideInfo =>
      'Usa una versión oficial en un dispositivo físico. Solo para pruebas internas, los desarrolladores pueden anular este bloqueo con --dart-define=ALLOW_INSECURE_DEVICE=true.';

  @override
  String get anetGlobal => 'A-Network Global';

  @override
  String get globalSubtitle =>
      'Resumen de red profesional, estado de minería y visibilidad de billetera.';

  @override
  String get profileSupport => 'Perfil y soporte';

  @override
  String get halvingAnnouncementTitle => 'LA REDUCCIÓN A LA MITAD HA COMENZADO';

  @override
  String get halvingAnnouncementBody =>
      'La red ha alcanzado el hito de 500,000 sesiones. La primera reducción a la mitad ya está en vigor.';

  @override
  String get halvingAnnouncementNote =>
      'Hay un retraso de validación de 6 horas antes de que se aplique la tasa actualizada.';

  @override
  String get halvingActionSafe =>
      'No se requiere ninguna acción: las sesiones en progreso son seguras y se acreditarán a la tasa correcta.';

  @override
  String get xAnnouncementTitle => 'ÚLTIMA ACTUALIZACIÓN DE X';

  @override
  String get xAnnouncementBody =>
      'Sigue a Mr_A_Awakening para las últimas publicaciones oficiales de A-Network.';

  @override
  String get xAnnouncementNote =>
      'Esta diapositiva rota automáticamente cada 60 segundos con la tarjeta de actualización de reducción a la mitad.';

  @override
  String get xAnnouncementCTA => 'Abrir las últimas actualizaciones de X';

  @override
  String get liveStatus => 'EN VIVO';

  @override
  String get networkStatus => 'Estado de la red';

  @override
  String get totalAnts => 'Total de hormigas';

  @override
  String get registered => 'registrados';

  @override
  String get activeWorkers => 'Trabajadores activos';

  @override
  String get completedWork => 'trabajo completado';

  @override
  String activeTerritories(String count) {
    return 'Territorios activos ($count+)';
  }

  @override
  String get verifiedSessions => 'SESIONES VERIFICADAS';

  @override
  String get networkThroughput => 'Rendimiento de red';

  @override
  String get liveOutput => 'PRODUCCIÓN EN VIVO';

  @override
  String get anetPerSession => 'ANET / sesión';

  @override
  String get markets => 'MERCADOS';

  @override
  String get activeTerritoriesCount => 'Territorios activos';

  @override
  String get liveAntWork => 'Trabajo de hormigas en vivo';

  @override
  String get startingAntWork => 'Iniciando trabajo de hormigas...';

  @override
  String get antWorkActive => 'Trabajo de hormigas activo';

  @override
  String get readyToStart => 'Listo para comenzar';

  @override
  String sessionEndsIn(String time) {
    return 'La sesión termina en $time';
  }

  @override
  String get startAnyTime =>
      'Comienza cuando quieras. El temporizador de 6 horas comienza con tu toque.';

  @override
  String get openAntWork => 'Abrir trabajo de hormigas';

  @override
  String get startAntWork => 'Iniciar trabajo de hormigas';

  @override
  String get refreshActivity => 'Actualizar actividad';

  @override
  String get beginJourney => 'Comienza tu viaje';

  @override
  String get startAntWorkInfo =>
      'Inicia una sesión de trabajo de hormigas verificada de 6 horas. La actividad se rastrea primero en ANTS, luego se puede reclamar en ANET.';

  @override
  String get anetWalletAction => 'Billetera ANET';

  @override
  String get balanceWalletTools =>
      'Saldo, herramientas de billetera, visibilidad de cadena';

  @override
  String get anetWalletInfo =>
      'Abre herramientas de billetera, mapeo de saldo actual y visibilidad del ecosistema público.';

  @override
  String get sessionOutput => 'PRODUCCIÓN DE SESIÓN';

  @override
  String get anetPer6Hour => 'ANET por ciclo de 6 horas';

  @override
  String get portfolio => 'PORTAFOLIO';

  @override
  String get antsAccumulated => 'ANTS acumulados';

  @override
  String get typeWebsite => 'Primero escribe un sitio web o palabra clave';

  @override
  String get createWalletFirst => 'Primero crea tu billetera';

  @override
  String get walletBalanceSynced =>
      'Saldo de billetera sincronizado desde ANET minado';

  @override
  String get noColonyMessage =>
      'Tu colonia está lista. No se necesita línea superior. Elige un nombre de colonia e invita hormigas con tu código Ant.';

  @override
  String get noColonyMessagesYet => 'Aún no hay mensajes de colonia.';

  @override
  String get myAntCodeTitle => 'Mi enlace de código Ant';

  @override
  String antCodeLabel(String code) {
    return 'Código Ant: $code';
  }

  @override
  String get referralLinksLabel => 'Enlaces de referido';

  @override
  String get openGoogleLink => 'Abrir enlace de Google';

  @override
  String get openAPKLink => 'Abrir enlace APK';

  @override
  String get copyShareText => 'Copiar texto para compartir';

  @override
  String get colonyTrackerTitle => 'Rastreador de colonia';

  @override
  String get colonyDescription =>
      'La colonia es la futura capa comunitaria Web5. Es solo de visualización por ahora y se mantiene separada de las sesiones de minería Web2.';

  @override
  String get operatingModel =>
      'Modelo operativo: Web2 = Minería Ant Work y contabilidad ANTS. Web3 = visibilidad BNB Chain. Web4 = liquidación ANET-Chain. Web5 = coordinación comunitaria.';

  @override
  String get futureAnetCoreNote =>
      'Nota futura del núcleo ANET: esta cuenta ya tiene una billetera Web3 lista para la incorporación futura de socios.';

  @override
  String get futureCorNoteNoWallet =>
      'Nota futura del núcleo ANET: la incorporación futura de socios puede requerir un requisito separado de billetera Web3, pero en esta compilación no se aplica ninguna barrera de entrada.';

  @override
  String get yourAntCode => 'Tu código Ant';

  @override
  String directColonyAnts(String count) {
    return 'Hormigas directas de colonia: $count';
  }

  @override
  String colonyCompleted1K(String count) {
    return 'Hormigas de colonia con 1k sesiones completadas: $count';
  }

  @override
  String totalColonySessions(String count) {
    return 'Total de sesiones de colonia: $count';
  }

  @override
  String get communityVisibilityOnly =>
      'Estado actual: solo visibilidad comunitaria. CP, rango, instantáneas están separados del saldo ANET.';

  @override
  String get blockchainTransparency =>
      'Transparencia blockchain: los usuarios pueden inspeccionar la actividad pública de la cadena a través de ANET-Chain.';

  @override
  String yourCompletedSessions(String sessions, String target) {
    return 'Tus sesiones completadas: $sessions / $target';
  }

  @override
  String remainingTo1K(String remaining) {
    return 'Restantes para 1k: $remaining';
  }

  @override
  String get colonySessionProgress => 'Progreso de sesiones de colonia';

  @override
  String get noColonyAnts => 'Aún no hay hormigas de colonia.';

  @override
  String completedSessionsAnt(String sessions) {
    return 'Sesiones completadas: $sessions / 1000';
  }

  @override
  String get qualifiedFor1KMilestone => 'Calificado para el hito de 1k';

  @override
  String get copyAntCode => 'Copiar código';

  @override
  String get shareColony => 'Compartir colonia';

  @override
  String get copyGoogleLink => 'Copiar enlace de Google';

  @override
  String get copyAPKLink => 'Copiar enlace APK';

  @override
  String get seedPhraseBackupTitle => 'Copia de seguridad de frase semilla';

  @override
  String get securityCheckRequired =>
      'Se requiere verificación de seguridad. Ingresa tu PIN de billetera para continuar.';

  @override
  String get walletPINHint => 'PIN de billetera';

  @override
  String get sendOTPButton => 'Enviar OTP';

  @override
  String get emailOTPHint => 'OTP por correo';

  @override
  String get neverSharePhrase =>
      'Nunca compartas esta frase. Cualquiera con esta frase puede controlar tu billetera.';

  @override
  String get revealButton => 'Revelar';

  @override
  String get setWalletPINTitle => 'Establecer PIN de billetera';

  @override
  String get changeWalletPINTitle => 'Cambiar PIN de billetera';

  @override
  String get changePINRequiresOTP =>
      'Cambiar el PIN requiere verificación OTP de tu correo registrado.';

  @override
  String get registeredEmail => 'Correo registrado';

  @override
  String get currentPIN => 'PIN actual';

  @override
  String get newPINHint => 'Nuevo PIN (4-8 dígitos)';

  @override
  String get forgotPINButton => '¿Olvidaste el PIN?';

  @override
  String get forgotWalletPINTitle => 'Olvidé el PIN de la billetera';

  @override
  String get forgotPINInstructions =>
      'Restablece tu PIN de billetera mediante verificación por correo. Enviaremos un código de 6 dígitos a tu correo registrado.';

  @override
  String get sixDigitVerificationCode => 'Código de verificación de 6 dígitos';

  @override
  String get pinResetSuccessful => 'PIN restablecido correctamente';

  @override
  String get deleteAccountTitle => 'Eliminar cuenta';

  @override
  String get deleteAccountMessage =>
      'Esto programará la eliminación de tu cuenta después de un período de seguridad.';

  @override
  String get enterPINToConfirm => 'Ingresa el PIN para confirmar';

  @override
  String get deleteButton => 'Eliminar';

  @override
  String get deletionRequested => 'Eliminación solicitada';

  @override
  String get welcomeTitle => 'Bienvenido a A-Network';

  @override
  String get tutorialStep1 =>
      '1) Inicia Ant Work y espera 6 horas para completar una sesión.';

  @override
  String get tutorialStep2 =>
      '2) Acumulas ANTS primero. 100,000,000 ANTS = 1 ANET.';

  @override
  String get tutorialStep3 =>
      '3) Alcanza 1,000 sesiones para ser elegible para las funciones completas de conversión de ANET.';

  @override
  String get tutorialStep4 =>
      '4) Protege tu billetera: establece un PIN y solo revela tu semilla cuando sea necesario.';

  @override
  String get gotItButton => 'Entendido';

  @override
  String get accountProfileTitle => 'Perfil de cuenta';

  @override
  String get levelEligible => 'Elegibilidad de nivel: Elegible';

  @override
  String levelNotEligible(String remaining) {
    return 'Elegibilidad de nivel: Aún no elegible ($remaining sesiones restantes)';
  }

  @override
  String get web4MigrationWalletTitle => 'Billetera de migración Web4';

  @override
  String get migrationWalletOptional =>
      'Opcional: ingresa ahora tu futura dirección de billetera de migración Web4.';

  @override
  String get migrationWalletExample =>
      'Ejemplo: ANET1A2B3C4D5E6F... (ANET + 36 caracteres hex)';

  @override
  String get saveButton => 'Guardar';

  @override
  String get migrationWalletNotChanged =>
      'La dirección de la billetera de migración no cambió';

  @override
  String get migrationWalletSaved =>
      'Dirección de billetera de migración guardada';

  @override
  String get changeEmailTitle => 'Cambiar correo electrónico';

  @override
  String get newEmailHint => 'Nuevo correo electrónico';

  @override
  String get currentPasswordHint => 'Contraseña actual';

  @override
  String get emailChangedSuccessfully =>
      'Correo electrónico cambiado correctamente';

  @override
  String get changePasswordTitle => 'Cambiar contraseña';

  @override
  String get newPasswordMin8 => 'Nueva contraseña (mín. 8 caracteres)';

  @override
  String get passwordChangedSuccessfully => 'Contraseña cambiada correctamente';

  @override
  String get securityOwnershipTitle => 'Seguridad y propiedad';

  @override
  String get emailVerificationNote =>
      'A-Network actualmente aplica la verificación de correo mediante OTP durante el registro.';

  @override
  String get otpVerificationOneTime =>
      'Esta verificación OTP es única solo para la activación de la cuenta.';

  @override
  String get emailLossWarning =>
      'Si pierdes el acceso a tu correo y no puedes recuperarlo, perderás el acceso a tu cuenta y al ANET minado.';

  @override
  String get ownershipModel =>
      'Modelo de propiedad: tu correo + la dirección de billetera que creaste = tu clave de propiedad directa en el ecosistema.';

  @override
  String get web4MigrationKeepSafe =>
      'Para la migración Web4, mantén seguros tanto tu correo como los detalles de tu billetera.';

  @override
  String get notificationsTitle => 'Notificaciones';

  @override
  String get antWorkAlertsActive =>
      'Las alertas de Ant Work están activas para la sesión actual de 6 horas.';

  @override
  String get startAntWorkNotifications =>
      'Inicia Ant Work para programar la próxima alerta de finalización.';

  @override
  String get notificationsInfo =>
      'Las notificaciones se usan para recordatorios de sesión verificada, tiempo de finalización y actualizaciones importantes del ecosistema.';

  @override
  String get sessionRunning =>
      'Estado actual: sesión en curso, recordatorio de finalización pendiente.';

  @override
  String get noActiveSession =>
      'Estado actual: sin sesión activa, por lo que aún no se ha programado ningún recordatorio.';

  @override
  String get refreshButton => 'Actualizar';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageHelp =>
      'Elige el idioma de tu aplicación. El modo automático mapea los idiomas por región: India → Hindi, Pakistán → Urdu, China → Chino, España/Latinoamérica → Español, Vietnam → Vietnamita.';

  @override
  String get aboutTitle => 'Acerca de A-Network';

  @override
  String get aboutContent =>
      'A-Network es operada por A Network LLC, Entidad de California No. 20260170159.\n\nEl modelo de producción usa contabilidad ANTS-primero, donde 1 ANET = 100,000,000 ANTS.';

  @override
  String get openWeb4Button => 'Abrir Web4';

  @override
  String get displayThemeTitle => 'Tema de pantalla';

  @override
  String get classicTheme => 'Tema principal clásico';

  @override
  String get classicThemeDesc => 'Presentación cyan existente de A-Network.';

  @override
  String get antsTheme => 'Tema del ecosistema ANTS';

  @override
  String get antsThemeDesc =>
      'Estilo de inversor verde, cyan y dorado inspirado en Web4.';

  @override
  String get studioTheme => 'Tema claro de estudio';

  @override
  String get studioThemeDesc =>
      'Fondo claro profesional con partículas conectadas y acentos azul frío.';

  @override
  String get executiveTheme => 'Tema oscuro ejecutivo';

  @override
  String get executiveThemeDesc =>
      'Superficies de grafito con acentos champán para una presentación de inversor más nítida.';

  @override
  String get paperTheme => 'Tema claro de papel';

  @override
  String get paperThemeDesc =>
      'Estilo editorial cálido con etiquetas azul tinta y movimiento más suave.';

  @override
  String get viewProfileDetails => 'Ver detalles del perfil';

  @override
  String get changeEmail => 'Cambiar correo';

  @override
  String get changePassword => 'Cambiar contraseña';

  @override
  String get helpSupport => 'Ayuda y soporte';

  @override
  String get logoutButton => 'Cerrar sesión';

  @override
  String get sixHourAntWorkComplete =>
      'Sesión de trabajo de hormigas de 6 horas completada. Publicando tu crédito de sesión ANET ahora...';

  @override
  String antWorkCompletedAccumulated(String reward) {
    return '✅ ¡Trabajo de hormigas completado! Acumulaste $reward ANET';
  }

  @override
  String antWorkAutoCompleted(String reward) {
    return '✅ Trabajo de hormigas completado automáticamente. $reward ANET acreditados.';
  }

  @override
  String get antWorkStartedSuccessfully =>
      'Trabajo de hormigas iniciado correctamente';

  @override
  String completeAntWorkFailed(String error) {
    return 'Error al completar el trabajo de hormigas: $error';
  }

  @override
  String startAntWorkFailed(String error) {
    return 'Error al iniciar el trabajo de hormigas: $error';
  }

  @override
  String get territoryOverview => 'Resumen del territorio';

  @override
  String get totalAntsDialog => 'Total de hormigas';

  @override
  String get networkShare => 'Participación en la red';

  @override
  String get activeWorkersDialog => 'Trabajadores activos';

  @override
  String get sessionsInTerritory => 'Sesiones en el territorio';

  @override
  String get liveBackendStats =>
      'Fuente: estadísticas de país del backend en vivo.';

  @override
  String get fallbackEstimate =>
      'Fuente: estimación de respaldo. Punto final de estadísticas de país no disponible.';

  @override
  String get web3AnetMarket => 'Mercado Web3 ANET';

  @override
  String get marketImportance =>
      'Importante: el ANET minado en esta aplicación se acumula a través de Ant Work. El contrato ANET de BNB Chain es la capa de visibilidad Web3 separada.';

  @override
  String get bnbChainContract => 'Contrato de mercado BNB Chain';

  @override
  String get currentSeparation => 'Separación actual';

  @override
  String get separationPoint1 =>
      '1. Los tokens ANET en esta aplicación se acumulan a través de sesiones verificadas.';

  @override
  String get separationPoint2 =>
      '2. El contrato ANET de BNB Chain y las referencias DEX son herramientas separadas de visibilidad Web3.';

  @override
  String get separationPoint3 =>
      '3. Colonia, CP, rango, instantáneas y distribuciones futuras de socios están fuera del modelo de contabilidad ANET y ANTS.';

  @override
  String get separationPoint4 =>
      '4. La transparencia completa de blockchain está disponible a través de ANET-Chain.';

  @override
  String get openMarketPair => 'Abrir par de mercado';

  @override
  String get viewLiveChart => 'Ver gráfico en vivo';

  @override
  String get viewContract => 'Ver contrato';

  @override
  String get copyContractAddress => 'Copiar contrato';

  @override
  String get anetMarketContract => 'Contrato de mercado ANET';

  @override
  String get moreInfo => 'Más información';

  @override
  String get createYourL1Wallet => 'Primero crea tu billetera L1';

  @override
  String get createL1WalletMessage =>
      'Tu semilla BIP-44 es compatible con todas las billeteras EVM.';

  @override
  String get generateWallet => 'Generar billetera';

  @override
  String get walletLocked => 'Billetera bloqueada';

  @override
  String get setPINToContinue => 'Establecer PIN para continuar';

  @override
  String get enterWalletPIN =>
      'Ingresa tu PIN de billetera para acceder a tu billetera Web3.';

  @override
  String get setWalletPINAccess =>
      'Establece un PIN para proteger tu billetera antes de acceder.';

  @override
  String get unlockWallet => 'Desbloquear billetera';

  @override
  String get setWalletPINButton => 'Establecer PIN de billetera';

  @override
  String get mainnetWallet => 'Billetera Mainnet';

  @override
  String get homeTab => 'Inicio';

  @override
  String get assetsTab => 'Activos';

  @override
  String get activityTab => 'Actividad';

  @override
  String get sessionsTab => 'Sesiones';

  @override
  String get addToken => 'Agregar token';

  @override
  String get totalBalance => 'Saldo total';

  @override
  String get send => 'Enviar';

  @override
  String get receive => 'Recibir';

  @override
  String get explorer => 'Explorador';

  @override
  String get bridge => 'Puente';

  @override
  String get miningProfile => 'Perfil de minería';

  @override
  String get joined => 'Unido';

  @override
  String get completedSessions => 'Sesiones completadas';

  @override
  String get anetBalance => 'Saldo ANET';

  @override
  String get currentRate => 'Tasa actual';

  @override
  String get colonyJoined => 'Colonia unida';

  @override
  String get notInColony => 'No está en una colonia';

  @override
  String get sessionHistory => 'Historial de sesiones';

  @override
  String get credited => 'Acreditado';

  @override
  String get inProgress => 'En progreso';

  @override
  String get aiSupportTitle => 'A-Network IA';

  @override
  String get trainButton => 'Entrenar';

  @override
  String get web4MigrationPolicy => 'Política de migración Web4';

  @override
  String get anetVsAnts => 'ANET vs ANTS';

  @override
  String get securityWalletSafety => 'Seguridad y protección de billetera';

  @override
  String get trainAITitle => 'Entrenar IA de A-Network';

  @override
  String get knowledgeHint =>
      'Conocimiento a recordar (hechos, políticas, detalles del producto)';

  @override
  String get optionalTrainingPrompt => 'Indicación de entrenamiento opcional';

  @override
  String get optionalIdealResponse => 'Respuesta ideal opcional';

  @override
  String get addMemoryOrBoth =>
      'Agrega texto de memoria, o tanto el indicador de entrenamiento como la respuesta ideal.';

  @override
  String get aiTrainingSaved => 'Entrenamiento de IA guardado';

  @override
  String get noAITokensLeft =>
      'No quedan tokens de IA. Mira un anuncio para obtener más tokens o espera la recarga de 6 horas.';

  @override
  String get voiceRecognitionUnavailable =>
      'El reconocimiento de voz no está disponible en este dispositivo';

  @override
  String get noAssistantResponse =>
      'No hay respuesta del asistente disponible para leer en voz alta';

  @override
  String get adNotCompleted =>
      'El anuncio no se completó. Aún no hay recompensa de tokens.';

  @override
  String aiTokensAdded(String tokens, String balance) {
    return '$tokens tokens de IA agregados. Saldo: $balance';
  }

  @override
  String uploadedToMemory(String filename) {
    return '$filename subido a la memoria de IA';
  }

  @override
  String get copiedResponse => 'Respuesta copiada';

  @override
  String get listeningSpeak => 'Escuchando... di tu pregunta';

  @override
  String get askAIAnything => 'Pregunta cualquier cosa a la IA de A-Network...';

  @override
  String get deepResearchEnabled =>
      'Investigación profunda habilitada para los próximos mensajes';

  @override
  String get deepResearchDisabled => 'Investigación profunda deshabilitada';

  @override
  String get uploadTxtTooltip => 'Subir txt/md/pdf para entrenar la IA';

  @override
  String get stopListeningTooltip => 'Dejar de escuchar';

  @override
  String get startVoiceInputTooltip => 'Iniciar entrada de voz';

  @override
  String get stopReadAloudTooltip => 'Dejar de leer en voz alta';

  @override
  String get readLatestResponseTooltip =>
      'Leer la última respuesta en voz alta';

  @override
  String watchAdTokens(String tokens) {
    return 'Ver anuncio + $tokens tokens';
  }

  @override
  String tokenBalance(String balance) {
    return 'Tokens: $balance';
  }

  @override
  String get pickGroupName => 'Elige el nombre de tu grupo';

  @override
  String get claimPermanentUpline => 'Reclamar línea superior permanente';

  @override
  String get claimUplineInstructions =>
      'No se necesita línea superior para mantener tu propia colonia. Ingresa un código Ant aquí solo si quieres unirte permanentemente a la colonia de ese propietario.';

  @override
  String get enterAntCode => 'Ingresa el código Ant';

  @override
  String get claimButton => 'Reclamar';

  @override
  String get antCodeLinked =>
      'Código Ant vinculado. Tu línea superior de colonia ahora es permanente.';

  @override
  String get writeToColony => 'Escribir a tu colonia';

  @override
  String get writeToUplines => 'Escribir a tus líneas superiores de colonia';

  @override
  String get pickGroupNameTooltip => 'Elegir nombre de grupo';

  @override
  String get refreshChatTooltip => 'Actualizar chat';

  @override
  String get tabEcosystem => 'Ecosistema';

  @override
  String get tabAntWork => 'Trabajo Ant';

  @override
  String get tabWallet => 'Billetera';

  @override
  String get tabColony => 'Colonia';

  @override
  String get tabMore => 'Más';

  @override
  String get pageTitleEcosystem => 'Ecosistema Ant';

  @override
  String get pageTitleAntWork => 'Trabajo Ant';

  @override
  String get pageTitleWallet => 'Billetera ANET';

  @override
  String get pageTitleWeb4 => 'Web4';

  @override
  String get pageTitleWhitepaper => 'Libro Blanco';

  @override
  String get pageTitleColony => 'Colonia (Web5)';

  @override
  String get pageTitleMore => 'Más';

  @override
  String get antWorkSectionLabel => 'Trabajo Ant';

  @override
  String get morePageTitle => 'Más';

  @override
  String get morePageSubtitle =>
      'Cuenta, legal, soporte y controles de pantalla en un lugar.';

  @override
  String get walletMenuLabel => 'Billetera';

  @override
  String get walletMenuSubtitle => 'Saldo y herramientas Web3';

  @override
  String get antWorkHeroTitle => 'Trabajo Ant';

  @override
  String get antWorkHeroSubtitle =>
      'Monitorea la sesión en vivo de 6 horas, la producción actual y los hitos de red importantes.';
}
