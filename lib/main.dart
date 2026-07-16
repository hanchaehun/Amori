import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // 웹 배포: 호스팅이 닷파일(assets/.env)을 서빙하지 않으면 로드가 실패한다.
    // AppConfig가 릴리스 웹 빌드용 기본 URL로 폴백하므로 그대로 진행.
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AmoriApp());
}
