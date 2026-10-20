import 'package:flutter/material.dart';

/// Paramètres de l'application, regroupés ici pour être modifiés sans toucher aux pages.
class AppConfig {
  static const appName = 'Dialaw TV';

  /// Flux HLS du direct (HTTP uniquement chez l'hébergeur, voir les exceptions ATS / network_security_config).
  static const liveStreamUrl =
      'http://livestream.kgsols.com/push/DialawTV/playlist.m3u8';

  static const newsUrl = 'https://dialawactu.com';
  static const newsHost = 'dialawactu.com';

  // Couleurs reprises du site dialawactu.com.
  static const blue = Color(0xFF2F00BF);
  static const red = Color(0xFFCE0000);

  /// Contacts affichés sur la page Contacts. Une valeur vide masque l'entrée.
  // TODO: renseigner les vrais contacts de Dialaw TV.
  static const phone = '';
  static const whatsapp =
      ''; // numéro international sans « + », ex. 221770000000
  static const email = '';
  static const facebook = '';
  static const youtube = '';
  static const tiktok = '';
  static const instagram = '';
  static const twitter = '';
}
