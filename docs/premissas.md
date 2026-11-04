# Premissas do projeto

> **Material fictício.** A empresa e as pessoas da simulação não existem. Os dados
> são os do dataset público *Brazilian E-Commerce Public Dataset by Olist* (Kaggle).
> As decisões abaixo vêm do profiling (`sql/03_profiling.sql`).

## 1. Definições acordadas

| Termo | Definição |
|---|---|
| **Receita / "vendemos"** | Soma de `price` dos itens (sem o frete) de pedidos válidos |
| **Pedido válido** | Status diferente de `canceled` e `unavailable` |
| **Período de análise** | Janeiro/2017 a agosto/2018 (20 meses completos). Comparação ano contra ano usa jan-ago nos dois anos |
| **Ticket médio** | Receita ÷ número de pedidos (`COUNT(DISTINCT order_id)`) |
| **Cliente** | Pessoa identificada por `customer_unique_id` (o `customer_id` muda a cada pedido) |
| **Recompra** | Cliente com 2 ou mais pedidos válidos em datas diferentes |
| **Entrega no prazo** | Comparação por data e hora: `order_delivered_customer_date` ≤ `order_estimated_delivery_date`, só pedidos válidos e entregues. A data estimada vem sem horário (00:00:00), então uma entrega no dia prometido, depois da meia-noite, conta como atraso (ver Bloco 2A) |
| **Atraso** | Pedido entregue depois da data e hora estimadas. `dias_atraso` é a diferença em dias de calendário entre a data de entrega e a data estimada; quem chega depois da meia-noite do dia prometido tem `dias_atraso` = 0, mas é atrasado |
| **Atraso médio** | Média de `dias_atraso` dos pedidos com `entregue_no_prazo` = 0 (todos os atrasados, inclusive os de `dias_atraso` = 0). Resultado: 8,86 dias |
| **Tempo de entrega** | Dias entre a compra e a entrega ao cliente, só pedidos entregues |
| **Vendedor que despacha no prazo** | Postagem até a data limite de envio (`shipping_limit_date`) |
| **Classificação de vendedores** | Só vendedores com 30 ou mais pedidos. **Bom:** nota média ≥ 4,3 e atraso ≤ 5%. **Problema:** nota média < 3,5 ou atraso > 15%. **Regular:** os demais. Atraso = % de pedidos do vendedor com `entregue_no_prazo` = 0. Os cortes são regra do projeto, não vêm do dado |
| **Satisfação** | Nota de 1 a 5 de `order_reviews`, 1 review por pedido |
| **Nota baixa** | Nota 1 ou 2. O % de nota baixa é pedidos com nota 1 ou 2 ÷ pedidos avaliados (base: pedidos válidos com item) |
| **Faixa de atraso** | Só pedidos válidos entregues: No prazo, Até 3 dias, De 4 a 7 dias, De 8 a 14 dias e Mais de 14 dias, pelo `dias_atraso` dos pedidos com `entregue_no_prazo` = 0. "Até 3 dias" inclui os 1.291 entregues no dia prometido, depois da meia-noite. Os cortes de 3, 7 e 14 dias são escolha da análise, não vêm do dado |
| **Frete** | `freight_value`; peso do frete = frete ÷ valor dos itens |
| **Pedido perdido** | Pedido com status `canceled` ou `unavailable`. A taxa de perdidos usa como base **todos** os pedidos do período (99.092), não só os 97.905 válidos com item |
| **Forma de pagamento** | `payment_type` das linhas de `order_payments` de pedidos válidos, com valor acima de zero: cartão de crédito, boleto, voucher e cartão de débito. No painel os nomes aparecem em português (coluna calculada `Forma Pagamento PT`) |
| **Pagamento parcelado** | Pagamento de cartão de crédito com 2 ou mais parcelas. A média de parcelas e o % parcelado consideram só cartão de crédito com `payment_installments` maior que 0, contados por pagamento (e não por pedido) |
| **Faixa de horário** | Madrugada 0 a 5h, Manhã 6 a 11h, Tarde 12 a 17h e Noite 18 a 23h, pela hora da compra |
| **Região** | Região do IBGE do estado do cliente (`customer_state`): Norte (AC, AP, AM, PA, RO, RR, TO), Nordeste (AL, BA, CE, MA, PB, PE, PI, RN, SE), Centro-Oeste (DF, GO, MT, MS), Sudeste (ES, MG, RJ, SP) e Sul (PR, RS, SC) |
| **Nome da categoria** | Em português, com acento, pela tabela `categoria_ptbr` (73 categorias; chave = nome original de `products`; `sql/05_views/05a_categorias_ptbr.sql`). As 2 categorias sem tradução no dataset (`pc_gamer`, 3 produtos, e `portateis_cozinha_e_preparadores_de_alimentos`, 10 produtos) entram no mapeamento. Os 610 produtos sem categoria viram `Sem categoria` |

## 2. O que os dados não permitem responder

| Pergunta | Limite |
|---|---|
| **16. Lucro** | Não dá para responder. O dataset não tem custo dos produtos nem despesas. O painel mostra **receita**. |
| **5. Black Friday valeu a pena?** | Parcial. Dá para medir o aumento de vendas e pedidos em torno de 24/11/2017. Margem e desconto não existem no dataset. |
| **10. Vendedores "dor de cabeça"** | Dá para medir atraso, prazo de postagem e nota. Não há custo de suporte. |
| **11 e 12. Causa da lentidão e do frete alto** | Dá para mostrar onde a entrega é mais lenta e onde o frete pesa mais (estado e região). O dataset não identifica a transportadora e a distância não foi calculada: a causa é hipótese. |
| **13. Satisfação** | A nota representa só quem avaliou: 768 pedidos não têm review (todos os status). Entre os pedidos válidos com item, a base do painel, são 727 de 97.905 (0,74%). |
| **15. Perdemos muitos pedidos? Onde?** | Dá para medir quanto (1,19% dos pedidos do período) e onde (por mês e por estado do cliente). O dataset não traz o motivo do cancelamento, então o porquê é hipótese. |
| **Períodos** | Só jan/2017 a ago/2018 é completo. 2016 e set-out/2018 ficam fora. |
| **Nomes** | Clientes, vendedores e produtos aparecem só como códigos. |

## 3. Decisões do profiling

### Bloco 1: tamanho e período
- Intervalo bruto: 2016-09-04 a 2018-10-17.
- **Decisão:** analisar jan/2017 a ago/2018. Ficam fora 2016 e set/2018 em diante.
- Fato: nov/2017 é o pico (7.544 pedidos), perto da Black Friday de 24/11/2017.
- Fato: em 2018 o volume fica entre 6 e 7 mil pedidos por mês. A causa é hipótese, os dados não provam.
- Atenção: o crescimento jan-ago/2018 contra jan-ago/2017 é muito alto porque a base de 2017 é pequena. O relatório precisa dar esse contexto.

### Bloco 2: status dos pedidos
- Fato: delivered 97,02%; shipped 1,11%; canceled 0,63%; unavailable 0,61%; demais 0,63%.
- **Decisão:** pedido válido = diferente de `canceled` e `unavailable`. Exclui 1.234 pedidos (1,24%) e deixa 98.207.
- Dos válidos, 1.729 ainda não foram entregues: entram na receita, mas ficam fora de tempo de entrega e % no prazo.
- 8 pedidos `delivered` sem data de entrega: fora do cálculo de prazo e tempo.
- 2 `delivered` sem postagem: fora do despacho no prazo.
- 14 `delivered` sem aprovação: não afetam nenhuma métrica definida.
- 6 `canceled` com data de entrega: já saem pela regra de pedido válido.

### Bloco 2A: pontualidade e atraso na entrega
- Fato: a data estimada de entrega vem sem horário (00:00:00); a data de entrega ao cliente vem com horário.
- Fato: dos 96.203 pedidos válidos entregues, 88.381 chegaram até a data e hora estimadas (91,87%) e 7.822 chegaram depois.
- Fato: desses 7.822, 1.291 chegaram no próprio dia prometido, depois da meia-noite (`dias_atraso` = 0), e 6.531 chegaram 1 dia ou mais depois, com média de 10,62 dias. A média dos 7.822 é 8,86 dias.
- Fato: sem o filtro de pedido válido, as consultas retornam 96.204 entregues e 7.823 atrasados. O pedido a mais é 1 `canceled` com data de entrega.
- **Decisão (revisada em 28/10/2026):** manter a comparação por data e hora (`entregue_no_prazo`). Ela é a regra das views, das consultas 5.1 a 5.5 e das páginas já conferidas. A regra anterior (comparar só a data) foi retirada.
- **Resultado adotado no painel:** 91,87% no prazo, 7.822 atrasados e atraso médio de 8,86 dias.
- **Sensibilidade:** se a comparação fosse só por data, os 1.291 passariam a no prazo: % no prazo ≈ 93,2% ((88.381 + 1.291) ÷ 96.203), 6.531 atrasados e média de 10,62 dias. Cálculo derivado das consultas 5.1 e 5.7, não rodado como consulta própria.
- **Consistência:** a mesma regra vale para as views (`entregue_no_prazo`, `dias_atraso`), as consultas SQL, as medidas do Power BI (`% No Prazo`, `Atraso Medio`) e os textos do relatório. Se algum texto ainda citar 6.531 ou 10,62 como total de atrasos, corrigir.

### Bloco 3: duplicatas e junções
- Fato: `order_reviews` tem 99.224 linhas e 98.410 `review_id` distintos (814 linhas a mais que ids distintos).
- Fato: 547 pedidos têm mais de um review (4 com 3 reviews e 543 com 2). Os `review_id` repetidos aparecem sempre em pedidos diferentes.
- Fato: 775 pedidos sem item, dos quais 8 em status válido.
- Fato: 768 pedidos sem review (646 são `delivered`, 0,67% dos entregues).
- Fato: nos pedidos válidos com item (97.905), 727 não têm review (0,74%). O 734 que circulou antes era um teto, sem o recorte de período.
- **Decisões:**
  - 1 review por pedido nas views, com `ROW_NUMBER()`, ficando o review mais recente (`review_answer_timestamp` decrescente, com `review_creation_date` decrescente como desempate).
  - Receita e contagem de pedidos saem de `order_items`, não de `orders`.
  - Pedidos sem review ficam fora da média de nota, com ressalva na pergunta 13.

### Bloco 4: chaves e integridade
- Fato: são únicas `customers(customer_id)`, `orders(order_id)`, `sellers(seller_id)`, `products(product_id)`, `order_items(order_id, order_item_id)`, `order_payments(order_id, payment_sequential)` e `translation(product_category_name)`.
- Fato: `order_reviews.review_id` não é único; o par (`review_id`, `order_id`) é.
- Fato: zero órfãos nas 6 relações (orders→customers, order_items→orders/products/sellers, order_payments→orders, order_reviews→orders).
- **Decisões:**
  - Criar chaves primárias nas colunas acima (reviews com o par `review_id` + `order_id`).
  - Criar chaves estrangeiras nas 6 relações.
  - **Sem** chave estrangeira de `products` para a tradução (categorias sem tradução e 610 produtos sem categoria).
  - `geolocation` sem chave.
  - Ajustar o `TRUNCATE` do `02_carga.sql` ao criar as FKs (erro 1701).

### Bloco 5: geolocation e valores suspeitos
- Fato: `geolocation` tem 1.000.163 linhas para 19.015 CEPs (52,6 por CEP).
- Fato: 157 CEPs de clientes não existem em `geolocation`. Isso afeta 278 linhas de `customers` (0,28%), que correspondem a 269 clientes (`customer_unique_id`).
- Fato: preço mínimo 0,85 e máximo 6.735,00; nenhum frete negativo; 383 itens com frete zero.
- Fato: os 5 itens mais caros custam 6.735,00, 6.729,00, 6.499,00, 4.799,00 e 4.690,00, com frete entre 74,34 e 227,66. Não há um valor isolado muito acima dos outros. Se são produtos caros de verdade (por exemplo, de uma categoria específica) é hipótese: a categoria não foi conferida.
- Fato: notas só de 1 a 5, sem nulos.
- Fato: 1.359 pedidos postados antes da aprovação e 23 entregues antes da postagem. A causa é hipótese.
- Fato: pagamentos por tipo: credit_card 76.795, boleto 19.784, voucher 5.775, debit_card 1.529, not_defined 3. A tabela tem uma linha por pagamento, não por pedido.
- Fato: 9 pagamentos com valor zero: 3 `not_defined` (1 parcela) e 6 `voucher`. Os 2 pagamentos de cartão com 0 parcelas têm valor real (58,69 e 129,94, ambos o 2º pagamento do pedido).
- **Decisões:**
  - Não juntar `geolocation` direto: resumir por CEP (média de lat/lng) em view. A pergunta 7 usa estado e não depende dela.
  - Manter frete zero (frete grátis é plausível).
  - Os 23 entregues antes da postagem ficam fora das métricas postagem→entrega. O tempo compra→entrega não é afetado.
  - Manter os itens mais caros (valores plausíveis, sem salto isolado).
  - Pagamentos com valor zero (3 `not_defined` e 6 `voucher`) saem da análise de formas de pagamento.
  - Os 2 pagamentos de cartão com 0 parcelas saem só da média de parcelas; o valor deles continua somando.
  - Pergunta 14 (formas de pagamento): mostrar a **participação** de cada forma de duas maneiras: por **pedidos** (pedidos distintos que usaram aquela forma) e por **valor** (soma de `payment_value`). A participação por pedidos pode passar de 100% no total, porque um pedido pode usar mais de uma forma (por exemplo, cartão e voucher). A participação por valor soma 100%.
  - Pergunta 14 (parcelas): a média de parcelas considera só pagamentos de cartão de crédito.

### Bloco 6: nomes de categoria em português (29/10/2026)
- Fato: o inventário de `products` com a tradução tem 74 linhas: 71 categorias traduzidas, 2 sem tradução e o grupo sem categoria (610 produtos). Nenhum nome em inglês se repete.
- Fato: a tabela de tradução tem erros de digitação (`costruction_tools_garden`, `costruction_tools_tools`, `fashio_female_clothing`, `home_confort`), que apareciam no painel.
- Fato: a planilha de tradução do dataset só vai de português para inglês; o nome legível em português (ex.: "Beleza e saúde") não existe em nenhum arquivo e foi escrito à mão.
- **Decisões:**
  - Tabela `categoria_ptbr` (`sql/05_views/05a_categorias_ptbr.sql`): chave = nome original, nome em português único (`UNIQUE`). A `vw_dim_produtos` e as consultas 2.1 e 2.2 usam essa tabela; o inglês deixa de ser usado.
  - Mapeamento 1 para 1, sem fundir categorias. `eletrodomesticos_2` e `casa_conforto_2` ficam separadas ("Eletrodomésticos 2", "Casa e conforto 2"); fundi-las mudaria os totais por categoria.
  - As 5 `construcao_ferramentas_*` viram "Construção: construção", "segurança", "jardim", "iluminação" e "ferramentas", para os nomes ficarem curtos e distintos. `cool_stuff` e `la_cuisine` mantêm o nome original.
  - Produtos sem categoria: `Sem categoria`.
- Conferido: 32.951 produtos (610 sem categoria); consulta 2.1 com o mesmo top 10 de antes (R$ 8.393.781,98, 62,4% da receita); consulta 2.2 com 52 categorias com 100+ avaliações, de "Livros de interesse geral" (4,50) a "Móveis de escritório" (3,63).
- Atenção: o `05a` precisa rodar **antes** do `05_views_bi.sql` e com `SET NAMES utf8mb4`. Sem isso, o cliente `mysql` do Windows gravou os acentos com a codificação errada (`sa├║de`).

### Bloco 7: satisfação e atraso na entrega (29/10/2026)
Consultas 6.1 a 6.6 de `sql/04_analises/06_satisfacao.sql`.

- Fato: a base do painel são os pedidos válidos com pelo menos 1 item no período: 97.905 pedidos, 97.178 avaliados e 727 sem avaliação (0,74%). Nota média: 4,12.
- Fato: a consulta 6.2 não exige item (97.910 pedidos, 97.181 avaliados, 99,3% com review). A diferença são os 5 pedidos válidos sem item, 3 deles com review; a nota média é a mesma (4,12). A medida `Pedidos Avaliados` (página Produtos) dá 97.181 pelo mesmo motivo, então a página Satisfação usa `Pedidos` e `Pedidos Sem Avaliacao`, que partem dos itens.
- Fato: pedidos por nota: 1 = 10.417 (10,72%), 2 = 3.037 (3,13%), 3 = 8.028 (8,26%), 4 = 18.942 (19,49%) e 5 = 56.754 (58,40%). Notas 1 ou 2: 13.454 avaliações (13,84%).
- Fato: entre os 96.203 pedidos entregues, a nota média de quem recebeu no prazo é 4,29 (87.902 avaliados) e a de quem recebeu com atraso é 2,57 (7.658 avaliados).
- Fato: nota média por faixa de atraso (consulta 6.5):

| Faixa | Pedidos entregues | Avaliados | Nota média |
|---|---|---|---|
| No prazo | 88.381 | 87.902 | 4,29 |
| Até 3 dias | 3.160 | 3.131 | 3,59 |
| De 4 a 7 dias | 1.802 | 1.748 | 2,10 |
| De 8 a 14 dias | 1.478 | 1.446 | 1,67 |
| Mais de 14 dias | 1.382 | 1.333 | 1,72 |

- Fato: a queda mais forte da nota está entre "Até 3 dias" (3,59) e "De 4 a 7 dias" (2,10); de 8 dias em diante a nota fica perto de 1,7.
- Fato: por mês de compra a nota média vai de 3,76 (mar/18) a 4,29 (jun, jul e ago/18). Os outros vales são fev/18 (3,86) e nov/17 (3,95); de abr/18 em diante a nota volta a 4,17 a 4,29.
- Hipótese (não provada): o atraso causa a nota baixa. Os dados mostram associação, não causa. Os meses de menor nota (fev e mar/18) coincidem com a menor pontualidade (mar/18: 78,6% no prazo) e o maior tempo de entrega (fev/18: 16,9 dias), mas isso não foi testado; nov/17, outro vale, é o mês de pico de pedidos. Que a nota chegue a um piso depois de cerca de uma semana de atraso também é hipótese.
- **Decisões:**
  - A base do painel é a de pedidos válidos com item (97.905).
  - Os cortes de 3, 7 e 14 dias das faixas são escolha da análise.
  - Só pedidos entregues entram na nota por faixa; os válidos ainda não entregues (cerca de 1.700: 97.905 menos 96.203, conta derivada) ficam fora do gráfico.
  - `Faixa Atraso` e `Faixa Atraso Ordem` (colunas calculadas em `vw_fato_pedidos`) repetem os mesmos cortes: mudar um exige mudar o outro.
  - A nota mensal usa o mês da compra, a mesma data da receita.
- Limite: a nota representa só quem avaliou (727 pedidos sem avaliação).

### Bloco 8: pagamentos e pedidos perdidos (30/10/2026)
Consultas 7.1 a 7.6 de `sql/04_analises/07_pagamentos_pedidos.sql`. As consultas 7.1, 7.2 e 7.6 usam a base de `vw_fato_pagamentos` (pedidos válidos, no período, com valor acima de zero); as 7.3 a 7.5 usam todos os pedidos do período.

- Fato: participação por forma de pagamento (7.1):

| Forma | Pedidos | % dos pedidos | Valor (R$) | % do valor |
|---|---|---|---|---|
| Cartão de crédito | 75.390 | 77,0 | 12.308.514,90 | 78,5 |
| Boleto | 19.479 | 19,9 | 2.817.575,39 | 18,0 |
| Voucher | 3.734 | 3,8 | 348.890,86 | 2,2 |
| Cartão de débito | 1.513 | 1,5 | 212.176,02 | 1,4 |

- Fato: por pedidos a soma dá 102,2%, porque um pedido pode usar mais de uma forma; por valor soma 100% (R$ 15.687.157,17 no total).
- Fato: a soma dos pagamentos (R$ 15,69 Mi) é maior que a receita sem frete (R$ 13,45 Mi), e as duas não devem ser comparadas. Hipótese: a diferença é principalmente o frete; com o frete em 16,6% do valor dos itens (cerca de R$ 2,2 Mi), 13,45 mais 2,2 dá cerca de 15,7 Mi. Conta aproximada, não rodada como consulta.
- Fato: parcelas (7.2 e 7.6): 75.674 pagamentos de cartão com parcelas acima de zero; 33,2% à vista (25.092) e 66,8% em 2 ou mais parcelas (50.582); média de 3,50 parcelas por pagamento. 99,6% têm até 10 parcelas (336 pagamentos têm 11 ou mais); aparecem 23 valores de parcelas (não existe 19). Há picos em 8 (5,6%) e 10 parcelas (6,9%), acima de 7 (2,1%) e 9 (0,8%). Hipótese: planos fixos de parcelamento; os dados não dizem o motivo.
- Fato: status no período (7.3): 99.092 pedidos; delivered 96.211 (97,09%), shipped 1.097, unavailable 602, canceled 580, processing 299, invoiced 296, created 5 e approved 2. Perdidos = 602 + 580 = 1.182 (1,19%). O 1.234 (1,24%) do Bloco 2 é do dataset inteiro, de 2016 a 2018.
- Fato: por mês (7.4), a taxa vai de 0,29% (abr/18) a 3,48% (fev/17, com 62 perdidos em 1.780 pedidos). O 1,40% de ago/18 vem de 84 cancelados (7 indisponíveis). Derivado da 7.4, sem consulta própria: em 2017 foram 722 perdidos em 45.101 pedidos (1,60%) e em jan a ago/18, 460 em 53.991 (0,85%); os indisponíveis somam 457 em 2017 e 145 em 2018, e os cancelados, 265 e 315. A causa é hipótese.
- Fato: por estado do cliente (7.5, mínimo de 100 pedidos), 24 estados, de 0,44% (MT) a 2,77% (RO). RO tem só 7 pedidos perdidos em 253, então a taxa é instável. MA tem 1,48% e SP e SE, 1,44%. SP, com 41.621 pedidos, tem cerca de 600 perdidos, mais ou menos metade do total (conta derivada). Entre os estados com base grande, nenhum se destaca.
- **Decisões:**
  - A base da taxa de perdidos são todos os pedidos do período (99.092).
  - O mínimo de 100 pedidos por estado copia o `HAVING COUNT(*) >= 100` da 7.5 (medida `% Perdidos 100+`).
  - Os estados abaixo do corte ficam fora: pelas somas da 7.5 (98.899 pedidos nos 24 estados), restam 193 pedidos em 3 estados, a confirmar com consulta (ver seção 4).
  - A linha de referência do gráfico de estados é a taxa do período todo (1,19%, medida `% Perdidos Geral`), não a média simples dos estados.
  - A média de parcelas é por pagamento, só cartão, sem os de 0 parcelas.
  - Os nomes das formas em português vêm de uma coluna calculada no Power BI (`Forma Pagamento PT`); as medidas usam o `forma_pagamento` original.
- Limites: o dataset não traz o motivo do cancelamento, e "onde" significa mês e estado. Há 1 pedido sem pagamento (conferência do `sql/02c_testes.sql`), cujo status não foi conferido; ele não entra nas formas de pagamento.

## 4. Decisões em aberto

Nenhuma decisão em aberto. Conferências pequenas pendentes:

1. Confirmar que os pedidos do período vêm de 27 estados (a página Pagamentos e pedidos fala em 3 estados abaixo do corte de 100 pedidos): `SELECT COUNT(DISTINCT c.customer_state)` sobre `orders` e `customers`, com o recorte do período.
2. Conferir o status do 1 pedido sem pagamento.

Novas dúvidas entram aqui e viram decisão na seção 3.
