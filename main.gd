extends Node2D

# --- CONFIGURAÇÕES VISUAIS ---
const COR_FUNDO = Color("#2e8b57") 
const COR_TRIANGULO_1 = Color("#e0e0e0") 
const COR_TRIANGULO_2 = Color("#cd5c5c") 
const COR_BRANCAS = Color("#ffffff")
const COR_PRETAS = Color("#111111")
const COR_MOVEL = Color("#00FF00")   # Verde Neon

const LARGURA_CASA = 1280.0 / 13.0
const ALTURA_CASA = 720.0 * 0.4
const RAIO_PECA = 28.0

# --- ESTADO DO JOGO ---
var board: Array[int] = []
var dados_disponiveis: Array[int] = [] # Lista de movimentos (ex: [3, 5] ou [4,4,4,4])
var casa_selecionada: int = -1
var turno_atual: int = 1 # 1 = Vez das Brancas, -1 = Vez das Pretas

func _ready():
	iniciar_tabuleiro()
	if has_node("BtnRolar"):
		$BtnRolar.pressed.connect(rolar_dados)
		
	# Atualiza o texto inicial
	atualizar_interface()

func iniciar_tabuleiro():
	board.resize(24)
	board.fill(0)
	board[0] = 2; board[11] = 5; board[16] = 3; board[18] = 5
	board[23] = -2; board[12] = -5; board[7] = -3; board[5] = -5
	
	turno_atual = 1 # Brancas começam
	dados_disponiveis = [] # Ninguém rolou ainda
	queue_redraw()

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		detectar_casa_clicada(event.position)

func detectar_casa_clicada(pos_mouse: Vector2):
	var coluna_visual = int(pos_mouse.x / LARGURA_CASA)
	if coluna_visual == 6: return 
	
	var coluna_ajustada = coluna_visual
	if coluna_visual > 6: coluna_ajustada -= 1
		
	var eh_topo = pos_mouse.y < (720 / 2)
	var indice = -1
	
	if eh_topo: indice = 12 + coluna_ajustada
	else:       indice = 11 - coluna_ajustada
	
	if indice >= 0 and indice <= 23:
		gerenciar_clique(indice)

func gerenciar_clique(indice: int):
	# CENÁRIO 1: Nada selecionado -> Tenta SELECIONAR
	if casa_selecionada == -1:
		# Regra 1: Só pode selecionar peças do jogador do turno atual
		# sign() retorna 1 para positivo, -1 para negativo
		if board[indice] != 0 and sign(board[indice]) == turno_atual:
			
			# Regra 2: Só pode selecionar se tiver dados para usar
			if dados_disponiveis.size() > 0:
				casa_selecionada = indice
				print("Selecionou casa ", indice, " (Turno: ", turno_atual, ")")
			else:
				print("Sem dados! Role os dados primeiro.")
		else:
			print("Não é sua vez ou casa vazia.")
	
	# CENÁRIO 2: Algo selecionado -> Tenta MOVER
	else:
		if casa_selecionada == indice:
			casa_selecionada = -1 # Cancela
		else:
			# Verifica se o clique foi em um destino válido calculado
			var movimentos = calcular_destinos_validos(casa_selecionada)
			if indice in movimentos:
				mover_peca(casa_selecionada, indice)
				casa_selecionada = -1
			else:
				print("Movimento inválido para os dados atuais.")
				casa_selecionada = -1 # Cancela se clicar errado
	
	queue_redraw()

# --- NOVA LÓGICA DE CÁLCULO DE DESTINOS ---
func calcular_destinos_validos(origem: int) -> Array:
	var destinos = []
	var direcao = 1 if turno_atual == 1 else -1 # Brancas sobem (+), Pretas descem (-)
	
	# Para cada valor de dado disponível (ex: 3 e 5), calcula onde cairia
	# Usamos um dicionário ou verificação para evitar duplicatas visuais
	for valor_dado in dados_disponiveis:
		var destino_potencial = origem + (valor_dado * direcao)
		
		# Verifica se está dentro do tabuleiro (0 a 23)
		if destino_potencial >= 0 and destino_potencial <= 23:
			# REGRA BÁSICA DE OCUPAÇÃO:
			# Pode ir se for vazia (0) OU se tiver peças suas (mesmo sinal)
			# (Ainda não implementamos a regra de comer peças inimigas expostas, 
			#  apenas bloqueamos se tiver inimigos)
			var qtd_destino = board[destino_potencial]
			
			# Se destino for vazio OU tiver peças da minha cor
			if qtd_destino == 0 or sign(qtd_destino) == turno_atual:
				destinos.append(destino_potencial)
	
	return destinos

func mover_peca(origem: int, destino: int):
	# 1. Atualiza o Tabuleiro
	var valor_peca = 1 if turno_atual == 1 else -1
	board[origem] -= valor_peca
	board[destino] += valor_peca
	
	# 2. Consome o Dado usado
	# Calcula qual distância foi andada para saber qual dado remover
	var distancia = abs(destino - origem)
	if distancia in dados_disponiveis:
		dados_disponiveis.erase(distancia) # Remove apenas a primeira ocorrência
	
	print("Moveu. Dados restantes: ", dados_disponiveis)
	atualizar_interface()

func rolar_dados():
	# Passa a vez automaticamente ao rolar (simples para testar)
	# Na vida real, você rola no INÍCIO do seu turno. 
	# Aqui vamos alternar: Se era Branco, vira Preto e rola.
	if dados_disponiveis.size() == 0: # Só troca se acabou os movimentos (opcional)
		turno_atual = -turno_atual
	
	var d1 = randi_range(1, 6)
	var d2 = randi_range(1, 6)
	
	# Regra do Duplo
	if d1 == d2:
		dados_disponiveis = [d1, d1, d1, d1]
		print("DUPLO! 4 movimentos de ", d1)
	else:
		dados_disponiveis = [d1, d2]
		print("Dados: ", d1, " e ", d2)
		
	atualizar_interface()
	queue_redraw()

func atualizar_interface():
	if has_node("LblResultado"):
		var nome_jogador = "BRANCAS" if turno_atual == 1 else "PRETAS"
		var texto = "Vez de: " + nome_jogador + "\nDados: " + str(dados_disponiveis)
		$LblResultado.text = texto

# --- DESENHO ---
func _draw():
	draw_rect(Rect2(0, 0, 1280, 720), COR_FUNDO)
	
	# Se tiver peça selecionada, calcula onde ela pode ir para desenhar os contornos
	var destinos_validos = []
	if casa_selecionada != -1:
		destinos_validos = calcular_destinos_validos(casa_selecionada)
	
	for i in range(24):
		desenhar_casa(i, destinos_validos)

func desenhar_casa(indice: int, destinos_validos: Array):
	var eh_topo = (indice >= 12)
	var pos_x = 0.0
	
	if eh_topo: pos_x = (indice - 12) * LARGURA_CASA + (LARGURA_CASA / 2)
	else:       pos_x = (11 - indice) * LARGURA_CASA + (LARGURA_CASA / 2)
	if pos_x >= (6 * LARGURA_CASA): pos_x += LARGURA_CASA 

	var pos_y_base = 0 if eh_topo else 720
	var pos_y_ponta = 300 if eh_topo else 420
	
	# Triângulo
	var cor_triangulo = COR_TRIANGULO_1 if indice % 2 == 0 else COR_TRIANGULO_2
	var pontos = PackedVector2Array([
		Vector2(pos_x - LARGURA_CASA/2, pos_y_base),
		Vector2(pos_x + LARGURA_CASA/2, pos_y_base),
		Vector2(pos_x, pos_y_ponta)
	])
	draw_colored_polygon(pontos, cor_triangulo)
	
	# CONTORNO DE DESTINO (Verde Neon)
	# Só desenha se este índice estiver na lista de destinos válidos calculados
	if indice in destinos_validos:
		var pontos_contorno = PackedVector2Array([
			Vector2(pos_x - LARGURA_CASA/2, pos_y_base),
			Vector2(pos_x, pos_y_ponta),
			Vector2(pos_x + LARGURA_CASA/2, pos_y_base),
			Vector2(pos_x - LARGURA_CASA/2, pos_y_base)
		])
		draw_polyline(pontos_contorno, COR_MOVEL, 3.0)
	
	# Peças
	var qtd = board[indice]
	if qtd != 0:
		var cor_p = COR_BRANCAS if qtd > 0 else COR_PRETAS
		var dir = 1 if eh_topo else -1
		var num_pecas = abs(qtd)
		
		for p in range(num_pecas):
			var off_y = (RAIO_PECA * 2 * p * dir) + (RAIO_PECA * dir)
			var centro = Vector2(pos_x, pos_y_base + off_y)
			
			var cor_atual = cor_p
			# Se selecionado e for topo
			if indice == casa_selecionada and p == num_pecas - 1:
				cor_atual = COR_MOVEL
				
			draw_circle(centro, RAIO_PECA, cor_atual)
			
			# LÓGICA DO ANEL VERDE (Movimento Possível)
			# Agora verificamos não só se é a peça do topo, mas se é a VEZ dela
			var eh_minha_vez = sign(qtd) == turno_atual
			var tenho_dados = dados_disponiveis.size() > 0
			
			if p == num_pecas - 1 and casa_selecionada == -1 and eh_minha_vez and tenho_dados:
				draw_arc(centro, RAIO_PECA, 0, 360, 32, COR_MOVEL, 4.0)
			else:
				# Contorno padrão preto para peças normais
				draw_arc(centro, RAIO_PECA, 0, 360, 32, Color.BLACK, 2.0)
