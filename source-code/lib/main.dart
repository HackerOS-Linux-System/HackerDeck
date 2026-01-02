import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'dart:math';
import 'dart:convert';

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
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
        ),
        cardColor: const Color(0xFF2A2A2A),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Colors.white70),
          labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007BFF),
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
  String? coverPath;
  bool isFavorite;

  Game({
    required this.name,
    required this.path,
    this.coverPath,
    this.isFavorite = false,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      name: json['name'],
      path: json['path'],
      coverPath: json['coverPath'],
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'path': path,
      'coverPath': coverPath,
      'isFavorite': isFavorite,
    };
  }
}

class GamedeckHomePage extends StatefulWidget {
  const GamedeckHomePage({super.key});

  @override
  State<GamedeckHomePage> createState() => _GamedeckHomePageState();
}

class _GamedeckHomePageState extends State<GamedeckHomePage> {
  List<Game> games = [];
  String? backgroundPath;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final gamesFile = File('games.json');
      if (await gamesFile.exists()) {
        final jsonStr = await gamesFile.readAsString();
        final List<dynamic> jsonList = json.decode(jsonStr)['games'];
        setState(() {
          games = jsonList.map((json) => Game.fromJson(json)).toList();
        });
      }

      final bgFile = File('background.txt');
      if (await bgFile.exists()) {
        backgroundPath = await bgFile.readAsString();
        setState(() {});
      }
    } catch (e) {
      print('Error loading data: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      final gamesFile = File('games.json');
      final map = {'games': games.map((g) => g.toJson()).toList()};
      await gamesFile.writeAsString(json.encode(map));

      if (backgroundPath != null) {
        final bgFile = File('background.txt');
        await bgFile.writeAsString(backgroundPath!);
      }
    } catch (e) {
      print('Error saving data: $e');
    }
  }

  Future<void> _addGame() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );
    if (result != null) {
      PlatformFile file = result.files.first;
      String? filePath = file.path;
      if (filePath != null) {
        String gameName = p.basenameWithoutExtension(file.name).replaceAll('_', ' ').trim();

        // Pick cover image (optional)
        FilePickerResult? coverResult = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );
        String? coverPath = coverResult?.files.first.path;

        setState(() {
          games.add(Game(name: gameName, path: filePath, coverPath: coverPath));
        });
        await _saveData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dodano grę: $gameName')),
        );
      }
    }
  }

  Future<void> _launchGame(String path) async {
    try {
      await Process.start(path, []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uruchomiono grę: ${p.basename(path)}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd podczas uruchamiania gry: $e')),
      );
      print('Błąd uruchamiania: $e');
    }
  }

  Future<void> _launchRandom() async {
    if (games.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak gier do losowego uruchomienia')),
      );
      return;
    }
    final randomIndex = Random().nextInt(games.length);
    _launchGame(games[randomIndex].path);
  }

  void _showOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opcje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                FilePickerResult? res = await FilePicker.platform.pickFiles(
                  type: FileType.image,
                );
                if (res != null) {
                  setState(() {
                    backgroundPath = res.files.first.path;
                  });
                  await _saveData();
                }
              },
              child: const Text('Zmień tapetę'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zamknij'),
          ),
        ],
      ),
    );
  }

  Widget _buildGameList(List<Game> gameList) {
    if (gameList.isEmpty) {
      return const Center(
        child: Text(
          'Brak gier w tej sekcji.',
          style: TextStyle(fontSize: 18, color: Colors.white70),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 0.75,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: gameList.length,
      itemBuilder: (context, index) {
        final game = gameList[index];
        return GameCard(
          game: game,
          onPlay: () => _launchGame(game.path),
          onToggleFavorite: () {
            setState(() {
              game.isFavorite = !game.isFavorite;
            });
            _saveData();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Wszystkie'),
              Tab(text: 'Ulubione'),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: backgroundPath == null
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1A1A), Color(0xFF001A4D)],
                  )
                : null,
            image: backgroundPath != null
                ? DecorationImage(
                    image: FileImage(File(backgroundPath!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: games.isEmpty
              ? const Center(
                  child: Text(
                    'Brak gier w bibliotece.\nDodaj swoją pierwszą grę!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                )
              : TabBarView(
                  children: [
                    _buildGameList(games),
                    _buildGameList(games.where((g) => g.isFavorite).toList()),
                  ],
                ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: const Color(0xFF121212),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Nawiguj'),
              ),
              ElevatedButton.icon(
                onPressed: _showOptions,
                icon: const Icon(Icons.settings),
                label: const Text('Opcje'),
              ),
              ElevatedButton.icon(
                onPressed: _launchRandom,
                icon: const Icon(Icons.shuffle),
                label: const Text('Losowa Gra'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameCard extends StatelessWidget {
  final Game game;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;

  const GameCard({
    super.key,
    required this.game,
    required this.onPlay,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final placeholderUrl =
        'https://via.placeholder.com/200x260/2A2A2A/FFFFFF?text=${game.name.substring(0, 1)}';

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPlay,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: game.coverPath != null
                  ? Image.file(
                      File(game.coverPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Image.network(
                        placeholderUrl,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.network(
                      placeholderUrl,
                      fit: BoxFit.cover,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          game.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          game.isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: game.isFavorite ? Colors.red : null,
                        ),
                        onPressed: onToggleFavorite,
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('GRAJ'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
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
