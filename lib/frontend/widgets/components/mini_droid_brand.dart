import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _miniDroidAsset = 'assets/icons/scriptagher_mini_droid.svg';

/// Renders the full-body Scriptagher mini droid icon.
///
/// This widget centralises the usage of [_miniDroidAsset] so that both the
/// desktop and web chrome reuse the same branding asset.
class MiniDroidBrandMark extends StatelessWidget {
  const MiniDroidBrandMark({super.key, this.size = 28, this.semanticLabel});

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      _miniDroidAsset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticLabel ?? 'Scriptagher mini droid',
    );
  }
}
