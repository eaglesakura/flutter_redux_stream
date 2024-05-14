## 1.0.0+1

* Del: リポジトリ移動に伴い、試験的に用意されていたPlugin系を削除
* Del: Provider依存処理を削除
* Add: Actionオブジェクトを伴わずに直接更新を行うメソッドを追加

## 0.4.1+1

* Fix: dispatchAndResult()の待ち合わせ中にクラッシュする場合がある問題を修正
* Chg: 実行時のステートチェック方法を変更

## 0.4.1

* Add: ReduxStoreのdisposeチェックプロパティを追加

## 0.3.0

* Flutter 3.0.0対応
* ReduxStateの比較処理が重い場合は警告を出力

## 0.2.2

* ReduxStore.stateStream(データ通知)とReduxStore.renderStream(レンダリング制御通知)を分離
  * これにより更新がスパイクしてもRebuildが肥大化しないようになった

## 0.2.1

* ReduxStore.stateStream()の通知が最小になるように最適化
* ReduxStore.stateStreamをStreamを返却するように調整

## 0.2.0+3

* Mod Loggingに簡易タグを追加

## 0.2.0+2

* Fix MultiSourceBufferPlugin.
* Rename
    * ReduxAction.delegate() => ReduxAction.interrupt()


## 0.2.0+1

* Fix analyzer.

## 0.2.0

* Beta Release.
