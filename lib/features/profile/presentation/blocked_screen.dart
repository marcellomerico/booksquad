import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/booksquad_ui.dart';
import '../../../core/widgets/snack.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';

final blockedUserIdsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.watch(moderationRepositoryProvider).getBlockedUserIds(user.id);
});

/// Settings → Blockierte Konten: everyone you blocked, with "Entsperren".
class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  Future<void> _unblock(BuildContext context, WidgetRef ref, String id) async {
    final me = ref.read(currentUserProvider);
    if (me == null) return;
    try {
      await ref
          .read(moderationRepositoryProvider)
          .unblockUser(blockerId: me.id, blockedId: id);
      ref
        ..invalidate(blockedUserIdsProvider)
        ..invalidate(isBlockedProvider(id));
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(blockedUserIdsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Blockierte Konten')),
      body: ids.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => ErrorState(
          message: 'Liste konnte nicht geladen werden.',
          onRetry: () => ref.invalidate(blockedUserIdsProvider),
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.block,
                title: 'Niemand blockiert',
                message:
                    'Wen du blockierst, der sieht deine Inhalte nicht mehr und kann dir nicht schreiben.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final p = ref.watch(profileByIdProvider(list[i])).valueOrNull;
                  final name = p?.displayName ?? p?.username ?? '…';
                  return ListCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(url: p?.avatarUrl, name: name),
                      title: Text(name),
                      subtitle: p == null ? null : Text('@${p.username}'),
                      trailing: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 40),
                        ),
                        onPressed: () => _unblock(context, ref, list[i]),
                        child: const Text('Entsperren'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
