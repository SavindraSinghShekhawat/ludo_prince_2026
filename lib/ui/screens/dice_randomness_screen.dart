import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../controllers/ludo_controller.dart';
import '../widgets/shared_ui.dart';
import '../../utils/colors.dart';

class DiceRandomnessScreen extends StatefulWidget {
  const DiceRandomnessScreen({super.key});

  @override
  State<DiceRandomnessScreen> createState() => _DiceRandomnessScreenState();
}

class _DiceRandomnessScreenState extends State<DiceRandomnessScreen> {
  final Map<int, int> _distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

  int _totalRolls = 0;
  bool _isRunning = false;
  final int _targetRolls = 100000000;

  void _runSimulation() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _totalRolls = 0;
      for (var i = 1; i <= 6; i++) {
        _distribution[i] = 0;
      }
    });

    DateTime lastUiUpdate = DateTime.now();

    while (_totalRolls < _targetRolls && _isRunning) {
      final progress = _totalRolls / _targetRolls;
      int currentBatchSize;
      int currentDelay = 0;

      if (_totalRolls < 15000) {
        // Phase 1: Refined Learning Phase (Faster than before)
        // Batch size 5 -> 2000, delay 30ms -> 0ms
        final phaseProgress = _totalRolls / 15000;
        currentBatchSize = (5 + (phaseProgress * 2000)).toInt();
        currentDelay = (30 * (1 - phaseProgress)).toInt().clamp(0, 30);
      } else {
        // Phase 2: Verification Phase (High Speed)
        currentBatchSize = (2000 + (progress * progress * 8000000)).toInt();
      }

      currentBatchSize = currentBatchSize.clamp(1, 200000);
      currentBatchSize = currentBatchSize.clamp(1, _targetRolls - _totalRolls);

      if (currentDelay > 0) {
        await Future.delayed(Duration(milliseconds: currentDelay));
      } else {
        await Future.delayed(Duration.zero);
      }

      if (!mounted || !_isRunning) break;

      // Tight loop for batch simulation
      for (int i = 0; i < currentBatchSize; i++) {
        final val = LudoController.generateDiceValue();
        _distribution[val] = (_distribution[val] ?? 0) + 1;
      }
      _totalRolls += currentBatchSize;

      // Throttle UI updates to ~30 FPS for smoothness
      final now = DateTime.now();
      if (now.difference(lastUiUpdate).inMilliseconds > 33 ||
          _totalRolls >= _targetRolls) {
        setState(() {});
        lastUiUpdate = now;
      }
    }

    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _stopSimulation() {
    setState(() {
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        appBar: AppBar(title: const Text('DICE FAIRNESS CHECK')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _buildInfoCard(),
                const SizedBox(height: 32),
                _buildChart(),
                const SizedBox(height: 32),
                _buildStats(),
                const SizedBox(height: 48),
                _buildControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryCyan.withAlpha(40),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.casino, color: AppColors.primaryCyan),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Simulation Engine",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Verifying 100,000,000 rolls",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              tween: Tween<double>(
                begin: 0,
                end: _targetRolls > 0 ? _totalRolls / _targetRolls : 0,
              ),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white.withAlpha(10),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.imperialJade,
                ),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "${(_totalRolls / 1000000).toStringAsFixed(1)}M / 100M rolls",
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    // Find max to scale bars
    int maxVal = 0;
    _distribution.forEach((k, v) {
      if (v > maxVal) maxVal = v;
    });

    return AspectRatio(
      aspectRatio: 1.4,
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(6, (index) {
            final diceVal = index + 1;
            final count = _distribution[diceVal] ?? 0;
            final heightFactor = maxVal > 0 ? count / maxVal : 0.0;

            return _buildBar(diceVal, heightFactor, count);
          }),
        ),
      ),
    );
  }

  Widget _buildBar(int label, double heightFactor, int count) {
    final colors = [
      AppColors.primaryCyan,
      AppColors.midnightSapphire,
      AppColors.imperialAmber,
      AppColors.imperialJade,
      AppColors.crimsonVelvet,
      AppColors.starPlatinum,
    ];

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              count >= 1000000
                  ? "${(count / 1000000).toStringAsFixed(1)}M"
                  : count >= 1000
                      ? "${(count / 1000).toStringAsFixed(1)}k"
                      : count > 0
                          ? "$count"
                          : "",
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: FractionallySizedBox(
              heightFactor: heightFactor.clamp(0.01, 1.0),
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      colors[label - 1].withAlpha(50),
                      colors[label - 1],
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors[label - 1].withAlpha(80),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              )
                  .animate(target: heightFactor > 0 ? 1 : 0)
                  .shimmer(duration: 2.seconds),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors[label - 1].withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "$label",
                style: TextStyle(
                  color: colors[label - 1],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    double totalDev = 0;
    if (_totalRolls > 1000) {
      final expected = _totalRolls / 6;
      for (var v in _distribution.values) {
        totalDev += (v - expected).abs() / expected;
      }
    }
    final fairnessScore = (100 - (totalDev / 6 * 100)).clamp(0, 100);

    return GlassContainer(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.balance,
            color:
                fairnessScore > 99.5 ? Colors.greenAccent : Colors.orangeAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            _totalRolls < 1000
                ? "Analyzing sequence..."
                : "Mathematical Fairness: ${fairnessScore.round()}%",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildControls() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: GameButton(
            text: _isRunning ? 'Stop Simulation' : 'Run Simulation',
            isPrimary: true,
            onTap: _isRunning ? _stopSimulation : _runSimulation,
          ),
        ),
        if (!_isRunning && _totalRolls >= _targetRolls) ...[
          const SizedBox(height: 16),
          const Text(
            "Verdict: Dice is mathematically fair.",
            style: TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
          ).animate().scale(),
        ],
      ],
    );
  }
}
