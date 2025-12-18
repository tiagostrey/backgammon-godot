extends Node2D

# --- CONFIGURAÇÕES VISUAIS ---
const COR_FUNDO = Color("#2e8b57") # Verde Feltro
const COR_TRIANGULO_1 = Color("#e0e0e0") # Cinza Claro
const COR_TRIANGULO_2 = Color("#cd5c5c") # Vermelho Indiano
const COR_BRANCAS = Color("#ffffff")
const COR_PRETAS = Color("#111111")
const COR_MOVEL = Color("#00FF00")   # Verde Neon (Dica/Seleção)

# Medidas (Baseado na tela 1280x720)
const LARGURA_CASA = 1280.0 / 13.0
const ALTURA_CASA = 720.0 * 0.4
const RAIO_PECA = 28.0

# --- ESTADO DO JOGO ---
var board: Array[int] = []
var dados_disponiveis: Array[int] = [] 
var casa_selecionada: int = -1 # -1 = Nenhuma, 99 = Barra
var turno_atual: int = 1 # 1 = Brancas, -1 = Pretas

# Peças comidas (Barra)
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
	
	# Setup Inicial Padrão
	board[0] = 2; board[11] = 5; board[16] = 3; board[18] = 5
	board[23] = -2; board[12] = -5; board[7] = -3; board[5] = -5
	
	bar_brancas = 0
	bar_pretas = 0
	
	turno_atual = 1
	dados_disponiveis = []
	casa_selecionada = -1
	
	queue_redraw()

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		detectar_casa_clicada(event.position)

func detectar_casa_clicada(pos_mouse: Vector2):
	var coluna_visual = int(pos_mouse.x / LARGURA_CASA)
	
	# 1. Detecta clique na Barra Central (Coluna 6 visualmente)
	if coluna_visual == 6:
		gerenciar_clique(99) # 99 é o código da Barra
		return
	
	# 2. Ajusta coluna para pular a barra no cálculo do índice
	var coluna_ajustada = coluna_visual
	if coluna_visual > 6: coluna_ajustada -= 1
		
	var eh_topo = pos_mouse.y < (720 / 2)
	var indice = -1
	
	# 3. Calcula índice do array (0-23)
	if eh_topo: indice = 12 + coluna_ajustada
	else:       indice = 11 - coluna_ajustada
	
	if indice >= 0 and indice <= 23:
		gerenciar_clique(indice)

func gerenciar_clique(indice: int):
	# Verifica se tem alguém preso na barra da cor atual
	var tem_peca_na_barra = (turno_atual == 1 and bar_brancas > 0) or (turno_atual == -1 and bar_pretas > 0)
	
	# CENÁRIO 1: Nada selecionado -> Tenta SELECIONAR
	if casa_selecionada == -1:
		
		# A. OBRIGAÇÃO DE SAIR DA BARRA
		if tem_peca_na_barra:
			if indice == 99:
				if dados_disponiveis.size() > 0:
					# Verifica se é possível sair (se não está bloqueado)
					var destinos = calcular_destinos_validos(99)
					if destinos.size() > 0:
						casa_selecionada = 99
						print("Selecionou a BARRA para entrar.")
					else:
						print("Bloqueado! Casas de entrada estão fechadas.")
				else:
					print("Role os dados para sair da barra.")
			else:
				print("MOVIMENTO ILEGAL: Você tem peças na barra! Clique no centro.")
			queue_redraw()
			return

		# B. SELEÇÃO NORMAL (Só se não tiver peça na barra)
		# Verifica se clicou numa casa válida, com peça da cor certa
		if indice != 99 and board[indice] != 0 and sign(board[indice]) == turno_atual:
			if dados_disponiveis.size() > 0:
				# Verifica se a peça tem movimentos possíveis antes de deixar selecionar
				var destinos = calcular_destinos_validos(indice)
				if destinos.size() > 0:
					casa_selecionada = indice
					print("Selecionou casa ", indice)
				else:
					print("Peça bloqueada! Não há movimentos válidos.")
			else:
				print("Sem dados! Role os dados primeiro.")
	
	# CENÁRIO 2: Algo selecionado -> Tenta MOVER
	else:
		if casa_selecionada == indice:
			casa_selecionada = -1 # Cancela ao clicar na mesma peça
		else:
			# Verifica se o clique foi num destino válido
			var destinos = calcular_destinos_validos(casa_selecionada)
			if indice in destinos:
				mover_peca(casa_selecionada, indice)
				casa_selecionada = -1
			else:
				casa_selecionada = -1 # Cancela se clicar em lugar inválido
	
	queue_redraw()

func calcular_destinos_validos(origem: int) -> Array:
	var destinos = []
	var direcao = 1 if turno_atual == 1 else -1 
	
	# CASO ESPECIAL: Saindo da Barra (Origem 99)
	if origem == 99:
		for valor_dado in dados_disponiveis:
			var destino_potencial = -1
			if turno_atual == 1: # Brancas entram no 0-5 (baseado no dado)
				destino_potencial = valor_dado - 1
			else: # Pretas entram no 23-18
				destino_potencial = 24 - valor_dado
			
			validar_e_adicionar_destino(destinos, destino_potencial)
			
	# CASO NORMAL: Movendo no Tabuleiro
	else:
		for valor_dado in dados_disponiveis:
			var destino_potencial = origem + (valor_dado * direcao)
			if destino_potencial >= 0 and destino_potencial <= 23:
				validar_e_adicionar_destino(destinos, destino_potencial)
	
	return destinos

func validar_e_adicionar_destino(lista_destinos: Array, casa_alvo: int):
	var qtd_destino = board[casa_alvo]
	
	# Regra 1: Casa Vazia -> Pode
	# Regra 2: Casa com peças minhas -> Pode
	# Regra 3: Casa com APENAS 1 inimigo (Blot) -> Pode comer
	if qtd_destino == 0 or sign(qtd_destino) == turno_atual:
		lista_destinos.append(casa_alvo)
	elif abs(qtd_destino) == 1 and sign(qtd_destino) != turno_atual:
		lista_destinos.append(casa_alvo)

func mover_peca(origem: int, destino: int):
	var valor_peca = 1 if turno_atual == 1 else -1
	
	# 1. PROCESSA HIT (Comer peça inimiga)
	if board[destino] != 0 and sign(board[destino]) != turno_atual:
		board[destino] = 0 # Zera a casa
		if turno_atual == 1: bar_pretas += 1
		else:                bar_brancas += 1
		print("Comeu peça adversária!")
	
	# 2. REMOVE DA ORIGEM
	if origem == 99:
		if turno_atual == 1: bar_brancas -= 1
		else:                bar_pretas -= 1
	else:
		board[origem] -= valor_peca
	
	# 3. ADICIONA NO DESTINO
	board[destino] += valor_peca
	
	# 4. CONSOME O DADO
	var distancia = 0
	if origem == 99:
		if turno_atual == 1: distancia = destino + 1
		else:                distancia = 24 - destino
	else:
		distancia = abs(destino - origem)
		
	if distancia in dados_disponiveis:
		dados_disponiveis.erase(distancia) # Remove apenas a primeira ocorrência
	
	atualizar_interface()

func rolar_dados():
	# Passa a vez automaticamente se não houver dados (simplificação)
	if dados_disponiveis.size() == 0:
		turno_atual = -turno_atual
	
	var d1 = randi_range(1, 6)
	var d2 = randi_range(1, 6)
	
	if d1 == d2: dados_disponiveis = [d1, d1, d1, d1] # Duplo
	else:        dados_disponiveis = [d1, d2]
		
	atualizar_interface()
	queue_redraw()

func atualizar_interface():
	if has_node("LblResultado"):
		var nome = "BRANCAS" if turno_atual == 1 else "PRETAS"
		$LblResultado.text = "Vez de: " + nome + "\nDados: " + str(dados_disponiveis)

# --- SISTEMA DE DESENHO ---
func _draw():
	draw_rect(Rect2(0, 0, 1280, 720), COR_FUNDO)
	
	# Linha da Barra Central
	var centro_x = 1280.0 / 2.0
	draw_line(Vector2(centro_x, 0), Vector2(centro_x, 720), Color(0, 0, 0, 0.3), 40.0)
	
	# Desenha peças presas na barra
	desenhar_pecas_na_barra()
	
	# Calcula destinos para desenhar contornos
	var destinos_validos = []
	if casa_selecionada != -1:
		destinos_validos = calcular_destinos_validos(casa_selecionada)
	
	# Desenha o tabuleiro
	for i in range(24):
		desenhar_casa(i, destinos_validos)

func desenhar_pecas_na_barra():
	var centro_x = 1280.0 / 2.0
	
	# Peças Brancas (Barra)
	for i in range(bar_brancas):
		var pos = Vector2(centro_x, 200 + (i * RAIO_PECA * 2.5))
		var cor = COR_BRANCAS
		if casa_selecionada == 99 and turno_atual == 1 and i == bar_brancas - 1:
			cor = COR_MOVEL
		
		draw_circle(pos, RAIO_PECA, cor)
		
		# Dica visual (Anel Verde) na barra
		var pode_sair = calcular_destinos_validos(99).size() > 0
		if turno_atual == 1 and casa_selecionada == -1 and dados_disponiveis.size() > 0 and i == bar_brancas - 1:
			if pode_sair:
				draw_arc(pos, RAIO_PECA, 0, 360, 32, COR_MOVEL, 4.0)
			else:
				draw_arc(pos, RAIO_PECA, 0, 360, 32, Color.RED, 2.0) # Bloqueado
		else:
			draw_arc(pos, RAIO_PECA, 0, 360, 32, Color.BLACK, 2.0)
		
	# Peças Pretas (Barra)
	for i in range(bar_pretas):
		var pos = Vector2(centro_x, 520 - (i * RAIO_PECA * 2.5))
		var cor = COR_PRETAS
		if casa_selecionada == 99 and turno_atual == -1 and i == bar_pretas - 1:
			cor = COR_MOVEL
			
		draw_circle(pos, RAIO_PECA, cor)
		
		var pode_sair = calcular_destinos_validos(99).size() > 0
		if turno_atual == -1 and casa_selecionada == -1 and dados_disponiveis.size() > 0 and i == bar_pretas - 1:
			if pode_sair:
				draw_arc(pos, RAIO_PECA, 0, 360, 32, COR_MOVEL, 4.0)
			else:
				draw_arc(pos, RAIO_PECA, 0, 360, 32, Color.RED, 2.0) # Bloqueado
		else:
			draw_arc(pos, RAIO_PECA, 0, 360, 32, Color.WHITE, 2.0)

func desenhar_casa(indice: int, destinos_validos: Array):
	var eh_topo = (indice >= 12)
	var pos_x = 0.0
	
	if eh_topo: pos_x = (indice - 12) * LARGURA_CASA + (LARGURA_CASA / 2)
	else:       pos_x = (11 - indice) * LARGURA_CASA + (LARGURA_CASA / 2)
	if pos_x >= (6 * LARGURA_CASA): pos_x += LARGURA_CASA 

	var pos_y_base = 0 if eh_topo else 720
	var pos_y_ponta = 300 if eh_topo else 420
	
	# Triângulos
	var cor_triangulo = COR_TRIANGULO_1 if indice % 2 == 0 else COR_TRIANGULO_2
	var pontos = PackedVector2Array([
		Vector2(pos_x - LARGURA_CASA/2, pos_y_base),
		Vector2(pos_x + LARGURA_CASA/2, pos_y_base),
		Vector2(pos_x, pos_y_ponta)
	])
	draw_colored_polygon(pontos, cor_triangulo)
	
	# Contorno Verde (Destino)
	if indice in destinos_validos:
		var pontos_contorno = PackedVector2Array([pontos[0], pontos[2], pontos[1], pontos[0]])
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
			# Se selecionado e for a peça do topo
			if indice == casa_selecionada and p == num_pecas - 1:
				cor_atual = COR_MOVEL
				
			draw_circle(centro, RAIO_PECA, cor_atual)
			
			# --- ANEL VERDE (Dica de Movimento) ---
			var eh_minha_vez = sign(qtd) == turno_atual
			var tenho_dados = dados_disponiveis.size() > 0
			var preso_na_barra = (turno_atual == 1 and bar_brancas > 0) or (turno_atual == -1 and bar_pretas > 0)
			var eh_topo_pilha = (p == num_pecas - 1)
			
			if not preso_na_barra and eh_topo_pilha and casa_selecionada == -1 and eh_minha_vez and tenho_dados:
				# Só acende se tiver movimentos reais (Correção do Bloqueio)
				var movimentos_desta_peca = calcular_destinos_validos(indice)
				if movimentos_desta_peca.size() > 0:
					draw_arc(centro, RAIO_PECA, 0, 360, 32, COR_MOVEL, 4.0)
				else:
					# Opcional: Anel vermelho para indicar bloqueio
					draw_arc(centro, RAIO_PECA, 0, 360, 32, Color.BLACK, 2.0)
			else:
				var cor_borda = Color.BLACK if cor_p == COR_BRANCAS else Color.WHITE
				draw_arc(centro, RAIO_PECA, 0, 360, 32, cor_borda, 2.0)
