import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local draft for in-progress document KYC (survives leaving the screen).
class DocumentKycDraft {
  const DocumentKycDraft({
    required this.step,
    this.aadhaarNumber,
    this.fssaiNumber,
    this.agreementAccepted = false,
    this.aadhaarFrontBytes,
    this.aadhaarBackBytes,
    this.fssaiDocBytes,
    this.signatureBytes,
  });

  final int step;
  final String? aadhaarNumber;
  final String? fssaiNumber;
  final bool agreementAccepted;
  final Uint8List? aadhaarFrontBytes;
  final Uint8List? aadhaarBackBytes;
  final Uint8List? fssaiDocBytes;
  final Uint8List? signatureBytes;

  bool get hasSignature =>
      signatureBytes != null && signatureBytes!.isNotEmpty;
}

abstract final class DocumentKycDraftStore {
  static String _phoneKey(String phone) =>
      phone.replaceAll(RegExp(r'\D'), '');

  static String _metaKey(String phone, String field) =>
      'doc_kyc_draft_${_phoneKey(phone)}_$field';

  static Future<Directory> _draftDir(String phone) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(
      '${base.path}/document_kyc_draft/${_phoneKey(phone)}',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _draftFile(String phone, String name) async {
    final dir = await _draftDir(phone);
    return File('${dir.path}/$name');
  }

  static Future<void> _writeBytesFile(String phone, String name, Uint8List? bytes) async {
    final file = await _draftFile(phone, name);
    if (bytes == null || bytes.isEmpty) {
      if (await file.exists()) {
        await file.delete();
      }
      return;
    }
    await file.writeAsBytes(bytes, flush: true);
  }

  static Future<Uint8List?> _readBytesFile(String phone, String name) async {
    final file = await _draftFile(phone, name);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  }

  static Future<void> save({
    required String phoneE164,
    required int step,
    String? aadhaarNumber,
    String? fssaiNumber,
    bool agreementAccepted = false,
    Uint8List? aadhaarFrontBytes,
    Uint8List? aadhaarBackBytes,
    Uint8List? fssaiDocBytes,
    Uint8List? signatureBytes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = phoneE164;

    await prefs.setInt(_metaKey(phone, 'step'), step);
    await prefs.setBool(_metaKey(phone, 'agreement'), agreementAccepted);

    if (aadhaarNumber != null && aadhaarNumber.isNotEmpty) {
      await prefs.setString(_metaKey(phone, 'aadhaar'), aadhaarNumber);
    } else {
      await prefs.remove(_metaKey(phone, 'aadhaar'));
    }

    if (fssaiNumber != null && fssaiNumber.isNotEmpty) {
      await prefs.setString(_metaKey(phone, 'fssai'), fssaiNumber);
    } else {
      await prefs.remove(_metaKey(phone, 'fssai'));
    }

    await _writeBytesFile(phone, 'aadhaar_front.jpg', aadhaarFrontBytes);
    await _writeBytesFile(phone, 'aadhaar_back.jpg', aadhaarBackBytes);
    await _writeBytesFile(phone, 'fssai_document.jpg', fssaiDocBytes);
    await _writeBytesFile(phone, 'agreement_signature.png', signatureBytes);
  }

  static Future<DocumentKycDraft?> load(String phoneE164) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = phoneE164;
    final key = _phoneKey(phone);

    if (key.isEmpty) return null;

    final hasMeta = prefs.containsKey(_metaKey(phone, 'step')) ||
        await (await _draftFile(phone, 'aadhaar_front.jpg')).exists() ||
        await (await _draftFile(phone, 'aadhaar_back.jpg')).exists() ||
        await (await _draftFile(phone, 'fssai_document.jpg')).exists() ||
        await (await _draftFile(phone, 'agreement_signature.png')).exists();

    if (!hasMeta) return null;

    return DocumentKycDraft(
      step: prefs.getInt(_metaKey(phone, 'step')) ?? 0,
      aadhaarNumber: prefs.getString(_metaKey(phone, 'aadhaar')),
      fssaiNumber: prefs.getString(_metaKey(phone, 'fssai')),
      agreementAccepted: prefs.getBool(_metaKey(phone, 'agreement')) ?? false,
      aadhaarFrontBytes: await _readBytesFile(phone, 'aadhaar_front.jpg'),
      aadhaarBackBytes: await _readBytesFile(phone, 'aadhaar_back.jpg'),
      fssaiDocBytes: await _readBytesFile(phone, 'fssai_document.jpg'),
      signatureBytes: await _readBytesFile(phone, 'agreement_signature.png'),
    );
  }

  static Future<void> clear(String phoneE164) async {
    final prefs = await SharedPreferences.getInstance();
    final phone = phoneE164;
    final prefix = 'doc_kyc_draft_${_phoneKey(phone)}_';

    for (final key in prefs.getKeys()) {
      if (key.startsWith(prefix)) {
        await prefs.remove(key);
      }
    }

    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}'
      '/document_kyc_draft/${_phoneKey(phone)}',
    );
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
