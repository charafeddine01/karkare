// =============================================================================
// CarLog Garage Inventory & Workshop Directory Screen
// Spare Parts Shelf (Leftover Fluids, Filters, Spark Plugs) & Contacts Directory
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/carlog_providers.dart';
import '../../core/theme/carlog_theme.dart';
import '../../data/local/database.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/toast_service.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddInventoryModal() {
    final nameController = TextEditingController();
    final brandController = TextEditingController();
    final numberController = TextEditingController();
    final qtyController = TextEditingController(text: '1.0');
    final priceController = TextEditingController();
    String unit = 'pcs';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CarLogTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Add to Spare Parts Shelf', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CarLogTheme.textMain)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Item Name *', hintText: 'e.g. Motul 5W30 (Leftover), Front Brake Pads'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: brandController, decoration: const InputDecoration(labelText: 'Part Brand'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: numberController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Part Number'))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Quantity *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: unit,
                            decoration: const InputDecoration(labelText: 'Unit'),
                            items: ['pcs', 'L', 'mL', 'set'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                            onChanged: (val) => setModalState(() => unit = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Purchase Price (\$ USD)', prefixText: '\$ '),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        final qty = double.tryParse(qtyController.text.trim()) ?? 1.0;
                        final price = double.tryParse(priceController.text.trim());

                        if (name.isEmpty) {
                          ToastService.show('Item name is required', type: ToastType.warning);
                          return;
                        }

                        final auth = ref.read(authProvider);
                        final userId = auth.id ?? 'default_user';

                        await ref.read(inventoryDaoProvider).addInventoryItem(
                          userId: userId,
                          itemName: name,
                          partBrand: brandController.text.trim().isNotEmpty ? brandController.text.trim() : null,
                          partNumber: numberController.text.trim().isNotEmpty ? numberController.text.trim().toUpperCase() : null,
                          quantity: qty,
                          unitLabel: unit,
                          purchasePriceUsd: price,
                        );

                        if (mounted) {
                          Navigator.pop(ctx);
                          ToastService.show('Added item to spare parts shelf!', type: ToastType.success);
                        }
                      },
                      child: const Text('SAVE TO SHELF'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddContactModal() {
    final shopController = TextEditingController();
    final phoneController = TextEditingController();
    final notesController = TextEditingController();
    String specialty = 'mechanic';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CarLogTheme.surfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Add Workshop / Supplier', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CarLogTheme.textMain)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: shopController,
                      decoration: const InputDecoration(labelText: 'Shop / Specialist Name *', hintText: 'e.g. Apex Performance Garage'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: specialty,
                      decoration: const InputDecoration(labelText: 'Specialty'),
                      items: AppConstants.specialties.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ').toUpperCase()))).toList(),
                      onChanged: (val) => setModalState(() => specialty = val!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Phone / WhatsApp Number', prefixIcon: Icon(Icons.phone_outlined, color: CarLogTheme.primaryCyan)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Location / Notes', hintText: 'Street address, hours, ratings...'),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () async {
                        final shop = shopController.text.trim();
                        if (shop.isEmpty) {
                          ToastService.show('Shop name is required', type: ToastType.warning);
                          return;
                        }

                        final auth = ref.read(authProvider);
                        final userId = auth.id ?? 'default_user';

                        await ref.read(inventoryDaoProvider).addContact(
                          userId: userId,
                          shopName: shop,
                          specialty: specialty,
                          phone: phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : null,
                          locationNotes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                        );

                        if (mounted) {
                          Navigator.pop(ctx);
                          ToastService.show('Workshop saved to directory!', type: ToastType.success);
                        }
                      },
                      child: const Text('SAVE TO DIRECTORY'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final userId = auth.id ?? 'default_user';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Workshops'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CarLogTheme.primaryCyan,
          labelColor: CarLogTheme.primaryCyan,
          unselectedLabelColor: CarLogTheme.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.inventory_2_rounded), text: 'Parts Shelf'),
            Tab(icon: Icon(Icons.handyman_rounded), text: 'Workshop Directory'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Spare Parts Shelf
          StreamBuilder<List<GarageInventoryTableData>>(
            stream: ref.watch(inventoryDaoProvider).watchUserInventory(userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!;

              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: CarLogTheme.textMuted.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text('Shelf is Empty', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CarLogTheme.textMain)),
                        const SizedBox(height: 6),
                        const Text(
                          'Track leftover 1L engine oil bottles, spare oil filters, and spark plugs in your garage.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: CarLogTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  return Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CarLogTheme.primaryDarkCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2_rounded, color: CarLogTheme.primaryCyan, size: 22),
                      ),
                      title: Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w700, color: CarLogTheme.textMain)),
                      subtitle: Text(
                        '${item.partBrand ?? ''} ${item.partNumber != null ? '(#${item.partNumber})' : ''}',
                        style: const TextStyle(fontSize: 12, color: CarLogTheme.textMuted),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: CarLogTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: CarLogTheme.borderDark),
                        ),
                        child: Text(
                          '${item.quantity} ${item.unitLabel}',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: CarLogTheme.primaryCyan),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Tab 2: Workshop Directory
          StreamBuilder<List<ContactsDirectoryTableData>>(
            stream: ref.watch(inventoryDaoProvider).watchContacts(userId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final contacts = snapshot.data!;

              if (contacts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.handyman_outlined, size: 64, color: CarLogTheme.textMuted.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        const Text('No Workshops Saved', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CarLogTheme.textMain)),
                        const SizedBox(height: 6),
                        const Text(
                          'Save your trusted mechanics, electricians, tire shops, and parts dealers for quick access.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: CarLogTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final c = contacts[i];
                  return Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CarLogTheme.accentGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: CarLogTheme.accentGreen, size: 22),
                      ),
                      title: Text(c.shopName, style: const TextStyle(fontWeight: FontWeight.w700, color: CarLogTheme.textMain)),
                      subtitle: Text(
                        '${c.specialty.replaceAll('_', ' ').toUpperCase()} ${c.locationNotes != null ? '• ${c.locationNotes}' : ''}',
                        style: const TextStyle(fontSize: 12, color: CarLogTheme.textMuted),
                      ),
                      trailing: c.phone != null
                          ? IconButton(
                              icon: const Icon(Icons.phone_rounded, color: CarLogTheme.primaryCyan),
                              onPressed: () {
                                ToastService.show('Dialing: ${c.phone}', type: ToastType.info);
                              },
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: CarLogTheme.primaryCyan,
        foregroundColor: CarLogTheme.bgDark,
        child: const Icon(Icons.add_rounded),
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddInventoryModal();
          } else {
            _showAddContactModal();
          }
        },
      ),
    );
  }
}
