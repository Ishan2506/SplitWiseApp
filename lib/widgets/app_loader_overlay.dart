import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/global_loader.dart';

/// The app-wide loading indicator: the PaisaSplit logo centered inside a
/// spinning ring, over a dimmed, input-blocking backdrop. Mounted once above
/// the Navigator in [main.dart] and driven entirely by [GlobalLoader], so
/// every API call across every screen shows it automatically.
class AppLoaderOverlay extends StatelessWidget {
  const AppLoaderOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GlobalLoader.instance,
      builder: (context, _) {
        final visible = GlobalLoader.instance.isVisible;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(child: _LoaderBadge()),
            ),
          ),
        );
      },
    );
  }
}

class _LoaderBadge extends StatelessWidget {
  const _LoaderBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryAccent,
              ),
              backgroundColor: AppColors.primaryLight,
            ),
          ),
          ClipOval(
            child: Image.asset(
              'assets/images/paisasplit_icon.png',
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}
