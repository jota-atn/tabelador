/// Versão mostrada em Ajustes. Um teste confere que bate com o
/// `pubspec.yaml` (sem pacote nativo só pra ler isso).
const String kVersao = '1.20.0';

/// O que mudou, da versão mais nova pra trás — Ajustes → Sobre.
const List<(String, List<String>)> kNovidades = [
  (
    '1.20',
    [
      'Widget novo "Tarefas": as pendentes por seção, como na aba Tarefas; tocar na caixinha risca e a tarefa some.',
    ],
  ),
  (
    '1.19',
    [
      'Widget novo "Próximo": o próximo horário ou evento, com contagem, local e o que está acontecendo agora.',
    ],
  ),
  (
    '1.18',
    [
      'Cada tabela escolhe se a semana começa na segunda ou no domingo; a grade, a navegação, "Esta semana" e os calendários seguem a tabela ativa.',
    ],
  ),
  (
    '1.17',
    [
      'Avisos: escolha a hora do aviso de dia todo e quantos dias antes vem o lembrete de presente.',
      'Eventos e Tarefas: esconda os tipos de evento que você não usa.',
    ],
  ),
  (
    '1.16',
    [
      'Introdução nova: itens, eventos e tarefas, e o visual do app escolhido ali mesmo.',
    ],
  ),
  (
    '1.15',
    [
      'Ajustes organizados em seções.',
      'Tema e cor do app escolhidos ficam salvos.',
      'Resumo da Semana pode ser desligado, e você escolhe quantos eventos ele mostra.',
      '"Mostrar concluídas" em Tarefas fica como você deixou.',
    ],
  ),
  (
    '1.14',
    [
      'Tarefas: progresso do dia, faixa de prioridade e campo de adicionar rápido.',
    ],
  ),
  (
    '1.13',
    [
      'Aba Eventos cabe na tela; página de cada tipo com o topo fixo.',
    ],
  ),
  (
    '1.11',
    [
      'Resumo da Semana com cor, só eventos e seta pra recolher.',
    ],
  ),
];
