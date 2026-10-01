import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariantDark,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class SectionSkeleton extends StatelessWidget {
  const SectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SkeletonLoader(width: 140, height: 20),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            itemBuilder: (_, __) => Container(
              margin: const EdgeInsets.only(right: 14),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 145, height: 145, borderRadius: 10),
                  SizedBox(height: 8),
                  SkeletonLoader(width: 120, height: 12),
                  SizedBox(height: 4),
                  SkeletonLoader(width: 80, height: 10),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
