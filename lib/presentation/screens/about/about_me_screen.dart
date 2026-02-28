import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'components/components.dart';

class AboutMeScreen extends StatelessWidget {
  const AboutMeScreen({super.key, this.showScaffold = true});

  final bool showScaffold;

  static const _fullName = 'Tristan Rasheed S';
  static const _nickname = 'Tristan';
  static const _hobbies = <String>[
    'Mobile Development',
    'UI/UX Exploration',
    'Reading Tech News',
  ];
  static const _socialLinks = <SocialLinkItem>[
    SocialLinkItem(
      label: 'Instagram',
      value: '@tristan',
      url: 'https://instagram.com/tristan',
      icon: Icons.camera_alt_outlined,
    ),
    SocialLinkItem(
      label: 'GitHub',
      value: 'github.com/tristan',
      url: 'https://github.com/tristan',
      icon: Icons.code,
    ),
    SocialLinkItem(
      label: 'LinkedIn',
      value: 'linkedin.com/in/tristan',
      url: 'https://linkedin.com/in/tristan',
      icon: Icons.work_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _TopHeader(title: 'My Profile', subtitle: 'Personal details'),
        const SizedBox(height: 12),
        const AboutProfileCard(
          imageAssetPath: 'assets/profile/profile_photo.png',
          fullName: _fullName,
          nickname: _nickname,
        ),
        const SizedBox(height: 12),
        const AboutHobbiesCard(hobbies: _hobbies),
        const SizedBox(height: 12),
        AboutSocialLinksCard(
          links: _socialLinks,
          onTapLink: (link) => _openExternal(context, link.url),
        ),
      ],
    );

    if (!showScaffold) {
      return SafeArea(child: content);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('About Me')),
      body: content,
    );
  }

  Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL tidak valid.')));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Gagal membuka link.')));
    }
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
