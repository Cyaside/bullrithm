import 'package:flutter/material.dart';

import 'common/config/app_env.dart';
import 'presentation/app/bullrithm_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnv.loadRuntimeOverrides();
  runApp(const BullrithmApp());
}
