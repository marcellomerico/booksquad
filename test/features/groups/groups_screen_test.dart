import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:booksquad/features/groups/presentation/groups_screen.dart';
import 'package:booksquad/features/social/providers/social_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_groups.dart';

Future<void> _pump(WidgetTester tester, FakeGroups repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(testUser('me')),
        groupRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: Scaffold(body: GroupsScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('joining and leaving a circle', (tester) async {
    final repo = FakeGroups([testGroup('a', isPrivate: true)]);
    await _pump(tester, repo);
    expect(find.text('3 Mitglieder • Privat'), findsOneWidget);

    await tester.tap(find.text('Beitreten'));
    await tester.pumpAndSettle();
    expect(repo.groups.single.isMember, isTrue);

    await tester.tap(find.text('Verlassen'));
    await tester.pumpAndSettle();
    expect(repo.groups.single.isMember, isFalse);
  });

  testWidgets('creating a circle needs a name', (tester) async {
    final repo = FakeGroups([]);
    await _pump(tester, repo);
    expect(find.text('Noch keine Lesekreise'), findsOneWidget);

    await tester.tap(find.text('Neu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte gib einen Namen ein.'), findsOneWidget);
    expect(repo.groups, isEmpty);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Krimirunde',
    );
    await tester.tap(find.text('Erstellen'));
    await tester.pumpAndSettle();
    expect(repo.groups.single.creatorId, 'me');
    expect(find.text('Krimirunde'), findsOneWidget);
  });

  testWidgets('only the creator can delete, after confirming', (tester) async {
    final repo = FakeGroups([
      testGroup('mine', creatorId: 'me'),
      testGroup('b'),
    ]);
    await _pump(tester, repo);
    expect(find.byTooltip('Lesekreis löschen'), findsOneWidget);

    await tester.tap(find.byTooltip('Lesekreis löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(repo.groups.single.id, 'b');
    expect(find.text('Kreis mine'), findsNothing);
  });

  testWidgets('search without a hit says so', (tester) async {
    await _pump(tester, FakeGroups([testGroup('a')]));
    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pumpAndSettle();
    expect(find.text('Keine Lesekreise gefunden'), findsOneWidget);
  });
}
