-- =====================================================================
-- 05a_categorias_ptbr.sql
-- nome original da categoria (products) -> nome em português
-- Gerado a partir do inventário de 29/10/2026 (74 linhas: 73 categorias + NULL)
--
-- Regras:
--   A chave é o nome ORIGINAL (products.product_category_name), que é único.
--     Não usamos mais o nome em inglês: a tabela de tradução tem erros de digitação
--     (costruction_tools_*, fashio_female_clothing, home_confort).
--   * Mapeamento 1 para 1: nenhuma categoria é fundida com outra, então os totais
--     do painel não mudam (ex.: 52 categorias com 100+ avaliações).
--   * Produtos sem categoria (610, NULL) NÃO entram aqui; a view usa
--     COALESCE(c.categoria, 'Sem categoria').
-- =====================================================================

CREATE TABLE IF NOT EXISTS categoria_ptbr (
    product_category_name VARCHAR(100) NOT NULL,
    categoria             VARCHAR(100) NOT NULL,
    PRIMARY KEY (product_category_name),
    UNIQUE KEY uq_categoria_ptbr_nome (categoria)   -- garante que dois originais não ganhem o mesmo nome
) DEFAULT CHARSET = utf8mb4;

TRUNCATE TABLE categoria_ptbr;

INSERT INTO categoria_ptbr (product_category_name, categoria) VALUES
('cama_mesa_banho',                                'Cama, mesa e banho'),
('esporte_lazer',                                  'Esporte e lazer'),
('moveis_decoracao',                               'Móveis e decoração'),
('beleza_saude',                                   'Beleza e saúde'),
('utilidades_domesticas',                          'Utilidades domésticas'),
('automotivo',                                     'Automotivo'),
('informatica_acessorios',                         'Informática e acessórios'),
('brinquedos',                                     'Brinquedos'),
('relogios_presentes',                             'Relógios e presentes'),
('telefonia',                                      'Telefonia'),
('bebes',                                          'Bebês'),
('perfumaria',                                     'Perfumaria'),
('papelaria',                                      'Papelaria'),
('fashion_bolsas_e_acessorios',                    'Moda: bolsas e acessórios'),
('cool_stuff',                                     'Cool stuff'),
('ferramentas_jardim',                             'Ferramentas de jardim'),
('pet_shop',                                       'Pet shop'),
('eletronicos',                                    'Eletrônicos'),
('construcao_ferramentas_construcao',              'Construção: construção'),
('eletrodomesticos',                               'Eletrodomésticos'),
('malas_acessorios',                               'Malas e acessórios'),
('consoles_games',                                 'Consoles e games'),
('moveis_escritorio',                              'Móveis de escritório'),
('instrumentos_musicais',                          'Instrumentos musicais'),
('eletroportateis',                                'Eletroportáteis'),
('casa_construcao',                                'Casa e construção'),
('livros_interesse_geral',                         'Livros de interesse geral'),
('fashion_calcados',                               'Moda: calçados'),
('moveis_sala',                                    'Móveis de sala'),
('climatizacao',                                   'Climatização'),
('livros_tecnicos',                                'Livros técnicos'),
('telefonia_fixa',                                 'Telefonia fixa'),
('casa_conforto',                                  'Casa e conforto'),
('market_place',                                   'Marketplace'),
('alimentos_bebidas',                              'Alimentos e bebidas'),
('fashion_roupa_masculina',                        'Moda: roupa masculina'),
('moveis_cozinha_area_de_servico_jantar_e_jardim', 'Móveis: cozinha, serviço, jantar e jardim'),
('sinalizacao_e_seguranca',                        'Sinalização e segurança'),
('construcao_ferramentas_seguranca',               'Construção: segurança'),
('eletrodomesticos_2',                             'Eletrodomésticos 2'),
('construcao_ferramentas_jardim',                  'Construção: jardim'),
('alimentos',                                      'Alimentos'),
('bebidas',                                        'Bebidas'),
('construcao_ferramentas_iluminacao',              'Construção: iluminação'),
('agro_industria_e_comercio',                      'Agro, indústria e comércio'),
('industria_comercio_e_negocios',                  'Indústria, comércio e negócios'),
('artigos_de_natal',                               'Artigos de Natal'),
('audio',                                          'Áudio'),
('artes',                                          'Artes'),
('fashion_underwear_e_moda_praia',                 'Moda: íntima e praia'),
('dvds_blu_ray',                                   'DVDs e Blu-ray'),
('moveis_quarto',                                  'Móveis de quarto'),
('construcao_ferramentas_ferramentas',             'Construção: ferramentas'),
('portateis_casa_forno_e_cafe',                    'Portáteis: forno e café'),
('livros_importados',                              'Livros importados'),
('pcs',                                            'PCs'),
('cine_foto',                                      'Cine e foto'),
('musica',                                         'Música'),
('fashion_roupa_feminina',                         'Moda: roupa feminina'),
('artigos_de_festas',                              'Artigos de festas'),
('artes_e_artesanato',                             'Artes e artesanato'),
('fashion_esporte',                                'Moda: esporte'),
('flores',                                         'Flores'),
('fraldas_higiene',                                'Fraldas e higiene'),
('portateis_cozinha_e_preparadores_de_alimentos',  'Portáteis: cozinha e preparadores'),
('la_cuisine',                                     'La cuisine'),
('moveis_colchao_e_estofado',                      'Móveis: colchão e estofado'),
('tablets_impressao_imagem',                       'Tablets, impressão e imagem'),
('fashion_roupa_infanto_juvenil',                  'Moda: roupa infantojuvenil'),
('casa_conforto_2',                                'Casa e conforto 2'),
('pc_gamer',                                       'PC gamer'),
('seguros_e_servicos',                             'Seguros e serviços'),
('cds_dvds_musicais',                              'CDs e DVDs musicais');

-- =====================================================================
-- CONFERÊNCIAS (rodar logo após o INSERT)
-- =====================================================================

-- C1. Quantas linhas entraram. Esperado: 73
SELECT COUNT(*) AS categorias_mapeadas FROM categoria_ptbr;

-- C2. Categorias de products SEM mapeamento. Esperado: 0 linhas
SELECT DISTINCT p.product_category_name
FROM products p
LEFT JOIN categoria_ptbr c ON c.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND c.categoria IS NULL;

-- C3. Produtos por categoria em português: a soma deve ser igual ao total de products
--     (inclui o grupo 'Sem categoria' = 610)
SELECT COALESCE(c.categoria, 'Sem categoria') AS categoria, COUNT(*) AS produtos
FROM products p
LEFT JOIN categoria_ptbr c ON c.product_category_name = p.product_category_name
GROUP BY COALESCE(c.categoria, 'Sem categoria')
ORDER BY produtos DESC;
