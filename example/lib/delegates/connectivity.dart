import 'package:connectivity_plus/connectivity_plus.dart'
    show Connectivity, ConnectivityResult;
import 'package:data_management/data_management.dart'
    show DataConnectivityDelegate;

class ConnectivityHelper {
  const ConnectivityHelper._();

  static Future<bool> get isConnected {
    return Connectivity().checkConnectivity().then((value) {
      final connected = [
        ConnectivityResult.mobile,
        ConnectivityResult.wifi,
        ConnectivityResult.ethernet,
      ].any((element) => value.contains(element));
      return connected;
    });
  }

  static Future<bool> get isDisconnected async => !(await isConnected);

  static Stream<bool> get changed {
    return Connectivity().onConnectivityChanged.map((event) {
      final status = event.firstOrNull;
      final mobile = status == ConnectivityResult.mobile;
      final wifi = status == ConnectivityResult.wifi;
      final ethernet = status == ConnectivityResult.ethernet;
      return mobile || wifi || ethernet;
    });
  }

  static Future<bool> connected() => isConnected;
}

class ConnectivityDelegate extends DataConnectivityDelegate {
  @override
  Future<bool> get isConnected => ConnectivityHelper.isConnected;

  @override
  Stream<bool> get onChanged => ConnectivityHelper.changed;
}
