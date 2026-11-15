// =============================================================================
// CarLog Garage Inventory & Workshop Directory DAO
// Leftover fluids (L), spare filters/parts (pcs) & Workshop Directory
// =============================================================================

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database.dart';

class InventoryDao {
  final AppDatabase db;
  static const _uuid = Uuid();

  InventoryDao(this.db);

  // ---------------------------------------------------------------------------
  // Spare Parts Shelf
  // ---------------------------------------------------------------------------

  Stream<List<GarageInventoryTableData>> watchUserInventory(String userId) {
    return (db.select(db.garageInventoryTable)
          ..where((i) => i.userId.equals(userId) & i.isDeleted.equals(false))
          ..orderBy([(i) => OrderingTerm(expression: i.itemName)]))
        .watch();
  }

  Future<String> addInventoryItem({
    required String userId,
    String? vehicleId,
    String? taskId,
    required String itemName,
    String? partBrand,
    String? partNumber,
    double quantity = 1.0,
    String unitLabel = 'pcs',
    double? purchasePriceUsd,
  }) async {
    final itemId = _uuid.v4();
    final now = DateTime.now().toUtc();

    await db.into(db.garageInventoryTable).insert(
      GarageInventoryTableCompanion(
        id: Value(itemId),
        userId: Value(userId),
        vehicleId: Value(vehicleId),
        taskId: Value(taskId),
        itemName: Value(itemName),
        partBrand: Value(partBrand),
        partNumber: Value(partNumber?.toUpperCase()),
        quantity: Value(quantity),
        unitLabel: Value(unitLabel),
        purchasePriceUsd: Value(purchasePriceUsd),
        isDeleted: const Value(false),
        syncStatus: const Value('pending_insert'),
        updatedAt: Value(now),
      ),
    );

    return itemId;
  }

  /// Check if user already has matching spare parts on shelf
  Future<List<GarageInventoryTableData>> findMatchingParts({
    required String userId,
    String? vehicleId,
    String? taskId,
    String? partNumber,
  }) async {
    final query = db.select(db.garageInventoryTable)
      ..where((i) => i.userId.equals(userId) & i.isDeleted.equals(false) & i.quantity.isBiggerThanValue(0.0));

    if (taskId != null) {
      query.where((i) => i.taskId.equals(taskId));
    }
    if (vehicleId != null) {
      query.where((i) => i.vehicleId.isNull() | i.vehicleId.equals(vehicleId));
    }
    if (partNumber != null && partNumber.trim().isNotEmpty) {
      query.where((i) => i.partNumber.equals(partNumber.trim().toUpperCase()));
    }

    return await query.get();
  }

  /// Decrement stock when part is consumed in a maintenance log
  Future<void> consumePartQuantity(String inventoryId, double amountUsed) async {
    final item = await (db.select(db.garageInventoryTable)..where((i) => i.id.equals(inventoryId))).getSingleOrNull();
    if (item == null) return;

    final newQty = (item.quantity - amountUsed) > 0 ? (item.quantity - amountUsed) : 0.0;
    final now = DateTime.now().toUtc();

    await (db.update(db.garageInventoryTable)..where((i) => i.id.equals(inventoryId))).write(
      GarageInventoryTableCompanion(
        quantity: Value(newQty),
        syncStatus: const Value('pending_update'),
        updatedAt: Value(now),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Workshop Directory
  // ---------------------------------------------------------------------------

  Stream<List<ContactsDirectoryTableData>> watchContacts(String userId) {
    return (db.select(db.contactsDirectoryTable)
          ..where((c) => c.userId.equals(userId) & c.isDeleted.equals(false))
          ..orderBy([(c) => OrderingTerm(expression: c.shopName)]))
        .watch();
  }

  Future<String> addContact({
    required String userId,
    required String shopName,
    String specialty = 'mechanic',
    String? phone,
    String? locationNotes,
  }) async {
    final contactId = _uuid.v4();
    final now = DateTime.now().toUtc();

    await db.into(db.contactsDirectoryTable).insert(
      ContactsDirectoryTableCompanion(
        id: Value(contactId),
        userId: Value(userId),
        shopName: Value(shopName),
        specialty: Value(specialty),
        phone: Value(phone),
        locationNotes: Value(locationNotes),
        isDeleted: const Value(false),
        syncStatus: const Value('pending_insert'),
        updatedAt: Value(now),
      ),
    );

    return contactId;
  }
}
