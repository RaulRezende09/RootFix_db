-- =====================================================================
-- RootFix · Banco de Dados · 04
-- Testes das funções, procedimentos, gatilhos e pacotes (bloco anônimo)
-- =====================================================================
-- INTEGRANTES:
-- Raul Rezende — RM564002
-- Felipe Furlanetto — RM562766
-- João Victor Caetano — RM562074
-- Ryan Victor — RM565667
-- João Victor Castelini — RM564115
-- =====================================================================
-- Pré-requisito: 01-objetos-plsql.sql e 02-carga-dados-teste.sql.
--
-- Cada teste mostra [OK] ou [FALHOU] com DBMS_OUTPUT.
-- Os casos de erro conferem o código devolvido pelo RAISE_APPLICATION_ERROR.
-- No fim, tudo o que os testes mudaram é desfeito com ROLLBACK.
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
    c_dominio CONSTANT VARCHAR2(30) := '@teste.rootfix.com';

    v_ok      PLS_INTEGER := 0;
    v_falhas  PLS_INTEGER := 0;

    -- dados da carga
    v_gestor_vm   NUMBER;   -- gestora da Vila Mariana (comunidades 1 e 3)
    v_gestor_pin  NUMBER;   -- gestor de Pinheiros
    v_ana         NUMBER;   -- moradora perto da Vila Mariana
    v_gustavo     NUMBER;   -- morador longe de todas (Santo Amaro)
    v_com_anarosa NUMBER;
    v_p_buraco    NUMBER;   -- RESOLVIDO, 2 apoios
    v_p_lixo      NUMBER;   -- no feed (usado na adoção)
    v_p_bueiro    NUMBER;   -- no feed (usado no gatilho de adoção)
    v_p_calcada   NUMBER;   -- no feed (comunidade Ibirapuera)
    v_p_ciclovia  NUMBER;   -- PENDENTE (Pinheiros)

    -- auxiliares
    v_num      NUMBER;
    v_num2     NUMBER;
    v_txt      VARCHAR2(4000);
    v_txt2     VARCHAR2(4000);
    v_adotado  NUMBER;
    v_status   VARCHAR2(20);
    v_data     TIMESTAMP;
    v_cursor   SYS_REFCURSOR;
    v_c_id     NUMBER;
    v_c_nome   VARCHAR2(120);
    v_c_gestor VARCHAR2(120);
    v_c_org    VARCHAR2(150);
    v_c_dist   NUMBER;
    v_max_dist NUMBER;

    PROCEDURE verifica (p_nome VARCHAR2, p_condicao BOOLEAN, p_detalhe VARCHAR2 DEFAULT NULL) IS
    BEGIN
        IF NVL(p_condicao, FALSE) THEN
            v_ok := v_ok + 1;
            DBMS_OUTPUT.PUT_LINE('[OK]     ' || p_nome || CASE WHEN p_detalhe IS NOT NULL THEN ' -> ' || p_detalhe END);
        ELSE
            v_falhas := v_falhas + 1;
            DBMS_OUTPUT.PUT_LINE('[FALHOU] ' || p_nome || CASE WHEN p_detalhe IS NOT NULL THEN ' -> ' || p_detalhe END);
        END IF;
    END verifica;

    -- Usado dentro do EXCEPTION: confere se o erro foi o esperado
    PROCEDURE erro_esperado (p_nome VARCHAR2, p_codigo_esperado NUMBER, p_sqlcode NUMBER, p_sqlerrm VARCHAR2) IS
    BEGIN
        verifica(p_nome, p_sqlcode = p_codigo_esperado, p_sqlerrm);
    END erro_esperado;

    FUNCTION id_usuario (p_email VARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT ID INTO v_id FROM RF_USUARIO WHERE EMAIL = p_email || c_dominio;
        RETURN v_id;
    END id_usuario;

    -- 1 se a comunidade é da carga de teste, 0 se foi criada pelas APIs
    FUNCTION eh_comunidade_teste (p_id_comunidade NUMBER) RETURN NUMBER IS
        v_qtd NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_qtd
          FROM RF_COMUNIDADE c
          JOIN RF_USUARIO g ON g.ID = c.ID_GESTOR
         WHERE c.ID = p_id_comunidade
           AND g.EMAIL LIKE '%' || c_dominio;
        RETURN v_qtd;
    END eh_comunidade_teste;

    FUNCTION id_problema (p_titulo VARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT p.ID INTO v_id
          FROM RF_PROBLEMA p
          JOIN RF_USUARIO u ON u.ID = p.ID_AUTOR
         WHERE p.TITULO = p_titulo
           AND u.EMAIL LIKE '%' || c_dominio
         FETCH FIRST 1 ROW ONLY;
        RETURN v_id;
    END id_problema;

BEGIN
    -- -----------------------------------------------------------------
    -- Preparação: localizar os dados da carga
    -- -----------------------------------------------------------------
    BEGIN
        v_gestor_vm  := id_usuario('gestor.vilamariana');
        v_gestor_pin := id_usuario('gestor.pinheiros');
        v_ana        := id_usuario('morador.ana');
        v_gustavo    := id_usuario('morador.gustavo');

        SELECT ID INTO v_com_anarosa FROM RF_COMUNIDADE
         WHERE NOME = 'Vila Mariana - Metrô Ana Rosa' AND ID_GESTOR = v_gestor_vm;

        v_p_buraco   := id_problema('Buraco grande na Rua Domingos de Morais');
        v_p_lixo     := id_problema('Lixo acumulado na esquina da Rua França Pinto');
        v_p_bueiro   := id_problema('Bueiro entupido na Rua Vergueiro');
        v_p_calcada  := id_problema('Calçada quebrada perto do portão 10 do Ibirapuera');
        v_p_ciclovia := id_problema('Buraco na ciclovia da Rua Teodoro Sampaio');
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20999, 'Dados de teste não encontrados. Rode 02-carga-dados-teste.sql antes.');
    END;

    DBMS_OUTPUT.PUT_LINE('=============== TESTES PL/SQL ROOTFIX ===============');

    -- -----------------------------------------------------------------
    -- Funções
    -- -----------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- Funções ---');

    v_num := FN_DISTANCIA_KM(-23.5614, -46.6559, -23.5505, -46.6333);  -- MASP -> Praça da Sé
    verifica('T01 FN_DISTANCIA_KM: MASP até a Sé fica entre 2,5 e 2,7 km',
             v_num BETWEEN 2.5 AND 2.7, TO_CHAR(v_num, 'FM990.000') || ' km');

    verifica('T02 FN_DISTANCIA_KM: mesmo ponto dá 0 km',
             FN_DISTANCIA_KM(-23.5812, -46.6383, -23.5812, -46.6383) = 0);

    verifica('T03 FN_DISTANCIA_KM: coordenada vazia devolve NULL',
             FN_DISTANCIA_KM(NULL, -46.6383, -23.5812, -46.6383) IS NULL);

    v_num := FN_TOTAL_APOIOS(v_p_buraco);
    verifica('T04 FN_TOTAL_APOIOS: buraco da Domingos de Morais tem 2 apoios', v_num = 2, v_num || ' apoio(s)');

    verifica('T05 FN_TOTAL_APOIOS: problema inexistente devolve 0', FN_TOTAL_APOIOS(-1) = 0);

    -- -----------------------------------------------------------------
    -- PKG_COMUNIDADE
    -- -----------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- PKG_COMUNIDADE ---');

    verifica('T06 distancia_km do pacote igual à FN_DISTANCIA_KM',
             PKG_COMUNIDADE.distancia_km(-23.5614, -46.6559, -23.5505, -46.6333)
             = FN_DISTANCIA_KM(-23.5614, -46.6559, -23.5505, -46.6333));

    v_num := PKG_COMUNIDADE.total_membros(v_com_anarosa);
    verifica('T07 total_membros: Metrô Ana Rosa tem 3 membros', v_num = 3, v_num || ' membro(s)');

    verifica('T08 esta_no_raio: Ana mora a menos de 3 km da Ana Rosa',
             PKG_COMUNIDADE.esta_no_raio(v_ana, v_com_anarosa) = 1);

    verifica('T09 esta_no_raio: Gustavo (Santo Amaro) está fora do raio',
             PKG_COMUNIDADE.esta_no_raio(v_gustavo, v_com_anarosa) = 0);

    -- Conta só as comunidades da carga (outras, criadas pelas APIs, podem estar perto também)
    v_num := 0;
    v_max_dist := 0;
    v_cursor := PKG_COMUNIDADE.comunidades_proximas(v_ana);
    LOOP
        FETCH v_cursor INTO v_c_id, v_c_nome, v_c_gestor, v_c_org, v_c_dist;
        EXIT WHEN v_cursor%NOTFOUND;
        v_num := v_num + eh_comunidade_teste(v_c_id);
        v_max_dist := GREATEST(v_max_dist, v_c_dist);
    END LOOP;
    CLOSE v_cursor;
    verifica('T10 comunidades_proximas: Ana tem as 2 comunidades de teste da Vila Mariana, todas a até 3 km',
             v_num = 2 AND v_max_dist <= 3, v_num || ' de teste; maior distância ' || TO_CHAR(v_max_dist, 'FM990.00') || ' km');

    v_num := 0;
    v_cursor := PKG_COMUNIDADE.comunidades_proximas(v_gustavo);
    LOOP
        FETCH v_cursor INTO v_c_id, v_c_nome, v_c_gestor, v_c_org, v_c_dist;
        EXIT WHEN v_cursor%NOTFOUND;
        v_num := v_num + eh_comunidade_teste(v_c_id);
    END LOOP;
    CLOSE v_cursor;
    verifica('T11 comunidades_proximas: Gustavo (Santo Amaro) não tem nenhuma de teste', v_num = 0, v_num || ' comunidade(s)');

    BEGIN
        v_num := PKG_COMUNIDADE.esta_no_raio(-1, v_com_anarosa);
        verifica('T12 esta_no_raio: usuário inexistente dá erro', FALSE, 'não deu erro');
    EXCEPTION
        WHEN OTHERS THEN
            erro_esperado('T12 esta_no_raio: usuário inexistente dá erro', -20008, SQLCODE, SQLERRM);
    END;

    DBMS_OUTPUT.PUT_LINE('    listar_proximas da Ana:');
    PKG_COMUNIDADE.listar_proximas(v_ana);

    -- -----------------------------------------------------------------
    -- Procedimentos e PKG_PROBLEMA: adoção
    -- -----------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- Adoção (PRC_ADOTAR_PROBLEMA / PKG_PROBLEMA.adotar) ---');

    BEGIN
        PRC_ADOTAR_PROBLEMA(v_p_lixo, v_ana);
        verifica('T13 morador não pode adotar', FALSE, 'não deu erro');
    EXCEPTION
        WHEN OTHERS THEN
            erro_esperado('T13 morador não pode adotar', -20002, SQLCODE, SQLERRM);
    END;

    BEGIN
        PRC_ADOTAR_PROBLEMA(v_p_lixo, v_gestor_pin);
        verifica('T14 gestor de outra comunidade não pode adotar', FALSE, 'não deu erro');
    EXCEPTION
        WHEN OTHERS THEN
            erro_esperado('T14 gestor de outra comunidade não pode adotar', -20002, SQLCODE, SQLERRM);
    END;

    BEGIN
        PRC_ADOTAR_PROBLEMA(-1, v_gestor_vm);
        verifica('T15 problema inexistente dá erro', FALSE, 'não deu erro');
    EXCEPTION
        WHEN OTHERS THEN
            erro_esperado('T15 problema inexistente dá erro', -20001, SQLCODE, SQLERRM);
    END;

    BEGIN
        PKG_PROBLEMA.adotar(v_p_lixo, v_gestor_vm);
        SELECT ADOTADO, STATUS, ADOTADO_EM INTO v_adotado, v_status, v_data FROM RF_PROBLEMA WHERE ID = v_p_lixo;
        verifica('T16 gestor da comunidade adota: ADOTADO = 1, PENDENTE, com data',
                 v_adotado = 1 AND v_status = 'PENDENTE' AND v_data IS NOT NULL, v_status);
    EXCEPTION
        WHEN OTHERS THEN
            verifica('T16 gestor da comunidade adota', FALSE, SQLERRM);
    END;

    BEGIN
        PKG_PROBLEMA.adotar(v_p_lixo, v_gestor_vm);
        verifica('T17 adotar de novo dá erro', FALSE, 'não deu erro');
    EXCEPTION
        WHEN OTHERS THEN
            erro_esperado('T17 adotar de novo dá erro', -20003, SQLCODE, SQLERRM);
    END;

    -- -----------------------------------------------------------------
    -- Procedimentos e PKG_PROBLEMA: status
    -- -----------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- Status (PRC_ALTERAR_STATUS / PKG_PROBLEMA.alterar_status) ---');

    BEGIN
        PKG_PROBLEMA.alterar_status(v_p_lixo, v_gestor_vm, 'EM_ANDAMENTO');
        SELECT STATUS INTO v_status FROM RF_PROBLEMA WHERE ID = v_p_lixo;
        verifica('T18 PENDENTE -> EM_ANDAMENTO', v_status = 'EM_ANDAMENTO', v_status);
    EXCEPTION
        WHEN OTHERS THEN
            verifica('T18 PENDENTE -> EM_ANDAMENTO', FALSE, SQLERRM);
    END;

    BEGIN
        PRC_ALTERAR_STATUS(v_p_lixo, v_gestor_vm, 'resolvido');  -- minúsculo também vale
        SELECT STATUS INTO v_status FROM RF_PROBLEMA WHERE ID = v_p_lixo;
        verifica('T19 EM_ANDAMENTO -> RESOLVIDO', v_status = 'RESOLVIDO', v_status);
    EXCEPTION
        WHEN OTHERS THEN
            verifica('T19 EM_ANDAMENTO -> RESOLVIDO', FALSE, SQLERRM);
    END;

    BEGIN
        PRC_ALTERAR_STATUS(v_p_lixo, v_gestor_vm, 'PENDENTE');
        verifica('T20 RESOLVIDO -> PENDENTE não é permitido', FALSE, 'não deu erro');
    EXCEPTION
        WHEN OTHERS THEN
            erro_esperado('T20 RESOLVIDO -> PENDENTE não é permitido', -20006, SQLCODE, SQLERRM);
    END;

    BEGIN
        PRC_ALTERAR_STATUS(v_p_ciclovia, v_gestor_pin, 'RESOLVIDO');
        verifica('T21 PENDENTE -> RESOLVIDO direto não é permitido', FALSE, 'não deu erro');
    EXCEPTION
        WHEN OTHERS THEN
            erro_esperado('T21 PENDENTE -> RESOLVIDO direto não é permitido', -20006, SQLCODE, SQLERRM);
    END;

    BEGIN
        PRC_ALTERAR_STATUS(v_p_calcada, v_gestor_vm, 'EM_ANDAMENTO');
        verifica('T22 problema não adotado não muda de status', FALSE, 'não deu erro');
    EXCEPTION
        WHEN OTHERS THEN
            erro_esperado('T22 problema não adotado não muda de status', -20004, SQLCODE, SQLERRM);
    END;

    BEGIN
        PRC_ALTERAR_STATUS(v_p_ciclovia, v_gestor_pin, 'CONCLUIDO');
        verifica('T23 status inexistente dá erro', FALSE, 'não deu erro');
    EXCEPTION
        WHEN OTHERS THEN
            erro_esperado('T23 status inexistente dá erro', -20005, SQLCODE, SQLERRM);
    END;

    BEGIN
        PRC_ALTERAR_STATUS(v_p_ciclovia, v_gestor_vm, 'EM_ANDAMENTO');
        verifica('T24 gestor de outra comunidade não muda status', FALSE, 'não deu erro');
    EXCEPTION
        WHEN OTHERS THEN
            erro_esperado('T24 gestor de outra comunidade não muda status', -20002, SQLCODE, SQLERRM);
    END;

    -- -----------------------------------------------------------------
    -- PKG_PROBLEMA: contagens e ranking
    -- -----------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- PKG_PROBLEMA ---');

    verifica('T25 total_apoios do pacote igual à FN_TOTAL_APOIOS',
             PKG_PROBLEMA.total_apoios(v_p_buraco) = FN_TOTAL_APOIOS(v_p_buraco));

    v_num := PKG_PROBLEMA.total_por_status(v_com_anarosa, 'RESOLVIDO');
    verifica('T26 total_por_status: Ana Rosa tem 2 resolvidos (carga + T19)', v_num = 2, v_num || ' problema(s)');

    v_num := PKG_PROBLEMA.total_por_status(v_com_anarosa, NULL);
    verifica('T27 total_por_status: Ana Rosa tem 1 no feed (o bueiro)', v_num = 1, v_num || ' problema(s)');

    DBMS_OUTPUT.PUT_LINE('    listar_mais_apoiados da Ana Rosa:');
    PKG_PROBLEMA.listar_mais_apoiados(v_com_anarosa, 3);

    -- -----------------------------------------------------------------
    -- Gatilhos
    -- -----------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('--- Gatilhos ---');

    -- Auditoria de UPDATE
    SELECT COUNT(*) INTO v_num FROM RF_AUDITORIA_PROBLEMA WHERE ID_PROBLEMA = v_p_buraco;
    UPDATE RF_PROBLEMA SET PRIORIDADE = 'ALTA' WHERE ID = v_p_buraco;
    SELECT COUNT(*) INTO v_num2 FROM RF_AUDITORIA_PROBLEMA WHERE ID_PROBLEMA = v_p_buraco;
    SELECT VALOR_ANTIGO, VALOR_NOVO INTO v_txt, v_txt2
      FROM RF_AUDITORIA_PROBLEMA
     WHERE ID_PROBLEMA = v_p_buraco
     ORDER BY ID DESC
     FETCH FIRST 1 ROW ONLY;
    verifica('T28 auditoria grava o UPDATE com valor antigo e novo',
             v_num2 = v_num + 1 AND v_txt LIKE '%prioridade=null%' AND v_txt2 LIKE '%prioridade=ALTA%',
             (v_num2 - v_num) || ' linha(s) nova(s)');

    -- Data de adoção: só ADOTADO = 1, sem data nem status
    BEGIN
        UPDATE RF_PROBLEMA SET ADOTADO = 1 WHERE ID = v_p_bueiro;
        SELECT STATUS, ADOTADO_EM INTO v_status, v_data FROM RF_PROBLEMA WHERE ID = v_p_bueiro;
        verifica('T29 gatilho de adoção preenche ADOTADO_EM e STATUS',
                 v_data IS NOT NULL AND v_status = 'PENDENTE',
                 v_status || ' em ' || TO_CHAR(v_data, 'DD/MM/YYYY HH24:MI'));
    EXCEPTION
        WHEN OTHERS THEN
            verifica('T29 gatilho de adoção preenche ADOTADO_EM e STATUS', FALSE, SQLERRM);
    END;

    -- Auditoria de DELETE (a linha fica mesmo com o problema apagado)
    DELETE FROM RF_PROBLEMA WHERE ID = v_p_bueiro;
    SELECT COUNT(*) INTO v_num FROM RF_AUDITORIA_PROBLEMA WHERE ID_PROBLEMA = v_p_bueiro AND OPERACAO = 'DELETE';
    verifica('T30 auditoria grava o DELETE', v_num = 1);

    -- -----------------------------------------------------------------
    -- Resumo e limpeza
    -- -----------------------------------------------------------------
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('======================================================');
    DBMS_OUTPUT.PUT_LINE('Resultado: ' || v_ok || ' OK, ' || v_falhas || ' falha(s) de ' || (v_ok + v_falhas) || ' testes.');
    DBMS_OUTPUT.PUT_LINE('Alterações feitas pelos testes desfeitas com ROLLBACK.');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('Erro inesperado nos testes (alterações desfeitas): ' || SQLERRM);
        RAISE;
END;
/
