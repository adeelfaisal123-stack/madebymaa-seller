import '../config/optica2_asset_url.dart';

class SellerTrainingVideo {
  const SellerTrainingVideo({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.sortOrder,
  });

  final int id;
  final String title;
  final String videoUrl;
  final String? thumbnailUrl;
  final int sortOrder;

  factory SellerTrainingVideo.fromJson(Map<String, dynamic> json) {
    final videoUrl = Optica2AssetUrl.resolve(_str(json['video_url'])) ?? '';
    final thumb = Optica2AssetUrl.resolve(json['thumbnail_url'] as String?);

    return SellerTrainingVideo(
      id: json['id'] as int? ?? 0,
      title: _str(json['title']).isEmpty ? 'Training' : _str(json['title']),
      videoUrl: videoUrl,
      thumbnailUrl: thumb,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  String get displayTitle =>
      title.trim().isEmpty ? 'Training' : title.trim();
}

String _str(dynamic value) => value == null ? '' : '$value';
