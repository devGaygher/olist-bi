# Dicionário de dados: Olist BI

Este documento descreve as 6 views que alimentam o Power BI, as colunas calculadas e as medidas criadas no Power BI. Serve para que outra pessoa chegue aos mesmos números do painel.

> Projeto de portfólio com cenário fictício. Os dados são os do dataset público Brazilian E-Commerce Public Dataset by Olist (Kaggle). Clientes, vendedores e produtos aparecem só como códigos.

As regras de negócio completas estão em `docs/premissas.md`. Aqui ficam apenas as que mudam o conteúdo das colunas.

## 1. Regras que valem para todas as views

| Regra | Definição |
|---|---|
| Período | Compras de 01/01/2017 a 31/08/2018 (`data_hora_compra >= '2017-01-01'` e `< '2018-09-01'`). 2016 e set/2018 em diante ficam fora. |
| Pedido válido | Status diferente de `canceled` e `unavailable`. |
| Receita | Soma de `preco` dos itens, sem o frete, de pedidos válidos. |
| Review | 1 review por pedido: o mais recente (`review_answer_timestamp` decrescente, `review_creation_date` decrescente como desempate). |
| Pagamento de valor zero | Fica fora (3 `not_defined` e 6 `voucher`). |
| Cliente | Pessoa identificada por `customer_unique_id`. O `customer_id` muda a cada pedido. |
| Categoria do produto | Nome em português, vindo da tabela `categoria_ptbr` (script `05a_categorias_ptbr.sql`, que deve rodar **antes** do `05_views_bi.sql`). |

Os tipos abaixo vêm do schema e das expressões das views. Para confirmar no banco: `DESCRIBE nome_da_view;`.

## 2. Modelo e relacionamentos

Seis views e uma tabela de datas criada no Power BI. Todos os relacionamentos são 1:N, com filtro em uma direção (do lado "um" para o lado "muitos").

| Lado "um" | Lado "muitos" |
|---|---|
| `vw_dim_cliente[customer_id]` | `vw_fato_pedidos[customer_id]` |
| `vw_dim_vendedor[seller_id]` | `vw_fato_itens[seller_id]` |
| `vw_dim_produtos[product_id]` | `vw_fato_itens[product_id]` |
| `vw_fato_pedidos[order_id]` | `vw_fato_itens[order_id]` |
| `vw_fato_pedidos[order_id]` | `vw_fato_pagamentos[order_id]` |
| `Calendario[Date]` | `vw_fato_pedidos[data_compra]` |

Itens e pagamentos **nunca** se ligam entre si: um pedido pode ter vários itens e vários pagamentos, e ligar os dois multiplicaria a receita (fan-out). No Power BI as tabelas aparecem com o prefixo `olist` (por exemplo, `olist vw_fato_pedidos`).

## 3. Dimensões

### 3.1 `vw_dim_cliente`

- **Grão:** 1 linha por `customer_id` (99.441 linhas, o mesmo número de `customers`).
- **Chave:** `customer_id`.

| Coluna | Tipo | Descrição | Observação |
|---|---|---|---|
| `customer_id` | texto | Código do cliente naquele pedido | Muda a cada pedido; liga com `vw_fato_pedidos` |
| `customer_unique_id` | texto | Código da pessoa | Usar para contar clientes e recompra; contar linhas superestima clientes |
| `cidade` | texto | Cidade do cliente | |
| `estado` | texto | Sigla do estado do cliente | 27 estados |

### 3.2 `vw_dim_vendedor`

- **Grão:** 1 linha por vendedor (3.095 linhas).
- **Chave:** `seller_id`.

| Coluna | Tipo | Descrição | Observação |
|---|---|---|---|
| `seller_id` | texto | Código do vendedor | Liga com `vw_fato_itens` |
| `cidade` | texto | Cidade do vendedor | |
| `estado` | texto | Sigla do estado do vendedor | |

Apenas 3.029 vendedores têm venda de pedido válido no período.

### 3.3 `vw_dim_produtos`

- **Grão:** 1 linha por produto (32.951 linhas).
- **Chave:** `product_id`.

| Coluna | Tipo | Descrição | Observação |
|---|---|---|---|
| `product_id` | texto | Código do produto | Liga com `vw_fato_itens` |
| `categoria` | texto | Categoria em português | Vem de `categoria_ptbr`. Produto sem categoria (610) aparece como "Sem categoria". Total esperado: 74 valores (73 categorias mais "Sem categoria") |

A tradução é 1 para 1, sem fundir categorias, para que os totais não mudem.

## 4. Fatos

### 4.1 `vw_fato_pedidos`

- **Grão:** 1 linha por pedido, de todos os status do período, inclusive cancelados (99.092 pedidos). Os válidos são 97.910; os que têm item, 97.905.
- **Chave:** `order_id`.
- As colunas `dias_ate_entrega`, `entregue_no_prazo`, `dias_atraso` e `nota_review` ficam vazias (NULL) para pedido não válido. As três primeiras também ficam vazias se o pedido ainda não foi entregue.

| Coluna | Tipo | Descrição | Observação |
|---|---|---|---|
| `order_id` | texto | Código do pedido | Liga com itens e pagamentos |
| `customer_id` | texto | Código do cliente no pedido | Liga com `vw_dim_cliente` |
| `data_hora_compra` | data e hora | Momento da compra | Base da faixa de horário |
| `data_compra` | data | Dia da compra | Liga com `Calendario[Date]` |
| `status_pedido` | texto | Status original do pedido | delivered, shipped, canceled, unavailable, invoiced, processing, created, approved |
| `pedido_valido` | 0 ou 1 | 1 se o status não é canceled nem unavailable | Os pedidos com 0 são os "perdidos" |
| `data_entrega_estimada` | data e hora | Data prometida ao cliente | Vem às 00:00:00 |
| `data_entrega_real` | data e hora | Data em que o cliente recebeu | Vazia se não entregue |
| `dias_ate_entrega` | inteiro | Dias entre a compra e a entrega | Só pedido válido entregue; `DATEDIFF` conta dias inteiros |
| `entregue_no_prazo` | 0 ou 1 | 1 = no prazo, 0 = atrasado | Compara **data e hora** (`entrega real <= estimada`). Uma entrega no próprio dia prometido, depois da meia-noite, conta como atrasada |
| `dias_atraso` | inteiro | Dias entre a entrega real e a estimada | Negativo = adiantado; 0 pode ser atrasado (chegou no dia prometido, depois da meia-noite) |
| `nota_review` | inteiro | Nota de 1 a 5 do review mais recente | Vazia se o pedido não foi avaliado (727 dos 97.905 válidos com item, 0,74%) |

### 4.2 `vw_fato_itens`

- **Grão:** 1 linha por item de pedido, só de pedido válido do período.
- **Chave:** `order_id` + `order_item_id`.

| Coluna | Tipo | Descrição | Observação |
|---|---|---|---|
| `order_id` | texto | Código do pedido | Liga com `vw_fato_pedidos` |
| `order_item_id` | inteiro | Número do item dentro do pedido | |
| `product_id` | texto | Código do produto | Liga com `vw_dim_produtos` |
| `seller_id` | texto | Código do vendedor | Liga com `vw_dim_vendedor` |
| `preco` | decimal (R$) | Preço do item, sem frete | Receita = soma desta coluna |
| `frete` | decimal (R$) | Frete do item | Fica fora da receita; 383 itens têm frete zero |
| `data_limite_postagem` | data e hora | Data limite para o vendedor postar | Base do despacho no prazo |
| `data_postagem` | data e hora | Data em que o pedido foi postado | Vem de `orders`; vazia se ainda não postado |

Para contar pedidos use `COUNT(DISTINCT order_id)` (em DAX, `DISTINCTCOUNT`), nunca contar linhas.

### 4.3 `vw_fato_pagamentos`

- **Grão:** 1 linha por pagamento, de pedido válido do período, sem valor zero.
- **Chave:** `order_id` + `sequencia`.

| Coluna | Tipo | Descrição | Observação |
|---|---|---|---|
| `order_id` | texto | Código do pedido | Liga com `vw_fato_pedidos` |
| `sequencia` | inteiro | Ordem do pagamento dentro do pedido | |
| `forma_pagamento` | texto | credit_card, boleto, voucher ou debit_card | Um pedido pode usar mais de uma forma |
| `parcelas` | inteiro | Número de parcelas | 2 pagamentos de cartão têm 0 parcelas e saem só da média de parcelas |
| `valor` | decimal (R$) | Valor do pagamento | A soma dos pagamentos passa da receita (inclui frete; hipótese ainda não conferida) |

## 5. Tabelas criadas no Power BI

| Tabela | Tipo | Função |
|---|---|---|
| `Calendario` | calculada (`CALENDAR` de 01/01/2017 a 31/08/2018) | Tabela de datas, marcada como tabela de datas |
| `_Medidas` | tabela de apoio | Guarda as medidas |
| `Faixa Vendedor` | `DATATABLE`, sem relacionamento | Faixas "Top 10", "11 a 100" e "Demais", com coluna `Ordem` |
| `Faixa Compra` | `DATATABLE`, sem relacionamento | Faixas "1 dia", "2 dias" e "3 ou mais", com coluna `Ordem` |

## 6. Colunas calculadas do Power BI

São calculadas linha a linha e ficam na tabela indicada. Não confundir com medidas.

| Tabela | Coluna | Descrição |
|---|---|---|
| `Calendario` | `Ano`, `Mes`, `MesNum` | Ano, nome do mês e número do mês. `Mes` é classificada por `MesNum` |
| `Calendario` | `MesOrdem` | Ano × 100 + mês, usada para ordenar |
| `Calendario` | `MesRotulo` | Rótulo como "jan/17", classificado por `MesOrdem` |
| `Calendario` | `DiaSemanaNum`, `DiaSemana` | Dia da semana (segunda = 1) e seu nome |
| `vw_fato_pedidos` | `Situacao Entrega` | "No prazo" ou "Com atraso" (vazio se não entregue) |
| `vw_fato_pedidos` | `Faixa Horario` | Madrugada (0 a 5h), Manhã (6 a 11h), Tarde (12 a 17h), Noite (18 a 23h) |
| `vw_fato_pedidos` | `Faixa Ordem` | 1 a 4, ordena a faixa de horário |
| `vw_fato_pedidos` | `Faixa Atraso` | No prazo, Até 3 dias, De 4 a 7 dias, De 8 a 14 dias, Mais de 14 dias (só pedidos entregues) |
| `vw_fato_pedidos` | `Faixa Atraso Ordem` | 1 a 5. Lê `entregue_no_prazo` e `dias_atraso`, e não a `Faixa Atraso`, para evitar dependência circular |
| `vw_dim_cliente` | `Regiao` | Região do IBGE (Norte, Nordeste, Centro-Oeste, Sudeste, Sul) a partir do estado |
| `vw_fato_pagamentos` | `Forma Pagamento PT` | Crédito, Boleto, Voucher, Débito |

Os cortes de 3, 7 e 14 dias da faixa de atraso e as faixas de horário são escolhas do projeto, não do dataset.

## 7. Medidas DAX

Todas ficam em `_Medidas`. O texto exato de cada uma está em `powerbi/olist-bi.SemanticModel/definition`. Aqui estão o significado e a regra.

### Vendas

| Medida | O que mede |
|---|---|
| `Receita` | Soma de `preco` (sem frete) |
| `Pedidos` | Pedidos distintos nos itens (`DISTINCTCOUNT` de `order_id`) |
| `Ticket Medio` | `Receita` ÷ `Pedidos` |
| `Receita LY` | Receita do mesmo período do ano anterior |
| `Receita 2017 JanAgo`, `Receita 2018 JanAgo` | Receita de jan a ago de cada ano |
| `Var YoY %` | Crescimento de jan-ago/2018 sobre jan-ago/2017. Nunca ao lado do total de 20 meses sem dizer "jan-ago" |
| `Receita Acumulada` | Receita acumulada no ano (`TOTALYTD`) |

### Logística

| Medida | O que mede |
|---|---|
| `% No Prazo` | Pedidos entregues no prazo sobre os entregues (`entregue_no_prazo`) |
| `Tempo Medio Entrega` | Média de `dias_ate_entrega` |
| `Atraso Medio` | Média de `dias_atraso` dos pedidos com `entregue_no_prazo = 0` |
| `Frete % do Valor` | Soma do frete ÷ soma do preço |

### Satisfação e produtos

| Medida | O que mede |
|---|---|
| `Nota Media` | Média de `nota_review` por pedido |
| `% Nota Baixa` | Pedidos com nota 1 ou 2 sobre os avaliados |
| `Pedidos Sem Avaliacao` | Pedidos sem `nota_review` (base de itens) |
| `Pedidos Avaliados` | Pedidos com nota, filtrando pelos itens da categoria (`CROSSFILTER ... BOTH` dentro da medida) |
| `Nota Media Categoria` | `Nota Media` com o filtro da categoria chegando aos pedidos |
| `Nota Media Categoria 100+` | Igual, mas vazia abaixo de 100 pedidos avaliados |
| `Categorias 100+` | Número de categorias com 100 ou mais pedidos avaliados |

### Clientes e vendedores

| Medida | O que mede |
|---|---|
| `Clientes` | Pessoas distintas (`customer_unique_id`) com pedido válido |
| `Clientes Recompra` | Pessoas com compra em 2 ou mais dias distintos |
| `% Recompra` | `Clientes Recompra` ÷ `Clientes` |
| `Clientes na Faixa`, `% Clientes na Faixa` | Pessoas por faixa de dias de compra, e sua participação |
| `Receita na Faixa`, `% Receita na Faixa`, `% Receita Top 10` | Receita e participação por faixa de vendedor |
| `% Postado no Prazo` | Pares pedido x vendedor postados até `data_limite_postagem` |
| `% Atrasado` | Atraso na entrega dos pedidos do vendedor |
| `Nota Vendedor` | Nota média dos pedidos do vendedor |
| `Pedidos 30+` | `Pedidos` só para vendedores com 30 ou mais pedidos |

### Pagamentos e pedidos

| Medida | O que mede |
|---|---|
| `Pedidos no Periodo` | Todos os pedidos do período (linhas de `vw_fato_pedidos`) |
| `Pedidos Perdidos` | Pedidos com `pedido_valido = 0` |
| `% Pedidos Perdidos`, `% Perdidos 100+`, `% Perdidos Geral` | Taxa de perdidos; com piso de 100 pedidos; e a taxa do período todo (linha de referência) |
| `% Pedidos por Forma`, `% Valor por Forma` | Participação de cada forma por pedidos (soma passa de 100%) e por valor (soma 100%) |
| `Pagamentos Cartao`, `Pagamentos Cartao Total`, `Pagamentos Parcelados` | Contagens de pagamentos no cartão |
| `% Parcelado` | Pagamentos de cartão em 2 ou mais parcelas |
| `% Pagamentos por Parcela` | Participação de cada número de parcelas |
| `Media Parcelas Cartao` | Média de parcelas do cartão, por pagamento, sem pagamentos de 0 parcelas |

## 8. Bases de contagem que aparecem no painel

| Base | Valor | Onde aparece |
|---|---|---|
| Todos os pedidos do período | 99.092 | Pagamentos e pedidos (taxa de perdidos) |
| Pedidos válidos (sem filtro de item) | 97.910 | `vw_fato_pedidos` com `pedido_valido = 1` |
| Pedidos válidos com item | 97.905 | Cartões de pedidos, receita e ressalva de avaliação |
| Pedidos entregues | 96.203 | Logística e Satisfação (faixas de atraso) |
| Clientes únicos com pedido válido | 94.707 | Clientes |

Cada página do painel diz qual é a sua base.

## 9. Limites dos dados

- Não há custo nem despesa: o lucro não pode ser calculado. O painel mostra receita.
- A nota média cobre só quem avaliou.
- Clientes, vendedores e produtos só existem como códigos.
- A relação entre nota e atraso é associação; o dado não prova a causa.
