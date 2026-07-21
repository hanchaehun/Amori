import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/amori_snackbar.dart';

class AmoriApp extends StatelessWidget {
  const AmoriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'amori',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AmoriSnackbar.messengerKey,
      theme: AppTheme.light,
      // OS 글꼴 확대가 과하면 고정 높이 버튼·탭바에서 텍스트가 넘친다 —
      // 접근성은 지키되 레이아웃이 깨지지 않게 1.0~1.3 범위로 제한한다.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.3,
            ),
          ),
          child: child!,
        );
      },
      routerConfig: AppRouter.router,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
