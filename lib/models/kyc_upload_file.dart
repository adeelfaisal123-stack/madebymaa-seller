/// Local file picked for KYC upload (image or PDF).
class KycUploadFile {
  const KycUploadFile({
    required this.name,
    required this.bytes,
    this.imagePath,
  });

  final String name;
  final List<int> bytes;
  final String? imagePath;

  bool get isPdf => name.toLowerCase().endsWith('.pdf');

  bool get hasImagePreview => imagePath != null && !isPdf;
}
