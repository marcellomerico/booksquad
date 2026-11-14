import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:booksquad/features/discover/presentation/discover_screen.dart';
import 'package:booksquad/features/books/providers/books_provider.dart';
import 'package:booksquad/features/social/providers/social_providers.dart';
import 'package:booksquad/models/profile.dart';
import 'package:booksquad/repositories/follow_repository.dart';
import 'package:booksquad/repositories/moderation_repository.dart';
import 'package:booksquad/repositories/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_groups.dart';

class _FakeProfiles extends ProfileRepository {
  _FakeProfiles() : super(offlineClient());

  @override
  Future<List<Profile>> searchProfiles(
    String query, {
    String? excludeUserId,
    int limit = 20,
  }) async => query == 'nix'
      ? []
      : const [
          Profile(id: 'ok', username: 'lesemaus'),
          Profile(id: 'spam', username: 'spammer'),
        ];
}

class _FakeModeration extends ModerationRepository {
  _FakeModeration() : super(offlineClient());

  @override
  Future<List<String>> getBlockedUserIds(String userId) async => ['spam'];
}

Future<void> _pump(WidgetTester tester, FakeGroups repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(testUser('me')),
        groupRepositoryProvider.overrideWithValue(repo),
        profileRepositoryProvider.overrideWithValue(_FakeProfiles()),
        moderationRepositoryProvider.overrideWithValue(_FakeModeration()),
        discoverPeopleProvider.overrideWith(
          (ref) async => const [Profile(id: 'p1', username: 'buchfink')],
        ),
        followStateProvider.overrideWith((ref, id) async => FollowState.none),
      ],
      child: const MaterialApp(home: Scaffold(body: DiscoverScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('suggests readers and at most three circles, new ones first', (
    tester,
  ) async {
    final repo = FakeGroups([
      testGroup('joined', isMember: true),
      testGroup('a'),
      testGroup('b'),
      testGroup('c'),
    ]);
    await _pump(tester, repo);
    expect(find.text('@buchfink'), findsOneWidget);
    expect(find.text('Folgen'), findsOneWidget);
    expect(find.text('Kreis joined'), findsNothing);
    expect(find.text('Beitreten'), findsNWidgets(3));

    await tester.ensureVisible(find.text('Beitreten').first);
    await tester.tap(find.text('Beitreten').first);
    await tester.pumpAndSettle();
    expect(repo.groups.firstWhere((g) => g.id == 'a').isMember, isTrue);
  });

  testWidgets('search hides blocked readers and reports no hits', (
    tester,
  ) async {
    await _pump(tester, FakeGroups([]));
    await tester.enterText(find.byType(TextField), 'les');
    await tester.tap(find.byTooltip('Suchen'));
    await tester.pumpAndSettle();
    expect(find.text('@lesemaus'), findsOneWidget);
    expect(find.text('@spammer'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nix');
    await tester.tap(find.byTooltip('Suchen'));
    await tester.pumpAndSettle();
    expect(find.text('Keine Treffer gefunden.'), findsOneWidget);
  });
}
