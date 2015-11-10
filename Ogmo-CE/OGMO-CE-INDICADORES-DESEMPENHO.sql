BEGIN

DECLARE @DTINICIO DATE = '20150301';
DECLARE @DTFIM DATE = '20150330';


SELECT 
T.MATRICULA,
T.NOME,
T.CATEGORIA,
(SELECT COUNT(*) FROM REQFUNCAO RQ WHERE RQ.ESCALADO BETWEEN @DTINICIO AND @DTFIM AND MATRICULA = T.MATRICULA) AS 'ENGAJAMENTO',
(SELECT COUNT(*) FROM OCORRENCIA O INNER JOIN GRUPO G ON O.GRUPO = G.GRUPO WHERE G.INDICADORDESEMPENHO IN (1,2,3)  
AND O.TRAVATPA = 1 AND O.MATRICULA = T.MATRICULA 
AND O.INICIO >= @DTINICIO AND (O.TERMINO IS NULL OR O.TERMINO <= @DTFIM ))  AS 'PUNICOES',
(SELECT COUNT(*) FROM OCORRENCIA O INNER JOIN GRUPO G ON O.GRUPO = G.GRUPO WHERE G.INDICADORDESEMPENHO = 2  
AND O.TRAVATPA = 1 AND O.MATRICULA = T.MATRICULA 
AND O.INICIO >= @DTINICIO AND (O.TERMINO IS NULL OR O.TERMINO <= @DTFIM ))  AS 'PUNICOESEPI',
(SELECT COUNT(*) FROM OCORRENCIA O INNER JOIN GRUPO G ON O.GRUPO = G.GRUPO WHERE G.INDICADORDESEMPENHO = 3  
AND O.TRAVATPA = 1 AND O.MATRICULA = T.MATRICULA 
AND O.INICIO >= @DTINICIO AND (O.TERMINO IS NULL OR O.TERMINO <= @DTFIM ))  AS 'PUNICOESASO',
(SELECT (CONVERT(MONEY, 
(SELECT COUNT(*) FROM HABILITACAO WHERE (HABILITADO <= @DTINICIO AND HABILITADO <= @DTFIM OR HABILITADO IS NULL) AND MATRICULA = T.MATRICULA AND (CHAMADA = 1 OR CHAMADA = 3))) 
* 100) / (SELECT COUNT(*) FROM FUNCAO F WHERE F.CATEGORIA = T.CATEGORIA))  AS 'CAPACITACAO',
(SELECT COUNT(*) FROM CAMBIOS WHERE CHAMADA > 3 AND MATRICULA = T.MATRICULA) AS 'LISTAMULTI',
(SELECT COUNT(*) FROM OCORRENCIA O INNER JOIN REQFUNCAO RQ ON RQ.CFUNCAO = O.CFUNCAO 
WHERE (O.INICIO >= @DTINICIO AND (O.TERMINO IS NULL OR O.TERMINO <= @DTFIM)) AND O.GRUPO = 46 AND O.MATRICULA = T.MATRICULA) 'FALTAENGAJADO',
(SELECT COUNT(*)*6 FROM REQFUNCAO RQ WHERE RQ.ESCALADO BETWEEN @DTINICIO AND @DTFIM AND MATRICULA = T.MATRICULA) AS 'HORATRABALHADAS',
(SELECT COUNT(*) FROM OCORRENCIA WHERE GRUPO = 6 AND MATRICULA = T.MATRICULA AND (INICIO >= @DTINICIO AND (TERMINO IS NULL OR TERMINO <= @DTFIM))) AS 'AFASTAMENTOINSS'
FROM TRABALHADOR T
WHERE T.EFETIVO = 1 AND T.EXCLUIDO = 0

END;