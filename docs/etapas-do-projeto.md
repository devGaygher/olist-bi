# Olist BI: etapas do projeto

Projeto de portfólio (simulação). A empresa, as pessoas e o cenário são fictícios;
os dados são os do dataset público *Brazilian E-Commerce Public Dataset by Olist*
(Kaggle). Última atualização: 04/11/2026. Prazo da simulação: 06/11/2026 (prorrogado; o prazo original era 28/10/2026).

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
| 10 | Modelo estrela e painel no Power BI (PBIP) | `powerbi/olist-bi.pbip` | **Em andamento** |
| 11 | Dicionário de dados | `docs/dicionario-dados.md` | A fazer |
| 12 | Relatório executivo, README e apresentação | relatório de 1 página | A fazer |
| 13 | Ensaio com o diretor e entrega final | n/a | A fazer |

**Fases concluídas: preparação (etapas 1 a 7), análises (etapa 8) e views para o BI
(etapa 9).** Em andamento: modelo estrela e painel no Power BI (etapa 10); o modelo, as
medidas e as 8 páginas (Visão executiva, Vendas, Produtos, Clientes, Vendedores,
Logística, Satisfação e Pagamentos e pedidos) estão montados; faltam o acabamento da
página Pagamentos e pedidos e as conferências abertas da Vendas. Em seguida vêm o dicionário
de dados (etapa 11), o relatório de 1 página e o README (etapa 12).

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
  1.2): **97.905 pedidos e R$ 13.449.529,68 de receita**. As consultas de
  satisfação (6.1 a 6.6) e de pagamentos e pedidos (7.1 a 7.6) tiveram as somas conferidas
  entre si em 04/11 (97.178 avaliados nas 6.3, 6.4 e 6.6; 96.203 entregues nas 6.1 e 6.5;
  99.092 pedidos nas 7.3 e 7.4; 75.674 pagamentos de cartão nas 7.2 e 7.6). Os valores das
  demais consultas ainda precisam de conferência (somas de percentuais e contagens).

### 9. Views para o BI
As views ficam no MySQL e são consumidas pelo Power BI na etapa 10. As regras das
premissas (pedido válido, recorte do período, 1 review por pedido, pagamentos de
valor zero fora) ficam dentro das views, para o painel não refazer filtros.

| View | Grão | Observação |
|---|---|---|
| `vw_dim_cliente` | 1 por `customer_id` | traz `customer_unique_id` para contar pessoas e recompra |
| `vw_dim_vendedor` | 1 por vendedor | cidade e estado |
| `vw_dim_produtos` | 1 por produto | categoria em português pela tabela `categoria_ptbr` (`05a_categorias_ptbr.sql`), com `COALESCE` e `Sem categoria` |
| `vw_fato_pedidos` | 1 por pedido (todos do período) | flag `pedido_valido`; prazo (comparação por data e hora), dias até a entrega, `dias_atraso` (entrega real menos estimada; negativo = adiantado) e nota só para pedido válido |
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

## Etapa em andamento

### 10. Modelo estrela e painel no Power BI
O painel fica em `powerbi/olist-bi.pbip`, no formato PBIP (arquivos de texto, que
funcionam bem com o Git). A conexão com o MySQL usa o modo Importar e lê apenas as 6
views da etapa 9, nunca as tabelas brutas.

**Modelo.** Cinco relacionamentos 1:N, com filtro em uma direção:

| Lado "um" | Lado "muitos" |
|---|---|
| `vw_dim_cliente[customer_id]` | `vw_fato_pedidos[customer_id]` |
| `vw_dim_vendedor[seller_id]` | `vw_fato_itens[seller_id]` |
| `vw_dim_produtos[product_id]` | `vw_fato_itens[product_id]` |
| `vw_fato_pedidos[order_id]` | `vw_fato_itens[order_id]` |
| `vw_fato_pedidos[order_id]` | `vw_fato_pagamentos[order_id]` |

Mais `Calendario[Date]` para `vw_fato_pedidos[data_compra]`. A tabela de pedidos é o
eixo do modelo; itens e pagamentos se ligam só a ela e nunca entre si, para a receita
não ser multiplicada.

**Calendário.** Criado em DAX para jan/2017 a ago/2018 (o recorte das premissas), com
ano, mês, rótulo do mês ("jan/17") e dia da semana, cada um com ordenação própria, e
marcado como tabela de datas.

**Medidas** (tabela `_Medidas`): Receita, Pedidos, Ticket Medio, Receita LY, Receita
2017 e 2018 jan-ago, Var YoY %, Receita Acumulada, % No Prazo, Tempo Medio Entrega,
Atraso Medio e Nota Media. Da página Produtos: Pedidos Avaliados, Nota Media Categoria,
Nota Media Categoria 100+ e Categorias 100+. Da página Clientes: Clientes, Clientes Recompra,
% Recompra, Clientes na Faixa, % Clientes na Faixa e Pedidos por Cliente (mais a tabela
auxiliar `Faixa Compra`, sem relacionamento). Da página Vendedores: medidas de faixa de receita, % postado no prazo, % atrasado, nota por vendedor e piso de 30 pedidos. Da página Logística: Frete % do Valor e a coluna calculada `Regiao` em `vw_dim_cliente`; `Atraso Medio` é a média de `dias_atraso` dos pedidos com `entregue_no_prazo` = 0. Da página Satisfação: `% Nota Baixa` e `Pedidos Sem Avaliacao`, mais as colunas calculadas `Faixa Atraso` e `Faixa Atraso Ordem` em `vw_fato_pedidos`. Da página Pagamentos e pedidos: `Pedidos no Periodo`, `Pedidos Perdidos`, `% Pedidos Perdidos`, `% Perdidos 100+`, `% Perdidos Geral`, `Pagamentos Cartao`, `Pagamentos Cartao Total`, `Pagamentos Parcelados`, `% Parcelado`, `Media Parcelas Cartao`, `% Pagamentos por Parcela`, `% Pedidos por Forma` e `% Valor por Forma`, mais a coluna calculada `Forma Pagamento PT` em `vw_fato_pagamentos`. A comparação de crescimento usa sempre jan-ago nos dois
anos, porque só 2017 tem 12 meses e 2018 termina em agosto.

**Conferências já feitas contra o SQL:**
- receita total de R$ 13.449.529,68 e 97.905 pedidos, iguais nos dois lados;
- 99.441 linhas de cliente (uma por pedido), 3.095 vendedores e 32.951 produtos;
- Produtos: top 10 de receita, 5 melhores e 5 piores notas e nº de categorias com 100+ avaliações (52), contra `02_produtos.sql`;
- Clientes: 94.707 pessoas, 2.054 recompradores (2,17%), faixas de dias de compra e recompra nos 5 maiores estados, contra `03_clientes.sql`;
- Vendedores: 3.029 vendedores com venda, faixas de receita (13,2% no top 10), 633 vendedores com 30+ pedidos (100 bons, 460 regulares, 73 problema) e 91,1% postados no prazo, contra `04_vendedores.sql`;
- Logística: 91,87% no prazo, 12,5 dias, 7.822 atrasados com média de 8,86 dias, frete de 16,6% do valor, os 20 meses, os 27 estados e as 5 regiões, contra `05_logistica.sql`.
- Satisfação: nota média 4,12, 13,84% de notas 1 ou 2, 727 sem avaliação em 97.905, pedidos por nota (soma 97.178), nota por faixa de atraso (4,29 / 3,59 / 2,10 / 1,67 / 1,72) e os 20 meses, contra `06_satisfacao.sql`.
- Pagamentos e pedidos: 1,19% de perdidos (1.182 de 99.092), média de 3,50 parcelas, 66,8% parcelados, participação por forma (77,0 / 19,9 / 3,8 / 1,5% dos pedidos e 78,5 / 18,0 / 2,2 / 1,4% do valor), parcelas, os 20 meses e os 24 estados com 100+ pedidos, contra `07_pagamentos_pedidos.sql`.

**Páginas do painel (8 previstas no desenho):**

| Página | Perguntas | Situação |
|---|---|---|
| Visão executiva | resumo | Pronta (texto de pedidos sem avaliação corrigido no PR #20; ajustes de formato pendentes) |
| Vendas | 1 a 5 | Pronta (conferências do ticket mensal, da Black Friday e da matriz ainda abertas) |
| Produtos | 6 | Pronta, conferida contra o SQL |
| Clientes | 7 e 8 | Pronta, conferida contra o SQL (PR feito em 26/10) |
| Vendedores | 9 e 10 | Pronta, conferida contra o SQL (27/10) |
| Logística | 11 e 12 | Pronta, conferida contra o SQL (28/10) |
| Satisfação | 13 | Pronta, conferida contra o SQL (29/10) |
| Pagamentos e pedidos | 14 e 15 | Montada em 30/10 e conferida contra o SQL; acabamento e PR em 04/11 |

A pergunta 16 (lucro) não tem página: a resposta é "o dado não permite" e vai no relatório.

**Página Produtos (concluída).**
- Cartões, top 10 por receita e rankings das 5 melhores e 5 piores notas, com piso de 100 pedidos avaliados (`>= 100`).
- Problema: o Top N com filtro separado de volume deixava os rankings incompletos. Solução: o piso foi movido para dentro da medida `Nota Media Categoria 100+`.
- Problema: o cartão de categorias contava todo o catálogo (74). Passou a contar só as que passam do piso (52, igual à consulta 2.2).
- Conferido contra `02_produtos.sql`: top 10 de receita, 5 melhores e 5 piores notas e nº de categorias.
- Pedidos sem avaliação: 727 de 97.905 (0,74%), base de pedidos com item. O 734 anterior era um teto, sem o recorte de período.
- Cache e arquivos locais do Power BI (`cache.abf`, `localSettings.json`) ficam fora do Git; ao abrir o PBIP, ligar o MySQL e atualizar.
- Achado: o ranking das piores notas é sensível ao piso (fashion_male_clothing tem 109 pedidos avaliados).

**Página Clientes (concluída em 26/10).**
- 4 cartões (Clientes, Pedidos válidos, % que recompraram, Pedidos por cliente), top 10 estados por clientes, clientes por número de dias de compra (1 dia, 2 dias, 3 ou mais), recompra nos 5 maiores estados e caixa "Como ler esta página".
- Definições: cliente = pessoa (`customer_unique_id`); recompra = comprou em 2 ou mais dias diferentes, só pedidos válidos.
- Problema: contar linhas de `vw_dim_cliente` superestima clientes (99.441 linhas, uma por pedido). Solução: a medida `Clientes` conta `customer_unique_id` distintos de pedidos válidos, com `CROSSFILTER` dentro da medida (94.707).
- Problema: o cartão "Pedidos por cliente" mostrou 1,000, porque a média por `customer_id` é sempre 1 (cada pedido tem um `customer_id` novo). Passou a ser `DIVIDE([Pedidos], [Clientes])`, que dá 1,034.
- Problema: o gráfico de dias de compra não tinha eixo no modelo. Solução: tabela auxiliar `Faixa Compra` (3 linhas, sem relacionamento) e duas medidas.
- Conferido contra `03_clientes.sql`: 94.707 clientes, 2.054 recompradores (2,17%), faixas 92.653 / 1.899 / 155 (97,83% / 2,01% / 0,16%) e recompra nos 5 maiores estados (SP 2,29%, RJ 2,43%, MG 2,02%, RS 2,15%, PR 1,94%).
- Resultado: 97,8% dos clientes compraram em um único dia; só 2,17% voltaram.
- Limites: a janela é de 20 meses, então a taxa medida é um piso da recompra real; a soma de clientes por estado passa do total, porque algumas pessoas aparecem em mais de um estado; cartões e gráfico de estados usam bases diferentes (pedidos válidos x pedidos com item), com diferença de até 4 clientes no total.
- A causa da recompra baixa (preço, frete, mix, falta de retenção) é hipótese, não é provada pelos dados.
- Git: o PR teve conflito em `pages.json` e `_Medidas.tmdl`, porque a `main` mudou os mesmos arquivos; resolvido com merge da `main` na branch.

**Página Vendedores (concluída em 27/10).**
- 3 cartões (vendedores com venda, % da receita no top 10 e % postado no prazo), colunas por faixa de receita (top 10, 11 a 100 e demais), tabela dos vendedores com 30 ou mais pedidos (nota, atraso e postagem) e caixa "Como ler esta página".
- Definições: vendedor = `seller_id` (sem nomes); um pedido com itens de 2 vendedores entra na conta dos dois (99.245 pares pedido x vendedor contra 97.905 pedidos). Classificação por nota e atraso, com piso de 30 pedidos, em `docs/premissas.md`.
- Conferido contra `04_vendedores.sql`: 3.029 vendedores com venda (a dimensão tem 3.095); top 10 = R$ 1.780.371,06 (13,2% da receita), 11 a 100 = 32,1% e demais = 54,7%; o maior vendedor tem 1,7% e os 20 maiores 21,2%; 91,1% postados no prazo; dos 633 vendedores com 30+ pedidos, 100 bons, 460 regulares e 73 problema (7,3% da receita).
- Resposta à pergunta 10: o dataset não tem custo de suporte, então "dor de cabeça" é medida por nota baixa ou atraso.
- Achado: o 5º maior vendedor (982 pedidos) tem nota 3,49 e é "problema" só pela nota.
- Limites: nota, atraso e postagem só aparecem para os vendedores com 30+ pedidos (77,1% da receita); o cartão de postagem cobre todos os vendedores.
- A causa de um vendedor atrasar ou avaliar mal é hipótese, não é provada pelos dados.

**Página Logística (concluída em 28/10).**
- 4 cartões (% no prazo, tempo médio de entrega, atraso médio e frete % do valor), colunas e linha por mês (tempo médio e % no prazo), os 5 estados com menor % no prazo, os 5 maiores fretes por estado, entrega no prazo por região e caixa "Como ler esta página".
- Definições: o prazo é comparado por data e hora, e a data estimada não tem horário (`docs/premissas.md`, Bloco 2A); região = região do IBGE do estado do cliente.
- Medida nova: `Frete % do Valor`. Coluna calculada nova: `Regiao`, em `vw_dim_cliente`.
- Problema: o cartão de atraso médio mostrava 10,62 dias, enquanto o `% No Prazo` já contava 7.822 atrasados. A medida só considerava atrasos de 1 dia ou mais (6.531 pedidos); 1.291 pedidos chegaram no dia prometido, depois da meia-noite (`dias_atraso` = 0). Solução: a medida passou a usar `entregue_no_prazo` = 0, e o cartão mostra 8,86, igual à consulta 5.4.
- Problema: o gráfico "Top 5 atraso médio por estado" mostrava AP com 72,5 dias, mas AP teve 67 pedidos entregues e 95,5% no prazo, ou seja, só cerca de 3 atrasos. Solução: o visual foi trocado pelos 5 estados com menor % no prazo (AL 76,0%; MA 80,4%; PI 84,0%; CE e SE 84,6%), todos com mais de 300 pedidos.
- Conferido contra `05_logistica.sql` (5.1 a 5.6; as duplicatas de 5.1 e 5.2 foram removidas) e consultas de verificação no MySQL: 96.203 pedidos entregues, 91,87% no prazo, 12,5 dias, 7.822 atrasados com média de 8,86 dias (1.291 no dia prometido e 6.531 com 1 dia ou mais, a consulta 5.7 registra essa divisão), frete de 16,6% do valor, os 20 meses, os 27 estados e as 5 regiões (a soma das regiões dá 96.203).
- Fatos: mar/18 teve a menor pontualidade (78,6%) e fev/18 o maior tempo médio (16,9 dias). O Norte tem as entregas mais lentas (RR 29,9, AP 27,2 e AM 26,4 dias), contra 8,7 dias em SP. Lento não é o mesmo que atrasado: RO, AM, AC e AP ficam entre 95% e 97% no prazo, enquanto AL (76,0%) e MA (80,4%) são os piores. O Nordeste tem a menor pontualidade entre as regiões (85,6%). O frete pesa mais em RR (27,8%), MA (26,2%) e RO (24,7%), e menos em SP (13,8%).
- Limites: RR (40 pedidos), AP (67) e AC (80) oscilam mais; só entram pedidos entregues, o que pode subestimar o tempo médio dos meses mais recentes; o dataset não identifica a transportadora. Pela comparação só por data, o % no prazo iria para cerca de 93,2% (conta derivada, ver `docs/premissas.md`).
- A causa da lentidão e do frete alto (distância, transportadora, vendedor) é hipótese, não é provada pelos dados.

**Correção dos nomes de categoria (29/10).**
- Problema: o painel mostrava as categorias em inglês, com erros de digitação vindos da tabela de tradução do dataset (ex.: `costruction_tools_garden`). Solução: tabela de mapeamento `categoria_ptbr` (73 categorias, nome único em português), usada pela `vw_dim_produtos` e pelas consultas 2.1 e 2.2.
- Problema: os acentos foram gravados errados (`sa├║de`, 15 caracteres em vez de 14) porque o cliente `mysql` do Windows enviou o arquivo com a code page do console. Solução: `SET NAMES utf8mb4` no início do `05a_categorias_ptbr.sql` e conferência dos bytes com `HEX()`.
- Problema: a view nova não mudava o painel enquanto o `CREATE OR REPLACE VIEW` não era executado no MySQL; só depois disso e de atualizar a importação os nomes trocaram.
- Conferido: 32.951 produtos (610 sem categoria), top 10 de receita igual ao anterior (R$ 8,39 Mi, 62,4%) e 52 categorias com 100+ avaliações.
- Decisão: sem fusão de categorias (`eletrodomesticos_2` e `casa_conforto_2` ficam separadas), para os totais não mudarem (`docs/premissas.md`, Bloco 6).

**Página Satisfação (concluída em 29/10).**
- 3 cartões (nota média, % de avaliações com nota 1 ou 2 e pedidos sem avaliação), colunas de nota média por faixa de atraso, colunas de pedidos por nota, linha de nota média por mês de compra e caixa "Como ler esta página".
- Definições: nota = 1 review por pedido (o mais recente); base = pedidos válidos com item (97.905); faixas de atraso só entre pedidos entregues, com cortes de 3, 7 e 14 dias, escolha da análise (`docs/premissas.md`, Bloco 7).
- Colunas calculadas novas em `vw_fato_pedidos`: `Faixa Atraso` e `Faixa Atraso Ordem`. Medidas novas: `% Nota Baixa` e `Pedidos Sem Avaliacao`, ambas sobre `Pedidos` (base de itens). `Pedidos Avaliados` (Produtos) não foi usada: dá 97.181, porque inclui 3 pedidos avaliados que não têm item.
- Problema: a `Faixa Atraso Ordem` lia a `Faixa Atraso`, e a `Faixa Atraso` era classificada por ela; o Power BI acusou dependência circular. Solução: a ordem lê as colunas de origem (`entregue_no_prazo` e `dias_atraso`).
- Problema: o gráfico de pedidos por nota somou 3.266 (esperado 97.178) e a linha mensal ficou abaixo da consulta 6.6, enquanto os cartões e o gráfico de faixa de atraso batiam. A medida estava certa; a causa estava no contexto de filtro dos dois visuais (provavelmente filtros herdados na cópia de um visual de outra página; causa não confirmada). Corrigido nos visuais.
- Problema: uma barra "(Em branco)" no gráfico de faixa de atraso, dos pedidos válidos ainda sem entrega (cerca de 1.700). Solução: filtro no visual (faixa não vazia).
- Conferido contra `06_satisfacao.sql` (6.1 a 6.6): 4,12; 13,84% de notas 1 ou 2; 727 sem avaliação em 97.905; pedidos por nota (soma 97.178); nota por faixa de atraso (4,29 / 3,59 / 2,10 / 1,67 / 1,72); 20 meses (soma 97.178 avaliados). As consultas fecham entre si (6.1 e 6.5: 7.658 avaliados com atraso e 96.203 entregues).
- Fatos: nota média de 4,29 no prazo contra 2,57 com atraso; a queda mais forte está entre "Até 3 dias" (3,59) e "De 4 a 7 dias" (2,10), e de 8 dias em diante a nota fica perto de 1,7. 13,84% das avaliações têm nota 1 ou 2. As menores notas mensais são mar/18 (3,76), fev/18 (3,86) e nov/17 (3,95); mar/18 também teve a menor pontualidade.
- Limites: a nota representa só quem avaliou (727 pedidos sem avaliação); a faixa "Até 3 dias" inclui 1.291 pedidos entregues no dia prometido, depois da meia-noite; pedidos ainda não entregues ficam fora do gráfico de faixas.
- A causa da nota baixa (atraso, produto, atendimento) é hipótese, não é provada pelos dados.

**Página Pagamentos e pedidos (montada em 30/10; acabamento e PR em 04/11).**
- 3 cartões (pedidos perdidos, média de parcelas no cartão e pagamentos no cartão em 2 ou mais parcelas), participação por forma de pagamento (por pedidos e por valor), parcelas do cartão, % de perdidos por mês, % de perdidos por estado do cliente (com linha da taxa geral) e caixa "Como ler esta página".
- Definições: perdidos = cancelados + indisponíveis, sobre todos os pedidos do período (99.092); formas de pagamento de pedidos válidos com valor acima de zero; média de parcelas por pagamento, só cartão, sem os de 0 parcelas; estados com 100 ou mais pedidos (`docs/premissas.md`, Bloco 8).
- Colunas e medidas novas: `Forma Pagamento PT` (coluna calculada em `vw_fato_pagamentos`) e as 13 medidas listadas acima. A taxa de perdidos sai de `COUNTROWS` na `vw_fato_pedidos` (que mantém os cancelados), não de `Pedidos`, que é por item.
- Problema: as barras de participação por forma saíram todas com 100%. As medidas removiam o filtro da coluna original `forma_pagamento`, mas o eixo do gráfico usava a coluna traduzida. Solução: remover o filtro da coluna que está no eixo (`Forma Pagamento PT`).
- Problema: `% Perdidos 100+` e `% Perdidos Geral` deram erro porque a `% Pedidos Perdidos`, da qual dependem, ainda não existia no modelo. Solução: criar as medidas na ordem de dependência.
- Problema: o cartão de 2 ou mais parcelas mostrou 0,67 em vez de 66,8%. O formato de porcentagem precisa estar na medida, não no visual.
- Regra aplicada: `KEEPFILTERS` em `Pagamentos Cartao`. Sem ele, o filtro `parcelas > 0` do `CALCULATE` apagaria o filtro do eixo de parcelas e todas as colunas mostrariam o total.
- Conferido contra `07_pagamentos_pedidos.sql` (7.1 a 7.6): 1,19%; 3,50; 66,8%; participação por forma; parcelas (33,2 / 16,2 / 13,6 / 9,2 / 6,9 / 6,8 / 5,6 / 5,1 / 2,1 / 0,8 ...); 20 meses (0,29% a 3,48%); 24 estados (RO 2,77% a MT 0,44%) com a linha da taxa geral em 1,19%.
- Fatos: cartão de crédito é 77,0% dos pedidos e 78,5% do valor; 66,8% dos pagamentos no cartão são parcelados, com picos em 8 e 10 parcelas; 1.182 pedidos perdidos (580 cancelados e 602 indisponíveis); a maior taxa mensal é a de fev/17 (3,48%, base de 1.780 pedidos), e o 1,40% de ago/18 vem dos cancelados; RO tem a maior taxa por estado, com só 7 pedidos perdidos.
- Limites: a participação por pedidos soma 102,2%; o dataset não traz o motivo do cancelamento; 3 estados com menos de 100 pedidos ficam fora do gráfico (a confirmar com consulta).
- A causa do cancelamento, da indisponibilidade e dos picos de parcelamento é hipótese, não é provada pelos dados.
- Vendas, no mesmo PR: o gráfico de ticket médio por mês ganhou uma linha de referência com o ticket do período (R$ 137,37, igual ao cartão).

**Pendente:**
- fechar o PR da página Pagamentos e pedidos (aberto em 04/11) e commitar estes documentos;
- acabamento da página Pagamentos e pedidos, na captura de 04/11: subtítulo "Nota de 1 a 5" herdado no gráfico de estados, eixo das parcelas ordenado por valor (deveria ir de 1 a 24) e rótulos dos botões de navegação ("Logística" e "Pagamentos") nas páginas;
- formato dos contadores da Vendas, que mostram ",00" (ex.: 97.905,00);
- conferências abertas da Vendas: ticket médio por mês, receita de 24/11/2017 (Black Friday) e células da matriz de dia x horário; confirmar se a linha de média do ticket usa a medida ou um valor fixo;
- limpeza do modelo: excluir a medida vazia `Medida` e trocar o formato de `Pedidos Avaliados` para `#,0`;
- confirmar com consulta que os pedidos do período vêm de 27 estados;
- dicionário de dados (etapa 11), relatório de 1 página e README (etapa 12), ensaio com o diretor.

**Cronograma revisado (26/10).** O prazo passou de 28/10/2026 para 06/11/2026, para fechar as 8 páginas com o mesmo cuidado de conferência. Situação em 04/11:

| Data | Entrega | Situação |
|---|---|---|
| 27/10 | Página Vendedores (perguntas 9 e 10) | Feita |
| 28/10 | Página Logística (11 e 12) | Feita |
| 29/10 | Página Satisfação (13) | Feita |
| 30/10 | Página Pagamentos e pedidos (14 e 15) | Montada em 30/10; acabamento e PR em 04/11 |
| 31/10 | Reserva: conferências abertas e textos dos documentos | Textos dos documentos atualizados em 04/11; conferências da Vendas abertas |
| 02/11 | Dicionário de dados (etapa 11) | A fazer (atrasado) |
| 03 a 04/11 | Relatório executivo de 1 página e README | A fazer (atrasado) |
| 05/11 | Ensaio com o diretor | A fazer |
| 06/11 | Entrega final | A fazer |

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

Para abrir o painel (etapa 10), instale o MySQL Connector/NET, abra
`powerbi/olist-bi.pbip` no Power BI Desktop e informe as credenciais do MySQL na
primeira atualização. A senha não fica nos arquivos do projeto.
