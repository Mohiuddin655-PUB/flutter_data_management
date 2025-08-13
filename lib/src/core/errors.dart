abstract class DataException {
  final String? _exp;

  const DataException([this._exp]);

  String get message {
    if (_exp != null) {
      return _exp!;
    } else {
      return "DataProvider not initialization.";
    }
  }

  @override
  String toString() => message;
}

class DataRepositoryException extends DataException {
  const DataRepositoryException([super._exp]);
}

class DataSourceException extends DataException {
  const DataSourceException([super._exp]);
}

class LocalDataSourceException extends DataException {
  const LocalDataSourceException([super._exp]);
}

class RemoteDataSourceException extends DataException {
  const RemoteDataSourceException([super._exp]);
}
