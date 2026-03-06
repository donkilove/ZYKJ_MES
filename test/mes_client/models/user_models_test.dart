import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/user_models.dart';

void main() {
  group('UserItem', () {
    test('fromJson parses optional fields', () {
      final item = UserItem.fromJson({
        'id': 1,
        'username': 'admin',
        'full_name': '管理员',
        'is_online': true,
        'last_seen_at': '2026-03-01T10:00:00Z',
        'role_codes': ['system_admin'],
        'role_names': ['系统管理员'],
        'process_codes': ['01-01'],
        'process_names': ['切割'],
        'stage_names': ['切割段'],
      });

      expect(item.id, 1);
      expect(item.username, 'admin');
      expect(item.fullName, '管理员');
      expect(item.isOnline, isTrue);
      expect(item.lastSeenAt, DateTime.parse('2026-03-01T10:00:00Z'));
      expect(item.stageNames, ['切割段']);
    });

    test('fromJson uses defaults when optional fields are missing', () {
      final item = UserItem.fromJson({
        'id': 2,
        'username': 'worker',
        'full_name': null,
        'role_codes': <String>[],
        'role_names': <String>[],
        'process_codes': <String>[],
        'process_names': <String>[],
      });

      expect(item.isOnline, isFalse);
      expect(item.lastSeenAt, isNull);
      expect(item.stageNames, isEmpty);
    });
  });

  test('RoleItem and ProcessItem parse values', () {
    final role = RoleItem.fromJson({'id': 3, 'code': 'qa', 'name': '质检员'});
    final process = ProcessItem.fromJson({
      'id': 9,
      'code': '01-01',
      'name': '切割',
      'stage_id': 5,
      'stage_code': '01',
      'stage_name': '切割段',
    });

    expect(role.code, 'qa');
    expect(process.stageId, 5);
    expect(process.stageCode, '01');
  });

  test('list result wrappers keep total/items', () {
    final users = UserListResult(total: 2, items: <UserItem>[]);
    final roles = RoleListResult(total: 1, items: <RoleItem>[]);
    final processes = ProcessListResult(total: 4, items: <ProcessItem>[]);

    expect(users.total, 2);
    expect(roles.total, 1);
    expect(processes.total, 4);
  });

  test('Registration request models parse and wrap', () {
    final item = RegistrationRequestItem.fromJson({
      'id': 100,
      'account': 'new_user',
      'created_at': '2026-03-02T08:00:00Z',
    });
    final list = RegistrationRequestListResult(total: 1, items: [item]);

    expect(item.account, 'new_user');
    expect(item.createdAt, DateTime.parse('2026-03-02T08:00:00Z'));
    expect(list.items.single.id, 100);
  });
}
