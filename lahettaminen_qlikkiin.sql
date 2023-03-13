/* Lähettämisen Qlik-lataus */
-- Lähettäminen alk. v.2019. 
-- Mukana: laboratoriolähetteet, kuvantamisen lähetteet

use Doctorex_mirror

-- Poistetaan ei-labrat, eli esim. tupakointitieto
	SELECT DISTINCT TNS 
	into #filter_non_billable
	FROM dbo.tulos
	where TNS = '0006    'OR TNS = 'BDI     'OR TNS = 'KUUL    'OR TNS = 'BBI     'OR TNS = 'SIIRTO  'OR TNS = 'PAINO   'OR TNS = 'BMI     'OR TNS = 'BMI     'OR TNS = 'LB      'OR TNS = 'PITUUS  'OR TNS = 'BMI     'OR TNS = '1. savuk'OR TNS = 'SYKE    'OR TNS = '2939    'OR TNS = 'SYKE    'OR TNS = '2939    'OR TNS = 'VYMP    'OR TNS = 'VYMP    'OR TNS = 'PULSSI  'OR TNS = 'BMI     'OR TNS = 'TYÖKYKY 'OR TNS = '2939    'OR TNS = 'VYMP    'OR TNS = 'BMI     'OR TNS = 'VYMP    'OR TNS = 'BDI     'OR TNS = 'VYMP    'OR TNS = 'Tupakka 'OR TNS = '2770    'OR TNS = '2099    'OR TNS = 'Pituus  'OR TNS = 'AUDIT   'OR TNS = 'Paino   'OR TNS = '2939    'OR TNS = 'VYMP    'OR TNS = 'VYMP    'OR TNS = '2939    'OR RYHMA = 'BMIND     'OR TNS = 'VYMP    'OR TNS = '2095    'OR TNS = '3914    'OR TNS = 'VYMP    'OR TNS = 'PITUUS  'OR TNS = 'VYMP    'OR TNS = 'PULSSI  'OR TNS = '2939    'OR TNS = '2939    'OR TNS = '2939    'OR TNS = 'VYMP    'OR TNS = '2939    'OR TNS = 'Audit   'OR TNS = 'Paino   'OR TNS = 'PAINO   'OR TNS = 'BMI     'OR TNS = 'BMI     'OR TNS = '2939    'OR TNS = 'HAMMAS  'OR TNS = 'bmi     'OR TNS = 'AUDIT   'OR TNS = '051     'OR TNS = 'VYMP    'OR TNS = 'PULSSI  'OR TNS = 'PITUUS  'OR TNS = 'BMI     'OR TNS = 'BMI     'OR TNS = 'PAINO   'OR TNS = 'ASKIVUOS'OR TNS = 'BMI     'OR TNS = '2939    'OR TNS = '2939    'OR TNS = 'FSIIRTO 'OR TNS = '2939    'OR TNS = '2939    'OR TNS = 'VYMP    'OR TNS = 'BMI     'OR TNS = 'BMI     'OR TNS = 'paino   'OR TNS = 'ASKIVUOS'OR TNS = 'BMI     'OR TNS = 'TYÖKYKY2'OR TNS = '2097    'OR TNS = 'RR      'OR TNS = 'BDI    '

-- Aseta min, max -päivämäärät
	DECLARE @MinDate_ DATETIME = '2019-01-01'
	DECLARE @MaxDate_ DATETIME = GetDate() 

	DECLARE @MinDate DATETIME = DateDiff(day, DateAdd(day, -4, '1801-01-01'), @MinDate_)
	DECLARE @MaxDate DATETIME = DateDiff(day, DateAdd(day, -4, '1801-01-01'), @MaxDate_)


-- Maksajatieto maksutaulusta
SELECT NRO, TNS
into #maksut
FROM dbo.MAKSUT
WHERE PVM >= @MinDate AND PVM <= @MaxDate
	

SELECT c.LKRI, c.HT, c.Lablah_pvm, c.Lab_kaynti, c.Summa, lahete, Tutkimus
INTO #labra
FROM (
/*Käytetyt lähetteet, haetaan laskutuksesta ja lisätään lähetteeltä tieto lähetepäivästä*/
select distinct b.LKRI,b.HT,b.PVM,b.Lab_kaynti,SUM(b.SUMMA) as Summa,lab.Lablah_pvm,'V' as Lahete,'Muu' as Tutkimus
from
	(SELECT L_HLO AS LKRI, l.HT+' | '+CAST(l.PVM as varchar) as Lab_kaynti, NRO, HT, PVM, SUM(l.LKM*l.HINTA) AS SUMMA
	FROM dbo.laskut l left join palkkiot p on l.KOODI=p.KOODI
	where p.TUNNUS in ('LAB','LAB1','LAB4','LABP') 
	/*poistetaan tästä osiosta koronatestit*/
	and l.KOODI not in ('6466','6478','6492','6479','11034','11077','9901','7904','11091','10943','11109','11228')
	and l.L_HLO not in ('EILÄ','','WEB*')
	and l.HT<>''

	and PVM >= @MinDate

	group by L_HLO, NRO, HT, PVM

	UNION ALL 

	SELECT L_HLO AS LKRI, l.HT+' | '+CAST(l.PVM as varchar) as Lab_kaynti, NRO, HT, PVM, SUM(MK) AS SUMMA
	FROM dbo.kaynnit l left join palkkiot p on l.KOODI=p.KOODI
	where p.TUNNUS in ('LAB','LAB1','LAB4','LABP','KNF','KLF','PAT') 
	/*poistetaan tästä osiosta koronatestit*/
	and l.KOODI not in ('6466','6478','6492','6479','11034','11077','9901','7904','11091','10943','11109','11228')
	and l.L_HLO not in ('EILÄ','','WEB*')
	and l.HT<>''

	and PVM >= @MinDate

	group by L_HLO, NRO, HT, PVM
)b 

left join  (select distinct HLO,HT,PVM,L_PVM as Lablah_pvm
	from tulos t 
	where t.HLO not in ('EILÄ','WEB*')
	and t.LAHETE in ('V','N')
	/*poistetaan tästä osiosta koronatestit*/
	and t.TNS not in ('6466','6478','6492','6466,CVL','6466,CVS','6479','11033','10843','11034','11036','11077','9901','7904','11091','10943','11228')
	
	and t.L_PVM >= @MinDate AND PVM <= @MaxDate
)lab on b.HT=lab.HT and b.LKRI=lab.HLO and b.PVM=lab.PVM

group by b.LKRI,b.HT,b.PVM,b.Lab_kaynti,lab.Lablah_pvm

UNION ALL

/*Käyttämättömät lähetteet, nämä haetaan vain tulos-taulusta ja näille Lab_kaynti=NULL ja Summa=NULL*/
select distinct t2.HLO as LKRI,t2.HT,NULL as PVM,null as Lab_kaynti,NULL as Summa,t2.L_PVM as Lablah_pvm,t2.LAHETE,
CASE WHEN t2.TNS in ('6466','6478','6492','6466,CVL','6466,CVS','6479','11033','10843','11034','11036','11077','9901','7904','11091','10943','11228')
	THEN 'Covid'
	ELSE 'Muu' END as Tutkimus
from tulos t2
where t2.HLO not in ('EILÄ','','WEB*')
and t2.LAHETE='L'

and t2.L_PVM >= @MinDate AND PVM <= @MaxDate

UNION ALL

/*Käytetyt KORONATESTIlähetteet, haetaan laskutuksesta ja lisätään lähetteeltä tieto lähetepäivästä*/
select distinct b.LKRI,b.HT,b.PVM,b.Lab_kaynti,SUM(b.SUMMA) as Summa,lab.Lablah_pvm,'V' as Lahete,'Covid' as Tutkimus
from
	(SELECT L_HLO AS LKRI, l.HT+' | '+CAST(l.PVM as varchar) as Lab_kaynti, NRO, HT, PVM, SUM(l.LKM*l.HINTA) AS SUMMA
	FROM dbo.laskut l left join palkkiot p on l.KOODI=p.KOODI
	where  
	/*Haetaan AINOASTAAN koronatestit*/
	l.KOODI in ('6466','6478','6492','6479','11034','11077','9901','7904','11091','10943','11109','11228')
	and l.L_HLO not in ('EILÄ','','WEB*')
	and l.HT<>''

	and PVM >= @MinDate

	group by L_HLO, NRO, HT, PVM

	UNION ALL 

	SELECT L_HLO AS LKRI, l.HT+' | '+CAST(l.PVM as varchar) as Lab_kaynti, NRO, HT, PVM, SUM(MK) AS SUMMA
	FROM dbo.kaynnit l left join palkkiot p on l.KOODI=p.KOODI
	where 
	/*Haetaan AINOASTAAN koronatestit*/
	l.KOODI in ('6466','6478','6492','6479','11034','11077','9901','7904','11091','10943','11109','11228')
	and l.L_HLO not in ('EILÄ','','WEB*')
	and l.HT<>''

	and PVM >= @MinDate

	group by L_HLO, NRO, HT, PVM
)b 

left join  (select distinct HLO,HT,PVM,L_PVM as Lablah_pvm
	from tulos t 
	where t.HLO not in ('EILÄ','WEB*')
	and t.LAHETE in ('V','N')
	/*Haetaan AINOASTAAN koronatestit*/
	and t.TNS in ('6466','6478','6492','6466,CVL','6466,CVS','6479','11033','10843','11034','11036','11077','9901','7904','11091','10943','11228')
	
	and t.L_PVM >= @MinDate AND PVM <= @MaxDate
)lab on b.HT=lab.HT and b.LKRI=lab.HLO and b.PVM=lab.PVM

group by b.LKRI,b.HT,b.PVM,b.Lab_kaynti,lab.Lablah_pvm

)c


SELECT c.LKRI, c.NRO, c.HT, c.PVM, c.Kaynti, c.SUMMA
INTO #summa_kaynti
FROM (
SELECT LKRI, NRO, HT, PVM, HT+' | '+CAST(PVM as varchar) as Kaynti,
SUM(CAST(CASE WHEN ISNULL(l.AIKA,0)>0 
    THEN CAST((CAST(l.AIKA as float)-1)/360000 as decimal(9,5))
    WHEN ISNULL(l.AIKA,0)<0 THEN CAST((CAST(l.AIKA as float)+1)/360000 as decimal(9,5))
    ELSE l.LKM END *l.HINTA as decimal(8,2))) AS SUMMA
FROM dbo.laskut l left join palkkiot p on l.KOODI=p.KOODI
where p.TUNNUS not in ('LAB','LAB1','LAB4','LABP'/*kuvantamisen hinnastoryhmät:*/,'CT','MRI','RTG','UÄ','UÄG','UÄK')
and l.PVM >= @MinDate AND l.PVM <= @MaxDate


GROUP BY LKRI, NRO, HT, PVM

UNION ALL

SELECT HLO AS LKRI, NRO, HT, PVM, HT+' | '+CAST(PVM as varchar) as Kaynti, SUM(MK) AS SUMMA

FROM dbo.kaynnit l left join palkkiot p on l.KOODI=p.KOODI

where p.TUNNUS not in ('LAB','LAB1','LAB4','LABP'/*kuvantamisen hinnastoryhmät:*/,'CT','MRI','RTG','UÄ','UÄG','UÄK')
and l.PVM >= @MinDate AND l.PVM <= @MaxDate

group by HLO, NRO, HT, PVM

) c

-- Haetaan käynnit ja yhdistetään näihin niiden laskutus
	SELECT a.PTR, a.LKRI, a.HT, a.PVM, a.ETNS, s.SUMMA, s.NRO, a.LAJI, left(k.DG_KOODI,5) as DG_RYHMA, 
	a.HT+' | '+CAST(a.PVM as varchar) as Kaynti
	INTO #kaynnit
	FROM (
		SELECT * FROM dbo.aika
		WHERE PVM >= @MinDate AND PVM <= @MaxDate
		-- Poistetaan varaamattomat ajat
		AND HT != '999999-9999' AND HT != 'YRITYSAIKA'
	) a 
	LEFT JOIN #summa_kaynti s 
	ON a.HT = s.HT AND s.PVM = a.PVM and a.LKRI = s.LKRI
	LEFT JOIN kertomusdiagnoosit k
    ON k.PVM_XXX=s.PVM AND k.HT=s.HT AND k.HLO_XXX=s.LKRI
--    where  left(k.DG_KOODI,3) in ('J02', 'N40', 'N30', 'B35', 'I49', 'I48', 'J45', 'E66', 'R10', 
--	'F51', 'R53', 'G47', 'F90', 'K21', 'K59', 'S83', 'F32','F33','F34','E11','E03','E78','I10','J11','J20','J03')
/*J20.9*/
--or left(k.DG_KOODI,5) ='J06.9' or left(k.DG_KOODI,6) ='J06.89'


-- käyttämättömät labrat
select *, HT+' | '+CAST(Lablah_PVM as varchar) as Kaynti into #kayttamaton_labra from #labra where lahete <>'V'


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
--		labr_id,
		DG_RYHMA,
		lab_kaynti, 
		Tutkimus
		--,hinnastokoodi
	INTO #tulos
	FROM (
		SELECT 
		    distinct 
			k.ETNS, 
			k.PVM, 
			k.NRO,
			lab_kaynti,
			k.LAJI,
			l.lahete,
			CASE WHEN l.SUMMA IS NULL THEN 0 ELSE 1 END AS lahete_tehty,
			CASE WHEN k.SUMMA IS NULL THEN 0 ELSE k.SUMMA END AS kaynti_summa,
			CASE WHEN l.SUMMA IS NULL THEN 0 ELSE l.SUMMA END AS lahetteen_summa,
			k.PTR, 
--			l.labr_id, 
			k.DG_RYHMA, 
			Tutkimus
			--l.hinnastokoodi
		FROM #kaynnit k
		LEFT JOIN #labra l
		-- Sama lääkäri, potilas ja päivän sisällä tehty lähete -> sama lähete
		ON  l.Lab_kaynti = k.Kaynti  
		--AND l.hinnastokoodi = k.hinnastokoodi
		AND k.LKRI = l.LKRI
	) t
	LEFT JOIN #maksut m
	ON m.NRO = t.NRO


--  käyttämättömät
	SELECT 
		t.ETNS,
		t.PVM,
		t.LAJI,
		case when t.lahete = 'V' then 1 else 0 end as lahete_kaytetty,
		lahete,
		lahete_tehty,
		kaynti_summa,
		lahetteen_summa,
		kaynti_summa + lahetteen_summa AS summa,
	    NULL AS maksaja, 
		PTR, 
--		labr_id,
		DG_RYHMA,
		lab_kaynti, 
		Tutkimus
		--,hinnastokoodi
	INTO #tulos_kayttamattomat
	FROM (
		SELECT 
		    distinct 
			k.ETNS, 
			k.PVM, 
			k.NRO,
			lab_kaynti,
			k.LAJI,
			l.lahete,
			CASE WHEN l.lahete IS NULL THEN 0 ELSE 1 END AS lahete_tehty,
			CASE WHEN k.SUMMA IS NULL THEN 0 ELSE k.SUMMA END AS kaynti_summa,
			CASE WHEN l.SUMMA IS NULL THEN 0 ELSE l.SUMMA END AS lahetteen_summa,
			k.PTR, 
--			l.labr_id, 
			k.DG_RYHMA, 
			Tutkimus
			--l.hinnastokoodi
		FROM #kaynnit k
		LEFT JOIN #kayttamaton_labra l
		-- Sama lääkäri, potilas ja päivän sisällä tehty lähete -> sama lähete
		ON  l.Kaynti = k.Kaynti  
		--AND l.hinnastokoodi = k.hinnastokoodi
		--AND k.LKRI = l.LKRI
	) t
	--LEFT JOIN #maksut m
	--ON m.NRO = t.NRO




	-- Lasketaan tulostaulukko käynneille ja lähetteille, jotka on käytetty 
	SELECT
	    ETNS, 
		LAJI as aikalaji,
		DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')) AS vuosi,
		DATEPART(MONTH, DateAdd(day, PVM  - 4, '1801-01-01')) AS kuukausi,
		DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')) AS viikko,
		SUM(kaynti_summa) AS kaynti_summa,
		SUM(lahetteen_summa) AS lahetteen_summa,
		SUM(SUMMA) AS kokonais_summa,
		count(distinct PTR) as kayntien_lkm,
		count(lab_kaynti) as lab_lahetteiden_lkm,
		--sum(lahete_tehty) as tehdyt_lahetteet,
		--sum(lahete_kaytetty) as kaytetyt_lahetteet,
		lahete_tehty,
		lahete_kaytetty,
		DG_RYHMA,
		maksaja, 
		Tutkimus
		--,hinnastokoodi
	FROM #tulos
	--WHERE DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')) = 2022
	GROUP BY LAJI, DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')), DATEPART(MONTH, DateAdd(day, PVM  - 4, '1801-01-01')), DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')), DG_RYHMA--, hinnastokoodi
	, lahete_kaytetty, lahete_tehty, ETNS, maksaja, Tutkimus
	ORDER BY viikko asc
	
	-- Lasketaan tulostaulukko käyttämättömille lähetteille:
	SELECT
	    ETNS, 
		LAJI as aikalaji,
		DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')) AS vuosi,
		DATEPART(MONTH, DateAdd(day, PVM  - 4, '1801-01-01')) AS kuukausi,
		DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')) AS viikko,
		SUM(kaynti_summa) AS kaynti_summa,
		SUM(lahetteen_summa) AS lahetteen_summa,
		SUM(SUMMA) AS kokonais_summa,
		count(distinct PTR) as kayntien_lkm,
		count(lab_kaynti) as lab_lahetteiden_lkm,
		--sum(lahete_tehty) as tehdyt_lahetteet,
		--sum(lahete_kaytetty) as kaytetyt_lahetteet,
		lahete_tehty,
		lahete_kaytetty,
		DG_RYHMA,
		maksaja, 
		Tutkimus
		--,hinnastokoodi
	FROM #tulos_kayttamattomat
	where lahete_tehty=1
	--WHERE DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')) = 2022
	GROUP BY LAJI, DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')), DATEPART(MONTH, DateAdd(day, PVM  - 4, '1801-01-01')), DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')), DG_RYHMA--, hinnastokoodi
	, lahete_kaytetty, lahete_tehty, ETNS, maksaja, Tutkimus
	ORDER BY viikko asc




-- Haetaan kuvantamisen diagnooseille liittyvät käynnit ja yhdistetään näihin niiden laskutus
	SELECT a.PTR, a.LKRI, a.HT, a.PVM, a.ETNS, s.SUMMA, s.NRO, a.LAJI, left(k.DG_KOODI,5) as DG_RYHMA, 
	a.HT+' | '+CAST(a.PVM as varchar) as Kaynti
	INTO #kaynnit_kuvantaminen
	FROM (
		SELECT * FROM dbo.aika
		WHERE PVM >= @MinDate AND PVM <= @MaxDate
		-- Poistetaan varaamattomat ajat
		AND HT != '999999-9999' AND HT != 'YRITYSAIKA'
	) a 
	LEFT JOIN #summa_kaynti s 
	ON a.HT = s.HT AND s.PVM = a.PVM and a.LKRI = s.LKRI
	-- rajaus siihen valittuun lääkärijoukkoon
--	INNER JOIN #TMPlaakarit t on t.HLO = a.LKRI
	LEFT JOIN kertomusdiagnoosit k
    ON k.PVM_XXX=s.PVM and k.HT=s.HT and k.HLO_XXX=s.LKRI
--    where  left(k.DG_KOODI,3) in ('S83','S93','S63','S43','S46','S80','S60','S52','J45')


/*Käytetyt lähetteet, haetaan laskutuksesta ja lisätään lähetteeltä tieto lähetepäivästä*/
select distinct b.LKRI,b.HT,b.PVM,b.Kuv_kaynti,b.TUNNUS,SUM(b.SUMMA) as Summa,kuv.Kuvlah_pvm,'V' as Lahete
into #tulos_kuvantaminen
from
	(SELECT L_HLO AS LKRI, l.HT+' | '+CAST(l.PVM as varchar) as Kuv_kaynti, NRO, HT, PVM, SUM(l.LKM*l.HINTA) AS SUMMA,p.TUNNUS
	FROM dbo.laskut l left join palkkiot p on l.KOODI=p.KOODI
	where p.TUNNUS in ('CT','MRI','RTG','UÄ','UÄG','UÄK')
	and l.L_HLO not in ('*','EXT*','')
	and l.HT<>''

	and PVM >= @MinDate

	group by L_HLO, NRO, HT, PVM,p.TUNNUS

	UNION ALL 

	SELECT L_HLO AS LKRI, l.HT+' | '+CAST(l.PVM as varchar) as Kuv_kaynti, NRO, HT, PVM, SUM(MK) AS SUMMA,p.TUNNUS
	FROM dbo.kaynnit l left join palkkiot p on l.KOODI=p.KOODI
	where p.TUNNUS in ('CT','MRI','RTG','UÄ','UÄG','UÄK')
	and l.L_HLO not in ('*','EXT*','')
	and l.HT<>''

	and PVM >= @MinDate

	group by L_HLO, NRO, HT, PVM,p.TUNNUS
)b 


left join  (select distinct la.LAH_TRI,la.LAH_PVM as Kuvlah_pvm,la.HT,p.TUNNUS,r.KUV_PVM

	from lausunto la left join rad_tutkimus r on la.GUID=r.GUID and r.KUV_PVM>0
	left join palkkiot p on r.KOODI=p.KOODI

	WHERE la.LAH_TRI NOT IN ('EXT*','*')
	and la.HT<>''
	
	and la.LAH_PVM >= @MinDate AND PVM <= @MaxDate
)kuv on b.HT=kuv.HT and b.LKRI=kuv.LAH_TRI and b.PVM=kuv.KUV_PVM and b.TUNNUS=kuv.TUNNUS


group by b.LKRI,b.HT,b.PVM,b.Kuv_kaynti,b.Tunnus,kuv.Kuvlah_pvm


UNION ALL

/*Käyttämättömät lähetteet, nämä haetaan vain lausunto+rad_tutkimus+palkkiot-tauluista ja näille Kuv_kaynti=NULL ja Summa=NULL*/
select 
distinct la.LAH_TRI as LKRI,la.HT,NULL as PVM,  la.HT+' | '+CAST(LAH_PVM as varchar) as Kuv_kaynti,p.TUNNUS,NULL as Summac,la.LAH_PVM as Kuvlah_pvm,'L' as Lahete
from lausunto la left join rad_tutkimus r on la.GUID=r.GUID and r.KUV_PVM=0
left join palkkiot p on r.KOODI=p.KOODI

WHERE la.LAH_PVM >= @MinDate AND PVM <= @MaxDate
and la.LAH_TRI NOT IN ('EXT*','*')
and la.HT<>''

and not EXISTS (select 1 
	from lausunto la2 left join rad_tutkimus r2 on la2.GUID=r2.GUID and r2.KUV_PVM>0
	left join palkkiot p2 on r2.KOODI=p2.KOODI

	WHERE la2.LAH_PVM >= @MinDate AND PVM <= @MaxDate
	and la2.LAH_TRI NOT IN ('EXT*','*')
	and la2.HT<>''
	and la2.HT=la.HT and la2.LAH_TRI=la.LAH_TRI and la2.LAH_PVM=la.LAH_PVM and p.TUNNUS=p2.TUNNUS
	)

-- Yhdistetään käynnit ja kuvantamisen lähetteet
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
		Kuv_kaynti,
		DG_RYHMA
		--,hinnastokoodi
	INTO #tulos_kuvantamisella
	FROM (
		SELECT 
		    distinct 
			k.ETNS, 
			k.PVM, 
			k.NRO,
			k.LAJI,
			l.lahete,
			CASE WHEN l.Kuv_kaynti IS NULL THEN 0 ELSE 1 END AS lahete_tehty,
			CASE WHEN k.SUMMA IS NULL THEN 0 ELSE k.SUMMA END AS kaynti_summa,
			CASE WHEN l.SUMMA IS NULL THEN 0 ELSE l.SUMMA END AS lahetteen_summa,
			k.PTR, 
			l.Kuv_kaynti,
--			l.labr_id, 
			k.DG_RYHMA 
			--l.hinnastokoodi
		FROM #kaynnit_kuvantaminen k
		LEFT JOIN #tulos_kuvantaminen l
		-- Sama lääkäri, potilas ja päivän sisällä tehty lähete -> sama lähete
		ON  l.Kuv_kaynti = k.Kaynti   
		--AND l.hinnastokoodi = k.hinnastokoodi
		AND k.LKRI = l.LKRI
	) t
	LEFT JOIN #maksut m
	ON m.NRO = t.NRO


	-- Lasketaan tulostaulukko kuvantamisen lähetteille: 
	SELECT
	    ETNS, 
		LAJI as aikalaji,
		DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')) AS vuosi,
		DATEPART(MONTH, DateAdd(day, PVM  - 4, '1801-01-01')) AS kuukausi,
		DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')) AS viikko,
		SUM(kaynti_summa) AS kaynti_summa,
		SUM(lahetteen_summa) AS lahetteen_summa,
		SUM(SUMMA) AS kokonais_summa,
		count(distinct PTR) as kayntien_lkm,
		count(Kuv_kaynti) as lab_lahetteiden_lkm,
		--sum(lahete_tehty) as tehdyt_lahetteet,
		--sum(lahete_kaytetty) as kaytetyt_lahetteet,
		lahete_tehty,
		lahete_kaytetty,
		DG_RYHMA,
		maksaja
		--,hinnastokoodi
	FROM #tulos_kuvantamisella
	--WHERE DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')) = 2022
	GROUP BY LAJI, DATEPART(YEAR, DateAdd(day, PVM  - 4, '1801-01-01')), DATEPART(MONTH, DateAdd(day, PVM  - 4, '1801-01-01')), DATEPART(WEEK, DateAdd(day, PVM  - 4, '1801-01-01')), DG_RYHMA--, hinnastokoodi
	, lahete_kaytetty, lahete_tehty, ETNS, maksaja
	ORDER BY viikko asc
