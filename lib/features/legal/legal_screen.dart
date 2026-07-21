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
        '본 약관은 주식회사 비엔스(이하 "회사")가 제공하는 AI 프리데이팅 서비스 amori(이하 "서비스")의 이용과 관련하여 회사와 회원 간의 권리·의무 및 책임사항을 규정함을 목적으로 합니다.'),
    LegalSection('제2조 (정의)',
        '① "회원"이란 본 약관에 동의하고 서비스 이용 계약을 체결한 자를 말합니다.\n② "AI 에이전트(페르소나)"란 회원이 입력한 답변을 바탕으로 회원 본인을 대리하도록 생성된 인공지능 프로필을 말합니다.\n③ "프리데이팅"이란 회원의 에이전트 간 모의 대화를 통해 대화 미리보기와 궁합 리포트를 제공하는 기능을 말합니다.\n④ "콘텐츠"란 회원이 입력·게시한 답변, 프로필, 사진, 대화 등 일체의 자료를 말합니다.'),
    LegalSection('제3조 (서비스의 내용)',
        '서비스는 회원이 입력한 답변을 바탕으로 회원 본인을 대리하는 AI 에이전트를 생성하고, 에이전트 간 모의 대화(프리데이팅)를 통해 대화 미리보기와 궁합 리포트를 제공합니다. 회원은 리포트를 확인한 뒤 실제 만남 신청 여부를 스스로 결정하며, 실제 만남 성사 및 진행은 전적으로 회원의 선택과 책임에 따릅니다.'),
    LegalSection('제4조 (회원 가입 및 자격)',
        '① 서비스는 데이팅 서비스의 특성상 만 19세 이상만 이용할 수 있습니다. 회사는 생년월일 등을 통해 이용 연령을 확인하며, 만 19세 미만으로 확인된 계정의 이용을 제한할 수 있습니다.\n② 회원은 가입 시 정확한 정보를 제공해야 하며, 타인의 정보를 도용하거나 허위 정보를 등록해서는 안 됩니다.\n③ 계정과 비밀번호의 관리 책임은 회원에게 있으며, 회원은 이를 제3자에게 양도·대여할 수 없습니다.'),
    LegalSection('제5조 (AI 에이전트와 리포트의 성격)',
        'AI가 생성하는 페르소나·대화·궁합 점수·리포트는 회원의 답변을 바탕으로 한 추정이며, 실제 관계의 성공이나 상대방의 실제 성향을 보장하지 않습니다. 심리 관련 표현은 의학적·전문적 진단이 아닌 참고용 힌트이며, 회원은 이를 참고 자료로만 활용해야 합니다.'),
    LegalSection('제6조 (회원의 콘텐츠와 금지행위)',
        '① 회원이 입력·게시한 콘텐츠에 대한 책임은 회원에게 있습니다.\n② 회원은 다음 각 호의 행위를 해서는 안 됩니다.\n  1. 타인을 사칭·괴롭힘·성희롱·협박하거나 혐오·차별을 조장하는 행위\n  2. 음란물, 불법 정보, 타인의 권리(초상권·저작권 등)를 침해하는 콘텐츠를 게시하는 행위\n  3. 허위 프로필 생성, 상업적 광고·스팸 전송, 만남 강요 등 서비스 목적에 반하는 행위\n  4. 서비스를 부정하게 이용하거나 정상적 운영을 방해하는 행위\n③ 회사는 위반 콘텐츠를 사전 통지 없이 삭제·숨김 처리할 수 있으며, 위반 정도에 따라 이용을 제한하거나 계약을 해지할 수 있습니다.'),
    LegalSection('제7조 (신고·차단 및 게시물 관리)',
        '① 회원은 부적절한 콘텐츠나 상대방을 서비스 내 신고하기·차단하기 기능을 통해 신고 또는 차단할 수 있습니다.\n② 차단 시 상호 간 대화 및 노출이 중단되며, 신고된 내용은 회사의 검토를 거쳐 삭제·이용 제한 등 필요한 조치가 이루어집니다.\n③ 회사는 불쾌감을 유발하는 콘텐츠 및 이용자에 대해 관련 정책에 따라 신속히 조치하기 위해 노력합니다.'),
    LegalSection('제8조 (유료 서비스 및 환불)',
        '① 리포트 열람 등 일부 기능은 유료로 제공될 수 있으며, 유료 상품의 가격·내용은 결제 전 화면에 표시됩니다.\n② 결제 후 아직 이용하지 않은 유료 상품은 관련 법령(전자상거래법 등) 및 앱 마켓 정책에 따라 환불받을 수 있습니다. 이미 열람한 리포트 등 사용을 개시한 디지털 콘텐츠는 청약철회가 제한될 수 있습니다.\n③ 결제 및 환불은 앱 마켓(App Store·Google Play)의 결제 수단과 정책을 통해 처리됩니다.'),
    LegalSection('제9조 (계약 해지 및 회원 탈퇴)',
        '① 회원은 언제든 서비스 내 "회원 탈퇴" 기능을 통해 이용 계약을 해지할 수 있습니다.\n② 탈퇴 시 회원의 매칭·시뮬레이션·대화·리포트·만남 신청·피드백·페르소나 등 관련 데이터가 삭제되며, 로그인 계정도 함께 삭제됩니다. 관련 법령에 따라 보관이 필요한 정보는 예외로 합니다.\n③ 회사는 회원이 본 약관을 중대하게 위반한 경우 이용 계약을 해지할 수 있습니다.'),
    LegalSection('제10조 (책임의 제한)',
        '회사는 회원 간 만남의 결과, 회원이 제공하거나 게시한 정보의 진위, 회원 간 분쟁으로 인해 발생한 손해에 대하여 관련 법령이 허용하는 범위에서 책임을 지지 않습니다. 다만 회사의 고의 또는 중대한 과실로 인한 손해는 그러하지 아니합니다.'),
    LegalSection('제11조 (약관의 변경)',
        '회사는 관련 법령을 준수하는 범위에서 약관을 변경할 수 있으며, 변경 시 시행일과 변경 사유를 서비스 내 공지합니다. 회원이 변경 약관 시행일 이후에도 서비스를 계속 이용하는 경우 변경에 동의한 것으로 봅니다.'),
    LegalSection('제12조 (준거법 및 분쟁 해결)',
        '본 약관 및 서비스 이용과 관련한 분쟁에는 대한민국 법령을 준거법으로 하며, 회사와 회원 간 분쟁은 상호 협의로 해결하되, 협의가 이루어지지 않을 경우 민사소송법에 따른 관할 법원에 소를 제기할 수 있습니다.'),
  ];

  static const List<LegalSection> privacy = [
    LegalSection('1. 수집하는 개인정보 항목',
        '서비스 제공을 위해 아래 항목을 수집합니다.\n\n• 계정 정보: 이메일, 표시 이름(닉네임)\n• 프로필 정보: 프로필 사진, 생년월일(만 19세 이상 확인용), 성별, 매칭 희망 성별, 활동 지역(시/도 단위의 텍스트 — GPS 위치는 수집하지 않음), MBTI, 한 줄 소개\n• 서비스 콘텐츠: 온보딩 답변, AI 페르소나, 프리데이팅 대화·시뮬레이션 콘텐츠\n• 지인 필터 정보(선택): 자기신고 전화번호, 주소록 연락처의 전화번호·이메일 해시값(원문은 수집하지 않음 — 아래 4항 참조)\n• 자동 수집: 기기 푸시 알림 토큰(FCM), 서비스 이용 기록'),
    LegalSection('2. 개인정보의 수집·이용 목적',
        '수집한 정보는 다음 목적으로만 이용됩니다.\n\n• 회원 가입·본인 확인 및 만 19세 이상 이용 자격 확인\n• AI 에이전트(페르소나) 생성 및 회원의 말투·성향 재현\n• 매칭 및 프리데이팅 시뮬레이션, 궁합 리포트 제공\n• 아는 사람과 서로 매칭되지 않도록 하는 지인 필터 제공\n• 푸시 알림 발송, 문의 응대 및 서비스 개선'),
    LegalSection('3. 개인정보의 처리위탁 및 제3자 처리',
        '회사는 원활한 서비스 제공을 위해 아래와 같이 개인정보 처리를 위탁하며, 위탁받은 자는 위탁 목적 범위 내에서만 정보를 처리합니다.\n\n• Google LLC(Firebase Authentication): 계정 인증(이메일/비밀번호)\n• Google LLC(Firebase Cloud Storage): 프로필 사진 저장\n• Google LLC(Firebase Cloud Messaging): 푸시 알림 발송\n• LLM(대규모 언어모델) 처리: 페르소나 생성 및 대화·시뮬레이션 콘텐츠 생성을 위해, 온보딩 답변 및 대화 텍스트가 회사 서버(BFF)를 거쳐 LLM API로 전송·처리됩니다.\n\n도메인 데이터(페르소나·매칭·대화·리포트 등)는 회사가 운영하는 서버의 데이터베이스에 저장되며, Firebase는 인증·저장소·알림 용도로만 사용됩니다.'),
    LegalSection('4. 주소록(지인 필터)의 처리 — 연락처 원문 미전송 원칙',
        '지인 필터는 회원이 아는 사람과 서로 매칭되지 않도록 하는 기능입니다.\n\n• 주소록 접근은 회원의 명시적 동의를 받은 후에만 기기에서 이루어집니다.\n• 연락처의 전화번호·이메일은 회원의 기기에서 정규화된 뒤 SHA-256으로 해시 처리되며, 서버로는 오직 해시값만 전송됩니다.\n• 전화번호·이메일 등 연락처 원문은 서버로 전송되거나 저장되지 않습니다. 이는 회사가 준수하는 핵심 원칙입니다.\n• 회원은 언제든 동기화를 취소하여 등록된 해시를 삭제할 수 있습니다.'),
    LegalSection('5. 개인정보의 국외 이전',
        '위 3항의 처리위탁 과정에서 일부 정보(사진, 인증 정보, 대화 텍스트 등)가 국외에 소재한 서버(Google Cloud 및 LLM API 등)로 전송·처리될 수 있습니다. 회사는 이전되는 항목·목적·보유기간을 본 방침을 통해 고지하며, 필요한 경우 별도 동의를 받습니다.'),
    LegalSection('6. 개인정보의 보유·파기 및 회원 탈퇴 시 삭제 범위',
        '① 회사는 수집 목적이 달성되거나 회원이 탈퇴하면 관련 법령에 따라 보관이 필요한 정보를 제외하고 지체 없이 파기합니다.\n② 회원은 앱 내 프로필 화면의 "회원 탈퇴"를 통해 계정 삭제를 요청할 수 있으며, 탈퇴 시 다음 정보가 삭제됩니다.\n  • 참여한 매칭 및 이에 연결된 시뮬레이션·대화·리포트·만남 신청·피드백\n  • AI 페르소나, 회원이 남긴 피드백, LLM 호출 기록\n  • 로그인 계정(Firebase Authentication)\n③ 서버 데이터 삭제와 로그인 계정 삭제가 함께 처리되어, 한쪽만 남는 상태가 발생하지 않도록 합니다.'),
    LegalSection('7. 이용자의 권리',
        '회원은 언제든 자신의 개인정보를 조회·수정·삭제하거나 처리 정지를 요청할 수 있으며, 수집·이용에 대한 동의를 철회할 수 있습니다. 프로필 정보는 앱 내에서 직접 수정할 수 있고, 계정 및 관련 데이터는 회원 탈퇴로 삭제할 수 있습니다.'),
    LegalSection('8. 이용 연령',
        '서비스는 데이팅 서비스의 특성상 만 19세 이상만 이용할 수 있으며, 만 19세 미만 아동·청소년의 개인정보는 수집하지 않습니다. 만 19세 미만으로 확인된 경우 이용이 제한됩니다.'),
    LegalSection('9. 개인정보의 안전성 확보 조치',
        '회사는 전송 구간 암호화(HTTPS), 접근 권한 통제, 연락처의 온디바이스 해시 처리 등 개인정보를 안전하게 보호하기 위한 기술적·관리적 조치를 시행합니다.'),
    LegalSection('10. 개인정보 보호책임자 및 문의처',
        '개인정보 처리에 관한 문의·열람·정정·삭제 요청은 아래 연락처로 접수할 수 있습니다.\n\n• 이메일: privacy@vience.co.kr\n\n※ 위 연락처는 게시 예정 값이며, 정식 출시 시 실제 개인정보 보호책임자 정보로 갱신됩니다.'),
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
              '본 문서는 amori 서비스에 적용되는 공식 문서입니다. 문의: privacy@vience.co.kr',
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
