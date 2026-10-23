import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Photo de profil, ou initiales sur dégradé de la marque quand il n'y a pas de photo.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.imagePath,
    this.size = 48,
  });

  final String name;
  final String? imagePath;
  final double size;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final initials = _initials;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.blue, AppColors.red],
        ),
      ),
      alignment: Alignment.center,
      child: path != null
          ? Image.file(
              File(path),
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
            )
          : initials.isNotEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.38,
              ),
            )
          : Icon(Icons.person, color: Colors.white, size: size * 0.55),
    );
  }
}
