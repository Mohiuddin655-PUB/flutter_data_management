import 'package:data_management/data_management.dart'
    show
        LocalDataSource,
        RemoteDataSource,
        RemoteDataRepository,
        DataQuery,
        DataFetchOptions,
        Checker,
        DataSorting;
import 'package:flutter/material.dart'
    show
        StatefulWidget,
        State,
        BuildContext,
        Widget,
        Text,
        EdgeInsets,
        SizedBox,
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
import 'package:flutter_entity/entity.dart' show EntityKey, Entity, Response;

import 'delegates/firestore.dart' show FirestoreDataDelegate;
import 'delegates/local.dart' show LocalDataDelegate;

class ProductKey extends EntityKey {
  static const id_ = 'id';
  static const name = 'name';
  static const price = 'price';
  static const category = 'category';
  static const tags = 'tags';
  static const stock = 'stock';

  @override
  Iterable<String> get keys => [
        id_,
        timeMills,
        name,
        price,
        category,
        tags,
        stock,
      ];
}

class Product extends Entity<ProductKey> {
  final String name;
  final double price;
  final String category;
  final List<String> tags;
  final int stock;

  Product({
    required super.id,
    required this.name,
    required this.price,
    required this.category,
    required this.tags,
    required this.stock,
  }) : super.auto();

  @override
  ProductKey makeKey() => ProductKey();

  factory Product.from(dynamic source) {
    final map = source is Map<String, dynamic> ? source : <String, dynamic>{};
    return Product(
      id: map[ProductKey.id_] ?? '',
      name: map[ProductKey.name] ?? '',
      price: (map[ProductKey.price] ?? 0).toDouble(),
      category: map[ProductKey.category] ?? '',
      tags: List<String>.from(map[ProductKey.tags] ?? []),
      stock: map[ProductKey.stock] ?? 0,
    );
  }

  @override
  Map<String, dynamic> get source => {
        ProductKey.id_: id,
        ProductKey.name: name,
        ProductKey.price: price,
        ProductKey.category: category,
        ProductKey.tags: tags,
        ProductKey.stock: stock,
      };

  Product copyWith({
    String? name,
    double? price,
    String? category,
    List<String>? tags,
    int? stock,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      stock: stock ?? this.stock,
    );
  }
}

class ProductLocalSource extends LocalDataSource<Product> {
  ProductLocalSource()
      : super(
          path: 'products',
          documentId: 'id',
          delegate: LocalDataDelegate.instance,
        );

  @override
  Product build(dynamic source) => Product.from(source);
}

class ProductRemoteSource extends RemoteDataSource<Product> {
  ProductRemoteSource()
      : super(
          path: 'products',
          documentId: 'id',
          delegate: FirestoreDataDelegate.instance,
        );

  @override
  Product build(dynamic source) => Product.from(source);
}

class ProductRepository extends RemoteDataRepository<Product> {
  ProductRepository()
      : super(source: ProductRemoteSource(), backup: ProductLocalSource());
}

class RemoteDataTestPage extends StatefulWidget {
  const RemoteDataTestPage({super.key});

  @override
  State<RemoteDataTestPage> createState() => _RemoteDataTestPageState();
}

class _RemoteDataTestPageState extends State<RemoteDataTestPage> {
  final _repo = ProductRepository();
  String _log = '';

  String get _id => '1778319785575';

  void _log_(String msg) => setState(() => _log = msg);

  Future<void> _create() async {
    final tagPool = [
      'new',
      'sale',
      'hot',
      'trending',
      'limited',
      'popular',
      'featured',
    ];

    final rnd = DateTime.now().millisecondsSinceEpoch;
    final price = double.parse((10 + (rnd % 990)).toStringAsFixed(2));
    final stock = 1 + (rnd % 100);
    final tags = (tagPool..shuffle()).take(2).toList();

    final p = Product(
      id: _id,
      name: 'Headphone ${rnd % 1000}',
      price: price,
      category: 'accessories',
      tags: tags,
      stock: stock,
    );
    final res = await _repo.create(p);

    _log_(
      res.isSuccessful
          ? 'Created: ${p.name} | ${p.category} | ৳${p.price}'
          : 'Error: ${res.error}',
    );
  }

  Future<void> _createRandom() async {
    final names = [
      'Laptop',
      'Phone',
      'Tablet',
      'Watch',
      'Speaker',
      'Camera',
      'Headphone',
      'Monitor',
    ];
    final categories = [
      'electronics',
      'gadgets',
      'accessories',
      'audio',
      'display',
    ];
    final tagPool = [
      'new',
      'sale',
      'hot',
      'trending',
      'limited',
      'popular',
      'featured',
    ];

    final rnd = DateTime.now().millisecondsSinceEpoch;
    final name = names[rnd % names.length];
    final category = categories[rnd % categories.length];
    final price = double.parse((10 + (rnd % 990)).toStringAsFixed(2));
    final stock = 1 + (rnd % 100);
    final tags = (tagPool..shuffle()).take(2).toList();

    final p = Product(
      id: rnd.toString(),
      name: '$name ${rnd % 1000}',
      price: price,
      category: category,
      tags: tags,
      stock: stock,
    );
    final res = await _repo.create(p);
    _log_(
      res.isSuccessful
          ? 'Created: ${p.name} | ${p.category} | ৳${p.price}'
          : 'Error: ${res.error}',
    );
  }

  Future<void> _update() async {
    final r = await _repo.updateById(_id, {ProductKey.price: 199.9});
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
      r.isValid ? 'Got: ${r.result.firstOrNull?.name}' : 'Error: ${r.error}',
    );
  }

  Future<void> _getByIds() async {
    final r = await _repo.getByIds([_id, _id]);
    _log_(r.isValid ? 'Got ${r.result.length} items' : 'Error: ${r.error}');
  }

  Future<void> _query() async {
    final res = await _repo.getByQuery(
      queries: [DataQuery(ProductKey.category, isEqualTo: 'accessories')],
      options: const DataFetchOptions.limit(10),
    );
    _log_(
      res.isValid ? 'Query: ${res.result.length} items' : 'Error: ${res.error}',
    );
  }

  Future<void> _search() async {
    final res = await _repo.search(
      Checker.contains(ProductKey.category, 'access'),
    );
    _log_(
      res.isValid
          ? 'Search: ${res.result.length} items: ${res.result.map((e) => e.category).join(', ')}'
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
        appBar: AppBar(title: const Text('Remote Data Test')),
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
                    return Text('Total products: $count');
                  },
                ),
                const Divider(),
                const Text(
                  'Listen By Id',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                StreamBuilder<Response<Product>>(
                  stream: _repo.listenById(_id),
                  builder: (context, s) {
                    final item = s.data?.result.firstOrNull;
                    if (s.data?.isLoading == true) {
                      return const Text('Loading...');
                    }
                    if (item == null) return const Text('No data');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(
                        'Price: ${item.price} | Stock: ${item.stock}',
                      ),
                      trailing: Text(item.category),
                    );
                  },
                ),
                const Divider(),
                const Text(
                  'Listen By Ids',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                StreamBuilder<Response<Product>>(
                  stream: _repo.listenByIds([_id]),
                  builder: (context, s) {
                    final item = s.data?.result.firstOrNull;
                    if (s.data?.isLoading == true) {
                      return const Text('Loading...');
                    }
                    if (item == null) return const Text('No data');
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(
                        'Price: ${item.price} | Stock: ${item.stock}',
                      ),
                      trailing: Text(item.category),
                    );
                  },
                ),
                const Divider(),
                const Text(
                  'Listen',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                StreamBuilder<Response<Product>>(
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
                          title: Text(item.name),
                          subtitle: Text('₹${item.price} | ${item.category}'),
                          trailing: Text('Stock: ${item.id}'),
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
                StreamBuilder<Response<Product>>(
                  stream: _repo.listenByQuery(
                    queries: [DataQuery(ProductKey.price, isGreaterThan: 100)],
                    sorts: [DataSorting(ProductKey.price)],
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
                          title: Text(item.name),
                          subtitle: Text('₹${item.price} | ${item.category}'),
                          trailing: Text('Stock: ${item.id}'),
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
