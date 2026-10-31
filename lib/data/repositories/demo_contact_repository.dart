import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/domain/contacts/contact.dart';
import 'package:fin_pay/domain/repositories/contact_repository.dart';

/// The demo payees. All names are invented; the VPAs are not real
/// addresses. Two entries exist to reach every payment outcome from the
/// UI (see `SimulatedPaymentGateway`):
/// - "Test Decline" (`test.decline@fail`): the bank declines;
/// - "Test Timeout" (`test.timeout@flaky`): the first confirmation times
///   out after the ledger recorded the debit; Retry resolves it as
///   already paid.
const List<Contact> demoContacts = [
  Contact(id: 'c-priya', name: 'Priya Raghavan', vpa: 'priya.r@okaxis'),
  Contact(id: 'c-rohan', name: 'Rohan Iyer', vpa: 'rohan.iyer@ybl'),
  Contact(id: 'c-meera', name: 'Meera Kulkarni', vpa: 'meera.k@oksbi'),
  Contact(id: 'c-arjun', name: 'Arjun Nair', vpa: 'arjun.nair@paytm'),
  Contact(id: 'c-sneha', name: 'Sneha Deshmukh', vpa: 'sneha.d@okhdfcbank'),
  Contact(id: 'c-vikram', name: 'Vikram Chauhan', vpa: 'vikram.c@ibl'),
  Contact(id: 'c-ananya', name: 'Ananya Bose', vpa: 'ananya.bose@okicici'),
  Contact(id: 'c-kabir', name: 'Kabir Malhotra', vpa: 'kabir.m@upi'),
  Contact(id: 'c-ishaan', name: 'Ishaan Verma', vpa: 'ishaan.v@axl'),
  Contact(id: 'c-decline', name: 'Test Decline', vpa: 'test.decline@fail'),
  Contact(id: 'c-timeout', name: 'Test Timeout', vpa: 'test.timeout@flaky'),
];

/// Serves [demoContacts].
class DemoContactRepository implements IContactRepository {
  const DemoContactRepository([this.contacts = demoContacts]);

  final List<Contact> contacts;

  @override
  Future<Result<List<Contact>>> getContacts() async => Success(contacts);
}
