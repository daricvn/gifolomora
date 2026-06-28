import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../theme/app_colors.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final allActions = [
      ...?actions,
      if (Platform.isWindows || Platform.isLinux) const _WindowControls(),
    ];

    final toolbar = NavigationToolbar(
      leading: leading,
      middle: centerTitle
          ? _TitleWidget(title: title)
          : (leading == null ? _TitleWidget(title: title) : null),
      trailing: allActions.isNotEmpty
          ? Row(mainAxisSize: MainAxisSize.min, children: allActions)
          : null,
      middleSpacing: 16,
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: preferredSize.height + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: const Border(
              bottom: BorderSide(color: AppColors.glassStroke, width: 0.5),
            ),
          ),
          // DragToMoveArea sits behind toolbar in the Stack so interactive
          // widgets (back button, window controls) get hit-tested first.
          // Without this, DragToMoveArea's pan recognizer occasionally wins
          // the gesture arena and swallows the back button tap.
          child: Platform.isWindows
              ? Stack(
                  children: [
                    const Positioned.fill(
                      child: DragToMoveArea(child: SizedBox.expand()),
                    ),
                    toolbar,
                  ],
                )
              : toolbar,
        ),
      ),
    );
  }
}

class _TitleWidget extends StatelessWidget {
  const _TitleWidget({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textHi,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

class _WindowControls extends StatelessWidget {
  const _WindowControls();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WinBtn(
          icon: Icons.remove_rounded,
          onTap: () => windowManager.minimize(),
        ),
        const _MaxRestoreBtn(),
        _WinBtn(
          icon: Icons.close_rounded,
          onTap: () => windowManager.close(),
          closeStyle: true,
        ),
      ],
    );
  }
}

class _MaxRestoreBtn extends StatefulWidget {
  const _MaxRestoreBtn();

  @override
  State<_MaxRestoreBtn> createState() => _MaxRestoreBtnState();
}

class _MaxRestoreBtnState extends State<_MaxRestoreBtn> {
  bool _isMax = false;

  @override
  void initState() {
    super.initState();
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _isMax = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _WinBtn(
      icon: _isMax ? Icons.filter_none_rounded : Icons.crop_square_rounded,
      onTap: () async {
        if (_isMax) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
        if (mounted) setState(() => _isMax = !_isMax);
      },
    );
  }
}

class _WinBtn extends StatefulWidget {
  const _WinBtn({
    required this.icon,
    required this.onTap,
    this.closeStyle = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool closeStyle;

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 46,
          height: 46,
          color: _hovered
              ? (widget.closeStyle
                  ? const Color(0xFFE81123)
                  : Colors.white.withValues(alpha: 0.10))
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _hovered && widget.closeStyle
                ? Colors.white
                : AppColors.textLo,
          ),
        ),
      ),
    );
  }
}
