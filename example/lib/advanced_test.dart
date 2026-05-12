import 'package:data_management/data_management.dart'
    show
        RemoteDataSource,
        RemoteDataRepository,
        DataFetchOptions,
        DataFieldValue,
        DataFieldValueWriter,
        DataSetWriter,
        DataFieldValueReader,
        DataQuery,
        DataSorting,
        DataFieldValueQueryOptions,
        DataUpdateWriter,
        DataDeleteWriter,
        DataWriter,
        Checker,
        KeyParams;
import 'package:flutter/material.dart'
    show
        StatefulWidget,
        State,
        BuildContext,
        Widget,
        Text,
        EdgeInsets,
        Divider,
        TextStyle,
        SizedBox,
        VoidCallback,
        ThemeData,
        AppBar,
        CrossAxisAlignment,
        Wrap,
        Colors,
        Container,
        StreamBuilder,
        Column,
        SingleChildScrollView,
        SafeArea,
        Scaffold,
        Theme,
        FontWeight,
        Padding,
        ElevatedButton,
        Card;
import 'package:flutter_entity/entity.dart' show Entity, Response, EntityKey;

import 'delegates/firestore.dart' show FirestoreDataDelegate;

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

class _K {
  static const String name = 'name';
  static const String price = 'price';
  static const String stock = 'stock';
  static const String category = 'category';
  static const String tags = 'tags';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String score = 'score';

  // @ reference keys (stored as paths, resolved to full docs on read)
  static const String refBrand = '@brand';
  static const String refMeta = '@meta';
  static const String refVariants = '@variants'; // List of paths
  static const String refByRegion = '@byRegion'; // Map of paths

  // # countable keys (stored as collection paths, resolved to int on read)
  static const String countReviews = '#reviews';
  static const String countOrders = '#orders';

  // resolved keys (after hydration the @ and # prefix is stripped)
  static const String brand = 'brand';
  static const String meta = 'meta';
  static const String variants = 'variants';
  static const String byRegion = 'byRegion';
  static const String reviews = 'reviews';
  static const String orders = 'orders';
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class _Product extends Entity {
  final String name;
  final double price;
  final int stock;
  final String category;
  final List<String> tags;

  // Resolved after hydration (nullable — absent when not requested)
  final Map<String, dynamic>? brand;
  final Map<String, dynamic>? meta;
  final List<dynamic>? variants;
  final Map<String, dynamic>? byRegion;
  final int? reviews;
  final int? orders;

  _Product({
    required super.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.category,
    required this.tags,
    this.brand,
    this.meta,
    this.variants,
    this.byRegion,
    this.reviews,
    this.orders,
  });

  @override
  Map<String, dynamic> get source => {
        _K.name: name,
        _K.price: price,
        _K.stock: stock,
        _K.category: category,
        _K.tags: tags,
      };

  factory _Product.fromMap(Map<String, dynamic> map) => _Product(
        id: map[EntityKey.i.id] as String? ?? '',
        name: map[_K.name] as String? ?? '',
        price: (map[_K.price] as num?)?.toDouble() ?? 0,
        stock: map[_K.stock] as int? ?? 0,
        category: map[_K.category] as String? ?? '',
        tags: List<String>.from(map[_K.tags] as List? ?? []),
        brand: map[_K.brand] as Map<String, dynamic>?,
        meta: map[_K.meta] as Map<String, dynamic>?,
        variants: map[_K.variants] as List?,
        byRegion: map[_K.byRegion] as Map<String, dynamic>?,
        reviews: map[_K.reviews] as int?,
        orders: map[_K.orders] as int?,
      );
}

// ---------------------------------------------------------------------------
// Source  (replace delegate with your real Firestore/Hive delegate)
// ---------------------------------------------------------------------------

class _ProductSource extends RemoteDataSource<_Product> {
  _ProductSource()
      : super(
          path: 'test_products',
          documentId: 'id',
          delegate: FirestoreDataDelegate.i,
        );

  @override
  _Product build(dynamic source) =>
      _Product.fromMap(source as Map<String, dynamic>);
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class _ProductRepo extends RemoteDataRepository<_Product> {
  _ProductRepo()
      : super(
          source: _ProductSource(),
          backupMode: true,
          lazyMode: true,
          queueMode: true,
        );
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class RefsTestPage extends StatefulWidget {
  const RefsTestPage({super.key});

  @override
  State<RefsTestPage> createState() => _RefsTestPageState();
}

class _RefsTestPageState extends State<RefsTestPage> {
  final _repo = _ProductRepo();
  String _log = '';

  // Fixed id used across tests so we can read back what we wrote
  String get _id => 'prod_ref_test_01';

  // Sub-collection / sibling paths derived from _id
  String get _brandPath => 'test_brands/brand_acme';

  String get _metaPath => 'test_products/$_id/meta/default';

  String get _variantAPath => 'test_products/$_id/variants/v_red';

  String get _variantBPath => 'test_products/$_id/variants/v_blue';

  String get _regionUsPath => 'test_products/$_id/regions/us';

  String get _regionBdPath => 'test_products/$_id/regions/bd';

  String get _reviewsPath => 'test_products/$_id/reviews';

  String get _ordersPath => 'test_products/$_id/orders';

  void _log_(String msg) => setState(() => _log = msg);

  // -------------------------------------------------------------------------
  // 1. Create with @ references (DataFieldValueWriter.set)
  //    All embedded set/update/delete run in ONE atomic batch alongside the
  //    parent document write.
  // -------------------------------------------------------------------------
  Future<void> _createWithRefs() async {
    final res = await _repo.createById(
      _id,
      {
        _K.name: 'AcmePhone Pro',
        _K.price: 599.0,
        _K.stock: 50,
        _K.category: 'smartphones',
        _K.tags: ['new', 'featured'],
        _K.createdAt: DataFieldValue.serverTimestamp(),

        // @ reference: creates/merges a sibling brand doc in the same batch.
        // On read (resolveRefs: true) this field is replaced with the full
        // brand document.
        _K.refBrand: DataFieldValueWriter.set(
          _brandPath,
          {
            'name': 'Acme Corp',
            'country': 'US',
            'tier': 'premium',
          },
        ),

        // @ reference: creates a sub-document for product metadata.
        _K.refMeta: DataFieldValueWriter.set(
          _metaPath,
          {
            'sku': 'ACM-PRO-001',
            'weight': '185g',
            'dimensions': '160x75x8mm',
          },
        ),

        // @ reference (List): multiple variant docs written in one batch.
        // On read (resolveRefs: true) this becomes a List of full variant maps.
        _K.refVariants: [
          DataFieldValueWriter.set(
            _variantAPath,
            {'color': 'Red', 'stock': 20, 'sku': 'ACM-PRO-RED'},
          ),
          DataFieldValueWriter.set(
            _variantBPath,
            {'color': 'Blue', 'stock': 30, 'sku': 'ACM-PRO-BLU'},
          ),
        ],

        // @ reference (Map): region-specific docs keyed by region code.
        // On read (resolveRefs: true) this becomes Map<String, Map> of region docs.
        _K.refByRegion: {
          'us': DataFieldValueWriter.set(
            _regionUsPath,
            {'price': 599.0, 'currency': 'USD', 'available': true},
          ),
          'bd': DataFieldValueWriter.set(
            _regionBdPath,
            {'price': 65000.0, 'currency': 'BDT', 'available': false},
          ),
        },

        // # countable: stores the collection path so that on read
        // (countable: true) the field is replaced with the live document count.
        _K.countReviews: _reviewsPath,
        _K.countOrders: _ordersPath,
      },
      createRefs: true, // required to process DataFieldValueWriter values
    );

    _log_(res.isSuccessful
        ? 'Created with @ and # refs ✓'
        : 'Error: ${res.error}');
  }

  // -------------------------------------------------------------------------
  // 2. Seed some review and order documents so # counts are non-zero
  // -------------------------------------------------------------------------
  Future<void> _seedCountCollections() async {
    final rnd = DateTime.now().millisecondsSinceEpoch;
    await _repo.write([
      DataSetWriter(
        '$_reviewsPath/r_$rnd',
        {'rating': 5, 'body': 'Great phone!', 'at': rnd},
      ),
      DataSetWriter(
        '$_ordersPath/o_$rnd',
        {'qty': 1, 'total': 599.0, 'at': rnd},
      ),
    ]);
    _log_('Seeded review + order docs ✓');
  }

  // -------------------------------------------------------------------------
  // 3. Read back — plain (no hydration)
  // -------------------------------------------------------------------------
  Future<void> _getPlain() async {
    final r = await _repo.getById(_id);
    if (!r.isSuccessful) {
      _log_('Error: ${r.error}');
      return;
    }
    final p = r.data!;
    _log_(
      'Plain read:\n'
      '  name=${p.name}\n'
      '  brand=${p.brand}  ← null (not resolved)\n'
      '  reviews=${p.reviews}  ← null (not resolved)\n',
    );
  }

  // -------------------------------------------------------------------------
  // 4. Read back — resolve @ reference fields
  //    @brand, @meta, @variants, @byRegion are fetched and inlined.
  // -------------------------------------------------------------------------
  Future<void> _getWithRefs() async {
    final r = await _repo.getById(_id, resolveRefs: true);
    if (!r.isSuccessful) {
      _log_('Error: ${r.error}');
      return;
    }
    final p = r.data!;
    _log_(
      'Resolved refs:\n'
      '  brand=${p.brand}\n'
      '  meta=${p.meta}\n'
      '  variants(${p.variants?.length ?? 0})=${p.variants}\n'
      '  byRegion=${p.byRegion}\n',
    );
  }

  // -------------------------------------------------------------------------
  // 5. Read back — resolve # countable fields
  //    #reviews and #orders are replaced with live integer counts.
  // -------------------------------------------------------------------------
  Future<void> _getWithCounts() async {
    final r = await _repo.getById(_id, countable: true);
    if (!r.isSuccessful) {
      _log_('Error: ${r.error}');
      return;
    }
    final p = r.data!;
    _log_(
      'Countable read:\n'
      '  reviews=${p.reviews}\n'
      '  orders=${p.orders}\n',
    );
  }

  // -------------------------------------------------------------------------
  // 6. Read back — fully hydrated (@refs + #counts)
  // -------------------------------------------------------------------------
  Future<void> _getFullyHydrated() async {
    final r = await _repo.getById(_id, resolveRefs: true, countable: true);
    if (!r.isSuccessful) {
      _log_('Error: ${r.error}');
      return;
    }
    final p = r.data!;
    _log_(
      'Fully hydrated:\n'
      '  brand=${p.brand?['name']}\n'
      '  meta sku=${p.meta?['sku']}\n'
      '  variants=${p.variants?.map((v) => v['color']).toList()}\n'
      '  byRegion keys=${p.byRegion?.keys.toList()}\n'
      '  reviews=${p.reviews}\n'
      '  orders=${p.orders}\n',
    );
  }

  // -------------------------------------------------------------------------
  // 7. Update with DataFieldValue sentinels + embedded @ update ref
  // -------------------------------------------------------------------------
  Future<void> _updateWithSentinels() async {
    final r = await _repo.updateById(
      _id,
      {
        // Standard sentinel values
        _K.price: 549.0,
        _K.updatedAt: DataFieldValue.serverTimestamp(),
        _K.score: DataFieldValue.increment(10),
        _K.tags: DataFieldValue.arrayUnion(['sale']),
        _K.stock: DataFieldValue.increment(-5),

        // @ embedded update: updates the brand doc in the same batch
        _K.refBrand: DataFieldValueWriter.update(
          _brandPath,
          {'tier': 'enterprise', 'updatedAt': DataFieldValue.serverTimestamp()},
        ),

        // @ embedded update: updates the meta doc in the same batch
        _K.refMeta: DataFieldValueWriter.update(
          _metaPath,
          {'weight': '182g'},
        ),
      },
      updateRefs: true, // required to process DataFieldValueWriter values
    );

    _log_(r.isSuccessful
        ? 'Updated with sentinels + @refs ✓'
        : 'Error: ${r.error}');
  }

  // -------------------------------------------------------------------------
  // 8. Update — remove a tag + delete a variant ref in one batch
  // -------------------------------------------------------------------------
  Future<void> _updateRemoveAndDelete() async {
    final r = await _repo.updateById(
      _id,
      {
        _K.tags: DataFieldValue.arrayRemove(['new']),

        // @ embedded delete: removes the red variant doc in the same batch
        _K.refVariants: DataFieldValueWriter.delete(_variantAPath),
      },
      updateRefs: true,
    );

    _log_(r.isSuccessful
        ? 'Removed tag + deleted variant ref ✓'
        : 'Error: ${r.error}');
  }

  // -------------------------------------------------------------------------
  // 9. DataFieldValueReader — store deferred read-time resolvers
  //    These are stored as field values; on every getById/listen the system
  //    fetches/counts the referenced path and inlines the result live.
  // -------------------------------------------------------------------------
  Future<void> _storeReaders() async {
    final r = await _repo.updateById(
      _id,
      {
        // On read: fetch the doc at _brandPath and inline it as 'brand'
        _K.refBrand: DataFieldValueReader.get(_brandPath),

        // On read: count _reviewsPath and inline as 'reviews'
        _K.countReviews: DataFieldValueReader.count(_reviewsPath),

        // On read: query _reviewsPath with filters and inline as 'variants'
        '@topReviews': DataFieldValueReader.filter(
          _reviewsPath,
          DataFieldValueQueryOptions(
            queries: [DataQuery('rating', isGreaterThanOrEqualTo: 4)],
            sorts: [DataSorting('at', descending: true)],
            options: const DataFetchOptions.limit(3),
          ),
        ),
      },
      updateRefs: false, // readers are plain field values, no batch needed
    );

    _log_(r.isSuccessful
        ? 'DataFieldValueReaders stored ✓'
        : 'Error: ${r.error}');
  }

  // -------------------------------------------------------------------------
  // 10. Bulk write — heterogeneous atomic batch (DataSetWriter / DataUpdateWriter
  //     / DataDeleteWriter) across unrelated paths in one commit
  // -------------------------------------------------------------------------
  Future<void> _bulkWrite() async {
    final rnd = DateTime.now().millisecondsSinceEpoch;
    final r = await _repo.write([
      // Set a new review
      DataSetWriter(
        '$_reviewsPath/r_bulk_$rnd',
        {'rating': 4, 'body': 'Solid build quality', 'at': rnd},
      ),
      // Update region availability
      DataUpdateWriter(
        _regionBdPath,
        {'available': true, 'updatedAt': DataFieldValue.serverTimestamp()},
      ),
      // Increment global product score
      DataUpdateWriter(_id, {_K.score: DataFieldValue.increment(5)}),
      // Delete the blue variant (no longer in stock)
      DataDeleteWriter(_variantBPath),
    ]);

    _log_(r.isSuccessful ? 'Bulk write (4 ops) ✓' : 'Error: ${r.error}');
  }

  // -------------------------------------------------------------------------
  // 11. creates — batch-create multiple products with # refs in one call
  // -------------------------------------------------------------------------
  Future<void> _batchCreate() async {
    final rnd = DateTime.now().millisecondsSinceEpoch;
    final writers = List.generate(
      3,
      (i) => DataWriter(
        id: 'batch_prod_${rnd}_$i',
        data: {
          _K.name: 'BatchItem $i',
          _K.price: 100.0 + i * 50,
          _K.stock: 10 + i,
          _K.category: 'batch',
          _K.tags: ['batch'],
          // # countable ref stored for later reads
          _K.countReviews: 'test_products/batch_prod_${rnd}_$i/reviews',
        },
      ),
    );

    final r = await _repo.createByWriters(writers);
    _log_(
      r.isSuccessful
          ? 'Batch created ${writers.length} products ✓'
          : 'Error: ${r.error}',
    );
  }

  // -------------------------------------------------------------------------
  // 12. get all — collection with countable hydration
  // -------------------------------------------------------------------------
  Future<void> _getAllHydrated() async {
    final r = await _repo.get(countable: true, resolveRefs: true);
    _log_(
      r.isValid
          ? 'Got ${r.result.length} products (hydrated) ✓'
          : 'Error: ${r.error}',
    );
  }

  // -------------------------------------------------------------------------
  // 13. getByQuery — filter + sort + ignore specific ref field
  // -------------------------------------------------------------------------
  Future<void> _queryWithIgnore() async {
    final r = await _repo.getByQuery(
      queries: [DataQuery(_K.category, isEqualTo: 'smartphones')],
      sorts: [DataSorting(_K.price, descending: true)],
      options: const DataFetchOptions.limit(10),
      resolveRefs: true,
      countable: true,
      // Skip hydrating '@meta' — we don't need it in this query result
      ignore: (key, _) => key == _K.refMeta,
    );
    _log_(
      r.isValid
          ? 'Query: ${r.result.length} smartphones (meta ignored) ✓\n'
              '  first brand=${r.result.firstOrNull?.brand?['name']}'
          : 'Error: ${r.error}',
    );
  }

  // -------------------------------------------------------------------------
  // 14. search — contains check with ref hydration
  // -------------------------------------------------------------------------
  Future<void> _searchHydrated() async {
    final r = await _repo.search(
      Checker.contains(_K.category, 'smart'),
      resolveRefs: true,
      countable: true,
    );
    _log_(
      r.isValid
          ? 'Search: ${r.result.length} results ✓\n'
              '  reviews=${r.result.firstOrNull?.reviews}'
          : 'Error: ${r.error}',
    );
  }

  // -------------------------------------------------------------------------
  // 15. Cascade delete — removes product + all @ referenced docs
  // -------------------------------------------------------------------------
  Future<void> _cascadeDelete() async {
    final r = await _repo.deleteById(
      _id,
      deleteRefs: true, // follows @ fields and deletes referenced docs
      counter: true, // also deletes docs in # collection paths
      ignore: (key, _) => key == _K.refBrand, // keep brand doc alive
    );
    _log_(r.isSuccessful
        ? 'Cascade deleted $_id ✓ (brand kept)'
        : 'Error: ${r.error}');
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        appBar: AppBar(title: const Text('@ # Refs Test')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('Write'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _btn('Create with @/#', _createWithRefs),
                    _btn('Seed counts', _seedCountCollections),
                    _btn('Update sentinels', _updateWithSentinels),
                    _btn('Remove + Delete ref', _updateRemoveAndDelete),
                    _btn('Store Readers', _storeReaders),
                    _btn('Bulk write (4 ops)', _bulkWrite),
                    _btn('Batch creates (3)', _batchCreate),
                    _btn('Cascade delete', _cascadeDelete),
                  ],
                ),
                const Divider(height: 24),
                _section('Read'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _btn('Get plain', _getPlain),
                    _btn('Get @refs', _getWithRefs),
                    _btn('Get #counts', _getWithCounts),
                    _btn('Get fully hydrated', _getFullyHydrated),
                    _btn('Get all hydrated', _getAllHydrated),
                    _btn('Query + ignore', _queryWithIgnore),
                    _btn('Search hydrated', _searchHydrated),
                  ],
                ),
                if (_log.isNotEmpty) ...[
                  const Divider(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    color: Colors.black26,
                    child: Text(
                      _log,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
                const Divider(height: 24),
                _section('Listen — fully hydrated (@refs + #counts)'),
                StreamBuilder<Response<_Product>>(
                  stream: _repo.listenById(
                    _id,
                    resolveRefs: true,
                    countable: true,
                  ),
                  builder: (context, s) {
                    final p = s.data?.result.firstOrNull;
                    if (p == null) return const Text('No data');
                    return _productTile(p);
                  },
                ),
                const Divider(height: 24),
                _section('Listen count — reviews sub-collection'),
                StreamBuilder<Response<int>>(
                  stream: _repo.listenCount(
                    params: KeyParams({
                      // If your source path has a placeholder like
                      // 'test_products/{id}/reviews', use params.
                      // Here we use the top-level repo just for listenCount.
                    }),
                  ),
                  builder: (context, s) {
                    return Text('Collection count: ${s.data?.data ?? 0}');
                  },
                ),
                const Divider(height: 24),
                _section('Listen by query — price > 100, hydrated'),
                StreamBuilder<Response<_Product>>(
                  stream: _repo.listenByQuery(
                    queries: [DataQuery(_K.price, isGreaterThan: 100)],
                    sorts: [DataSorting(_K.price)],
                    resolveRefs: true,
                    countable: true,
                  ),
                  builder: (context, s) {
                    final items = s.data?.result ?? [];
                    if (items.isEmpty) return const Text('No data');
                    return Column(
                      children: items.take(3).map(_productTile).toList(),
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

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      );

  Widget _btn(String label, VoidCallback onTap) => ElevatedButton(
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 11)),
      );

  Widget _productTile(_Product p) => Card(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Price: ${p.price}  Stock: ${p.stock}'),
              if (p.brand != null)
                Text('Brand: ${p.brand!['name']} (${p.brand!['tier']})'),
              if (p.meta != null) Text('SKU: ${p.meta!['sku']}'),
              if (p.variants != null)
                Text(
                  'Variants: ${p.variants!.map((v) => v['color']).join(', ')}',
                ),
              if (p.byRegion != null)
                Text(
                  'Regions: ${p.byRegion!.entries.map((e) => '${e.key}=${e.value['currency']}').join(', ')}',
                ),
              if (p.reviews != null) Text('Reviews: ${p.reviews}'),
              if (p.orders != null) Text('Orders: ${p.orders}'),
            ],
          ),
        ),
      );
}
