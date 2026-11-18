import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/business_controller.dart';
import '../../../controllers/client_controller.dart';
import '../../../models/client_model.dart';
import '../../../services/sms_reminder_service.dart';
import '../../../utils/advertisement_sms.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';
import '../../../utils/sms_phone.dart';

class AdvertisementSmsScreen extends StatefulWidget {
  const AdvertisementSmsScreen({super.key});

  @override
  State<AdvertisementSmsScreen> createState() => _AdvertisementSmsScreenState();
}

class _AdvertisementSmsScreenState extends State<AdvertisementSmsScreen> {
  static const int _maximumRecipients = 50;

  final ClientController _clientController = Get.find();
  final BusinessController _businessController = Get.find();
  final SmsReminderService _smsService = SmsReminderService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final Set<String> _selectedIds = <String>{};

  String _search = '';
  bool _isSending = false;

  bool get _isDark => Preferences.getTheme();

  String get _businessName =>
      (_businessController.business['name'] ?? 'Biashara').toString();

  int get _availableCredits {
    final value = _businessController.business['smsCredits'];
    return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  }

  List<Client> get _eligibleClients {
    final phones = <String>{};
    final clients = <Client>[];
    for (final client in _clientController.clients) {
      final phone = normalizeSmsPhone(client.phone);
      if (!isValidSmsPhone(phone) || !phones.add(phone)) continue;
      clients.add(client);
    }
    clients.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return clients;
  }

  List<Client> get _visibleClients {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return _eligibleClients;
    return _eligibleClients.where((client) {
      return client.name.toLowerCase().contains(query) ||
          client.phone.toLowerCase().contains(query);
    }).toList();
  }

  List<Client> get _selectedClients {
    return _eligibleClients
        .where((client) => _selectedIds.contains(client.id))
        .toList();
  }

  int get _maximumSegments {
    final selected = _selectedClients;
    if (selected.isEmpty) {
      return advertisementSmsSegments(
        _messageController.text,
        clientName: 'Mteja',
        businessName: _businessName,
      );
    }
    return selected
        .map(
          (client) => advertisementSmsSegments(
            _messageController.text,
            clientName: client.name,
            businessName: _businessName,
          ),
        )
        .fold<int>(0, (maximum, value) => value > maximum ? value : maximum);
  }

  int get _estimatedCredits {
    return _selectedClients.fold<int>(
      0,
      (total, client) =>
          total +
          advertisementSmsSegments(
            _messageController.text,
            clientName: client.name,
            businessName: _businessName,
          ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _toggleClient(Client client) {
    if (_isSending) return;
    setState(() {
      if (!_selectedIds.remove(client.id)) {
        if (_selectedIds.length >= _maximumRecipients) {
          errorSnackbar(
            'You can send to at most $_maximumRecipients clients at once.',
          );
          return;
        }
        _selectedIds.add(client.id);
      }
    });
  }

  void _toggleVisibleClients() {
    if (_isSending) return;
    final visible = _visibleClients;
    final allSelected =
        visible.isNotEmpty &&
        visible.every((client) => _selectedIds.contains(client.id));
    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(visible.map((client) => client.id));
        return;
      }
      for (final client in visible) {
        if (_selectedIds.length >= _maximumRecipients) break;
        _selectedIds.add(client.id);
      }
    });
    if (!allSelected && visible.length > _maximumRecipients && mounted) {
      errorSnackbar(
        'Only the first $_maximumRecipients clients were selected.',
      );
    }
  }

  Future<void> _send() async {
    if (_isSending) return;
    final message = _messageController.text.trim();
    if (_selectedIds.isEmpty) {
      errorSnackbar('Select at least one client.');
      return;
    }
    if (message.isEmpty) {
      errorSnackbar('Write an advertisement message.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.campaign_outlined, size: 36),
        title: const Text('Send advertisement?'),
        content: Text(
          'Send to ${_selectedIds.length} clients using up to '
          '$_estimatedCredits SMS credits?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('cancel'.tr),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.send_outlined, size: 18),
            label: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSending = true);
    try {
      final result = await _smsService.sendAdvertisement(
        businessId: _businessController.businessId.value,
        clientIds: _selectedIds.toList(),
        message: message,
      );
      await _businessController.updateBusinessData();
      final sent = (result['sent'] as num?)?.toInt() ?? 0;
      final failed = (result['failed'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _isSending = false;
      });
      if (sent > 0) {
        successSnackbar(
          failed > 0
              ? 'Advertisement sent to $sent clients; $failed failed.'
              : 'Advertisement sent to $sent clients.',
        );
      } else {
        errorSnackbar('No advertisement SMS was sent.');
      }
    } catch (error) {
      if (mounted) setState(() => _isSending = false);
      errorSnackbar(smsFunctionErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageColor = _isDark ? darkGrayColor : const Color(0xFFF6F7FB);
    final surfaceColor = _isDark ? mediumGrayColor : whiteColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? textDarkColor;

    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(title: const Text('Advertisement SMS'), elevation: 0),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            border: Border(
              top: BorderSide(
                color: _isDark
                    ? lightGrayColor.withValues(alpha: 0.3)
                    : borderColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedIds.length} selected',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Estimated: $_estimatedCredits credits',
                      style: const TextStyle(
                        color: textMutedColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 46,
                child: FilledButton.icon(
                  onPressed: _isSending ? null : _send,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 19),
                  label: Text(_isSending ? 'Sending...' : 'Send SMS'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Obx(() {
        final visibleClients = _visibleClients;
        final invalidPhones = _clientController.clients
            .where((client) => !isValidSmsPhone(client.phone))
            .length;
        final allVisibleSelected =
            visibleClients.isNotEmpty &&
            visibleClients.every((client) => _selectedIds.contains(client.id));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1769E0), Color(0xFF4A8CF0)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.campaign_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reach your clients',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_availableCredits SMS credits available',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isDark
                      ? lightGrayColor.withValues(alpha: 0.25)
                      : borderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Message',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Use {name} for the client and {business} for your business.',
                    style: TextStyle(color: textMutedColor, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _messageController,
                    enabled: !_isSending,
                    minLines: 4,
                    maxLines: 7,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          'Hello {name}, visit {business} for our latest offers...',
                      filled: true,
                      fillColor: _isDark
                          ? darkGrayColor
                          : const Color(0xFFF8F9FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: textMutedColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_messageController.text.length} characters · '
                        'up to $_maximumSegments SMS parts',
                        style: const TextStyle(
                          fontSize: 12,
                          color: textMutedColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose clients',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: visibleClients.isEmpty
                      ? null
                      : _toggleVisibleClients,
                  icon: Icon(
                    allVisibleSelected
                        ? Icons.deselect_outlined
                        : Icons.select_all_outlined,
                    size: 18,
                  ),
                  label: Text(
                    allVisibleSelected ? 'Clear shown' : 'Select all',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              enabled: !_isSending,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Search by name or phone',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                filled: true,
                fillColor: surfaceColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (invalidPhones > 0) ...[
              const SizedBox(height: 8),
              Text(
                '$invalidPhones client(s) with invalid phone numbers are hidden.',
                style: const TextStyle(color: textMutedColor, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            if (visibleClients.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.person_search_outlined,
                      size: 42,
                      color: textMutedColor,
                    ),
                    SizedBox(height: 10),
                    Text('No clients with valid phone numbers found.'),
                  ],
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isDark
                        ? lightGrayColor.withValues(alpha: 0.25)
                        : borderColor,
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: visibleClients.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final client = visibleClients[index];
                    final selected = _selectedIds.contains(client.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: _isSending
                          ? null
                          : (_) => _toggleClient(client),
                      controlAffinity: ListTileControlAffinity.trailing,
                      secondary: CircleAvatar(
                        backgroundColor: selected
                            ? primaryColor
                            : const Color(0xFFE9EEF7),
                        child: Text(
                          client.name.trim().isEmpty
                              ? '?'
                              : client.name.trim()[0].toUpperCase(),
                          style: TextStyle(
                            color: selected ? Colors.white : primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        client.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(client.phone),
                    );
                  },
                ),
              ),
          ],
        );
      }),
    );
  }
}
