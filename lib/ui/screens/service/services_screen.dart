import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../models/service_model.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Placeholder for services list
    final List<Service> services = [];
    return Scaffold(
      appBar: AppBar(
        title: Text('Services'),
      ),
      body: ListView.builder(
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          return ListTile(
            title: Text(service.name),
            subtitle: Text(service.description),
            trailing: Text('Tsh ${service.price.toStringAsFixed(2)}'),
            onTap: () {
              // TODO: Edit service
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add new service
        },
        child: Icon(Icons.add),
      ),
    );
  }
} 