import 'package:flutter/material.dart';

class AboutProfileCard extends StatelessWidget {
  const AboutProfileCard({
    super.key,
    required this.imageAssetPath,
    required this.fullName,
    required this.nickname,
  });

  final String imageAssetPath;
  final String fullName;
  final String nickname;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 52,
              backgroundImage: AssetImage(imageAssetPath),
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
