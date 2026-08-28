import 'package:flutter_test/flutter_test.dart';
import 'package:laptop_inventory_manager/features/inventory/data/inventory_repository.dart';
import 'package:laptop_inventory_manager/main.dart';

void main() {
  test('model list filters by generation and family values', () {
    final base = [
      const Choice(1, 'Dell Latitude 7440 7th U'),
      const Choice(2, 'Dell Latitude 7440 8th H'),
      const Choice(3, 'Dell Latitude 7440 7th HX'),
      const Choice(4, 'HP EliteBook 840 6th U'),
    ];

    final filtered = filterModelChoicesByCpu(
      base,
      generation: '7th',
      family: 'hx',
    );

    expect(filtered.map((e) => e.id), [3]);
  });
}
