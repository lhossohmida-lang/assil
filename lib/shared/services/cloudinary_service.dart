import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../core/constants/app_constants.dart';
import '../../core/i18n/app_strings.dart';

class UploadedImage {
  const UploadedImage(this.url, this.publicId);
  final String url;
  final String publicId;
}

class CloudinaryException implements Exception {
  CloudinaryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// رفع الصور إلى Cloudinary برفع «غير موقّع» (unsigned).
///
/// لماذا Cloudinary لا Firebase Storage: الأخير يتطلب ربط بطاقة بنكية
/// بالمشروع. الرفع غير الموقّع مصمَّم أصلاً للعمل من تطبيق العميل، والحدّ
/// الوحيد أنه لا يسمح بالحذف — لذلك نسجّل الصور اليتيمة في Firestore
/// وتُنظَّف يدوياً (انظر `InventoryRepository._recordOrphans`).
class CloudinaryService {
  const CloudinaryService();

  /// ضغط الصورة **يدوياً** بـ package:image.
  ///
  /// `image_picker` يقبل `maxWidth`/`imageQuality` لكنه **يتجاهلهما على
  /// ويندوز** (لا يوجد ضاغط أصلي هناك)، فترفع صور 6 ميغابايت وتبطئ المتجر.
  /// الضغط هنا يعمل على كل المنصّات بالنتيجة نفسها.
  static Uint8List compress(Uint8List bytes, {int maxSide = 1600, int quality = 85}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    img.Image out = decoded;
    final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longest > maxSide) {
      out = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxSide)
          : img.copyResize(decoded, height: maxSide);
    }
    return Uint8List.fromList(img.encodeJpg(out, quality: quality));
  }

  Future<UploadedImage> upload(Uint8List rawBytes, {String? filename}) async {
    if (!AppConstants.isCloudinaryConfigured) {
      throw CloudinaryException(
        tr('رفع الصور غير مهيّأ: املأ cloudinaryCloudName و cloudinaryUploadPreset في lib/core/constants/app_constants.dart'),
      );
    }

    final bytes = compress(rawBytes);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(AppConstants.cloudinaryUploadUrl),
    )
      ..fields['upload_preset'] = AppConstants.cloudinaryUploadPreset
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename ?? 'product.jpg',
      ));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw CloudinaryException(
        trf('فشل رفع الصورة ({0}). تأكد أن الـ upload preset بوضع Unsigned.', [streamed.statusCode]),
      );
    }

    final map = _decode(body);
    final url = (map['secure_url'] ?? map['url']) as String?;
    final publicId = map['public_id'] as String?;
    if (url == null || publicId == null) {
      throw CloudinaryException(tr('ردّ Cloudinary غير متوقّع'));
    }
    return UploadedImage(url, publicId);
  }

  Map<String, dynamic> _decode(String body) {
    try {
      return Map<String, dynamic>.from(jsonDecode(body) as Map);
    } catch (_) {
      throw CloudinaryException(tr('تعذّر قراءة ردّ Cloudinary'));
    }
  }
}
