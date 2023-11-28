import 'package:libra_sheet/data/objects/account.dart';
import 'package:libra_sheet/data/objects/allocation.dart';
import 'package:libra_sheet/data/objects/category.dart';
import 'package:libra_sheet/data/objects/reimbursement.dart';
import 'package:libra_sheet/data/objects/tag.dart';

class Transaction {
  Transaction({
    this.key = 0,
    required this.name,
    required this.date,
    required this.value,
    this.category,
    this.account,
    this.note = "",
    this.allocations,
    this.reimbursements,
    this.tags,
  });

  int key;
  final String name;
  final DateTime date;
  final int value;
  final String note;

  final Account? account;
  final Category? category;

  final List<Tag>? tags;
  final List<Allocation>? allocations;
  final List<Reimbursement>? reimbursements;

  @override
  String toString() {
    var out = "Transaction($key): $value $date"
        "\n\t$name"
        "\n\t$account"
        "\n\t$category";
    if (note.isNotEmpty) {
      out += "\n\t$note";
    }
    out += "\n\ttags=${tags?.length ?? 0}"
        " alloc=${allocations?.length ?? 0}"
        " reimb=${reimbursements?.length ?? 0}";
    return out;
  }
}

final dummyTransaction = Transaction(name: '___TEST___', date: DateTime(1987), value: 10000);
