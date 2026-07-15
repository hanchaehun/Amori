import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// 프로필 사진 — 갤러리에서 골라 Firebase Storage에 올리고 다운로드 URL을 돌려준다.
///
/// 저장 경로는 storage.rules의 본인 전용 규칙과 일치해야 한다:
/// `users/{uid}/profile/avatar.jpg` (5MB 미만·이미지만, 읽기는 로그인 사용자 전체 —
/// 매칭 상대가 리포트에서 보는 경로). URL은 `PUT /users/me`의 photo_url로 저장된다.
class ProfilePhotoUploader {
  ProfilePhotoUploader({FirebaseAuth? auth, FirebaseStorage? storage})
    : _auth = auth ?? FirebaseAuth.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  /// 갤러리 선택 → 리사이즈(1024px·화질 85) → 업로드 → URL.
  /// 사용자가 선택을 취소하면 null.
  Future<String?> pickAndUpload() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('로그인이 필요합니다.');
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final ref = _storage.ref('users/$uid/profile/avatar.jpg');
    await ref.putData(
      await picked.readAsBytes(),
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }
}
