import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:booksquad/features/profile/presentation/blocked_screen.dart';
import 'package:booksquad/features/social/providers/social_providers.dart';
import 'package:booksquad/models/profile.dart';
import 'package:booksquad/repositories/moderation_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fixtures.dart';

class _FakeModeration extends ModerationRepository {
  _FakeModeration() : super(offlineClient());
  final blocked = {'spam'};

  @override
  Future<List<String>> getBlockedUserIds(String userId) async =>
      blocked.toList();

  @override
  Future<void> unblockUser({
    required String blockerId,
    required String blockedId,
  }) async => blocked.remove(blockedId);
}

void main() {
  testWidgets('blocked accounts can be unblocked', (tester) async {
    final repo = _FakeModeration();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserProvider.overrideWithValue(testUser('me')),
          moderationRepositoryProvider.overrideWithValue(repo),
          profileByIdProvider.overrideWith(
            (ref, id) async => Profile(id: id, username: 'spammer'),
          ),
        ],
        child: const MaterialApp(home: BlockedScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('@spammer'), findsOneWidget);

    await tester.tap(find.text('Entsperren'));
    await tester.pumpAndSettle();
    expect(repo.blocked, isEmpty);
    expect(find.text('Niemand blockiert'), findsOneWidget);
  });
}
