import 'package:flutter/material.dart';

/// ¿El avatar es una URL (p. ej. la foto de Google) en vez de un emoji?
bool avatarEsUrl(String avatar) =>
    avatar.startsWith('http://') || avatar.startsWith('https://');

/// Muestra el avatar de un usuario de forma uniforme: si es una **URL** (foto de
/// Google) la pinta como imagen circular; si es un **emoji** lo pinta como texto.
///
/// Evita el bug de mostrar la URL literal como texto (issue #66). [tamano] es el
/// tamaño de fuente del emoji; la imagen usa un radio proporcional.
class Avatar extends StatelessWidget {
  const Avatar(this.avatar, {super.key, this.tamano = 24});

  final String avatar;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    if (avatarEsUrl(avatar)) {
      final lado = tamano * 1.24; // diámetro equivalente al radio 0.62·tamaño
      return ClipOval(
        child: Image.network(
          avatar,
          width: lado,
          height: lado,
          fit: BoxFit.cover,
          // Si la foto no carga (sin red, URL expirada), muestra un icono en
          // vez de romper o dejar un hueco oscuro.
          errorBuilder: (_, __, ___) => CircleAvatar(
            radius: tamano * 0.62,
            child: Icon(Icons.person, size: tamano * 0.7),
          ),
        ),
      );
    }
    return Text(avatar, style: TextStyle(fontSize: tamano));
  }
}
