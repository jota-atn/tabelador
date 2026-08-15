package com.jota.tabelador

import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

/**
 * O `AppWidgetProvider` de verdade — é este nome que `HomeWidget.updateWidget`
 * (lado Dart) e o `<receiver>` do manifest precisam bater.
 */
class TodayScheduleWidgetReceiver : HomeWidgetGlanceWidgetReceiver<TodayScheduleWidget>() {
    override val glanceAppWidget = TodayScheduleWidget()
}
