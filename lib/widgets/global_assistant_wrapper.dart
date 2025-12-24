import 'package:flutter/material.dart';
import '../services/robot_settings_service.dart';
import '../services/assistant_service.dart';
import 'assistant_character.dart';

class GlobalAssistantWrapper extends StatefulWidget {
  final Widget child;

  const GlobalAssistantWrapper({super.key, required this.child});

  @override
  State<GlobalAssistantWrapper> createState() => _GlobalAssistantWrapperState();
}

class _GlobalAssistantWrapperState extends State<GlobalAssistantWrapper> {
  @override
  void initState() {
    super.initState();
    RobotSettingsNotifier().addListener(_onSettingsChanged);
    AssistantService().addListener(_onAssistantChanged);
  }

  @override
  void dispose() {
    RobotSettingsNotifier().removeListener(_onSettingsChanged);
    AssistantService().removeListener(_onAssistantChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onAssistantChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isVisible = RobotSettingsService.isVisible;
    final bool showOnlyOnHome = RobotSettingsService.showOnlyOnHome;
    final bool isAtHome = AssistantService().isAtHome;
    final bool isOnboardingComplete = AssistantService().isOnboardingComplete;
    final bool isCurrentRouteAllowed = AssistantService().isCurrentRouteAllowed;

    bool shouldShow =
        isVisible && isOnboardingComplete && isCurrentRouteAllowed;
    if (showOnlyOnHome && !isAtHome) {
      shouldShow = false;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        AssistantService().onGlobalTouch(event.position);
      },
      onPointerMove: (event) {
        AssistantService().onGlobalTouch(event.position);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RepaintBoundary(child: widget.child),
          if (shouldShow)
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 80),
                child: AssistantCharacter(size: 65),
              ),
            ),
        ],
      ),
    );
  }
}
