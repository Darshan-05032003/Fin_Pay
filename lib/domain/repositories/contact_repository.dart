import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/contacts/contact.dart';

/// Where the payee list comes from. The demo build ships a fixed list; a
/// real build would read the device address book behind the same shape.
abstract interface class IContactRepository {
  /// Every payable contact, in no particular order.
  Future<Result<List<Contact>>> getContacts();
}
