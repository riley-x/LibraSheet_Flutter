import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:libra_sheet/graphing/cartesian/cartesian_axes.dart';
import 'package:libra_sheet/graphing/cartesian/cartesian_coordinate_space.dart';
import 'package:libra_sheet/graphing/cartesian/month_axis.dart';
import 'package:libra_sheet/graphing/series/column_series.dart';
import 'package:libra_sheet/graphing/series/series.dart';

class _DiscreteCartesianGraphPainter<T> extends CustomPainter {
  final CartesianAxis xAxis;
  final CartesianAxis yAxis;
  final ThemeData theme;
  final List<Series<T>> data;

  /// Variables of a given paint
  Size currentSize = Size.zero;
  CartesianCoordinateSpace? coordSpace;
  List<(double, TextPainter)>? xLabels;
  List<(double, TextPainter)>? yLabels;

  _DiscreteCartesianGraphPainter({
    super.repaint,
    required this.data,
    required this.xAxis,
    required this.yAxis,
    required this.theme,
  });

  /// Lays out the axis with default labels and padding.
  void layoutAxes(Size size) {
    if (size == currentSize) return;

    currentSize = size;
    coordSpace = CartesianCoordinateSpace.fromAxes(
      canvasSize: size,
      xAxis: xAxis,
      yAxis: yAxis,
    );
    coordSpace!.autoRange(xAxis: xAxis, yAxis: yAxis, data: data);

    /// Auto labels and axis padding; TODO this is hard coded for bottom and left aligned labels
    yLabels = yAxis.autoYLabels(coordSpace!);
    if (coordSpace!.xAxis.padStart == null) {
      var maxLabelWidth = 0.0;
      for (final (_, x) in yLabels!) {
        maxLabelWidth = max(maxLabelWidth, x.width);
      }
      coordSpace!.xAxis.padStart = maxLabelWidth + yAxis.labelOffset;
    }
    xLabels = xAxis.autoXLabels(coordSpace!);
    if (coordSpace!.yAxis.padStart == null) {
      coordSpace!.yAxis.padStart = coordSpace!.xAxis.labelLineHeight + xAxis.labelOffset;
    }
  }

  // TODO this is hard coded for bottom and left aligned labels
  void paintLabels(Canvas canvas) {
    if (coordSpace == null) return;

    /// x labels
    if (xLabels != null) {
      for (final (pos, painter) in xLabels!) {
        final loc = Offset(
          coordSpace!.xAxis.userToPixel(pos) - painter.width / 2,
          coordSpace!.yAxis.pixelMin + yAxis.labelOffset,
        );
        painter.paint(canvas, loc);
      }
    }

    /// y labels
    if (yLabels != null) {
      for (final (pos, painter) in yLabels!) {
        final loc = Offset(
          coordSpace!.xAxis.pixelMin - yAxis.labelOffset - painter.width,
          coordSpace!.yAxis.userToPixel(pos) - painter.height / 2,
        );
        painter.paint(canvas, loc);
      }
    }
  }

  List<double> _defaultXGridlines() {
    List<double> out = [];
    if (xLabels != null) {
      for (final (pos, _) in xLabels!) {
        out.add(pos);
      }
    }
    return out;
  }

  List<double> _defaultYGridlines() {
    List<double> out = [];
    if (yLabels != null) {
      for (final (pos, _) in yLabels!) {
        out.add(pos);
      }
    }
    return out;
  }

  void paintGridLines(Canvas canvas) {
    if (coordSpace == null) return;

    /// Horizontal grid lines
    final horizontalGridLines = yAxis.gridLines ?? _defaultYGridlines();
    for (final pos in horizontalGridLines) {
      double y = coordSpace!.yAxis.userToPixel(pos);
      double x1 = coordSpace!.xAxis.pixelMin;
      double x2 = coordSpace!.xAxis.pixelMax;
      canvas.drawLine(Offset(x1, y), Offset(x2, y), yAxis.gridLinePainter);
    }

    /// Vertical grid lines
    final verticalGridLines = xAxis.gridLines ?? _defaultXGridlines();
    for (final pos in verticalGridLines) {
      double x = coordSpace!.xAxis.userToPixel(pos);
      double y1 = coordSpace!.yAxis.pixelMin;
      double y2 = coordSpace!.yAxis.pixelMax;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), xAxis.gridLinePainter);
    }
  }

  void paintAxisLines(Canvas canvas) {
    if (coordSpace == null) return;
    if (xAxis.axisLoc != null) {
      double x1 = coordSpace!.xAxis.pixelMin;
      double x2 = coordSpace!.xAxis.pixelMax;
      double y = coordSpace!.yAxis.userToPixel(xAxis.axisLoc!);
      canvas.drawLine(Offset(x1, y), Offset(x2, y), xAxis.axisPainter);
    }

    if (yAxis.axisLoc != null) {
      double y1 = coordSpace!.yAxis.pixelMin;
      double y2 = coordSpace!.yAxis.pixelMax;
      double x = coordSpace!.xAxis.userToPixel(yAxis.axisLoc!);
      canvas.drawLine(Offset(x, y1), Offset(x, y2), yAxis.axisPainter);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    layoutAxes(size);
    if (coordSpace == null) return;
    paintGridLines(canvas);
    for (final series in data) {
      series.paint(canvas, coordSpace!);
    }
    paintLabels(canvas);
    paintAxisLines(canvas);
  }

  @override
  bool shouldRepaint(_DiscreteCartesianGraphPainter<T> oldDelegate) {
    return xAxis != oldDelegate.xAxis || yAxis != oldDelegate.yAxis || data != oldDelegate.data;
  }
}

class _DiscreteCartesianGraphHoverPainter extends CustomPainter {
  final _DiscreteCartesianGraphPainter mainGraph;
  final ValueNotifier<int?> hoverLoc;

  _DiscreteCartesianGraphHoverPainter({
    required this.mainGraph,
    required this.hoverLoc,
  }) : super(repaint: hoverLoc);

  @override
  void paint(Canvas canvas, Size size) {
    if (size != mainGraph.currentSize) return;
    if (mainGraph.coordSpace == null) return;
    if (hoverLoc.value == null) return;

    final loc = mainGraph.coordSpace!.xAxis.userToPixel(hoverLoc.value!.toDouble());
    canvas.drawLine(
      Offset(loc, mainGraph.coordSpace!.yAxis.pixelMin),
      Offset(loc, mainGraph.coordSpace!.yAxis.pixelMax),
      Paint()
        ..color = Colors.white
        ..isAntiAlias = false,
    );
  }

  @override
  bool shouldRepaint(_DiscreteCartesianGraphHoverPainter oldDelegate) {
    return mainGraph != oldDelegate.mainGraph;
  }
}

class DiscreteCartesianGraph extends StatefulWidget {
  final MonthAxis xAxis;
  final CartesianAxis yAxis;

  const DiscreteCartesianGraph({
    super.key,
    required this.xAxis,
    required this.yAxis,
  });

  @override
  State<DiscreteCartesianGraph> createState() => _DiscreteCartesianGraphState();
}

class _DiscreteCartesianGraphState extends State<DiscreteCartesianGraph> {
  final hoverLocX = ValueNotifier<int?>(null);
  _DiscreteCartesianGraphPainter? painter;
  _DiscreteCartesianGraphHoverPainter? hoverPainter;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    painter = _DiscreteCartesianGraphPainter(
      theme: Theme.of(context),
      xAxis: widget.xAxis,
      yAxis: widget.yAxis,
      data: [testColumnSeries],
    );
    hoverPainter = _DiscreteCartesianGraphHoverPainter(
      mainGraph: painter!,
      hoverLoc: hoverLocX,
    );
  }

  void onHover(PointerHoverEvent event) {
    if (painter == null || painter!.currentSize == Size.zero || painter!.coordSpace == null) return;
    final userX = painter!.coordSpace!.xAxis.pixelToUser(event.localPosition.dx).round();
    if (userX < 0 || userX >= widget.xAxis.dates.length) {
      hoverLocX.value = null;
    } else {
      hoverLocX.value = userX;
    }
  }

  void onExit(PointerExitEvent event) {
    hoverLocX.value = null;
  }

  @override
  Widget build(BuildContext context) {
    // print(MediaQuery.of(context).devicePixelRatio);
    print(painter);
    return MouseRegion(
      onHover: onHover,
      onExit: onExit,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: painter,
              size: Size.infinite,
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(
              foregroundPainter: hoverPainter,
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}
