import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/models/current_user.dart';

void main() {
  test('CurrentUser.fromJson parses all fields and prefers fullName', () {
    final user = CurrentUser.fromJson({
      'id': 11,
      'username': 'operator_a',
      'full_name': '操作员A',
      'role_codes': ['production_admin'],
      'role_names': ['生产管理员'],
      'process_codes': ['01-01'],
      'process_names': ['切割'],
    });

    expect(user.id, 11);
    expect(user.username, 'operator_a');
    expect(user.fullName, '操作员A');
    expect(user.displayName, '操作员A');
    expect(user.roleCodes, ['production_admin']);
    expect(user.processCodes, ['01-01']);
  });

  test('CurrentUser.displayName falls back to username when fullName is blank', () {
    final user = CurrentUser.fromJson({
      'id': 12,
      'username': 'operator_b',
      'full_name': '   ',
      'role_codes': <String>[],
      'role_names': <String>[],
      'process_codes': <String>[],
      'process_names': <String>[],
    });

    expect(user.displayName, 'operator_b');
  });
}
