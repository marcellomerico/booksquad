import 'dart:async';

import 'package:intl/date_symbol_data_local.dart';

/// Runs before every test file: the app loads German date names in main().
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await initializeDateFormatting('de');
  await testMain();
}
