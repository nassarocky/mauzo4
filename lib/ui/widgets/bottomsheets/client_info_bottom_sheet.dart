import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/sale_controller.dart';
import 'package:mauzo/models/client_model.dart';
import 'package:mauzo/ui/widgets/dialogs/double_action_dialog.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/ui/widgets/dialogs/debt_sms_dialog.dart';
import 'package:mauzo/utils/sms_phone.dart';
import '../../../utils/constants.dart';
import '../../screens/client/advance_transaction.dart';
import '../../screens/client/edit_client_screen.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';
import '../dialogs/advance_dialog.dart';

class ClientInfoBottomSheet extends StatelessWidget {
  final Client client;
  const ClientInfoBottomSheet({Key? key, required this.client})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ClientController clientController = Get.find();
    final BusinessController businessController = Get.find();
    final ProfileController profileController = Get.find();
    final SaleController saleController = Get.find();
    final bool canEditClient = profileController.isManagerOrOwner();

    return Obx(() {
      final shown = clientController.clients.firstWhere(
        (c) => c.id == client.id,
        orElse: () => client,
      );

      return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 25.0,
            horizontal: 20,
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: shown.image != null && shown.image != ''
                    ? Container(
                  decoration: const BoxDecoration(
                    color: gray200Color,
                  ),
                  width: 72,
                  height: 72,
                  child: CachedNetworkImage(
                    placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                    imageUrl: shown.image!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                    const CircleAvatar(
                      radius: 31,
                      backgroundColor: gray200Color,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color: primaryColor,
                      ),
                    ),
                  ),
                )
                    : const CircleAvatar(
                  radius: 31,
                  backgroundColor: gray200Color,
                  child: Icon(
                    Icons.person,
                    size: 40,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                shown.name,
                style: h5(Theme.of(context).textTheme.bodyLarge!.color),
              ),
              const SizedBox(height: 12),
              Text(
                shown.phone != "" ? shown.phone : "no_phone".tr,
                style: bodyText(
                  Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                  shown.note != null && shown.note != ''
                      ? shown.note!
                      : 'no_note'.tr,
                  style: bodyText(
                    Theme.of(context).textTheme.bodyMedium!.color,
                  )),
              const SizedBox(height: 12),
              Text(
                shown.debt > 0
                    ? "${'debt'.tr}: ${formatCurrency(shown.debt, businessController.business['mainCurrency'])}"
                    : 'no_debt'.tr,
                style: TextStyle(
                  fontSize: 14,
                  color: shown.debt > 0
                      ? redColor
                      : Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
              if (shown.debt > 0 &&
                  isValidSmsPhone(shown.phone) &&
                  (profileController.hasPermission('send_debt_sms') ||
                      profileController.hasPermission('manage_debt')))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await showDebtSmsDialog(
                        context: context,
                        clientName: shown.name,
                        phone: shown.phone,
                        amount: shown.debt,
                        clientId: shown.id,
                      );
                    },
                    icon: const Icon(Icons.sms_outlined, size: 18),
                    label: Text('sms_send_one'.tr),
                  ),
                ),
              const SizedBox(height: 12),
              // When user taps this button, show the AdvanceTransactionsSheet
              // Replace the existing ElevatedButton for advance with this Row:
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'advance payment'.tr,
                    style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                  ),
                  Row(
                    children: [
                      // Display the current advance amount.
                      Text(
                        formatCurrency(shown.advance, businessController.business['mainCurrency']),
                        style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                      ),
                      const SizedBox(width: 8),
                      // Icon button to view advance transactions.
                      IconButton(
                        icon: const Icon(Icons.history, size: 20, color: gray400Color),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (context) => AdvanceTransactionsSheet(client: shown),
                          );
                        },
                      ),
                      // Icon button to add or reduce advance.
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: gray400Color),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AddAdvance(client: shown),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              )
              ,
              const SizedBox(height: 44),
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (canEditClient)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: borderColor,
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) {
                                return DoubleActionDialog(
                                  title: 'delete_client'.tr,
                                  content: 'delete_client_confirmation'.tr,
                                  confirm: 'delete'.tr,
                                  cancel: 'cancel'.tr,
                                  onConfirm: () {
                                    clientController.deleteClient(shown.id);
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                  },
                                  onCancel: () {
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            );
                          },
                          icon: const Icon(
                            Icons.delete,
                            color: redColor,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (canEditClient)
                      SecondaryButton(
                        text: 'edit'.tr,
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => EditClientScreen(
                                client: shown,
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PrimaryButton(
                        text: 'view_orders'.tr,
                        onPressed: () {
                          saleController.selectedDateRange = null;
                          saleController.filterClients([shown.id]);
                          saleController.filterSales();
                          Navigator.pushNamed(context, '/sales');
                        },
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
    });
  }
}
