import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showSnackbar(String title, String message, {bool isError = false}) {
  final context = scaffoldMessengerKey.currentContext;
  final Color bg = isError 
      ? const Color(0xFFFF5C5C) 
      : (context != null ? Theme.of(context).colorScheme.primary : const Color(0xFFCBFF47));
  
  final useWhiteText = isError || (context == null 
      ? false 
      : ThemeData.estimateBrightnessForColor(bg) == Brightness.dark);
  final textColor = useWhiteText ? Colors.white : const Color(0xFF0A0A0F);

  scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(
        '$title: $message',
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
      backgroundColor: bg,
      duration: const Duration(seconds: 3),
    ),
  );
}

class Rx<T> extends ChangeNotifier implements ValueListenable<T> {
  T _value;
  Rx(this._value);

  @override
  T get value => _value;
  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  @override
  String toString() => _value.toString();
}

typedef RxInt = Rx<int>;
typedef RxDouble = Rx<double>;
typedef RxBool = Rx<bool>;
typedef RxString = Rx<String>;

extension RxExtension<T> on T {
  Rx<T> get obs => Rx<T>(this);
}

class RxList<T> extends ListMixin<T> with ChangeNotifier {
  final List<T> _list;
  RxList(this._list);

  @override
  int get length => _list.length;
  @override
  set length(int newLength) {
    _list.length = newLength;
    notifyListeners();
  }

  @override
  T operator [](int index) => _list[index];
  @override
  void operator []=(int index, T value) {
    _list[index] = value;
    notifyListeners();
  }

  @override
  void add(T element) {
    _list.add(element);
    notifyListeners();
  }

  @override
  void addAll(Iterable<T> iterable) {
    _list.addAll(iterable);
    notifyListeners();
  }

  @override
  bool remove(Object? element) {
    final result = _list.remove(element);
    if (result) notifyListeners();
    return result;
  }

  @override
  T removeAt(int index) {
    final result = _list.removeAt(index);
    notifyListeners();
    return result;
  }

  @override
  void clear() {
    _list.clear();
    notifyListeners();
  }

  void assignAll(Iterable<T> iterable) {
    _list.clear();
    _list.addAll(iterable);
    notifyListeners();
  }
}

extension RxListExtension<T> on List<T> {
  RxList<T> get obs => RxList<T>(this);
}

class RxMap<K, V> extends MapMixin<K, V> with ChangeNotifier {
  final Map<K, V> _map;
  RxMap(this._map);

  @override
  V? operator [](Object? key) => _map[key];
  @override
  void operator []=(K key, V value) {
    _map[key] = value;
    notifyListeners();
  }

  @override
  void clear() {
    _map.clear();
    notifyListeners();
  }

  @override
  Iterable<K> get keys => _map.keys;

  @override
  V? remove(Object? key) {
    final result = _map.remove(key);
    notifyListeners();
    return result;
  }

  void assignAll(Map<K, V> other) {
    _map.clear();
    _map.addAll(other);
    notifyListeners();
  }
}

extension RxMapExtension<K, V> on Map<K, V> {
  RxMap<K, V> get obs => RxMap<K, V>(this);
}
