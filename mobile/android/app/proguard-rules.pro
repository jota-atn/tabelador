# Ações de widget (Glance) são criadas por reflexão pelo construtor vazio;
# sem isto o R8 tira o construtor no release e tocar na caixinha do widget
# de Tarefas não faz nada (NoSuchMethodException em AlternarTarefa.<init>).
-keep class * implements androidx.glance.appwidget.action.ActionCallback {
    <init>();
}
