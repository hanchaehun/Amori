class AppRoutes {
  AppRoutes._();

  // Phase 1
  static const String splash = '/';
  static const String walkthrough = '/walkthrough';
  static const String signup = '/signup';
  static const String kycBlock = '/kyc-block';
  static const String personaIntro = '/persona/intro';
  static const String scenarioPlayer = '/persona/scenario';
  static const String dataImport = '/persona/import';
  static const String personaLoading = '/persona/loading';
  static const String home = '/home';
  static const String agentChat = '/home/agent-chat';

  // Phase 2
  static const String matchList = '/match';
  static const String lockedReport = '/match/locked';
  static const String paywall = '/paywall';
  static const String fullReport = '/match/report';

  // Phase 3
  static const String meetRequestSend = '/meet/send';
  static const String quotaExceeded = '/meet/quota';
  static const String requestStatus = '/meet/status';
  static const String requestDeclined = '/meet/declined';
  static const String requestTimeout = '/meet/timeout';
  static const String meetRequestReceive = '/meet/receive';
  static const String inbox = '/inbox';
  static const String chat = '/chat';
  static const String scheduling = '/scheduling';
  static const String feedback = '/feedback';

  // Phase 4
  static const String freeLockReport = '/free/locked';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String notificationSettings = '/settings/notifications';
  static const String pushPreview = '/push';

  // Login (placeholder)
  static const String login = '/login';
}
