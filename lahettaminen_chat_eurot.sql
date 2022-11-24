
/*
Chat-lähettäminen 2022

Tarkoitus on analysoida, miten lähetteellisten / ilman lähetteitä olevien käyntien arvo on muuttunut vuosien varrella. 
Tarkoitus on myös selvittää, miten lähetteiden määrä on muuttunut vuosien varrella. 

Skriptissa yhdistetään käynteihin vastaavat lähetteet (lähettävä lääkäri, HT ja päivä samat) ja lasketaan käyntien arvo.



select HLO, ERIKOISALA 
INTO #TMPlaakarit
 from eres_vrk_toimikortti
where ERIKOISALA like '%työterv%' or ERIKOISALA  like '%yleislä%' or 
ERIKOISALA like 'lääketieteen lisen%'

-- Aseta min, max -päivämäärät
DECLARE @MinDate_ DATETIME = '2022-01-01'
DECLARE @MaxDate_ DATETIME = '2022-12-31'

DECLARE @MinDate DATETIME = DateDiff(day, DateAdd(day, -4, '1801-01-01'), @MinDate_)
DECLARE @MaxDate DATETIME = DateDiff(day, DateAdd(day, -4, '1801-01-01'), @MaxDate_)

-- luo summataulu käynneille, jossa jokaiselle käynnille on laskettu hinta
SELECT LKRI, NRO, HT, PVM, SUMMA
INTO #summa_kaynti
FROM (
    SELECT LKRI, NRO, HT, PVM, SUM(M_MK) AS SUMMA
    FROM dbo.laskut l
    GROUP BY LKRI, NRO, HT, PVM
    UNION ALL
    SELECT HLO AS LKRI, NRO, HT, PVM, SUM(M_MK) AS SUMMA
    FROM dbo.kaynnit l
    group by HLO, NRO, HT, PVM
) s
WHERE PVM >= @MinDate AND PVM <= @MaxDate



-- Sama labroille (labroilla erillinen hinta)
SELECT LKRI, NRO, HT, PVM, SUMMA
INTO #summa_labra
FROM (
    SELECT L_HLO AS LKRI, NRO, HT, PVM, SUM(M_MK) AS SUMMA
    FROM dbo.laskut l
    group by L_HLO, NRO, HT, PVM
    UNION ALL
    SELECT L_HLO AS LKRI, NRO, HT, PVM, SUM(M_MK) AS SUMMA
    FROM dbo.kaynnit l
    group by L_HLO, NRO, HT, PVM
) s
WHERE PVM >= @MinDate AND PVM <= @MaxDate

-- Maksajatieto maksutaulusta
SELECT NRO, TNS
into #maksut
FROM dbo.MAKSUT
WHERE PVM >= @MinDate AND PVM <= @MaxDate

-- Haetaan käynnit ja yhdistetään näihin niiden laskutus
SELECT PTR, a.LKRI, a.HT, a.PVM, a.ETNS, s.SUMMA, s.NRO, a.LAJI
INTO #kaynnit
FROM (
    SELECT * FROM dbo.aika
    WHERE PVM >= @MinDate AND PVM <= @MaxDate
    -- Poistetaan varaamattomat ajat
    AND HT != '999999-9999' AND HT != 'YRITYSAIKA'
) a 
LEFT JOIN #summa_kaynti s 
ON a.HT = s.HT AND s.PVM = a.PVM
-- a.LKRI = s.LKRI
INNER JOIN #TMPlaakarit t on t.HLO = a.LKRI

-- Haetaan labrat ja yhdistetään niiden laskutus
SELECT t.HLO AS LKRI, t.HT, t.PVM, s.SUMMA, s.NRO, t.lahete, PTR as labr_id
INTO #labrat
FROM (
    SELECT * FROM dbo.tulos
    WHERE PVM >= @MinDate AND PVM <= @MaxDate
	AND RYHMA not like '%COVID%'
) t
LEFT JOIN #summa_labra s 
ON t.HT = s.HT AND s.PVM = t.PVM
INNER JOIN #TMPlaakarit l
on l.HLO = t.HLO
-- and t.HLO = s.LKRI

-- Yhdistetään käynnit ja labrat
SELECT 
	t.ETNS,
	t.PVM,
    t.LAJI,
    case when t.lahete = 'V' then 1 else 0 end as lahete_kaytetty,
	lahete_tehty,
	kaynti_summa,
	lahetteen_summa,
    kaynti_summa + lahetteen_summa AS summa,
    m.TNS AS maksaja, 
	PTR, 
	labr_id
INTO #tulos
FROM (
    SELECT 
        k.ETNS, 
        k.PVM, 
        k.NRO,
        k.LAJI,
        l.lahete,
        CASE WHEN l.SUMMA IS NULL THEN 0 ELSE 1 END AS lahete_tehty,
        CASE WHEN k.SUMMA IS NULL THEN 0 ELSE k.SUMMA END AS kaynti_summa,
        CASE WHEN l.SUMMA IS NULL THEN 0 ELSE l.SUMMA END AS lahetteen_summa,
		PTR, 
		l.labr_id
    FROM #kaynnit k
    LEFT JOIN #labrat l
    -- Sama lääkäri, potilas ja päivän sisällä tehty lähete -> sama lähete
    ON k.HT = l.HT AND l.PVM BETWEEN k.PVM AND k.PVM + 1
    -- and k.LKRI = l.LKRI
	WHERE k.LAJI = 'CHAT'
) t
LEFT JOIN #maksut m
ON m.NRO = t.NRO
--WHERE t.kaynti_summa > 0 or t.lahetteen_summa > 0

-- Lasketaan tulostaulukko
SELECT
    LAJI as aikalaji,
    DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')) AS vuosi,
    DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')) AS viikko,
    sum(lahete_tehty) as tehdyt_lahetteet,
    sum(lahete_kaytetty) as kaytetyt_lahetteet,
    maksaja,
    CASE 
        WHEN maksaja IN ('T', 'V', 'Y') THEN 'muu' 
        WHEN maksaja IN ('P') THEN 'itse'
        ELSE 'tuntematon' END
    AS maksaja_tyyppi,
    COUNT(*) AS kayntien_maara,
    SUM(kaynti_summa) AS kaynti_summa,
--    AVG(kaynti_summa) AS kaynti_summa_keskiarvo,
    SUM(lahetteen_summa) AS lahetteen_summa,
--    AVG(lahetteen_summa) AS lahetteen_summa_keskiarvo, --tarkista, että se tulee lähetteen summien keskiarvoina (ei niin että rivitason ka)
    SUM(SUMMA) AS kokonais_summa,
--     AVG(SUMMA) AS kokonais_summa_keskiarvo, 
	count(distinct PTR) as kayntien_lkm,
	count(labr_id) as lab_lahetteiden_lkm
FROM #tulos
WHERE LAJI = 'CHAT'
GROUP BY LAJI, DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')), DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')), lahete_kaytetty, maksaja, lahete_tehty
ORDER BY viikko asc


*/
/* Sitten vain viikkotasolla */

/*
Lähetteiden arvoketjun analyysi 2022

Tarkoitus on analysoida, miten lähetteellisten / ilman lähetteitä olevien käyntien arvo on muuttunut vuosien varrella. 
Tarkoitus on myös selvittää, miten lähetteiden määrä on muuttunut vuosien varrella. 

Skriptissa yhdistetään käynteihin vastaavat lähetteet (lähettävä lääkäri, HT ja päivä samat) ja lasketaan käyntien arvo.

*/

-- Poistetaan ei-labrat, eli esim. tupakointitieto
SELECT DISTINCT TNS 
into #filter_non_billable
FROM dbo.tulos
where TNS = '0006    'OR TNS = 'BDI     'OR TNS = 'KUUL    'OR TNS = 'BBI     'OR TNS = 'SIIRTO  'OR TNS = 'PAINO   'OR TNS = 'BMI     'OR TNS = 'BMI     'OR TNS = 'LB      'OR TNS = 'PITUUS  'OR TNS = 'BMI     'OR TNS = '1. savuk'OR TNS = 'SYKE    'OR TNS = '2939    'OR TNS = 'SYKE    'OR TNS = '2939    'OR TNS = 'VYMP    'OR TNS = 'VYMP    'OR TNS = 'PULSSI  'OR TNS = 'BMI     'OR TNS = 'TYÖKYKY 'OR TNS = '2939    'OR TNS = 'VYMP    'OR TNS = 'BMI     'OR TNS = 'VYMP    'OR TNS = 'BDI     'OR TNS = 'VYMP    'OR TNS = 'Tupakka 'OR TNS = '2770    'OR TNS = '2099    'OR TNS = 'Pituus  'OR TNS = 'AUDIT   'OR TNS = 'Paino   'OR TNS = '2939    'OR TNS = 'VYMP    'OR TNS = 'VYMP    'OR TNS = '2939    'OR RYHMA = 'BMIND     'OR TNS = 'VYMP    'OR TNS = '2095    'OR TNS = '3914    'OR TNS = 'VYMP    'OR TNS = 'PITUUS  'OR TNS = 'VYMP    'OR TNS = 'PULSSI  'OR TNS = '2939    'OR TNS = '2939    'OR TNS = '2939    'OR TNS = 'VYMP    'OR TNS = '2939    'OR TNS = 'Audit   'OR TNS = 'Paino   'OR TNS = 'PAINO   'OR TNS = 'BMI     'OR TNS = 'BMI     'OR TNS = '2939    'OR TNS = 'HAMMAS  'OR TNS = 'bmi     'OR TNS = 'AUDIT   'OR TNS = '051     'OR TNS = 'VYMP    'OR TNS = 'PULSSI  'OR TNS = 'PITUUS  'OR TNS = 'BMI     'OR TNS = 'BMI     'OR TNS = 'PAINO   'OR TNS = 'ASKIVUOS'OR TNS = 'BMI     'OR TNS = '2939    'OR TNS = '2939    'OR TNS = 'FSIIRTO 'OR TNS = '2939    'OR TNS = '2939    'OR TNS = 'VYMP    'OR TNS = 'BMI     'OR TNS = 'BMI     'OR TNS = 'paino   'OR TNS = 'ASKIVUOS'OR TNS = 'BMI     'OR TNS = 'TYÖKYKY2'OR TNS = '2097    'OR TNS = 'RR      'OR TNS = 'BDI     'OR RYHMA = 'tth-SCREEN'


select HLO, ERIKOISALA 
INTO #TMPlaakarit
 from eres_vrk_toimikortti
where ERIKOISALA like '%työterv%' or ERIKOISALA  like '%yleislä%'  
--or ERIKOISALA like 'lääketieteen lisen%'

-- Aseta min, max -päivämäärät
DECLARE @MinDate_ DATETIME = '2022-01-01'
DECLARE @MaxDate_ DATETIME = '2022-12-31'

DECLARE @MinDate DATETIME = DateDiff(day, DateAdd(day, -4, '1801-01-01'), @MinDate_)
DECLARE @MaxDate DATETIME = DateDiff(day, DateAdd(day, -4, '1801-01-01'), @MaxDate_)

-- luo summataulu käynneille, jossa jokaiselle käynnille on laskettu hinta
SELECT LKRI, NRO, HT, PVM, SUMMA
INTO #summa_kaynti
FROM (
    SELECT LKRI, NRO, HT, PVM, SUM(M_MK) AS SUMMA
    FROM dbo.laskut l
    GROUP BY LKRI, NRO, HT, PVM
    UNION ALL
    SELECT HLO AS LKRI, NRO, HT, PVM, SUM(M_MK) AS SUMMA
    FROM dbo.kaynnit l
    group by HLO, NRO, HT, PVM
) s
WHERE PVM >= @MinDate AND PVM <= @MaxDate



-- Sama labroille (labroilla erillinen hinta)
SELECT LKRI, NRO, HT, PVM, SUMMA
INTO #summa_labra
FROM (
    SELECT L_HLO AS LKRI, NRO, HT, PVM, SUM(M_MK) AS SUMMA
    FROM dbo.laskut l
    group by L_HLO, NRO, HT, PVM
    UNION ALL
    SELECT L_HLO AS LKRI, NRO, HT, PVM, SUM(M_MK) AS SUMMA
    FROM dbo.kaynnit l
    group by L_HLO, NRO, HT, PVM
) s
WHERE PVM >= @MinDate AND PVM <= @MaxDate

-- Maksajatieto maksutaulusta
SELECT NRO, TNS
into #maksut
FROM dbo.MAKSUT
WHERE PVM >= @MinDate AND PVM <= @MaxDate

-- Haetaan käynnit ja yhdistetään näihin niiden laskutus
SELECT PTR, a.LKRI, a.HT, a.PVM, a.ETNS, s.SUMMA, s.NRO, a.LAJI
INTO #kaynnit
FROM (
    SELECT * FROM dbo.aika
    WHERE PVM >= @MinDate AND PVM <= @MaxDate
    -- Poistetaan varaamattomat ajat
    AND HT != '999999-9999' AND HT != 'YRITYSAIKA'
) a 
LEFT JOIN #summa_kaynti s 
ON a.HT = s.HT AND s.PVM = a.PVM
-- a.LKRI = s.LKRI
INNER JOIN #TMPlaakarit t on t.HLO = a.LKRI
where LAJI='CHAT'


SELECT tulos.* 
into #tmp_tulos
FROM dbo.tulos tulos
left outer join #filter_non_billable f on f.tns = tulos.tns where f.tns is null
and  PVM >= @MinDate AND PVM <= @MaxDate
AND RYHMA not like '%COVID%'

-- Haetaan labrat ja yhdistetään niiden laskutus
-- Tästä poistettu labralähettämisten monistaminen (useita osatutkimuksia -> useampi rivi #tulos-tauluun) 
SELECT t.HLO AS LKRI, t.HT, t.PVM, s.SUMMA, s.NRO, t.lahete, PTR as labr_id
INTO #labrat_tmp
FROM #tmp_tulos t
LEFT JOIN #summa_labra s 
ON t.HT = s.HT AND s.PVM = t.PVM
INNER JOIN #TMPlaakarit l
on l.HLO = t.HLO
--and t.HLO = s.LKRI

select  distinct LKRI, HT, PVM, SUMMA, NRO, lahete, labr_id 
into #labrat
from #labrat_tmp

-- Yhdistetään käynnit ja labrat
SELECT 
	t.ETNS,
	t.PVM,
    t.LAJI,
    case when t.lahete = 'V' then 1 else 0 end as lahete_kaytetty,
	lahete_tehty,
	kaynti_summa,
	lahetteen_summa,
    kaynti_summa + lahetteen_summa AS summa,
--    m.TNS AS maksaja, 
	PTR, 
	labr_id
INTO #tulos
FROM (
    SELECT 
        k.ETNS, 
        k.PVM, 
        k.NRO,
        k.LAJI,
        l.lahete,
        CASE WHEN l.SUMMA IS NULL THEN 0 ELSE 1 END AS lahete_tehty,
        CASE WHEN k.SUMMA IS NULL THEN 0 ELSE k.SUMMA END AS kaynti_summa,
        CASE WHEN l.SUMMA IS NULL THEN 0 ELSE l.SUMMA END AS lahetteen_summa,
		PTR, 
		l.labr_id
    FROM #kaynnit k
    LEFT JOIN #labrat l
    -- Sama lääkäri, potilas ja päivän sisällä tehty lähete -> sama lähete
    ON k.HT = l.HT AND l.PVM BETWEEN k.PVM AND k.PVM + 1
    -- and k.LKRI = l.LKRI
	WHERE k.LAJI = 'CHAT'
) t
--LEFT JOIN #maksut m
--ON m.NRO = t.NRO
WHERE t.kaynti_summa > 0 or t.lahetteen_summa > 0


SELECT 
	t.ETNS,
	t.PVM,
    t.LAJI,
    case when t.lahete = 'V' then 1 else 0 end as lahete_kaytetty,
	lahete_tehty,
	kaynti_summa,
	lahetteen_summa,
    kaynti_summa + lahetteen_summa AS summa,
--    m.TNS AS maksaja, 
	PTR, 
	labr_id
INTO #tulos_kaytetyt
FROM (
    SELECT 
        k.ETNS, 
        k.PVM, 
        k.NRO,
        k.LAJI,
        l.lahete,
        CASE WHEN l.SUMMA IS NULL THEN 0 ELSE 1 END AS lahete_tehty,
        CASE WHEN k.SUMMA IS NULL THEN 0 ELSE k.SUMMA END AS kaynti_summa,
        CASE WHEN l.SUMMA IS NULL THEN 0 ELSE l.SUMMA END AS lahetteen_summa,
		PTR, 
		l.labr_id
    FROM #kaynnit k
    LEFT JOIN #labrat l
    -- Sama lääkäri, potilas ja päivän sisällä tehty lähete -> sama lähete
    ON k.HT = l.HT AND l.PVM BETWEEN k.PVM AND k.PVM + 1
    -- and k.LKRI = l.LKRI
	WHERE k.LAJI = 'CHAT'
) t
--LEFT JOIN #maksut m
--ON m.NRO = t.NRO
WHERE (t.kaynti_summa > 0 or t.lahetteen_summa > 0) and t.lahete ='V'

SELECT 
	t.ETNS,
	t.PVM,
    t.LAJI,
    case when t.lahete = 'V' then 1 else 0 end as lahete_kaytetty,
	lahete_tehty,
	kaynti_summa,
	lahetteen_summa,
    kaynti_summa + lahetteen_summa AS summa,
--    m.TNS AS maksaja, 
	PTR, 
	labr_id
INTO #tulos_kayttamattomat
FROM (
    SELECT 
        k.ETNS, 
        k.PVM, 
        k.NRO,
        k.LAJI,
        l.lahete,
        CASE WHEN l.SUMMA IS NULL THEN 0 ELSE 1 END AS lahete_tehty,
        CASE WHEN k.SUMMA IS NULL THEN 0 ELSE k.SUMMA END AS kaynti_summa,
        CASE WHEN l.SUMMA IS NULL THEN 0 ELSE l.SUMMA END AS lahetteen_summa,
		PTR, 
		l.labr_id
    FROM #kaynnit k
    LEFT JOIN #labrat l
    -- Sama lääkäri, potilas ja päivän sisällä tehty lähete -> sama lähete
    ON k.HT = l.HT AND l.PVM BETWEEN k.PVM AND k.PVM + 1
    -- and k.LKRI = l.LKRI
	WHERE k.LAJI = 'CHAT'
) t
--LEFT JOIN #maksut m
--ON m.NRO = t.NRO
WHERE (t.kaynti_summa > 0 or t.lahetteen_summa > 0) and t.lahete <>'V'



-- Lasketaan tulostaulukko
SELECT
    LAJI as aikalaji,
    DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')) AS vuosi,
    DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')) AS viikko,
    SUM(kaynti_summa) AS kaynti_summa,
    SUM(lahetteen_summa) AS lahetteen_summa,
    SUM(SUMMA) AS kokonais_summa,
	count(distinct PTR) as kayntien_lkm,
	--count(labr_id) as lab_lahetteiden_lkm,
	sum(lahete_tehty) as tehdyt_lahetteet,
	sum(lahete_kaytetty) as kaytetyt_lahetteet
FROM #tulos
WHERE LAJI = 'CHAT'
GROUP BY LAJI, DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')), DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01'))--, lahete_kaytetty, maksaja, lahete_tehty
ORDER BY viikko asc


SELECT
    LAJI as aikalaji,
    DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')) AS vuosi,
    DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')) AS viikko,
    SUM(kaynti_summa) AS kaynti_summa,
    SUM(lahetteen_summa) AS lahetteen_summa,
    SUM(SUMMA) AS kokonais_summa,
	count(distinct PTR) as kayntien_lkm,
	--count(labr_id) as lab_lahetteiden_lkm,
	sum(lahete_tehty) as tehdyt_lahetteet,
	sum(lahete_kaytetty) as kaytetyt_lahetteet
FROM #tulos_kaytetyt
WHERE LAJI = 'CHAT'
GROUP BY LAJI, DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')), DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01'))--, lahete_kaytetty, maksaja, lahete_tehty
ORDER BY viikko asc

SELECT
    LAJI as aikalaji,
    DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')) AS vuosi,
    DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')) AS viikko,
    SUM(lahetteen_summa) AS kaytetyt_lahetteet_summa
FROM #tulos_kaytetyt
WHERE LAJI = 'CHAT'
GROUP BY LAJI, DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')), DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01'))--, lahete_kaytetty, maksaja, lahete_tehty
ORDER BY viikko asc

SELECT
    LAJI as aikalaji,
    DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')) AS vuosi,
    DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')) AS viikko,
    SUM(lahetteen_summa) AS kayttamattomat_lahetteet_summa
FROM #tulos_kayttamattomat
WHERE LAJI = 'CHAT'
GROUP BY LAJI, DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')), DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01'))--, lahete_kaytetty, maksaja, lahete_tehty
ORDER BY viikko asc

/*
-Labralähete tehty CHATistä - check 

-Labralähetteen tehnyt yle tai TTL - check 

-Covid poistettu luvuista - check 

-Labralähetteet vuodelta 2022
*millä tasolla? Päivä, viikko, kk?

-Labralähetteiden yhteenlaskettu myynti/€
*brutto vai netto?

-Tehtyjen labralähetteiden määrä

-Käytettyjen (labratulos valmistunut) labralähetteiden määrä

Meidän tarkoituksena on siis laskea, minkä arvoinen on yksi CHATista 
tehty lähete euroissa ja kuinka paljon siitä jää katetta. 
Tässä on vielä pari tarkennettavaa kysymystä, kuten se mitä lähete sisältää 
(lähetteitä on paljon, joten purkautuvatko nämä itse asiassa tutkimustasolle?)

*/
