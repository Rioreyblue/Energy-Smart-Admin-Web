class CloudinaryConfig {
  // Cloudinary Cloud Name
  static const String cloudName = 'duza86enw';

  // Cloudinary API Key
  static const String apiKey = '199568522614648';

  // Cloudinary API Secret
  static const String apiSecret = 'WqTTy_PBHMZUIhJ3ZzY4Pdouhvk';

  // Cloudinary Upload Preset
  // Upload preset name: energysmart_upload
  // Signing mode: Unsigned
  // Note: 'Unsigned' mode is used for uploading directly from the browser or embedded Upload Widget
  // Use 'Signed' mode only for Media Library uploads
  static const String uploadPreset = 'energysmart_upload';

  // Cloudinary Upload URL
  static const String uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}
