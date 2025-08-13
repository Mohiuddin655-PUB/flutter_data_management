import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_entity/entity.dart';

import '../core/repository.dart';
import 'provider.dart';

mixin DataManagementMixin<T extends Entity, S extends StatefulWidget>
    on State<S> {
  String get repositoryId;

  DataRepository<T>? _instance;

  DataRepository<T> get repository {
    return _instance ??= DataManagementProvider.repositoryOf(
      context,
      repositoryId,
    );
  }

  StreamSubscription? _subscription;

  void _init() {
    _subscription?.cancel();
    _subscription = DataManagementProvider.of(context)
        .connectivityChanges
        .listen((connected) {
      if (!connected) return;
      repository.restore();
    });
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
