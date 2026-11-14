import 'package:flutter/material.dart';

import 'item_pages.dart';
import 'main.dart';
import 'models.dart';
import 'widgets.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _query = TextEditingController();
  ItemCategory? _category;
  bool _freeOnly = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = ShareKitScope.of(context);
    final results = store.search(
      query: _query.text,
      category: _category,
      freeOnly: _freeOnly,
    );

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
            '需要就借，不必先買。',
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
                    label: category.label,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
                _FilterChip(
                  label: '只看免費',
                  selected: _freeOnly,
                  onTap: () => setState(() => _freeOnly = !_freeOnly),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${results.length} 件在附近',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 28),
              child: Text('這個社區暫時沒有符合的物品。可以換一個分類，或自己上架。'),
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
            '試點社區 · 九龍塘示範屋苑',
            style: TextStyle(
              color: Color(0xFFE7F3EE),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '電鑽、清潔機、露營裝備和活動桌椅，很多時一年只用幾次。附近已有人擁有，只是缺少一個安全、有紀錄的借用方式。',
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
                      '${formatDistance(item.distanceMeters)} · ${item.condition} · ${item.owner}',
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
