redux_stream

[![Github Actions](https://github.com/eaglesakura/flutter_redux_stream/actions/workflows/flutter-package-test.yaml/badge.svg)](https://github.com/eaglesakura/flutter_redux_stream/actions/workflows/flutter-package-test.yaml)

## Features

[Redux](https://redux.js.org/) をFlutterで実現するためのフレームワーク。

Reduxの処理がFutureではなくStreamで実装されており、Event等の通知に応用することができる.

下記の機能が実装済み

* State Interface
  * Reduxのステートを保持する
  * 常にImmutableとして実装すること
* Action Interface
  * Stateの操作処理を定義する
* Store
  * 現在のStateを保持する
  * Stateの変更はStreamで通知する
* Plugin
  * Store動作をハンドリング/拡張するためのインターフェースを提供する
  * Actionとは異なりState操作は行えないが、Stateの変動を検出したり、追加のリソースを管理したり、任意のタイミング（例えば毎秒1回）でActionを発行する等で使用する

特性上データコピーが頻発するため、低スペック端末に対応する場合は十分に注意して実装すること.

## Usage

TODO.

```dart
```
