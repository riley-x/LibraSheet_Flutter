import 'package:flutter/foundation.dart' as fnd;
import 'package:libra_sheet/data/app_state/libra_app_state.dart';
import 'package:libra_sheet/data/database/category_history.dart';
import 'package:libra_sheet/data/objects/category.dart';
import 'package:libra_sheet/data/time_value.dart';

class CashFlowState extends fnd.ChangeNotifier {
  CashFlowState(this.appState) {
    _init();
  }

  final LibraAppState appState;

  List<CategoryHistory> incomeData = [];
  List<CategoryHistory> expenseData = [];

  void _loadList(
    List<CategoryHistory> list,
    Map<int, List<TimeIntValue>> categoryHistory,
    Category parent,
  ) {
    final parentVals = categoryHistory[parent.key];
    if (parentVals != null) {
      list.add(CategoryHistory(parent, alignTimes(parentVals, appState.monthList)));
    }

    for (final cat in parent.subCats) {
      var vals = categoryHistory[cat.key];
      if (vals != null) {
        vals = alignTimes(vals, appState.monthList);
      }

      /// Add values from subcategories too. Only need to recurse once since max level = 2.
      for (final subCat in cat.subCats) {
        var subVals = categoryHistory[subCat.key];
        if (subVals == null) continue;
        subVals = alignTimes(subVals, appState.monthList);
        vals = (vals == null) ? subVals : addParallel(vals, subVals);
      }
      if (vals != null) {
        list.add(CategoryHistory(cat, vals));
      }
    }
  }

  Future<void> _init() async {
    final categoryHistory = await getCategoryHistory();

    incomeData.clear();
    _loadList(incomeData, categoryHistory, appState.categories.income);

    expenseData.clear();
    _loadList(expenseData, categoryHistory, appState.categories.expense);

    notifyListeners();
  }
}
