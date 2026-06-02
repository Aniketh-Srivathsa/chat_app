import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void startListening({
    required Function() onDisconnected,
    required Function() onConnected,
  }) {
    _subscription =
        _connectivity.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none)) {
        onDisconnected();
      } else {
        onConnected();
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
