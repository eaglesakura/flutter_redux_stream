import 'dart:async';
import 'dart:developer' as developer;

import 'package:async_notify/async_notify.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import 'internal/logger.dart';
import 'redux_plugin.dart';

part 'dispatcher.dart';
part 'redux_action.dart';
part 'redux_state.dart';
part 'redux_state_notify.dart';

/// 通知前の判定カスタマイズ関数.
/// before/afterをチェックし、falseを返した場合は変更を行わない.
typedef ReduxStateEquals<TState extends ReduxState> = bool Function(
    TState before, TState after);

/// Redux PatternにおけるStoreを定義する.
/// Storeは現在のステートと処理主体であるReducerを持つ.
///
/// Storeは配下に持つReducer等のライフサイクルも管理する.
/// Store.dispose()されたタイミングでLifecycle.onDestroy()が実行され、
/// 非同期処理等が逐次キャンセルされる.
class ReduxStore<TState extends ReduxState> {
  final _notifier = Notify();

  final BehaviorSubject<TState> _state;

  final _subscription = CompositeSubscription();

  final PublishSubject<ReduxStateNotify<TState>> _notifyEvent =
      PublishSubject();

  late Dispatcher<TState> _dispatcher;

  final List<ReduxPlugin<TState>> _pluginList = [];

  /// State解放関数
  final ReduxStateDispose<TState>? _stateDispose;

  /// 通知番号
  /// Initialを除き、データが更新されるタイミングで発行される.
  var _notifyNumber = 0;

  /// 破棄済みチェックフラグ
  var _disposed = false;

  final ReduxStateEquals<TState> _equals;

  /// 指定された初期値でReduxStoreを生成する.
  /// Stateの解放処理を明示的に記述したい場合、 [stateDispose] を設定する.
  ReduxStore({
    required TState initial,
    ReduxStateDispose<TState>? stateDispose,
    ReduxStateEquals<TState>? equals,
  })  : _stateDispose = stateDispose,
        _state = BehaviorSubject.seeded(initial),
        _equals = equals ?? _basicEquals {
    _dispatcher = Dispatcher(_notifier);
    _dispatcher._start(this);
  }

  /// このStoreが破棄済みであるかどうかを取得する.
  /// trueを返却するとき、もうActionを行うことはできない.
  ///
  /// ただし、破棄済みであっても完全に処理が終了していない場合がある.
  bool get isDisposed => _disposed;

  /// このStoreが有効である場合にtrueを返却する.
  bool get isNotDisposed => !isDisposed;

  /// 更新タイミングで付加情報を取得する.
  ///
  /// 更新回数や実行されたAction等も取得できる.
  /// この値はEventとして動作するため、Storeに保持されない.
  Stream<ReduxStateNotify<TState>> get notifyEvent => _notifyEvent;

  /// 現在のStateを取得する.
  TState get state => _state.value;

  /// StateをStreamとして取得する.
  Stream<TState> get stateStream => _state.where((event) => isNotDisposed);

  /// Action実行をリクエストする.
  ///
  /// この処理はFire & Forgetのため、終了を待ち合わせることはできない.
  void dispatch(ReduxAction<TState> action) {
    assert(isNotDisposed, 'ReduxStore<$TState> is disposed');

    action._store = this;
    for (final element in _pluginList) {
      element.onDispatch(this, action, state);
    }
    _dispatcher.dispatch(action);
    _notifier.notify();
  }

  /// Action実行をリクエストし、終了待ちのFuture<TState>を返却する.
  ///
  /// MEMO:
  /// async funcにすると実行タイミングにズレが生じるため、
  /// 即時実行 + 非同期関数として動作する.
  Future<TState> dispatchAndResult(ReduxAction<TState> action) {
    assert(isNotDisposed, 'ReduxStore<$TState> is disposed');

    final task = notifyEvent
        .where((event) => identical(event.action, action) && event.done)
        .map((event) => event.newState)
        .first;
    dispatch(action);
    return task;
  }

  /// Storeの終了処理を行う
  ///
  /// NOTE.
  /// Task実行中のState不全を避けるため、Disposeは非同期で行われる.
  /// 最低限、現在 [dispatch] に積まれている処理は全て処理され、
  /// その後終了処理が実行される.
  @mustCallSuper
  Future dispose() async {
    assert(isNotDisposed, 'ReduxStore<$TState> is disposed');

    dispatch(_FinalizeAction());
    _disposed = true;
    try {
      while (!_notifier.isClosed) {
        await _notifier.wait();
      }
    } on CancellationException catch (_) {
      // Notifierが閉じるのを待つ.
    }
    assert(_notifier.isClosed, '!Notifier.isClosed');

    final latestState = state;
    _pluginList
      ..forEach((element) {
        element
          ..onUnregistered(this)
          ..dispose();
      })
      ..clear();
    await _notifyEvent.close();
    await _dispatcher.dispose();
    await _subscription.dispose();
    await _state.close();

    if (_stateDispose != null) {
      // カスタムDisposeに解放処理を行わせる
      await _stateDispose!(latestState);
    }
  }

  /// 実行待ち、もしくは実行中のActionがあればtrueを返却する.
  bool hasActions() => _dispatcher.hasActions();

  bool hasPendingActions() => _dispatcher.hasPendingActions();

  /// 指定Pluginを取得する.
  /// 指定型のPluginが見つからない場合、このメソッドは例外を投げる.
  TPlugin plugin<TPlugin>() {
    final itr = _pluginList.whereType<TPlugin>();
    assert(itr.isNotEmpty, 'Invalid Plugin<$TPlugin>');
    return itr.first;
  }

  /// 指定Pluginを取得する.
  /// 指定型のPluginが見つからない場合、このメソッドは例外を投げる.
  TPlugin? pluginOrNull<TPlugin>() {
    final itr = _pluginList.whereType<TPlugin>();
    if (itr.isEmpty) {
      return null;
    }
    return itr.first;
  }

  /// PluginをStoreへ登録する.
  void registerPlugin(ReduxPlugin<TState> plugin) {
    assert(!_pluginList.contains(plugin), 'plugin is registered');

    _pluginList.add(plugin);
    plugin.onRegistered(this);
  }

  /// 指定型と条件に一致するPluginを検索する
  TPlugin wherePlugin<TPlugin>(
      bool Function(ReduxPlugin<TState> element) test) {
    final itr = _pluginList.where(test).whereType<TPlugin>();
    assert(itr.isNotEmpty, 'Invalid Plugin<$TPlugin>');
    return itr.first;
  }

  /// 新しいデータをStoreに反映させる
  void _notify(ReduxAction<TState> action, int number, TState rawNewState) {
    if (_notifier.isClosed) {
      // closeされているので何もしない
      return;
    }
    final oldState = state;

    // Hookに値の正規化を行わせる.
    var newState = rawNewState;

    // 正規化済みの値を書き込む.
    // NOTE. このとき、値が変動しなければ通知を行わない.
    if (!_equals(_state.value, newState)) {
      _state.value = newState;
    }
    _notifyEvent.add(ReduxStateNotify._init(
      _notifyNumber,
      action,
      number,
      oldState,
      newState,
    ));
    _notifyNumber++;
    for (final element in _pluginList) {
      element.onStateChanged(
        this,
        action,
        oldState,
        newState,
      );
    }
    _notifier.notify(); // 通知待ちオブジェクトに処理を継続させる.
  }

  static bool _basicEquals<TState>(TState before, TState after) {
    if (kReleaseMode) {
      // デバッグビルドの場合、前後比較にかかる時間をチェックし、
      // 異常な時間が発生している場合は警告を出す
      final watch = Stopwatch()..start();
      try {
        return before == after;
      } finally {
        watch.stop();
        if (watch.elapsedMilliseconds > 0) {
          logInfo(
              '[WARNING] <$TState>.equals() is slow: ${watch.elapsedMilliseconds} ms');
        }
      }
    } else {
      return before == after;
    }
  }
}

class _FinalizeAction<TState extends ReduxState> extends ReduxAction<TState> {
  @override
  Stream<TState> execute(TState state) async* {
    await store._notifier.dispose();
  }
}
