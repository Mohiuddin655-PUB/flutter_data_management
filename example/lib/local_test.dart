import 'package:data_management/data_management.dart'
    show
        LocalDataSource,
        RemoteDataSource,
        LocalDataRepository,
        DataQuery,
        DataFetchOptions,
        Checker,
        DataSorting;
import 'package:flutter/material.dart'
    show
        SizedBox,
        Text,
        StatefulWidget,
        State,
        BuildContext,
        Widget,
        EdgeInsets,
        Divider,
        TextStyle,
        NeverScrollableScrollPhysics,
        VoidCallback,
        ThemeData,
        AppBar,
        CrossAxisAlignment,
        FontWeight,
        Wrap,
        Colors,
        Container,
        StreamBuilder,
        ListTile,
        ListView,
        Column,
        SingleChildScrollView,
        SafeArea,
        Scaffold,
        Theme,
        ElevatedButton;
import 'package:flutter_entity/entity.dart' show Entity, EntityKey, Response;

import 'delegates/firestore.dart' show FirestoreDataDelegate;
import 'delegates/local.dart' show LocalDataDelegate;

class NoteKey extends EntityKey {
  final String title = 'title';
  final String body = 'body';
  final String tags = 'tags';
  final String pinned = 'pinned';
  final String color = 'color';

  static NoteKey? _i;

  static NoteKey get i => _i ??= NoteKey();

  @override
  Iterable<String> get keys => [
        id,
        timeMills,
        title,
        body,
        tags,
        pinned,
        color,
      ];
}

class Note extends Entity<NoteKey> {
  final String title;
  final String body;
  final List<String> tags;
  final bool pinned;
  final String color;

  Note({
    required super.id,
    required this.title,
    required this.body,
    required this.tags,
    required this.pinned,
    required this.color,
  }) : super.auto();

  @override
  NoteKey makeKey() => NoteKey();

  factory Note.from(dynamic source) {
    final map = source is Map<String, dynamic> ? source : <String, dynamic>{};
    final key = NoteKey.i;
    return Note(
      id: map[key.id] ?? '',
      title: map[key.title] ?? '',
      body: map[key.body] ?? '',
      tags: List<String>.from(map[key.tags] ?? []),
      pinned: map[key.pinned] ?? false,
      color: map[key.color] ?? '',
    );
  }

  @override
  Map<String, dynamic> get source => {
        key.id: id,
        key.title: title,
        key.body: body,
        key.tags: tags,
        key.pinned: pinned,
        key.color: color,
      };

  Note copyWith({
    String? title,
    String? body,
    List<String>? tags,
    bool? pinned,
    String? color,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      tags: tags ?? this.tags,
      pinned: pinned ?? this.pinned,
      color: color ?? this.color,
    );
  }
}

class NoteLocalSource extends LocalDataSource<Note> {
  NoteLocalSource()
      : super(
          path: 'notes',
          documentId: 'id',
          delegate: LocalDataDelegate.i,
        );

  @override
  Note build(dynamic source) => Note.from(source);
}

class NoteRemoteSource extends RemoteDataSource<Note> {
  NoteRemoteSource()
      : super(
          path: 'notes',
          documentId: 'id',
          delegate: FirestoreDataDelegate.i,
        );

  @override
  Note build(dynamic source) => Note.from(source);
}

class NoteRepository extends LocalDataRepository<Note> {
  NoteRepository()
      : super(source: NoteLocalSource(), backup: NoteRemoteSource());
}

class LocalDataTestPage extends StatefulWidget {
  const LocalDataTestPage({super.key});

  @override
  State<LocalDataTestPage> createState() => _LocalDataTestPageState();
}

class _LocalDataTestPageState extends State<LocalDataTestPage> {
  final _repo = NoteRepository();
  String _log = '';

  String get _id => '1778319785575';

  void _log_(String msg) => setState(() => _log = msg);

  Future<void> _create() async {
    final tagPool = [
      'work',
      'personal',
      'idea',
      'todo',
      'urgent',
      'reminder',
      'draft',
    ];
    final colors = ['yellow', 'blue', 'green', 'pink', 'white'];

    final rnd = DateTime.now().millisecondsSinceEpoch;
    final tags = (tagPool..shuffle()).take(2).toList();
    final color = colors[rnd % colors.length];

    final n = Note(
      id: _id,
      title: 'Note ${rnd % 1000}',
      body: 'This is a sample note body created at $rnd',
      tags: tags,
      pinned: rnd % 2 == 0,
      color: color,
    );
    final res = await _repo.create(n);

    _log_(
      res.isValid
          ? 'Created: ${n.title} | ${n.color} | pinned: ${n.pinned}'
          : 'Error: ${res.error}',
    );
  }

  Future<void> _createRandom() async {
    final titles = [
      'Meeting',
      'Idea',
      'Shopping',
      'Reminder',
      'Quote',
      'Task',
      'Journal',
      'Recipe',
    ];
    final colors = ['yellow', 'blue', 'green', 'pink', 'white'];
    final tagPool = [
      'work',
      'personal',
      'idea',
      'todo',
      'urgent',
      'reminder',
      'draft',
    ];

    final rnd = DateTime.now().millisecondsSinceEpoch;
    final title = titles[rnd % titles.length];
    final color = colors[rnd % colors.length];
    final tags = (tagPool..shuffle()).take(2).toList();

    final n = Note(
      id: rnd.toString(),
      title: '$title ${rnd % 1000}',
      body: 'Body content for $title at $rnd',
      tags: tags,
      pinned: rnd % 2 == 0,
      color: color,
    );
    final res = await _repo.create(n);
    _log_(
      res.isValid
          ? 'Created: ${n.title} | ${n.color} | pinned: ${n.pinned}'
          : 'Error: ${res.error}',
    );
  }

  Future<void> _update() async {
    final r = await _repo.updateById(_id, {NoteKey.i.pinned: true});
    _log_(r.isSuccessful ? 'Updated: $_id' : 'Error: ${r.error}');
  }

  Future<void> _delete(String id) async {
    final r = await _repo.deleteById(id);
    _log_(r.isSuccessful ? 'Deleted: $id' : 'Error: ${r.error}');
  }

  Future<void> _checkById() async {
    final r = await _repo.checkById(_id);
    _log_(r.isSuccessful ? 'Checked' : 'Error: ${r.error}');
  }

  Future<void> _deleteByIds() async {
    final r = await _repo.deleteByIds([_id]);
    _log_(r.isSuccessful ? 'Deleted' : 'Error: ${r.error}');
  }

  Future<void> _deleteAll() async {
    final r = await _repo.clear();
    _log_(r.isSuccessful ? 'Cleared' : 'Error: ${r.error}');
  }

  Future<void> _get() async {
    final res = await _repo.get(backupMode: true);
    _log_(
      res.isValid ? 'Got ${res.result.length} items' : 'Error: ${res.error}',
    );
  }

  Future<void> _getById() async {
    final r = await _repo.getById(_id);
    _log_(
      r.isValid ? 'Got: ${r.result.firstOrNull?.title}' : 'Error: ${r.error}',
    );
  }

  Future<void> _getByIds() async {
    final r = await _repo.getByIds([_id, _id]);
    _log_(r.isValid ? 'Got ${r.result.length} items' : 'Error: ${r.error}');
  }

  Future<void> _query() async {
    final res = await _repo.getByQuery(
      queries: [DataQuery(NoteKey.i.color, isEqualTo: 'yellow')],
      options: const DataFetchOptions.limit(10),
    );
    _log_(
      res.isValid ? 'Query: ${res.result.length} items' : 'Error: ${res.error}',
    );
  }

  Future<void> _search() async {
    final res = await _repo.search(Checker.contains(NoteKey.i.title, 'Note'));
    _log_(
      res.isValid
          ? 'Search: ${res.result.length} items: ${res.result.map((e) => e.title).join(', ')}'
          : 'Error: ${res.error}',
    );
  }

  Future<void> _count() async {
    final res = await _repo.count();
    _log_('Count: ${res.result.firstOrNull}');
  }

  @override
  void initState() {
    _repo.restore();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Local Data Test')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Operations',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _btn('Create', _create),
                    _btn('CreateRandom', _createRandom),
                    _btn('Check By Id', _checkById),
                    _btn('Update (first)', _update),
                    _btn('Get All', _get),
                    _btn('Get By Id', _getById),
                    _btn('Get By Ids', _getByIds),
                    _btn('Query', _query),
                    _btn('Search', _search),
                    _btn('Count', _count),
                    _btn('Delete By Ids', _deleteByIds),
                    _btn('Clear', _deleteAll),
                  ],
                ),
                const Divider(),
                if (_log.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    color: Colors.black12,
                    child: Text(_log, style: const TextStyle(fontSize: 12)),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Listen Count',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                StreamBuilder<Response<int>>(
                  stream: _repo.listenCount(),
                  builder: (context, s) {
                    final count = s.data?.result.firstOrNull ?? 0;
                    return Text('Total notes: $count');
                  },
                ),
                const Divider(),
                const Text(
                  'Listen By Id',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                StreamBuilder<Response<Note>>(
                  stream: _repo.listenById(_id),
                  builder: (context, s) {
                    final item = s.data?.result.firstOrNull;
                    if (s.data?.isLoading == true) {
                      return const Text('Loading...');
                    }
                    if (item == null) return const Text('No data');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.title),
                      subtitle: Text('${item.body} | pinned: ${item.pinned}'),
                      trailing: Text(item.color),
                    );
                  },
                ),
                const Divider(),
                const Text(
                  'Listen By Ids',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                StreamBuilder<Response<Note>>(
                  stream: _repo.listenByIds([_id]),
                  builder: (context, s) {
                    final item = s.data?.result.firstOrNull;
                    if (s.data?.isLoading == true) {
                      return const Text('Loading...');
                    }
                    if (item == null) return const Text('No data');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.title),
                      subtitle: Text('${item.body} | pinned: ${item.pinned}'),
                      trailing: Text(item.color),
                    );
                  },
                ),
                const Divider(),
                const Text(
                  'Listen',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                StreamBuilder<Response<Note>>(
                  stream: _repo.listen(),
                  builder: (context, s) {
                    final items = s.data?.result ?? [];
                    if (items.isEmpty) return const Text('No data');
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.take(2).length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return ListTile(
                          onLongPress: () => _delete(item.id),
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.title),
                          subtitle: Text(
                            '${item.color} | ${item.tags.join(", ")}',
                          ),
                          trailing: Text('Pinned: ${item.pinned}'),
                        );
                      },
                    );
                  },
                ),
                const Divider(),
                const Text(
                  'Listen By Query',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                StreamBuilder<Response<Note>>(
                  stream: _repo.listenByQuery(
                    queries: [DataQuery(NoteKey.i.pinned, isEqualTo: true)],
                    sorts: [DataSorting(NoteKey.i.timeMills)],
                  ),
                  builder: (context, s) {
                    final items = s.data?.result ?? [];
                    if (items.isEmpty) return const Text('No data');
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.take(2).length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return ListTile(
                          onLongPress: () => _delete(item.id),
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.title),
                          subtitle: Text(
                            '${item.color} | ${item.tags.join(", ")}',
                          ),
                          trailing: Text('Pinned: ${item.pinned}'),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) {
    return ElevatedButton(onPressed: onTap, child: Text(label));
  }
}
