# Olist BI: etapas do projeto

Projeto de portfólio (simulação). A empresa, as pessoas e o cenário são fictícios;
os dados são os do dataset público *Brazilian E-Commerce Public Dataset by Olist*
(Kaggle). Última atualização: 09/10/2026.

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
| 8 | Análises em SQL das 16 perguntas | `sql/04_analises/` | A fazer |
| 9 | Views para o BI | `sql/05_views_bi.sql` | A fazer |
| 10 | Modelo estrela e painel no Power BI (PBIP) | painel | A fazer |
| 11 | Dicionário de dados | `docs/dicionario-dados.md` | A fazer |
| 12 | Relatório executivo, README e apresentação | relatório de 1 página | A fazer |
| 13 | Ensaio com o diretor e entrega final | n/a | A fazer |

**Fase concluída: preparação (etapas 1 a 7).** Próxima: análises em SQL (etapa 8).

---

## Etapas concluídas

### 1. Alinhamento
- O diretor pediu respostas a 16 perguntas, em 7 áreas: vendas, produtos, clientes,
  vendedores, logística, satisfação, pagamentos e pedidos.
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

---

## Como reproduzir (etapas 3 a 7)

Da raiz do projeto:

```powershell
& $mysql -u root -p -e "source sql/01_schema.sql"
& $mysql -u root -p -D olist --local-infile=1 --show-warnings -e "source sql/02_carga.sql"
& $mysql -u root -p -D olist -e "source sql/02b_chaves.sql"
& $mysql -u root -p -D olist -e "source sql/02c_testes.sql"
```

`02b_chaves.sql` não é reexecutável: para rodar de novo, recrie o banco a partir
do `01_schema.sql`.
