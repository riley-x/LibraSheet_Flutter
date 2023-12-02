import 'package:libra_sheet/data/database/allocations.dart';
import 'package:libra_sheet/data/database/category_history.dart';
import 'package:libra_sheet/data/database/tags.dart';
import 'package:libra_sheet/data/database/transactions.dart';
import 'package:libra_sheet/data/objects/account.dart';
import 'package:libra_sheet/data/objects/category.dart';
import 'package:libra_sheet/data/objects/reimbursement.dart';
import 'package:libra_sheet/data/objects/tag.dart';
import 'package:libra_sheet/data/objects/transaction.dart' as lt;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const reimbursementsTable = "reimbursements";

const _expense = "expenseId";
const _income = "incomeId";
const _value = "value";

const reimbExpense = _expense;
const reimbIncome = _income;
const reimbValue = _value;

const createReimbursementsTableSql = "CREATE TABLE IF NOT EXISTS $reimbursementsTable ("
    "$_expense INTEGER NOT NULL, "
    "$_income INTEGER NOT NULL, "
    "$_value INTEGER NOT NULL, "
    "PRIMARY KEY($_expense, $_income))";

Map<String, dynamic> _toMap(lt.Transaction parent, Reimbursement r) {
  return {
    _income: (parent.value > 0) ? parent.key : r.target.key,
    _expense: (parent.value > 0) ? r.target.key : parent.key,
    _value: r.value,
  };
}

// Reimbursement _fromMap(Map<String, dynamic> map) {
//
// }

Future<int> _insert(
  Reimbursement r, {
  required lt.Transaction parent,
  required Transaction txn,
}) {
  return txn.insert(
    reimbursementsTable,
    _toMap(parent, r),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<int> _delete(
  Reimbursement r, {
  required lt.Transaction parent,
  required Transaction txn,
}) {
  final income = (parent.value > 0) ? parent.key : r.target.key;
  final expense = (parent.value > 0) ? r.target.key : parent.key;
  return txn.delete(
    reimbursementsTable,
    where: '$_expense = ? AND $_income = ?',
    whereArgs: [expense, income],
  );
}

Future<void> addReimbursement(
  Reimbursement r, {
  required lt.Transaction parent,
  required Transaction txn,
}) async {
  assert(parent.key != 0);
  assert(r.target.key != 0);
  assert(r.value >= 0);
  if (parent.account == null) throw Exception("addReimbursement() parent account is null");
  if (parent.category == null) throw Exception("addReimbursement() parent category is null");
  if (r.target.account == null) throw Exception("addReimbursement() target account is null");
  if (r.target.category == null) throw Exception("addReimbursement() target category is null");
  if (parent.value * r.target.value > 0)
    throw Exception("addReimbursement() transactions have same sign");

  await _insert(r, parent: parent, txn: txn);
  final income = (parent.value > 0) ? parent : r.target;
  final expense = (parent.value > 0) ? r.target : parent;

  /// Remove value from both transactions' original category
  await updateCategoryHistory(
    account: income.account!.key,
    category: income.category!.key,
    date: income.date,
    delta: -r.value,
    txn: txn,
  );
  await updateCategoryHistory(
    account: expense.account!.key,
    category: expense.category!.key,
    date: expense.date,
    delta: r.value,
    txn: txn,
  );

  /// Add value to "Ignore" category
  if (income.account!.key != expense.account!.key) {
    await updateCategoryHistory(
      account: income.account!.key,
      category: Category.ignore.key,
      date: income.date,
      delta: r.value,
      txn: txn,
    );
    await updateCategoryHistory(
      account: expense.account!.key,
      category: Category.ignore.key,
      date: expense.date,
      delta: -r.value,
      txn: txn,
    );
  }
}

Future<void> deleteReimbursement(
  Reimbursement r, {
  required lt.Transaction parent,
  required Transaction txn,
}) async {
  assert(parent.key != 0);
  assert(r.target.key != 0);
  assert(r.value >= 0);
  if (parent.account == null) throw Exception("deleteReimbursement() parent account is null");
  if (parent.category == null) throw Exception("deleteReimbursement() parent category is null");
  if (r.target.account == null) throw Exception("deleteReimbursement() target account is null");
  if (r.target.category == null) throw Exception("deleteReimbursement() target category is null");
  if (parent.value * r.target.value > 0)
    throw Exception("deleteReimbursement() transactions have same sign");

  await _delete(r, parent: parent, txn: txn);
  final income = (parent.value > 0) ? parent : r.target;
  final expense = (parent.value > 0) ? r.target : parent;

  /// Add value back to both transactions' original category
  await updateCategoryHistory(
    account: income.account!.key,
    category: income.category!.key,
    date: income.date,
    delta: r.value,
    txn: txn,
  );
  await updateCategoryHistory(
    account: expense.account!.key,
    category: expense.category!.key,
    date: expense.date,
    delta: -r.value,
    txn: txn,
  );

  /// Remove value from "Ignore" category
  if (income.account!.key != expense.account!.key) {
    await updateCategoryHistory(
      account: income.account!.key,
      category: Category.ignore.key,
      date: income.date,
      delta: -r.value,
      txn: txn,
    );
    await updateCategoryHistory(
      account: expense.account!.key,
      category: Category.ignore.key,
      date: expense.date,
      delta: r.value,
      txn: txn,
    );
  }
}

Future<List<Reimbursement>> loadReimbursements({
  required lt.Transaction parent,
  required Map<int, Account> accounts,
  required Map<int, Category> categories,
  required Map<int, Tag> tags,
  required DatabaseExecutor db,
}) async {
  final parentColumn = (parent.value > 0) ? _income : _expense;
  final targetColumn = (parent.value > 0) ? _expense : _income;
  final maps = await db.rawQuery(
    """
    SELECT 
      t.*,
      GROUP_CONCAT(tag.$tagKey) as tags,
      COUNT(a.$allocationsKey) as nAllocs,
      COUNT(r1.$reimbExpense) + COUNT(r2.$reimbExpense) as nReimbs,
      reimbs.$_value as reimb_value
    FROM (
        SELECT $targetColumn, $_value FROM $reimbursementsTable WHERE $parentColumn = ?
      ) reimbs
    JOIN
      $transactionsTable t on t.$transactionKey = reimbs.$targetColumn
    LEFT OUTER JOIN 
      $tagJoinTable tag_join on tag_join.$tagJoinTrans = t.$transactionKey
    LEFT OUTER JOIN
      $tagsTable tag on tag.$tagKey = tag_join.$tagJoinTag
    LEFT OUTER JOIN 
      $allocationsTable a on a.$allocationsTransaction = t.$transactionKey
    LEFT OUTER JOIN
      $reimbursementsTable r1 ON r1.$reimbExpense = t.$transactionKey
    LEFT OUTER JOIN
      $reimbursementsTable r2 ON r2.$reimbIncome = t.$transactionKey
    """,
    [parent.key],
  );
  return [
    for (final map in maps)
      Reimbursement(
        target: transactionFromMap(
          map,
          accounts: accounts,
          categories: categories,
          tags: tags,
        ),
        value: map["reimb_value"] as int,
      ),
  ];
}
