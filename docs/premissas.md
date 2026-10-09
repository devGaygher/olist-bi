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
| **Entrega no prazo** | `order_delivered_customer_date` ≤ `order_estimated_delivery_date` |
| **Tempo de entrega** | Dias entre a compra e a entrega ao cliente, só pedidos entregues |
| **Vendedor que despacha no prazo** | Postagem até a data limite de envio (`shipping_limit_date`) |
| **Satisfação** | Nota de 1 a 5 de `order_reviews`, 1 review por pedido |
| **Frete** | `freight_value`; peso do frete = frete ÷ valor dos itens |
| **Categoria sem tradução** | `pc_gamer` (3 produtos) e `portateis_cozinha_e_preparadores_de_alimentos` (10 produtos) não têm tradução. Nas views usar `COALESCE(inglês, português)` |

## 2. O que os dados não permitem responder

| Pergunta | Limite |
|---|---|
| **16. Lucro** | Não dá para responder. O dataset não tem custo dos produtos nem despesas. O painel mostra **receita**. |
| **5. Black Friday valeu a pena?** | Parcial. Dá para medir o aumento de vendas e pedidos em torno de 24/11/2017. Margem e desconto não existem no dataset. |
| **10. Vendedores "dor de cabeça"** | Dá para medir atraso, prazo de postagem e nota. Não há custo de suporte. |
| **13. Satisfação** | A nota representa só quem avaliou: 768 pedidos não têm review. |
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

### Bloco 3: duplicatas e junções
- Fato: `order_reviews` tem 99.224 linhas e 98.410 `review_id` distintos (814 repetidos).
- Fato: há pedidos com mais de um review (4 com 3 reviews, o resto com 2). A contagem exata ainda não foi rodada.
- Fato: 775 pedidos sem item, dos quais 8 em status válido.
- Fato: 768 pedidos sem review (646 são `delivered`, 0,67% dos entregues).
- **Decisões:**
  - 1 review por pedido nas views, com `ROW_NUMBER()` (critério a definir, por exemplo o mais recente).
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
- Fato: 157 CEPs de clientes não existem em `geolocation`. Quantos clientes isso afeta ainda não foi medido.
- Fato: preço mínimo 0,85 e máximo 6.735,00; nenhum frete negativo; 383 itens com frete zero.
- Fato: notas só de 1 a 5, sem nulos.
- Fato: 1.359 pedidos postados antes da aprovação e 23 entregues antes da postagem. A causa é hipótese.
- Fato: pagamentos por tipo: credit_card 76.795, boleto 19.784, voucher 5.775, debit_card 1.529, not_defined 3. A tabela tem uma linha por pagamento, não por pedido.
- **Decisões:**
  - Não juntar `geolocation` direto: resumir por CEP (média de lat/lng) em view. A pergunta 7 usa estado e não depende dela.
  - Manter frete zero (frete grátis é plausível).
  - Os 23 entregues antes da postagem ficam fora das métricas postagem→entrega. O tempo compra→entrega não é afetado.
  - Os 3 `not_defined` saem da análise de formas de pagamento.
  - Os 2 pagamentos de cartão com 0 parcelas saem da média de parcelas.
  - **Em aberto:** definir se a pergunta 14 conta pagamentos, pedidos ou valor.

## 4. Pendências de validação

Consultas de inspeção ainda não rodadas: 5.2b (5 itens mais caros), 5.1d (quantos clientes sem coordenada), 5.5b (pagamentos com valor zero ou 0 parcelas) e a contagem exata de pedidos com mais de um review (3.2).
