import 'package:flutter_test/flutter_test.dart';
import 'package:sharekit/auth_repository.dart';
import 'package:sharekit/models.dart';
import 'package:sharekit/store.dart';

ShareItem sample({
  required String id,
  required String name,
  required ItemCategory category,
  String owner = 'Demo1',
  String summary = '',
  double? dailyPrice,
  double rating = 0,
  int distance = 100,
}) {
  return ShareItem(
    id: id,
    name: name,
    owner: owner,
    category: category,
    condition: '良好',
    distanceMeters: distance,
    summary: summary,
    rating: rating,
    reviewCount: rating == 0 ? 0 : 1,
    handovers: 0,
    dailyPrice: dailyPrice,
  );
}

void main() {
  test('搜尋名稱、英文分類，並可按評價和租金的高低排序', () {
    final store = ShareStore();
    store.replaceItems([
      sample(id: 'a', name: 'Drill', category: ItemCategory.tool, dailyPrice: 40, rating: 3, distance: 50),
      sample(id: 'b', name: 'Tent', category: ItemCategory.outdoor, dailyPrice: 10, rating: 5, distance: 20),
      sample(id: 'c', name: '雨傘', category: ItemCategory.others, summary: '校園借用', dailyPrice: null, rating: 4, distance: 80),
    ]);

    expect(store.search(query: 'drill', freeOnly: false).map((item) => item.id), ['a']);
    expect(store.search(query: 'Tools', freeOnly: false).map((item) => item.id), ['a']);
    expect(store.search(query: '雨傘', freeOnly: false).map((item) => item.id), ['c']);

    final byRatingHigh = store.search(
      query: '',
      freeOnly: false,
      field: SortField.rating,
      direction: SortDir.highToLow,
    );
    expect(byRatingHigh.map((item) => item.id), ['b', 'c', 'a']);

    final byPriceLow = store.search(
      query: '',
      freeOnly: false,
      field: SortField.price,
      direction: SortDir.lowToHigh,
    );
    expect(byPriceLow.first.id, 'c');
    expect(byPriceLow.last.id, 'a');

    final toolsAndOutdoor = store.search(
      query: '',
      freeOnly: false,
      categories: {ItemCategory.tool, ItemCategory.outdoor},
    );
    expect(toolsAndOutdoor.map((item) => item.id).toSet(), {'a', 'b'});
  });

  test('密碼要有 8 個字、英文字母和數字', () {
    expect(AuthRepository.passwordProblem('short1'), isNotNull);
    expect(AuthRepository.passwordProblem('abcdefgh'), isNotNull);
    expect(AuthRepository.passwordProblem('12345678'), isNotNull);
    expect(AuthRepository.passwordProblem('Aa12345678'), isNull);
  });
}
