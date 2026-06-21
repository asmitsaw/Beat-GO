import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../theme/app_colors.dart';

class ShareCardWidget extends StatelessWidget {
  final SongModel song;

  const ShareCardWidget({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 460,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border, width: 4),
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            offset: Offset(8, 8),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Logo & Branding
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'RETRO BEATS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 2.0,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'NOW PLAYING FEED',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 8,
                      letterSpacing: 1.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.radio_rounded,
                size: 28,
                color: AppColors.pink,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cover Art Box
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    offset: Offset(4, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.zero,
                child: CachedNetworkImage(
                  imageUrl: song.coverUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => Container(
                    color: AppColors.purple,
                    child: const Icon(
                      Icons.music_note,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title & Artist
          Text(
            song.title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            song.artist,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // Footer Vibe Badge & Scan Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.yellow,
                  border: Border.all(color: AppColors.border, width: 2),
                ),
                child: const Text(
                  '100% ORIGINAL',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 8,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.bar_chart_rounded, size: 16, color: AppColors.green),
                  SizedBox(width: 4),
                  Text(
                    'LISTEN ON RETRO BEATS',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
