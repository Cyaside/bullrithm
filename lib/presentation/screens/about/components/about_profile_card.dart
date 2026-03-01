import 'package:flutter/material.dart';

class AboutProfileCard extends StatelessWidget {
  const AboutProfileCard({
    super.key,
    required this.imageProvider,
    required this.fullName,
    required this.nickname,
    this.onEditPhoto,
  });

  final ImageProvider imageProvider;
  final String fullName;
  final String nickname;
  final VoidCallback? onEditPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundImage: imageProvider,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: theme.colorScheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: onEditPhoto,
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          size: 18,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(fullName, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Nama panggilan: $nickname',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
