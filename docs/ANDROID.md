# Android

O preset `Android` gera um APK de **depuração** para **Android 7.0+ (API 24)**, **ARM64**,
orientação horizontal, renderizador *Compatibility* (OpenGL ES 3.0), sem permissões e offline.
Pacote: `com.asterion.caminhodabruxa`, versão `1.1.0` (código 4).

## Gerar

Pré-requisitos (Linux x86_64): Godot **4.6.3** no PATH como `godot`, Java 17+, `apksigner`
(Ubuntu/Debian: `sudo apt install apksigner`), curl, unzip, python3.

```bash
./tools/setup_android.sh
```

```bash
./tools/export_android.sh
```

O `setup_android.sh` baixa os templates oficiais do Godot 4.6.3 (verifica o SHA‑512), cria um
SDK mínimo apontando para o `apksigner`, gera a chave pública de depuração padrão e configura o
editor. Variáveis opcionais: `ASTERION_TOOL_ROOT`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`.

O resultado é `build/asterion.apk`, verificado com `apksigner verify` e
`tools/inspect_apk.py` (pacote, ARM64, orientação, ausência de internet, scripts, shaders,
sprites, fontes, áudio e licenças).

## Instalar

Copie `build/asterion.apk` para o celular e abra o arquivo (permita "instalar apps desta
fonte"). Ou, com depuração USB:

```bash
adb install -r build/asterion.apk
```

Se houver uma versão anterior do protótipo, ela tinha outro pacote (`org.asterion.prototype`)
e pode ser desinstalada separadamente.

## Desempenho

- Cerca de 140 chamadas de desenho e 45 mil triângulos por quadro.
- No celular o 3D é renderizado a 80% da resolução nativa (60% em *Leve*); a interface fica nítida.
- O modo *Leve* (Configurações → Gráficos) reduz a densidade da floresta, partículas e o brilho;
  vale ao iniciar ou continuar uma jornada.
- Texturas 3D usam compressão ETC2 com mipmaps.

O ambiente na nuvem não tem um aparelho físico conectado: a execução foi validada no Godot com
renderização OpenGL (Mesa) e testes automatizados; vale testar em um celular real.

## Publicação futura

Para a Play Store será preciso um fluxo de release separado: chave de produção fora do
repositório, Android App Bundle (AAB) e configurações da loja.
