import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';

class FullScreenImage extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const FullScreenImage({
    super.key,
    required this.imagePaths,
    required this.initialIndex,
  });

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showControls = true;
  Timer? _hideTimer;
  bool _isActionInProgress = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _startHideTimer();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _nextPage() {
    if (_currentIndex < widget.imagePaths.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startHideTimer();
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startHideTimer();
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isActionInProgress = true);
    try {
      final currentImagePath = widget.imagePaths[_currentIndex];
      await Share.shareXFiles([XFile(currentImagePath)], text: 'مشاركة صورة');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل المشاركة: $e')));
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
      _startHideTimer();
    }
  }

  Future<void> _saveImage() async {
    setState(() => _isActionInProgress = true);
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      final currentImagePath = widget.imagePaths[_currentIndex];
      await Gal.putImage(currentImagePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الصورة في المعرض بنجاح ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving image: $e');
      if (mounted) {
        String errorMessage = 'فشل حفظ الصورة';
        if (e is GalException) {
          errorMessage = 'فشل الوصول للمعرض: ${e.type}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionInProgress = false);
      _startHideTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.imagePaths.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.file(
                      File(widget.imagePaths[index]),
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),

            if (_isActionInProgress)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            IgnorePointer(
              ignoring: !_showControls,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _showControls ? 1.0 : 0.0,
                child: Stack(
                  children: [
                    Positioned(
                      top: 40,
                      left: 20,
                      right: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.5,
                              ),
                              shape: const CircleBorder(),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentIndex + 1} / ${widget.imagePaths.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.download_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                tooltip: 'حفظ الصورة',
                                onPressed: _isActionInProgress
                                    ? null
                                    : _saveImage,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(
                                    alpha: 0.5,
                                  ),
                                  shape: const CircleBorder(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.share_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                tooltip: 'مشاركة',
                                onPressed: _isActionInProgress
                                    ? null
                                    : _shareImage,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(
                                    alpha: 0.5,
                                  ),
                                  shape: const CircleBorder(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (_currentIndex < widget.imagePaths.length - 1)
                      Positioned(
                        right: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 40,
                            ),
                            onPressed: _nextPage,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.3,
                              ),
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        ),
                      ),

                    if (_currentIndex > 0)
                      Positioned(
                        left: 10,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 40,
                            ),
                            onPressed: _previousPage,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.3,
                              ),
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
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
    );
  }
}
