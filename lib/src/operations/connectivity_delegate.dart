abstract class DataConnectivityDelegate {
  Future<bool> get isConnected;

  Stream<bool> get onChanged;
}
