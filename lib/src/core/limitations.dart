final class DataLimitations {
  final int whereIn;
  final int batchLimit;
  final int? maximumDeleteLimit;

  const DataLimitations({
    this.whereIn = 10,
    this.batchLimit = 500,
    this.maximumDeleteLimit,
  });
}
