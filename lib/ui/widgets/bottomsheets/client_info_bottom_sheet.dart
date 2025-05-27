import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/sale_controller.dart';
import 'package:mauzo/models/client_model.dart';
import 'package:mauzo/ui/widgets/dialogs/double_action_dialog.dart';
import '../../../controllers/profile_controller.dart';
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
    final bool passwordMatches = profileController.role.value == 'owner';

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
                child: client.image != null && client.image != ''
                    ? Container(
                  decoration: const BoxDecoration(
                    color: gray200Color,
                  ),
                  width: 72,
                  height: 72,
                  child: CachedNetworkImage(
                    placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                    imageUrl: client.image!,
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
                client.name,
                style: h5(Theme.of(context).textTheme.bodyLarge!.color),
              ),
              const SizedBox(height: 12),
              Text(
                client.phone != "" ? client.phone : "no_phone".tr,
                style: bodyText(
                  Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                  client.note != null && client.note != ''
                      ? client.note!
                      : 'no_note'.tr,
                  style: bodyText(
                    Theme.of(context).textTheme.bodyMedium!.color,
                  )),
              const SizedBox(height: 12),
              Text(
                client.debt > 0
                    ? "${'debt'.tr}: ${formatCurrency(client.debt, businessController.business['mainCurrency'])}"
                    : 'no_debt'.tr,
                style: TextStyle(
                  fontSize: 14,
                  color: client.debt > 0
                      ? redColor
                      : Theme.of(context).textTheme.bodyMedium!.color,
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
                        formatCurrency(client.advance, businessController.business['mainCurrency']),
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
                            builder: (context) => AdvanceTransactionsSheet(client: client),
                          );
                        },
                      ),
                      // Icon button to add or reduce advance.
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20, color: gray400Color),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AddAdvance(client: client),
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
                    if (passwordMatches)
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
                                    clientController.deleteClient(client.id);
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
                    if (passwordMatches)
                      SecondaryButton(
                        text: 'edit'.tr,
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => EditClientScreen(
                                client: client,
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
                          saleController.filterClients([client.id]);
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
  }
}
