# Dotfiles — Omarchy

Este repositório armazena configurações pessoais e scripts utilizados para preparar um ambiente Omarchy.

As configurações são versionadas no Git e aplicadas ao sistema com o **GNU Stow**, que cria links simbólicos entre os arquivos do repositório e seus respectivos locais dentro de `~/.config`.

## Estrutura

```text
.dotfiles/
├── hyprland/
├── waybar/
└── scripts/
    ├── units/
    ├── optionals/
    └── pipeline/
```

### `hyprland`

Contém as configurações do Hyprland, como:

```text
hypridle.conf
input.lua
monitors.lua
```

O diretório reproduz a estrutura esperada dentro de `~/.config`.

### `waybar`

Contém as configurações e estilos da Waybar.

Assim como o Hyprland, pode ser aplicado utilizando o GNU Stow.

### `scripts/units`

Contém scripts pequenos e independentes.

Cada script é responsável pela instalação de uma única ferramenta, como:

```text
install-brave.sh
install-stow.sh
install-yazi.sh
```

Eles podem ser executados separadamente quando necessário.

### `scripts/optionals`

Contém instalações opcionais que não fazem parte da configuração principal.

Esses scripts devem ser executados manualmente.

### `scripts/pipeline`

Contém os scripts que organizam o processo completo de instalação.

O arquivo principal é:

```text
install-all.sh
```

Ele executa os scripts unitários na ordem correta e, ao final, aplica as configurações do sistema.

O script `configure-hypr.sh` valida os arquivos Lua, preserva eventuais conflitos em backups com timestamp, executa o Stow, recarrega o Hyprland e verifica erros de configuração.

## GNU Stow

O GNU Stow cria links simbólicos entre os arquivos deste repositório e o diretório pessoal.

Por exemplo:

```text
~/.config/hypr/input.lua
→ ~/.dotfiles/hyprland/.config/hypr/input.lua
```

Dessa forma, os arquivos permanecem dentro do repositório e podem ser versionados pelo Git.

## Instalação completa

Clone o repositório:

```bash
git clone git@github.com:SEU_USUARIO/dotfiles.git ~/.dotfiles
```

Entre no diretório:

```bash
cd ~/.dotfiles
```

Garanta que os scripts possuem permissão de execução:

```bash
chmod +x scripts/units/*.sh
chmod +x scripts/optionals/*.sh
chmod +x scripts/pipeline/*.sh
```

Execute o pipeline principal:

```bash
./scripts/pipeline/install-all.sh
```

O pipeline instala as ferramentas necessárias, aplica as configurações com GNU Stow, recarrega o Hyprland e falha caso `hyprctl configerrors` reporte algum problema.
