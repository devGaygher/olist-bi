-- 02c_testes.sql
-- Projeto Olist BI: testes das chaves primárias e estrangeiras (etapa 7)
-- Rodar depois de 02b_chaves.sql, da raiz do projeto:
--   & $mysql -u root -p -D olist -e "source sql/02c_testes.sql"
--
-- Este script NÃO altera os dados:
--   * os testes 1, 2 e 4 só leem;
--   * o teste 3 escreve dentro de transação e termina com ROLLBACK,
--     usando tabelas temporárias como molde.
-- Pode ser rodado quantas vezes quiser.

USE olist;


-- =====================================================================
-- TESTE 1: EXISTÊNCIA
-- Pergunta: as chaves foram criadas?
-- Esperado: 8 tabelas com PK e 6 FKs, todas com status OK.
-- =====================================================================

SELECT 'chaves primarias' AS item,
    COUNT(DISTINCT table_name) AS encontrado,
    8 AS esperado,
    IF(COUNT(DISTINCT table_name) = 8, 'OK', 'FALHA') as status
FROM information_schema.key_column_usage
WHERE table_schema = 'olist'
    AND constraint_name = 'PRIMARY'
UNION ALL
SELECT 'chaves estrangeiras',
       COUNT(DISTINCT constraint_name),
       6,
       IF(COUNT(DISTINCT constraint_name) = 6, 'OK', 'FALHA')
FROM information_schema.key_column_usage
WHERE table_schema = 'olist'
  AND referenced_table_name IS NOT NULL;

-- =====================================================================
-- TESTE 2: INTEGRIDADE DOS DADOS QUE JÁ ESTÃO NO BANCO
-- Pergunta: existe linha filha apontando para um pai que não existe?
-- Esperado: 0 órfãos em todas as 6 relações.
-- Técnica: LEFT JOIN + IS NULL na chave do lado direito (o pai).
-- Fiz algo parecido no schema/carga entao o resultado temq  ser o mesmo
-- =====================================================================

SELECT 'orders -> customers' AS relacao, COUNT(*) AS orfaos
FROM orders o
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'order_items -> orders', COUNT(*)
FROM order_items i
LEFT JOIN orders o ON o.order_id = i.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_items -> products', COUNT(*)
FROM order_items i
LEFT JOIN products p ON p.product_id = i.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'order_items -> sellers', COUNT(*)
FROM order_items i
LEFT JOIN sellers s ON s.seller_id = i.seller_id
WHERE s.seller_id IS NULL
UNION ALL
SELECT 'order_payments -> orders', COUNT(*)
FROM order_payments p
LEFT JOIN orders o ON o.order_id = p.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_reviews -> orders', COUNT(*)
FROM order_reviews r
LEFT JOIN orders o ON o.order_id = r.order_id
WHERE o.order_id IS NULL;

-- =====================================================================
-- TESTE 3: APLICAÇÃO
-- Pergunta: o banco realmente BARRA o órfão e a duplicata?
-- Como: para cada chave, copia uma linha real para uma tabela temporária
--       (molde), estraga só a coluna que está sendo testada e tenta inserir
--       na tabela de verdade. Usar uma linha real evita o erro 1364
--       (coluna obrigatória sem valor), que invalidou o teste anterior.
-- Esperado:
--   as 6 FKs   -> erro 1452 (violação de chave estrangeira)
--   a PK       -> erro 1062 (entrada duplicada)
-- Se algum erro for diferente, o teste marca FALHA: ele só vale quando
-- falha pelo motivo certo.
-- O ROLLBACK desfaz a linha de teste caso ela tenha entrado por engano.
-- O handler captura o erro para o script continuar e montar o relatório.
-- =====================================================================

DROP PROCEDURE IF EXISTS teste_chaves;
 
DELIMITER //
 
CREATE PROCEDURE teste_chaves()
BEGIN
  DECLARE v_1452  INT DEFAULT 0;   -- 1 se o MySQL devolveu erro 1452
  DECLARE v_1062  INT DEFAULT 0;   -- 1 se o MySQL devolveu erro 1062
  DECLARE v_outro INT DEFAULT 0;   -- 1 se devolveu qualquer outro erro
 
  DECLARE CONTINUE HANDLER FOR 1452 SET v_1452 = 1;
  DECLARE CONTINUE HANDLER FOR 1062 SET v_1062 = 1;
  DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_outro = 1;
 
  DROP TEMPORARY TABLE IF EXISTS resultado_chaves;
  CREATE TEMPORARY TABLE resultado_chaves (
    chave    VARCHAR(30),
    esperado VARCHAR(30),
    status   VARCHAR(40)
  );

-- 3.1 fk_items_orders: item apontando para pedido inexistente
  DROP TEMPORARY TABLE IF EXISTS molde;
  CREATE TEMPORARY TABLE molde LIKE order_items;
  INSERT INTO molde SELECT * FROM order_items LIMIT 1;
  UPDATE molde SET order_id = 'pedido_orfao';
  SET v_1452 = 0, v_1062 = 0, v_outro = 0;
  START TRANSACTION;
  INSERT INTO order_items SELECT * FROM molde;
  ROLLBACK;
  INSERT INTO resultado_chaves VALUES ('fk_items_orders', 'erro 1452',
    IF(v_1452 = 1, 'OK', IF(v_outro = 1, 'FALHA: outro erro', 'FALHA: aceitou o órfão')));
    
  -- 3.2 fk_items_products: item apontando para produto inexistente
  DROP TEMPORARY TABLE IF EXISTS molde;
  CREATE TEMPORARY TABLE molde LIKE order_items;
  INSERT INTO molde SELECT * FROM order_items LIMIT 1;
  UPDATE molde SET product_id = 'produto_orfao', order_item_id = 999;
  SET v_1452 = 0, v_1062 = 0, v_outro = 0;
  START TRANSACTION;
  INSERT INTO order_items SELECT * FROM molde;
  ROLLBACK;
  INSERT INTO resultado_chaves VALUES ('fk_items_products', 'erro 1452',
    IF(v_1452 = 1, 'OK', IF(v_outro = 1, 'FALHA: outro erro', 'FALHA: aceitou o órfão')));
 
  -- 3.3 fk_items_sellers: item apontando para vendedor inexistente
  DROP TEMPORARY TABLE IF EXISTS molde;
  CREATE TEMPORARY TABLE molde LIKE order_items;
  INSERT INTO molde SELECT * FROM order_items LIMIT 1;
  UPDATE molde SET seller_id = 'vendedor_orfao', order_item_id = 999;
  SET v_1452 = 0, v_1062 = 0, v_outro = 0;
  START TRANSACTION;
  INSERT INTO order_items SELECT * FROM molde;
  ROLLBACK;
  INSERT INTO resultado_chaves VALUES ('fk_items_sellers', 'erro 1452',
    IF(v_1452 = 1, 'OK', IF(v_outro = 1, 'FALHA: outro erro', 'FALHA: aceitou o órfão')));
 
  -- 3.4 fk_orders_customers: pedido apontando para cliente inexistente
  DROP TEMPORARY TABLE IF EXISTS molde;
  CREATE TEMPORARY TABLE molde LIKE orders;
  INSERT INTO molde SELECT * FROM orders LIMIT 1;
  UPDATE molde SET order_id = 'pedido_orfao', customer_id = 'cliente_orfao';
  SET v_1452 = 0, v_1062 = 0, v_outro = 0;
  START TRANSACTION;
  INSERT INTO orders SELECT * FROM molde;
  ROLLBACK;
  INSERT INTO resultado_chaves VALUES ('fk_orders_customers', 'erro 1452',
    IF(v_1452 = 1, 'OK', IF(v_outro = 1, 'FALHA: outro erro', 'FALHA: aceitou o órfão')));
 
  -- 3.5 fk_payments_orders: pagamento apontando para pedido inexistente
  DROP TEMPORARY TABLE IF EXISTS molde;
  CREATE TEMPORARY TABLE molde LIKE order_payments;
  INSERT INTO molde SELECT * FROM order_payments LIMIT 1;
  UPDATE molde SET order_id = 'pedido_orfao';
  SET v_1452 = 0, v_1062 = 0, v_outro = 0;
  START TRANSACTION;
  INSERT INTO order_payments SELECT * FROM molde;
  ROLLBACK;
  INSERT INTO resultado_chaves VALUES ('fk_payments_orders', 'erro 1452',
    IF(v_1452 = 1, 'OK', IF(v_outro = 1, 'FALHA: outro erro', 'FALHA: aceitou o órfão')));
 
  -- 3.6 fk_reviews_orders: avaliação apontando para pedido inexistente
  DROP TEMPORARY TABLE IF EXISTS molde;
  CREATE TEMPORARY TABLE molde LIKE order_reviews;
  INSERT INTO molde SELECT * FROM order_reviews LIMIT 1;
  UPDATE molde SET review_id = 'review_orfao', order_id = 'pedido_orfao';
  SET v_1452 = 0, v_1062 = 0, v_outro = 0;
  START TRANSACTION;
  INSERT INTO order_reviews SELECT * FROM molde;
  ROLLBACK;
  INSERT INTO resultado_chaves VALUES ('fk_reviews_orders', 'erro 1452',
    IF(v_1452 = 1, 'OK', IF(v_outro = 1, 'FALHA: outro erro', 'FALHA: aceitou o órfão')));
 
  -- 3.7 PK composta de order_items: reinserir uma linha idêntica
  DROP TEMPORARY TABLE IF EXISTS molde;
  CREATE TEMPORARY TABLE molde LIKE order_items;
  INSERT INTO molde SELECT * FROM order_items LIMIT 1;
  SET v_1452 = 0, v_1062 = 0, v_outro = 0;
  START TRANSACTION;
  INSERT INTO order_items SELECT * FROM molde;
  ROLLBACK;
  INSERT INTO resultado_chaves VALUES ('pk_order_items (duplicata)', 'erro 1062',
    IF(v_1062 = 1, 'OK', IF(v_outro = 1, 'FALHA: outro erro', 'FALHA: aceitou a duplicata')));
 
  DROP TEMPORARY TABLE IF EXISTS molde;
  SELECT * FROM resultado_chaves;
END //
 
DELIMITER ;
 
CALL teste_chaves();
DROP PROCEDURE teste_chaves;

-- =====================================================================
-- TESTE 4: COBERTURA (informativo, não é erro)
-- Pergunta: existem pais sem nenhum filho?
-- A FK permite pai sem filho. Mas, para o BI, importa saber, porque um
-- pedido sem item some de qualquer análise de receita.
-- Compare o número com o Bloco 4 do profiling (03_profiling.sql); se for o
-- mesmo valor, está tudo coerente.
-- =====================================================================
 
SELECT 'pedidos sem nenhum item' AS situacao, COUNT(*) AS quantidade
FROM orders o
LEFT JOIN order_items i ON i.order_id = o.order_id
WHERE i.order_id IS NULL
UNION ALL
SELECT 'pedidos sem pagamento', COUNT(*)
FROM orders o
LEFT JOIN order_payments p ON p.order_id = o.order_id
WHERE p.order_id IS NULL
UNION ALL
SELECT 'pedidos sem avaliação', COUNT(*)
FROM orders o
LEFT JOIN order_reviews r ON r.order_id = o.order_id
WHERE r.order_id IS NULL;