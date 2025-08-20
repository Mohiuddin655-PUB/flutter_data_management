import 'package:flutter/material.dart';
import 'package:flutter_entity/flutter_entity.dart';
import 'package:in_app_database/in_app_database.dart';

import 'local.dart';
import 'model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InAppDatabase.init(delegate: LocalDatabaseDelegate());
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final crud = FeedRepository.i;

  String feedPath = "test_feeds";
  String userPath = "test_users";
  String feedId = "feed_123";
  String userId = "user_123";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Custom Ref CRUD Demo")),
      bottomNavigationBar: Row(
        children: [
          ElevatedButton(onPressed: _createFeed, child: const Text("Create")),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: _updateFeed, child: const Text("Update")),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _deleteFeed,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
      body: FutureBuilder<Response<Feed>>(
        future: crud.getById(feedId, resolveRefs: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("No feed found"));
          }

          final feed = snapshot.data!.data ?? Feed();
          final publisher = feed.publisher ?? User();
          final photo = feed.photo ?? Photo();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feed.title ?? "No title",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage:
                          photo.url != null ? NetworkImage(photo.url!) : null,
                      radius: 24,
                      child:
                          photo.url == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Text(publisher.name ?? "Unknown publisher"),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Example Create
  Future<void> _createFeed() async {
    await crud.createById(feedId, createRefs: true, {
      "title": "My First Feed",
      "@publisher": {
        "path": "$userPath/$userId",
        "create": {
          "name": "John Doe",
          "joinedAt": DateTime.now().millisecondsSinceEpoch,
        },
      },
      "@photo": {
        "path": "$userPath/$userId/avatars/avatar_456",
        "create": {"url": "https://picsum.photos/200"},
      },
    });
  }

  /// Example Update
  Future<void> _updateFeed() async {
    await crud.updateById(feedId, updateRefs: true, {
      "title":
          "Feed Updated at ${DateTime.now().hour}:${DateTime.now().minute}",
      "@photo": {
        "path": "$userPath/$userId/avatars/avatar_456",
        "update": {
          "url": "https://picsum.photos/500",
          "title": "Updated title",
        },
      },
      "@publisher": {
        "path": "$userPath/$userId",
        "update": {
          "name": "Update Omie",
          "updatedAt": DateTime.now().millisecondsSinceEpoch,
        },
      },
    });
  }

  Future<void> _deleteFeed() async {
    await crud.deleteById(
      feedId,
      deleteRefs: true,
    );
  }
}
