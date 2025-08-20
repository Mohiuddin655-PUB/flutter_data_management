import 'package:data_management/core.dart';
import 'package:flutter_entity/entity.dart';

import 'local.dart';
import 'remote.dart';

class Photo extends Entity {
  final String? path;
  final String? url;

  const Photo({super.id, super.timeMills, this.path, this.url});

  factory Photo.from(Object? source) {
    if (source is! Map) return Photo();
    return Photo(
      id: source["id"],
      timeMills: source["timeMills"],
      path: source["path"],
      url: source["url"],
    );
  }

  @override
  bool isInsertable(String key, value) => value != null;

  @override
  Map<String, dynamic> get source {
    return super.source..addAll({"path": path, "url": url});
  }
}

class User extends Entity {
  final String? path;
  final String? name;

  const User({super.id, super.timeMills, this.path, this.name});

  factory User.from(Object? source) {
    if (source is! Map) return User();
    return User(
      id: source["id"],
      timeMills: source["timeMills"],
      path: source["path"],
      name: source["name"],
    );
  }

  @override
  bool isInsertable(String key, value) => value != null;

  @override
  Map<String, dynamic> get source {
    return super.source..addAll({"path": path, "url": name});
  }
}

class Feed extends Entity {
  final String? title;
  final User? publisher;
  final Photo? photo;

  const Feed({
    super.id,
    super.timeMills,
    this.title,
    this.publisher,
    this.photo,
  });

  factory Feed.from(Object? source) {
    if (source is! Map) return Feed();
    return Feed(
      id: source["id"],
      timeMills: source["timeMills"],
      title: source["title"],
      publisher: User.from(source["publisher"]),
      photo: Photo.from(source["photo"]),
    );
  }

  @override
  bool isInsertable(String key, value) => value != null;

  @override
  Map<String, dynamic> get source {
    return super.source
      ..addAll(
        {
          "title": title,
          "@publisher": publisher?.path,
          "@photo": photo?.path,
        },
      );
  }
}

class RemoteFeedDataSource extends RemoteDataSource<Feed> {
  RemoteFeedDataSource()
      : super(
          path: "users",
          delegate: FirestoreDataDelegate(),
          limitations: DataLimitations(whereIn: 10),
        );

  @override
  Feed build(source) => Feed.from(source);
}

class LocalFeedDataSource extends LocalDataSource<Feed> {
  LocalFeedDataSource()
      : super(
          path: "users",
          delegate: LocalDataDelegate(),
          limitations: DataLimitations(whereIn: 10),
        );

  @override
  Feed build(source) => Feed.from(source);
}

class FeedRepository extends RemoteDataRepository<Feed> {
  static FeedRepository? _i;

  static FeedRepository get i => _i ??= FeedRepository._();

  FeedRepository._()
      : super(source: RemoteFeedDataSource(), backup: LocalFeedDataSource());
}
