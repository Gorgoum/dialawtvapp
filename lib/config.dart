import 'package:flutter/material.dart';

/// Paramètres de l'application, regroupés ici pour être modifiés sans toucher aux pages.
class AppConfig {
  static const appName = 'Dialaw TV';

  /// Flux HLS du direct (HTTP uniquement chez l'hébergeur, voir les exceptions ATS / network_security_config).
  static const liveStreamUrl =
      'http://livestream.kgsols.com/push/DialawTV/playlist.m3u8';

  /// Serveur des abonnements (dossier server/, hébergé sur Render), sans « / » final.
  /// Vide : abonnement désactivé, le direct reste gratuit pour tous.
  /// Remplaçable à la compilation : --dart-define=API_BASE_URL=https://…
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dialaw-tv-api.onrender.com',
  );

  static const newsUrl = 'https://dialawactu.com';
  static const newsHost = 'dialawactu.com';

  // Couleurs reprises du site dialawactu.com.
  static const blue = Color(0xFF2F00BF);
  static const red = Color(0xFFCE0000);

  /// Contacts affichés sur la page Contacts. Une valeur vide masque l'entrée.
  // TODO: renseigner les vrais contacts de Dialaw TV.
  static const phone = '';

  /// WhatsApp de l'admin : reçoit aussi les demandes de couverture.
  static const whatsapp = '221772197773'; // international, sans « + »
  static const email = '';
  static const facebook =
      'https://www.facebook.com/profile.php?id=100064379100371';
  static const youtube = '';
  static const tiktok = 'https://www.tiktok.com/@dialawtv';
  static const instagram = '';
  static const twitter = '';
}
