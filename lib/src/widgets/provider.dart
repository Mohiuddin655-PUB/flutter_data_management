import 'dart:async';

import 'package:flutter/material.dart';

import '../core/repository.dart';

class DataManagementProvider extends InheritedWidget {
  final List<DataRepository> repositories;
  final Stream<bool> connectivityChanges;

  const DataManagementProvider({
    super.key,
    required this.repositories,
    required this.connectivityChanges,
    required super.child,
  });

  static DataManagementProvider of(BuildContext context) {
    final x =
        context.dependOnInheritedWidgetOfExactType<DataManagementProvider>();
    if (x != null) {
      return x;
    } else {
      throw "You should call like of();";
    }
  }

  static T repositoryOf<T extends DataRepository>(
    BuildContext context,
    String id,
  ) {
    final repository = of(context)
        .repositories
        .whereType<T>()
        .where((e) => e.id == id)
        .firstOrNull;
    if (repository != null) return repository;
    throw UnimplementedError("$T hasn't initialized yet");
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return oldWidget is DataManagementProvider &&
        repositories != oldWidget.repositories;
  }
}
