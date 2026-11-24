import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../design_system/motion_system.dart';
import '../design_system/saas_design_system.dart';
import '../theme/app_theme.dart';
import 'saas_dashboard_widgets.dart';

/// Representa uma série temporal ou categórica para gráficos de linha/área.
class AncoraChartSeries {
  const AncoraChartSeries({
    required this.label,
    required this.values,
    required this.color,
    this.fillArea = false,
    this.dashed = false,
  });

  final String label;
  final List<double> values;
  final Color color;
  final bool fillArea;
  final bool dashed;
}

/// Linha de referência (ex.: limiar de alerta warning/critical).
class AncoraChartThreshold {
  const AncoraChartThreshold({
    required this.value,
    required this.label,
    required this.color,
  });

  final double value;
  final String label;
  final Color color;
}

/// Container padronizado estilo Grafana/Stripe para gráficos com título, unidade,
/// legendas, ações e resumo acessível para leitores de tela.
class AncoraChartCard extends StatelessWidget {
  const AncoraChartCard({
    super.key,
    required this.title,
    this.subtitle,
    this.unit,
    this.trailing,
    this.legendItems = const [],
    required this.child,
    this.height = 240,
    this.isLoading = false,
    this.isEmpty = false,
    this.emptyMessage = 'Sem dados suficientes no período selecionado.',
    this.semanticsSummary,
  });

  final String title;
  final String? subtitle;
  final String? unit;
  final Widget? trailing;
  final List<({String label, Color color})> legendItems;
  final Widget child;
  final double height;
  final bool isLoading;
  final bool isEmpty;
  final String emptyMessage;
  final String? semanticsSummary;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    return Semantics(
      label: semanticsSummary ?? '$title${unit != null ? ' ($unit)' : ''}',
      child: SaaSGlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                                color: tokens.textPrimary,
                              ),
                            ),
                          ),
                          if (unit != null && unit!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tokens.surfaceSubtle,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: tokens.border),
                              ),
                              child: Text(
                                unit!,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing!,
                ],
              ],
            ),
            if (legendItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: legendItems
                    .map(
                      (item) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: tokens.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: height,
              child: isLoading
                  ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: tokens.accent,
                        ),
                      ),
                    )
                  : isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.show_chart_rounded,
                            size: 28,
                            color: tokens.textMuted,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            emptyMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: tokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : child,
            ),
          ],
        ),
      ),
    );
  }
}

/// Gráfico de linha/área multi-série com tooltips, limiares e proteção contra séries vazias/constantes.
class AncoraLineAreaChart extends StatelessWidget {
  const AncoraLineAreaChart({
    super.key,
    required this.series,
    this.xLabels = const [],
    this.unitSuffix = '',
    this.minY = 0,
    this.maxYOverride,
    this.thresholds = const [],
  });

  final List<AncoraChartSeries> series;
  final List<String> xLabels;
  final String unitSuffix;
  final double minY;
  final double? maxYOverride;
  final List<AncoraChartThreshold> thresholds;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final nonEmpty = series.where((s) => s.values.isNotEmpty).toList();
    if (nonEmpty.isEmpty) {
      return Center(
        child: Text(
          'Aguardando amostras...',
          style: TextStyle(fontSize: 12, color: tokens.textMuted),
        ),
      );
    }

    int maxLen = 0;
    double rawMax = minY;
    for (final s in nonEmpty) {
      if (s.values.length > maxLen) maxLen = s.values.length;
      for (final v in s.values) {
        if (v.isFinite && v > rawMax) rawMax = v;
      }
    }
    for (final t in thresholds) {
      if (t.value > rawMax) rawMax = t.value;
    }

    final maxX = maxLen <= 1 ? 1.0 : (maxLen - 1).toDouble();
    final computedMaxY = maxYOverride ?? (rawMax <= minY ? minY + 10 : rawMax * 1.15);
    final safeMaxY = computedMaxY <= minY ? minY + 1.0 : computedMaxY;
    final yInterval = math.max(1.0, (safeMaxY - minY) / 4.0);
    final xInterval = maxLen <= 5 ? 1.0 : math.max(1.0, (maxX / 4.0).floorToDouble());
    final animDuration =
        (isRunningTestEnvironment || AncoraMotion.shouldReduceMotion(context))
            ? Duration.zero
            : const Duration(milliseconds: 260);

    return LineChart(
      duration: animDuration,
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: minY,
        maxY: safeMaxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: tokens.border.withValues(alpha: tokens.isDark ? 0.55 : 0.8),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: thresholds.isEmpty
            ? null
            : ExtraLinesData(
                horizontalLines: thresholds
                    .map(
                      (t) => HorizontalLine(
                        y: t.value,
                        color: t.color.withValues(alpha: 0.7),
                        strokeWidth: 1.2,
                        dashArray: [5, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: t.color,
                          ),
                          labelResolver: (_) => t.label,
                        ),
                      ),
                    )
                    .toList(),
              ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 64,
              interval: yInterval,
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '${_compactNum(val)}$unitSuffix',
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: tokens.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: xLabels.isNotEmpty,
              reservedSize: 26,
              interval: xInterval,
              getTitlesWidget: (val, meta) {
                final idx = val.round();
                if (idx < 0 || idx >= xLabels.length) return const SizedBox.shrink();
                if ((val - meta.max).abs() > 0.01 &&
                    (meta.max - val) < xInterval * 0.55) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    xLabels[idx],
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 10, color: tokens.textMuted),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                tokens.isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
            getTooltipItems: (spots) => spots.map((spot) {
              final s = nonEmpty[spot.barIndex];
              return LineTooltipItem(
                '${s.label}: ${_compactNum(spot.y)}$unitSuffix',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: nonEmpty.map((s) {
          final spots = <FlSpot>[
            for (int i = 0; i < s.values.length; i++)
              FlSpot(i.toDouble(), s.values[i].isFinite ? s.values[i] : 0.0),
          ];
          return LineChartBarData(
            spots: spots,
            isCurved: spots.length > 2,
            curveSmoothness: 0.25,
            color: s.color,
            barWidth: 2.3,
            isStrokeCapRound: true,
            dashArray: s.dashed ? [6, 4] : null,
            dotData: FlDotData(show: spots.length <= 1),
            belowBarData: BarAreaData(
              show: s.fillArea,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  s.color.withValues(alpha: tokens.isDark ? 0.26 : 0.18),
                  s.color.withValues(alpha: 0.01),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Item para gráfico de barras simples ou empilhadas.
class AncoraBarGroupItem {
  const AncoraBarGroupItem({
    required this.label,
    required this.segments,
  });

  final String label;
  final List<({String name, double value, Color color})> segments;

  double get total => segments.fold(0.0, (sum, s) => sum + s.value);
}

/// Gráfico de barras verticais (suporta barras simples, agrupadas ou empilhadas).
class AncoraBarChart extends StatelessWidget {
  const AncoraBarChart({
    super.key,
    required this.groups,
    this.unitSuffix = '',
    this.stacked = true,
  });

  final List<AncoraBarGroupItem> groups;
  final String unitSuffix;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    if (groups.isEmpty) {
      return Center(
        child: Text(
          'Sem registros no período',
          style: TextStyle(fontSize: 12, color: tokens.textMuted),
        ),
      );
    }

    double rawMax = 0;
    for (final g in groups) {
      final candidate = stacked
          ? g.total
          : g.segments.fold(0.0, (m, s) => math.max(m, s.value));
      if (candidate > rawMax) rawMax = candidate;
    }
    final safeMaxY = rawMax <= 0 ? 5.0 : rawMax * 1.18;
    final yInterval = math.max(1.0, safeMaxY / 4.0);
    final animDuration =
        (isRunningTestEnvironment || AncoraMotion.shouldReduceMotion(context))
            ? Duration.zero
            : const Duration(milliseconds: 260);

    return BarChart(
      duration: animDuration,
      BarChartData(
        maxY: safeMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: tokens.border.withValues(alpha: tokens.isDark ? 0.55 : 0.8),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: yInterval,
              getTitlesWidget: (val, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '${_compactNum(val)}$unitSuffix',
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: groups.length >= 6 ? 34 : 26,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= groups.length) return const SizedBox.shrink();
                final label = groups[idx].label;
                return Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2, right: 2),
                  child: groups.length >= 6
                      ? Transform.rotate(
                          angle: -0.35,
                          child: Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontSize: 9.5,
                              color: tokens.textMuted,
                            ),
                          ),
                        )
                      : Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: tokens.textMuted),
                        ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                tokens.isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
            getTooltipItem: (group, _, rod, __) {
              final g = groups[group.x];
              final lines = g.segments
                  .where((s) => s.value > 0)
                  .map((s) => '${s.name}: ${_compactNum(s.value)}$unitSuffix')
                  .join('\n');
              return BarTooltipItem(
                '${g.label}\n${lines.isEmpty ? '0$unitSuffix' : lines}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (int i = 0; i < groups.length; i++)
            _buildGroupData(i, groups[i], stacked),
        ],
      ),
    );
  }

  BarChartGroupData _buildGroupData(
    int index,
    AncoraBarGroupItem group,
    bool isStacked,
  ) {
    if (isStacked) {
      double running = 0;
      final stackItems = <BarChartRodStackItem>[];
      for (final seg in group.segments) {
        final v = seg.value < 0 ? 0.0 : seg.value;
        stackItems.add(BarChartRodStackItem(running, running + v, seg.color));
        running += v;
      }
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: running,
            width: groups.length > 10 ? 12 : 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            rodStackItems: stackItems,
            color: group.segments.isNotEmpty
                ? group.segments.first.color
                : AncoraChartPalette.indigo,
          ),
        ],
      );
    }

    return BarChartGroupData(
      x: index,
      barsSpace: 4,
      barRods: group.segments
          .map(
            (seg) => BarChartRodData(
              toY: seg.value < 0 ? 0.0 : seg.value,
              width: 12,
              color: seg.color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          )
          .toList(),
    );
  }
}

/// Histograma de distribuição (ex.: faixas de latência HTTP).
class AncoraHistogramChart extends StatelessWidget {
  const AncoraHistogramChart({
    super.key,
    required this.buckets,
    this.barColor = AncoraChartPalette.indigo,
  });

  final List<({String label, double count})> buckets;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return AncoraBarChart(
      stacked: true,
      groups: buckets
          .map(
            (b) => AncoraBarGroupItem(
              label: b.label,
              segments: [(name: 'Requisições', value: b.count, color: barColor)],
            ),
          )
          .toList(),
    );
  }
}

/// Fatia de gráfico de rosca.
class AncoraDonutSlice {
  const AncoraDonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// Gráfico de rosca com KPI central, interação ao toque e legenda tabular.
class AncoraDonutChart extends StatefulWidget {
  const AncoraDonutChart({
    super.key,
    required this.slices,
    required this.centerLabel,
    required this.centerValue,
    this.valueSuffix = '',
  });

  final List<AncoraDonutSlice> slices;
  final String centerLabel;
  final String centerValue;
  final String valueSuffix;

  @override
  State<AncoraDonutChart> createState() => _AncoraDonutChartState();
}

class _AncoraDonutChartState extends State<AncoraDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    final nonZero = widget.slices.where((s) => s.value > 0).toList();
    final total = nonZero.fold(0.0, (sum, s) => sum + s.value);

    if (nonZero.isEmpty || total <= 0) {
      return Center(
        child: Text(
          'Sem distribuição disponível',
          style: TextStyle(fontSize: 12, color: tokens.textMuted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 360;
        final ultraNarrow = box.maxWidth < 250;
        final chartSize = ultraNarrow ? 130.0 : (compact ? 118.0 : 170.0);
        final chartWidget = SizedBox(
          width: chartSize,
          height: chartSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: compact ? 34 : 50,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        if (_touchedIndex != -1) {
                          setState(() => _touchedIndex = -1);
                        }
                        return;
                      }
                      final idx = response.touchedSection!.touchedSectionIndex;
                      if (idx != _touchedIndex) {
                        setState(() => _touchedIndex = idx);
                      }
                    },
                  ),
                  sections: [
                    for (int i = 0; i < nonZero.length; i++)
                      PieChartSectionData(
                        value: nonZero[i].value,
                        color: nonZero[i].color,
                        radius: i == _touchedIndex
                            ? (compact ? 22 : 30)
                            : (compact ? 17 : 24),
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.centerValue,
                    style: TextStyle(
                      fontSize: compact ? 15 : 18,
                      fontWeight: FontWeight.w800,
                      color: tokens.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    widget.centerLabel,
                    style: TextStyle(fontSize: 10.5, color: tokens.textMuted),
                  ),
                ],
              ),
            ],
          ),
        );

        final legendWidget = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: nonZero.map((s) {
            final pct = total > 0 ? ((s.value / total) * 100).round() : 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${_compactNum(s.value)}${widget.valueSuffix} ($pct%)',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: tokens.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );

        if (ultraNarrow) {
          return SingleChildScrollView(
            child: Column(
              children: [
                chartWidget,
                const SizedBox(height: 12),
                legendWidget,
              ],
            ),
          );
        }

        return Row(
          children: [
            chartWidget,
            SizedBox(width: compact ? 12 : 18),
            Expanded(child: SingleChildScrollView(child: legendWidget)),
          ],
        );
      },
    );
  }
}

/// Item de ranking horizontal proporcional.
class AncoraRankingItem {
  const AncoraRankingItem({
    required this.label,
    required this.value,
    required this.displayValue,
    this.subtitle,
    this.color,
  });

  final String label;
  final double value;
  final String displayValue;
  final String? subtitle;
  final Color? color;
}

/// Ranking horizontal com barras proporcionais (endpoints, tabelas, condomínios).
class AncoraHorizontalRankingChart extends StatelessWidget {
  const AncoraHorizontalRankingChart({
    super.key,
    required this.items,
    this.defaultColor = AncoraChartPalette.indigo,
  });

  final List<AncoraRankingItem> items;
  final Color defaultColor;

  @override
  Widget build(BuildContext context) {
    final tokens = AncoraThemeTokens.of(context);
    if (items.isEmpty) {
      return Center(
        child: Text(
          'Nenhum item para ranquear',
          style: TextStyle(fontSize: 12, color: tokens.textMuted),
        ),
      );
    }

    final maxVal = items.fold(0.0, (m, i) => math.max(m, i.value));
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final item = items[idx];
        final ratio = (item.value / safeMax).clamp(0.0, 1.0);
        final barColor = item.color ?? defaultColor;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.displayValue,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                item.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: tokens.textMuted),
              ),
            ],
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: tokens.surfaceSubtle,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Mini sparkline para cards de KPI em tempo real.
class AncoraSparkline extends StatelessWidget {
  const AncoraSparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 28,
  });

  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(height: height);
    }
    double minV = values.first;
    double maxV = values.first;
    for (final v in values) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    if (maxV <= minV) {
      maxV = minV + 1.0;
    }
    return SizedBox(
      height: height,
      child: LineChart(
        duration: Duration.zero,
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: minV,
          maxY: maxV,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (int i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              color: color,
              barWidth: 1.8,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _compactNum(double v) {
  if (v == v.roundToDouble()) {
    return v.toInt().toString();
  }
  return v.toStringAsFixed(1);
}
