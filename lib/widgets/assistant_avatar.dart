import 'dart:io';
import 'package:flutter/material.dart';
import '../services/avatar_service.dart';

/// ويدجت عرض أفاتار المساعد المتحرك مع Lottie
class AssistantAvatar extends StatefulWidget {
  final double size;
  final bool animated;
  final VoidCallback? onTap;
  final bool showBorder;

  const AssistantAvatar({
    super.key,
    this.size = 50, // Reduced from 60
    this.animated = true,
    this.onTap,
    this.showBorder = true,
  });

  @override
  State<AssistantAvatar> createState() => _AssistantAvatarState();
}

class _AssistantAvatarState extends State<AssistantAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.animated) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.animated ? _pulseAnimation.value : 1.0,
            child: _buildAvatar(),
          );
        },
      ),
    );
  }

  Widget _buildAvatar() {
    if (AvatarService.avatarType == 'custom' &&
        AvatarService.customAvatarPath.isNotEmpty) {
      return _buildCustomAvatar();
    }
    return _buildLottieAvatar();
  }

  Widget _buildLottieAvatar() {
    final avatar = AvatarService.currentDefaultAvatar;

    // استخدام الأيقونة البديلة مباشرة بدلاً من Lottie
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [avatar.color, avatar.color.withValues(alpha: 0.7)],
        ),
        border: widget.showBorder
            ? Border.all(color: avatar.color, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: avatar.color.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        avatar.fallbackIcon,
        size: widget.size * 0.5,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCustomAvatar() {
    final file = File(AvatarService.customAvatarPath);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: widget.showBorder
            ? Border.all(color: Colors.white, width: 3)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
        image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
      ),
    );
  }
}

/// ويدجت اختيار الأفاتار من القائمة مع Lottie
class AvatarSelector extends StatefulWidget {
  final int? selectedIndex;
  final Function(int) onSelect;

  const AvatarSelector({super.key, this.selectedIndex, required this.onSelect});

  @override
  State<AvatarSelector> createState() => _AvatarSelectorState();
}

class _AvatarSelectorState extends State<AvatarSelector> {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: AvatarService.defaultAvatars.length,
      itemBuilder: (context, index) {
        final avatar = AvatarService.defaultAvatars[index];
        final isSelected = widget.selectedIndex == index;

        return GestureDetector(
          onTap: () => widget.onSelect(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatar.color.withValues(alpha: 0.1),
              border: Border.all(
                color: isSelected
                    ? avatar.color
                    : Colors.grey.withValues(alpha: 0.3),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: avatar.color.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
            child: ClipOval(
              child: Container(
                color: avatar.color.withValues(alpha: 0.1),
                child: Icon(avatar.fallbackIcon, size: 32, color: avatar.color),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ويدجت صغير لعرض الأفاتار في الدردشة
class ChatAvatar extends StatelessWidget {
  final double size;

  const ChatAvatar({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    if (AvatarService.avatarType == 'custom' &&
        AvatarService.customAvatarPath.isNotEmpty) {
      return _buildCustomAvatar();
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    final avatar = AvatarService.currentDefaultAvatar;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [avatar.color, avatar.color.withValues(alpha: 0.7)],
        ),
        boxShadow: [
          BoxShadow(
            color: avatar.color.withValues(alpha: 0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(avatar.fallbackIcon, size: size * 0.5, color: Colors.white),
    );
  }

  Widget _buildCustomAvatar() {
    final file = File(AvatarService.customAvatarPath);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
        image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
      ),
    );
  }
}
