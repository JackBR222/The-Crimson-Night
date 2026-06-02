extends Node

# CONFIGURAÇÃO
const SAVE_PATH := "user://save.dat"

# Se TRUE → não salva no disco (só memória)
@export var save_temporario: bool = true

# Mapeamento de checkpoints → cenas
var checkpoint_cenas := {
	-1: "res://scenes/test/CheckpointTest_1.scn",
	 0: "res://scenes/Game.scn",
	 1: "res://cenas/fase_25.tscn",
	 2: "res://cenas/fase_50.tscn",
	 3: "res://cenas/fase_75.tscn",
	 4: "res://scenes/final.tscn"
}

# ESTADO
var checkpoint_atual: int = 0


# INICIALIZAÇÃO
func _ready():
	carregar()


# CHECKPOINT
func definir_checkpoint(valor: int):

	# checkpoint de teste sempre permitido
	if valor == -1:
		checkpoint_atual = valor
		salvar()
		return

	# só avança (não volta)
	if valor > checkpoint_atual:
		checkpoint_atual = valor
		salvar()


# CARREGAMENTO DE CENA
func carregar_checkpoint():
	if checkpoint_atual in checkpoint_cenas:
		var cena = checkpoint_cenas[checkpoint_atual]
		print("Carregando checkpoint:", checkpoint_atual, "→", cena)
		get_tree().change_scene_to_file(cena)
	else:
		print("Checkpoint inválido, indo pro início")
		get_tree().change_scene_to_file(checkpoint_cenas[0])


# SAVE / LOAD
func salvar():

	# MODO TEMPORÁRIO (não grava no PC)
	if save_temporario:
		print("SAVE TEMPORÁRIO (memória):", checkpoint_atual)
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(checkpoint_atual)
		print("Salvo no disco:", checkpoint_atual)


func carregar():

	# MODO TEMPORÁRIO (ignora arquivo)
	if save_temporario:
		checkpoint_atual = 0
		print("Modo temporário ativo (sem load)")
		return

	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			checkpoint_atual = file.get_var()
			print("Carregado:", checkpoint_atual)
	else:
		checkpoint_atual = 0
		print("Sem save, começando do 0")


# UTILIDADES
func resetar():
	checkpoint_atual = 0

	# só salva se não for temporário
	salvar()


func tem_checkpoint() -> bool:
	return checkpoint_atual != 0
