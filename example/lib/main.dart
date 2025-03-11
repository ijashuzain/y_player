import 'package:flutter/material.dart';
import 'package:y_player/y_player.dart';

void main() {
  YPlayerInitializer.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YPlayer Example'),
      ),
      body: const Column(
        children: [
          YPlayer(
            youtubeUrl: "https://www.youtube.com/watch?v=Rjw1319nwrQ",
            autoPlay: false,
          ),
        ],
      ),
    );
  }
}
