import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VideoUploadService {
  VideoUploadService._();
  static final instance = VideoUploadService._();

  static const String cloudName = 'zcv5jhw6';
  static const String uploadPreset = 'gametribunal_video';
  static const int maxSizeBytes = 100 * 1024 * 1024; // 영상 최대 100MB
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 프로필 사진 최대 10MB

  /// 선택한 영상 파일을 Cloudinary에 업로드하고 재생 URL과 자동 썸네일 URL을 반환합니다.
  Future<({String videoUrl, String thumbnailUrl})> uploadVideo(
    PlatformFile file,
  ) async {
    final size = await file.xFile.length();
    if (size > maxSizeBytes) {
      throw StateError('영상 용량이 100MB를 초과합니다. 더 짧은 클립을 선택해 주세요.');
    }

    final secureUrl = await _uploadToCloudinary(
      file: file,
      resourceType: 'video',
    );

    return (
      videoUrl: secureUrl,
      thumbnailUrl: _buildThumbnailUrl(secureUrl),
    );
  }

  /// 선택한 프로필 사진을 Cloudinary에 업로드하고 이미지 URL을 반환합니다.
  Future<String> uploadProfileImage(PlatformFile file) async {
    final size = await file.xFile.length();
    if (size > maxImageSizeBytes) {
      throw StateError('프로필 사진은 최대 10MB까지 업로드할 수 있습니다.');
    }

    return _uploadToCloudinary(
      file: file,
      resourceType: 'image',
    );
  }

  Future<String> _uploadToCloudinary({
    required PlatformFile file,
    required String resourceType,
  }) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset;

    if (kIsWeb) {
      final bytes = await file.xFile.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.name),
      );
    } else {
      final path = file.path;
      if (path != null) {
        request.files.add(
          await http.MultipartFile.fromPath('file', path, filename: file.name),
        );
      } else {
        final bytes = await file.xFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: file.name),
        );
      }
    }

    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      String detail = 'HTTP ${streamedResponse.statusCode}';
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map && decoded['error'] is Map) {
          final msg = decoded['error']['message'];
          if (msg != null) detail = msg.toString();
        }
      } catch (_) {}
      throw StateError('파일 업로드 실패 ($detail)');
    }

    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) {
      throw StateError('Cloudinary 응답 형식이 올바르지 않습니다.');
    }

    final secureUrl = decoded['secure_url'] as String?;
    if (secureUrl == null || secureUrl.isEmpty) {
      throw StateError('업로드된 파일 주소를 받아오지 못했습니다.');
    }

    return secureUrl;
  }

  /// Cloudinary 영상 주소(.mp4/.mov 등)의 확장자를 .jpg로 바꿔 자동 썸네일 URL 생성
  String _buildThumbnailUrl(String secureUrl) {
    final uri = Uri.tryParse(secureUrl);
    if (uri == null) return '';
    final dotIndex = uri.path.lastIndexOf('.');
    if (dotIndex == -1) return '';
    final jpgPath = '${uri.path.substring(0, dotIndex)}.jpg';
    return uri.replace(path: jpgPath).toString();
  }
}