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
var dados_disponiveis: Array[int] = [] 
var casa_selecionada: int = -1
var turno_atual: int = 1 # 1 = Brancas, -1 = Pretas

# Novas Variáveis para a BARRA (Peças comidas)
var bar_brancas: int = 0
var bar_pretas: int = 0

func _ready():
	iniciar_tabuleiro()
	if has_node("BtnRolar"):
		$BtnRolar.pressed.connect(rolar_dados)
	atualizar_interface()

func iniciar_tabuleiro():
	board.resize(24)
	board.fill(0)
	board[0] = 2; board[11] = 5; board[16] = 3; board[18] = 5
	board[23] = -2; board[12] = -5; board[7] = -3; board[5] = -5
	
	# Reseta a barra
	bar_brancas = 0
	bar_pretas = 0
	
	turno_atual = 1
	dados_disponiveis = []
	queue_redraw()

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		detectar_casa_clicada(event.position)

func detectar_casa_clicada(pos_mouse: Vector2):
	var coluna_visual = int(pos_mouse.x / LARGURA_CASA)
	if coluna_visual == 6: return # Clicou na barra (visualmente)
	
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
		if board[indice] != 0 and sign(board[indice]) == turno_atual:
			if dados_disponiveis.size() > 0:
				casa_selecionada = indice
			else:
				print("Sem dados! Role os dados primeiro.")
		else:
			print("Não é sua vez ou casa vazia.")
	
	# CENÁRIO 2: Algo selecionado -> Tenta MOVER
	else:
		if casa_selecionada == indice:
			casa_selecionada = -1 # Cancela
		else:
			var movimentos = calcular_destinos_validos(casa_selecionada)
			if indice in movimentos:
				mover_peca(casa_selecionada, indice)
				casa_selecionada = -1
			else:
				casa_selecionada = -1
	
	queue_redraw()

func calcular_destinos_validos(origem: int) -> Array:
	var destinos = []
	var direcao = 1 if turno_atual == 1 else -1 
	
	for valor_dado in dados_disponiveis:
		var destino_potencial = origem + (valor_dado * direcao)
		
		if destino_potencial >= 0 and destino_potencial <= 23:
			var qtd_destino = board[destino_potencial]
			
			# REGRA DE MOVIMENTO + COMER:
			# 1. Casa Vazia (0) -> Pode
			# 2. Minha cor (sign == turno) -> Pode
			# 3. Inimigo SOZINHO (abs == 1 e sign != turno) -> PODE COMER!
			if qtd_destino == 0 or sign(qtd_destino) == turno_atual:
				destinos.append(destino_potencial)
			elif abs(qtd_destino) == 1 and sign(qtd_destino) != turno_atual:
				destinos.append(destino_potencial) # Blot Inimigo detectado
	
	return destinos

func mover_peca(origem: int, destino: int):
	var valor_peca = 1 if turno_atual == 1 else -1
	
	# LÓGICA DE COMER (HIT)
	# Se o destino não está vazio e tem sinal diferente, é um inimigo
	if board[destino] != 0 and sign(board[destino]) != turno_atual:
		print("Comeu peça adversária!")
		# Remove a peça inimiga do tabuleiro
		board[destino] = 0 
		# Manda para a barra correta
		if turno_atual == 1: # Eu sou branco, comi uma preta
			bar_pretas += 1
		else: # Eu sou preto, comi uma branca
			bar_brancas += 1
	
	# Movimento Padrão
	board[origem] -= valor_peca
	board[destino] += valor_peca
	
	# Consome Dado
	var distancia = abs(destino - origem)
	if distancia in dados_disponiveis:
		dados_disponiveis.erase(distancia)
	
	atualizar_interface()

func rolar_dados():
	if dados_disponiveis.size() == 0:
		turno_atual = -turno_atual
	
	var d1 = randi_range(1, 6)
	var d2 = randi_range(1, 6)
	
	if d1 == d2:
		dados_disponiveis = [d1, d1, d1, d1]
	else:
		dados_disponiveis = [d1, d2]
		
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
	
	# 1. Desenha a BARRA (Corredor Central)
	var centro_x = 1280.0 / 2.0
	draw_line(Vector2(centro_x, 0), Vector2(centro_x, 720), Color(0, 0, 0, 0.3), 40.0)
	
	# Desenha peças na barra
	desenhar_pecas_na_barra()
	
	# 2. Desenha Casas e Peças Normais
	var destinos_validos = []
	if casa_selecionada != -1:
		destinos_validos = calcular_destinos_validos(casa_selecionada)
	
	for i in range(24):
		desenhar_casa(i, destinos_validos)

func desenhar_pecas_na_barra():
	var centro_x = 1280.0 / 2.0
	
	# Desenha Brancas (Geralmente no topo ou centro)
	for i in range(bar_brancas):
		var pos = Vector2(centro_x, 200 + (i * RAIO_PECA * 2.5))
		draw_circle(pos, RAIO_PECA, COR_BRANCAS)
		draw_arc(pos, RAIO_PECA, 0, 360, 32, Color.BLACK, 2.0)
		
	# Desenha Pretas
	for i in range(bar_pretas):
		var pos = Vector2(centro_x, 520 - (i * RAIO_PECA * 2.5))
		draw_circle(pos, RAIO_PECA, COR_PRETAS)
		draw_arc(pos, RAIO_PECA, 0, 360, 32, Color.WHITE, 2.0) # Borda branca para ver no fundo escuro

func desenhar_casa(indice: int, destinos_validos: Array):
	var eh_topo = (indice >= 12)
	var pos_x = 0.0
	
	if eh_topo: pos_x = (indice - 12) * LARGURA_CASA + (LARGURA_CASA / 2)
	else:       pos_x = (11 - indice) * LARGURA_CASA + (LARGURA_CASA / 2)
	if pos_x >= (6 * LARGURA_CASA): pos_x += LARGURA_CASA 

	var pos_y_base = 0 if eh_topo else 720
	var pos_y_ponta = 300 if eh_topo else 420
	
	var cor_triangulo = COR_TRIANGULO_1 if indice % 2 == 0 else COR_TRIANGULO_2
	var pontos = PackedVector2Array([
		Vector2(pos_x - LARGURA_CASA/2, pos_y_base),
		Vector2(pos_x + LARGURA_CASA/2, pos_y_base),
		Vector2(pos_x, pos_y_ponta)
	])
	draw_colored_polygon(pontos, cor_triangulo)
	
	if indice in destinos_validos:
		var pontos_contorno = PackedVector2Array([
			Vector2(pos_x - LARGURA_CASA/2, pos_y_base),
			Vector2(pos_x, pos_y_ponta),
			Vector2(pos_x + LARGURA_CASA/2, pos_y_base),
			Vector2(pos_x - LARGURA_CASA/2, pos_y_base)
		])
		draw_polyline(pontos_contorno, COR_MOVEL, 3.0)
	
	var qtd = board[indice]
	if qtd != 0:
		var cor_p = COR_BRANCAS if qtd > 0 else COR_PRETAS
		var dir = 1 if eh_topo else -1
		var num_pecas = abs(qtd)
		
		for p in range(num_pecas):
			var off_y = (RAIO_PECA * 2 * p * dir) + (RAIO_PECA * dir)
			var centro = Vector2(pos_x, pos_y_base + off_y)
			
			var cor_atual = cor_p
			if indice == casa_selecionada and p == num_pecas - 1:
				cor_atual = COR_MOVEL
				
			draw_circle(centro, RAIO_PECA, cor_atual)
			
			var eh_minha_vez = sign(qtd) == turno_atual
			var tenho_dados = dados_disponiveis.size() > 0
			
			if p == num_pecas - 1 and casa_selecionada == -1 and eh_minha_vez and tenho_dados:
				draw_arc(centro, RAIO_PECA, 0, 360, 32, COR_MOVEL, 4.0)
			else:
				draw_arc(centro, RAIO_PECA, 0, 360, 32, Color.BLACK, 2.0)
