import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences de l'utilisateur (thème et profil), enregistrées sur l'appareil uniquement.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs)
    : _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == _prefs.getString(_kTheme),
        orElse: () => ThemeMode.dark,
      ),
      _name = _prefs.getString(_kName) ?? '',
      _phone = _prefs.getString(_kPhone) ?? '',
      _email = _prefs.getString(_kEmail) ?? '',
      _avatarPath = _prefs.getString(_kAvatar);

  static const _kTheme = 'theme_mode';
  static const _kName = 'profile_name';
  static const _kPhone = 'profile_phone';
  static const _kEmail = 'profile_email';
  static const _kAvatar = 'profile_avatar';

  static Future<AppSettings> load() async {
    final settings = AppSettings._(await SharedPreferences.getInstance());
    // La photo a pu être effacée (nettoyage du stockage) : on oublie le chemin.
    final avatar = settings._avatarPath;
    if (avatar != null && !File(avatar).existsSync()) {
      settings._avatarPath = null;
      await settings._prefs.remove(_kAvatar);
    }
    return settings;
  }

  final SharedPreferences _prefs;
  ThemeMode _themeMode;
  String _name;
  String _phone;
  String _email;
  String? _avatarPath;

  ThemeMode get themeMode => _themeMode;
  String get name => _name;
  String get phone => _phone;
  String get email => _email;
  String? get avatarPath => _avatarPath;
  bool get hasProfile => _name.isNotEmpty || _avatarPath != null;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_kTheme, mode.name);
  }

  Future<void> saveProfile({
    required String name,
    required String phone,
    required String email,
  }) async {
    _name = name.trim();
    _phone = phone.trim();
    _email = email.trim();
    notifyListeners();
    await _prefs.setString(_kName, _name);
    await _prefs.setString(_kPhone, _phone);
    await _prefs.setString(_kEmail, _email);
  }

  /// Copie la photo choisie dans le dossier de l'application, pour qu'elle
  /// survive au nettoyage du cache de l'outil de sélection.
  Future<void> setAvatar(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = file.path.contains('.') ? file.path.split('.').last : 'jpg';
    // Nom unique : sinon Image.file afficherait l'ancienne photo en cache.
    final dest = File(
      '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await File(file.path).copy(dest.path);
    await _deleteAvatarFile();
    _avatarPath = dest.path;
    notifyListeners();
    await _prefs.setString(_kAvatar, dest.path);
  }

  Future<void> removeAvatar() async {
    await _deleteAvatarFile();
    _avatarPath = null;
    notifyListeners();
    await _prefs.remove(_kAvatar);
  }

  Future<void> _deleteAvatarFile() async {
    final path = _avatarPath;
    if (path == null) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // Déjà supprimée.
    }
  }
}
