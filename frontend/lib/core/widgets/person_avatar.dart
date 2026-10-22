import 'package:flutter/material.dart';

/// A portrait for a named person, and never somebody else's face.
///
/// The header used to fall back from a person's own photo to the *role* photo,
/// which meant a newly added storekeeper was greeted by the picture of the demo
/// storekeeper. That is the same fault that put a woman's photograph next to
/// "Baraka Mushi": the portrait was being chosen by job title, not by person.
///
/// Order is now: the person's own asset, then their initials on the role colour.
/// A role photo is only used where a caller passes it deliberately, e.g. an
/// illustration standing in for "the cashier" rather than for a person.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.name,
    required this.grad,
    this.asset,
    this.size = 44,
    this.radius,
    this.border,
  });

  final String name;
  final List<Color> grad;

  /// The person's own portrait path. Null renders initials.
  final String? asset;

  final double size;

  /// Null means a circle; a value means a rounded square of that radius.
  final double? radius;

  final Border? border;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        colors: grad,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: radius == null ? null : BorderRadius.circular(radius!),
      border: border,
    );

    // A portrait is either a bundled asset (the seeded staff) or a URL the
    // person uploaded to storage. Treating every value as an asset meant an
    // uploaded photo silently fell back to initials.
    final child = asset == null
        ? _initialsTile()
        : (asset!.startsWith('http')
            ? Image.network(
                asset!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initialsTile(),
              )
            : Image.asset(
                asset!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _initialsTile(),
              ));

    return Container(
      width: size,
      height: size,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _initialsTile() {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
