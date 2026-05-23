import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../dummy/matches.dart';
import 'backend_exception.dart';
import 'firestore_paths.dart';
import 'mock_backend_engine.dart';
import 'models.dart';
import 'scenario_answers_store.dart';

class AmoriBackend {
  AmoriBackend({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
    MockBackendEngine? mockEngine,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _mockEngine = mockEngine ?? const MockBackendEngine();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;
  final MockBackendEngine _mockEngine;

  User? get currentUser => _auth.currentUser;

  String get requireUid {
    final uid = currentUser?.uid;
    if (uid == null) {
      throw const BackendException('로그인이 필요합니다.', code: 'unauthenticated');
    }
    return uid;
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required AmoriUserProfile profile,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const BackendException('계정 생성에 실패했습니다.');
      }
      await user.updateDisplayName(profile.displayName);
      await _firestore
          .collection(FirestorePaths.users)
          .doc(user.uid)
          .set(
            AmoriUserProfile(
              uid: user.uid,
              displayName: profile.displayName,
              birthDate: profile.birthDate,
              gender: profile.gender,
              interestGender: profile.interestGender,
              photoUrl: profile.photoUrl,
            ).toCreateJson(),
          );
      return credential;
    } on FirebaseAuthException catch (error) {
      throw BackendException(_authMessage(error), code: error.code);
    } on FirebaseException catch (error) {
      throw BackendException(
        error.message ?? 'Firebase 요청에 실패했습니다.',
        code: error.code,
      );
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw BackendException(_authMessage(error), code: error.code);
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<PersonaCard> buildAndSaveMockPersona(
    List<ScenarioAnswer> answers,
  ) async {
    final uid = requireUid;
    final persona = _mockEngine.buildPersona(userId: uid, answers: answers);
    await _firestore
        .collection(FirestorePaths.personas)
        .doc(uid)
        .set(persona.toJson());
    await ensureDemoMatches();
    return persona;
  }

  Future<void> saveScenarioAnswers(List<ScenarioAnswer> answers) async {
    final uid = requireUid;
    await _firestore
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection('private')
        .doc('scenarioAnswers')
        .set({
          'answers': answers.map((answer) => answer.toJson()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> ensureDemoMatches() async {
    final uid = requireUid;
    final matchBatch = _firestore.batch();
    final demoMatches = _mockEngine.demoMatchesFor(uid);
    for (var i = 0; i < kMatches.length; i++) {
      final match = kMatches[i];
      final matchId = _demoMatchId(uid, match.id);
      final doc = _firestore.collection(FirestorePaths.matches).doc(matchId);
      matchBatch.set(doc, {
        ...demoMatches[i],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await matchBatch.commit();

    final reportBatch = _firestore.batch();
    for (final match in kMatches) {
      final matchId = _demoMatchId(uid, match.id);
      reportBatch.set(
        _firestore.collection(FirestorePaths.reports).doc(matchId),
        _mockEngine
            .reportFor(
              MatchProfile(
                id: matchId,
                initial: match.initial,
                name: match.name,
                age: match.age,
                score: match.score,
                values: match.values,
                humor: match.humor,
                communication: match.communication,
                recommendedTopics: match.recommendedTopics,
              ),
            )
            .toJson(),
        SetOptions(merge: true),
      );
    }
    await reportBatch.commit();
  }

  Stream<List<MatchDocument>> watchMatches({int minScore = 75}) {
    final uid = requireUid;
    return _firestore
        .collection(FirestorePaths.matches)
        .where('participantIds', arrayContains: uid)
        .orderBy('score', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(MatchDocument.fromSnapshot)
              .where((match) => match.profile.score >= minScore)
              .toList(),
        );
  }

  Future<List<MatchDocument>> fetchMatches({int minScore = 75}) async {
    final uid = requireUid;
    final snapshot = await _firestore
        .collection(FirestorePaths.matches)
        .where('participantIds', arrayContains: uid)
        .orderBy('score', descending: true)
        .get();
    return snapshot.docs
        .map(MatchDocument.fromSnapshot)
        .where((match) => match.profile.score >= minScore)
        .toList();
  }

  Future<MatchDocument?> fetchMatchById(String matchId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.matches)
        .doc(matchId)
        .get();
    if (!snapshot.exists) return null;
    return MatchDocument.fromSnapshot(snapshot);
  }

  Future<void> createMeetRequest(MeetRequestDraft draft) async {
    final uid = requireUid;
    final requestId =
        '${draft.matchId}_${uid}_${DateTime.now().millisecondsSinceEpoch}';
    await _firestore
        .collection(FirestorePaths.meetRequests)
        .doc(requestId)
        .set({
          'matchId': draft.matchId,
          'requesterId': uid,
          'receiverId': draft.receiverId,
          'message': draft.message,
          'status': 'pending',
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 24)),
          ),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> submitFeedback({
    required String matchId,
    required String impression,
    required double accuracy,
    required String nextStep,
    String? note,
  }) async {
    final uid = requireUid;
    final feedbackId =
        '${matchId}_${uid}_${DateTime.now().millisecondsSinceEpoch}';
    await _firestore.collection(FirestorePaths.feedback).doc(feedbackId).set({
      'matchId': matchId,
      'userId': uid,
      'impression': impression,
      'accuracy': accuracy,
      'nextStep': nextStep,
      'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveNotificationToken() async {
    final uid = requireUid;
    final token = await _messaging.getToken();
    if (token == null) return;
    await _firestore
        .collection(FirestorePaths.notificationTokens)
        .doc(token)
        .set({
          'userId': uid,
          'platform': 'flutter',
          'token': token,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> completeStoredPersonaBuild() async {
    final answers = ScenarioAnswersStore.answers;
    final effectiveAnswers = answers.isEmpty
        ? const [
            ScenarioAnswer(
              code: 'mock',
              category: 'mock',
              question: 'mock',
              answerLetter: 'A',
              answerText: '발표용 mock 답변',
            ),
          ]
        : answers;
    await saveScenarioAnswers(effectiveAnswers);
    await buildAndSaveMockPersona(effectiveAnswers);
    ScenarioAnswersStore.clear();
  }

  String _authMessage(FirebaseAuthException error) => switch (error.code) {
    'email-already-in-use' => '이미 가입된 이메일이에요.',
    'invalid-email' => '올바른 이메일 형식이 아니에요.',
    'weak-password' => '비밀번호가 너무 약해요.',
    'user-not-found' => '가입된 계정을 찾을 수 없어요.',
    'wrong-password' => '비밀번호가 맞지 않아요.',
    _ => error.message ?? '인증 요청에 실패했습니다.',
  };

  String _demoMatchId(String uid, String matchId) => '${uid}_$matchId';
}
