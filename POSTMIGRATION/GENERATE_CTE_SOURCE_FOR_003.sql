WITH CONV AS (
SELECT EXTERNAL_AUDIT_ID
	,CONTRACT_NUMBER
	,FISCAL_YEAR
	,ISNULL(ACRNM, 'NULL') AS INSTITUTION_CODE
	,ISNULL(OPINION.CODE, 'NULL') AS OPINION_CODE
	,ISNULL(PRODUCT_STATUS.CODE, 'NULL') AS PRODUCT_STATUS_CODE
	,ISNULL(CONVERT(varchar, CONVERT(datetime, MIGRATED_DUE_DATE), 20), 'NULL') AS MIGRATED_DUE_DATE
	,EXTERNAL_AUDIT.CREATED
	,EXTERNAL_AUDIT.CREATED_BY
	,ROW_NUMBER() OVER(PARTITION BY CONTRACT_NUMBER
		,FISCAL_YEAR
		,ACRNM
		,OPINION.CODE
		,PRODUCT_STATUS.CODE
		,MIGRATED_DUE_DATE ORDER BY EXTERNAL_AUDIT_ID) AS RN
	,COUNT(*) OVER(PARTITION BY CONTRACT_NUMBER
		,FISCAL_YEAR
		,ACRNM
		,OPINION.CODE
		,PRODUCT_STATUS.CODE
		,MIGRATED_DUE_DATE) AS CNT
FROM EXTERNAL_AUDIT
JOIN CONTRACT ON CONTRACT_ID = FK_CONTRACT_ID
LEFT JOIN INSTITUTION ON INSTITUTION_ID = FK_AUDITOR_ID
LEFT JOIN CONVERGENCE_MASTER_DATA AS OPINION ON OPINION.CONVERGENCE_MASTER_DATA_ID = FK_OPINION_ID
LEFT JOIN CONVERGENCE_MASTER_DATA AS PRODUCT_STATUS ON PRODUCT_STATUS.CONVERGENCE_MASTER_DATA_ID = FK_PRODUCT_STATUS_ID
WHERE EXTERNAL_AUDIT.CREATED_BY IN ('MIGR_EXT_AUD', 'POSTMIGR_EXT_AUD_002')),

LMS AS (
SELECT CONTRACT_NUMBER
	,FISCAL_YEAR
	,INSTITUTION_CODE
	,OPINION_CODE
	,PRODUCT_STATUS_CODE
	,DUE_DATE
	,AUDIT_TYPE
FROM MIGR_WLMS_EXTERNAL_AUDIT)

SELECT CONCAT('SELECT ''',CONV.CONTRACT_NUMBER, ''' AS CONTRACT_NUMBER, '
	,CONV.FISCAL_YEAR, ' AS FISCAL_YEAR, '''
	,CONV.INSTITUTION_CODE, ''' AS INSTITUTION_CODE, '''
	,CONV.OPINION_CODE, ''' AS OPINION_CODE, '''
	,CONV.PRODUCT_STATUS_CODE, ''' AS PRODUCT_STATUS_CODE, '''
	,CONV.MIGRATED_DUE_DATE, ''' AS MIGRATED_DUE_DATE, '''
	,LMS.AUDIT_TYPE, ''' AS AUDIT_TYPE UNION ALL')
FROM CONV
LEFT JOIN LMS ON LMS.CONTRACT_NUMBER = CONV.CONTRACT_NUMBER
	AND LMS.FISCAL_YEAR = CONV.FISCAL_YEAR
	AND LMS.INSTITUTION_CODE = CONV.INSTITUTION_CODE
	AND LMS.OPINION_CODE = CONV.OPINION_CODE
	AND LMS.PRODUCT_STATUS_CODE = CONV.PRODUCT_STATUS_CODE
	AND LMS.DUE_DATE = CONV.MIGRATED_DUE_DATE
	AND (CONV.CNT = 1 
		OR (CONV.CNT = 2 
			AND LEFT(LMS.AUDIT_TYPE, 4) = 
				CASE CONV.RN 
					WHEN 1 THEN 'PROJ' 
					WHEN 2 THEN 'EXEC' 
				END))
WHERE LMS.CONTRACT_NUMBER IS NOT NULL
ORDER BY CONV.CONTRACT_NUMBER
	,CONV.FISCAL_YEAR
	,CONV.INSTITUTION_CODE
	,CONV.OPINION_CODE
	,CONV.PRODUCT_STATUS_CODE
	,CONV.MIGRATED_DUE_DATE
	,LMS.AUDIT_TYPE
