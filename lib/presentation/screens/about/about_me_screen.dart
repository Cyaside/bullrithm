import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'components/components.dart';
import '../../widgets/market_top_header.dart';

class AboutMeScreen extends StatefulWidget {
  const AboutMeScreen({super.key, this.showScaffold = true});

  final bool showScaffold;

  @override
  State<AboutMeScreen> createState() => _AboutMeScreenState();
}

class _AboutMeScreenState extends State<AboutMeScreen> {
  static const _prefsKey = 'about_me_profile_v1';

  final ImagePicker _imagePicker = ImagePicker();
  AboutProfileData _profile = AboutProfileData.defaults();
  Uint8List? _avatarBytes;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _profile = AboutProfileData.fromJson(decoded);
        } else if (decoded is Map) {
          _profile = AboutProfileData.fromJson(
            decoded.map((key, value) => MapEntry('$key', value)),
          );
        }
      } catch (_) {
        _profile = AboutProfileData.defaults();
      }
    }

    final imageBase64 = _profile.avatarBase64.trim();
    if (imageBase64.isNotEmpty) {
      try {
        _avatarBytes = base64Decode(imageBase64);
      } catch (_) {
        _avatarBytes = null;
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_profile.toJson()));
  }

  Future<void> _openEditProfileDialog() async {
    final fullNameController = TextEditingController(text: _profile.fullName);
    final nicknameController = TextEditingController(text: _profile.nickname);
    final hobbiesController = TextEditingController(
      text: _profile.hobbies.join(', '),
    );
    final instagramValueController = TextEditingController(
      text: _profile.instagramValue,
    );
    final instagramUrlController = TextEditingController(
      text: _profile.instagramUrl,
    );
    final githubValueController = TextEditingController(
      text: _profile.githubValue,
    );
    final githubUrlController = TextEditingController(text: _profile.githubUrl);
    final linkedInValueController = TextEditingController(
      text: _profile.linkedInValue,
    );
    final linkedInUrlController = TextEditingController(
      text: _profile.linkedInUrl,
    );

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fullNameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nicknameController,
                    decoration: const InputDecoration(labelText: 'Nickname'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hobbiesController,
                    decoration: const InputDecoration(
                      labelText: 'Hobbies (pisahkan dengan koma)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SocialFormSection(
                    title: 'Instagram',
                    valueController: instagramValueController,
                    urlController: instagramUrlController,
                  ),
                  const SizedBox(height: 10),
                  _SocialFormSection(
                    title: 'GitHub',
                    valueController: githubValueController,
                    urlController: githubUrlController,
                  ),
                  const SizedBox(height: 10),
                  _SocialFormSection(
                    title: 'LinkedIn',
                    valueController: linkedInValueController,
                    urlController: linkedInUrlController,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) return;

    final parsedHobbies = hobbiesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    _profile = _profile.copyWith(
      fullName: fullNameController.text.trim(),
      nickname: nicknameController.text.trim(),
      hobbies: parsedHobbies,
      instagramValue: instagramValueController.text.trim(),
      instagramUrl: instagramUrlController.text.trim(),
      githubValue: githubValueController.text.trim(),
      githubUrl: githubUrlController.text.trim(),
      linkedInValue: linkedInValueController.text.trim(),
      linkedInUrl: linkedInUrlController.text.trim(),
    );

    await _saveProfile();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil dari Kamera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1024,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      _avatarBytes = bytes;
      _profile = _profile.copyWith(avatarBase64: base64Encode(bytes));
      await _saveProfile();

      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memilih gambar profil.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final socialLinks = _profile.toSocialLinks();
    final imageProvider = _avatarBytes == null
        ? const AssetImage('assets/profile/profile_photo.png') as ImageProvider
        : MemoryImage(_avatarBytes!);

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const MarketTopHeader(
          title: 'My Profile',
          subtitle: 'Personal details',
        ),
        const SizedBox(height: 12),
        AboutProfileCard(
          imageProvider: imageProvider,
          fullName: _profile.fullName,
          nickname: _profile.nickname,
          onEditPhoto: _pickAvatar,
        ),
        const SizedBox(height: 12),
        AboutHobbiesCard(hobbies: _profile.hobbies),
        const SizedBox(height: 12),
        AboutSocialLinksCard(
          links: socialLinks,
          onTapLink: (link) => _openExternal(context, link.url),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _openEditProfileDialog,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit Profile'),
        ),
      ],
    );

    if (_isLoading) {
      final loading = const Center(child: CircularProgressIndicator());
      if (!widget.showScaffold) {
        return SafeArea(child: loading);
      }
      return Scaffold(
        appBar: AppBar(title: const Text('About Me')),
        body: loading,
      );
    }

    if (!widget.showScaffold) {
      return SafeArea(child: content);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('About Me')),
      body: content,
    );
  }

  Future<void> _openExternal(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (url.trim().isEmpty || uri == null) {
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

class _SocialFormSection extends StatelessWidget {
  const _SocialFormSection({
    required this.title,
    required this.valueController,
    required this.urlController,
  });

  final String title;
  final TextEditingController valueController;
  final TextEditingController urlController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: Theme.of(context).textTheme.labelMedium),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: valueController,
          decoration: const InputDecoration(labelText: 'Display text'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: urlController,
          decoration: const InputDecoration(labelText: 'URL'),
        ),
      ],
    );
  }
}

class AboutProfileData {
  const AboutProfileData({
    required this.fullName,
    required this.nickname,
    required this.hobbies,
    required this.instagramValue,
    required this.instagramUrl,
    required this.githubValue,
    required this.githubUrl,
    required this.linkedInValue,
    required this.linkedInUrl,
    required this.avatarBase64,
  });

  factory AboutProfileData.defaults() {
    return const AboutProfileData(
      fullName: 'Tristan Rasheed S',
      nickname: 'Tristan',
      hobbies: <String>[
        'Mobile Development',
        'UI/UX Exploration',
        'Reading Tech News',
      ],
      instagramValue: '@tristan',
      instagramUrl: 'https://instagram.com/tristan',
      githubValue: 'github.com/tristan',
      githubUrl: 'https://github.com/tristan',
      linkedInValue: 'linkedin.com/in/tristan',
      linkedInUrl: 'https://linkedin.com/in/tristan',
      avatarBase64: '',
    );
  }

  factory AboutProfileData.fromJson(Map<String, dynamic> json) {
    final hobbiesRaw = json['hobbies'];
    final hobbies = hobbiesRaw is List
        ? hobbiesRaw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
        : const <String>[];

    final defaults = AboutProfileData.defaults();
    return AboutProfileData(
      fullName: _readString(json['fullName'], fallback: defaults.fullName),
      nickname: _readString(json['nickname'], fallback: defaults.nickname),
      hobbies: hobbies.isEmpty ? defaults.hobbies : hobbies,
      instagramValue: _readString(
        json['instagramValue'],
        fallback: defaults.instagramValue,
      ),
      instagramUrl: _readString(
        json['instagramUrl'],
        fallback: defaults.instagramUrl,
      ),
      githubValue: _readString(json['githubValue'], fallback: defaults.githubValue),
      githubUrl: _readString(json['githubUrl'], fallback: defaults.githubUrl),
      linkedInValue: _readString(
        json['linkedInValue'],
        fallback: defaults.linkedInValue,
      ),
      linkedInUrl: _readString(
        json['linkedInUrl'],
        fallback: defaults.linkedInUrl,
      ),
      avatarBase64: _readString(json['avatarBase64']),
    );
  }

  final String fullName;
  final String nickname;
  final List<String> hobbies;
  final String instagramValue;
  final String instagramUrl;
  final String githubValue;
  final String githubUrl;
  final String linkedInValue;
  final String linkedInUrl;
  final String avatarBase64;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fullName': fullName,
      'nickname': nickname,
      'hobbies': hobbies,
      'instagramValue': instagramValue,
      'instagramUrl': instagramUrl,
      'githubValue': githubValue,
      'githubUrl': githubUrl,
      'linkedInValue': linkedInValue,
      'linkedInUrl': linkedInUrl,
      'avatarBase64': avatarBase64,
    };
  }

  AboutProfileData copyWith({
    String? fullName,
    String? nickname,
    List<String>? hobbies,
    String? instagramValue,
    String? instagramUrl,
    String? githubValue,
    String? githubUrl,
    String? linkedInValue,
    String? linkedInUrl,
    String? avatarBase64,
  }) {
    return AboutProfileData(
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      hobbies: hobbies ?? this.hobbies,
      instagramValue: instagramValue ?? this.instagramValue,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      githubValue: githubValue ?? this.githubValue,
      githubUrl: githubUrl ?? this.githubUrl,
      linkedInValue: linkedInValue ?? this.linkedInValue,
      linkedInUrl: linkedInUrl ?? this.linkedInUrl,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
    );
  }

  List<SocialLinkItem> toSocialLinks() {
    return <SocialLinkItem>[
      SocialLinkItem(
        label: 'Instagram',
        value: instagramValue,
        url: instagramUrl,
        icon: Icons.camera_alt_outlined,
      ),
      SocialLinkItem(
        label: 'GitHub',
        value: githubValue,
        url: githubUrl,
        icon: Icons.code,
      ),
      SocialLinkItem(
        label: 'LinkedIn',
        value: linkedInValue,
        url: linkedInUrl,
        icon: Icons.work_outline,
      ),
    ];
  }
}

String _readString(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
