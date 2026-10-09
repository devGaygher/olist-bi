# Olist BI - E-commerce Analytics

Projeto de portfólio em **SQL (MySQL), Power BI e Git/GitHub**, construído como uma
**simulação**: eu faço o papel de analista de dados da área de BI de um marketplace
brasileiro, que recebe um pedido da diretoria.

> **Aviso:** a empresa, o diretor e o cenário são **fictícios**. Os dados são os do
> dataset público *Brazilian E-Commerce Public Dataset by Olist*
> ([Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)), com pedidos
> de 2016 a 2018. Este projeto não representa experiência de trabalho em nenhuma
> empresa. Consulte a licença do dataset na página do Kaggle.

## O cenário

O Diretor Geral precisa explicar ao conselho como foi a operação nos últimos dois anos e
pediu:

1. um **painel no Power BI** (uma página de resumo e uma por área);
2. um **relatório executivo de 1 página**, em linguagem de negócio;
3. **documentação** (dicionário de dados e premissas);
4. **código versionado**, para o time de TI reproduzir o trabalho.

Ele também pediu que, quando o dado não permitir responder, isso seja dito com clareza,
em vez de entregar um número chutado. O briefing completo está em
[`docs/briefing-diretoria.md`](docs/briefing-diretoria.md).

## As 16 perguntas

| Área | Perguntas |
|---|---|
| Vendas | Vendas e pedidos por mês; crescimento contra o ano anterior; ticket médio; sazonalidade; Black Friday |
| Produtos | O que mais vende; melhores e piores categorias em avaliação |
| Clientes | Origem dos clientes; recompra |
| Vendedores | Dependência de poucos vendedores; quem entrega bem e quem dá problema |
| Logística | Entrega no prazo e tempo de entrega; regiões lentas e peso do frete |
| Satisfação | Nota média e efeito do atraso na nota |
| Pagamentos e pedidos | Formas de pagamento e parcelas; pedidos cancelados |
| Lucro | **Não dá para responder:** o dataset não tem custos (isso fica explícito no relatório) |

## Regras de negócio (premissas)

As definições foram combinadas antes de qualquer cálculo e estão em
[`docs/premissas.md`](docs/premissas.md). As principais:

- **Receita:** soma de `price` dos itens (sem frete) de pedidos válidos.
- **Pedido válido:** status diferente de `canceled` e `unavailable`.
- **Período:** janeiro/2017 a agosto/2018, os únicos 20 meses completos.
- **Cliente:** pessoa identificada por `customer_unique_id` (o `customer_id` muda a
  cada pedido).
- **Satisfação:** 1 avaliação por pedido, a mais recente.

## Limites dos dados

- Não há custos nem despesas: **lucro não pode ser calculado**, só receita.
- Clientes, vendedores e produtos aparecem apenas como códigos.
- 768 pedidos não têm avaliação; a nota média representa só quem avaliou.
- Fora de jan/2017 a ago/2018 os dados são incompletos.

## Como o trabalho foi organizado

O fluxo de dados vai da camada bruta (CSVs carregados como estão) até views prontas para
o Power BI. Cada achado do profiling virou uma regra escrita, e as chaves do banco foram
criadas e testadas antes de qualquer análise.

| # | Etapa | Situação |
|---|---|---|
| 1 | Alinhamento: cenário, briefing e definições | Concluída |
| 2 | Ambiente, Git e GitHub | Concluída |
| 3 | Schema (`sql/01_schema.sql`) | Concluída |
| 4 | Carga e validação (`sql/02_carga.sql`) | Concluída |
| 5 | Profiling (`sql/03_profiling.sql`) | Concluída |
| 6 | Premissas (`docs/premissas.md`) | Concluída |
| 7 | Chaves primárias e estrangeiras, com testes (`sql/02b_chaves.sql`, `sql/02c_testes.sql`) | Concluída |
| 8 | Análises em SQL das 16 perguntas (`sql/04_analises/`) | Em andamento |
| 9 | Views para o BI (`sql/05_views_bi.sql`) | A fazer |
| 10 | Modelo estrela e painel no Power BI | A fazer |
| 11 | Dicionário de dados | A fazer |
| 12 | Relatório executivo e apresentação | A fazer |

Resumo do que foi validado até aqui:

- 9 CSVs carregados (cerca de 1,4 milhão de linhas), com cada tabela conferida contra o
  arquivo de origem.
- 8 chaves primárias e 6 chaves estrangeiras, com testes que provam que o banco barra
  linhas órfãs e duplicadas.
- 0 órfãos entre as tabelas principais.

## Estrutura do repositório

```
olist-bi/
|-- data/raw/          CSVs do Kaggle (não versionados)
|-- docs/              briefing, premissas, etapas e estudo de Git
|-- sql/
|   |-- 01_schema.sql      cria as 9 tabelas da camada bruta
|   |-- 02_carga.sql       carrega os CSVs
|   |-- 02b_chaves.sql     chaves primárias e estrangeiras
|   |-- 02c_testes.sql     testes das chaves
|   |-- 03_profiling.sql   profiling em 5 blocos
|   `-- 04_analises/       análises por área (em andamento)
`-- README.md
```

As pastas `powerbi/` e `relatorio/` serão criadas nas etapas 10 e 12.

## Como reproduzir

Requisitos: MySQL 8.0 e o cliente de linha de comando `mysql`. O projeto foi desenvolvido
no Windows com PowerShell.

1. Baixe os 9 CSVs do dataset no Kaggle e coloque em `data/raw/`.
2. Crie o banco e habilite a carga local de arquivos:

   ```sql
   CREATE DATABASE olist CHARACTER SET utf8mb4;
   SET GLOBAL local_infile = 1;
   ```

3. Rode os scripts **da raiz do projeto**, nesta ordem. A carga precisa do parâmetro
   `--local-infile=1`:

   ```
   mysql -u root -p -e "source sql/01_schema.sql"
   mysql -u root -p -D olist --local-infile=1 --show-warnings -e "source sql/02_carga.sql"
   mysql -u root -p -D olist -e "source sql/02b_chaves.sql"
   mysql -u root -p -D olist -e "source sql/02c_testes.sql"
   mysql -u root -p -D olist -t -e "source sql/03_profiling.sql"
   ```

   O `02_carga.sql` termina com a contagem de linhas de cada tabela, para conferência.
   O `02b_chaves.sql` não pode ser rodado duas vezes: para repetir, recrie o banco a
   partir do `01_schema.sql`.

## Decisões de método

- **SQL para preparar e validar, Power BI para o modelo e as medidas.** As regras de
  negócio ficam em views reutilizáveis; o DAX cuida das medidas que mudam com o filtro.
- **Camada bruta primeiro, chaves depois do profiling:** o dataset tem duplicatas (por
  exemplo, `review_id` repetido), e impor chaves antes de conhecer os dados esconderia o
  problema.
- **Validar contra a fonte:** as contagens do banco foram conferidas com os próprios
  CSVs, e a carga corrigiu três problemas que não geravam nenhum erro (caractere de
  escape, texto cortado por `varchar` curto e fim de linha do Windows).
- **Git:** uma branch por assunto, Pull Request e commits no padrão
  `tipo(escopo): resumo`.
