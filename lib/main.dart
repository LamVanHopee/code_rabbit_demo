import 'package:code_rabbit_test/models/favorites.dart';
import 'package:code_rabbit_test/screens/favorites.dart';
import 'package:code_rabbit_test/screens/home.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const TestingApp());
}

GoRouter router() {
  return GoRouter(
    routes: [
      GoRoute(
        path: HomePage.rn,
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(
            path: FavoritesPage.routeName,
            builder: (context, state) => const FavoritesPage(),
          ),
        ],
      ),
    ],
  );
}

class TestingApp extends StatelessWidget {
  const TestingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<Favorites>(
      create: (context) => Favorites(),
      child: MaterialApp.router(
        title: 'Testing Sample',
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        routerConfig: router(),
      ),
    );
  }
}