import 'package:flutter/material.dart';

import 'item_pages.dart';
import 'main.dart';
import 'models.dart';
import 'store.dart';
import 'text.dart';
import 'widgets.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _query = TextEditingController();
  final Set<ItemCategory> _categories = {};
  SortField _field = SortField.nearest;
  SortDir _direction = SortDir.lowToHigh;
  bool _freeOnly = false;
  bool _mineOnly = false;
  ShareStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = ShareKitScope.of(context);
    if (!identical(_store, store)) {
      _store?.removeListener(_onStore);
      _store = store;
      store.addListener(_onStore);
    }
    _onStore();
  }

  void _onStore() {
    final store = _store;
    if (store == null || !store.takeFocusMine() || _mineOnly) return;
    setState(() => _mineOnly = true);
  }

  @override
  void dispose() {
    _store?.removeListener(_onStore);
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ShareKitScope.of(context);
    final user = AccountScope.of(context).user;
    final results = store.search(
      query: _query.text,
      categories: _categories,
      freeOnly: _freeOnly,
      district: null,
      owner: _mineOnly ? user.label : null,
      field: _field,
      direction: _direction,
    );
    final place = tr(context, '香港浸會大學', 'HKBU Campus');

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Text(
            'ShareKit',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              context,
              '你在香港浸會大學。向同學借雨傘、充電器、活動物資。',
              'You are at HKBU. Borrow umbrellas, chargers, and event gear from classmates.',
            ),
            style: const TextStyle(fontSize: 16, color: Color(0xFF3E4E62)),
          ),
          const SizedBox(height: 14),
          const _PilotCard(),
          const SizedBox(height: 16),
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: tr(
                context,
                '搜尋雨傘、充電器、摺枱…',
                'Search umbrellas, chargers, tables…',
              ),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, '分類', 'Category'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(
                      label: tr(context, '全部', 'All'),
                      selected: _categories.isEmpty && !_freeOnly,
                      onTap: () => setState(() {
                        _categories.clear();
                        _freeOnly = false;
                      }),
                    ),
                    for (final category in ItemCategory.values)
                      _FilterChip(
                        label: categoryLabel(context, category),
                        selected: _categories.contains(category),
                        onTap: () => setState(() {
                          if (!_categories.add(category)) _categories.remove(category);
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  tr(context, '篩選與排序', 'Filter and sort'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _FilterChip(
                      label: tr(context, '只看免費', 'Free only'),
                      selected: _freeOnly,
                      onTap: () => setState(() => _freeOnly = !_freeOnly),
                    ),
                    _FilterChip(
                      label: tr(context, '我的物品', 'My items'),
                      selected: _mineOnly,
                      onTap: () => setState(() => _mineOnly = !_mineOnly),
                    ),
                    for (final field in SortField.values)
                      _FilterChip(
                        label: sortFieldLabel(context, field),
                        selected: _field == field,
                        onTap: () => setState(() => _field = field),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final direction in SortDir.values)
                      _FilterChip(
                        label: sortDirLabel(context, direction),
                        selected: _direction == direction,
                        onTap: () => setState(() => _direction = direction),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$place · ${results.length} 件',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Text(
                _mineOnly
                    ? tr(
                        context,
                        '你還沒有上架物品。',
                        'You have not listed anything yet.',
                      )
                    : tr(
                        context,
                        '校園暫時沒有符合的物品。可以改篩選條件，或自己上架。',
                        'Nothing on campus matches. Change filters, or list an item.',
                      ),
              ),
            )
          else if (MediaQuery.sizeOf(context).width >= 900)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: results.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 520,
                mainAxisExtent: 132,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) => _ItemCard(item: results[index]),
            )
          else
            for (final item in results) ...[
              _ItemCard(item: item),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _PilotCard extends StatelessWidget {
  const _PilotCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF003070),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, '你在香港浸會大學', 'You are at HKBU'),
            style: const TextStyle(
              color: Color(0xFFE8F1FB),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              context,
              'ShareKit 浸大校園試點：同學之間借用雨傘、充電器、活動道具等不常用物品。',
              'ShareKit HKBU campus pilot: classmates lend umbrellas, chargers, event props, and other rarely used items.',
            ),
            style: const TextStyle(color: Color(0xFFD0E4F7), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, softWrap: false),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item});

  final ShareItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ItemDetailPage(itemId: item.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Hero(
                tag: item.id,
                child: ItemMark(item: item),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(context, '物主 ${item.owner}', 'Owner ${item.owner}'),
                      style: const TextStyle(color: Color(0xFF5E6A64), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${districtLabel(context, item.district)} · ${distanceText(context, item.distanceMeters)} · ${conditionLabel(context, item.condition)}',
                      style: const TextStyle(
                        color: Color(0xFF5E6A64),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        PriceChip(item: item),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        Text(
                          item.reviewCount == 0
                              ? tr(context, ' 新上架', ' New')
                              : ' ${item.rating}（${item.reviewCount}）',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8A918C)),
            ],
          ),
        ),
      ),
    );
  }
}
