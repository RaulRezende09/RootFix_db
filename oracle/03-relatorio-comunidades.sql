-- =====================================================================
-- RootFix · Banco de Dados · 03 · Relatório por comunidade (bloco anônimo com cursores)
-- =====================================================================
-- INTEGRANTES:
--    Raul Rezende — RM564002 — 2TDSPF
--    Felipe Furlanetto — RM562766 — 2TDSPF
--    João Victor Caetano — RM562074 — 2TDSPF
--    Ryan Vetoriano — RM565667 — 2TDSPF
--    João Victor Bueno — RM564115 — 2TDSPF
-- =====================================================================
-- Para cada comunidade: gestor, membros,
-- problemas por situação(feed, pendente, em andamento, resolvido, arquivado),
-- apoios, observações, comunicados e o ranking dos mais apoiados.
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    -- Cursor explícito: comunidades com o gestor
    CURSOR c_comunidades IS
        SELECT c.ID, c.NOME, g.NOME AS GESTOR, g.ORGANIZACAO
          FROM RF_COMUNIDADE c
          JOIN RF_USUARIO g ON g.ID = c.ID_GESTOR
         ORDER BY c.NOME;

    -- Cursor com parâmetro: problemas da comunidade agrupados por situação
    CURSOR c_situacoes (p_id_comunidade NUMBER) IS
        SELECT SITUACAO, QTD
          FROM (SELECT NVL(p.STATUS, 'NO FEED') AS SITUACAO,
                       COUNT(*)                 AS QTD
                  FROM RF_PROBLEMA p
                 WHERE p.ID_COMUNIDADE = p_id_comunidade
                 GROUP BY NVL(p.STATUS, 'NO FEED'))
         ORDER BY DECODE(SITUACAO, 'NO FEED', 1, 'PENDENTE', 2, 'EM_ANDAMENTO', 3,
                                   'RESOLVIDO', 4, 'ARQUIVADO', 5, 6);

    r_comunidade   c_comunidades%ROWTYPE;
    v_total_prob   NUMBER;
    v_total_apoios NUMBER;
    v_total_obs    NUMBER;
    v_comunicados  NUMBER;
    v_qtd_com      PLS_INTEGER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('==================== RELATÓRIO ROOTFIX POR COMUNIDADE ====================');
    DBMS_OUTPUT.PUT_LINE('Gerado em ' || TO_CHAR(SYSTIMESTAMP, 'DD/MM/YYYY HH24:MI'));

    OPEN c_comunidades;
    LOOP
        FETCH c_comunidades INTO r_comunidade;
        EXIT WHEN c_comunidades%NOTFOUND;
        v_qtd_com := v_qtd_com + 1;

        SELECT COUNT(*) INTO v_total_prob FROM RF_PROBLEMA WHERE ID_COMUNIDADE = r_comunidade.ID;

        SELECT COUNT(a.ID) INTO v_total_apoios
          FROM RF_APOIO a JOIN RF_PROBLEMA p ON p.ID = a.ID_PROBLEMA
         WHERE p.ID_COMUNIDADE = r_comunidade.ID;

        SELECT COUNT(o.ID) INTO v_total_obs
          FROM RF_OBSERVACAO o JOIN RF_PROBLEMA p ON p.ID = o.ID_PROBLEMA
         WHERE p.ID_COMUNIDADE = r_comunidade.ID;

        SELECT COUNT(*) INTO v_comunicados FROM RF_COMUNICADO WHERE ID_COMUNIDADE = r_comunidade.ID;

        DBMS_OUTPUT.PUT_LINE(' ');
        DBMS_OUTPUT.PUT_LINE('>> ' || r_comunidade.NOME);
        DBMS_OUTPUT.PUT_LINE('   Gestor: ' || r_comunidade.GESTOR || ' (' || r_comunidade.ORGANIZACAO || ')');
        DBMS_OUTPUT.PUT_LINE('   Membros: ' || PKG_COMUNIDADE.total_membros(r_comunidade.ID)
                             || ' | Problemas: ' || v_total_prob
                             || ' | Apoios: ' || v_total_apoios
                             || ' | Observações: ' || v_total_obs
                             || ' | Comunicados: ' || v_comunicados);

        DBMS_OUTPUT.PUT_LINE('   Problemas por situação:');
        IF v_total_prob = 0 THEN
            DBMS_OUTPUT.PUT_LINE('    (nenhum)');
        ELSE
            FOR r_sit IN c_situacoes(r_comunidade.ID) LOOP
                DBMS_OUTPUT.PUT_LINE('    ' || RPAD(r_sit.SITUACAO, 14) || r_sit.QTD);
            END LOOP;
        END IF;

        DBMS_OUTPUT.PUT_LINE('   Mais apoiados:');
        PKG_PROBLEMA.listar_mais_apoiados(r_comunidade.ID, 3);
    END LOOP;
    CLOSE c_comunidades;

    DBMS_OUTPUT.PUT_LINE(' ');
    DBMS_OUTPUT.PUT_LINE('Total de comunidades: ' || v_qtd_com);
EXCEPTION
    WHEN OTHERS THEN
        IF c_comunidades%ISOPEN THEN
            CLOSE c_comunidades;
        END IF;
        RAISE;
END;
/
