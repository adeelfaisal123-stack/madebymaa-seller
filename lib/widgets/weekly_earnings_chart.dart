import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/seller_dashboard.dart';
import '../theme/app_colors.dart';

class WeeklyEarningsChart extends StatelessWidget {
  const WeeklyEarningsChart({
    super.key,
    required this.days,
    required this.weekTotal,
    required this.loading,
  });

  final List<SellerWeeklyEarningDay> days;
  final double weekTotal;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final chartDays = days.length == 7
        ? days
        : parseWeeklyEarnings(null, SellerDashboardStats.empty);
    final maxAmount = chartDays
        .map((d) => d.amount)
        .fold(0.0, (a, b) => a > b ? a : b);
    final scaleMax = maxAmount > 0 ? maxAmount : 1.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            AppColors.cream.withValues(alpha: 0.85),
            AppColors.brandPurple.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: AppColors.brandPurple.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPurple.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              top: -28,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.bootstrapWarningBg,
                ),
              ),
            ),
            Positioned(
              left: -18,
              bottom: 36,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.sage.withValues(alpha: 0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.brandPurple.withValues(alpha: 0.18),
                              AppColors.terracotta.withValues(alpha: 0.14),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bar_chart_rounded,
                          color: AppColors.brandPurple,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Weekly earnings',
                              style: GoogleFonts.exo2(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepGreen,
                              ),
                            ),
                            Text(
                              'Mon – Sun snapshot',
                              style: GoogleFonts.exo2(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    AppColors.deepGreen.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            loading ? '…' : formatInr(weekTotal),
                            style: GoogleFonts.exo2(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brandPurple,
                            ),
                          ),
                          Text(
                            'This week',
                            style: GoogleFonts.exo2(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color:
                                  AppColors.deepGreen.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 196,
                    child: loading
                        ? const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.brandPurple,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: CustomPaint(
                                  painter: _ChartGridPainter(),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      for (final day in chartDays)
                                        Expanded(
                                          child: _WeeklyBarBody(
                                            day: day,
                                            scaleMax: scaleMax,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 30,
                                child: Row(
                                  children: [
                                    for (final day in chartDays)
                                      Expanded(
                                        child: _WeeklyBarLabel(day: day),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBarBody extends StatelessWidget {
  const _WeeklyBarBody({
    required this.day,
    required this.scaleMax,
  });

  final SellerWeeklyEarningDay day;
  final double scaleMax;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isToday = day.isToday;
        final hasValue = day.amount > 0;
        final showAmount = hasValue && isToday;
        final topReserve = showAmount ? 14.0 : 0.0;
        final maxBarHeight =
            (constraints.maxHeight - topReserve).clamp(8.0, double.infinity);
        final fraction = day.amount / scaleMax;
        final barHeight = day.amount > 0
            ? (fraction * maxBarHeight).clamp(10.0, maxBarHeight)
            : 8.0;

        final barGradient = isToday
            ? const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppColors.brandPurpleDeep, AppColors.brandPurple],
              )
            : LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: hasValue
                    ? [
                        AppColors.sage.withValues(alpha: 0.55),
                        AppColors.sage,
                      ]
                    : [
                        AppColors.deepGreen.withValues(alpha: 0.08),
                        AppColors.deepGreen.withValues(alpha: 0.14),
                      ],
              );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (showAmount)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    formatInr(day.amount),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: GoogleFonts.exo2(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandPurple,
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                height: barHeight,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: barGradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                    bottom: Radius.circular(4),
                  ),
                  boxShadow: isToday
                      ? [
                          BoxShadow(
                            color:
                                AppColors.brandPurple.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeeklyBarLabel extends StatelessWidget {
  const _WeeklyBarLabel({required this.day});

  final SellerWeeklyEarningDay day;

  @override
  Widget build(BuildContext context) {
    final isToday = day.isToday;
    final hasValue = day.amount > 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          day.label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: GoogleFonts.exo2(
            fontSize: 10,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
            color: isToday
                ? AppColors.brandPurple
                : AppColors.deepGreen.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: isToday ? 6 : 4,
          height: isToday ? 6 : 4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isToday
                ? AppColors.brandPurple
                : hasValue
                    ? AppColors.sage.withValues(alpha: 0.7)
                    : AppColors.deepGreen.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }
}

class _ChartGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.deepGreen.withValues(alpha: 0.06)
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
