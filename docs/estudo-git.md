# Registro de estudo: Git e GitHub

Este documento registra o que fiz e aprendi sobre Git e GitHub ao iniciar o projeto **Olist BI**, um projeto de portfólio para estudar SQL, Power BI e controle de versão. Data de início: 06/10/2026.

## Objetivo

Aprender a versionar um projeto de dados do jeito que se trabalha em equipe: histórico de alterações, mensagens de commit claras, repositório remoto e, nas próximas etapas, branches e Pull Requests.

## Conceitos que aprendi

| Conceito | O que é |
|---|---|
| **Git** | Programa que roda no computador e guarda o histórico das alterações do projeto |
| **GitHub** | Site que hospeda o repositório remoto e o torna visível para outras pessoas |
| **Repositório** | Pasta de projeto monitorada pelo Git (a pasta oculta `.git` guarda o histórico) |
| **Commit** | "Foto" do projeto em um momento, com uma mensagem explicando o que mudou |
| **Área de preparação (staging)** | Lista do que entrará no próximo commit (`git add`) |
| **Branch** | Linha de desenvolvimento. A principal se chama `main` |
| **Remote / origin** | Endereço do repositório no GitHub. `origin` é o apelido padrão |
| **`.gitignore`** | Lista do que o Git deve ignorar (aqui, os CSVs pesados do dataset) |

O fluxo básico de um commit tem três lugares: a pasta de trabalho, a área de preparação e o histórico.

```
alterar arquivos  ->  git add  ->  git commit  ->  git push
 (pasta local)     (preparação)   (histórico)     (GitHub)
```

## O que fiz, passo a passo

### 1. Verificar e conferir a configuração do Git

```powershell
git --version
git config --list
```

Conferi se o Git estava instalado e se `user.name` e `user.email` estavam definidos. Cada commit leva esses dados, e o e-mail deve ser o mesmo da conta do GitHub para os commits aparecerem no perfil.

### 2. Criar a pasta do projeto fora de pastas do sistema

```powershell
cd ~
mkdir projetos
cd projetos
mkdir olist-bi
cd olist-bi
```

Criei a pasta dentro do perfil do usuário, fora do `System32` (pasta do sistema) e fora de Documentos e Área de Trabalho, que o OneDrive costuma sincronizar e isso atrapalha o Git.

### 3. Iniciar o repositório

```powershell
git init -b main
```

O `git init` transforma a pasta em repositório. O `-b main` já nomeia o ramo principal como `main`, o mesmo nome usado pelo GitHub.

### 4. Criar a estrutura de pastas

```powershell
mkdir data\raw, sql\04_analises, powerbi, docs
New-Item sql\04_analises\.gitkeep, powerbi\.gitkeep, docs\.gitkeep -ItemType File
```

O Git não guarda pastas vazias, só arquivos. Por isso usei arquivos `.gitkeep` vazios para manter as pastas no repositório.

Estrutura planejada:

```
olist-bi/
├── data/raw/          (CSVs, fora do Git)
├── sql/
├── powerbi/
├── docs/
└── README.md
```

### 5. Criar o `.gitignore` e o README

```powershell
Set-Content -Path .gitignore -Value "data/raw/" -Encoding ascii
Set-Content -Path README.md -Value "# Olist BI - E-commerce Analytics"
```

O `.gitignore` impede que os CSVs do dataset sejam enviados. Alguns arquivos são grandes, e o GitHub recusa arquivos acima de 100 MB.

### 6. Fazer o primeiro commit

```powershell
git status
git add .
git commit -m "Estrutura inicial do projeto"
git log --oneline
```

- `git status` mostra o que mudou e o que ainda não foi registrado.
- `git add .` seleciona tudo para o commit.
- `git commit -m "..."` grava o commit com uma mensagem curta.
- `git log --oneline` lista o histórico em uma linha por commit.

### 7. Publicar no GitHub

1. Criei no site um repositório público vazio chamado `olist-bi`, sem README, `.gitignore` nem licença (esses arquivos já existiam localmente, e criá-los de novo no site geraria conflito no primeiro envio).
2. Conectei a pasta local ao repositório remoto e enviei o projeto:

```powershell
git remote add origin https://github.com/devGaygher/olist-bi.git
git remote -v
git push -u origin main
```

- `git remote add origin` cadastra o endereço do GitHub.
- `git remote -v` lista os endereços cadastrados, para conferir.
- `git push -u origin main` envia os commits. O `-u` faz o Git lembrar a ligação entre o `main` local e o remoto, então depois basta `git push`.

## Erros que encontrei e o que aprendi

| Situação | Causa | Aprendizado |
|---|---|---|
| `git status` mostrava arquivos como *Untracked* | Eu ainda não tinha feito `git add` | O Git só registra o que foi preparado e commitado |
| `fatal: your current branch 'main' does not have any commits yet` ao rodar `git log` | Ainda não existia nenhum commit | Não é um problema real: o histórico só existe depois do primeiro commit |
| `git log --online` não funcionou | Erro de digitação, o correto é `--oneline` | Conferir a grafia das opções dos comandos |
| Ramo padrão global configurado como `master` | Configuração antiga do Git | Usar `git init -b main` garante o nome certo no repositório |

## Branches, Pull Requests e recuperação (outubro e novembro/2026)

Depois da estrutura inicial passei a trabalhar com uma branch por assunto (`feature/...`, `fix/...`, `docs/...`), commits no padrão `tipo(escopo): resumo`, Pull Request e merge na `main`. O fluxo de cada etapa:

```
git switch main  ->  git pull  ->  git fetch --prune  ->  git switch -c feature/nome
trabalho  ->  git add caminho  ->  git diff --cached --stat  ->  git commit -m "..."
git push -u origin feature/nome  ->  Pull Request  ->  merge
git switch main  ->  git pull  ->  git branch -d feature/nome
```

O projeto do Power BI foi versionado no formato PBIP, que guarda o painel em arquivos de texto. O cache e as configurações locais (`cache.abf`, `localSettings.json`) ficam fora do Git.

### Situações que apareceram e o que aprendi

| Situação | Causa | O que fiz | Aprendizado |
|---|---|---|---|
| Commit feito na `main` por engano, antes do push | Não conferi a branch antes de editar | Guardei o commit em uma branch nova (`git branch feature/nome`), devolvi a `main` ao estado do GitHub (`git reset --hard origin/main`) e mudei para a branch nova | Rodar `git branch --show-current` antes do primeiro commit. O `reset --hard` só é seguro sem alterações pendentes e com o commit guardado em outra branch |
| `git status -sb` com `[ahead 1]` depois de um "push" | O envio anterior não tinha terminado | Rodei `git push -u origin feature/nome` de novo e conferi a linha com os dois códigos de commit (`a5c7617..79e53cb`) | `ahead` mostra commits locais que o GitHub ainda não tem; conferir isso antes de procurar o botão do PR |
| O botão "Compare & pull request" não apareceu | O aviso some depois de um tempo | Abri o PR em Pull requests > New pull request, ou pelo endereço `compare/main...nome-da-branch` | O PR não depende do aviso amarelo |
| PR da página Clientes com conflito em `pages.json` e `_Medidas.tmdl` (26/10) | A `main` mudou os mesmos arquivos | Merge da `main` na branch, resolvendo os dois arquivos, e novo push | Conflito é dois lados mudando o mesmo trecho; branches curtas reduzem o problema |
| Risco de levar arquivo que não é do projeto (cache do Power BI, arquivo pessoal) | `git add .` e `git add -A` pegam tudo | Preparar por caminho e conferir com `git diff --cached --stat` antes do commit | Ver o que vai entrar antes de commitar; o arquivo pessoal de retomada fica fora do repositório |

## Comandos de referência

| Comando | Para que serve |
|---|---|
| `git init -b main` | Iniciar um repositório com o ramo `main` |
| `git status` | Ver o estado atual dos arquivos |
| `git add .` | Preparar todas as alterações para o commit |
| `git commit -m "mensagem"` | Gravar um commit |
| `git log --oneline` | Ver o histórico resumido |
| `git remote add origin URL` | Ligar a pasta local ao GitHub |
| `git push -u origin main` | Enviar commits ao GitHub (primeira vez) |
| `git branch --show-current` | Mostrar em qual branch estou |
| `git switch -c nome` | Criar uma branch e mudar para ela |
| `git switch nome` | Mudar de branch |
| `git status -sb` | Estado resumido, com a branch e quantos commits ainda não foram enviados (`ahead`) |
| `git add caminho` | Preparar só os arquivos escolhidos |
| `git diff --cached --stat` | Conferir o que vai entrar no commit |
| `git push -u origin nome` | Enviar uma branch nova ao GitHub |
| `git fetch --prune` | Atualizar a lista de branches remotas e tirar as apagadas |
| `git branch -d nome` | Apagar uma branch local já mesclada |
| `git reset --hard origin/main` | Fazer a `main` local voltar ao estado do GitHub (descarta commits locais; só com tudo guardado em outra branch) |

## Próximos passos

- Praticar `git revert`, `git restore` e `git reflog`, para recuperar alterações sem reescrever o histórico.
- Treinar a resolução de conflitos em situações novas, além do `pages.json` e do `_Medidas.tmdl`.
