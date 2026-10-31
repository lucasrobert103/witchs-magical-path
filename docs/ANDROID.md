# Android — primeiro protótipo

O preset `Android` gera um APK de desenvolvimento para **Android 7.0 ou superior (API 24)**, em aparelhos **ARM64**, com orientação horizontal. O renderizador Compatibility usa OpenGL ES 3.0. O primeiro pacote é `org.asterion.prototype`, versão `0.1.0`.

O APK usa assinatura de depuração, não solicita permissões e funciona sem conexão. Não é uma publicação na Play Store. A versão inicial ainda precisa ser avaliada num aparelho real: desempenho, aquecimento, controles e recortes de tela variam entre dispositivos.

## Gerar no ambiente na nuvem

Pré-requisitos: Godot **4.6.3**, Java 17 ou superior, Python 3, Bash, curl, unzip e dpkg-deb, em uma máquina Linux x86_64. Este ambiente já tem Godot 4.6.3 e Java 21.

```bash
cd /workspace/witchs-magical-path
./tools/setup_android.sh
./tools/export_android.sh
```

O resultado fica em `build/asterion-debug.apk`. A exportação também grava o log, metadados do manifesto, resultado da verificação de assinatura e SHA-256 em `build/`.

O script de preparação instala arquivos exclusivamente em `/workspace/.tools`, `/workspace/.local/share`, `/workspace/.config` e `/workspace/.cache`. As variáveis `ASTERION_TOOL_ROOT`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME` e `XDG_CACHE_HOME` permitem escolher outros diretórios. Não altera o sistema operacional nem instala o SDK proprietário do Google.

Para a exportação sem Gradle, Godot só precisa dos templates Android, Java, `adb` e `apksigner`. Utilizamos as ferramentas AOSP distribuídas pelo Debian, preservando suas licenças abertas e conferindo os hashes em `tools/android-tools.lock.json`, obtidos de índices Debian assinados. Os templates oficiais são da mesma versão do editor e têm o SHA-512 verificado contra o arquivo publicado pelo projeto Godot:

- [Godot 4.6.3 — arquivos e checksums oficiais](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable)
- [Documentação oficial de exportação Android](https://github.com/godotengine/godot-docs/blob/4.6/tutorials/export/exporting_for_android.rst)

O arquivo completo de templates tem aproximadamente 1,2 GB, mas só os templates Android são extraídos. O download é reutilizado em execuções posteriores.

Godot pode avisar que a versão das ferramentas de assinatura AOSP `35.0.2` difere do target SDK `36` do template. A exportação sem Gradle usa o template pré-compilado; a assinatura e a verificação do APK são executadas com sucesso com essas ferramentas. Não se altera o target SDK para esconder o aviso.

## Instalar no aparelho

Transfira `build/asterion-debug.apk` para um aparelho ARM64 compatível e abra o arquivo. O Android pode pedir autorização para instalar aplicativos dessa origem. A assinatura é exclusiva para testes locais.

Em seu computador local, com `adb` instalado, depuração USB habilitada e o aparelho autorizado:

```bash
adb devices
adb install -r build/asterion-debug.apk
```

Se já houver um aplicativo com o mesmo pacote assinado com outra chave, a atualização será recusada. Preserve seus dados antes de remover uma instalação existente.

O ambiente na nuvem não foi conectado a um aparelho. Seu `adb` serve à verificação dos pré-requisitos da exportação; iniciar o servidor de dispositivos aqui é limitado pelo diretório pessoal somente para leitura. Isso não impede gerar nem verificar o APK.

## Validar o pacote

```bash
python3 tools/inspect_apk.py build/asterion-debug.apk
/workspace/.tools/android/build-tools/35.0.2/apksigner verify --verbose build/asterion-debug.apk
```

Esses comandos verificam a integridade ZIP, o manifesto, a arquitetura ARM64, a orientação horizontal, a ausência de permissão de internet e a assinatura do pacote. Não substituem execução no Android.

## Publicação futura

O pacote atual é um protótipo de desenvolvimento. Publicar na Play Store exige um fluxo de release separado: identificador definitivo, assinatura de produção mantida fora do repositório, Android App Bundle (AAB), configurações da loja e testes em aparelhos. O script cria somente a identidade pública padrão de debug; ela não deve ser usada em produção. Nenhuma conta da loja ou credencial de publicação foi configurada.
