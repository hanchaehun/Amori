import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/back_app_bar.dart';

/// 약관/개인정보처리방침 등 정적 법적 고지 문서를 렌더한다.
class LegalScreen extends StatelessWidget {
  const LegalScreen({
    super.key,
    required this.title,
    required this.effectiveDate,
    required this.sections,
    this.intro,
  });

  final String title;
  final String effectiveDate;
  final String? intro;
  final List<LegalSection> sections;

  static const List<LegalSection> terms = [
    LegalSection('제1조 (목적)',
        '본 약관은 amori(이하 "회사")가 제공하는 AI 프리데이팅 서비스(이하 "서비스")의 이용과 관련하여 회사와 회원 간의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.'),
    LegalSection('제2조 (서비스의 내용)',
        '서비스는 회원이 입력한 답변을 바탕으로 회원 본인을 대리하는 AI 에이전트를 생성하고, 에이전트 간 모의 대화(프리데이팅)를 통해 대화 미리보기와 궁합 리포트를 제공합니다. 실제 만남 여부는 전적으로 회원의 선택에 따릅니다.'),
    LegalSection('제3조 (회원 가입 및 자격)',
        '서비스는 만 19세 이상만 이용할 수 있습니다. 회원은 가입 시 정확한 정보를 제공해야 하며, 타인의 정보를 도용하거나 허위 정보를 등록해서는 안 됩니다.'),
    LegalSection('제4조 (AI 에이전트와 리포트의 성격)',
        'AI가 생성하는 페르소나·대화·궁합 점수·리포트는 회원의 답변을 바탕으로 한 추정이며, 실제 관계의 성공을 보장하지 않습니다. 심리 관련 표현은 진단이 아닌 참고용 힌트입니다.'),
    LegalSection('제5조 (금지행위)',
        '회원은 타인을 사칭·괴롭힘·성희롱하거나, 불법 정보를 유통하거나, 서비스를 부정한 방법으로 이용해서는 안 됩니다. 위반 시 이용이 제한될 수 있습니다.'),
    LegalSection('제6조 (유료 서비스)',
        '리포트 열람 등 일부 기능은 유료로 제공될 수 있으며, 결제·환불은 관련 법령 및 앱 마켓 정책을 따릅니다.'),
    LegalSection('제7조 (책임의 제한)',
        '회사는 회원 간 만남의 결과, 회원이 제공한 정보의 진위로 인해 발생한 손해에 대해 관련 법령이 허용하는 범위에서 책임을 지지 않습니다.'),
    LegalSection('제8조 (약관의 변경)',
        '회사는 관련 법령을 준수하는 범위에서 약관을 변경할 수 있으며, 변경 시 서비스 내 공지합니다.'),
  ];

  static const List<LegalSection> privacy = [
    LegalSection('1. 수집하는 개인정보 항목',
        '• 필수: 이메일, 생년월일, 성별, 매칭 희망 성별, 온보딩 답변\n• 선택: 프로필 사진, 지역, MBTI, 한 줄 소개\n• 자동 수집: 기기 알림 토큰(FCM), 서비스 이용 기록'),
    LegalSection('2. 개인정보의 이용 목적',
        '수집한 정보는 회원 확인, AI 에이전트 생성 및 말투 재현, 매칭·프리데이팅 시뮬레이션, 궁합 리포트 제공, 알림 발송, 서비스 개선을 위해 이용됩니다.'),
    LegalSection('3. 민감정보 처리',
        '매칭 희망 성별은 민감정보에 해당할 수 있어 별도 동의를 받아 매칭 목적으로만 이용합니다. 추론된 심리 특성(성향 힌트 등)은 회원에게 공개되며 언제든 수정·숨김할 수 있습니다.'),
    LegalSection('4. 국외 이전(처리위탁)',
        '말투·대화 생성을 위해 답변 및 발화 텍스트가 국외 LLM API로 전송·처리될 수 있습니다. 이 경우 처리 목적·항목·보유기간을 고지하고 동의를 받습니다.'),
    LegalSection('5. 보유 및 이용 기간',
        '회원 탈퇴 시 관련 법령에 따라 보관이 필요한 정보를 제외하고 지체 없이 파기합니다. 회원은 앱 내에서 계정 삭제를 요청할 수 있습니다.'),
    LegalSection('6. 이용자의 권리',
        '회원은 언제든 자신의 개인정보를 조회·수정·삭제하거나 처리 정지를 요청할 수 있으며, 동의를 철회할 수 있습니다.'),
    LegalSection('7. 개인정보 보호책임자',
        '개인정보 관련 문의는 서비스 내 고객센터를 통해 접수할 수 있습니다.'),
  ];

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: BackAppBar(title: title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text('시행일: $effectiveDate',
              style: AppTypography.caption.copyWith(color: AppColors.ink500)),
          AppSpacing.vXs,
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Text(
              '본 문서는 amori 프로토타입(공모전 출품 버전)의 정책 예시입니다.',
              style: AppTypography.caption.copyWith(color: AppColors.ink500),
            ),
          ),
          if (intro != null) ...[
            AppSpacing.vMd,
            Text(intro!,
                style:
                    AppTypography.bodyMedium.copyWith(color: AppColors.ink700)),
          ],
          AppSpacing.vLg,
          for (final section in sections) ...[
            Text(section.heading, style: AppTypography.titleMedium),
            AppSpacing.vXs,
            Text(
              section.body,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.ink700,
                height: 1.6,
              ),
            ),
            AppSpacing.vLg,
          ],
        ],
      ),
    );
  }
}

class LegalSection {
  const LegalSection(this.heading, this.body);
  final String heading;
  final String body;
}
