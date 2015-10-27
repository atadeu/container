

EXEC SP_CRIAR_ASSIDUIDADE '20151001', '20151031'
delete from ASSIDUIDADE;

select * from ASSIDUIDADE;

SELECT * FROM FREQUENCIA
SELECT (count(T.MATRICULA)*4)*30 FROM TRABALHADOR T 
			WHERE	T.EFETIVO = 1
					AND T.EXCLUIDO = 0
					
					
select f.CAMBIO, COUNT(*)
						From REQUISICAO r
						join REQFUNCAO rf on rf.REQUISICAO = r.REQUISICAO
						join funcao f on f.FUNCAO = rf.funcao
						where r.DIA = '20151015' 
						  and r.PERIODO = 1
						  and r.CANCELADO =0
						  and rf.VISUALIZAQUADRO = 1
						  and f.CATEGORIA in (24,28,43)
						group by f.cambio;