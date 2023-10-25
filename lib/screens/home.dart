import 'package:code_rabbit_test/models/favorites.dart';
import 'package:code_rabbit_test/screens/favorites.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class HomePage extends StatelessWidget {
  static const rn = '/';

  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Testing Sample'),
        actions: [
          TextButton.icon(
            onPressed: () {
              context.go(FavoritesPage.fullPath);
            },
            icon: const Icon(Icons.favorite_border),
            label: const Text('Favorites'),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 100,
        cacheExtent: 20.0 + 6,
        controller: ScrollController(),
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemBuilder: (context, index) => ItemTile(index),
      ),
    );
  }
}

class ItemTile extends StatelessWidget {
  final int itemNo;

  const ItemTile(this.itemNo, {super.key});

  @override
  Widget build(BuildContext context) {
    final favoritesList = context.watch<Favorites>();

    return Padding(
      padding: EdgeInsets.all(8.0),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: Colors.primaries[itemNo % Colors.primaries.length],
            ),
            CircleAvatar(
              backgroundColor: Colors.primaries[itemNo % Colors.primaries.length + 1],
            ),
            CircleAvatar(
              backgroundColor: Colors.primaries[itemNo % Colors.primaries.length + 2],
            )
          ],
        ),
        title: Text(
          'Item $itemNo',
          key: Key('text_$itemNo'),
        ),
        trailing: IconButton(
          key: Key('icon_$itemNo'),
          icon: favoritesList.items.contains(itemNo) ? const Icon(Icons.favorite) : const Icon(Icons.favorite_border),
          onPressed: () {
            !favoritesList.items.contains(itemNo) ? favoritesList.add(itemNo) : favoritesList.remove(itemNo);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(favoritesList.items.contains(itemNo) ? 'Added to favorites.' : 'Removed from favorites.'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
      ),
    );
  }
}
