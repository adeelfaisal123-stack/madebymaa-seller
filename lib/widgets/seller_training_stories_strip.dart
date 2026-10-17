import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_training_video.dart';
import '../screens/seller_training_stories_viewer_screen.dart';
import '../theme/app_colors.dart';

class SellerTrainingStoriesStrip extends StatelessWidget {
  const SellerTrainingStoriesStrip({
    super.key,
    required this.videos,
    required this.loading,
  });

  final List<SellerTrainingVideo> videos;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 108,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (_, index) => const _StorySkeleton(),
        ),
      );
    }

    if (videos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Training videos',
            style: GoogleFonts.exo2(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.deepGreen.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: videos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final video = videos[index];
              return _StoryCircle(
                video: video,
                onTap: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => SellerTrainingStoriesViewerScreen(
                        videos: videos,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.video,
    required this.onTap,
  });

  final SellerTrainingVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.brandPurple,
                    AppColors.terracotta,
                    AppColors.amberGlow,
                  ],
                ),
              ),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: video.thumbnailUrl != null
                      ? Image.network(
                          video.thumbnailUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              video.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.exo2(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.deepGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return ColoredBox(
      color: AppColors.brandPurple.withValues(alpha: 0.12),
      child: const Icon(
        Icons.play_circle_fill_rounded,
        color: AppColors.brandPurple,
        size: 28,
      ),
    );
  }
}

class _StorySkeleton extends StatelessWidget {
  const _StorySkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.deepGreen.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 48,
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.deepGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}
