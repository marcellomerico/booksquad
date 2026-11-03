import 'package:flutter/material.dart';

import '../../features/auth/providers/auth_provider.dart';

/// Shows [error] as a readable German message (network, rate limit, auth …).
void showErrorSnack(BuildContext context, Object error) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
