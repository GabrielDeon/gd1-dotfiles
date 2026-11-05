# System & Markets

Plugin do **Omarchy shell / Quickshell**, ID `gd1.system-market`. Não é um módulo da Waybar.

## Instalação

Na raiz do repositório:

```bash
bash scripts/units/install-system-market.sh
```

O `scripts/pipeline/install-all.sh` também executa essa etapa depois da configuração do Hyprland. Requer Omarchy com suporte a plugins e Python 3. Não requer pacotes Python adicionais.

O instalador valida o manifesto, copia os arquivos para `~/.config/omarchy/plugins/gd1.system-market/` e adiciona o widget à direita, antes de `omarchy.monitor` quando disponível. Configurações existentes, posição já escolhida e preferências do widget são preservadas. Arquivos substituídos são copiados para um backup `~/.config/omarchy/system-market-<timestamp>-*/`. Execuções repetidas não duplicam o widget. Sem uma sessão gráfica ativa, a configuração é aplicada no próximo login.

Este diretório é copiado, **não aplicado com Stow**: o validador do Omarchy rejeita links simbólicos dentro de plugins. Depois de editar os arquivos do repositório, execute o instalador novamente. Se o shell conservar uma versão em cache, execute `omarchy restart shell`.

## Uso

Clique no ícone para abrir o painel nativo. Escape ou um clique fora fecha o painel; Tab alterna painéis; Enter alterna atualizações automáticas de preços.

- RAM, CPU e GPU: utilização; CPU e GPU também exibem temperatura em Celsius. RAM usa `— °C` como placeholder. Valores alinhados em colunas.
- Percentuais verdes abaixo de 50%, amarelos de 50% até menos de 80%, vermelho claro a partir de 80%.
- Hardware atualizado a cada dois segundos enquanto o painel está aberto; sensores indisponíveis são identificados. GPU usa o primeiro dispositivo DRM compatível (AMD nesta máquina).
- Bitcoin/USD e USD/BRL: cotações de compra da AwesomeAPI, via HTTPS, a cada cinco minutos enquanto aberto. “Refresh Prices” solicita ambos imediatamente, inclusive com atualização automática pausada. “Pause Prices” / “Resume Prices” preserva a preferência em `shell.json`.
- “Quote time” mostra o início da última requisição bem-sucedida, até minutos. Os timestamps do provedor são preservados para detectar cotações com mais de 15 minutos. Uma falha mantém os preços e horário anteriores.
- Timeout de dez segundos, limite de 32 KiB, sem redirects, validação numérica e de moedas. Sem chave de API. Traduções em inglês e português brasileiro.

Desabilitar:

```bash
omarchy plugin disable gd1.system-market
```

Testes, na raiz do repositório:

```bash
python3 -B -m unittest discover -s tests -v
python3 -B -m unittest discover -s omarchy/plugins/gd1.system-market -p 'test_*.py' -v
```
