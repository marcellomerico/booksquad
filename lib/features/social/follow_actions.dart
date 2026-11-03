import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/follow_repository.dart';
import '../auth/providers/auth_provider.dart';
import '../books/providers/books_provider.dart';
import '../messages/providers/messages_providers.dart';
import 'providers/paged_posts.dart';
import 'providers/social_providers.dart';

/// Follows [targetId] (or asks, for a private account) when [state] is none,
/// otherwise unfollows or withdraws the request; then refreshes everything
/// that depends on the relation.
Future<void> toggleFollow(
  WidgetRef ref,
  String targetId,
  FollowState state,
) async {
  final me = ref.read(currentUserProvider);
  if (me == null) return;
  final repo = ref.read(followRepositoryProvider);
  if (state == FollowState.none) {
    await repo.follow(followerId: me.id, followingId: targetId);
  } else {
    await repo.unfollow(followerId: me.id, followingId: targetId);
  }
  ref
    ..invalidate(followStateProvider(targetId))
    ..invalidate(canMessageProvider(targetId))
    ..invalidate(bookshelfByUserProvider(targetId))
    ..invalidate(profileStatsProvider(targetId))
    ..invalidate(discoverPeopleProvider)
    ..invalidate(pagedPostsProvider)
    ..invalidate(activityProvider);
}
