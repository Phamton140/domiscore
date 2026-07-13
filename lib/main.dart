import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/score_entry.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const DomiScoreApp());
}

class DomiScoreApp extends StatelessWidget {
  const DomiScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DomiScore',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ScoreScreen(),
    );
  }
}

class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen> {
  // App State
  String _teamAName = 'Nosotros';
  String _teamBName = 'Ellos';
  int _targetScore = 200;
  int _winsA = 0;
  int _winsB = 0;
  List<ScoreEntry> _scores = [];

  // Re-entry check for win vibration to prevent vibration loops
  bool _hasVibratedForCurrentWin = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  // Load state from SharedPreferences
  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _teamAName = prefs.getString('teamAName') ?? 'Nosotros';
        _teamBName = prefs.getString('teamBName') ?? 'Ellos';
        _targetScore = prefs.getInt('targetScore') ?? 200;
        _winsA = prefs.getInt('winsA') ?? 0;
        _winsB = prefs.getInt('winsB') ?? 0;
        
        final scoresJson = prefs.getString('scoresList');
        if (scoresJson != null) {
          final decoded = jsonDecode(scoresJson) as List;
          _scores = decoded
              .map((item) => ScoreEntry.fromMap(item as Map<String, dynamic>))
              .toList();
        }
      });
      _checkWinCondition(vibrate: false); // Check without vibrating on startup
    } catch (e) {
      debugPrint("Error loading state: $e");
    }
  }

  // Save state to SharedPreferences
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('teamAName', _teamAName);
      await prefs.setString('teamBName', _teamBName);
      await prefs.setInt('targetScore', _targetScore);
      await prefs.setInt('winsA', _winsA);
      await prefs.setInt('winsB', _winsB);
      
      final scoresMap = _scores.map((e) => e.toMap()).toList();
      await prefs.setString('scoresList', jsonEncode(scoresMap));
    } catch (e) {
      debugPrint("Error saving state: $e");
    }
  }

  // Get active totals
  int get _totalA => _scores
      .where((e) => !e.isDeleted)
      .fold(0, (sum, item) => sum + item.scoreA);

  int get _totalB => _scores
      .where((e) => !e.isDeleted)
      .fold(0, (sum, item) => sum + item.scoreB);

  // Add Score Entry
  void _addScore(int points, bool isTeamA) {
    setState(() {
      if (isTeamA) {
        _scores.insert(0, ScoreEntry(scoreA: points, scoreB: 0));
      } else {
        _scores.insert(0, ScoreEntry(scoreA: 0, scoreB: points));
      }
    });
    _saveState();
    _checkWinCondition(vibrate: true);
  }

  // Toggle delete on score entry
  void _toggleDeleteEntry(int index) {
    setState(() {
      _scores[index].isDeleted = !_scores[index].isDeleted;
    });
    _saveState();
    
    // If we marked it as deleted, show snackbar with undo
    if (_scores[index].isDeleted) {
      final wasTeamA = _scores[index].scoreA > 0;
      final points = wasTeamA ? _scores[index].scoreA : _scores[index].scoreB;
      final teamName = wasTeamA ? _teamAName : _teamBName;

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se eliminó la anotación de $points pts para $teamName.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1E293B),
          action: SnackBarAction(
            label: 'DESHACER',
            textColor: Colors.blueAccent,
            onPressed: () {
              setState(() {
                _scores[index].isDeleted = false;
              });
              _saveState();
              _checkWinCondition(vibrate: true);
            },
          ),
        ),
      );
    }
    
    _checkWinCondition(vibrate: true);
  }

  // Check if someone reached the target score
  void _checkWinCondition({required bool vibrate}) {
    final tA = _totalA;
    final tB = _totalB;

    if (tA >= _targetScore || tB >= _targetScore) {
      if (!_hasVibratedForCurrentWin) {
        if (vibrate) {
          _triggerWinVibration();
        }
        _hasVibratedForCurrentWin = true;
        
        // Show winner dialog
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showWinDialog(tA >= _targetScore ? _teamAName : _teamBName);
        });
      }
    } else {
      // Reset win vibration lock if scores are below meta (e.g. after deletion or reset)
      _hasVibratedForCurrentWin = false;
    }
  }

  // Vibration sequence for win
  Future<void> _triggerWinVibration() async {
    for (int i = 0; i < 3; i++) {
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 250));
    }
  }

  // Show winning dialog and add victory
  void _showWinDialog(String winnerTeam) {
    final isTeamA = winnerTeam == _teamAName;
    
    // Automatically increment wins (only if not already added to avoid duplicates)
    setState(() {
      if (isTeamA) {
        _winsA++;
      } else {
        _winsB++;
      }
    });
    _saveState();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              const Text('¡Partida Terminada!'),
            ],
          ),
          content: Text(
            'El equipo "$winnerTeam" ha alcanzado la meta de $_targetScore puntos y gana la partida.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetHandOnly();
              },
              child: const Text('Comenzar Nueva Partida', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  // Reset current scores (keep wins)
  void _resetHandOnly() {
    setState(() {
      _scores.clear();
      _hasVibratedForCurrentWin = false;
    });
    _saveState();
  }

  // Reset entire match (scores and wins)
  void _resetAll() {
    setState(() {
      _scores.clear();
      _winsA = 0;
      _winsB = 0;
      _hasVibratedForCurrentWin = false;
    });
    _saveState();
  }

  // Dialog to edit team names
  void _showEditNamesDialog() {
    final nameAController = TextEditingController(text: _teamAName);
    final nameBController = TextEditingController(text: _teamBName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Editar Equipos'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameAController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Bando Azul',
                  labelStyle: TextStyle(color: Colors.blueAccent),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameBController,
                decoration: const InputDecoration(
                  labelText: 'Nombre Bando Rojo',
                  labelStyle: TextStyle(color: Colors.redAccent),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.redAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _teamAName = nameAController.text.trim().isNotEmpty
                      ? nameAController.text.trim()
                      : 'Nosotros';
                  _teamBName = nameBController.text.trim().isNotEmpty
                      ? nameBController.text.trim()
                      : 'Ellos';
                });
                _saveState();
                Navigator.of(context).pop();
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  // Dialog to edit target score (meta)
  void _showEditTargetDialog() {
    final controller = TextEditingController(text: _targetScore.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Definir Meta de Puntos'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Puntos de Meta',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text);
                if (parsed != null && parsed > 0) {
                  setState(() {
                    _targetScore = parsed;
                  });
                  _saveState();
                  _checkWinCondition(vibrate: true);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  // Bottom Sheet to add score
  void _showAddScoreBottomSheet() {
    int enteredPoints = 0;
    bool isTeamA = true; // Defaults to Team A (Blue)
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Anotar Puntos de la Mano',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // Team selector buttons
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => isTeamA = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: isTeamA
                                  ? const LinearGradient(
                                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                                    )
                                  : null,
                              color: isTeamA ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isTeamA ? Colors.transparent : Colors.blue.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _teamAName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isTeamA ? Colors.white : Colors.blue.shade300,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => isTeamA = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: !isTeamA
                                  ? const LinearGradient(
                                      colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
                                    )
                                  : null,
                              color: !isTeamA ? null : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: !isTeamA ? Colors.transparent : Colors.red.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _teamBName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !isTeamA ? Colors.white : Colors.red.shade300,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Display currently typed score
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$enteredPoints pts',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: isTeamA ? const Color(0xFF60A5FA) : const Color(0xFFF87171),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quick add presets
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [20, 25, 30, 40, 50, 75, 100].map((preset) {
                      return ElevatedButton(
                        onPressed: () {
                          setModalState(() {
                            enteredPoints = preset;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('+$preset'),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  // Custom input pad row & Clear button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          setModalState(() => enteredPoints = 0);
                        },
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        label: const Text('Limpiar', style: TextStyle(color: Colors.grey)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      // Custom points dialog button
                      OutlinedButton.icon(
                        onPressed: () async {
                          final customVal = await _showCustomPointsInputDialog();
                          if (customVal != null) {
                            setModalState(() {
                              enteredPoints = customVal;
                            });
                          }
                        },
                        icon: const Icon(Icons.keyboard, color: Colors.blueAccent),
                        label: const Text('Teclado', style: TextStyle(color: Colors.blueAccent)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Save score button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: enteredPoints <= 0
                          ? null
                          : () {
                              _addScore(enteredPoints, isTeamA);
                              Navigator.of(context).pop();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isTeamA ? const Color(0xFF2563EB) : const Color(0xFFDC2626),
                        disabledBackgroundColor: Colors.grey.shade800,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Anotar Mano',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Popup input for entering custom scores not in presets
  Future<int?> _showCustomPointsInputDialog() async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Ingresar Puntos Personalizados'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              hintText: 'Ej. 18',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                final val = int.tryParse(controller.text);
                Navigator.of(context).pop(val);
              },
              child: const Text('Aceptar', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DomiScore',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Open Settings Sheet or Menu
              _showSettingsBottomSheet();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scores header - Prominent for distant reading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  // Team A (Blue) Panel
                  Expanded(
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)], // Darker Blue to Bright Blue
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Team name and wins
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _teamAName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_winsA ${_winsA == 1 ? 'victoria' : 'victorias'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white60,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Big Score
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 24.0),
                              child: Text(
                                '$_totalA',
                                style: const TextStyle(
                                  fontSize: 76,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Team B (Red) Panel
                  Expanded(
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFB91C1C), Color(0xFFEF4444)], // Darker Red to Bright Red
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Team name and wins
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _teamBName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_winsB ${_winsB == 1 ? 'victoria' : 'victorias'}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white60,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Big Score
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 24.0),
                              child: Text(
                                '$_totalB',
                                style: const TextStyle(
                                  fontSize: 76,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Meta indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'META: $_targetScore PTS',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            
            // History label and separator
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
              child: Row(
                children: [
                  Text(
                    'Historial de Manos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Spacer(),
                  Text(
                    '(Arrastra o pulsa para eliminar)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            
            // Score History List (scrollable)
            Expanded(
              child: _scores.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sports_esports, size: 48, color: Colors.blue.withOpacity(0.2)),
                          const SizedBox(height: 8),
                          Text(
                            'No hay anotaciones registradas',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _scores.length,
                      itemBuilder: (context, index) {
                        final entry = _scores[index];
                        return Dismissible(
                          key: UniqueKey(), // Use UniqueKey to support toggle states correctly
                          direction: DismissDirection.horizontal,
                          onDismissed: (_) {
                            _toggleDeleteEntry(index);
                          },
                          background: Container(
                            color: Colors.red.withOpacity(0.2),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20.0),
                            child: const Icon(Icons.delete, color: Colors.red),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red.withOpacity(0.2),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20.0),
                            child: const Icon(Icons.delete, color: Colors.red),
                          ),
                          child: InkWell(
                            onTap: () {
                              _toggleDeleteEntry(index);
                            },
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                                  child: Row(
                                    children: [
                                      // Score A
                                      Expanded(
                                        child: Text(
                                          '${entry.scoreA}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: entry.isDeleted ? FontWeight.normal : FontWeight.bold,
                                            color: entry.isDeleted
                                                ? Colors.blue.withOpacity(0.25)
                                                : (entry.scoreA > 0 ? const Color(0xFF60A5FA) : Colors.white60),
                                            decoration: entry.isDeleted ? TextDecoration.lineThrough : null,
                                            decorationColor: Colors.red,
                                            decorationThickness: 2.0,
                                          ),
                                        ),
                                      ),
                                      
                                      // Divider indicator
                                      Container(
                                        height: 24,
                                        width: 1.5,
                                        color: Colors.grey.shade800,
                                      ),
                                      
                                      // Score B
                                      Expanded(
                                        child: Text(
                                          '${entry.scoreB}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: entry.isDeleted ? FontWeight.normal : FontWeight.bold,
                                            color: entry.isDeleted
                                                ? Colors.red.withOpacity(0.25)
                                                : (entry.scoreB > 0 ? const Color(0xFFF87171) : Colors.white60),
                                            decoration: entry.isDeleted ? TextDecoration.lineThrough : null,
                                            decorationColor: Colors.red,
                                            decorationThickness: 2.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Divider(
                                  height: 1,
                                  color: Colors.grey.shade900,
                                  indent: 24,
                                  endIndent: 24,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            
            // Anotación trigger button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _showAddScoreBottomSheet,
                  icon: const Icon(Icons.add, color: Colors.white, size: 24),
                  label: const Text(
                    'Anotar Puntos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    elevation: 4,
                    shadowColor: Colors.blue.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            
            // Standard AdMob Banner space
            Container(
              width: double.infinity,
              height: 56, // Standard mobile banner size (50-60 pixels)
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF020617), // Slate 950
                border: Border(
                  top: BorderSide(color: Color(0xFF1E293B), width: 1),
                ),
              ),
              child: const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.ad_units, color: Colors.white30, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Espacio reservado para Publicidad',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog to handle all settings
  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Configuración y Opciones',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blueAccent),
                title: const Text('Editar nombres de bandos'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showEditNamesDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.blueAccent),
                title: const Text('Cambiar meta de puntos'),
                subtitle: Text('Meta actual: $_targetScore pts'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showEditTargetDialog();
                },
              ),
              const Divider(color: Colors.white10),
              ListTile(
                leading: const Icon(Icons.restart_alt, color: Colors.orangeAccent),
                title: const Text('Reiniciar mano actual'),
                subtitle: const Text('Pone los puntos actuales a 0. Mantiene las victorias.'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showConfirmResetDialog(false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.redAccent),
                title: const Text('Reiniciar partida completa'),
                subtitle: const Text('Reinicia puntos y marcador de victorias.'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showConfirmResetDialog(true);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // Dialog to confirm reset
  void _showConfirmResetDialog(bool resetAllMatches) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(resetAllMatches ? '¿Reiniciar Todo?' : '¿Reiniciar Mano?'),
          content: Text(
            resetAllMatches
                ? 'Esta acción reiniciará los puntos a cero y borrará el contador de victorias de ambos equipos. ¿Proceder?'
                : 'Esta acción borrará todas las anotaciones de la mano actual. Las victorias se mantendrán. ¿Proceder?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (resetAllMatches) {
                  _resetAll();
                } else {
                  _resetHandOnly();
                }
                Navigator.of(context).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(resetAllMatches ? 'Partida reiniciada por completo.' : 'Mano actual reiniciada.'),
                    backgroundColor: const Color(0xFF1E293B),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Reiniciar', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }
}
