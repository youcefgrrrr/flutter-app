import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/stats_service.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<StatsService>();
    final profile = context.watch<AuthService>().profile;
    final fullName = profile?.fullName ?? 'Utilisateur';

    if (stats.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final goalOptions = [10, 15, 20, 25, 30, 40, 50];

    if (stats.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                stats.loadError!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: stats.refresh,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: stats.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text.rich(
            TextSpan(
              text: 'Bienvenue, ',
              style: Theme.of(context).textTheme.titleLarge,
              children: [
                TextSpan(
                  text: fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ' !'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Temps d\'écoute ce mois',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${stats.totalHours} h ${stats.remainingMinutes} min',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Objectif mensuel :'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: stats.monthlyGoalHours,
                items: goalOptions
                    .map(
                      (h) => DropdownMenuItem(
                        value: h,
                        child: Text('$h heures'),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) stats.setMonthlyGoalHours(v);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: stats.goalProgress,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 4),
          Text(
            '${(stats.goalProgress * 100).toStringAsFixed(0)} % de l\'objectif (${stats.monthlyGoalHours} h)',
          ),
          const SizedBox(height: 24),
          Text(
            'Minutes par jour (mois en cours)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: _MonthlyChart(stats: stats),
          ),
          const SizedBox(height: 24),
          Text(
            'Morceaux les plus écoutés',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (stats.topTracks.isEmpty)
            const Text('Aucune écoute enregistrée pour le moment.')
          else
            ...stats.topTracks.map(
              (t) => ListTile(
                leading: const CircleAvatar(child: Icon(Icons.headphones)),
                title: Text(t.title),
                subtitle: Text(t.subtitle),
                trailing: Text('${t.playCount}×'),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.stats});

  final StatsService stats;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final minutesByDay = <int, int>{};
    for (final d in stats.dailyStats) {
      if (d.date.year == now.year && d.date.month == now.month) {
        minutesByDay[d.date.day] = d.minutes;
      }
    }

    final bars = List.generate(daysInMonth, (i) {
      final day = i + 1;
      final minutes = minutesByDay[day] ?? 0;
      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: minutes.toDouble(),
            color: Theme.of(context).colorScheme.primary,
            width: 6,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

    final maxY = minutesByDay.values.isEmpty
        ? 10.0
        : (minutesByDay.values.reduce((a, b) => a > b ? a : b) + 5).toDouble();

    return BarChart(
      BarChartData(
        maxY: maxY,
        barGroups: bars,
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 32),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                if (day == 1 || day == 15 || day == daysInMonth) {
                  return Text('$day');
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
