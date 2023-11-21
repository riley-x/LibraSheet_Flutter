import 'package:flutter/material.dart';
import 'package:libra_sheet/data/account.dart';
import 'package:libra_sheet/data/allocation.dart';
import 'package:libra_sheet/data/category.dart';
import 'package:libra_sheet/data/enums.dart';
import 'package:libra_sheet/data/reimbursement.dart';
import 'package:libra_sheet/data/tag.dart';
import 'package:libra_sheet/data/transaction.dart';

enum TransactionDetailActiveFocus { none, allocation, reimbursement }

class TransactionDetailsState extends ChangeNotifier {
  TransactionDetailsState(this.seed) {
    _init();
  }
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> allocationFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> reimbursementFormKey = GlobalKey<FormState>();

  /// Initial values for the respective editors. Don't edit these; they're used to reset.
  Transaction? seed;
  Allocation? focusedAllocation;
  Reimbursement? focusedReimbursement;

  /// Updated values for the respective editors. These are used to save the values retrieved from
  /// the various FormFields' onSave methods. They don't contain any UI state, so don't need to
  /// notifyListeners.
  final MutableAllocation updatedAllocation = MutableAllocation();
  final MutableReimbursement updatedReimbursement = MutableReimbursement();

  /// These variables are saved to by the relevant FormFields. Don't need to manage via SetState.
  Account? account;
  String? name;
  DateTime? date;
  int? value;
  Category? category;
  String? note;

  /// These variables are the state for the relevant fields
  ExpenseFilterType expenseType = ExpenseFilterType.all;
  final List<Tag> tags = [];
  final List<Allocation> allocations = [];
  final List<Reimbursement> reimbursements = [];

  TransactionDetailActiveFocus focus = TransactionDetailActiveFocus.none;

  void _init() {
    if (seed != null) {
      expenseType = _valToFilterType(seed?.value);
      tags.insertAll(0, seed?.tags ?? const []);
      allocations.insertAll(0, seed?.allocations ?? const []);
      reimbursements.insertAll(0, seed?.reimbursements ?? const []);
    }
  }

  void reset() {
    formKey.currentState?.reset();
    tags.clear();
    allocations.clear();
    reimbursements.clear();
    _init();
    notifyListeners();
  }

  void save() {
    if (formKey.currentState?.validate() ?? false) {
      formKey.currentState?.save();
      if (name == null || date == null || value == null || note == null) {
        debugPrint("TransactionDetailsState:save() ERROR found null values!");
        return;
      }
      var t = Transaction(
        key: seed?.key ?? 0,
        name: name!,
        date: date!,
        value: value!,
        category: category,
        account: account,
        note: note!,
        allocations: allocations,
        reimbursements: reimbursements,
        tags: tags,
      );
      print(t); // TODO save transaction
    }
  }

  void delete() {
    // TODO
  }

  void onValueChanged(int? val) {
    var newType = _valToFilterType(val);
    if (newType != expenseType) {
      expenseType = newType;
      notifyListeners();
    }
  }

  void onTagChanged(Tag tag, bool? selected) {
    if (selected == true) {
      tags.add(tag);
    } else {
      tags.remove(tag);
    }
    notifyListeners();
  }

  ExpenseFilterType _valToFilterType(int? val) {
    if (val == null || val == 0) {
      return ExpenseFilterType.all;
    } else if (val > 0) {
      return ExpenseFilterType.income;
    } else {
      return ExpenseFilterType.expense;
    }
  }

  void clearFocus() {
    focusedAllocation = null;
    focusedReimbursement = null;
    focus = TransactionDetailActiveFocus.none;
    notifyListeners();
  }

  void focusAllocation(Allocation? alloc) {
    if (focus == TransactionDetailActiveFocus.reimbursement) {
      focusedReimbursement = null;
    }
    focusedAllocation = alloc;
    focus = TransactionDetailActiveFocus.allocation;
    notifyListeners();
  }

  void focusReimbursement(Reimbursement? it) {
    if (focus == TransactionDetailActiveFocus.allocation) {
      focusedAllocation = null;
    }
    focusedReimbursement = it;
    focus = TransactionDetailActiveFocus.reimbursement;
    notifyListeners();
  }

  void saveAllocation() {
    if (allocationFormKey.currentState?.validate() ?? false) {
      allocationFormKey.currentState?.save();
      if (focusedAllocation == null) {
        allocations.add(updatedAllocation);
      } else {
        for (int i = 0; i < allocations.length; i++) {
          if (allocations[i] == focusedAllocation) {
            allocations[i] = updatedAllocation.withKey(allocations[i].key);
            break;
          }
        }
      }
      clearFocus();
    }
  }

  void deleteAllocation() {
    allocations.remove(focusedAllocation);
    clearFocus();
  }

  void resetAllocation() {
    allocationFormKey.currentState?.reset();
  }

  void saveReimbursement() {
    if (reimbursementFormKey.currentState?.validate() ?? false) {
      reimbursementFormKey.currentState?.save();
      if (focusedReimbursement == null) {
        reimbursements.add(updatedReimbursement);
      } else {
        for (int i = 0; i < reimbursements.length; i++) {
          if (reimbursements[i] == focusedReimbursement) {
            reimbursements[i] = updatedReimbursement.freeze();
            break;
          }
        }
      }
      clearFocus();
    }
  }

  void deleteReimbursement() {
    reimbursements.remove(focusedReimbursement);
    clearFocus();
  }

  void resetReimbursement() {
    reimbursementFormKey.currentState?.reset();
  }
}
