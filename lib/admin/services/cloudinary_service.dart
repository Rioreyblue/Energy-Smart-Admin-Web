import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../constants/cloudinary_config.dart';
import '../../utils/logger.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  /// Upload image to Cloudinary (unsigned upload with preset)
  Future<String?> uploadImage({
    required File imageFile,
    String? folder,
    Function(int, int)? onProgress,
  }) async {
    try {
      // Create multipart request for unsigned upload
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.uploadUrl),
      );

      // Add upload preset for unsigned uploads
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;

      // Add folder if specified
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Send request
      final streamedResponse = await request.send();

      // Handle response
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        final responseData = jsonDecode(response.body);

        if (responseData['secure_url'] != null) {
          final secureUrl = responseData['secure_url'] as String;
          Logger.info('Image uploaded successfully: $secureUrl');
          return secureUrl;
        } else {
          Logger.error('Upload failed: No secure_url in response');
          return null;
        }
      } else {
        final response = await http.Response.fromStream(streamedResponse);
        Logger.error('Upload failed: ${streamedResponse.statusCode}');
        Logger.debug('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      Logger.error('Error uploading image to Cloudinary', e);
      return null;
    }
  }

  /// Upload image with public ID (unsigned upload with preset)
  Future<String?> uploadImageWithPublicId({
    required File imageFile,
    required String publicId,
    String? folder,
  }) async {
    try {
      // Create multipart request for unsigned upload
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.uploadUrl),
      );

      // Add upload preset for unsigned uploads
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;

      // Add public ID
      request.fields['public_id'] = publicId;

      // Add folder if specified
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Send request
      final streamedResponse = await request.send();

      // Handle response
      if (streamedResponse.statusCode == 200) {
        final response = await http.Response.fromStream(streamedResponse);
        final responseData = jsonDecode(response.body);

        if (responseData['secure_url'] != null) {
          final secureUrl = responseData['secure_url'] as String;
          Logger.info('Image uploaded successfully: $secureUrl');
          return secureUrl;
        } else {
          Logger.error('Upload failed: No secure_url in response');
          return null;
        }
      } else {
        final response = await http.Response.fromStream(streamedResponse);
        Logger.error('Upload failed: ${streamedResponse.statusCode}');
        Logger.debug('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      Logger.error('Error uploading image to Cloudinary', e);
      return null;
    }
  }
}
