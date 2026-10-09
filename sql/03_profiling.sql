-- 03_profiling.sql
-- Objetivo: conhecer a qualidade dos dados da camada raw antes das análises.
-- Cada bloco responde uma pergunta e gera uma decisão (registrada em docs/premissas.md).
-- Rodar da raiz do projeto:
-- & $mysql -u root -p -D olist -t -e "source sql/03_profiling.sql"

-- ============================================================
-- BLOCO 1: Tamanho e intervalo de datas
-- ============================================================

-- 1.1 Quantas linhas tem cada tabela? (deve bater com a carga validada)

SELECT 'customers' AS tabela, count(*) AS linhas FROM customers
UNION ALL
SELECT 'sellers' AS tabela, count(*) AS linhas FROM sellers
UNION ALL
SELECT 'geolocation' AS tabela, count(*) AS linhas FROM geolocation
UNION ALL
SELECT 'orders' AS tabela, count(*) AS linhas FROM orders
UNION ALL
SELECT 'order_items' AS tabela, count(*) AS linhas FROM order_items
UNION ALL
SELECT 'order_payments' AS tabela, count(*) AS linhas FROM order_payments
UNION ALL
SELECT 'order_reviews' AS tabela, count(*) AS linhas FROM order_reviews
UNION ALL
SELECT 'products' AS tabela, count(*) AS linhas FROM products
UNION ALL
SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation;

-- 1.2 Qual o período real dos dados? (confirma o recorte jan/2017 a ago/2018)

SELECT
    MIN(order_purchase_timestamp) AS primeira_compra,
    MAX(order_purchase_timestamp) AS ultima_compra
FROM orders;

-- 1.3 Quantos pedidos por mês? (mostra quais meses são completos e quais são parciais)
SELECT
    DATE_FORMAT(order_purchase_timestamp,'%Y-%m' ) AS mes,
    COUNT(*) AS pedidos
FROM orders
GROUP BY DATE_FORMAT(order_purchase_timestamp, '%Y-%m')
ORDER BY mes;

-- DECISÃO DO BLOCO 1:
-- Período de análise: jan/2017 a ago/2018 (20 meses completos).
-- Fora: 2016 (4, 324 e 1 pedidos, sem série contínua) e set/2018 em diante
-- (16 e 4 pedidos, mês incompleto). Registrar em docs/premissas.md.

-- ============================================================
-- BLOCO 2: Status dos pedidos
-- ============================================================
-- 2.1 Quantos pedidos há em cada status e qual o peso de cada um?
SELECT
    order_status,
    COUNT(*) AS pedidos,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM orders), 2) as percent
FROM orders
GROUP BY order_status
ORDER BY pedidos DESC;

-- 2.2 Os campos vazios fazem sentido para cada status?

SELECT
    order_status,
    COUNT(*) AS pedidos,
    SUM(order_approved_at IS NULL) AS sem_aprovacao,
    SUM(order_delivered_carrier_date IS NULL) AS sem_postagem,
    SUM(order_delivered_customer_date IS NULL) AS sem_entrega
FROM orders
GROUP BY order_status
ORDER BY pedidos DESC;

-- 2.3 Existem pedidos marcados como entregues sem a data em que chegaram?
SELECT
    order_status,
    COUNT(*) AS pedidos,
    SUM(order_delivered_customer_date IS NULL) AS sem_data
FROM orders
WHERE order_status = 'delivered'
GROUP BY order_status;

-- DECISÃO DO BLOCO 2:
-- Pedido válido = status diferente de canceled e unavailable (exclui 1.234 pedidos, 1,24%).
-- Dos 98.207 válidos, 1.729 ainda não foram entregues (shipped, invoiced, processing,
-- created, approved): entram na receita, mas ficam fora de tempo de entrega e % no prazo.
-- 8 delivered sem data de entrega: fora do cálculo de prazo e tempo de entrega.
-- 2 delivered sem data de postagem: fora do cálculo de despacho no prazo.
-- 14 delivered sem aprovação: não afetam nenhuma métrica definida.
-- 6 canceled com data de entrega: já ficam fora pela regra de pedido válido.
-- Registrar em docs/premissas.md.

-- ============================================================
-- BLOCO 3: Duplicatas e integridade entre tabelas
-- ============================================================
-- 3.1 Existem review_id repetidos?
SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT review_id) AS review_ids_distintos,
    COUNT(*) - COUNT(DISTINCT review_id) AS linhas_a_mais
FROM order_reviews;

-- 3.1b Os review_id repetidos aparecem em pedidos diferentes?
SELECT
    review_id,
    COUNT(*) AS vezes,
    COUNT(DISTINCT order_id) AS pedidos_distintos
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1
ORDER BY vezes DESC
LIMIT 10;

-- 3.2 Quantos pedidos têm mais de um review?
SELECT COUNT(*) AS pedidos_com_mais_de_um_review
FROM (
    SELECT order_id
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) AS t;

-- 3.2b Lista de exemplo dos pedidos com mais de um review
SELECT order_id, COUNT(*) AS reviews
FROM order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY reviews DESC
LIMIT 10;

-- 3.3 Pedidos sem nenhum item
SELECT
    o.order_status,
    COUNT(*) AS pedidos_sem_item
FROM orders o
LEFT JOIN order_items oi
    ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY pedidos_sem_item DESC;

-- para isnpecionar quais sao os pedidos sem item
-- SELECT o.order_id, o.order_status
-- FROM orders o
-- LEFT JOIN order_items oi
--    ON oi.order_id = o.order_id
-- WHERE oi.order_id IS NULL;

-- 3.4 Pedidos sem review
SELECT
    o.order_status,
    COUNT(*) AS pedidos_sem_reviews
FROM orders o
LEFT JOIN order_reviews ore
    ON o.order_id = ore.order_id
WHERE ore.order_id IS NULL
GROUP BY o.order_status
ORDER BY pedidos_sem_reviews DESC;

-- DECISÃO DO BLOCO 3:
-- order_reviews: review_id não é único (814 linhas repetidas) e há pedidos com mais de
-- um review (4 com 3 reviews, o restante com 2). Nas views, usar 1 review por pedido
-- (critério a definir, ex.: o mais recente) com ROW_NUMBER().
-- 775 pedidos sem item (603 unavailable, 164 canceled, 8 em status válidos): receita e
-- contagem de pedidos saem de order_items, não de orders.
-- 768 pedidos sem review (646 delivered, 0,67%): fora da média de nota; ressalva na
-- pergunta 13. Registrar em docs/premissas.md.

-- ============================================================
-- BLOCO 4: Chaves e integridade entre tabelas
-- ============================================================

-- 4.1 A coluna que deveria ser chave é única? (linhas = distintos significa que sim)
SELECT 'customers.customer_id' AS chave, COUNT(*) AS linhas, COUNT(DISTINCT customer_id) AS distintos FROM customers
UNION ALL
SELECT 'orders.order_id' AS chave, COUNT(*), COUNT(DISTINCT order_id) AS distintos FROM orders
UNION ALL
SELECT 'sellers.seller_id' AS chave, COUNT(*), COUNT(DISTINCT seller_id) AS distintos FROM sellers
UNION ALL
SELECT 'products.product_id' AS chave, COUNT(*), COUNT(DISTINCT product_id) AS distintos FROM products
UNION ALL
SELECT 'order_items.(order_id,order_item_id)' AS chave, COUNT(*), COUNT(DISTINCT order_id,order_item_id) AS distintos FROM order_items
UNION ALL
SELECT 'order_payments (order_id, payment_sequential)', COUNT(*), COUNT(DISTINCT order_id, payment_sequential) FROM order_payments
UNION ALL
SELECT 'order_reviews.review_id', COUNT(*), COUNT(DISTINCT review_id) FROM order_reviews
UNION ALL
SELECT 'order_reviews (review_id, order_id)', COUNT(*), COUNT(DISTINCT review_id, order_id) FROM order_reviews
UNION ALL
SELECT 'translation.product_category_name', COUNT(*), COUNT(DISTINCT product_category_name) FROM product_category_name_translation;

-- 4.2 Existe registro filho apontando para um pai que não existe?

SELECT 'orders -> customers' AS relacao, COUNT(*) AS orfaos
FROM orders o
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'order_items -> orders', COUNT(*)
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_items -> products', COUNT(*)
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'order_items -> sellers', COUNT(*)
FROM order_items oi
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL
UNION ALL
SELECT 'order_payments -> orders', COUNT(*)
FROM order_payments op
LEFT JOIN orders o ON op.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_reviews -> orders', COUNT(*)
FROM order_reviews r
LEFT JOIN orders o ON o.order_id = r.order_id
WHERE o.order_id IS NULL;

-- DECISÃO DO BLOCO 4:
-- Chaves primárias possíveis: customers(customer_id), orders(order_id), sellers(seller_id),
-- products(product_id), order_items(order_id, order_item_id),
-- order_payments(order_id, payment_sequential), order_reviews(review_id, order_id),
-- product_category_name_translation(product_category_name).
-- review_id sozinho NÃO é único em order_reviews (814 repetidos, ligados a pedidos diferentes).
-- Zero órfãos nas 6 relações filho -> pai: as chaves estrangeiras podem ser criadas.
-- Sem chave estrangeira em products -> translation (categorias sem tradução e produtos sem categoria).
-- geolocation: sem chave (verificar duplicatas no próximo bloco).
-- Ao criar as chaves estrangeiras, ajustar o TRUNCATE do 02_carga.sql (erro 1701).

-- ============================================================
-- BLOCO 5: Geolocalização e valores suspeitos
-- ============================================================

-- 5.1 Quantas linhas de geolocation existem por CEP?
SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS ceps_distintos,
    ROUND(COUNT(*) / COUNT(DISTINCT geolocation_zip_code_prefix), 1) AS linhas_por_cep
FROM geolocation;

-- 5.1b Quais CEPs têm mais linhas?
SELECT
    geolocation_zip_code_prefix AS cep,
    COUNT(*) AS linhas
FROM geolocation
GROUP BY geolocation_zip_code_prefix
ORDER BY linhas DESC
LIMIT 5;

-- 5.1c Quantos CEPs de clientes não existem em geolocation?
-- (a subconsulta com DISTINCT evita que o JOIN multiplique as linhas)
SELECT
    COUNT(DISTINCT c.customer_zip_code_prefix) AS cep_clientes_sem_geoloc
FROM customers c
LEFT JOIN (
    SELECT DISTINCT geolocation_zip_code_prefix
    FROM geolocation
) g ON g.geolocation_zip_code_prefix = c.customer_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;

-- 5.1d Quantos clientes ficam sem coordenada?
SELECT
    COUNT(*) AS linhas_customers,
    COUNT(DISTINCT c.customer_unique_id) AS pessoas
FROM customers c
LEFT JOIN (
    SELECT DISTINCT geolocation_zip_code_prefix
    FROM geolocation
) g ON g.geolocation_zip_code_prefix = c.customer_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;

-- 5.2 Preço e frete têm valores impossíveis?
SELECT
    COUNT(*) AS itens,
    SUM(price <= 0) AS preco_zero_ou_negativo,
    MIN(price) AS preco_min,
    MAX(price) AS preco_max,
    SUM(freight_value < 0) AS frete_negativo,
    SUM(freight_value = 0) AS frete_zero,
    MAX(freight_value) AS frete_max
FROM order_items;

-- 5.2b Quais são os 5 itens mais caros?
SELECT order_id, product_id, seller_id, price, freight_value
FROM order_items
ORDER BY price DESC
LIMIT 5;

-- 5.3 Qual a distribuição das notas? Existe nota fora de 1 a 5 ou nula?
SELECT
    review_score,
    COUNT(*)  AS reviews
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;

-- 5.4 Existem datas fora de ordem lógica dentro do mesmo pedido?
SELECT
    SUM(order_approved_at < order_purchase_timestamp) AS aprovado_antes_da_compra,
    SUM(order_delivered_carrier_date < order_approved_at) AS postado_antes_da_aprovacao,
    SUM(order_delivered_customer_date < order_delivered_carrier_date) AS entregue_antes_da_postagem,
    SUM(order_delivered_customer_date < order_purchase_timestamp) AS entregue_antes_da_compra
FROM orders;

-- 5.5 Os tipos de pagamento e as parcelas fazem sentido?
SELECT
    payment_type,
    COUNT(*) AS pagamentos,
    SUM(payment_value <= 0) AS valor_zero_ou_negativo,
    SUM(payment_installments = 0) AS parcelas_zero,
    MAX(payment_installments) AS max_parcelas
FROM order_payments
GROUP BY payment_type
ORDER BY pagamentos DESC;

-- 5.5b Quais pagamentos têm valor zero ou 0 parcelas?
SELECT order_id, payment_sequential, payment_type, payment_installments, payment_value
FROM order_payments
WHERE payment_value <= 0 OR payment_installments = 0
ORDER BY payment_type;

-- DECISÃO DO BLOCO 5:
-- geolocation: 1.000.163 linhas para 19.015 CEPs (52,6 por CEP). Não juntar direto:
-- resumir por CEP (média de latitude e longitude) em view. 157 CEPs de clientes sem
-- geolocalização. A pergunta 7 (origem dos clientes) usa estado, que não depende dela.
-- Preço e frete: sem preço <= 0 nem frete negativo. 383 itens com frete zero: mantidos
-- (frete grátis é plausível). Preço máximo 6.735,00: conferir (5.2b) antes de médias.
-- Notas: apenas 1 a 5, sem nulos.
-- Datas: 1.359 pedidos postados antes da aprovação e 23 entregues antes da postagem;
-- nenhum aprovado ou entregue antes da compra. Tempo de entrega (compra -> entrega) não
-- é afetado; os 23 ficam fora de qualquer métrica de postagem -> entrega.
-- Pagamentos: 3 not_defined (valor zero) fora da análise de formas de pagamento; 2 de
-- cartão com 0 parcelas fora da média de parcelas. Definir se a pergunta 14 conta
-- pagamentos, pedidos ou valor.
-- Registrar em docs/premissas.md.