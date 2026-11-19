-- =====================================================================
-- RootFix · Banco de Dados · 02 · Carga de dados de teste (bloco anônimo com laços)
-- =====================================================================
-- INTEGRANTES:
--    Raul Rezende — RM564002 — 2TDSPF
--    Felipe Furlanetto — RM562766 — 2TDSPF
--    João Victor Caetano — RM562074 — 2TDSPF
--    Ryan Vetoriano — RM565667 — 2TDSPF
--    João Victor Bueno — RM564115 — 2TDSPF
-- =====================================================================
-- Pré-requisito: 01-objetos-plsql.sql já executado.
--
-- Cria, em São Paulo:
--   2 gestores e 3 comunidades (Vila Mariana, Ibirapuera, Pinheiros)
--   7 moradores; 6 entram, pela regra dos 3 km, nas comunidades perto
--     de casa e 1 (Santo Amaro) fica longe de todas, para os testes
--   10 problemas, apoios, observações e 1 comunicado por comunidade
--   5 problemas adotados com status variados, usando os procedimentos
-- =====================================================================
-- Todos os usuários de teste usam e-mail @teste.rootfix.com e a senha
-- Rootfix@2026 (mesma das contas de teste do Java), então também
-- conseguem entrar no app. Ex.: morador.ana@teste.rootfix.com
-- =====================================================================
-- Pode rodar de novo: o bloco apaga antes só os dados @teste.rootfix.com
-- (e o que depende deles); os dados criados pelas APIs não são tocados.
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    c_dominio  CONSTANT VARCHAR2(30)  := '@teste.rootfix.com';
    -- BCrypt de "Rootfix@2026", aceito pelo BCryptPasswordEncoder do Java
    c_senha    CONSTANT VARCHAR2(100) := '$2a$10$KnQ//KQGw1gep8ylGrDXCea.zz2OtT1l7u0NpGNSZ3UnmIKqvI1wa';

    -- ---------- estruturas dos dados ----------
    TYPE t_gestor IS RECORD (nome VARCHAR2(120), email VARCHAR2(150), organizacao VARCHAR2(150), id NUMBER);
    TYPE t_comunidade IS RECORD (nome VARCHAR2(120), descricao VARCHAR2(500), lat NUMBER, lon NUMBER,
                                 idx_gestor PLS_INTEGER, id NUMBER);
    TYPE t_morador IS RECORD (nome VARCHAR2(120), email VARCHAR2(150), endereco VARCHAR2(255),
                              lat NUMBER, lon NUMBER, id NUMBER);
    TYPE t_problema IS RECORD (titulo VARCHAR2(120), descricao VARCHAR2(1000), idx_comunidade PLS_INTEGER,
                               idx_autor PLS_INTEGER, categoria VARCHAR2(60), gravidade VARCHAR2(10),
                               lat NUMBER, lon NUMBER, qtd_apoios PLS_INTEGER, observacao VARCHAR2(1000),
                               status_final VARCHAR2(20), id NUMBER);

    TYPE t_gestores    IS TABLE OF t_gestor    INDEX BY PLS_INTEGER;
    TYPE t_comunidades IS TABLE OF t_comunidade INDEX BY PLS_INTEGER;
    TYPE t_moradores   IS TABLE OF t_morador   INDEX BY PLS_INTEGER;
    TYPE t_problemas   IS TABLE OF t_problema  INDEX BY PLS_INTEGER;

    v_gestores    t_gestores;
    v_comunidades t_comunidades;
    v_moradores   t_moradores;
    v_problemas   t_problemas;

    v_id_categoria  NUMBER;
    v_id_comunidade NUMBER;
    v_id_autor      NUMBER;
    v_qtd_apoios    NUMBER;
    v_novo_id       NUMBER;
    v_id_gestor     NUMBER;
    v_id_observador NUMBER;
    v_qtd           NUMBER;

    -- ---------- funções de apoio para montar as listas ----------
    PROCEDURE add_gestor (p_nome VARCHAR2, p_email VARCHAR2, p_org VARCHAR2) IS
        i PLS_INTEGER := v_gestores.COUNT + 1;
    BEGIN
        v_gestores(i).nome := p_nome;
        v_gestores(i).email := p_email || c_dominio;
        v_gestores(i).organizacao := p_org;
    END;

    PROCEDURE add_comunidade (p_nome VARCHAR2, p_desc VARCHAR2, p_lat NUMBER, p_lon NUMBER, p_gestor PLS_INTEGER) IS
        i PLS_INTEGER := v_comunidades.COUNT + 1;
    BEGIN
        v_comunidades(i).nome := p_nome;
        v_comunidades(i).descricao := p_desc;
        v_comunidades(i).lat := p_lat;
        v_comunidades(i).lon := p_lon;
        v_comunidades(i).idx_gestor := p_gestor;
    END;

    PROCEDURE add_morador (p_nome VARCHAR2, p_email VARCHAR2, p_end VARCHAR2, p_lat NUMBER, p_lon NUMBER) IS
        i PLS_INTEGER := v_moradores.COUNT + 1;
    BEGIN
        v_moradores(i).nome := p_nome;
        v_moradores(i).email := p_email || c_dominio;
        v_moradores(i).endereco := p_end;
        v_moradores(i).lat := p_lat;
        v_moradores(i).lon := p_lon;
    END;

    PROCEDURE add_problema (p_titulo VARCHAR2, p_desc VARCHAR2, p_com PLS_INTEGER, p_autor PLS_INTEGER,
                            p_cat VARCHAR2, p_grav VARCHAR2, p_lat NUMBER, p_lon NUMBER,
                            p_apoios PLS_INTEGER, p_obs VARCHAR2, p_status VARCHAR2) IS
        i PLS_INTEGER := v_problemas.COUNT + 1;
    BEGIN
        v_problemas(i).titulo := p_titulo;
        v_problemas(i).descricao := p_desc;
        v_problemas(i).idx_comunidade := p_com;
        v_problemas(i).idx_autor := p_autor;
        v_problemas(i).categoria := p_cat;
        v_problemas(i).gravidade := p_grav;
        v_problemas(i).lat := p_lat;
        v_problemas(i).lon := p_lon;
        v_problemas(i).qtd_apoios := p_apoios;
        v_problemas(i).observacao := p_obs;
        v_problemas(i).status_final := p_status;  -- NULL = fica no feed, sem adoção
    END;

BEGIN
    -- =================================================================
    -- 0. Limpeza dos dados de teste anteriores (ordem respeita as FKs)
    -- =================================================================
    DELETE FROM RF_NOTIFICACAO      WHERE ID_USUARIO IN (SELECT ID FROM RF_USUARIO WHERE EMAIL LIKE '%' || c_dominio);
    DELETE FROM RF_IDEMPOTENCIA     WHERE ID_USUARIO IN (SELECT ID FROM RF_USUARIO WHERE EMAIL LIKE '%' || c_dominio);
    DELETE FROM RF_HISTORICO_STATUS WHERE ID_USUARIO IN (SELECT ID FROM RF_USUARIO WHERE EMAIL LIKE '%' || c_dominio);
    DELETE FROM RF_APOIO            WHERE ID_USUARIO IN (SELECT ID FROM RF_USUARIO WHERE EMAIL LIKE '%' || c_dominio);
    DELETE FROM RF_OBSERVACAO       WHERE ID_AUTOR   IN (SELECT ID FROM RF_USUARIO WHERE EMAIL LIKE '%' || c_dominio);
    DELETE FROM RF_PROBLEMA
     WHERE ID_AUTOR IN (SELECT ID FROM RF_USUARIO WHERE EMAIL LIKE '%' || c_dominio)
        OR ID_COMUNIDADE IN (SELECT c.ID FROM RF_COMUNIDADE c JOIN RF_USUARIO u ON u.ID = c.ID_GESTOR
                              WHERE u.EMAIL LIKE '%' || c_dominio);
    DELETE FROM RF_COMUNICADO       WHERE ID_AUTOR   IN (SELECT ID FROM RF_USUARIO WHERE EMAIL LIKE '%' || c_dominio);
    DELETE FROM RF_PARTICIPACAO     WHERE ID_USUARIO IN (SELECT ID FROM RF_USUARIO WHERE EMAIL LIKE '%' || c_dominio);
    DELETE FROM RF_COMUNIDADE       WHERE ID_GESTOR  IN (SELECT ID FROM RF_USUARIO WHERE EMAIL LIKE '%' || c_dominio);
    DELETE FROM RF_USUARIO          WHERE EMAIL LIKE '%' || c_dominio;

    -- =================================================================
    -- 1. Dados
    -- =================================================================
    add_gestor('Carla Mendes',         'gestor.vilamariana', 'Associação de Moradores da Vila Mariana');
    add_gestor('Paulo Henrique Souza', 'gestor.pinheiros',   'Conselho Comunitário de Pinheiros');

    add_comunidade('Vila Mariana - Metrô Ana Rosa',
                   'Ruas em volta do Metrô Ana Rosa, entre a Domingos de Morais e a Vergueiro.',
                   -23.5812000, -46.6383000, 1);
    add_comunidade('Pinheiros - Largo da Batata',
                   'Quarteirões entre o Largo da Batata, a Teodoro Sampaio e a Rua dos Pinheiros.',
                   -23.5668000, -46.6930000, 2);
    add_comunidade('Vila Mariana - Parque Ibirapuera',
                   'Entorno do portão 10 do Ibirapuera e da Av. Pedro Álvares Cabral.',
                   -23.5874000, -46.6576000, 1);

    add_morador('Ana Lima',        'morador.ana',     'Rua Domingos de Morais, 1200 - Vila Mariana', -23.5840000, -46.6350000);
    add_morador('Bruno Costa',     'morador.bruno',   'Rua Vergueiro, 2100 - Vila Mariana',          -23.5790000, -46.6410000);
    add_morador('Camila Rocha',    'morador.camila',  'Rua França Pinto, 500 - Vila Mariana',        -23.5905000, -46.6420000);
    add_morador('Diego Martins',   'morador.diego',   'Rua Teodoro Sampaio, 1500 - Pinheiros',       -23.5650000, -46.6900000);
    add_morador('Elisa Fernandes', 'morador.elisa',   'Rua dos Pinheiros, 800 - Pinheiros',          -23.5690000, -46.6970000);
    add_morador('Fábio Nunes',     'morador.fabio',   'Rua Cardeal Arcoverde, 1300 - Pinheiros',     -23.5620000, -46.6880000);
    add_morador('Gustavo Pereira', 'morador.gustavo', 'Largo Treze de Maio, 50 - Santo Amaro',       -23.6543000, -46.7105000);

    --           título                                              descrição
    --           comunidade, autor, categoria, gravidade, lat, lon, apoios, observação, status final
    add_problema('Buraco grande na Rua Domingos de Morais',
                 'Buraco de quase um metro na faixa da direita, na altura do número 1200. Carros desviam em cima da hora.',
                 1, 1, 'Buraco ou pavimento', 'ALTA', -23.5838000, -46.6352000, 2,
                 'Ontem um motoqueiro quase caiu aí.', 'RESOLVIDO');
    add_problema('Poste apagado na Rua Joaquim Távora',
                 'O poste em frente ao número 300 está apagado há duas semanas e a rua fica escura à noite.',
                 1, 2, 'Iluminação pública', 'MEDIA', -23.5801000, -46.6395000, 2,
                 NULL, 'EM_ANDAMENTO');
    add_problema('Lixo acumulado na esquina da Rua França Pinto',
                 'Sacos de lixo acumulados na esquina, fora do horário da coleta, atraindo ratos.',
                 1, 3, 'Lixo e limpeza', 'MEDIA', -23.5902000, -46.6418000, 1,
                 'A coleta passou e não levou tudo.', NULL);
    add_problema('Bueiro entupido na Rua Vergueiro',
                 'Quando chove forte a água sobe na calçada porque o bueiro está entupido de folhas.',
                 1, 2, 'Bueiro e drenagem', 'ALTA', -23.5788000, -46.6408000, 0,
                 NULL, NULL);
    add_problema('Calçada quebrada perto do portão 10 do Ibirapuera',
                 'Placas da calçada soltas e levantadas por raízes; difícil passar com cadeira de rodas.',
                 3, 1, 'Calçada e acessibilidade', 'MEDIA', -23.5870000, -46.6570000, 1,
                 'Minha mãe tropeçou aqui semana passada.', NULL);
    add_problema('Semáforo piscando na Av. Pedro Álvares Cabral',
                 'Semáforo de pedestres em amarelo piscante desde segunda; travessia perigosa no horário de pico.',
                 3, 3, 'Sinalização de trânsito', 'CRITICA', -23.5880000, -46.6560000, 2,
                 NULL, 'EM_ANDAMENTO');
    add_problema('Buraco na ciclovia da Rua Teodoro Sampaio',
                 'Buraco no meio da ciclovia, perto do cruzamento com a Rua Fradique Coutinho.',
                 2, 4, 'Buraco ou pavimento', 'ALTA', -23.5655000, -46.6905000, 2,
                 'Já vi dois ciclistas desviando para a pista dos carros.', 'PENDENTE');
    add_problema('Entulho abandonado no Largo da Batata',
                 'Restos de obra deixados no canto do largo há mais de dez dias.',
                 2, 5, 'Lixo e limpeza', 'BAIXA', -23.5670000, -46.6935000, 1,
                 NULL, NULL);
    add_problema('Praça sem iluminação na Rua dos Pinheiros',
                 'Os refletores da praça não acendem; à noite ninguém passa por lá.',
                 2, 6, 'Iluminação pública', 'MEDIA', -23.5692000, -46.6965000, 2,
                 'Foi aberta reclamação no 156 também.', 'ARQUIVADO');
    add_problema('Banco quebrado na Praça Benedito Calixto',
                 'Um dos bancos de madeira está com o assento partido e com pregos expostos.',
                 2, 5, 'Praças e áreas verdes', 'BAIXA', -23.5625000, -46.6880000, 1,
                 NULL, NULL);

    -- =================================================================
    -- 2. Gestores
    -- =================================================================
    FOR i IN 1 .. v_gestores.COUNT LOOP
        INSERT INTO RF_USUARIO (NOME, EMAIL, SENHA_HASH, PERFIL, ORGANIZACAO)
        VALUES (v_gestores(i).nome, v_gestores(i).email, c_senha, 'GESTOR', v_gestores(i).organizacao)
        RETURNING ID INTO v_novo_id;
        v_gestores(i).id := v_novo_id;
    END LOOP;

    -- =================================================================
    -- 3. Comunidades
    -- =================================================================
    FOR i IN 1 .. v_comunidades.COUNT LOOP
        v_id_gestor := v_gestores(v_comunidades(i).idx_gestor).id;

        INSERT INTO RF_COMUNIDADE (NOME, DESCRICAO, LATITUDE, LONGITUDE, ID_GESTOR)
        VALUES (v_comunidades(i).nome, v_comunidades(i).descricao, v_comunidades(i).lat, v_comunidades(i).lon,
                v_id_gestor)
        RETURNING ID INTO v_novo_id;
        v_comunidades(i).id := v_novo_id;
    END LOOP;

    -- =================================================================
    -- 4. Moradores e participações (regra dos 3 km com FN_DISTANCIA_KM)
    -- =================================================================
    FOR i IN 1 .. v_moradores.COUNT LOOP
        INSERT INTO RF_USUARIO (NOME, EMAIL, SENHA_HASH, PERFIL, ENDERECO, LATITUDE, LONGITUDE)
        VALUES (v_moradores(i).nome, v_moradores(i).email, c_senha, 'MORADOR', v_moradores(i).endereco,
                v_moradores(i).lat, v_moradores(i).lon)
        RETURNING ID INTO v_novo_id;
        v_moradores(i).id := v_novo_id;

        FOR j IN 1 .. v_comunidades.COUNT LOOP
            IF FN_DISTANCIA_KM(v_moradores(i).lat, v_moradores(i).lon,
                               v_comunidades(j).lat, v_comunidades(j).lon) <= PKG_COMUNIDADE.c_raio_km THEN
                INSERT INTO RF_PARTICIPACAO (ID_USUARIO, ID_COMUNIDADE)
                VALUES (v_moradores(i).id, v_comunidades(j).id);
            END IF;
        END LOOP;
    END LOOP;

    -- =================================================================
    -- 5. Problemas, apoios e observações
    -- =================================================================
    FOR i IN 1 .. v_problemas.COUNT LOOP
        v_id_comunidade := v_comunidades(v_problemas(i).idx_comunidade).id;
        v_id_autor      := v_moradores(v_problemas(i).idx_autor).id;
        v_qtd_apoios    := v_problemas(i).qtd_apoios;

        SELECT ID INTO v_id_categoria FROM RF_CATEGORIA WHERE NOME = v_problemas(i).categoria;

        INSERT INTO RF_PROBLEMA (TITULO, DESCRICAO, LATITUDE, LONGITUDE, ID_AUTOR, ID_COMUNIDADE,
                                 ID_CATEGORIA, GRAVIDADE_IA, JUSTIFICATIVA_IA)
        VALUES (v_problemas(i).titulo, v_problemas(i).descricao, v_problemas(i).lat, v_problemas(i).lon,
                v_id_autor, v_id_comunidade,
                v_id_categoria, v_problemas(i).gravidade, 'Classificação de exemplo da carga de teste (PL/SQL).')
        RETURNING ID INTO v_novo_id;
        v_problemas(i).id := v_novo_id;

        -- Apoios: os primeiros membros da comunidade, menos o autor
        IF v_qtd_apoios > 0 THEN
            INSERT INTO RF_APOIO (ID_USUARIO, ID_PROBLEMA)
            SELECT pa.ID_USUARIO, v_problemas(i).id
              FROM RF_PARTICIPACAO pa
             WHERE pa.ID_COMUNIDADE = v_id_comunidade
               AND pa.ID_USUARIO   != v_id_autor
             ORDER BY pa.ID_USUARIO
             FETCH FIRST v_qtd_apoios ROWS ONLY;
        END IF;

        -- Observação: escrita pelo último membro da comunidade que não é o autor
        IF v_problemas(i).observacao IS NOT NULL THEN
            SELECT MAX(pa.ID_USUARIO)
              INTO v_id_observador
              FROM RF_PARTICIPACAO pa
             WHERE pa.ID_COMUNIDADE = v_id_comunidade
               AND pa.ID_USUARIO   != v_id_autor;

            INSERT INTO RF_OBSERVACAO (ID_PROBLEMA, ID_AUTOR, TEXTO)
            VALUES (v_problemas(i).id, v_id_observador, v_problemas(i).observacao);
        END IF;
    END LOOP;

    -- =================================================================
    -- 6. Adoção e status, pelos procedimentos (sem histórico: é da API .NET)
    -- =================================================================
    FOR i IN 1 .. v_problemas.COUNT LOOP
        IF v_problemas(i).status_final IS NOT NULL THEN
            v_id_gestor := v_gestores(v_comunidades(v_problemas(i).idx_comunidade).idx_gestor).id;

            PRC_ADOTAR_PROBLEMA(v_problemas(i).id, v_id_gestor);  -- fica PENDENTE

            CASE v_problemas(i).status_final
                WHEN 'EM_ANDAMENTO' THEN
                    PRC_ALTERAR_STATUS(v_problemas(i).id, v_id_gestor, 'EM_ANDAMENTO');
                WHEN 'RESOLVIDO' THEN
                    PRC_ALTERAR_STATUS(v_problemas(i).id, v_id_gestor, 'EM_ANDAMENTO');
                    PRC_ALTERAR_STATUS(v_problemas(i).id, v_id_gestor, 'RESOLVIDO');
                WHEN 'ARQUIVADO' THEN
                    PRC_ALTERAR_STATUS(v_problemas(i).id, v_id_gestor, 'ARQUIVADO');
                ELSE
                    NULL;  -- PENDENTE: já ficou assim na adoção
            END CASE;
        END IF;
    END LOOP;

    -- =================================================================
    -- 7. Um comunicado por comunidade (o da primeira em destaque)
    -- =================================================================
    FOR i IN 1 .. v_comunidades.COUNT LOOP
        v_id_gestor := v_gestores(v_comunidades(i).idx_gestor).id;

        INSERT INTO RF_COMUNICADO (ID_COMUNIDADE, ID_AUTOR, TITULO, TEXTO, DESTACADO)
        VALUES (v_comunidades(i).id, v_id_gestor,
                'Mutirão de limpeza no sábado',
                'Neste sábado, às 9h, faremos um mutirão de limpeza na comunidade ' || v_comunidades(i).nome
                || '. Tragam luvas; os sacos ficam por nossa conta.',
                CASE WHEN i = 1 THEN 1 ELSE 0 END);
    END LOOP;

    COMMIT;

    -- =================================================================
    -- 8. Resumo
    -- =================================================================
    DBMS_OUTPUT.PUT_LINE('Carga de teste concluída.');
    FOR i IN 1 .. v_comunidades.COUNT LOOP
        SELECT COUNT(*) INTO v_qtd FROM RF_PROBLEMA WHERE ID_COMUNIDADE = v_comunidades(i).id;
        DBMS_OUTPUT.PUT_LINE('  ' || v_comunidades(i).nome || ': '
                             || PKG_COMUNIDADE.total_membros(v_comunidades(i).id) || ' membro(s), '
                             || v_qtd || ' problema(s)');
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Login de exemplo: morador.ana' || c_dominio || ' / Rootfix@2026');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Erro na carga, nada foi gravado: ' || SQLERRM);
        RAISE;
END;
/
