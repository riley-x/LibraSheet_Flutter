import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:libra_sheet/data/app_state/transaction_service.dart';
import 'package:libra_sheet/data/database/transactions.dart' as db;
import 'package:libra_sheet/data/int_dollar.dart';
import 'package:libra_sheet/data/objects/account.dart';
import 'package:libra_sheet/data/objects/category.dart';
import 'package:libra_sheet/data/enums.dart';
import 'package:libra_sheet/data/objects/tag.dart';
import 'package:libra_sheet/data/objects/transaction.dart';

class TransactionTabState extends ChangeNotifier {
  TransactionTabState(this.service) {
    loadTransactions();
  }
  final TransactionService service;

  /// Mutable filter list
  final db.TransactionFilters filters = db.TransactionFilters();

  /// Error state for the text boxes
  bool startTimeError = false;
  bool endTimeError = false;
  bool minValueError = false;
  bool maxValueError = false;

  /// States for the dropdown checkbox filters
  final Set<Account> accountFilterSelected = {};
  final CategoryTristateMap categoryFilterSelected = CategoryTristateMap();
  final List<Tag> tags = [];

  /// Loaded transactions
  List<Transaction> transactions = [];

  void loadTransactions() async {
    notifyListeners();
    filters.categories = categoryFilterSelected.activeKeys();
    filters.accounts = accountFilterSelected.map((e) => e.key);
    filters.tags = tags.map((e) => e.key);
    transactions = await service.load(filters);
    notifyListeners();
  }

  void setAccountFilter(Account account, bool? selected) {
    if (selected == true) {
      accountFilterSelected.add(account);
    } else {
      accountFilterSelected.remove(account);
    }
    loadTransactions();
  }

  void setMinValue(String? text) {
    int? value;
    if (text == null || text.isEmpty) {
      value = null;
      minValueError = false;
    } else {
      value = text.toIntDollar();
      minValueError = value == null;
    }
    if (!minValueError) {
      filters.minValue = value;
      loadTransactions();
    } else {
      notifyListeners();
    }
  }

  void setMaxValue(String? text) {
    int? value;
    if (text == null || text.isEmpty) {
      value = null;
      maxValueError = false;
    } else {
      value = text.toIntDollar();
      maxValueError = value == null;
    }
    if (!maxValueError) {
      filters.maxValue = value;
      loadTransactions();
    } else {
      notifyListeners();
    }
  }

  (DateTime?, bool) _parseDate(String? text) {
    DateTime? time;
    bool error = false;
    if (text == null || text.isEmpty) {
      // pass
    } else {
      try {
        final format = DateFormat('MM/dd/yy');
        time = format.parse(text);
      } on FormatException {
        error = true;
      }
    }
    debugPrint('TransactionTabState::_parseDate() text:$text time=$time error=$error');
    return (time, error);
  }

  void setStartTime(String? text) {
    final val = _parseDate(text);
    startTimeError = val.$2;
    if (!startTimeError) {
      filters.startTime = val.$1;
      loadTransactions();
    } else {
      notifyListeners();
    }
  }

  void setEndTime(String? text) {
    final val = _parseDate(text);
    endTimeError = val.$2;
    if (!endTimeError) {
      filters.endTime = val.$1;
      loadTransactions();
    } else {
      notifyListeners();
    }
  }

  void onTagChanged(Tag tag, bool? selected) {
    if (selected == true) {
      tags.add(tag);
    } else {
      tags.remove(tag);
    }
    loadTransactions();
  }
}
