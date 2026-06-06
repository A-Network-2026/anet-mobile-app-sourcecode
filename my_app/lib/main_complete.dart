import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:video_player/video_player.dart';
import 'api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSession();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.cyanAccent,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: token == null ? const AuthPage() : const MainTabPage(),
    );
  }
}

/// =======================
/// ✨ PARTICLES BACKGROUND
/// =======================
class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  final List<Offset> particles = List.generate(
    80,
    (_) => Offset(Random().nextDouble(), Random().nextDouble()),
  );

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        return CustomPaint(
          painter: ParticlePainter(particles, controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class ParticlePainter extends CustomPainter {
  final List<Offset> particles;
  final double progress;

  ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.cyanAccent.withOpacity(0.6);

    for (var p in particles) {
      final dx = (p.dx * size.width + progress * 150) % size.width;
      final dy = (p.dy * size.height + progress * 100) % size.height;

      canvas.drawCircle(Offset(dx, dy), 2.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// =======================
/// 🔐 AUTH PAGE
/// =======================
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool isLogin = true;
  String message = "";
  bool isLoading = false;

  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() {
    _videoController = VideoPlayerController.asset("assets/video.mp4")
      ..initialize()
          .then((_) {
            _videoController.setLooping(true);
            _videoController.setVolume(0);
            _videoController.play();
            setState(() {});
          })
          .catchError((_) {
            debugPrint("Video error");
          });
  }

  void submit() async {
    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      setState(() => message = "Please fill all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      final deviceId = await getOrCreateDeviceId();
      final res = isLogin
          ? await login(emailCtrl.text, passCtrl.text, deviceId)
          : await register(emailCtrl.text, passCtrl.text, deviceId);

      if (res["token"] != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainTabPage()),
          );
        }
      } else {
        if (!mounted) {
          return;
        }
        setState(() => message = res["error"] ?? "Authentication failed");
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => message = "Error: $e");
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: _videoController.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black,
                          Color(0xFF0F2027),
                          Color(0xFF2C5364),
                        ],
                      ),
                    ),
                  ),
          ),
          const ParticleBackground(),
          Container(color: Colors.black.withOpacity(0.6)),
          Center(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(25),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.2),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.cyanAccent, Colors.blue],
                      ).createShader(bounds),
                      child: const Text(
                        "⛏ A-Network",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Text(
                      "Crypto Mining Platform",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 25),
                    TextField(
                      controller: emailCtrl,
                      enabled: !isLoading,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Email",
                        prefixIcon: const Icon(
                          Icons.email,
                          color: Colors.white54,
                        ),
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Colors.cyanAccent,
                            width: 0.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.cyanAccent.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      enabled: !isLoading,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: "Password",
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: Colors.white54,
                        ),
                        hintStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Colors.cyanAccent,
                            width: 0.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Colors.cyanAccent.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          elevation: 15,
                          shadowColor: Colors.cyanAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black,
                                  ),
                                ),
                              )
                            : Text(
                                isLogin ? "Login" : "Register",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin ? "Create New Account" : "Back to Login",
                        style: const TextStyle(color: Colors.cyanAccent),
                      ),
                    ),
                    if (message.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          message,
                          style: const TextStyle(color: Colors.redAccent),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// 👥 MAIN TAB PAGE
/// =======================
class MainTabPage extends StatefulWidget {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();
}

class _MainTabPageState extends State<MainTabPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: const [MiningPage(), LeaderboardPage(), ProfilePage()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedTab,
        onTap: (index) => setState(() => _selectedTab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.flash_on), label: "Mine"),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: "Leaderboard",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

/// =======================
/// ⛏ MINING PAGE
/// =======================
class MiningPage extends StatefulWidget {
  const MiningPage({super.key});

  @override
  State<MiningPage> createState() => _MiningPageState();
}

class _MiningPageState extends State<MiningPage> with WidgetsBindingObserver {
  double balance = 0;
  bool isMining = false;
  int remainingSeconds = 0;
  bool isLoading = true;

  Map<String, dynamic>? network;
  Map<String, dynamic>? myStatus;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isMining) {
      _syncMiningStatus();
    }
  }

  Future<void> _loadData() async {
    try {
      final netRes = await getNetworkStats();
      final statusRes = await getMiningStatus();

      if (mounted) {
        setState(() {
          network = netRes;
          myStatus = statusRes;

          if (statusRes["isMining"] == true) {
            isMining = true;
            remainingSeconds = statusRes["remainingSeconds"] ?? 0;
            if (remainingSeconds > 0) {
              _startTimer();
            }
          } else {
            isMining = false;
            remainingSeconds = 0;
          }

          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Load data error: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _syncMiningStatus() async {
    try {
      final res = await getMiningStatus();
      if (mounted && isMining) {
        setState(() {
          if (res["remainingSeconds"] != null) {
            remainingSeconds = res["remainingSeconds"];
          }
        });
      }
    } catch (e) {
      debugPrint("Sync error: $e");
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
      } else {
        timer.cancel();
        _completeMining();
      }
    });
  }

  Future<void> _startMining() async {
    try {
      await startMiningAPI();
      setState(() {
        isMining = true;
        remainingSeconds = 21600;
      });
      _startTimer();

      Future.delayed(const Duration(seconds: 2), _syncMiningStatus);
    } catch (e) {
      _showError("Mining failed: $e");
    }
  }

  Future<void> _completeMining() async {
    try {
      final res = await completeMiningAPI();

      if (mounted) {
        setState(() {
          balance += (res["reward"] ?? 0).toDouble();
          isMining = false;
          remainingSeconds = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("⛏ Mined: ${res["reward"]} ANET"),
            backgroundColor: Colors.greenAccent,
            duration: const Duration(seconds: 3),
          ),
        );

        _loadData();
      }
    } catch (e) {
      _showError("Complete failed: $e");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  String _formatTime(int seconds) {
    if (seconds <= 0) return "00:00:00";
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    return "$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("⛏ Mining"),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const ParticleBackground(),
          Container(color: Colors.black.withOpacity(0.6)),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      /// Balance Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.cyan, Colors.blue.shade900],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withOpacity(0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Your Balance",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "\$${balance.toStringAsFixed(6)} ANET",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Mining Status
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          border: Border.all(
                            color: isMining
                                ? Colors.greenAccent
                                : Colors.white24,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            Text(
                              isMining ? "⛏ Mining Active" : "Ready to Mine",
                              style: TextStyle(
                                color: isMining
                                    ? Colors.greenAccent
                                    : Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _formatTime(remainingSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isMining
                                  ? "(Time remaining to complete mining)"
                                  : "(6 hours required)",
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Mining Button
                      ElevatedButton(
                        onPressed: isMining ? null : _startMining,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.grey,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 15,
                          shadowColor: Colors.cyanAccent,
                        ),
                        child: Text(
                          isMining ? "Mining in Progress..." : "Start Mining",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Network Stats
                      if (network != null) ...[
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 10),
                        const Text(
                          "Network Statistics",
                          style: TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _statTile(
                          "Total Users",
                          network!["totalUsers"].toString(),
                        ),
                        _statTile(
                          "Eligible Users",
                          network!["eligibleUsers"].toString(),
                        ),
                        _statTile(
                          "Halving Level",
                          network!["halvingCount"].toString(),
                        ),
                        _statTile(
                          "Total Mined",
                          network!["totalMined"]?.toString() ?? "0",
                        ),
                        _statTile(
                          "Mining Rate",
                          "${network!["currentRate"]} ANET/hour",
                        ),
                        _statTile(
                          "Next Halving",
                          "${network!["nextHalvingProgress"]}/${network!["nextHalvingTarget"]}",
                        ),
                      ],
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// 🏆 LEADERBOARD PAGE
/// =======================
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<dynamic>? leaderboard;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final data = await getLeaderboard();
      if (mounted) {
        setState(() {
          leaderboard = data;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Leaderboard error: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("🏆 Leaderboard"),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const ParticleBackground(),
          Container(color: Colors.black.withOpacity(0.6)),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : leaderboard == null || leaderboard!.isEmpty
              ? const Center(child: Text("No data available"))
              : RefreshIndicator(
                  onRefresh: _loadLeaderboard,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: leaderboard!.length,
                    itemBuilder: (context, index) {
                      final user = leaderboard![index];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          border: Border.all(
                            color: index < 3
                                ? const Color.fromARGB(255, 255, 215, 0)
                                : Colors.white24,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Text(
                              "#${index + 1}",
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user["email"] ?? "Unknown",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "${user["successful_sessions"]} sessions",
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "\$${user["balance"]?.toStringAsFixed(4) ?? "0"}",
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}

/// =======================
/// 👤 PROFILE PAGE
/// =======================
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? userRank;
  Map<String, dynamic>? networkStats;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final rank = await getUserRank();
      final stats = await getNetworkStats();

      if (mounted) {
        setState(() {
          userRank = rank;
          networkStats = stats;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Profile error: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("👤 Profile"),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const ParticleBackground(),
          Container(color: Colors.black.withOpacity(0.6)),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      /// User Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.cyan, Colors.blue.shade900],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.person, size: 40),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              currentUserId?.toString() ??
                                  "User $currentUserId",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              "Crypto Miner",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Rank Section
                      if (userRank != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  const Text(
                                    "Your Rank",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    "#${userRank!["rank"] ?? "N/A"}",
                                    style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  const Text(
                                    "Total Balance",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    "\$${(userRank!["balance"] ?? 0).toStringAsFixed(4)}",
                                    style: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),

                      /// Network Info
                      if (networkStats != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Network Info",
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _profileStat(
                              "Active Users",
                              networkStats!["totalUsers"].toString(),
                            ),
                            _profileStat(
                              "Eligible Users",
                              networkStats!["eligibleUsers"].toString(),
                            ),
                            _profileStat(
                              "Total Mined",
                              networkStats!["totalMined"]?.toString() ?? "0",
                            ),
                            _profileStat(
                              "Current Halving",
                              networkStats!["halvingCount"].toString(),
                            ),
                          ],
                        ),

                      const SizedBox(height: 30),

                      /// Logout Button
                      ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Logout"),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _profileStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
