import 'package:booksquad/models/group.dart';
import 'package:booksquad/repositories/group_repository.dart';

import 'auth_fixtures.dart';

BookGroup testGroup(
  String id, {
  String creatorId = 'someone',
  bool isMember = false,
  bool isPrivate = false,
}) => BookGroup(
  id: id,
  creatorId: creatorId,
  name: 'Kreis $id',
  isPrivate: isPrivate,
  createdAt: DateTime.utc(2026),
  memberCount: 3,
  isMember: isMember,
);

/// In-memory circles: join, leave, create and delete change [groups].
class FakeGroups extends GroupRepository {
  FakeGroups(this.groups) : super(offlineClient());
  List<BookGroup> groups;

  @override
  Future<List<BookGroup>> listGroups({
    String? currentUserId,
    String? query,
  }) async =>
      groups.where((g) => query == null || g.name.contains(query)).toList();

  void _setMember(String id, bool member) => groups = [
    for (final g in groups) g.id == id ? g.copyWith(isMember: member) : g,
  ];

  @override
  Future<void> joinGroup({
    required String groupId,
    required String userId,
  }) async => _setMember(groupId, true);

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async => _setMember(groupId, false);

  @override
  Future<BookGroup> createGroup({
    required String creatorId,
    required String name,
    String? description,
    bool isPrivate = false,
  }) async {
    final group = BookGroup(
      id: 'new',
      creatorId: creatorId,
      name: name,
      isPrivate: isPrivate,
      createdAt: DateTime.utc(2026),
      memberCount: 1,
      isMember: true,
    );
    groups = [...groups, group];
    return group;
  }

  @override
  Future<void> deleteGroup(String groupId) async =>
      groups = groups.where((g) => g.id != groupId).toList();
}
