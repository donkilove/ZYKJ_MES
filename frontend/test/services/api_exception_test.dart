import 'package:flutter_test/flutter_test.dart';
import 'package:mes_client/core/network/api_exception.dart';

void main() {
  test('ApiException stores message/statusCode and toString returns message', () {
    final exception = ApiException('failure', 400);

    expect(exception.message, 'failure');
    expect(exception.statusCode, 400);
    expect(exception.toString(), 'failure');
  });

  test('ApiException 将旧版维修中阻塞英文提示归一为中文', () {
    final exception = ApiException(
      'Order has in-progress repair orders that must be completed first: '
      'RW20260512084745635772CDF0',
      409,
    );

    expect(
      exception.message,
      '该订单仍有维修中的维修单，请先完成维修单后再手工完工：'
      'RW20260512084745635772CDF0',
    );
    expect(exception.toString(), exception.message);
  });
}
