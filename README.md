# Asterion — O despertar

Primeiro protótipo de um RPG de bruxa em **3D, terceira pessoa, para Android**. Feito com **Godot 4.6.3 / GDScript**, renderizador Compatibility e geometria procedural, sem bibliotecas externas.

## Experiência implementada

- Menu e abertura com trechos do prólogo fornecido pelo autor, que pode ser pulada.
- Clareira explorável com árvores, vegetação, pontos de luz e uma planta luminosa.
- Movimento relativo à câmera, câmera orbital e controles de toque simultâneos.
- Uma interação mágica por proximidade, resposta visual, conclusão e reinício.
- Pausa manual e automática ao perder foco.
- Registro local da descoberta. **Não é um sistema de salvamento/continuação**; cada nova jornada começa no ponto inicial.

O cenário, a planta e os efeitos são propostas de encenação para testar a jogabilidade, não novos fatos da mitologia. O modelo da personagem e sua roupa são provisórios; o projeto ainda não contém um modelo anime de produção. A aparência busca representar pele morena, olhos âmbar e cabelos escuros cacheados até a cintura. A referência aprovada da roupa precisa ser fornecida antes da arte definitiva.

## Abrir e jogar

Abra `project.godot` no Godot **4.6.3** e pressione **F6** na cena `scenes/main.tscn`, ou **F5** para executar o projeto.

```sh
cd /workspace/witchs-magical-path
godot --editor --path .
# Ou iniciar diretamente:
godot --path .
```

Em ambientes restritos, defina diretórios graváveis antes dos comandos:

```sh
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
export XDG_CACHE_HOME=/workspace/.cache
```

| Ação | Android | Computador |
| --- | --- | --- |
| Caminhar | Controle virtual à esquerda | WASD ou setas |
| Olhar | Arrastar à direita | Arrastar o mouse |
| Magia | Botão Magia | E ou Espaço |
| Pausar | Botão no canto superior direito | Esc |

Siga os pontos de luz e use magia perto da planta luminosa. A clareira delimita o espaço deste protótipo; não há combate ou outras regiões nesta versão.

## Android

Veja [como preparar, exportar e instalar](docs/ANDROID.md). O APK de desenvolvimento fica em `build/asterion-debug.apk` e usa assinatura de teste. Não é uma versão de loja. Nunca inclua chaves de produção no repositório.

## Validação

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/ui_smoke.gd
```

O teste integrado executa a cena e a física: movimento, chão, pausa, alcance da magia, descoberta, registro local e reinício. O teste da interface cobre os controles de toque. Essas verificações não substituem testar desempenho e ergonomia num celular real.

## Organização

```text
scenes/main.tscn       Cena inicial
scripts/main.gd        Fluxo de jogo e interação
scripts/player.gd      Personagem, movimento e câmera
scripts/forest.gd      Cenário procedural e resposta mágica
scripts/game_ui.gd     Menu, prólogo, HUD e controles
tests/                Testes executáveis no Godot
tools/                Preparação e exportação Android
docs/                 Instruções e continuidade narrativa
```

Próximas etapas: testar o APK em dispositivos Android, aprovar a direção visual e a roupa de Asterion e então expandir a exploração e os sistemas mágicos em etapas.
