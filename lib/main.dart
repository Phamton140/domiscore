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
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: const Color(0xFFF3F4F6), // Light grey background
        primaryColor: const Color(0xFF7C3AED), // Indigo/Purple accent
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C3AED),
          brightness: Brightness.light,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF7C3AED),
          selectionColor: Color(0xFFDDD6FE),
          selectionHandleColor: Color(0xFF7C3AED),
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
  String _teamAName = 'NOSOTROS';
  String _teamBName = 'ELLOS';
  int _targetScore = 200;
  int _winsA = 0;
  int _winsB = 0;
  List<ScoreEntry> _scores = [];

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
        _teamAName = prefs.getString('teamAName') ?? 'NOSOTROS';
        _teamBName = prefs.getString('teamBName') ?? 'ELLOS';
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
      _checkWinCondition(vibrate: false);
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
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showWinDialog(tA >= _targetScore ? _teamAName : _teamBName);
        });
      }
    } else {
      _hasVibratedForCurrentWin = false;
    }
  }

  // Vibration sequence for win - approx 3 seconds
  Future<void> _triggerWinVibration() async {
    for (int i = 0; i < 15; i++) {
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  // Show winning dialog and add victory (Matches user's screenshot)
  void _showWinDialog(String winnerTeam) {
    final isTeamA = winnerTeam == _teamAName;
    
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
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF8B5CF6), // Purple
                    Color(0xFFD946EF), // Magenta
                    Color(0xFFEF4444), // Red
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFFFD700), // Gold Trophy
                    size: 80,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '¡FELICIDADES!',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    winnerTeam.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'HA GANADO LA PARTIDA',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      // Clean hand automatically when dialog is closed/dismissed
      _resetHandOnly();
    });
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

  // Dialog to edit team names (Matches Image 3)
  void _showEditNameDialog(bool isTeamA) {
    final currentName = isTeamA ? _teamAName : _teamBName;
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            'Editar nombre para $currentName',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 10,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                decoration: const InputDecoration(
                  counterText: "",
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF7C3AED), width: 2),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  setState(() {
                    if (isTeamA) {
                      _teamAName = newName.toUpperCase();
                    } else {
                      _teamBName = newName.toUpperCase();
                    }
                  });
                  _saveState();
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Dialog to edit target score (meta) (Matches Image 4)
  void _showEditTargetDialog() {
    final controller = TextEditingController(text: _targetScore.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text(
            'Cambiar Meta',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                decoration: const InputDecoration(
                  suffixText: 'pts',
                  suffixStyle: TextStyle(color: Colors.black54),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF7C3AED), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CANCELAR',
                style: TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF3E8FF), // Light purple background
                foregroundColor: const Color(0xFF7C3AED), // Dark purple text
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'CAMBIAR',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Dialog to confirm reset all (Matches Image 5)
  void _showConfirmResetAllDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text(
            'Reiniciar Todo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          content: const Text(
            '¿Seguro que quieres borrar victorias y puntos actuales?',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CANCELAR',
                style: TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _resetAll();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252), // Red button
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'CONFIRMAR',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Dialog to confirm reset hand
  void _showConfirmResetHandDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text(
            'Reiniciar Mano',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          content: const Text(
            '¿Seguro que quieres borrar los puntos de la mano actual? Las victorias se conservarán.',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CANCELAR',
                style: TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                _resetHandOnly();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800), // Orange button
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'CONFIRMAR',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Dialog to sum points - Matches exactly "Cambiar Meta" dialog structure
  void _showSumPointsDialog(bool isTeamA) {
    final teamName = isTeamA ? _teamAName : _teamBName;
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text(
            'Sumar para $teamName',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                decoration: const InputDecoration(
                  suffixText: 'pts',
                  suffixStyle: TextStyle(color: Colors.black54),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF7C3AED), width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.black26),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'CANCELAR',
                style: TextStyle(
                  color: Color(0xFF7C3AED),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = int.tryParse(controller.text);
                if (parsed != null && parsed > 0) {
                  _addScore(parsed, isTeamA);
                }
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF3E8FF), // Light purple background
                foregroundColor: const Color(0xFF7C3AED), // Dark purple text
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'SUMAR',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
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
          'DOMISCORE',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 1.2,
            color: Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          // Meta Button Pill
          GestureDetector(
            onTap: _showEditTargetDialog,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag,
                    color: Color(0xFF475569),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'META: $_targetScore',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Two Side-by-Side Gradient Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // Team A (Blue) Card
                  Expanded(
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF0F3EBA), Color(0xFF1E6CDB)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Team name with Pencil Edit Icon (Enlarged hit target)
                          GestureDetector(
                            onTap: () => _showEditNameDialog(true),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _teamAName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.edit,
                                    color: Colors.white70,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Huge Score
                          Text(
                            '$_totalA',
                            style: const TextStyle(
                              fontSize: 78,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          // Victories Label
                          Text(
                            '$_winsA ${_winsA == 1 ? 'VICTORIA' : 'VICTORIAS'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                          // SUMAR Button
                          SizedBox(
                            height: 36,
                            width: 100,
                            child: ElevatedButton(
                              onPressed: () => _showSumPointsDialog(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.18),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'SUMAR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Team B (Red) Card
                  Expanded(
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF9E0B24), Color(0xFFD91E36)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Team name with Pencil Edit Icon (Enlarged hit target)
                          GestureDetector(
                            onTap: () => _showEditNameDialog(false),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _teamBName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white70,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.edit,
                                    color: Colors.white70,
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Huge Score
                          Text(
                            '$_totalB',
                            style: const TextStyle(
                              fontSize: 78,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                          // Victories Label
                          Text(
                            '$_winsB ${_winsB == 1 ? 'VICTORIA' : 'VICTORIAS'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                              letterSpacing: 0.5,
                            ),
                          ),
                          // SUMAR Button
                          SizedBox(
                            height: 36,
                            width: 100,
                            child: ElevatedButton(
                              onPressed: () => _showSumPointsDialog(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.18),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'SUMAR',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
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
            const SizedBox(height: 24),
            // White History Card Panel
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      offset: Offset(0, -2),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    // Column Headers Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 40,
                            child: Text(
                              '#',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _teamAName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F3CC9),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _teamBName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF9E0B24),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 60,
                            child: Text(
                              'ACCIÓN',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.black38,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    // List of hands / Empty state
                    Expanded(
                      child: _scores.isEmpty
                          ? const Center(
                              child: Text(
                                'SIN JUGADAS REGISTRADAS',
                                style: TextStyle(
                                  color: Color(0xFFD1D5DB),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              itemCount: _scores.length,
                              itemBuilder: (context, index) {
                                final entry = _scores[index];
                                final reverseIndex = _scores.length - index;
                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Row(
                                            children: [
                                              // Index column
                                              SizedBox(
                                                width: 40,
                                                child: Text(
                                                  '$reverseIndex',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black38,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              // Score A
                                              Expanded(
                                                child: Text(
                                                  '${entry.scoreA}',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: entry.isDeleted
                                                        ? Colors.black26
                                                        : (entry.scoreA > 0
                                                            ? const Color(0xFF0F3CC9)
                                                            : Colors.black38),
                                                  ),
                                                ),
                                              ),
                                              // Score B
                                              Expanded(
                                                child: Text(
                                                  '${entry.scoreB}',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: entry.isDeleted
                                                        ? Colors.black26
                                                        : (entry.scoreB > 0
                                                            ? const Color(0xFF9E0B24)
                                                            : Colors.black38),
                                                  ),
                                                ),
                                              ),
                                              // Action button
                                              SizedBox(
                                                width: 60,
                                                child: IconButton(
                                                  icon: Icon(
                                                    entry.isDeleted
                                                        ? Icons.settings_backup_restore
                                                        : Icons.delete_outline,
                                                    color: entry.isDeleted
                                                        ? const Color(0xFF10B981) // Green restore
                                                        : const Color(0xFFF59E0B), // Orange delete
                                                    size: 22,
                                                  ),
                                                  onPressed: () => _toggleDeleteEntry(index),
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Full-row cross out line
                                          if (entry.isDeleted)
                                            Positioned(
                                              left: 45,
                                              right: 65,
                                              child: Container(
                                                height: 1.5,
                                                color: Colors.black38,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFF3F4F6),
                                      indent: 24,
                                      endIndent: 24,
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    // Bottom actions row (Matches Image 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: _showConfirmResetHandDialog,
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.refresh,
                                  color: Color(0xFFD97706),
                                  size: 18,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'REINICIAR MANO',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFD97706),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _showConfirmResetAllDialog,
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFEF4444),
                                  size: 18,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'REINICIAR TODO',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFEF4444),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Dedicated AdMob Banner Space (Keeps the screen clean and standard sized)
            Container(
              width: double.infinity,
              height: 60,
              color: const Color(0xFFF3F4F6),
              alignment: Alignment.center,
              child: Container(
                width: 320,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.ad_units, color: Colors.black26, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'ANUNCIO PUBLICITARIO',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black26,
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
}
