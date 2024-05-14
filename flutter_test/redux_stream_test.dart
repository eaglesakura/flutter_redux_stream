import 'package:flutter_test/flutter_test.dart';
import 'package:redux_stream2/redux_stream2.dart';

void main() {
  test('new/dispose', () async {
    final store = ReduxStore(initial: _TestState(0));
    await store.dispose();
  });
}

class _TestState implements ReduxState {
  final int value;

  _TestState(this.value);
}
