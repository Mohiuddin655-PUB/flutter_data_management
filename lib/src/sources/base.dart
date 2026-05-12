import 'dart:async' show StreamTransformer;

import 'package:async/async.dart' show StreamGroup;
import 'package:flutter_entity/entity.dart' show Entity, Response, Status;

import '../encryptor/encryptor.dart' show DataEncryptor;
import '../operations/base.dart' show DataOperation;
import '../operations/delegate.dart' show DataDelegate;
import '../operations/typedefs.dart' show Ignore;
import '../operations/writers.dart' show DataBatchWriter;
import '../utils/checker.dart' show Checker;
import '../utils/extensions.dart' show DataMapHelper;
import '../utils/fetch_options.dart' show DataFetchOptions;
import '../utils/field_path.dart' show DataFieldPath;
import '../utils/limitations.dart' show DataLimitations;
import '../utils/modifiers.dart' show DataModifiers;
import '../utils/params.dart' show DataFieldParams, DataFieldParamsHelper;
import '../utils/query.dart' show DataQuery;
import '../utils/selection.dart' show DataSelection;
import '../utils/sorting.dart' show DataSorting;
import '../utils/updating_info.dart' show DataWriter;

part '_source_encryption_mixin.dart';
part '_source_execute_mixin.dart';
part '_source_field_mixin.dart';
part '_source_listen_mixin.dart';
part '_source_path_mixin.dart';
part '_source_read_base_mixin.dart';
part '_source_read_mixin.dart';
part '_source_write_mixin.dart';

abstract class DataSource<T extends Entity>
    with
        _SourceExecuteMixin<T>,
        _SourceEncryptionMixin<T>,
        _SourceFieldMixin,
        _SourcePathMixin<T>,
        _SourceReadBaseMixin<T>,
        _SourceReadMixin<T>,
        _SourceWriteMixin<T>,
        _SourceListenMixin<T> {
  @override
  final String path;

  @override
  final String documentId;

  @override
  final DataDelegate delegate;

  @override
  final DataLimitations limitations;

  @override
  final DataEncryptor? _encryptor;

  late final DataOperation _operation = DataOperation(delegate);

  @override
  DataOperation get operation => _operation;

  DataSource({
    required this.path,
    required this.documentId,
    required this.delegate,
    DataEncryptor? encryptor,
    this.limitations = const DataLimitations(),
  }) : _encryptor = encryptor;

  @override
  T build(dynamic source);
}
