# Olist BI: etapas do projeto

Projeto de portfólio (simulação). A empresa, as pessoas e o cenário são fictícios;
os dados são os do dataset público *Brazilian E-Commerce Public Dataset by Olist*
(Kaggle). Última atualização: 16/10/2026.

## Situação geral

| # | Etapa | Entrega | Situação |
|---|---|---|---|
| 1 | Alinhamento: cenário, briefing e definições | `docs/briefing-diretoria.md` | Concluída |
| 2 | Ambiente, Git e GitHub | repositório, `.gitignore`, fluxo de branches e PRs | Concluída |
| 3 | Schema | `sql/01_schema.sql` (9 tabelas) | Concluída |
| 4 | Carga e validação | `sql/02_carga.sql` | Concluída |
| 5 | Profiling | `sql/03_profiling.sql` (5 blocos) | Concluída |
| 6 | Premissas | `docs/premissas.md` | Concluída |
| 7 | Chaves primárias e estrangeiras, com testes | `sql/02b_chaves.sql`, `sql/02c_testes.sql` | Concluída |
| 8 | Análises em SQL das 16 perguntas | `sql/04_analises/` (7 arquivos) | Concluída |
| 9 | Views para o BI | `sql/05_views/` (6 views) | Concluída |
| 10 | Modelo estrela e painel no Power BI (PBIP) | painel | **Próxima** |
| 11 | Dicionário de dados | `docs/dicionario-dados.md` | A fazer |
| 12 | Relatório executivo, README e apresentação | relatório de 1 página | A fazer |
| 13 | Ensaio com o diretor e entrega final | n/a | A fazer |

**Fases concluídas: preparação (etapas 1 a 7), análises (etapa 8) e views para o BI
(etapa 9).** Próxima: modelo estrela e painel no Power BI (etapa 10).

---

## Etapas concluídas

### 1. Alinhamento
- O diretor pediu respostas a 16 perguntas, em 7 áreas (vendas, produtos, clientes,
  vendedores, logística, satisfação, pagamentos e pedidos), mais uma pergunta direta
  sobre lucro.
- Termos como receita, pedido válido e pedido entregue foram definidos antes de
  qualquer cálculo.
- A pergunta sobre lucro será respondida com "o dado não permite": o dataset não
  tem custos.

### 2. Ambiente, Git e GitHub
- Fluxo: uma branch por assunto, commits no padrão `tipo(escopo): resumo`,
  Pull Request e merge na `main`.
- Dados brutos fora do repositório (`.gitignore`).

### 3. Schema
- 9 tabelas na camada bruta, no banco `olist` (MySQL 8, `utf8mb4`).
- Script reexecutável (`DROP TABLE IF EXISTS` + `CREATE TABLE`).
- `NOT NULL` só onde a regra é segura; produtos podem não ter categoria nem peso.

### 4. Carga e validação
- `LOAD DATA LOCAL INFILE` com `NULLIF(@var, '')` para campos vazios virarem `NULL`.
- Script reexecutável (`TRUNCATE` + carga), com `FOREIGN_KEY_CHECKS` desligado só
  durante a carga.
- Contagens conferidas contra os CSVs:

| Tabela | Linhas |
|---|---|
| customers | 99.441 |
| sellers | 3.095 |
| geolocation | 1.000.163 |
| order_items | 112.650 |
| order_payments | 103.886 |
| order_reviews | 99.224 |
| orders | 99.441 |
| products | 32.951 |
| product_category_name_translation | 71 |

- Três problemas silenciosos, que não geraram erro no MySQL, foram pegos pela
  conferência:
  1. `order_reviews` perdia 1 registro por causa do caractere de escape padrão
     (corrigido com `ESCAPED BY ''`);
  2. `product_category_name varchar(20)` cortava categorias (corrigido para 100);
  3. o arquivo de tradução usa fim de linha `\r\n` (corrigido em `LINES TERMINATED BY`).

### 5. Profiling
- Período: dados completos de jan/2017 a ago/2018 (20 meses). Fora do recorte:
  2016 e set/2018 em diante.
- Pedido válido: status diferente de `canceled` e `unavailable` (98.207 pedidos;
  excluídos 1.234, ou 1,24%).
- `order_reviews.review_id` não é único (814 linhas a mais que ids distintos) e
  547 pedidos têm mais de um review.
- `geolocation` tem 52,6 linhas por CEP.
- Zero órfãos nas 6 relações principais.
- Valores suspeitos documentados: 383 itens com frete zero, 9 pagamentos de valor
  zero, 1.359 pedidos postados antes da aprovação.

### 6. Premissas
- Cada achado do profiling virou uma regra escrita em `docs/premissas.md`
  (1 review por pedido, o mais recente; `geolocation` resumida por CEP; recorte do
  período; tratamento de pagamentos de valor zero).
- Fato e hipótese ficam separados.

### 7. Chaves primárias e estrangeiras, com testes
- 8 chaves primárias (4 simples, 3 compostas e a da tabela de tradução) e 6
  chaves estrangeiras (as relações sem órfãos).
- Sem FK de `products` para a tradução (610 produtos sem categoria e 2 categorias
  sem tradução) e sem chave na `geolocation`.
- `sql/02c_testes.sql` verifica quatro coisas:
  1. **existência** das chaves (8 e 6);
  2. **0 órfãos** nos dados existentes;
  3. **aplicação**: o banco barra 6 órfãos (erro 1452) e 1 duplicata (erro 1062),
     dentro de transação com `ROLLBACK`;
  4. **cobertura**, de forma informativa: 775 pedidos sem item, 1 sem pagamento e
     768 sem avaliação.
- A recarga completa de `02_carga.sql` com as chaves ativas foi testada e as
  contagens se mantiveram.

### 8. Análises em SQL das 16 perguntas
- Sete arquivos em `sql/04_analises/`, um por área:

| Arquivo | Perguntas |
|---|---|
| `01_vendas.sql` | 1 a 5 |
| `02_produtos.sql` | 6 |
| `03_clientes.sql` | 7 e 8 |
| `04_vendedores.sql` | 9 e 10 |
| `05_logistica.sql` | 11 e 12 |
| `06_satisfacao.sql` | 13 |
| `07_pagamentos_pedidos.sql` | 14 e 15 |

- A pergunta 16 (lucro) não tem consulta: a resposta é "o dado não permite".
- Todas seguem as regras de `docs/premissas.md`: pedido válido, recorte de
  jan/2017 a ago/2018, receita como soma de `price` (sem frete), pedidos como
  `COUNT(DISTINCT order_id)` e 1 review por pedido. Cada consulta declara as
  próprias CTEs, porque uma CTE vale só para a instrução em que foi escrita.
- Os 7 arquivos rodam sem erro. Números de referência do período (consultas 1.1 e
  1.2): **97.905 pedidos e R$ 13.449.529,68 de receita**. Os valores das demais
  consultas ainda precisam de conferência (somas de percentuais e contagens).

### 9. Views para o BI
As views ficam no MySQL e são consumidas pelo Power BI na etapa 10. As regras das
premissas (pedido válido, recorte do período, 1 review por pedido, pagamentos de
valor zero fora) ficam dentro das views, para o painel não refazer filtros.

| View | Grão | Observação |
|---|---|---|
| `vw_dim_cliente` | 1 por `customer_id` | traz `customer_unique_id` para contar pessoas e recompra |
| `vw_dim_vendedor` | 1 por vendedor | cidade e estado |
| `vw_dim_produtos` | 1 por produto | categoria traduzida, com `COALESCE` e `sem_categoria` |
| `vw_fato_pedidos` | 1 por pedido (todos do período) | flag `pedido_valido`; prazo, dias até a entrega e nota só para pedido válido |
| `vw_fato_itens` | 1 por item (pedidos válidos) | `preco` e `frete` separados |
| `vw_fato_pagamentos` | 1 por pagamento (válidos, sem valor zero) | forma e parcelas |

- Itens e pagamentos nunca são juntados na mesma tabela: um pedido tem vários de
  cada, e a junção multiplicaria a receita.
- `vw_fato_pedidos` mantém os cancelados porque a pergunta 15 precisa deles.
- O calendário será criado no Power BI, a partir de `data_compra`.
- Script reexecutável (`CREATE OR REPLACE VIEW`), com consultas de conferência no
  final.
- Conferências, todas dentro do esperado:
  - `vw_fato_itens`: 97.905 pedidos e R$ 13.449.529,68, iguais aos da etapa 8;
  - dimensões: 99.441 clientes, 3.095 vendedores e 32.951 produtos;
  - `vw_fato_pedidos`: linhas iguais aos pedidos distintos;
  - itens e pagamentos sem pedido correspondente: 0 e 0.

---

## Como reproduzir (etapas 3 a 9)

Da raiz do projeto:

```powershell
& $mysql -u root -p -e "source sql/01_schema.sql"
& $mysql -u root -p -D olist --local-infile=1 --show-warnings -e "source sql/02_carga.sql"
& $mysql -u root -p -D olist -e "source sql/02b_chaves.sql"
& $mysql -u root -p -D olist -e "source sql/02c_testes.sql"
& $mysql -u root -p -D olist -e "source sql/03_profiling.sql"
& $mysql -u root -p -D olist -e "source sql/04_analises/01_vendas.sql"
& $mysql -u root -p -D olist -e "source sql/04_analises/02_produtos.sql"
& $mysql -u root -p -D olist -e "source sql/04_analises/03_clientes.sql"
& $mysql -u root -p -D olist -e "source sql/04_analises/04_vendedores.sql"
& $mysql -u root -p -D olist -e "source sql/04_analises/05_logistica.sql"
& $mysql -u root -p -D olist -e "source sql/04_analises/06_satisfacao.sql"
& $mysql -u root -p -D olist -e "source sql/04_analises/07_pagamentos_pedidos.sql"
& $mysql -u root -p -D olist --table -e "source sql/05_views/05_views_bi.sql"
```

`02b_chaves.sql` não é reexecutável: para rodar de novo, recrie o banco a partir
do `01_schema.sql`.
