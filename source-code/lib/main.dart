import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart'; // Dodaj do pubspec.yaml
import 'package:process_run/process_run.dart'; // Dodaj do pubspec.yaml
import 'dart:io'; // Do obsługi FilePicker

void main() {
  runApp(const GamedeckApp());
}

class GamedeckApp extends StatelessWidget {
  const GamedeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gamedeck PC',
      theme: ThemeData.dark().copyWith(
        // Motyw ciemny, jak w Gamedeck
        scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Bardzo ciemny szary
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212), // Ciemniejszy pasek
        ),
        cardColor: const Color(0xFF2A2A2A), // Kolor kart gier
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Colors.white70),
          labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007BFF), // Niebieski przycisk
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ),
      home: const GamedeckHomePage(),
    );
  }
}

class Game {
  final String name;
  final String path;

  Game({required this.name, required this.path});
}

class GamedeckHomePage extends StatefulWidget {
  const GamedeckHomePage({super.key});

  @override
  State<GamedeckHomePage> createState() => _GamedeckHomePageState();
}

class _GamedeckHomePageState extends State<GamedeckHomePage> {
  List<Game> games = [];

  Future<void> _addGame() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['exe'],
    );

    if (result != null) {
      PlatformFile file = result.files.first;
      String? filePath = file.path;
      if (filePath != null) {
        String gameName = file.name.replaceAll('.exe', '').replaceAll('_', ' ').trim();
        setState(() {
          games.add(Game(name: gameName, path: filePath));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dodano grę: $gameName')),
        );
      }
    }
  }

  Future<void> _launchGame(String path) async {
    try {
      // Uruchamia plik .exe, 'runExecutable' jest multiplatformowe
      await runExecutable(path, []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uruchomiono grę: ${Uri.file(path).pathSegments.last}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd podczas uruchamiania gry: $e')),
      );
      print('Błąd uruchamiania: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GAMEDECK PC', style: TextStyle(fontSize: 24)),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _addGame,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj Grę'),
            ),
          ),
        ],
      ),
      body: games.isEmpty
          ? const Center(
              child: Text(
                'Brak gier w bibliotece.\nDodaj swoją pierwszą grę!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300, // Maksymalna szerokość kafelka
                childAspectRatio: 0.75, // Proporcje kafelka (np. 3:4)
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return GameCard(
                  game: game,
                  onPlay: () => _launchGame(game.path),
                );
              },
            ),
    );
  }
}

class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onPlay;

  const GameCard({super.key, required this.game, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8, // Podniesienie dla efektu cienia
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // Ważne dla zaokrąglenia obrazka
      child: InkWell( // Pozwala na klikanie całej karty
        onTap: onPlay,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.network(
                // Tutaj będziemy dodawać dynamiczne okładki w przyszłości
                'https://via.placeholder.com/200x260/2A2A2A/FFFFFF?text=${game.name.substring(0, 1)}', // Placeholder
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('GRAJ'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40), // Pełna szerokość
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


