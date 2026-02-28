import 'package:flutter/material.dart';

class SocialLinkItem {
  const SocialLinkItem({
    required this.label,
    required this.value,
    required this.url,
    required this.icon,
  });

  final String label;
  final String value;
  final String url;
  final IconData icon;
}

class AboutSocialLinksCard extends StatelessWidget {
  const AboutSocialLinksCard({
    super.key,
    required this.links,
    required this.onTapLink,
  });

  final List<SocialLinkItem> links;
  final ValueChanged<SocialLinkItem> onTapLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Text('Social', style: theme.textTheme.titleLarge),
            ),
            ...links.map(
              (link) => ListTile(
                leading: Icon(link.icon),
                title: Text(link.label),
                subtitle: Text(link.value),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => onTapLink(link),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
