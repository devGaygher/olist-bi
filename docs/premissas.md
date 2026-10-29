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
| **Frete** | `freight_value`; peso do frete = frete ÷ valor dos itens |
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

## 4. Decisões em aberto

Nenhuma no momento.

Novas dúvidas entram aqui e viram decisão na seção 3.
