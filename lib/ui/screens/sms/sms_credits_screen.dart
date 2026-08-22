import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/sms_pack_model.dart';
import 'package:mauzo/services/sms_reminder_service.dart';
import 'package:mauzo/ui/widgets/dialogs/sms_payment_dialog.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/debt_reminder_message.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/utils/sms_settings.dart';

class SmsCreditsScreen extends StatefulWidget {
  const SmsCreditsScreen({Key? key}) : super(key: key);

  @override
  State<SmsCreditsScreen> createState() => _SmsCreditsScreenState();
}

class _SmsCreditsScreenState extends State<SmsCreditsScreen> {
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();
  final SmsReminderService _smsService = SmsReminderService();

  List<SmsPack> _packs = SmsPack.defaults;
  bool _savingSettings = false;
  late SmsSettings _settings;
  late final TextEditingController _debtTemplateCtrl;

  @override
  void initState() {
    super.initState();
    _settings = _businessController.smsSettings;
    _debtTemplateCtrl = TextEditingController(
      text: _settings.debtReminderTemplate.isNotEmpty
          ? _settings.debtReminderTemplate
          : defaultDebtReminderTemplate(
              lang: Get.locale?.languageCode == 'en' ? 'en' : 'sw',
            ),
    );
    _smsService.loadPacks().then((packs) {
      if (mounted) setState(() => _packs = packs);
    });
  }

  @override
  void dispose() {
    _debtTemplateCtrl.dispose();
    super.dispose();
  }

  void _syncTemplateFromSettings(SmsSettings settings) {
    final lang = Get.locale?.languageCode == 'en' ? 'en' : 'sw';
    final text = settings.debtReminderTemplate.isNotEmpty
        ? settings.debtReminderTemplate
        : defaultDebtReminderTemplate(lang: lang);
    if (_debtTemplateCtrl.text != text) {
      _debtTemplateCtrl.text = text;
    }
  }

  String get _templateToSave {
    final lang = Get.locale?.languageCode == 'en' ? 'en' : 'sw';
    final typed = _debtTemplateCtrl.text.trim();
    final builtin = defaultDebtReminderTemplate(lang: lang).trim();
    if (typed.isEmpty || typed == builtin) return '';
    return typed;
  }

  bool get _isOwner =>
      (_profileController.user['role'] ?? '').toString() == 'owner';

  bool get _isDark => Preferences.getTheme();

  Color get _cardBg => _isDark ? mediumGrayColor : whiteColor;

  Color get _pageBg => _isDark ? darkGrayColor : const Color(0xFFF7F8FA);

  Color get _textPrimary =>
      Theme.of(context).textTheme.bodyLarge?.color ?? textDarkColor;

  int get _smsCredits {
    final raw = _businessController.business['smsCredits'];
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? 0}') ?? 0;
  }

  int get _smsCreditsUsed {
    final raw = _businessController.business['smsCreditsUsed'];
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? 0}') ?? 0;
  }

  int get _smsCreditsPurchased {
    final raw = _businessController.business['smsCreditsTotalPurchased'];
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? 0}') ?? 0;
  }

  Future<void> _refreshBusiness() async {
    await _businessController.updateBusinessData();
    if (mounted) {
      setState(() {
        _settings = _businessController.smsSettings;
        _syncTemplateFromSettings(_settings);
      });
    }
  }

  void _patchLocalSmsSettings(SmsSettings settings) {
    _businessController.business['smsSettings'] = settings.toMap();
  }

  Future<void> _saveSettings({bool showSuccess = true}) async {
    setState(() => _savingSettings = true);
    final pending = _settings.copyWith(
      debtReminderTemplate: _templateToSave,
      // Loan period is edited on Debt Records — keep the latest value.
      defaultCreditDays: _businessController.smsSettings.defaultCreditDays,
    );
    try {
      final sample = buildDebtReminderMessage(
        clientName: 'Asha',
        amount: 15000,
        currency: 'TZS',
        businessName: 'Duka',
        dueDateLabel: '28/08/2026',
        template: pending.debtReminderTemplate,
        lang: Get.locale?.languageCode == 'en' ? 'en' : 'sw',
      );
      if (countSmsSegments(sample) > 4) {
        errorSnackbar('sms_message_too_long'.tr);
        return;
      }
      final saved = await _smsService.saveSettings(
        businessId: _businessController.businessId.value,
        settings: pending,
      );
      _patchLocalSmsSettings(saved);
      if (mounted) {
        setState(() {
          _settings = saved;
          _syncTemplateFromSettings(saved);
        });
      }
      if (showSuccess) successSnackbar('sms_settings_saved'.tr);
    } catch (e) {
      errorSnackbar(smsFunctionErrorMessage(e));
      rethrow;
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _setSwitch({
    required SmsSettings Function(bool value) update,
    required bool value,
  }) async {
    final previous = _settings;
    setState(() => _settings = update(value));
    try {
      await _saveSettings(showSuccess: false);
    } catch (_) {
      if (mounted) setState(() => _settings = previous);
    }
  }

  void _showBuyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('sms_subscribe'.tr),
        content: SingleChildScrollView(
          child: SmsPaymentDialogContent(packs: _packs),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('close'.tr),
          ),
        ],
      ),
    ).then((_) => _refreshBusiness());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        title: Text('sms_debt_reminders'.tr),
        elevation: 0,
        actions: [
          if (_isOwner)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _savingSettings ? null : () => _saveSettings(),
                icon: _savingSettings
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, color: Colors.white, size: 18),
                label: Text(
                  _savingSettings ? 'saving'.tr : 'sms_save_settings'.tr,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: _refreshBusiness,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _buildCreditsHero(context),
            if (_isOwner) ...[
              const SizedBox(height: 16),
              _buildSectionLabel('sms_settings'.tr),
              const SizedBox(height: 8),
              _buildDebtReminderSection(context),
              const SizedBox(height: 12),
              _buildMessageSection(context),
              const SizedBox(height: 12),
              _buildAlertsSection(context),
              const SizedBox(height: 12),
              _buildBottomSaveButton(),
            ],
            const SizedBox(height: 20),
            _buildSectionLabel('sms_recent'.tr),
            const SizedBox(height: 8),
            _buildRecentSmsCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: textMutedColor,
      ),
    );
  }

  Widget _buildSurface({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isDark ? lightGrayColor.withOpacity(0.25) : borderColor,
        ),
        boxShadow: _isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _buildCreditsHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDark
              ? [primaryColor.withOpacity(0.85), const Color(0xFF003A99)]
              : [primaryColor, const Color(0xFF3D7EFF)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sms_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'sms_credits_remaining'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$_smsCredits',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _creditStatChip('sms_used'.tr, '$_smsCreditsUsed'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _creditStatChip(
                  'sms_purchased'.tr,
                  '$_smsCreditsPurchased',
                ),
              ),
            ],
          ),
          if (_isOwner) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _showBuyDialog,
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: Text('sms_buy_credits'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _creditStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtReminderSection(BuildContext context) {
    const dayChoices = [0, 1, 2, 3, 5, 7, 14];
    const afterDayChoices = [1, 2, 3, 5, 7, 14];
    return _buildSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.schedule, 'sms_reminder_days'.tr),
          const SizedBox(height: 14),
          _fieldLabel('sms_reminder_days'.tr),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dayChoices.map((d) {
              final selected = _settings.reminderDaysBefore.contains(d);
              return FilterChip(
                label: Text(d == 0 ? 'sms_due_day'.tr : '$d'),
                selected: selected,
                selectedColor: primaryUltraLightColor,
                checkmarkColor: primaryColor,
                onSelected: (v) {
                  final next = [..._settings.reminderDaysBefore];
                  if (v) {
                    if (!next.contains(d)) next.add(d);
                  } else {
                    next.remove(d);
                  }
                  setState(() {
                    _settings = _settings.copyWith(reminderDaysBefore: next);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _fieldLabel('sms_reminder_days_after'.tr),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _modeChip(
                label: 'sms_after_off'.tr,
                selected:
                    _settings.reminderAfterMode == SmsSettings.afterModeOff,
                onSelected: () => setState(() {
                  _settings = _settings.copyWith(
                    reminderAfterMode: SmsSettings.afterModeOff,
                    reminderDaysAfter: const [],
                  );
                }),
              ),
              _modeChip(
                label: 'sms_after_days'.tr,
                selected:
                    _settings.reminderAfterMode == SmsSettings.afterModeDays,
                onSelected: () => setState(() {
                  _settings = _settings.copyWith(
                    reminderAfterMode: SmsSettings.afterModeDays,
                    reminderDaysAfter: _settings.reminderDaysAfter.isEmpty
                        ? const [1, 3, 7]
                        : _settings.reminderDaysAfter,
                  );
                }),
              ),
              _modeChip(
                label: 'sms_after_daily'.tr,
                selected:
                    _settings.reminderAfterMode == SmsSettings.afterModeDaily,
                onSelected: () => setState(() {
                  _settings = _settings.copyWith(
                    reminderAfterMode: SmsSettings.afterModeDaily,
                  );
                }),
              ),
              _modeChip(
                label: 'sms_after_weekly'.tr,
                selected:
                    _settings.reminderAfterMode == SmsSettings.afterModeWeekly,
                onSelected: () => setState(() {
                  _settings = _settings.copyWith(
                    reminderAfterMode: SmsSettings.afterModeWeekly,
                  );
                }),
              ),
            ],
          ),
          if (_settings.reminderAfterMode == SmsSettings.afterModeDays) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: afterDayChoices.map((d) {
                final selected = _settings.reminderDaysAfter.contains(d);
                return FilterChip(
                  label: Text('$d'),
                  selected: selected,
                  selectedColor: primaryUltraLightColor,
                  checkmarkColor: primaryColor,
                  onSelected: (v) {
                    final next = [..._settings.reminderDaysAfter];
                    if (v) {
                      if (!next.contains(d)) next.add(d);
                    } else {
                      next.remove(d);
                    }
                    setState(() {
                      _settings = _settings.copyWith(
                        reminderAfterMode: SmsSettings.afterModeDays,
                        reminderDaysAfter: next,
                      );
                    });
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          _fieldLabel('sms_reminder_max'.tr),
          const SizedBox(height: 6),
          _stepperRow(
            value: '${_settings.reminderMaxCount}',
            onMinus: _settings.reminderMaxCount <= 1
                ? null
                : () => setState(() {
                      _settings = _settings.copyWith(
                        reminderMaxCount: _settings.reminderMaxCount - 1,
                      );
                    }),
            onPlus: _settings.reminderMaxCount >= 30
                ? null
                : () => setState(() {
                      _settings = _settings.copyWith(
                        reminderMaxCount: _settings.reminderMaxCount + 1,
                      );
                    }),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageSection(BuildContext context) {
    return _buildSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.message_outlined, 'sms_debt_message_template'.tr),
          const SizedBox(height: 8),
          Text(
            'sms_debt_message_placeholders'.tr,
            style: const TextStyle(fontSize: 12, color: textMutedColor, height: 1.35),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _debtTemplateCtrl,
            maxLines: 4,
            enabled: !_savingSettings,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              filled: true,
              fillColor: _isDark ? darkGrayColor : gray100Color,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _isDark ? lightGrayColor : borderColor,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: _isDark ? lightGrayColor : borderColor,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: primaryColor, width: 1.4),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _savingSettings
                  ? null
                  : () {
                      final lang =
                          Get.locale?.languageCode == 'en' ? 'en' : 'sw';
                      setState(() {
                        _debtTemplateCtrl.text =
                            defaultDebtReminderTemplate(lang: lang);
                        _settings =
                            _settings.copyWith(debtReminderTemplate: '');
                      });
                    },
              child: Text('sms_debt_message_reset'.tr),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection(BuildContext context) {
    return _buildSurface(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: _sectionTitle(Icons.notifications_active_outlined, 'SMS'),
          ),
          _alertTile(
            icon: Icons.insights_outlined,
            title: 'sms_daily_digest'.tr,
            value: _settings.dailyDigestEnabled,
            onChanged: (v) => _setSwitch(
              value: v,
              update: (value) => _settings.copyWith(dailyDigestEnabled: value),
            ),
          ),
          _alertTile(
            icon: Icons.event_busy_outlined,
            title: 'sms_expiry_alert'.tr,
            value: _settings.expiryAlertEnabled,
            onChanged: (v) => _setSwitch(
              value: v,
              update: (value) => _settings.copyWith(expiryAlertEnabled: value),
            ),
          ),
          _alertTile(
            icon: Icons.inventory_2_outlined,
            title: 'sms_low_stock_alert'.tr,
            value: _settings.lowStockAlertEnabled,
            onChanged: (v) => _setSwitch(
              value: v,
              update: (value) =>
                  _settings.copyWith(lowStockAlertEnabled: value),
            ),
          ),
          _alertTile(
            icon: Icons.payments_outlined,
            title: 'sms_advance_notify'.tr,
            value: _settings.advanceSmsEnabled,
            onChanged: (v) => _setSwitch(
              value: v,
              update: (value) => _settings.copyWith(advanceSmsEnabled: value),
            ),
          ),
          _alertTile(
            icon: Icons.receipt_long_outlined,
            title: 'sms_debt_pay_notify'.tr,
            value: _settings.debtPaymentSmsEnabled,
            onChanged: (v) => _setSwitch(
              value: v,
              update: (value) =>
                  _settings.copyWith(debtPaymentSmsEnabled: value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      secondary: Icon(icon, color: primaryColor, size: 22),
      title: Text(title, style: TextStyle(fontSize: 14, color: _textPrimary)),
      value: value,
      activeColor: primaryColor,
      onChanged: _savingSettings ? null : onChanged,
    );
  }

  Widget _buildBottomSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _savingSettings ? null : () => _saveSettings(),
        icon: const Icon(Icons.save_outlined, size: 18),
        label: Text(
          _savingSettings ? 'saving'.tr : 'sms_save_settings'.tr,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSmsCard(BuildContext context) {
    return _buildSurface(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _smsService.logs(_businessController.businessId.value),
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('sms_log_error'.tr, style: bodyText(redColor)),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Column(
                children: [
                  Icon(Icons.sms_failed_outlined, size: 36, color: textMutedColor),
                  const SizedBox(height: 8),
                  Text(
                    'sms_no_logs'.tr,
                    style: bodyText(textMutedColor),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < docs.length; i++) ...[
                _recentSmsTile(docs[i].data()),
                if (i < docs.length - 1)
                  Divider(
                    height: 1,
                    indent: 64,
                    color: _isDark ? lightGrayColor.withOpacity(0.2) : gray200Color,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _recentSmsTile(Map<String, dynamic> d) {
    final status = (d['status'] ?? '').toString();
    final sent = status == 'sent';
    final when = d['createdAt'] is Timestamp
        ? DateFormat('dd/MM HH:mm').format((d['createdAt'] as Timestamp).toDate())
        : '';
    final title = (d['clientName'] ?? d['phone'] ?? '').toString();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: sent
            ? greenColor.withOpacity(0.12)
            : redColor.withOpacity(0.12),
        child: Icon(
          sent ? Icons.check : Icons.error_outline,
          size: 18,
          color: sent ? greenColor : redColor,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: _textPrimary,
        ),
      ),
      subtitle: Text(
        '${d['phone'] ?? ''}${when.isEmpty ? '' : '  ·  $when'}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: textMutedColor),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 18, color: primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: textMutedColor,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _stepperRow({
    required String value,
    required VoidCallback? onMinus,
    required VoidCallback? onPlus,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _isDark ? darkGrayColor : gray100Color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline),
            color: primaryColor,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline),
            color: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _modeChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: primaryUltraLightColor,
      labelStyle: TextStyle(
        color: selected ? primaryColor : _textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
