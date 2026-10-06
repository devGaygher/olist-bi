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
git remote add origin https://github.com/SEU_USUARIO/olist-bi.git
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

## Próximos passos

- Trabalhar com **branches**: uma branch por etapa do projeto (por exemplo, `feature/sql-schema`).
- Abrir e aprovar **Pull Requests** no GitHub e fazer o merge na `main`.
- Praticar resolução de **conflitos** e recuperação de alterações com `git revert`, `git restore` e `git reflog`.
- Versionar o projeto do Power BI no formato **PBIP**, que salva em texto e funciona bem com Git.
