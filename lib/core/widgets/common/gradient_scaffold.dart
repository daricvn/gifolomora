import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_gradients.dart';

class GradientScaffold extends StatefulWidget {
  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;

  @override
  State<GradientScaffold> createState() => _GradientScaffoldState();
}

class _GradientScaffoldState extends State<GradientScaffold>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.repeat(reverse: true);
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _controller.stop();
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: widget.appBar,
      bottomNavigationBar: widget.bottomNavigationBar,
      floatingActionButton: widget.floatingActionButton,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.background,
            ),
          ),
          // Isolated repaint boundary: blob animation doesn't dirty the
          // content layer on every frame.
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => _Blobs(t: _anim.value),
            ),
          ),
          // Fine grain above gradient + blobs to hide banding on cheap
          // panels. Alpha is baked into the asset (~3%), no Opacity needed.
          const RepaintBoundary(
            child: Image(
              image: AssetImage('assets/noise.png'),
              repeat: ImageRepeat.repeat,
              filterQuality: FilterQuality.none,
              fit: BoxFit.none,
            ),
          ),
          widget.body,
        ],
      ),
    );
  }
}

class _Blobs extends StatelessWidget {
  const _Blobs({required this.t});
  final double t;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final h = size.height;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Violet blob — top-left, pulses
        _Blob(
          left: w * (-0.1 + 0.05 * math.sin(t * math.pi)),
          top: h * (-0.05 + 0.04 * math.cos(t * math.pi)),
          size: math.max(w, h) * (0.55 + 0.05 * t),
          color: AppColors.accentA.withValues(alpha: 0.30),
        ),
        // Cyan blob — bottom-right, counter-pulses
        _Blob(
          right: w * (-0.1 + 0.04 * math.cos(t * math.pi)),
          bottom: h * (-0.05 + 0.05 * math.sin(t * math.pi)),
          size: math.max(w, h) * (0.50 + 0.04 * (1 - t)),
          color: AppColors.accentB.withValues(alpha: 0.22),
        ),
        // Magenta blob — center-ish, slow drift
        _Blob(
          left: w * (0.3 + 0.08 * math.sin(t * math.pi * 0.7)),
          top: h * (0.35 + 0.06 * math.cos(t * math.pi * 0.7)),
          size: math.max(w, h) * 0.38,
          color: AppColors.accentC.withValues(alpha: 0.15),
        ),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.size,
    required this.color,
    this.left,
    this.right,
    this.top,
    this.bottom,
  });

  final double size;
  final Color color;
  final double? left;
  final double? right;
  final double? top;
  final double? bottom;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
