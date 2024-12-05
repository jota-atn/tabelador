from tabulate import tabulate as table
from termcolor import colored as color

HEADER = ['HORÁRIOS', 'SEGUNDA', 'TERÇA', 'QUARTA', 'QUINTA', 'SEXTA']
HORA_INICIAL = 8
INTERVALO = 2
N_HORARIOS = 6

def gerar_horarios(hora_inicial, intervalo, n_horarios): 
    """
    Função que gera os horários tendo como base um horário inicial, num intervalo de 
    alteração e uma quantidade de horários para a tabela. Gera uma lista com sublistas
    dentro.

    Args:
        hora_inicial (int): O primeiro horário para cada dia.
        intervalo (int): O intervalo entre um horário e outro. Ex: (8:00 até as 10:00 caso seja 2).
        n_horarios (int): A quantidade de horários que os dias terão.

    Returns:
        list: Uma lista contendo listas de Strings formatadas com todos os horários. Geradas a partir de um List Comprehension de uma f-String pré-definida.
    """
    return [[f"{hora_inicial + i * intervalo}:00-{hora_inicial + (i + 1) * intervalo}:00"] for i in range(n_horarios)]

def colorir(texto):
    """
    Função responsável por colorir algum texto, que será printado futuramente na tabela. 
    Tendo como base um dicionário/mapa, a função gera uma cor com base no valor de cada
    texto no dicionário 'cores' respectivo.

    Args:
        texto (str): O texto que será colorido.

    Returns:
        str: Retorna a String colorida.

    """

    cores = {
        "MONITORIA": "red",
        "ALMOÇO": "yellow",
        "ALMOCO": "yellow",
        "LIVRE": "green"
    }
    cor = cores.get(texto, "white" if texto not in HEADER else "blue")
    return color(texto, cor)

def preencher_horarios(horarios):

    """
    Função que preenche uma lista com os horários passados pelo usuário.
    
    Args:
        horarios (list): Uma lista contendo listas de Strings, com os horários da tabela.

    Returns:
        list: Retorna a tabela preenchida completamente, como uma matriz contendo Strings.

    Raises:
        ValueError: Exceção relacionada às entradas vazias.

    """

    for dia in HEADER[1:]:
        print(f"\n-------------------------------")
        print(f"INSIRA OS HORÁRIOS DE {dia}")
        for i, hora in enumerate(horarios):
            while True:
                try:
                    entrada = input(f"HORÁRIO {i + 1} ({hora[0]}): ").strip().upper()
                    if not entrada:
                        raise ValueError("A entrada não pode estar vazia.")
                    hora.append(entrada)
                    break
                except ValueError as e:
                    print(color(f"Erro: {e}", "red"))
        print("-------------------------------")
    return horarios

def aplicar_cor_horarios(horarios):

    """
    Função responsável por colorir a tabela com os horários.

    Args: 
        horarios (list): Lista que contem listas de Strings com os horários fornecidos pelo usuário.
    
    Returns:
        list: A matriz que será utilizada como tabela.

    """

    return [[colorir(celula) if i > 0 else celula for i, celula in enumerate(linha)] for linha in horarios]

def main():
    horarios = gerar_horarios(HORA_INICIAL, INTERVALO, N_HORARIOS)
    horarios = preencher_horarios(horarios)
    horarios = aplicar_cor_horarios(horarios)
    print(table(horarios, headers=HEADER, tablefmt='fancy_grid'))

if __name__ == "__main__":
    main()

