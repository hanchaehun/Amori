import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/contact_hash.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/api/api_exception.dart';
import '../../data/repositories/contact_filter_repository.dart';

/// 주소록 지인 필터 — 아는 사람과 서로 매칭되지 않게 한다.
///
/// 연락처는 기기에서 정규화+SHA-256 해시된 뒤 해시만 서버로 올라간다
/// (원문 미전송 — core/utils/contact_hash.dart 계약). 주소록에 없는
/// 지인은 전화번호/이메일을 직접 추가할 수 있다. 본인인증 도입 전엔
/// 서버가 쓰기를 403으로 거부하므로 이 화면은 게이트 뒤에 있다.
class ContactFilterScreen extends StatefulWidget {
  const ContactFilterScreen({super.key});

  @override
  State<ContactFilterScreen> createState() => _ContactFilterScreenState();
}

class _ContactFilterScreenState extends State<ContactFilterScreen> {
  final ContactFilterRepository _repo = ContactFilterRepository();

  bool _loading = true;
  bool _syncing = false;
  BlockedContacts? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _repo.fetch();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast('지인 필터 정보를 불러오지 못했어요');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sync() async {
    if (_syncing) return;
    HapticFeedback.lightImpact();
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!mounted) return;
    if (!granted) {
      _toast('주소록 접근 권한이 필요해요. 설정에서 허용해 주세요.');
      return;
    }
    setState(() => _syncing = true);
    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      // 같은 번호가 여러 연락처에 있어도 해시 1개 — 원문은 여기서 버려진다.
      final hashes = <String, ContactHashItem>{};
      for (final contact in contacts) {
        for (final phone in contact.phones) {
          final h = ContactHash.phone(phone.number);
          if (h != null) hashes[h] = ContactHashItem(hash: h, kind: 'phone');
        }
        for (final email in contact.emails) {
          final h = ContactHash.email(email.address);
          if (h != null) hashes[h] = ContactHashItem(hash: h, kind: 'email');
        }
      }
      final result = await _repo.syncContacts(hashes.values.toList());
      if (!mounted) return;
      setState(() => _data = result);
      _toast('연락처 ${result.syncedCount}개를 동기화했어요');
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast('동기화에 실패했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _unsync() async {
    final count = _data?.syncedCount ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        title: Text('동기화 취소', style: AppTypography.titleMedium),
        content: Text(
          '동기화한 연락처 $count개를 목록에서 삭제할까요?\n직접 추가한 항목은 유지돼요.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.ink700,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              '유지',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.ink500),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              '삭제',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await _repo.unsyncContacts();
      if (!mounted) return;
      setState(() => _data = result);
      _toast('주소록 동기화를 취소했어요');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _addManual({required bool isPhone}) async {
    final result = await showDialog<_ManualInput>(
      context: context,
      builder: (_) => _ManualAddDialog(isPhone: isPhone),
    );
    if (result == null || !mounted) return;
    final hash = isPhone
        ? ContactHash.phone(result.value)
        : ContactHash.email(result.value);
    if (hash == null) {
      _toast(isPhone ? '전화번호 형식을 확인해 주세요' : '이메일 형식을 확인해 주세요');
      return;
    }
    // 서버엔 해시+표시용 라벨만 — 이름이 없으면 마스킹 문자열을 라벨로 쓴다.
    final label = result.name.isNotEmpty
        ? result.name
        : (isPhone
              ? ContactHash.maskPhone(result.value)
              : ContactHash.maskEmail(result.value));
    try {
      await _repo.addManual(
        hash: hash,
        kind: isPhone ? 'phone' : 'email',
        label: label,
      );
      await _load();
      if (mounted) _toast('추가했어요. 서로 매칭되지 않아요.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _remove(BlockedContactItem item) async {
    try {
      final result = await _repo.remove(item.id);
      if (!mounted) return;
      setState(() => _data = result);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final serverDisabled = data != null && !data.enabled;
    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: AppColors.ink900,
                    ),
                    onPressed: () => context.pop(),
                  ),
                  Text('주소록 지인 필터', style: AppTypography.titleLarge),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    children: [
                      Text(
                        '주소록에 있는 지인과는 서로 매칭되지 않아요.\n'
                        '연락처는 기기에서 암호화(해시)되어 대조에만 쓰이고, '
                        '원문은 서버로 전송되지 않아요.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.ink500,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      if (serverDisabled) ...[
                        AppSpacing.vMd,
                        const _NoticeBanner(
                          icon: Icons.lock_outline_rounded,
                          text: '본인인증 도입 후 이용할 수 있어요',
                        ),
                      ] else if (data != null && !data.enforced) ...[
                        // 수집은 지금부터, 매칭 실적용은 본인인증 도입부터
                        // (자기신고 번호는 미검증 — 2026-07-19 결정)
                        AppSpacing.vMd,
                        const _NoticeBanner(
                          icon: Icons.schedule_rounded,
                          text: '지금 등록해 두면 본인인증 도입 후 매칭에 자동으로 적용돼요',
                        ),
                      ],
                      AppSpacing.vMd,
                      _SyncCard(
                        syncedCount: data?.syncedCount ?? 0,
                        syncing: _syncing,
                        enabled: !serverDisabled,
                        onSync: _sync,
                        onUnsync: _unsync,
                      ),
                      AppSpacing.vLg,
                      Text(
                        '주소록에 없는 지인',
                        style: AppTypography.titleMedium.copyWith(fontSize: 15),
                      ),
                      AppSpacing.vXs,
                      Text(
                        '번호나 이메일을 직접 추가하면 그 지인과도 매칭되지 않아요.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.ink500,
                        ),
                      ),
                      AppSpacing.vSm,
                      for (final item in data?.manual ?? const <BlockedContactItem>[])
                        _ManualRow(item: item, onDelete: () => _remove(item)),
                      AppSpacing.vSm,
                      Row(
                        children: [
                          Expanded(
                            child: _AddButton(
                              icon: Icons.call_rounded,
                              label: '전화번호 추가',
                              enabled: !serverDisabled,
                              onTap: () => _addManual(isPhone: true),
                            ),
                          ),
                          AppSpacing.hSm,
                          Expanded(
                            child: _AddButton(
                              icon: Icons.alternate_email_rounded,
                              label: '이메일 추가',
                              enabled: !serverDisabled,
                              onTap: () => _addManual(isPhone: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// 잠금/안내 배너 — 회색 카드에 아이콘+한 줄 문구.
class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.ink500),
          AppSpacing.hSm,
          Expanded(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(
                color: AppColors.ink500,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.syncedCount,
    required this.syncing,
    required this.enabled,
    required this.onSync,
    required this.onUnsync,
  });

  final int syncedCount;
  final bool syncing;
  final bool enabled;
  final VoidCallback onSync;
  final VoidCallback onUnsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.ink100, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.contacts_rounded,
                  size: 20,
                  color: AppColors.ink700,
                ),
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주소록 동기화',
                      style: AppTypography.titleMedium.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      syncedCount > 0
                          ? '연락처 $syncedCount개 등록됨'
                          : '아직 동기화하지 않았어요',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.ink500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: enabled && !syncing ? onSync : null,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.ink100,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: syncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        syncedCount > 0 ? '다시 동기화' : '동기화하기',
                        style: AppTypography.caption.copyWith(
                          color: enabled ? Colors.white : AppColors.ink300,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ],
          ),
          // 동기화 취소 — 동기화분만 삭제 (수동 추가 항목은 유지)
          if (syncedCount > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: enabled && !syncing ? onUnsync : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(
                  '동기화 취소',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.ink500,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManualRow extends StatelessWidget {
  const _ManualRow({required this.item, required this.onDelete});

  final BlockedContactItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.rMd,
        border: Border.all(color: AppColors.ink100),
      ),
      child: Row(
        children: [
          Icon(
            item.kind == 'phone'
                ? Icons.call_rounded
                : Icons.alternate_email_rounded,
            size: 16,
            color: AppColors.ink500,
          ),
          AppSpacing.hSm,
          Expanded(
            child: Text(
              item.label ?? (item.kind == 'phone' ? '전화번호' : '이메일'),
              style: AppTypography.bodyMedium.copyWith(fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.ink300,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink700,
        side: const BorderSide(color: AppColors.ink100, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12),
        textStyle: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      ),
    );
  }
}

class _ManualInput {
  const _ManualInput({required this.value, required this.name});
  final String value;
  final String name;
}

class _ManualAddDialog extends StatefulWidget {
  const _ManualAddDialog({required this.isPhone});
  final bool isPhone;

  @override
  State<_ManualAddDialog> createState() => _ManualAddDialogState();
}

class _ManualAddDialogState extends State<_ManualAddDialog> {
  final TextEditingController _value = TextEditingController();
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = widget.isPhone;
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      title: Text(
        isPhone ? '전화번호 추가' : '이메일 추가',
        style: AppTypography.titleMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: isPhone
                ? TextInputType.phone
                : TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: isPhone ? '010-1234-5678' : 'friend@example.com',
            ),
          ),
          AppSpacing.vSm,
          TextField(
            controller: _name,
            decoration: const InputDecoration(hintText: '이름 (선택)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '취소',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.ink500),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            _ManualInput(
              value: _value.text.trim(),
              name: _name.text.trim(),
            ),
          ),
          child: Text(
            '추가',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
