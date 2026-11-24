import 'package:flutter/material.dart';

import 'item_pages.dart';
import 'main.dart';
import 'models.dart';
import 'text.dart';
import 'widgets.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _query = TextEditingController();
  ItemCategory? _category;
  HkDistrict? _district;
  ItemSort _sort = ItemSort.nearest;
  bool _freeOnly = false;
  bool _mineOnly = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ShareKitScope.of(context);
    final user = AccountScope.of(context).user;
    final results = store.search(
      query: _query.text,
      category: _category,
      freeOnly: _freeOnly,
      district: _district,
      owner: _mineOnly ? user.label : null,
      sort: _sort,
    );
    final place = _district?.label ?? '全港';

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
          const Text(
            '先選地區，再借附近的人已經有的東西。',
            style: TextStyle(fontSize: 16, color: Color(0xFF3E4A44)),
          ),
          const SizedBox(height: 14),
          const _PilotCard(),
          const SizedBox(height: 16),
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: '搜尋電鑽、露營、摺枱…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: '全部',
                  selected: _category == null && !_freeOnly,
                  onTap: () => setState(() {
                    _category = null;
                    _freeOnly = false;
                  }),
                ),
                for (final category in ItemCategory.values)
                  _FilterChip(
                    label: categoryLabel(context, category),
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
                _FilterChip(
                  label: '只看免費',
                  selected: _freeOnly,
                  onTap: () => setState(() => _freeOnly = !_freeOnly),
                ),
                _FilterChip(
                  label: '我的區 · ${user.district.label}',
                  selected: _district == user.district,
                  onTap: () => setState(() => _district = user.district),
                ),
                _FilterChip(
                  label: '我的物品',
                  selected: _mineOnly,
                  onTap: () => setState(() => _mineOnly = !_mineOnly),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showHkDistrictSheet(
                    context,
                    includeAll: true,
                    selected: _district,
                  );
                  if (!mounted || picked == null) return;
                  setState(() => _district = picked.district);
                },
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  _district == null
                      ? tr(context, '十八區', '18 districts')
                      : districtLabel(context, _district!),
                ),
              ),
              for (final sort in ItemSort.values)
                ChoiceChip(
                  label: Text(sortLabel(context, sort)),
                  selected: _sort == sort,
                  onSelected: (_) => setState(() => _sort = sort),
                ),
            ],
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
                    ? '你還沒有上架物品。'
                    : '這個地區暫時沒有符合的物品。可以改選其他區，或自己上架。',
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
        color: const Color(0xFF14352C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '香港十八區 · 社區借用',
            style: TextStyle(
              color: Color(0xFFE7F3EE),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '先揀你所在的區。電鑽、清潔機、露營裝備很多時一年只用幾次，附近已經有人擁有。',
            style: TextStyle(color: Color(0xFFD5E4DC), height: 1.4),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
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
                    const SizedBox(height: 4),
                    Text(
                      '${item.district.label} · ${formatDistance(item.distanceMeters)} · ${item.condition}',
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
                              ? ' 新上架'
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
