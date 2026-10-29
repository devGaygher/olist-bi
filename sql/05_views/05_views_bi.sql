-- 05_views_bi.sql
-- camada de views para o Power BI - etapa 9
-- regras (doc premissas.md) :
-- * recorte: 01 jan 2017 <= compra < 01 set 2018
-- * pedido valido: status fora de 'canceled' e 'unavailable'
-- * 1 review por pedido (mais recente)
-- * pagamentos de valor zero ficam fora
-- * requer categoria_ptbr: rodar 05a_categorias_ptbr.sql ANTES deste script
-- script reexecutavel (create or replace view)

USE olist;
-- ===========================================
-- Tabelas Dimensões
-- ===========================================

-- 3 dim (produtos, cliente, vendedor)


-- grão: 1 linha por customer_id
-- customer_unique_id identifica a pessoa e serve para contar clientes e recompra.

CREATE OR REPLACE VIEW vw_dim_cliente AS
    SELECT 
        customer_id,
        customer_unique_id,
        customer_city AS cidade,
        customer_state AS estado
    FROM customers;

-- grão: 1 linha por vendedor

CREATE OR REPLACE VIEW vw_dim_vendedor AS
    SELECT 
        seller_id,
        seller_city AS cidade,
        seller_state AS estado
    FROM sellers;

-- grão: 1 linha por produto, com categoria traduzida
-- mesma regra da consulta: tradução, senão nome original, senão 'sem_categoria'

CREATE OR REPLACE VIEW vw_dim_produtos AS
    SELECT
        p.product_id,
        COALESCE(c.categoria, 'sem_categoria') AS categoria
    FROM products p
    LEFT JOIN product_category_name_translation t
        ON c.product_category_name = p.product_category_name;

-- calendario: criado no POWER BI a partir de data_compra

-- ===========================================
-- Tabela Fato
-- ===========================================

-- 3 fato (pedidos, itens, pagamentos)
-- pedidos é o cabeçalho: itens e pagamentos se ligam a ele por order_id


-- grão: 1 linha por pedido (todos do período, inclusive cancelados)
-- as consultas 7.3 a 7.5 precisam dos cancelados, por isso a flag pedido_valido
-- dias_ate_entrega, entregue_no_prazo e nota_review só existem para pedido valido
-- (NULL nos demais: a média do power bi ignora sozinha)

CREATE OR REPLACE VIEW vw_fato_pedidos AS
    WITH review_unica AS (
        SELECT order_id, review_score
        FROM (
            SELECT order_id, review_score,
                ROW_NUMBER() OVER (PARTITION BY order_id
                    ORDER BY review_answer_timestamp DESC, review_creation_date DESC) AS rn
            FROM order_reviews
        ) x
        WHERE rn = 1
    )
    SELECT
        o.order_id,
        o.customer_id,
        o.order_purchase_timestamp AS data_hora_compra,
        DATE(o.order_purchase_timestamp) AS data_compra,
        o.order_status AS status_pedido,
        CASE WHEN o.order_status IN ('canceled', 'unavailable') THEN 0 ELSE 1 END AS pedido_valido,
        o.order_estimated_delivery_date AS data_entrega_estimada,
        o.order_delivered_customer_date AS data_entrega_real,
        CASE WHEN o.order_status NOT IN ('canceled', 'unavailable')
              AND o.order_delivered_customer_date IS NOT NULL
             THEN DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)
        END AS dias_ate_entrega,
        -- 1 = no prazo, 0 = atrasado
        CASE WHEN o.order_status NOT IN ('canceled', 'unavailable')
              AND o.order_delivered_customer_date IS NOT NULL
             THEN (o.order_delivered_customer_date <= o.order_estimated_delivery_date)
        END AS entregue_no_prazo,
	CASE WHEN o.order_status NOT IN ('canceled', 'unavailable')
              AND o.order_delivered_customer_date IS NOT NULL
             THEN DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date)
        END AS dias_atraso,
        CASE WHEN o.order_status NOT IN ('canceled', 'unavailable')
             THEN r.review_score
        END AS nota_review
    FROM orders o
    LEFT JOIN review_unica r
        ON r.order_id = o.order_id
    WHERE o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01';

-- grão: 1 linha por item de pedido (só pedido valido do período)
-- receita = SUM(preco), o frete fica separado (igual as consultas da etapa 8)

CREATE OR REPLACE VIEW vw_fato_itens AS
    SELECT
        oi.order_id,
        oi.order_item_id,
        oi.product_id,
        oi.seller_id,
        oi.price AS preco,
        oi.freight_value AS frete,
        oi.shipping_limit_date AS data_limite_postagem,
        o.order_delivered_carrier_date AS data_postagem
    FROM order_items oi
    JOIN orders o
        ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01';

-- grão: 1 linha por pagamento (pedido valido do período, sem valor zero)
-- um pedido pode ter varios pagamentos: nunca juntar com itens na mesma tabela

CREATE OR REPLACE VIEW vw_fato_pagamentos AS
    SELECT
        p.order_id,
        p.payment_sequential AS sequencia,
        p.payment_type AS forma_pagamento,
        p.payment_installments AS parcelas,
        p.payment_value AS valor
    FROM order_payments p
    JOIN orders o
        ON o.order_id = p.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
      AND p.payment_value > 0;

-- ===========================================
-- Conferências
-- ===========================================

-- rodar depois de criar as views
-- cada resultado tem que bater com a consulta da etapa 8 indicada


-- grão: nas dimensões, linhas = linhas da tabela de origem
-- customers 99.441 | sellers 3.095 | products 32.951

SELECT
    (SELECT COUNT(*) FROM vw_dim_cliente) AS clientes,
    (SELECT COUNT(*) FROM vw_dim_vendedor) AS vendedores,
    (SELECT COUNT(*) FROM vw_dim_produtos) AS produtos;

-- grão: em pedidos, linhas = pedidos distintos (se for maior, algum join multiplicou)

SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT order_id) AS pedidos
FROM vw_fato_pedidos;

-- bate com 01_vendas.sql, 1.2 (total de pedidos e receita do período)

SELECT
    COUNT(DISTINCT order_id) AS total_pedidos,
    SUM(preco) AS receita
FROM vw_fato_itens;

-- bate com 07_pagamentos_pedidos.sql, 7.3 (total do período e válidos)

SELECT
    COUNT(*) AS pedidos_periodo,
    SUM(pedido_valido) AS pedidos_validos
FROM vw_fato_pedidos;

-- bate com 06_satisfacao.sql, 6.2 (nota média geral)

SELECT
    ROUND(AVG(nota_review), 2) AS nota_media,
    COUNT(nota_review) AS pedidos_com_review
FROM vw_fato_pedidos;

-- bate com 05_logistica.sql, 5.1 (entregues, % no prazo, dias até a entrega)

SELECT
    COUNT(dias_ate_entrega) AS pedidos_entregues,
    ROUND(100 * AVG(entregue_no_prazo), 1) AS pct_no_prazo,
    ROUND(AVG(dias_ate_entrega), 1) AS dias_ate_entrega
FROM vw_fato_pedidos;

-- bate com 07_pagamentos_pedidos.sql, 7.1 (valor por forma de pagamento)

SELECT
    forma_pagamento,
    COUNT(DISTINCT order_id) AS pedidos,
    ROUND(SUM(valor), 2) AS valor
FROM vw_fato_pagamentos
GROUP BY forma_pagamento
ORDER BY valor DESC;

-- integridade: itens e pagamentos sem pedido correspondente (tem que dar 0)

SELECT
    (SELECT COUNT(*)
     FROM vw_fato_itens i
     LEFT JOIN vw_fato_pedidos p ON p.order_id = i.order_id
     WHERE p.order_id IS NULL) AS itens_sem_pedido,
    (SELECT COUNT(*)
     FROM vw_fato_pagamentos g
     LEFT JOIN vw_fato_pedidos p ON p.order_id = g.order_id
     WHERE p.order_id IS NULL) AS pagamentos_sem_pedido;

-- categorias em português: 32.951 produtos, 74 categorias (73 + 'Sem categoria'), 610 sem categoria
SELECT
    COUNT(*) AS produtos,
    COUNT(DISTINCT categoria) AS categorias,
    SUM(categoria = 'Sem categoria') AS sem_categoria
FROM vw_dim_produtos;

