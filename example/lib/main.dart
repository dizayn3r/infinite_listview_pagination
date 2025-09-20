import 'package:flutter/material.dart';
import 'package:infinite_listview_pagination/infinite_listview_pagination.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pagination ListView Example',
      home: ExampleScreen(),
    );
  }
}

class User {
  final String name;
  final String email;

  User({required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    final nameObj = json['name'];
    final fullName =
        '${nameObj['first'] ?? ''} ${nameObj['last'] ?? ''}'.trim();
    return User(name: fullName, email: json['email'] ?? '');
  }
}

class ExampleScreen extends StatelessWidget {
  // pageSize 10 to match API limit nicely
  final PaginationController<User> controller =
      PaginationController(fetchPage: fetchUsers, pageSize: 20);

  ExampleScreen({super.key});

  static Future<List<User>> fetchUsers(int page) async {
    final uri = Uri.parse(
        'https://api.freeapi.app/api/v1/public/randomusers?page=$page&limit=20');
    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      throw Exception('Failed to load users: ${resp.statusCode}');
    }
    final dynamic decoded = json.decode(resp.body);

    Logger().d('Decoded JSON type: ${decoded.runtimeType}');

    List rawItems = [];

    if (decoded is Map<String, dynamic>) {
      // common key names: data, results, items
      if (decoded['data']['data'] is List) {
        rawItems = decoded['data']['data'] as List;
      } else if (decoded['results'] is List) {
        rawItems = decoded['results'] as List;
      } else if (decoded['items'] is List) {
        rawItems = decoded['items'] as List;
      } else {
        // Sometimes APIs nest payload under data as a Map
        // Try to find the first List value inside the map
        final firstList = decoded.values.firstWhere(
          (v) => v is List,
          orElse: () => null,
        );
        if (firstList is List) rawItems = firstList;
      }
    }

    if (rawItems.isEmpty) {
      // Defensive: if nothing parsed, throw an error so caller marks failure
      throw Exception('Unexpected JSON shape from API: ${decoded.runtimeType}');
    }

    return rawItems
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pagination ListView")),
      body: PaginationListView<User>(
        controller: controller,
        itemBuilder: (context, user) => ListTile(
          title: Text(user.name),
          subtitle: Text(user.email),
        ),
        enablePullToRefresh: true,
        onRefreshCompleted: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Refresh completed!")),
          );
        },
        footerBuilder: (context, status, items) {
          if (status == PaginationStatus.loading) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          } else if (status == PaginationStatus.end) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text("🎉 You've reached the end!"),
              ),
            );
          } else if (status == PaginationStatus.failure) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: ElevatedButton(
                  onPressed: controller.loadMore,
                  child: const Text("Retry loading more"),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
