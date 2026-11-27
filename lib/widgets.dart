import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'models.dart';
import 'text.dart';

class ItemMark extends StatelessWidget {
  const ItemMark({super.key, required this.item, this.size = 64});

  final ShareItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: item.category.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      clipBehavior: Clip.antiAlias,
      child: item.photoBytes == null
          ? Icon(
              item.category.icon,
              color: item.category.color,
              size: size * 0.42,
            )
          : Image.memory(item.photoBytes!, fit: BoxFit.cover),
    );
  }
}

class PriceChip extends StatelessWidget {
  const PriceChip({super.key, required this.item});

  final ShareItem item;

  @override
  Widget build(BuildContext context) {
    final free = item.isFree;
    final color = free ? const Color(0xFF003070) : const Color(0xFF8C6239);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priceText(context, item),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class StageTrack extends StatelessWidget {
  const StageTrack({super.key, required this.stage});

  final BookingStage stage;

  @override
  Widget build(BuildContext context) {
    final labels = [
      tr(context, '預約', 'Book'),
      tr(context, '取件', 'Pickup'),
      tr(context, '歸還', 'Return'),
      tr(context, '評價', 'Review'),
    ];
    final active = stage.trackStep;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          _Node(label: labels[i], done: i <= active, current: i == active),
          if (i != labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i < active
                    ? const Color(0xFF003070)
                    : const Color(0xFFD9D3C8),
              ),
            ),
        ],
      ],
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.label, required this.done, required this.current});

  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = done ? const Color(0xFF003070) : const Color(0xFFB7AFA3);
    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: done ? color : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: current ? 2 : 1.4),
          ),
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

Future<DistrictFilter?> showHkDistrictSheet(
  BuildContext context, {
  required bool includeAll,
  HkDistrict? selected,
}) {
  return showModalBottomSheet<DistrictFilter>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.8;
      return SafeArea(
        child: SizedBox(
          height: height,
          child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              tr(context, '香港十八區', '18 districts'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (includeAll)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr(context, '全港', 'All Hong Kong')),
                trailing: selected == null
                    ? const Icon(Icons.check, color: Color(0xFF003070))
                    : null,
                onTap: () =>
                    Navigator.of(context).pop(const DistrictFilter(null)),
              ),
            for (final region in HkRegion.values) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  regionLabel(context, region),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final district in HkDistrict.values)
                    if (district.region == region)
                      ChoiceChip(
                        label: Text(districtLabel(context, district)),
                        selected: selected == district,
                        onSelected: (_) => Navigator.of(
                          context,
                        ).pop(DistrictFilter(district)),
                      ),
                ],
              ),
            ],
          ],
        ),
        ),
      );
    },
  );
}

void showFullPhoto(BuildContext context, Uint8List bytes) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(tr(context, '相片', 'Photo')),
        ),
        body: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(child: Image.memory(bytes)),
        ),
      ),
    ),
  );
}

class InfoLine extends StatelessWidget {
  const InfoLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF5E6A64)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }
}
