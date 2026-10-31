import 'package:fin_pay/core/result/result.dart';
import 'package:fin_pay/data/repositories/demo_contact_repository.dart';
import 'package:fin_pay/domain/contacts/contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Contact', () {
    test('initials take the first and last word', () {
      expect(
        const Contact(id: '1', name: 'Priya Raghavan', vpa: 'p@x').initials,
        'PR',
      );
      expect(const Contact(id: '1', name: 'Priya', vpa: 'p@x').initials, 'P');
      expect(
        const Contact(
          id: '1',
          name: '  Meera  Kulkarni  ',
          vpa: 'p@x',
        ).initials,
        'MK',
      );
      expect(const Contact(id: '1', name: '', vpa: 'p@x').initials, '?');
      expect(const Contact(id: '1', name: 'अनन्या', vpa: 'p@x').initials, 'अ');
      expect(
        const Contact(id: '1', name: '😀 Smile', vpa: 'p@x').initials,
        '😀S',
      );
    });

    test('maskedVpa keeps two characters and the handle', () {
      expect(Contact.maskVpa('priya.r@okaxis'), 'pr•••••@okaxis');
      expect(Contact.maskVpa('abc@x'), 'ab•••@x');
      expect(Contact.maskVpa('ab@x'), '••@x');
      expect(Contact.maskVpa('a@x'), '•@x');
      expect(Contact.maskVpa('averyveryverylongname@bank'), 'av••••••••@bank');
      expect(Contact.maskVpa('nohandle'), 'no••••••');
      expect(Contact.maskVpa(''), '');
    });

    test('toString carries only the id', () {
      const c = Contact(id: 'c-1', name: 'Priya Raghavan', vpa: 'priya@x');
      expect(c.toString(), 'Contact(c-1)');
      expect(c.toString(), isNot(contains('Priya')));
    });

    test('is a value type', () {
      expect(
        const Contact(id: '1', name: 'A', vpa: 'a@x'),
        const Contact(id: '1', name: 'A', vpa: 'a@x'),
      );
      expect(
        const Contact(id: '1', name: 'A', vpa: 'a@x'),
        isNot(const Contact(id: '2', name: 'A', vpa: 'a@x')),
      );
    });
  });

  group('demoContacts', () {
    test('has 8 to 12 entries with unique ids and VPAs', () {
      expect(demoContacts.length, inInclusiveRange(8, 12));
      expect(demoContacts.map((c) => c.id).toSet().length, demoContacts.length);
      expect(
        demoContacts.map((c) => c.vpa).toSet().length,
        demoContacts.length,
      );
    });

    test('every VPA looks like local@handle', () {
      for (final c in demoContacts) {
        expect(c.vpa, matches(RegExp(r'^[a-z0-9.]+@[a-z]+$')), reason: c.id);
        expect(c.name.trim(), isNotEmpty);
      }
    });

    test('includes the decline and timeout triggers exactly once each', () {
      expect(demoContacts.where((c) => c.vpa.endsWith('@fail')).length, 1);
      expect(demoContacts.where((c) => c.vpa.endsWith('@flaky')).length, 1);
    });

    test('the repository serves the list', () async {
      final result = await const DemoContactRepository().getContacts();
      expect(result.dataOrNull, demoContacts);
    });
  });
}
