

BEGIN
	/*
	Regras :
	Verificar se possui ocorr�ncia, senao NULL; OK
	Verificar se tem as 11h da ultima parede, senao NULL; OK
	Verificar se est� agulhado, senao NULL;
	Verificar frequencia, senao 0; OK
	Verificar se est� engajado, se sim 1. OK
	*/
	SET DATEFORMAT dmy;
		
	DECLARE @P_DATA DATETIME, @P_DATAFIM DATETIME, @TEM_ASSIDUIDADE INT, @P_MES INT, @P_ANO INT, @MATRICULA INT, @P_PAREDE INT, @REQUISICAO INT, @FUNCAO INT, @DIA DATE;
	SET @P_ANO = 2015;
	SET @P_MES = 5;
	
	SET @TEM_ASSIDUIDADE = 0;
	
	DECLARE C_TRABALHADOR CURSOR FOR
		SELECT T.MATRICULA FROM TRABALHADOR T 
			WHERE	T.EFETIVO = 1
					AND T.EXCLUIDO = 0;
		
	OPEN C_TRABALHADOR;
	FETCH NEXT FROM C_TRABALHADOR INTO @MATRICULA;
	WHILE @@FETCH_STATUS = 0
	BEGIN	
		SET @P_DATA = '01/'+CAST(@P_MES AS varchar)+'/'+CAST(@P_ANO AS varchar)
		SET @P_DATAFIM = '01/'+CAST(@P_MES+1 AS varchar)+'/'+CAST(@P_ANO AS varchar)
		SET @P_DATAFIM = DATEADD(DAY, -1, @P_DATAFIM)
		WHILE @P_DATA <= @P_DATAFIM
		BEGIN
			DECLARE @TEM_OCORRENCIA VARCHAR(MAX);
			SET @TEM_OCORRENCIA = (SELECT TOP 1 DESCRICAO FROM OCORRENCIA O 
				WHERE O.MATRICULA = @MATRICULA
					AND @P_DATA BETWEEN O.INICIO AND O.TERMINO);
			
			SET @P_PAREDE = 1;
			
			IF @TEM_OCORRENCIA <> '' --Caso exista ocorr�ncia ja insere uma 
			BEGIN
				INSERT INTO ASSIDUIDADE(MATRICULA, PAREDE, DATA, SITUACAO, REQUISICAO, OBSERVACAO)
					VALUES(@MATRICULA, NULL, @P_DATA, NULL, NULL, @TEM_OCORRENCIA);
			END
			ELSE
			BEGIN
				DECLARE @TEM_FREQUENCIA INT; --Se existe frequ�ncia
				DECLARE @INTERVALO INT; --Qual o intervalo
								
				SET @TEM_FREQUENCIA = (SELECT COUNT(*) FROM FREQUENCIA F 
					WHERE F.MATRICULA = @MATRICULA
						AND F.DIA = @P_DATA);
				
				IF @TEM_FREQUENCIA = 0
				BEGIN
					INSERT INTO ASSIDUIDADE(MATRICULA, PAREDE, DATA, SITUACAO, REQUISICAO, OBSERVACAO)
							VALUES(@MATRICULA, @P_PAREDE, @P_DATA, 0, 0, 'Sem frequ�ncia');
					BREAK;
				END
				
				SET @INTERVALO = (SELECT TOP 1 INTERVALO FROM FREQUENCIA F 
					WHERE F.MATRICULA = @MATRICULA
						AND F.DIA = @P_DATA);
					
				DECLARE @SITUACAO_FREQ INT; --Situa��o da frequencia
				SET @SITUACAO_FREQ = (SELECT TOP 1 SITUACAO FROM FREQUENCIA F 
					WHERE F.MATRICULA = @MATRICULA
						AND F.DIA = @P_DATA);
							
									
				WHILE @P_PAREDE <= 4
				BEGIN
					DECLARE @ERA_AGULHADO INT;
					DECLARE @CONT_REQFUNCAO INT; 
					SET @CONT_REQFUNCAO = (SELECT COUNT(RF.FUNCAO) FROM REQFUNCAO RF 
							INNER JOIN REQUISICAO R ON R.REQUISICAO = RF.REQUISICAO
							WHERE RF.MATRICULA = @MATRICULA AND R.PAREDE = @P_PAREDE);
										
					SET @ERA_AGULHADO = (SELECT COUNT(*) FROM AGULHADO A 
						WHERE 
							A.MATRICULA = @MATRICULA 
							AND A.PAREDE = @P_PAREDE
							AND A.DATA = @DIA);
									
					SET @TEM_ASSIDUIDADE = (SELECT COUNT(*) FROM ASSIDUIDADE 
						WHERE MATRICULA = @MATRICULA AND PAREDE = @P_PAREDE AND DATA = @P_DATA)
					
					SET @REQUISICAO = (SELECT R.REQUISICAO FROM REQUISICAO R INNER JOIN REQFUNCAO RF ON R.REQUISICAO = RF.REQUISICAO 
						WHERE RF.MATRICULA = @MATRICULA 
						AND R.PAREDE = @P_PAREDE
						AND R.DIA = @P_DATA);
					
					IF @TEM_ASSIDUIDADE = 0 
					BEGIN
						IF @INTERVALO > 1
						BEGIN
							INSERT INTO ASSIDUIDADE(MATRICULA, PAREDE, DATA, SITUACAO, REQUISICAO, OBSERVACAO)
							VALUES(@MATRICULA, @P_PAREDE, @P_DATA, null, 0, 'TPA com menos de 11h');
						END
						
						IF @SITUACAO_FREQ = 2 AND @CONT_REQFUNCAO > 1
						BEGIN
							INSERT INTO ASSIDUIDADE(MATRICULA, PAREDE, DATA, SITUACAO, REQUISICAO, OBSERVACAO)
								VALUES(@MATRICULA, @P_PAREDE, @P_DATA, 0, NULL, 'TPA embarcado foi engajado eu outra requisi��o');
						END
						ELSE
						BEGIN	
							INSERT INTO ASSIDUIDADE(MATRICULA, PAREDE, DATA, SITUACAO, REQUISICAO, OBSERVACAO)
								VALUES(@MATRICULA, @P_PAREDE, @P_DATA, 1, @REQUISICAO, '');
						END
					END
					
					SET @P_PAREDE = @P_PAREDE + 1; 
				END
			END
											
			SET @P_DATA = DATEADD(DAY, 1, @P_DATA);
		END
		FETCH NEXT FROM C_TRABALHADOR INTO @MATRICULA;
	END
	
	CLOSE C_TRABALHADOR;
	DEALLOCATE C_TRABALHADOR;
	/*
	WHILE @@FETCH_STATUS = 0
	BEGIN
		DECLARE @TEM_OCORRENCIA VARCHAR(MAX);
			SET @TEM_OCORRENCIA = (SELECT TOP 1 DESCRICAO FROM OCORRENCIA O 
				WHERE O.MATRICULA = @MATRICULA
					AND @DIA BETWEEN O.INICIO AND O.TERMINO);
					
	
		SET @PAREDE = 1;
		WHILE @PAREDE < 5
		BEGIN
			
		
			DECLARE C_REQFUNCAO CURSOR FOR
				SELECT RF.FUNCAO, RF.REQUISICAO, R.DIA FROM REQFUNCAO RF INNER JOIN REQUISICAO R ON R.REQUISICAO = RF.REQUISICAO
					WHERE RF.MATRICULA = @MATRICULA AND R.PAREDE = @CONTADOR;
			
			OPEN C_REQFUNCAO;
			FETCH NEXT FROM C_REQFUNCAO INTO @FUNCAO, @REQUISICAO, @DIA;
			
			WHILE @@FETCH_STATUS = 0
			BEGINj
				INSERT INTO ASSIDUIDADE(MATRICULA, PAREDE, DATA, SITUACAO, REQUISICAO, OBSERVACAO, PORCENTAGEM, VAGAS)
					VALUES(@MATRICULA, @PAREDE, @DIA, NULL, @REQUISICAO, '', 0, 0);
			
			
			END		
			
			SET @PAREDE = @PAREDE + 1;
		END
	
		
		
		DECLARE @TEM_OCORRENCIA VARCHAR(MAX);
		SET @TEM_OCORRENCIA = (SELECT TOP 1 DESCRICAO FROM OCORRENCIA O 
			WHERE O.MATRICULA = @MATRICULA
				AND @DIA BETWEEN O.INICIO AND O.TERMINO);
				
		IF @TEM_OCORRENCIA <> '' --Existe alguma ocorr�ncia
		BEGIN
			INSERT INTO ASSIDUIDADE(MATRICULA, PAREDE, DATA, SITUACAO, OBSERVACAO, PORCENTAGEM, VAGAS)
				VALUES(@MATRICULA, @PAREDE, @DIA, 0, @TEM_OCORRENCIA, 0, 0);
		END
		ELSE
		BEGIN
			DECLARE @ERA_BOCA INT;
			SET @ERA_BOCA = (SELECT COUNT(*) FROM AGULHADO A 
				WHERE 
					A.MATRICULA = @MATRICULA 
					AND A.PAREDE = @PAREDE
					AND A.DATA = @DIA);
					
			DECLARE @VAGAS INT;
			
			SET @VAGAS = (SELECT TOP 1
				(SELECT COUNT(*) FROM REQFUNCAO RF1 WHERE RF1.FUNCAO = RF.FUNCAO AND RF1.REQUISICAO = R.REQUISICAO) AS VAGAS 
				FROM REQFUNCAO RF 
				INNER JOIN REQUISICAO R ON RF.REQUISICAO = R.REQUISICAO
				WHERE RF.MATRICULA = @MATRICULA 
				AND R.PAREDE = @PAREDE
				AND R.DIA = @DIA);
			
			DECLARE @REQUISICAO INT;
			SET @REQUISICAO = (SELECT R.REQUISICAO FROM REQUISICAO R INNER JOIN REQFUNCAO RF ON R.REQUISICAO = RF.REQUISICAO 
				WHERE RF.MATRICULA = @MATRICULA 
				AND R.PAREDE = @PAREDE
				AND R.DIA = @DIA);
					
			IF @ERA_BOCA > 0 AND @VAGAS IS NULL --Se o funcion�rio � o da vez E NAO PREENCHOU NENHUMA VAGA
			BEGIN
				INSERT INTO ASSIDUIDADE(MATRICULA, PAREDE, DATA, SITUACAO, OBSERVACAO, REQUISICAO, PORCENTAGEM, VAGAS)
					VALUES(@MATRICULA, @PAREDE, @DIA, 0, 'Era Boca, mas n�o preenchou nenhuma vaga.', @REQUISICAO, 0, @VAGAS);
			END
			ELSE IF @ERA_BOCA > 0 AND @VAGAS > 0  --Se o funcion�rio � o da vez E PREENCHOU AS VAGAS
			BEGIN
				INSERT INTO ASSIDUIDADE(MATRICULA, PAREDE, DATA, SITUACAO, OBSERVACAO, REQUISICAO, PORCENTAGEM, VAGAS)
					VALUES(@MATRICULA, @PAREDE, @DIA, 1, 'Era Boca, E preenchou nenhuma vaga', @REQUISICAO, 0, @VAGAS);
			END
			ELSE IF @VAGAS > 0 
			BEGIN
				INSERT INTO ASSIDUIDADE(MATRICULA, PAREDE, DATA, SITUACAO, OBSERVACAO, REQUISICAO, PORCENTAGEM, VAGAS)
					VALUES(@MATRICULA, @PAREDE, @DIA, 1, '', @REQUISICAO, 0, @VAGAS);
			END
			ELSE
			BEGIN
				INSERT INTO ASSIDUIDADE(MATRICULA, PAREDE, DATA, SITUACAO, OBSERVACAO, REQUISICAO, PORCENTAGEM, VAGAS)
					VALUES(@MATRICULA, @PAREDE, @DIA, 0, '', @REQUISICAO, 0, @VAGAS);
			END
		END
		
		FETCH NEXT FROM C_TRABALHADOR INTO @MATRICULA;
	END 
	CLOSE C_TRABALHADOR;
	DEALLOCATE C_TRABALHADOR;
	*/
END;