import 'package:flutter/foundation.dart';

/// Thin data models used by the Church feature.
/// Audio items can either have a single audio `asset` or nested `subAudios`.

@immutable
class SubAudio {
  final String id;
  final String title;
  final Duration duration;
  final String asset; // asset path to an mp3 in assets/

  const SubAudio({
    required this.id,
    required this.title,
    required this.duration,
    required this.asset,
  });
}

@immutable
class ChurchAudio {
  final String id;
  final String title;
  final Duration duration;
  final String? asset; // If null -> uses subAudios
  final List<SubAudio> subAudios;
  final String? imageAsset; // optional square thumbnail

  const ChurchAudio({
    required this.id,
    required this.title,
    required this.duration,
    this.asset,
    this.subAudios = const [],
    this.imageAsset,
  });

  bool get hasChildren => subAudios.isNotEmpty;
}

@immutable
class ChurchCategory {
  final String id;
  final String title;
  final List<ChurchAudio> items;

  const ChurchCategory({required this.id, required this.title, this.items = const []});
}
