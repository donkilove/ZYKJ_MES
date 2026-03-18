import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/current_user.dart';

void main() {
  test('CurrentUser.fromJson parses all fields and prefers fullName', () {
    final user = CurrentUser.fromJson({
      'id': 11,
      'username': 'operator_a',
      'full_name': '操作员A',
      'role_code': 'production_admin',
      'role_name': '生产管理员',
      'stage_id': 1,
      'stage_name': '切割段',
    });

    expect(user.id, 11);
      expect(user.username, 'operator_a');
      expect(user.fullName, '操作员A');
      expect(user.displayName, '操作员A');
      expect(user.roleCode, 'production_admin');
      expect(user.roleName, '生产管理员');
      expect(user.stageId, 1);
      expect(user.stageName, '切割段');
  });

  test('CurrentUser.displayName falls back to username when fullName is blank', () {
    final user = CurrentUser.fromJson({
      'id': 12,
      'username': 'operator_b',
      'full_name': '   ',
    });

    expect(user.displayName, 'operator_b');
  });
}
