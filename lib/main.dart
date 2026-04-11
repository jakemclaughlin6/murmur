// Temporary stub — Plan 08 replaces this with the full triple-catch + ProviderScope wiring.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('murmur'),
          ),
        ),
      ),
    ),
  );
}
