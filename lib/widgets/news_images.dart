import 'package:flutter/material.dart';

import '../core/utils/drive_link.dart';
import 'animations.dart';

/// Banner of a post's pictures: the first one large, with a "+N" badge.
class NewsImageBanner extends StatelessWidget {
  final List<String> urls;
  const NewsImageBanner({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => openImageViewer(context, urls, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _NetImage(url: driveImageUrl(urls.first, width: 800), fit: BoxFit.cover),
              if (urls.length > 1)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.photo_library_rounded, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('${urls.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of all pictures (used in the post details).
class NewsImageStrip extends StatelessWidget {
  final List<String> urls;
  const NewsImageStrip({super.key, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => openImageViewer(context, urls, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: _NetImage(url: driveImageUrl(urls[i], width: 700), fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}

class _NetImage extends StatelessWidget {
  final String url;
  final BoxFit fit;
  const _NetImage({required this.url, required this.fit});

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const SkeletonBox(height: double.infinity, radius: 0),
      errorBuilder: (_, __, ___) => Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, size: 32),
      ),
    );
  }
}

void openImageViewer(BuildContext context, List<String> urls, int index) {
  Navigator.of(context).push(AppRoute.fadeSlide(ImageViewerScreen(urls: urls, initial: index)));
}

/// Full-screen gallery: swipe between pictures, pinch / double-tap to zoom.
class ImageViewerScreen extends StatefulWidget {
  final List<String> urls;
  final int initial;
  const ImageViewerScreen({super.key, required this.urls, this.initial = 0});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pc = PageController(initialPage: widget.initial);
  late int _page = widget.initial;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_page + 1} / ${widget.urls.length}', style: const TextStyle(color: Colors.white, fontSize: 15)),
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _page = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.network(
              driveImageUrl(widget.urls[i], width: 1600),
              fit: BoxFit.contain,
              loadingBuilder: (_, child, p) => p == null ? child : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
