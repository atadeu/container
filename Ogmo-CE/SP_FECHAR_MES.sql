USE [ogmocedesenv]
GO
/****** Object:  StoredProcedure [dbo].[SP_FECHAR_MES]    Script Date: 11/11/2015 09:38:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





ALTER PROCEDURE [dbo].[SP_FECHAR_MES] 
	@TANO AS INT = 0,
	@TMES AS INT = 0
	
AS BEGIN
	--SET DATEFORMAT dmy
	SET NOCOUNT ON
	
	DECLARE @MENSAGEM AS INT
	
	DECLARE @MATRICULA AS INT
	DECLARE @MMO AS MONEY
	DECLARE @RSR AS MONEY
	DECLARE @ADR AS MONEY
	DECLARE @FERIAS AS MONEY
	DECLARE @SAL13 AS MONEY
	DECLARE @DEPENDENTE AS INT
	DECLARE @DAS AS INT
	DECLARE @INSSFERIAS AS MONEY
	DECLARE @VALDEP AS MONEY
	DECLARE @BASEINSSFERIAS AS MONEY
	DECLARE @BASEIRRFFERIASSEMPENSAOMMO AS MONEY
	DECLARE @BASEIRRFFERIASSEMPENSAOFERIAS AS MONEY
	DECLARE @IRRFMMO AS MONEY
	DECLARE @IRRFFERIAS AS MONEY
	DECLARE @P_PENSIONISTA AS INT
	DECLARE @P_REGRA AS INT
	DECLARE @P_FATOR AS FLOAT
	DECLARE @P_DESCONTO_LIMITE AS MONEY
	DECLARE @P_DESCONTO_IRRF AS INT
	DECLARE @P_DESCONTO_INSS AS INT
	DECLARE @P_DESCONTO_DAS	AS INT
	DECLARE @BASEPENSAOFERIAS_PENSIONISTA AS MONEY
	DECLARE @PENSAOFERIAS_PENSIONISTA AS MONEY
	DECLARE @PENSAOFERIAS AS MONEY
	DECLARE @SALARIOMININO AS MONEY
	DECLARE @BASEIRRFFERIASCOMPENSAOMMO AS MONEY
	DECLARE @BASEIRRFFERIASCOMPENSAOFERIAS AS MONEY
	DECLARE @BASEINSSSAL13 AS MONEY
	DECLARE @BASEIRRFSAL13SEMPENSAO AS MONEY
	DECLARE @INSSSAL13 AS MONEY
	DECLARE @IRRFSAL13 AS MONEY
	DECLARE @PENSAOSAL13 AS MONEY
	DECLARE @PENSAO_FERIAS AS TINYINT
	DECLARE @PENSAO_SAL13 AS TINYINT
	DECLARE @BASEPENSAOSAL13_PENSIONISTA AS MONEY
	DECLARE @PENSAOSAL13_PENSIONISTA AS MONEY
	DECLARE @BASEIRRFSAL13COMPENSAO AS MONEY
	DECLARE @OP_OP AS INT
	DECLARE @OP_MATRICULA AS INT
	DECLARE @OP_INNS AS MONEY
	DECLARE @LIQFERIAS AS MONEY
	DECLARE @LIQSAL13 AS MONEY
	DECLARE @DESCPROGR_DESCONTO AS INT
	DECLARE @DESCPROGR_VALOR AS FLOAT
	DECLARE @DESCPROGR_MAXPERCLIQUIDO AS FLOAT
	DECLARE @DESCPROGR_VALOR_A_APLICAR AS FLOAT
	DECLARE @DESCPROGR_VALOR_SOBRA AS FLOAT
	DECLARE @DESCPROGR_VALOR_FERIAS AS FLOAT
	DECLARE @DESCPROGR_VALOR_SAL13 AS FLOAT
	DECLARE @INSSMENSAL AS MONEY
	DECLARE @INSSANO AS MONEY
	DECLARE @PENSAOVALOR AS MONEY
	DECLARE @PENSAOMENSAL AS MONEY
	DECLARE @DESCONTOVALOR AS MONEY
	DECLARE @FERIASMES AS DECIMAL(18, 8)
	DECLARE @FERIASINSSMES AS DECIMAL(18, 8)
	DECLARE @SAL13MES AS DECIMAL(18, 8)
	DECLARE @SAL13INSSMES AS DECIMAL(18, 8)
	DECLARE @PERCMES AS DECIMAL(18, 8)
	DECLARE @IRRFMENSAL AS MONEY
	DECLARE @DTINICIO DATE;
	DECLARE @DTFIM DATE;
	
	BEGIN TRY
		CLOSE CurOPMat;
		DEALLOCATE CurOPMat;
	END TRY
	BEGIN CATCH
	END CATCH

	BEGIN TRY
		CLOSE CurEncargoMes;
		DEALLOCATE CurEncargoMes;
	END TRY
	BEGIN CATCH
	END CATCH

	BEGIN TRY
		CLOSE CurPensionista;
		DEALLOCATE CurPensionista;
	END TRY
	BEGIN CATCH
	END CATCH

	BEGIN TRY
		CLOSE CurDescontos;
		DEALLOCATE CurDescontos;
	END TRY
	BEGIN CATCH
	END CATCH
	
	SET @MENSAGEM = 0
	
	IF @TANO = 0 OR @TMES = 0 BEGIN
		SET @MENSAGEM = 0
		GOTO ERROANOMES
	END
	
	IF EXISTS(SELECT TOP 1 1 FROM ENCARGOFERIASSAL13 WHERE ANO = @TANO AND MES = @TMES) BEGIN
		SET @MENSAGEM = 0
		GOTO ERROFECHOEXISTE
	END
	
	BEGIN TRANSACTION;

	BEGIN TRY	
		INSERT INTO ENCARGOFERIASSAL13 (MATRICULA, ANO, MES)
		SELECT DISTINCT REQFUNCAO.MATRICULA, @TANO, @TMES 
		FROM REQFUNCAOENCARGO
		JOIN REQFUNCAO ON REQFUNCAO.CFUNCAO = REQFUNCAOENCARGO.CFUNCAO
		WHERE YEAR(REQFUNCAO.CALCULADO) = @TANO 
		  AND MONTH(REQFUNCAO.CALCULADO) = @TMES
		  AND REQFUNCAO.MATRICULA is not null

		SET @SALARIOMININO = 0
			
		-- Recolhe o salário mínimo em vigor
		SELECT TOP 1 @SALARIOMININO = VALOR FROM SALARIOMINIMO where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO)
		
		SET @SALARIOMININO = ISNULL(@SALARIOMININO, 0)
		
        DECLARE CurEncargoMes --Nome do cursor
        CURSOR FOR Select ENCARGOFERIASSAL13.MATRICULA
	  		FROM ENCARGOFERIASSAL13
			WHERE ENCARGOFERIASSAL13.ANO = @TANO
			AND ENCARGOFERIASSAL13.MES = @TMES
		
		OPEN CurEncargoMes
		FETCH NEXT FROM CurEncargoMes
		INTO @MATRICULA
		
		WHILE @@FETCH_STATUS = 0 BEGIN
			-- Recolhe os valores de MMO, RSR e Insalubridade, INSS, IRRF, PENSAO, DAS, FGTS, DEPENDENTE, FERIAS, SAL13, INSSPAT e INSSPATOUTRO
			
			SET @DTINICIO = CONVERT(VARCHAR, @TANO) + '-' + CONVERT(VARCHAR, @TMES) + '-1';
			SET @DTFIM  = DATEADD(DAY, -1, DATEADD(MONTH, 1, @DTINICIO));
			
			UPDATE ENCARGOFERIASSAL13 
				SET MMO = isnull((select sum(rf2.mmo)
								from reqfuncao rf2
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)
								and rf2.visualizaquadro = 1
								and r.cancelado = 0), 0),
								
					RSR = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								and (ev2.regra = 17)
								and rf2.visualizaquadro = 1
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)
								and r.cancelado = 0),0),
					
					MMOSEMDSR = isnull((select sum(rf2.mmo)
								from reqfuncao rf2
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)
								and rf2.visualizaquadro = 1
								and r.cancelado = 0), 0) 
								-
								isnull((select abs(sum(rfe2.valor))
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								and (ev2.regra = 17)
								and rf2.visualizaquadro = 1
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)
								and r.cancelado = 0),0),
								
					AdicionalRisco = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								and (ev2.regra = 20)
								and rf2.visualizaquadro = 1
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)
								and r.cancelado = 0),0),
					
					MMOTOTAL = isnull((select sum(rf2.mmo)
								from reqfuncao rf2
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)
								and rf2.visualizaquadro = 1
								and r.cancelado = 0), 0) 
								+
								isnull((select abs(sum(rfe2.valor))
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								and (ev2.regra = 20)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)
								and rf2.visualizaquadro = 1
								and r.cancelado = 0),0),
					
					INSS = isnull((select abs(sum(rfe2.valor))
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								and (ev2.regra IN (4,6))
								and rf2.visualizaquadro = 1
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					IRRF = isnull((select abs(sum(rfe2.valor))
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								and (ev2.regra in (5,7))
								and rf2.visualizaquadro = 1
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					PENSAO = isnull((select abs(sum(rfe2.valor))
								from REQFUNCAOPENSAO rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								and rf2.visualizaquadro = 1
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					DAS = isnull((select abs(sum(rfe2.valor))
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								and (ev2.regra = 8)
								and rf2.visualizaquadro = 1
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					FGTS = isnull((SELECT SUM(rfe.VALOR) 
								FROM REQFUNCAOENCARGO AS rfe 
								inner join reqfuncao rf2 on rf2.cfuncao = rfe.cfuncao
								INNER JOIN ENCARGOVIGENCIA AS ev ON rfe.ENCARGOVIGENCIA = ev.ENCARGOVIGENCIA
								WHERE (rf2.matricula = @MATRICULA)
								AND (ev.FGTS = 1)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					DEPENDENTE = (Select Count(Dependente)
								From DEPENDENTE 
								Where DEPENDENTE.MATRICULA = @MATRICULA AND DEPENDENTE.IRRF = 1 
								and DEPENDENTE.INATIVO = 0 
								AND convert(varchar(4), @TANO) + '-' + RIGHT('00' + convert(varchar(2),@TMES),2) + '-01' BETWEEN DEPENDENTE.VIGENCIAI AND DEPENDENTE.VIGENCIAF),
					
					FERIAS = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								and (ev2.ferias = 1)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					SAL13 = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								and (ev2.SAL13 = 1)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					INSSPAT = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								and (ev2.INSSPAT = 1)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					INSSPATOUTRO = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (ev2.INSSPATOUTRO = 1)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					INSSPATSAL13 = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (ev2.INSSPATSAL13 = 1)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					INSSPATFERIAS = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (ev2.INSSPATFERIAS = 1)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					INSSPATFERIASOUTRO = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (ev2.INSSPATFERIASOUTRO = 1)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					INSSPATSAL13OUTRO = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (ev2.INSSPATSAL13OUTRO = 1)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					LIQUIDO = isnull((select abs(sum(rf2.LIQUIDO))
								from reqfuncao rf2 
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								and rf2.visualizaquadro = 1
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					DESCONTOS = isnull((select sum(VALOR) 
								from REQFUNCAODESC rfd 
								inner join reqfuncao rf2 on rf2.CFUNCAO = rfd.CFUNCAO 
								Where (rf2.matricula = @MATRICULA)
								and rf2.visualizaquadro = 1
								and year(rf2.CALCULADO) = @TANO and MONTH(rf2.CALCULADO) = @TMES), 0),
					
					TXOGMO = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (ev2.TXOGMO = 1)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					TXEPI = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								  
								and (ev2.TXEPI = 1)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					TXBANCARIA = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								and (ev2.TXBANCARIA = 1)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					TXCUSTOVARIAVEL = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								and (ev2.TXCUSTOVARIAVEL = 1)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								  
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					FGTSMENSAL = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								and (ev2.ENCARGO = 10) 
								AND (ev2.ENCARGOGRUPO = 4)
								
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					FGTSFERIAS = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								and (ev2.ENCARGO = 6) 
								AND (ev2.ENCARGOGRUPO = 4)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					FGTSSAL13 = isnull((select sum(rfe2.valor)
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								Where (rf2.matricula = @MATRICULA)
								and (ev2.ENCARGO = 9) 
								AND (ev2.ENCARGOGRUPO = 4)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					TRANSPORTE = isnull((select abs(sum(rfe2.valor))
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
								and (ev2.regra = 15)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
								
					TRANSPORTETPA = isnull((select abs(sum(rfe2.valor))
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								And rf2.VisualizaQuadro = 1
								and (ev2.regra = 14)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
								
					ASSAP = isnull((select abs(sum(rfe2.valor))
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								And (rf2.VisualizaQuadro = 1)
								and (ev2.regra = 21)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					
					CXAS = isnull((select abs(sum(rfe2.valor))
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								And (rf2.VisualizaQuadro = 1)
								and (ev2.regra = 22)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),

					FUNDOSOC = isnull((select abs(sum(rfe2.valor))
								from reqfuncaoencargo rfe2
								inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
								inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
								inner join requisicao r on r.requisicao = rf2.requisicao
								where (rf2.matricula = @MATRICULA)
								And (rf2.VisualizaQuadro = 1)
								and (ev2.regra = 23)
								and (year(rf2.calculado) = @TANO)
								and (month(rf2.calculado) = @TMES)), 0),
					ENGAJAMENTO = isnull((SELECT COUNT(*) 
							FROM REQFUNCAO RQ 
							INNER JOIN REQUISICAO R ON R.REQUISICAO = RQ.REQUISICAO 
							WHERE R.CANCELADO = 0 AND  RQ.VISUALIZAQUADRO = 1 
							AND (RQ.CALCULADO BETWEEN @DTINICIO 
							AND @DTFIM) AND MATRICULA = @MATRICULA),0),
					PUNICOES = ISNULL((SELECT COUNT(*) 
						FROM OCORRENCIA O 
						INNER JOIN GRUPO G ON O.GRUPO = G.GRUPO 
						WHERE G.PUNICAO = 1  
						AND (O.INICIO) >= @DTINICIO AND (O.TERMINO <= @DTFIM OR O.TERMINO IS NULL)
						AND MATRICULA = @MATRICULA), 0),
					PUNICOESEPI = ISNULL((SELECT COUNT(*) 
						FROM OCORRENCIA O INNER JOIN GRUPO G ON O.GRUPO = G.GRUPO 
						WHERE G.EPI = 1 
						AND (O.INICIO) >= @DTINICIO AND (O.TERMINO <= @DTFIM OR O.TERMINO IS NULL)
						AND MATRICULA = @MATRICULA),0),
					PUNICOESASO = ISNULL((SELECT ISNULL(SUM(DATEDIFF(DAY, O.INICIO, ISNULL(O.TERMINO, GETDATE()))),0) 
						FROM OCORRENCIA O INNER JOIN GRUPO G ON O.GRUPO = G.GRUPO 
						WHERE G.ASO = 1 
						AND (O.INICIO) >= @DTINICIO AND (O.TERMINO <= @DTFIM OR O.TERMINO IS NULL)
						AND MATRICULA = @MATRICULA),0),
					CAPACITACAO = ISNULL((SELECT (CONVERT(MONEY, 
						(SELECT COUNT(*) 
							FROM HABILITACAO WHERE (HABILITADO BETWEEN @DTINICIO AND @DTFIM) AND MATRICULA = @MATRICULA 
							AND (CHAMADA = 1 OR CHAMADA = 3))) * 100) / (SELECT COUNT(*) 
														FROM FUNCAO F 
														WHERE F.CATEGORIA IN (SELECT CATEGORIA FROM TRABALHADOR WHERE MATRICULA = @MATRICULA))),0),
					LISTAMULTIF = ISNULL((SELECT COUNT(*) 
						FROM CAMBIOS C 
						WHERE C. CHAMADA > 3 
						AND MATRICULA = @MATRICULA), 0),
					FALTASTRABALHO = ISNULL((SELECT COUNT(*) 
						FROM OCORRENCIA O INNER JOIN REQFUNCAO RQ ON RQ.CFUNCAO = O.CFUNCAO 
						WHERE (O.INICIO) >= @DTINICIO AND (O.TERMINO <= @DTFIM OR O.TERMINO IS NULL) 
						AND O.GRUPO = 46 AND O.MATRICULA = @MATRICULA),0),
					HRTRABALHADAS = ISNULL((SELECT COUNT(*)*6 
						FROM REQFUNCAO RQ 
						WHERE (RQ.CALCULADO BETWEEN @DTINICIO AND @DTFIM) 
						AND MATRICULA = @MATRICULA),0),
					ACIDENTESTRABALHO = ISNULL((SELECT COUNT(*) 
						FROM OCORRENCIA O INNER JOIN REQFUNCAO RQ ON RQ.CFUNCAO = O.CFUNCAO 
						WHERE (O.INICIO) >= @DTINICIO AND (O.TERMINO <= @DTFIM OR O.TERMINO IS NULL) 
						AND O.GRUPO = 45 
						AND O.MATRICULA = @MATRICULA),0),
					DIASAFASTADOINSS = ISNULL((SELECT COUNT(*) 
						FROM OCORRENCIA 
						WHERE GRUPO = 6 
						AND MATRICULA = @MATRICULA 
						AND (INICIO) >= @DTINICIO AND (TERMINO <= @DTFIM OR TERMINO IS NULL)),0),
					CURSOSEGTRABALHO = ISNULL((SELECT (CASE WHEN 
						(SELECT COUNT(*) FROM CURSO_TURMA CT INNER JOIN CURSO C ON C.CURSO = CT.CURSO AND C.TIPOCURSO = 1 WHERE CT.INICIO >= @DTINICIO) = 0  
							THEN 
								100 
							ELSE 
								(CONVERT(MONEY, (SELECT COUNT(*) FROM CURSO_TURMA_ALUNOS CTA WHERE CTA.CURSO_TURMA IN (SELECT CT.CURSO_TURMA FROM CURSO_TURMA CT INNER JOIN CURSO C ON C.CURSO = CT.CURSO AND C.TIPOCURSO = 1
								WHERE CT.INICIO >= @DTINICIO) AND CTA.MATRICULA = @MATRICULA))*100 / (SELECT COUNT(*) FROM CURSO_TURMA CT INNER JOIN CURSO C ON C.CURSO = CT.CURSO AND C.TIPOCURSO = 1
								WHERE CT.INICIO >= @DTINICIO)) END)),0),
					QUESTIONARIO = 0
								
												
				WHERE ENCARGOFERIASSAL13.MATRICULA = @MATRICULA
				  AND ENCARGOFERIASSAL13.ANO = @TANO
				  AND ENCARGOFERIASSAL13.MES = @TMES
				
			SET @MMO = 0
			SET @RSR = 0
			SET @ADR = 0
			SET @FERIAS = 0
			SET @SAL13 = 0
			SET @DEPENDENTE = 0
			SET @DAS = 0
			SET @INSSMENSAL = 0
			SET @INSSANO = 0
			SET @PENSAOMENSAL = 0
			SET @IRRFMENSAL = 0
			
			SELECT 	@MMO = MMO, @RSR = RSR, @ADR = AdicionalRisco, @FERIAS = FERIAS, @SAL13 = SAL13, @DEPENDENTE = DEPENDENTE, @DAS = DAS, @INSSMENSAL = INSS, @PENSAOMENSAL = PENSAO, @IRRFMENSAL = IRRF
				FROM ENCARGOFERIASSAL13
				WHERE ENCARGOFERIASSAL13.MATRICULA = @MATRICULA
				AND ENCARGOFERIASSAL13.ANO = @TANO
				AND ENCARGOFERIASSAL13.MES = @TMES
			
			SELECT 	@INSSANO = ISNULL(SUM(INSS), 0)
				FROM ENCARGOFERIASSAL13
				WHERE ENCARGOFERIASSAL13.MATRICULA = @MATRICULA
				AND ENCARGOFERIASSAL13.ANO = @TANO
				AND ENCARGOFERIASSAL13.MES <= @TMES
				
			SET @MMO = ISNULL(@MMO, 0)
			SET @RSR = ISNULL(@RSR, 0)
			SET @ADR = ISNULL(@ADR, 0)
			SET @FERIAS = ISNULL(@FERIAS, 0)
			SET @SAL13 = ISNULL(@SAL13, 0)
			SET @DEPENDENTE = ISNULL(@DEPENDENTE, 0)
			SET @DAS = ISNULL(@DAS, 0)
			SET @INSSMENSAL = ISNULL(@INSSMENSAL, 0)
			SET @INSSANO = ISNULL(@INSSANO, 0)
			SET @PENSAOMENSAL = ISNULL(@PENSAOMENSAL, 0)
			SET @IRRFMENSAL = ISNULL(@IRRFMENSAL, 0)
			
			SET @MMO = @MMO + @ADR
			
			SET @VALDEP = 0
			-- Calculo do valor por dependente
			SELECT TOP 1 @VALDEP = DEPENDENTE FROM IRRF WHERE ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) ORDER BY EMVIGOR DESC
			
			SET @VALDEP = ISNULL(@VALDEP, 0)
			
			-- Cálculo do valor base a considerar para a base do INSS de Férias
			SET @BASEINSSFERIAS = @MMO + @FERIAS  --Base de calculo em fortaleza não pega ferias é somente MMO

			-- Cálculo do valor base a considerar para a base do INSS de 13 Sal
			SET @BASEINSSSAL13 = @SAL13
			
			SET @INSSFERIAS = 0
			SET @INSSSAL13 = 0
			
			-- Calculo do INSS de Férias
			SELECT @INSSFERIAS =
				case when @BASEINSSFERIAS <= (select top 1 ate1 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then @BASEINSSFERIAS * ((select top 1 aliquota1 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)
				else case when @BASEINSSFERIAS <= (select top 1 ate2 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then @BASEINSSFERIAS * ((select top 1 aliquota2 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)
				else case when @BASEINSSFERIAS <= (select top 1 ate3 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then @BASEINSSFERIAS * ((select top 1 aliquota3 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)
				else case when @BASEINSSFERIAS <= (select top 1 ate4 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then @BASEINSSFERIAS * ((select top 1 aliquota4 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)
				else (select top 1 ate4 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) * ((select top 1 aliquota4 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100) end end end end
					

			-- Calculo do INSS do 13 Sal
			SELECT @INSSSAL13 =
				case when @BASEINSSSAL13 <= (select top 1 ate1 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then @BASEINSSSAL13 * ((select top 1 aliquota1 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)
				else case when @BASEINSSSAL13 <= (select top 1 ate2 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then @BASEINSSSAL13 * ((select top 1 aliquota2 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)
				else case when @BASEINSSSAL13 <= (select top 1 ate3 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then @BASEINSSSAL13 * ((select top 1 aliquota3 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)
				else case when @BASEINSSSAL13 <= (select top 1 ate4 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then @BASEINSSSAL13 * ((select top 1 aliquota4 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)
				else (select top 1 ate4 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) * ((select top 1 aliquota4 from inss where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100) end end end end
			
			SET @INSSFERIAS = ROUND(ISNULL(@INSSFERIAS, 0), 2)
			SET @INSSSAL13 = ROUND(ISNULL(@INSSSAL13, 0), 2)


			--SET @INSSFERIAS = @INSSFERIAS - (@INSSMENSAL - @INSSFERIAS)
			SET @INSSFERIAS = @INSSFERIAS - @INSSMENSAL
						
			IF @INSSFERIAS < 0 BEGIN
				SET @INSSFERIAS = 0
			END
			
			IF @INSSSAL13 < 0 BEGIN
				SET @INSSSAL13 = 0
			END
			
			-- Calcula o valor base do IRFF de Férias sem Pensão
										 --@BASEINSSFERIAS
			SET @BASEIRRFFERIASSEMPENSAOMMO    = @MMO    - @INSSMENSAL - (@VALDEP * @DEPENDENTE)
			SET @BASEIRRFFERIASSEMPENSAOFERIAS = @FERIAS - @INSSFERIAS - (@VALDEP * @DEPENDENTE)

			-- Calcula o valor base do IRFF do 13 Sal sem Pensão
			SET @BASEIRRFSAL13SEMPENSAO = @BASEINSSSAL13 - (@INSSSAL13 + @INSSANO) - (@VALDEP * @DEPENDENTE)
			
			IF @BASEIRRFFERIASSEMPENSAOMMO < 0 BEGIN
				SET @BASEIRRFFERIASSEMPENSAOMMO = 0
			END
			
			IF @BASEIRRFFERIASSEMPENSAOFERIAS < 0 BEGIN
				SET @BASEIRRFFERIASSEMPENSAOFERIAS = 0
			END
			
			IF @BASEIRRFSAL13SEMPENSAO < 0 BEGIN
				SET @BASEIRRFSAL13SEMPENSAO = 0
			END
			
			-- Calcula o valor do IRRF de Férias Sem Pensão
			SELECT @IRRFMMO =
				case when @BASEIRRFFERIASSEMPENSAOMMO <= (select top 1 isnull(ate1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASSEMPENSAOMMO * ((select top 1 isnull(aliquota1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASSEMPENSAOMMO >= (select top 1 isnull(de2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASSEMPENSAOMMO <= (select top 1 isnull(ate2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASSEMPENSAOMMO * ((select top 1 isnull(aliquota2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASSEMPENSAOMMO >= (select top 1 isnull(de3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASSEMPENSAOMMO <= (select top 1 isnull(ate3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASSEMPENSAOMMO * ((select top 1 isnull(aliquota3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASSEMPENSAOMMO >= (select top 1 isnull(de4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASSEMPENSAOMMO <= (select top 1 isnull(ate4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASSEMPENSAOMMO * ((select top 1 isnull(aliquota4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASSEMPENSAOMMO >= (select top 1 isnull(de5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASSEMPENSAOMMO <= (select top 1 isnull(ate5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASSEMPENSAOMMO * ((select top 1 isnull(aliquota5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else (@BASEIRRFFERIASSEMPENSAOMMO * ((select top 1 isnull(ALIQUOTAACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(DEDUZIRACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) end end end end end
				
			SELECT @IRRFFERIAS =
				case when @BASEIRRFFERIASSEMPENSAOFERIAS <= (select top 1 isnull(ate1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASSEMPENSAOFERIAS * ((select top 1 isnull(aliquota1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASSEMPENSAOFERIAS >= (select top 1 isnull(de2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASSEMPENSAOFERIAS <= (select top 1 isnull(ate2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASSEMPENSAOFERIAS * ((select top 1 isnull(aliquota2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASSEMPENSAOFERIAS >= (select top 1 isnull(de3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASSEMPENSAOFERIAS <= (select top 1 isnull(ate3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASSEMPENSAOFERIAS * ((select top 1 isnull(aliquota3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASSEMPENSAOFERIAS >= (select top 1 isnull(de4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASSEMPENSAOFERIAS <= (select top 1 isnull(ate4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASSEMPENSAOFERIAS * ((select top 1 isnull(aliquota4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASSEMPENSAOFERIAS >= (select top 1 isnull(de5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASSEMPENSAOFERIAS <= (select top 1 isnull(ate5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASSEMPENSAOFERIAS * ((select top 1 isnull(aliquota5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else (@BASEIRRFFERIASSEMPENSAOFERIAS * ((select top 1 isnull(ALIQUOTAACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(DEDUZIRACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) end end end end end				
			
			-- Calcula o valor do IRRF de Férias Sem Pensão
			SELECT @IRRFSAL13 =
				case when @BASEIRRFSAL13SEMPENSAO <= (select top 1 isnull(ate1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFSAL13SEMPENSAO * ((select top 1 isnull(aliquota1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFSAL13SEMPENSAO >= (select top 1 isnull(de2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFSAL13SEMPENSAO <= (select top 1 isnull(ate2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFSAL13SEMPENSAO * ((select top 1 isnull(aliquota2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFSAL13SEMPENSAO >= (select top 1 isnull(de3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFSAL13SEMPENSAO <= (select top 1 isnull(ate3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFSAL13SEMPENSAO * ((select top 1 isnull(aliquota3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFSAL13SEMPENSAO >= (select top 1 isnull(de4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFSAL13SEMPENSAO <= (select top 1 isnull(ate4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFSAL13SEMPENSAO * ((select top 1 isnull(aliquota4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFSAL13SEMPENSAO >= (select top 1 isnull(de5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFSAL13SEMPENSAO <= (select top 1 isnull(ate5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFSAL13SEMPENSAO * ((select top 1 isnull(aliquota5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else (@BASEIRRFSAL13SEMPENSAO * ((select top 1 isnull(ALIQUOTAACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(DEDUZIRACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) end end end end end
			
			SET @IRRFMMO = ROUND(ISNULL(@IRRFMMO, 0), 2)
			SET @IRRFFERIAS = ROUND(ISNULL(@IRRFFERIAS, 0), 2)
			SET @IRRFSAL13 = ROUND(ISNULL(@IRRFSAL13, 0), 2)
			
			IF @IRRFFERIAS < 0 BEGIN
				SET @IRRFFERIAS = 0
			END
		
			IF @IRRFMMO < 0 BEGIN
				SET @IRRFMMO = 0
			END
			
--			SET @IRRFFERIAS = @IRRFFERIAS + @IRRFMMO
			
			IF @IRRFSAL13 < 0 BEGIN
				SET @IRRFSAL13 = 0
			END
			
			-- CALCULO DA PENSAO de Férias
			SET @PENSAOFERIAS = 0
			
			-- CALCULO DA PENSAO do 13 Sal
			SET @PENSAOSAL13 = 0
			
			-- Percorre todos os pensionistas para a matricula atual
			DECLARE CurPensionista --Nome do cursor
				CURSOR FOR select PENSIONISTA, REGRA, FATOR, DESCONTO_LIMITE, DESCONTO_IRRF, DESCONTO_INSS, DESCONTO_DAS, PENSAO_FERIAS, PENSAO_SAL13
					From PENSIONISTA
					Where PENSIONISTA.MATRICULA = @MATRICULA 
					and PENSIONISTA.INATIVO = 0 
					and (PENSIONISTA.PENSAO_FERIAS = 1 OR PENSIONISTA.PENSAO_SAL13 = 1)
--					AND '01-' + RIGHT('00' + convert(varchar(2),@TMES),2) + '-' + convert(varchar(4), @TANO) BETWEEN PENSIONISTA.VIGENCIAI AND PENSIONISTA.VIGENCIAF
					AND convert(varchar(4), @TANO) + '-' + RIGHT('00' + convert(varchar(2),@TMES),2) + '-01' BETWEEN PENSIONISTA.VIGENCIAI AND PENSIONISTA.VIGENCIAF
					ORDER BY PENSIONISTA.CLASSIFICACAO
			
			OPEN CurPensionista
			FETCH NEXT FROM CurPensionista
			INTO @P_PENSIONISTA, @P_REGRA, @P_FATOR, @P_DESCONTO_LIMITE, @P_DESCONTO_IRRF, @P_DESCONTO_INSS, @P_DESCONTO_DAS, @PENSAO_FERIAS, @PENSAO_SAL13
			
			WHILE @@FETCH_STATUS = 0 BEGIN
				SET @BASEPENSAOFERIAS_PENSIONISTA = 0
				SET @PENSAOFERIAS_PENSIONISTA = 0
				SET @BASEPENSAOSAL13_PENSIONISTA = 0
				SET @PENSAOSAL13_PENSIONISTA = 0
					
				-- Bruto
				IF @P_REGRA = 1 AND @P_FATOR > 0 BEGIN
					IF @PENSAO_FERIAS = 1 BEGIN
						SET @BASEPENSAOFERIAS_PENSIONISTA = @FERIAS
						IF @BASEPENSAOFERIAS_PENSIONISTA < 0 BEGIN
							SET @BASEPENSAOFERIAS_PENSIONISTA = 0
						END
						SET @PENSAOFERIAS_PENSIONISTA = ROUND(@BASEPENSAOFERIAS_PENSIONISTA * @P_FATOR, 2)
					END
					IF @PENSAO_SAL13 = 1 BEGIN
						SET @BASEPENSAOSAL13_PENSIONISTA = @SAL13
						IF @BASEPENSAOSAL13_PENSIONISTA < 0 BEGIN
							SET @BASEPENSAOSAL13_PENSIONISTA = 0
						END
						SET @PENSAOSAL13_PENSIONISTA = ROUND(@BASEPENSAOSAL13_PENSIONISTA * @P_FATOR, 2)
					END					
				END
				-- Liquido
				IF @P_REGRA = 0 AND @P_FATOR > 0 BEGIN
					IF @PENSAO_FERIAS = 1 BEGIN
						SET @BASEPENSAOFERIAS_PENSIONISTA = @FERIAS
						IF @P_DESCONTO_INSS = 1 BEGIN
							SET @BASEPENSAOFERIAS_PENSIONISTA = @BASEPENSAOFERIAS_PENSIONISTA - @INSSFERIAS
						END
						IF @P_DESCONTO_IRRF = 1 BEGIN
							SET @BASEPENSAOFERIAS_PENSIONISTA = @BASEPENSAOFERIAS_PENSIONISTA - @IRRFFERIAS
						END					
						IF @P_DESCONTO_DAS = 1 BEGIN
							SET @BASEPENSAOFERIAS_PENSIONISTA = @BASEPENSAOFERIAS_PENSIONISTA
						END					
						IF @BASEPENSAOFERIAS_PENSIONISTA < 0 BEGIN
							SET @BASEPENSAOFERIAS_PENSIONISTA = 0
						END
						SET @PENSAOFERIAS_PENSIONISTA = ROUND(@BASEPENSAOFERIAS_PENSIONISTA * @P_FATOR, 2)
					END
					IF @PENSAO_SAL13 = 1 BEGIN
						SET @BASEPENSAOSAL13_PENSIONISTA = @SAL13
						IF @P_DESCONTO_INSS = 1 BEGIN
							SET @BASEPENSAOSAL13_PENSIONISTA = @BASEPENSAOSAL13_PENSIONISTA - @INSSSAL13
						END
						IF @P_DESCONTO_IRRF = 1 BEGIN
							SET @BASEPENSAOSAL13_PENSIONISTA = @BASEPENSAOSAL13_PENSIONISTA - @IRRFSAL13
						END					
						IF @P_DESCONTO_DAS = 1 BEGIN
							SET @BASEPENSAOSAL13_PENSIONISTA = @BASEPENSAOSAL13_PENSIONISTA
						END					
						IF @BASEPENSAOSAL13_PENSIONISTA < 0 BEGIN
							SET @BASEPENSAOSAL13_PENSIONISTA = 0
						END
						SET @PENSAOSAL13_PENSIONISTA = ROUND(@BASEPENSAOSAL13_PENSIONISTA * @P_FATOR, 2)
					END
				END
				-- Valor Mensal
				IF @P_REGRA = 2 AND @P_FATOR >= 1 BEGIN
					IF @PENSAO_FERIAS = 1 BEGIN
						SET @BASEPENSAOFERIAS_PENSIONISTA = @FERIAS - @INSSFERIAS - @IRRFFERIAS
						
						IF @BASEPENSAOFERIAS_PENSIONISTA < 0 BEGIN
							SET @BASEPENSAOFERIAS_PENSIONISTA = 0
						END
						
						IF @BASEPENSAOFERIAS_PENSIONISTA > @P_FATOR BEGIN
							SET @PENSAOFERIAS_PENSIONISTA = @P_FATOR
						END
						ELSE BEGIN
							SET @PENSAOFERIAS_PENSIONISTA = @BASEPENSAOFERIAS_PENSIONISTA
						END
					END
					IF @PENSAO_SAL13 = 1 BEGIN
						SET @BASEPENSAOSAL13_PENSIONISTA = @SAL13 - @INSSSAL13 - @IRRFSAL13
						
						IF @BASEPENSAOSAL13_PENSIONISTA < 0 BEGIN
							SET @BASEPENSAOSAL13_PENSIONISTA = 0
						END
						
						IF @BASEPENSAOSAL13_PENSIONISTA > @P_FATOR BEGIN
							SET @BASEPENSAOSAL13_PENSIONISTA = @P_FATOR
						END
						ELSE BEGIN
							SET @PENSAOSAL13_PENSIONISTA = @BASEPENSAOSAL13_PENSIONISTA
						END
					END
				END 
				-- Salário Mínimo
				IF @P_REGRA = 3 AND @SALARIOMININO > 0 BEGIN
					IF @PENSAO_FERIAS = 1 BEGIN
						SET @BASEPENSAOFERIAS_PENSIONISTA = @FERIAS - @INSSFERIAS - @IRRFFERIAS
						
						IF @BASEPENSAOFERIAS_PENSIONISTA < 0 BEGIN
							SET @BASEPENSAOFERIAS_PENSIONISTA = 0
						END
						
						IF @BASEPENSAOFERIAS_PENSIONISTA > @SALARIOMININO BEGIN
							SET @PENSAOFERIAS_PENSIONISTA = @SALARIOMININO
						END
						ELSE BEGIN
							SET @PENSAOFERIAS_PENSIONISTA = @BASEPENSAOFERIAS_PENSIONISTA
						END
					END
					IF @PENSAO_SAL13 = 1 BEGIN
						SET @BASEPENSAOSAL13_PENSIONISTA = @SAL13 - @INSSSAL13 - @IRRFSAL13
						
						IF @BASEPENSAOSAL13_PENSIONISTA < 0 BEGIN
							SET @BASEPENSAOSAL13_PENSIONISTA = 0
						END
						
						IF @BASEPENSAOSAL13_PENSIONISTA > @SALARIOMININO BEGIN
							SET @PENSAOSAL13_PENSIONISTA = @SALARIOMININO
						END
						ELSE BEGIN
							SET @PENSAOSAL13_PENSIONISTA = @BASEPENSAOSAL13_PENSIONISTA
						END
					END
				END 
				-- Lança a Pensão de Férias do Pensionista 
				IF @PENSAOFERIAS_PENSIONISTA > 0 BEGIN
					-- Atualiza o valor da pensão para o limite de desconto caso haja limite de desconto definido
					-- e o valor calculado da pensão seja em percentagem, em relação ao Liquido, superior ao desconto definido
					IF @P_DESCONTO_LIMITE > 0 BEGIN
						IF ((@PENSAOFERIAS_PENSIONISTA * 100) / (@BASEPENSAOFERIAS_PENSIONISTA)) > (@P_DESCONTO_LIMITE * 100) BEGIN
							SET @PENSAOFERIAS_PENSIONISTA = ROUND(@BASEPENSAOFERIAS_PENSIONISTA * @P_DESCONTO_LIMITE, 2)
						END
					END
					
					IF @PENSAOFERIAS_PENSIONISTA < 0 BEGIN
						SET @PENSAOFERIAS_PENSIONISTA = 0
					END
					
					SET @PENSAOFERIAS = @PENSAOFERIAS + @PENSAOFERIAS_PENSIONISTA
				END
				-- Lança a Pensão do 13 Sal do Pensionista
				IF @PENSAOSAL13_PENSIONISTA > 0 BEGIN
					-- Atualiza o valor da pensão para o limite de desconto caso haja limite de desconto definido
					-- e o valor calculado da pensão seja em percentagem, em relação ao Liquido, superior ao desconto definido
					IF @P_DESCONTO_LIMITE > 0 BEGIN
						IF ((@PENSAOSAL13_PENSIONISTA * 100) / (@BASEPENSAOSAL13_PENSIONISTA)) > (@P_DESCONTO_LIMITE * 100) BEGIN
							SET @PENSAOSAL13_PENSIONISTA = ROUND(@BASEPENSAOSAL13_PENSIONISTA * @P_DESCONTO_LIMITE, 2)
						END
					END
					
					IF @PENSAOSAL13_PENSIONISTA < 0 BEGIN
						SET @PENSAOSAL13_PENSIONISTA = 0
					END
					
					SET @PENSAOSAL13 = @PENSAOSAL13 + @PENSAOSAL13_PENSIONISTA
				END
				
				IF @PENSAOFERIAS_PENSIONISTA > 0 or @PENSAOSAL13_PENSIONISTA > 0 BEGIN
					Insert Into PensaoMes (Matricula, Pensionista, Ano, Mes, VlrFerias, VlrSal13, VlrPensao)
					VALUES (@MATRICULA, @P_PENSIONISTA, @TANO, @TMES, @PENSAOFERIAS_PENSIONISTA, @PENSAOSAL13_PENSIONISTA, 0)
				END
				
				FETCH NEXT FROM CurPensionista
				INTO @P_PENSIONISTA, @P_REGRA, @P_FATOR, @P_DESCONTO_LIMITE, @P_DESCONTO_IRRF, @P_DESCONTO_INSS, @P_DESCONTO_DAS, @PENSAO_FERIAS, @PENSAO_SAL13
			END
			CLOSE CurPensionista
			DEALLOCATE CurPensionista
			
			-- Calcula o valor Base do IRRF de Férias com Pensao
			--SET @BASEIRRFFERIASCOMPENSAO = @BASEINSSFERIAS - @PENSAOFERIAS -(@INSSFERIAS + @INSSMENSAL) - (@VALDEP * @DEPENDENTE)
										   --@BASEINSSFERIAS
										   
			SET @BASEIRRFFERIASCOMPENSAOMMO    = @MMO    - @PENSAOMENSAL - @INSSMENSAL - (@VALDEP * @DEPENDENTE)
			SET @BASEIRRFFERIASCOMPENSAOFERIAS = @FERIAS - @PENSAOFERIAS - @INSSFERIAS - (@VALDEP * @DEPENDENTE)

			-- Calcula o valor Base do IRRF do 13 Sal com Pensao
			SET @BASEIRRFSAL13COMPENSAO = @BASEINSSSAL13 - @PENSAOSAL13 - @INSSSAL13 - (@VALDEP * @DEPENDENTE)
			
			IF @BASEIRRFFERIASCOMPENSAOMMO < 0 BEGIN
				SET @BASEIRRFFERIASCOMPENSAOMMO = 0
			END
			
			IF @BASEIRRFFERIASCOMPENSAOFERIAS < 0 BEGIN
				SET @BASEIRRFFERIASCOMPENSAOFERIAS = 0
			END
			
			IF @BASEIRRFSAL13COMPENSAO < 0 BEGIN
				SET @BASEIRRFSAL13COMPENSAO = 0
			END
			
			SET @IRRFMMO = 0
			SET @IRRFFERIAS = 0
			SET @IRRFSAL13 = 0
			
			-- Calcula o valor do IRRF de Férias Com Pensão
			SELECT @IRRFMMO =
				case when @BASEIRRFFERIASCOMPENSAOMMO <= (select top 1 isnull(ate1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASCOMPENSAOMMO * ((select top 1 isnull(aliquota1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASCOMPENSAOMMO >= (select top 1 isnull(de2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASCOMPENSAOMMO <= (select top 1 isnull(ate2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASCOMPENSAOMMO * ((select top 1 isnull(aliquota2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASCOMPENSAOMMO >= (select top 1 isnull(de3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASCOMPENSAOMMO <= (select top 1 isnull(ate3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASCOMPENSAOMMO * ((select top 1 isnull(aliquota3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASCOMPENSAOMMO >= (select top 1 isnull(de4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASCOMPENSAOMMO <= (select top 1 isnull(ate4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASCOMPENSAOMMO * ((select top 1 isnull(aliquota4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASCOMPENSAOMMO >= (select top 1 isnull(de5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASCOMPENSAOMMO <= (select top 1 isnull(ate5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASCOMPENSAOMMO * ((select top 1 isnull(aliquota5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else (@BASEIRRFFERIASCOMPENSAOMMO * ((select top 1 isnull(ALIQUOTAACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(DEDUZIRACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) end end end end end 
				
			SELECT @IRRFFERIAS =
				case when @BASEIRRFFERIASCOMPENSAOFERIAS <= (select top 1 isnull(ate1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASCOMPENSAOFERIAS * ((select top 1 isnull(aliquota1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASCOMPENSAOFERIAS >= (select top 1 isnull(de2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASCOMPENSAOFERIAS <= (select top 1 isnull(ate2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASCOMPENSAOFERIAS * ((select top 1 isnull(aliquota2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASCOMPENSAOFERIAS >= (select top 1 isnull(de3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASCOMPENSAOFERIAS <= (select top 1 isnull(ate3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASCOMPENSAOFERIAS * ((select top 1 isnull(aliquota3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASCOMPENSAOFERIAS >= (select top 1 isnull(de4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASCOMPENSAOFERIAS <= (select top 1 isnull(ate4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASCOMPENSAOFERIAS * ((select top 1 isnull(aliquota4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFFERIASCOMPENSAOFERIAS >= (select top 1 isnull(de5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFFERIASCOMPENSAOFERIAS <= (select top 1 isnull(ate5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFFERIASCOMPENSAOFERIAS * ((select top 1 isnull(aliquota5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else (@BASEIRRFFERIASCOMPENSAOFERIAS * ((select top 1 isnull(ALIQUOTAACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(DEDUZIRACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) end end end end end 				

			-- Calcula o valor do IRRF do 13 Sal Com Pensão
			SELECT @IRRFSAL13 =
				case when @BASEIRRFSAL13COMPENSAO <= (select top 1 isnull(ate1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFSAL13COMPENSAO * ((select top 1 isnull(aliquota1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir1, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFSAL13COMPENSAO >= (select top 1 isnull(de2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFSAL13COMPENSAO <= (select top 1 isnull(ate2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFSAL13COMPENSAO * ((select top 1 isnull(aliquota2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir2, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFSAL13COMPENSAO >= (select top 1 isnull(de3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFSAL13COMPENSAO <= (select top 1 isnull(ate3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFSAL13COMPENSAO * ((select top 1 isnull(aliquota3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir3, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFSAL13COMPENSAO >= (select top 1 isnull(de4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFSAL13COMPENSAO <= (select top 1 isnull(ate4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFSAL13COMPENSAO * ((select top 1 isnull(aliquota4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir4, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else case when @BASEIRRFSAL13COMPENSAO >= (select top 1 isnull(de5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) and @BASEIRRFSAL13COMPENSAO <= (select top 1 isnull(ate5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) then (@BASEIRRFSAL13COMPENSAO * ((select top 1 isnull(aliquota5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(deduzir5, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc)
				else (@BASEIRRFSAL13COMPENSAO * ((select top 1 isnull(ALIQUOTAACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) / 100)) - (select top 1 isnull(DEDUZIRACIMA, 0) from irrf where ((year(emvigor) = @TANO and month(emvigor) <= @TMES) or year(emvigor) < @TANO) order by emvigor desc) end end end end end 
				
			SET @IRRFMMO = ROUND(ISNULL(@IRRFMMO, 0), 2)
			SET @IRRFFERIAS = ROUND(ISNULL(@IRRFFERIAS, 0), 2)
			SET @IRRFSAL13 = ROUND(ISNULL(@IRRFSAL13, 0), 2)
			
			/*
			IF @IRRFMMO < 0 BEGIN
				SET @IRRFMMO = 0
			END
			
			IF @IRRFFERIAS < 0 BEGIN
				SET @IRRFFERIAS = 0
			END
			*/


/*
delete encargoferiassal13 where ano = 2015 and mes = 7
delete pensaomes where ano = 2015 and mes = 7
delete descmes where ano = 2015 and mes = 7
delete encargooptrabalhador where ano = 2015 and mes = 7
delete encargoop where ano = 2015 and mes = 7

exec SP_FECHAR_MES 2015, 7


if (@MATRICULA = 300064) BEGIN
	print 'BASEIRRFFERIASCOMPENSAOMMO: ' + convert(varchar, @BASEIRRFFERIASCOMPENSAOMMO)

	print 'IRRF Recolhido: ' + convert(varchar, @IRRFMENSAL)
	print 'IRRF MMO: ' + convert(varchar, @IRRFMMO)
	print 'IRRF Férias: ' + convert(varchar, @IRRFFERIAS)
END			
*/   
			SET @IRRFMMO = (@IRRFMMO - @IRRFMENSAL)
			
			
			IF @IRRFSAL13 < 0 BEGIN
				SET @IRRFSAL13 = 0
			END
			

			UPDATE ENCARGOFERIASSAL13
				SET IRRFMMO = @IRRFMMO, 
				    BASEIRRFMMO = @BASEIRRFFERIASCOMPENSAOMMO,
				    BASEIRRFFERIAS = @BASEIRRFFERIASCOMPENSAOFERIAS,
				    BASEIRRFSAL13 = @BASEIRRFSAL13COMPENSAO,
				    FERIASIRRF = @IRRFFERIAS, 
					FERIASINSS = @INSSFERIAS, 
					FERIASPENSAO = @PENSAOFERIAS,
					FERIASLIQUIDO = CASE WHEN @FERIAS - @IRRFMMO - @INSSFERIAS - @PENSAOFERIAS - @IRRFFERIAS < 0 THEN 0 ELSE @FERIAS - @IRRFMMO - @INSSFERIAS - @PENSAOFERIAS - @IRRFFERIAS END,
					SAL13IRRF = @IRRFSAL13,
					SAL13INSS = @INSSSAL13,
					SAL13PENSAO = @PENSAOSAL13,
					SAL13LIQUIDO = CASE WHEN @SAL13 - @INSSSAL13 - @PENSAOSAL13 - @IRRFSAL13 < 0 THEN 0 ELSE @SAL13 - @INSSSAL13 - @PENSAOSAL13 - @IRRFSAL13 END,
					--TRANSPORTE = 0,
					ALIMENTACAO = 0
				WHERE ENCARGOFERIASSAL13.MATRICULA = @MATRICULA	
				AND ENCARGOFERIASSAL13.ANO = @TANO
				AND ENCARGOFERIASSAL13.MES = @TMES
			
			SET @LIQFERIAS = @FERIAS - @INSSFERIAS - @PENSAOFERIAS - @IRRFFERIAS
			SET @LIQSAL13 = @SAL13 - @INSSSAL13 - @PENSAOSAL13 - @IRRFSAL13
			
			IF @LIQFERIAS < 0 BEGIN
				SET @LIQFERIAS = 0
			END
			
			IF @LIQSAL13 < 0 BEGIN
				SET @LIQSAL13 = 0
			END
			
			IF @LIQFERIAS > 1 OR @LIQSAL13 > 1 BEGIN
				-- CALCULO DOS DESCONTOS PROGRAMADOS
				
				-- Percorre todos os descontos programados para a matricula atual
				DECLARE CurDescontos --Nome do cursor
				CURSOR FOR SELECT DESCPROGRAMADO.DESCONTO, DESCPROGRAMADO.VALOR, DESCPROGRAMADO.MAXPERCLIQUIDO
						FROM DESCPROGRAMADO
						INNER JOIN DESCPROGRAMADOTIPO ON DESCPROGRAMADOTIPO.DESCPROGRAMADOTIPO = DESCPROGRAMADO.DESCPROGRAMADOTIPO
						WHERE DESCPROGRAMADO.VALOR > 0
						AND DESCPROGRAMADOTIPO.DIARIO = 0
						AND DESCPROGRAMADO.MATRICULA = @MATRICULA
						AND '01-' + RIGHT('00' + convert(varchar(2),@TMES),2) + '-' + convert(varchar(4), @TANO) BETWEEN DESCPROGRAMADO.INICIO AND DESCPROGRAMADO.TERMINO
						ORDER BY DESCPROGRAMADOTIPO.CLASSIFICACAO
				
				OPEN CurDescontos
				FETCH NEXT FROM CurDescontos
				INTO @DESCPROGR_DESCONTO, @DESCPROGR_VALOR, @DESCPROGR_MAXPERCLIQUIDO
				
				WHILE @@FETCH_STATUS = 0 AND (@LIQFERIAS > 1 OR @LIQSAL13 > 1) BEGIN
					SET @DESCPROGR_VALOR_A_APLICAR = @DESCPROGR_VALOR
					SET @DESCPROGR_VALOR_SOBRA = 0
					SET @DESCPROGR_VALOR_FERIAS = 0
					SET @DESCPROGR_VALOR_SAL13 = 0
					
					IF @DESCPROGR_VALOR_A_APLICAR > 0 AND @LIQFERIAS > 1 BEGIN
						-- Atualiza o valor do desconto para o limite de desconto caso haja limite de desconto definido
						-- e o valor calculado do desconto seja em percentagem, em relação ao Liquido, superior ao desconto definido
						IF @DESCPROGR_MAXPERCLIQUIDO > 0 BEGIN
							IF ((@DESCPROGR_VALOR_A_APLICAR * 100) / @LIQFERIAS) > (@DESCPROGR_MAXPERCLIQUIDO) BEGIN
								SET @DESCPROGR_VALOR_A_APLICAR = ROUND(@LIQFERIAS * (@DESCPROGR_MAXPERCLIQUIDO / 100), 2)
							END
						END
						
						-- Atualiza o valor do desconto a usar por forma a assegurar que o Liquido seja no mínimo 1
						IF @LIQFERIAS - @DESCPROGR_VALOR_A_APLICAR < 1 BEGIN
							SET @DESCPROGR_VALOR_SOBRA = @DESCPROGR_VALOR_A_APLICAR
							SET @DESCPROGR_VALOR_A_APLICAR = @DESCPROGR_VALOR_A_APLICAR - (@DESCPROGR_VALOR_A_APLICAR - @LIQFERIAS) - 1
							SET @DESCPROGR_VALOR_SOBRA = @DESCPROGR_VALOR_SOBRA - @DESCPROGR_VALOR_A_APLICAR
							IF @DESCPROGR_VALOR_A_APLICAR < 0 BEGIN
								SET @DESCPROGR_VALOR_A_APLICAR = 0
							END
							SET @LIQFERIAS = @LIQFERIAS - @DESCPROGR_VALOR_A_APLICAR
						END
						
						IF @DESCPROGR_VALOR_A_APLICAR > 0 BEGIN
							SET @DESCPROGR_VALOR_FERIAS = @DESCPROGR_VALOR_A_APLICAR
						END
						SET @DESCPROGR_VALOR_A_APLICAR = @DESCPROGR_VALOR_SOBRA
					END
					
					IF @DESCPROGR_VALOR_A_APLICAR > 0 AND @LIQSAL13 > 1 BEGIN
						-- Atualiza o valor do desconto para o limite de desconto caso haja limite de desconto definido
						-- e o valor calculado do desconto seja em percentagem, em relação ao Liquido, superior ao desconto definido
						IF @DESCPROGR_MAXPERCLIQUIDO > 0 BEGIN
							IF ((@DESCPROGR_VALOR_A_APLICAR * 100) / @LIQSAL13) > (@DESCPROGR_MAXPERCLIQUIDO) BEGIN
								SET @DESCPROGR_VALOR_A_APLICAR = ROUND(@LIQSAL13 * (@DESCPROGR_MAXPERCLIQUIDO / 100), 2)
							END
						END
						
						-- Atualiza o valor do desconto a usar por forma a assegurar que o Liquido seja no mínimo 1
						IF @LIQSAL13 - @DESCPROGR_VALOR_A_APLICAR < 1 BEGIN
							SET @DESCPROGR_VALOR_A_APLICAR = @DESCPROGR_VALOR_A_APLICAR - (@DESCPROGR_VALOR_A_APLICAR - @LIQSAL13) - 1
						END
						
						IF @DESCPROGR_VALOR_A_APLICAR < 0 BEGIN
							SET @DESCPROGR_VALOR_A_APLICAR = 0
						END
						SET @LIQSAL13 = @LIQSAL13 - @DESCPROGR_VALOR_A_APLICAR
						
						IF @DESCPROGR_VALOR_A_APLICAR > 0 BEGIN
							SET @DESCPROGR_VALOR_SAL13 = @DESCPROGR_VALOR_A_APLICAR
						END
					END
					
					IF @DESCPROGR_VALOR_FERIAS > 0 OR @DESCPROGR_VALOR_SAL13 > 0 BEGIN
						Insert Into DESCMES (MATRICULA, ANO, MES, DESCONTO, VALORFERIAS, VALORSAL13, VALORDESCONTO) 
						values(@MATRICULA, @TANO, @TMES, @DESCPROGR_DESCONTO, @DESCPROGR_VALOR_FERIAS, @DESCPROGR_VALOR_SAL13, 0)
					END
					
					FETCH NEXT FROM CurDescontos
					INTO @DESCPROGR_DESCONTO, @DESCPROGR_VALOR, @DESCPROGR_MAXPERCLIQUIDO
				END
				CLOSE CurDescontos
				DEALLOCATE CurDescontos
				
			END
			
			FETCH NEXT FROM CurEncargoMes 
			INTO @MATRICULA
		END
		CLOSE CurEncargoMes
		DEALLOCATE CurEncargoMes
		
		-- Atualização final da tabela PensaoMes
		DECLARE CurPensaoFinal --Nome do cursor
		CURSOR FOR 
			SELECT PENSIONISTA.MATRICULA, 
				PENSIONISTA.PENSIONISTA,
				ISNULL((SELECT SUM(RFP.VALOR) 
						FROM REQFUNCAO RF
						INNER JOIN REQUISICAO R ON R.REQUISICAO = RF.REQUISICAO
						INNER JOIN REQFUNCAOPENSAO RFP ON RFP.CFUNCAO = RF.CFUNCAO
						WHERE RF.MATRICULA = ENCARGOFERIASSAL13.MATRICULA
						  AND YEAR(RF.CALCULADO) = @TANO
						  AND MONTH(RF.CALCULADO) = @TMES
						  AND R.CANCELADO = 0
						  AND RF.VISUALIZAQUADRO = 1
						  AND RFP.PENSIONISTA = PENSIONISTA.PENSIONISTA), 0)
			FROM ENCARGOFERIASSAL13
			INNER JOIN PENSIONISTA ON PENSIONISTA.MATRICULA = ENCARGOFERIASSAL13.MATRICULA
			WHERE ENCARGOFERIASSAL13.PENSAO > 0
			  AND ENCARGOFERIASSAL13.ANO = @TANO
			  AND ENCARGOFERIASSAL13.MES = @TMES
		OPEN CurPensaoFinal
		FETCH NEXT FROM CurPensaoFinal
		INTO @MATRICULA, @P_PENSIONISTA, @PENSAOVALOR
		
		WHILE @@FETCH_STATUS = 0 BEGIN
			IF NOT EXISTS(SELECT TOP 1 1 FROM PensaoMes WHERE PensaoMes.Matricula = @MATRICULA AND PensaoMes.Pensionista = @P_PENSIONISTA) BEGIN
				Insert Into PensaoMes (Matricula, Pensionista, Ano, Mes, VlrFerias, VlrSal13, VlrPensao)
				VALUES (@MATRICULA, @P_PENSIONISTA, @TANO, @TMES, 0, 0, @PENSAOVALOR)
			END
			ELSE BEGIN
				update PensaoMes set VlrPensao = @PENSAOVALOR where PensaoMes.Matricula = @MATRICULA AND PensaoMes.Pensionista = @P_PENSIONISTA
			END
			
			FETCH NEXT FROM CurPensaoFinal
			INTO @MATRICULA, @P_PENSIONISTA, @PENSAOVALOR
		END
		CLOSE CurPensaoFinal;
		DEALLOCATE CurPensaoFinal;
		
		-- Atualização final da tabela DescMes
		DECLARE CurDescFinal CURSOR 
			FOR SELECT MATRICULA, 
					   DESCONTO, 
					   ISNULL((SELECT SUM(VALOR)
							   FROM REQFUNCAODESC RFD
							   INNER JOIN REQFUNCAO RF2 ON RF2.CFUNCAO = RFD.CFUNCAO
							   WHERE RF2.MATRICULA = TT.MATRICULA
							     AND RFD.DESCONTO = TT.DESCONTO
							     AND YEAR(RF2.CALCULADO) = @TANO
							     AND MONTH(RF2.CALCULADO) = @TMES), 0)
				FROM (SELECT DISTINCT ENCARGOFERIASSAL13.MATRICULA, REQFUNCAODESC.DESCONTO
					  FROM ENCARGOFERIASSAL13
					  INNER JOIN REQFUNCAO ON REQFUNCAO.MATRICULA = ENCARGOFERIASSAL13.MATRICULA
					  INNER JOIN REQFUNCAODESC ON REQFUNCAODESC.CFUNCAO = REQFUNCAO.CFUNCAO
					  WHERE ENCARGOFERIASSAL13.DESCONTOS > 0
					    AND ENCARGOFERIASSAL13.ANO = @TANO
						AND ENCARGOFERIASSAL13.MES = @TMES
						AND YEAR(REQFUNCAO.CALCULADO) = @TANO
						AND MONTH(REQFUNCAO.CALCULADO) = @TMES) AS TT
		OPEN CurDescFinal
		FETCH NEXT FROM CurDescFinal
		INTO @MATRICULA, @DESCPROGR_DESCONTO, @DESCONTOVALOR
		
		WHILE @@FETCH_STATUS = 0 BEGIN
			IF NOT EXISTS(SELECT TOP 1 1 FROM DESCMES WHERE DESCMES.Matricula = @MATRICULA AND DESCMES.DESCONTO = @DESCPROGR_DESCONTO) BEGIN
				Insert Into DESCMES (MATRICULA, ANO, MES, DESCONTO, VALORFERIAS, VALORSAL13, VALORDESCONTO) 
				values(@MATRICULA, @TANO, @TMES, @DESCPROGR_DESCONTO, 0, 0, @DESCONTOVALOR)
			END
			ELSE BEGIN
				update DESCMES set VALORDESCONTO = @DESCONTOVALOR where DESCMES.Matricula = @MATRICULA AND DESCMES.DESCONTO = @DESCPROGR_DESCONTO
			END
			
			FETCH NEXT FROM CurDescFinal
			INTO @MATRICULA, @DESCPROGR_DESCONTO, @DESCONTOVALOR
		END
		CLOSE CurDescFinal;
		DEALLOCATE CurDescFinal;
		
		-- Criação dos resumos de INSS por operador portuário
		INSERT INTO ENCARGOOP (OP, ANO, MES, MMO, RSR, MMOSEMDSR, AdicionalRisco, MMOTOTAL, FERIAS, SAL13, INSSPAT, INSSPATSAL13, INSSPATSAL13OUTRO, INSSPATOUTRO)
		SELECT TT.REQOP, @TANO, @TMES,
			isnull((select sum(rf2.mmo)
				from reqfuncao rf2
				inner join requisicao r on r.requisicao = rf2.requisicao
				where r.OP = tt.reqop
				
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)
				and r.cancelado = 0), 0) AS MMO,
			isnull((select sum(abs(rfe2.valor))
				from reqfuncaoencargo rfe2
				inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
				inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
				inner join requisicao r on r.requisicao = rf2.requisicao
				where r.OP = tt.reqop
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and (ev2.regra = 17)
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)), 0) AS RSR,
			isnull((select sum(rf2.mmo)
				from reqfuncao rf2
				inner join requisicao r on r.requisicao = rf2.requisicao
				where r.OP = tt.reqop
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and r.cancelado = 0), 0)
				-
			isnull((select sum(abs(rfe2.valor))
				from reqfuncaoencargo rfe2
				inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
				inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
				inner join requisicao r on r.requisicao = rf2.requisicao
				where r.OP = tt.reqop
				and (ev2.regra = 17)
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)), 0) AS MMOSEMDSR,
			isnull((select sum(abs(rfe2.valor))
				from reqfuncaoencargo rfe2
				inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
				inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
				inner join requisicao r on r.requisicao = rf2.requisicao
				where r.OP = tt.reqop
				and (ev2.regra = 20)
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)), 0) AS AdicionalRisco,
			isnull((select sum(rf2.mmo)
				from reqfuncao rf2
				inner join requisicao r on r.requisicao = rf2.requisicao
				where r.OP = tt.reqop
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and r.cancelado = 0), 0)
				+
			isnull((select sum(abs(rfe2.valor))
				from reqfuncaoencargo rfe2
				inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
				inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
				inner join requisicao r on r.requisicao = rf2.requisicao
				where r.OP = tt.reqop
				and (ev2.regra = 20)
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)), 0) AS MMOTOTAL,
			isnull((select sum(abs(rfe2.valor))
				from reqfuncaoencargo rfe2
				inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
				inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
				inner join requisicao r on r.requisicao = rf2.requisicao
				Where r.OP = tt.reqop
				and (ev2.ferias = 1)
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)), 0) AS FERIAS,
			isnull((select sum(abs(rfe2.valor))
				from reqfuncaoencargo rfe2
				inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
				inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
				inner join requisicao r on r.requisicao = rf2.requisicao
				Where r.OP = tt.reqop
				and (ev2.SAL13 = 1)
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)), 0) AS SAL13,
			isnull((select sum(abs(rfe2.valor))
				from reqfuncaoencargo rfe2
				inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
				inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
				inner join requisicao r on r.requisicao = rf2.requisicao
				Where r.OP = tt.reqop
				and (ev2.INSSPAT = 1)
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)), 0) AS INSSPAT,
			isnull((select sum(abs(rfe2.valor))
				from reqfuncaoencargo rfe2
				inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
				inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
				inner join requisicao r on r.requisicao = rf2.requisicao
				Where r.OP = tt.reqop
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and (ev2.INSSPATOUTRO = 1)
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)), 0) AS INSSPATOUTRO,
			isnull((select sum(abs(rfe2.valor))
				from reqfuncaoencargo rfe2
				inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
				inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
				inner join requisicao r on r.requisicao = rf2.requisicao
				Where r.OP = tt.reqop
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and (ev2.INSSPATSAL13 = 1)
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)), 0) AS INSSPATSAL13,
			isnull((select sum(abs(rfe2.valor))
				from reqfuncaoencargo rfe2
				inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
				inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
				inner join requisicao r on r.requisicao = rf2.requisicao
				Where r.OP = tt.reqop
				And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
				  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
				and (ev2.INSSPATSAL13OUTRO = 1)
				and (year(rf2.calculado) = @TANO)
				and (month(rf2.calculado) = @TMES)), 0)	AS INSSPATSAL13OUTRO	
			FROM (
				SELECT DISTINCT REQUISICAO.OP AS REQOP
				FROM REQFUNCAO
				INNER JOIN REQUISICAO ON REQUISICAO.REQUISICAO = REQFUNCAO.REQUISICAO
				WHERE YEAR(REQFUNCAO.CALCULADO) = @TANO and MONTH(REQFUNCAO.CALCULADO) = @TMES
				And ((REQFUNCAO.VisualizaQuadro = 1 and (isnull(REQFUNCAO.rateiobal, 0) = 0 and isnull(REQFUNCAO.rateiocap, 0) = 0)) 
				  OR (REQFUNCAO.VisualizaQuadro = 0 and (isnull(REQFUNCAO.rateiobal, 0) = 1 or isnull(REQFUNCAO.rateiocap, 0) = 1)))
				) AS TT
				
		DECLARE CurOPMat CURSOR 
			FOR SELECT TT.REQOP, 
					   TT.REQMAT, 
					   isnull((select abs(sum(rfe2.valor))
							   from reqfuncaoencargo rfe2
							   inner join reqfuncao rf2 on rf2.cfuncao = rfe2.cfuncao
							   inner join encargovigencia ev2 on ev2.encargovigencia = rfe2.encargovigencia
							   inner join requisicao r on r.requisicao = rf2.requisicao
							   where (rf2.matricula = TT.REQMAT)
							     and r.op = tt.reqop
							     And ((rf2.VisualizaQuadro = 1 and (isnull(rf2.rateiobal, 0) = 0 and isnull(rf2.rateiocap, 0) = 0)) 
								  OR (rf2.VisualizaQuadro = 0 and (isnull(rf2.rateiobal, 0) = 1 or isnull(rf2.rateiocap, 0) = 1)))
							     and (ev2.regra IN (4,6))
							     and (year(rf2.calculado) = @TANO)
							     and (month(rf2.calculado) = @TMES)), 0)
				FROM (SELECT DISTINCT REQUISICAO.OP AS REQOP, REQFUNCAO.MATRICULA AS REQMAT
					  FROM REQFUNCAO
					  INNER JOIN REQUISICAO ON REQUISICAO.REQUISICAO = REQFUNCAO.REQUISICAO
					  WHERE YEAR(REQFUNCAO.CALCULADO) = @TANO 
					    and MONTH(REQFUNCAO.CALCULADO) = @TMES
					    and isnull(reqfuncao.mmo, 0) > 0) AS TT
		OPEN CurOPMat
		FETCH NEXT FROM CurOPMat
		INTO @OP_OP, @OP_MATRICULA, @OP_INNS
		
		WHILE @@FETCH_STATUS = 0 BEGIN
			INSERT INTO ENCARGOOPTRABALHADOR (OP, MATRICULA, ANO, MES, INSSDEVIDO, INSSFERIASDEVIDO, INSSSAL13DEVIDO)
			VALUES (@OP_OP, @OP_MATRICULA, @TANO, @TMES, @OP_INNS, 0, 0)
			
			FETCH NEXT FROM CurOPMat
			INTO @OP_OP, @OP_MATRICULA, @OP_INNS
		END
		CLOSE CurOPMat;
		DEALLOCATE CurOPMat;
		
		SET @FERIASMES = 0
		SET @FERIASINSSMES = 0
		
		SELECT @FERIASMES = ISNULL(SUM(FERIAS), 0), @FERIASINSSMES = ISNULL(SUM(FERIASINSS), 0) 
		FROM ENCARGOFERIASSAL13
		WHERE ANO = @TANO AND MES = @TMES
		
		SET @FERIASMES = ISNULL(@FERIASMES, 0)
		SET @FERIASINSSMES = ISNULL(@FERIASINSSMES, 0)
		
		DECLARE CurOPMatINSS CURSOR 
			FOR SELECT OP, MATRICULA, PERCMES, ROUND((PERCMES * @FERIASINSSMES) / 100, 2)
				FROM (SELECT TT.OP, 
							 TT.MATRICULA,
							 (((ISNULL((SELECT SUM(ABS(RFE.VALOR))
										FROM REQFUNCAOENCARGO AS RFE
										INNER JOIN REQFUNCAO AS RF ON RF.CFUNCAO = RFE.CFUNCAO
										INNER JOIN ENCARGOVIGENCIA AS EV ON EV.ENCARGOVIGENCIA = RFE.ENCARGOVIGENCIA
										INNER JOIN REQUISICAO AS R ON R.REQUISICAO = RF.REQUISICAO
										WHERE RF.MATRICULA = TT.MATRICULA
										  AND R.OP = TT.OP
										  And ((rf.VisualizaQuadro = 1 and (isnull(rf.rateiobal, 0) = 0 and isnull(rf.rateiocap, 0) = 0)) 
											OR (rf.VisualizaQuadro = 0 and (isnull(rf.rateiobal, 0) = 1 or isnull(rf.rateiocap, 0) = 1)))
										  AND EV.FERIAS = 1
										  AND YEAR(RF.CALCULADO) = @TANO
										  AND MONTH(RF.CALCULADO) = @TMES), 0)) * 100) / @FERIASMES) AS PERCMES
					  FROM (SELECT DISTINCT REQUISICAO.OP, REQFUNCAO.MATRICULA
							FROM REQFUNCAO
							INNER JOIN REQUISICAO ON REQUISICAO.REQUISICAO = REQFUNCAO.REQUISICAO
							INNER JOIN REQFUNCAOENCARGO ON REQFUNCAOENCARGO.CFUNCAO = REQFUNCAO.CFUNCAO
							INNER JOIN ENCARGOVIGENCIA ON ENCARGOVIGENCIA.ENCARGOVIGENCIA = REQFUNCAOENCARGO.ENCARGOVIGENCIA
							WHERE NOT REQFUNCAO.MATRICULA IS NULL
							  And ((REQFUNCAO.VisualizaQuadro = 1 and (isnull(REQFUNCAO.rateiobal, 0) = 0 and isnull(REQFUNCAO.rateiocap, 0) = 0)) 
							   OR (REQFUNCAO.VisualizaQuadro = 0 and (isnull(REQFUNCAO.rateiobal, 0) = 1 or isnull(REQFUNCAO.rateiocap, 0) = 1)))
							  AND ENCARGOVIGENCIA.FERIAS = 1
							  AND YEAR(REQFUNCAO.CALCULADO) = @TANO
							  AND MONTH(REQFUNCAO.CALCULADO) = @TMES
							  AND ISNULL(REQFUNCAO.MMO, 0) > 0) AS TT) AS TTT
		OPEN CurOPMatINSS
		FETCH NEXT FROM CurOPMatINSS
		INTO @OP_OP, @OP_MATRICULA, @PERCMES, @OP_INNS
		
		WHILE @@FETCH_STATUS = 0 BEGIN
			UPDATE ENCARGOOPTRABALHADOR SET INSSFERIASDEVIDO = @OP_INNS, FERIASPERCMES = @PERCMES
				WHERE Ano = @TANO AND Mes = @TMES AND OP = @OP_OP AND Matricula = @OP_MATRICULA
			
			FETCH NEXT FROM CurOPMatINSS
			INTO @OP_OP, @OP_MATRICULA, @PERCMES, @OP_INNS
		END
		CLOSE CurOPMatINSS;
		DEALLOCATE CurOPMatINSS;
		
		SET @SAL13MES = 0
		SET @SAL13INSSMES = 0
		
		SELECT @SAL13MES = ISNULL(SUM(SAL13), 0), @SAL13INSSMES = ISNULL(SUM(SAL13INSS), 0)
		FROM ENCARGOFERIASSAL13
		WHERE ANO = @TANO AND MES = @TMES
		
		SET @SAL13MES = ISNULL(@SAL13MES, 0)
		SET @SAL13INSSMES = ISNULL(@SAL13INSSMES, 0)
		
		DECLARE CurOPMatINSS2 CURSOR 
			FOR SELECT OP, MATRICULA, PERCMES, ROUND((PERCMES * @SAL13INSSMES) / 100, 2)
				FROM (SELECT TT.OP, 
							 TT.MATRICULA,
							 (((ISNULL((SELECT ABS(SUM(RFE.VALOR))
										FROM REQFUNCAOENCARGO AS RFE
										INNER JOIN REQFUNCAO AS RF ON RF.CFUNCAO = RFE.CFUNCAO
										INNER JOIN ENCARGOVIGENCIA AS EV ON EV.ENCARGOVIGENCIA = RFE.ENCARGOVIGENCIA
										INNER JOIN REQUISICAO AS R ON R.REQUISICAO = RF.REQUISICAO
										WHERE RF.MATRICULA = TT.MATRICULA
										  AND R.OP = TT.OP
										  And ((RF.VisualizaQuadro = 1 and (isnull(RF.rateiobal, 0) = 0 and isnull(RF.rateiocap, 0) = 0)) 
										   OR (RF.VisualizaQuadro = 0 and (isnull(RF.rateiobal, 0) = 1 or isnull(RF.rateiocap, 0) = 1)))
										  AND EV.SAL13 = 1
										  AND YEAR(RF.CALCULADO) = @TANO
										  AND MONTH(RF.CALCULADO) = @TMES), 0)) * 100) / @SAL13MES) AS PERCMES
					  FROM (SELECT DISTINCT REQUISICAO.OP, REQFUNCAO.MATRICULA
							FROM REQFUNCAO
							INNER JOIN REQUISICAO ON REQUISICAO.REQUISICAO = REQFUNCAO.REQUISICAO
							INNER JOIN REQFUNCAOENCARGO ON REQFUNCAOENCARGO.CFUNCAO = REQFUNCAO.CFUNCAO
							INNER JOIN ENCARGOVIGENCIA ON ENCARGOVIGENCIA.ENCARGOVIGENCIA = REQFUNCAOENCARGO.ENCARGOVIGENCIA
							WHERE NOT REQFUNCAO.MATRICULA IS NULL
							  And ((REQFUNCAO.VisualizaQuadro = 1 and (isnull(REQFUNCAO.rateiobal, 0) = 0 and isnull(REQFUNCAO.rateiocap, 0) = 0)) 
							    OR (REQFUNCAO.VisualizaQuadro = 0 and (isnull(REQFUNCAO.rateiobal, 0) = 1 or isnull(REQFUNCAO.rateiocap, 0) = 1)))
							  AND ENCARGOVIGENCIA.SAL13 = 1
					    	  AND YEAR(REQFUNCAO.CALCULADO) = @TANO
							  AND MONTH(REQFUNCAO.CALCULADO) = @TMES
							  AND ISNULL(REQFUNCAO.MMO, 0) > 0) AS TT) AS TTT
		OPEN CurOPMatINSS2
		FETCH NEXT FROM CurOPMatINSS2
		INTO @OP_OP, @OP_MATRICULA, @PERCMES, @OP_INNS
		
		WHILE @@FETCH_STATUS = 0 BEGIN
			UPDATE ENCARGOOPTRABALHADOR SET InssSal13Devido = @OP_INNS, SAL13PERCMES = @PERCMES
				WHERE Ano = @TANO AND Mes = @TMES AND OP = @OP_OP AND Matricula = @OP_MATRICULA
			
			FETCH NEXT FROM CurOPMatINSS2
			INTO @OP_OP, @OP_MATRICULA, @PERCMES, @OP_INNS
		END
		CLOSE CurOPMatINSS2;
		DEALLOCATE CurOPMatINSS2;
		
		update encargoferiassal13 set
		   insspat = (SELECT sum(reqfuncaoencargo.valor)
					  from requisicao
					  inner join reqfuncao on (reqfuncao.requisicao = requisicao.requisicao)
					  inner join reqfuncaoencargo on (reqfuncaoencargo.cfuncao = reqfuncao.cfuncao)
					  inner join encargovigencia on (encargovigencia.encargovigencia = reqfuncaoencargo.encargovigencia)
					  where encargovigencia.insspat = 1
						and requisicao.cancelado = 0
						and reqfuncao.calculado is not null
						And ((reqfuncao.VisualizaQuadro = 1 and (isnull(reqfuncao.rateiobal, 0) = 0 and isnull(reqfuncao.rateiocap, 0) = 0)) 
						 OR (reqfuncao.VisualizaQuadro = 0 and (isnull(reqfuncao.rateiobal, 0) = 1 or isnull(reqfuncao.rateiocap, 0) = 1)))
						and reqfuncao.mmo > 0
						and month(reqfuncao.calculado) = encargoferiassal13.mes
						and year(reqfuncao.calculado) = encargoferiassal13.ano
						and reqfuncao.matricula = encargoferiassal13.matricula), 
						
		   insspatferias = (SELECT sum(reqfuncaoencargo.valor)
					  from requisicao
					  inner join reqfuncao on (reqfuncao.requisicao = requisicao.requisicao)
					  inner join reqfuncaoencargo on (reqfuncaoencargo.cfuncao = reqfuncao.cfuncao)
					  inner join encargovigencia on (encargovigencia.encargovigencia = reqfuncaoencargo.encargovigencia)
					  where encargovigencia.insspatferias = 1
						and requisicao.cancelado = 0
						and reqfuncao.calculado is not null
						And ((reqfuncao.VisualizaQuadro = 1 and (isnull(reqfuncao.rateiobal, 0) = 0 and isnull(reqfuncao.rateiocap, 0) = 0)) 
						 OR (reqfuncao.VisualizaQuadro = 0 and (isnull(reqfuncao.rateiobal, 0) = 1 or isnull(reqfuncao.rateiocap, 0) = 1)))
						and reqfuncao.mmo > 0
						and month(reqfuncao.calculado) = encargoferiassal13.mes
						and year(reqfuncao.calculado) = encargoferiassal13.ano
						and reqfuncao.matricula = encargoferiassal13.matricula), 
						
		   insspatsal13 = (SELECT sum(reqfuncaoencargo.valor)
					  from requisicao
					  inner join reqfuncao on (reqfuncao.requisicao = requisicao.requisicao)
					  inner join reqfuncaoencargo on (reqfuncaoencargo.cfuncao = reqfuncao.cfuncao)
					  inner join encargovigencia on (encargovigencia.encargovigencia = reqfuncaoencargo.encargovigencia)
					  where encargovigencia.insspatsal13 = 1
						and requisicao.cancelado = 0
						and reqfuncao.calculado is not null
						And ((reqfuncao.VisualizaQuadro = 1 and (isnull(reqfuncao.rateiobal, 0) = 0 and isnull(reqfuncao.rateiocap, 0) = 0)) 
						 OR (reqfuncao.VisualizaQuadro = 0 and (isnull(reqfuncao.rateiobal, 0) = 1 or isnull(reqfuncao.rateiocap, 0) = 1)))
						and reqfuncao.mmo > 0
						and month(reqfuncao.calculado) = encargoferiassal13.mes
						and year(reqfuncao.calculado) = encargoferiassal13.ano
						and reqfuncao.matricula = encargoferiassal13.matricula), 
						
		   insspatoutro = (SELECT sum(reqfuncaoencargo.valor)
					  from requisicao
					  inner join reqfuncao on (reqfuncao.requisicao = requisicao.requisicao)
					  inner join reqfuncaoencargo on (reqfuncaoencargo.cfuncao = reqfuncao.cfuncao)
					  inner join encargovigencia on (encargovigencia.encargovigencia = reqfuncaoencargo.encargovigencia)
					  where (encargovigencia.insspatoutro = 1 or encargovigencia.insspatgilrat = 1)
						and requisicao.cancelado = 0
						and reqfuncao.calculado is not null
						And ((reqfuncao.VisualizaQuadro = 1 and (isnull(reqfuncao.rateiobal, 0) = 0 and isnull(reqfuncao.rateiocap, 0) = 0)) 
						 OR (reqfuncao.VisualizaQuadro = 0 and (isnull(reqfuncao.rateiobal, 0) = 1 or isnull(reqfuncao.rateiocap, 0) = 1)))
						and reqfuncao.mmo > 0
						and month(reqfuncao.calculado) = encargoferiassal13.mes
						and year(reqfuncao.calculado) = encargoferiassal13.ano
						and reqfuncao.matricula = encargoferiassal13.matricula), 
						
		   insspatferiasoutro = (SELECT sum(reqfuncaoencargo.valor)
					  from requisicao
					  inner join reqfuncao on (reqfuncao.requisicao = requisicao.requisicao)
					  inner join reqfuncaoencargo on (reqfuncaoencargo.cfuncao = reqfuncao.cfuncao)
					  inner join encargovigencia on (encargovigencia.encargovigencia = reqfuncaoencargo.encargovigencia)
					  where (encargovigencia.insspatferiasoutro = 1 or encargovigencia.insspatferiasgilrat = 1)
						and requisicao.cancelado = 0
						and reqfuncao.calculado is not null
						And ((reqfuncao.VisualizaQuadro = 1 and (isnull(reqfuncao.rateiobal, 0) = 0 and isnull(reqfuncao.rateiocap, 0) = 0)) 
						 OR (reqfuncao.VisualizaQuadro = 0 and (isnull(reqfuncao.rateiobal, 0) = 1 or isnull(reqfuncao.rateiocap, 0) = 1)))
						and reqfuncao.mmo > 0
						and month(reqfuncao.calculado) = encargoferiassal13.mes
						and year(reqfuncao.calculado) = encargoferiassal13.ano
						and reqfuncao.matricula = encargoferiassal13.matricula), 
						
		   insspatsal13outro = (SELECT sum(reqfuncaoencargo.valor)
					  from requisicao
					  inner join reqfuncao on (reqfuncao.requisicao = requisicao.requisicao)
					  inner join reqfuncaoencargo on (reqfuncaoencargo.cfuncao = reqfuncao.cfuncao)
					  inner join encargovigencia on (encargovigencia.encargovigencia = reqfuncaoencargo.encargovigencia)
					  where (encargovigencia.insspatsal13outro = 1 or encargovigencia.insspatsal13gilrat = 1)
						and requisicao.cancelado = 0
						and reqfuncao.calculado is not null
						And ((reqfuncao.VisualizaQuadro = 1 and (isnull(reqfuncao.rateiobal, 0) = 0 and isnull(reqfuncao.rateiocap, 0) = 0)) 
						 OR (reqfuncao.VisualizaQuadro = 0 and (isnull(reqfuncao.rateiobal, 0) = 1 or isnull(reqfuncao.rateiocap, 0) = 1)))
						and reqfuncao.mmo > 0
						and month(reqfuncao.calculado) = encargoferiassal13.mes
						and year(reqfuncao.calculado) = encargoferiassal13.ano
						and reqfuncao.matricula = encargoferiassal13.matricula)
		Where encargoferiassal13.mes = @TMES
		  and encargoferiassal13.ano = @TANO			
		
	END TRY
	
	BEGIN CATCH
		IF (@@TRANCOUNT > 0) Begin
			ROLLBACK TRANSACTION;
			Insert Into [LOG] (auto, login, tabela, campo, descricao) Values ((select MAX(auto)+1 From log), 'SP_FECHAR_MES', 'SP', 'ERRO', substring(convert(varchar, ERROR_NUMBER()) + ' ' + ERROR_MESSAGE(),1,500));
		End
	END CATCH;
	
	IF (@@TRANCOUNT > 0) Begin
        Insert Into [LOG] (auto, login, tabela, campo, descricao) Values ((select MAX(auto)+1 From log), 'SP_FECHAR_MES', 'SP', 'Executada', 'SP Executada com Sucesso');
		COMMIT TRANSACTION;
	END
	
	SET @MENSAGEM = 1
	--SELECT @MENSAGEM, 'Cálculo efetuado.'
	
ERROANOMES:
	IF @MENSAGEM = 0 BEGIN
		SET @MENSAGEM = -1
		SELECT @MENSAGEM, 'Tem que indicar o ano e mês!'	
	END
	
ERROFECHOEXISTE:
	IF @MENSAGEM = 0 BEGIN
		SET @MENSAGEM = -2
		SELECT @MENSAGEM, 'O fecho já existente!'	
	END
END



