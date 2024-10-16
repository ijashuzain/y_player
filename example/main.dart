import 'package:flutter/material.dart';
import 'package:y_player/y_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('YPlayer Example'),
        ),
        body: const Column(
          children: [
            YPlayer(
              youtubeUrl:
                  "https://www.youtube.com/watch?v=9xwazD5SyVg&pp=ygULZHVtbXkgdmlkZW8%3D",
              autoPlay: false,
            ),
          ],
        ),
      ),
    );
  }
}
