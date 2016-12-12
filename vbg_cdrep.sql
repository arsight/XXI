CREATE OR REPLACE package body XXI.vbg_cdrep is
Function Get_FieldValue(pString varchar2,pField varchar2) return varchar2 is
cStr cd_mda.cMdaSbl%Type;
cTemp cd_mda.cMdaSbl%Type;
cField cd_mda.cMdaSbl%Type;
cValue cd_mda.cMdaSbl%Type;
i binary_integer;
lCont boolean := true;
Begin
if pString is null or pString = '' then
   return null;
end if;
cStr := pString;
while lCont
Loop
  cField := null; cValue := null;
  i:= instr(cStr,';',1);
  if i=0
    then lCont := false;
    cTemp := cStr;
  else
    cTemp := substr(cStr,1,i-1);
    cStr := substr( cStr,i+1,length(cStr) );
  end if;
  cField := substr(cTemp,1,instr(cTemp,'=',1)-1);
  if cField = pField then
     cValue := substr( cTemp,instr(cTemp,'=',1)+1,length(cTemp) );
    exit;
  end if;
End Loop;
return cValue;
End Get_FieldValue;
-- Сумма платежных позиций за дату по текущим счетам кред.договора  ( приводится к валюте договора )
Function get_current_accs_pp(pAgrId cda.nCdaAgrId%Type, pDate date default cd.get_lsdate ) return number is
nRet number := 0;
nTemp number := 0;
cCur acc.cAccCur%Type;
Begin
  select  cCdaCurIso, greatest(nvl(ACC_INFO.GetAccountPP( cCdaCurrentAcc ,cCdaCurIso, pDate ),0),0) into cCur,nRet
  from cda where nCdaAgrId = pAgrId
  and cCdaCurrentAcc is not null;

  select nvl(sum(greatest(ACC_INFO.GetAccountPP(cda_acc.cAddAcc,cda_acc.cAddCurIso,pDate),0)*rates.Cross_Rate_New(cda_acc.cAddCurIso, cCur, pDate) ), 0) into nTemp
  from cda_acc,cda2
  where
  cda_acc.nAddAgrId = pAgrId
  and cda2.nCda2AgrId   = cda_acc.nAddAgrId
  and cda_acc.nAddType in (2,100) and cda2.CCDA2ISOTHERACCPAY = '1'
  and iAddOrder is not null;
  return nRet+nTemp;
End get_current_accs_pp;
-- Сумма остатков на конец отчетной даты по текущим счетам кред.договора ( приводится к валюте договора )
Function get_current_accs_ost(pAgrId cda.nCdaAgrId%Type, pDate date default cd.get_lsdate ) return number is
nRet number := 0;
nTemp number := 0;
cCur acc.cAccCur%Type;
Begin
  select  cCdaCurIso,greatest(nvl(util_dm2.ACC_Ostt(0,cCdaCurrentAcc ,cCdaCurIso,pDate+1,'V'),0),0) into cCur,nRet
  from cda where nCdaAgrId = pAgrId
  and cCdaCurrentAcc is not null;

  select nvl(sum(greatest(util_dm2.ACC_Ostt(0,cda_acc.cAddAcc,cda_acc.cAddCurIso,pDate+1,'V'),0)*rates.Cross_Rate_New(cda_acc.cAddCurIso, cCur, pDate) ), 0) into nTemp
  from cda_acc,cda2
  where
  cda_acc.nAddAgrId = pAgrId
  and cda2.nCda2AgrId   = cda_acc.nAddAgrId
  and cda_acc.nAddType in (2,100) and cda2.CCDA2ISOTHERACCPAY = '1'
  and iAddOrder is not null;
  return nRet+nTemp;
End get_current_accs_ost;
-- Сумма остатков на конец отчетной даты по текущим счетам кред.договора ( приводится к валюте договора )
Function get_current_accs_ostAll(pCusNum cus.iCusNum%Type, pCur acc.cAccCur%Type, pDate date default cd.get_lsdate ) return number is
nRet number := 0;
nTemp number := 0;
cCur acc.cAccCur%Type;
Begin
  select nvl(sum(greatest(util_dm2.ACC_Ostt(0,cAccAcc,cAccCur,pDate+1,'V'),0)*rates.Cross_Rate_New(cAccCur, pCur, pDate) ), 0) into nTemp
  from acc
  where
  iAccCus = pCusNum
  and (cAccAcc like '40817%' or cAccAcc like '40820%')
  and cAccPrizn != 'З'
--  and not exists ( select '' from gac where cGacAcc = cAccAcc and cGacCur = cAccCur and iGacCat = 3 and iGacNum = 123);
  and not exists ( select '' from pl_ca where pl_ca.cAccAcc = acc.cAccAcc and pl_ca.cAccCur = acc.cAccCur);  
  return nRet+nTemp;
End get_current_accs_ostAll;
--- подсчет общего количества дней просрочки по типам(типу):Осн.долг,%%,%% на просроч.осн.долг
-- при подсчете день просрочки учитывается всего один раз.
-- iRepPeriod - период расчета просрочки, cOVerDue - 'ALL' - все возникшие просрочки, 'NOT_CANCELED' - только не погашенные, cInclDateVozvr - включать день возврата? '0' - просрочка начинается на след. день после даты возврата; '1'  - просрочка начинается с даты возврата
Function calc_CntDays_Overdue(nAgrId in NUMBER, cType in VARCHAR2 DEFAULT 'AI', iRepPeriod in integer default 180, cOverDue in varchar2 default 'ALL', cInclDateVozvr in varchar2 default '0',
pDate  IN date default cd.get_lsdate ) Return INTEGER IS
Cursor c1 IS
SELECT iCdoPart,cCdoType, dCdoStart,dOverdue dOverdue, least(dOverdue,pDate) dOverDue1
FROM (
   SELECT
   DISTINCT
   icdoPART, ccdoTYPE, dcdoSTART,
   NVL((SELECT dCdoDate-2          /* Дата окончания просрочки : dCdoDate = дата уплаты + 1;  Дата окончания просрочки = дата полной уплаты просрочки - 1 = dCdoDate-2 */
        FROM v_cdo c1
        WHERE c1.iCdoPart = cdo.iCdoPart AND c1.cCdoType = cdo.cCdoType
          AND c1.nCdoAgrId = cdo.nCdoAgrId
          AND c1.cCdoSessionId = cdo.cCdoSessionId
          and nvl(c1.iCdoCmfid,0) = nvl(cdo.iCdoCmfId,0) -- !!
          AND c1.dCdoStart = cdo.dCdoStart AND c1.mCdoOverDue=0),pDate) dOverDue
   FROM V_CDO cdo, cmf
--     с учетом родительских договоров
   WHERE ncdoAGRID in (select nCdaAgrId from cda_mf connect by nCdaAgrId = prior nCdaParent start with nCdaAgrId = nAgrId )
   AND dcdoSTART <= pDate
-- для %% 0.01 не является просрочкой, а ошибкой округления
   and cdo.iCdoCmfId=cmf.iCmfId(+)
   AND ( cCdoType='I' AND mCdoOverDue>0.01 OR cCdoType != 'I')
   AND ( cCdoType='O' AND mCdoOverDue>0.01 OR cCdoType != 'O')
   AND ( cdo.cCdoType = 'C' and nvl(cmf.iCmfType,0) != 1 or cdo.cCdoType <> 'C' ) -- комиссия - не штрафная
--        AND cCdoSessionId = SYS_CONTEXT ('USERENV','SESSIONID')
   ORDER BY icdoPART, ccdoTYPE, dcdoSTART
) WHERE ( cCdoType IN ('A','I') AND cType = 'AI' OR
          cCdoType IN ('A','I','O') AND cType = 'AIO' OR
          cCdoType IN ('A','I','O','C') AND cType = 'AIOC' OR
          cCdoType IN ('A') AND cType = 'A' OR
          cCdoType = 'I' AND cType = 'I' OR
          cCdoType = 'O' AND cType = 'O' OR -- просрочка %% на просроч.ср-ва
          cCdoType in ('I','O') AND cType = 'IO' OR
          cCdoType = 'C' AND cType = 'C' )
          AND ( cOverDue = 'ALL' and ( ( iRepPeriod is null  ) or
                                       ( iRepPeriod is not null and pDate - dOverDue <= iRepPeriod  )
                                     )
            or  (cOverDue = 'NOT CANCELED' and ( dOverDue >= pDate or dOverDue is null ))
            )
ORDER BY dCdoStart;
iRet INTEGER := -1;
lOverDue boolean := false;
dPeriodMin DATE := TO_DATE('01.01.1900','dd.mm.yyyy');
dPeriodMax DATE := TO_DATE('01.01.1900','dd.mm.yyyy');
lPeriod boolean := false;
Begin
FOR rec IN c1 Loop
 lOverDue := true;
 lPeriod := false;
  if iRepPeriod is not null and pDate-rec.dCdoStart>iRepPeriod  then
      rec.dCdoStart := pDate - iRepPeriod+1;
      lPeriod := true;
  End if;
  If rec.dCdoStart between dPeriodMin and dPeriodMax OR
       rec.dOverDue1 between dPeriodMin and dPeriodMax then
     dPeriodMin := LEAST(dPeriodMin,rec.dCdoStart);
     dPeriodMax := GREATEST(dPeriodMax,rec.dOverDue1);
  DBMS_OUTPUT.PUT_LINE('if: dCdoStart='||TO_CHAR(rec.dCdoStart)||' dOverDue='||TO_CHAR(rec.dOverDue)||' iRet='||iRet);
  DBMS_OUTPUT.PUT_LINE('if: dPeriodMin='||TO_CHAR(dPeriodMin)||' dPeriodMax='||TO_CHAR(dPeriodMax) );
  ELSE
     iRet := iRet + dPeriodMax-dPeriodMin+1;
  DBMS_OUTPUT.PUT_LINE('else: dCdoStart='||TO_CHAR(rec.dCdoStart)||' dOverDue='||TO_CHAR(rec.dOverDue)||' iRet='||iRet);
  DBMS_OUTPUT.PUT_LINE('else: dPeriodMin='||TO_CHAR(dPeriodMin)||' dPeriodMax='||TO_CHAR(dPeriodMax) );
    if cInclDateVozvr='1' and lPeriod = false then
     dPeriodMin := rec.dCdoStart-1;
    else
     dPeriodMin := rec.dCdoStart;
    end if;
    dPeriodMax := rec.dOverDue1;
  DBMS_OUTPUT.PUT_LINE('else2: dPeriodMin='||TO_CHAR(dPeriodMin)||' dPeriodMax='||TO_CHAR(dPeriodMax)||' iRet='||iRet );
  End If;
End Loop;
if lOverDue then
  DBMS_OUTPUT.PUT_LINE('after if: dPeriodMin='||TO_CHAR(dPeriodMin)||' dPeriodMax='||TO_CHAR(dPeriodMax) );
  iRet := iRet + dPeriodMax-dPeriodMin+1;
else
  iRet := 0;
end if;
Return iRet ;
End calc_CntDays_Overdue;
-- ------------------------------------------------
-- Получить максимальное число дней непрерывной просрочки по договору на дату модуля с даты подписания договора
Function get_max_continuous_Overdue(nAgrId Number) return integer is
iOverDue integer;
Begin
    Begin
    select max(least(dOverdue,cd.get_lsdate) - (dCdoStart-1)) + CDENV.Is_Include_EndDate into iOverDue
    from
    (
    SELECT iCdoPart,cCdoType, dCdoStart,dOverdue dOverdue
    FROM (
       SELECT
       DISTINCT
       icdoPART, ccdoTYPE, dcdoSTART,
       NVL((SELECT dCdoDate
        FROM cdo c1
        WHERE c1.iCdoPart = cdo.iCdoPart AND c1.cCdoType = cdo.cCdoType
              AND c1.nCdoAgrId = cdo.nCdoAgrId
              AND c1.cCdoSessionId = cdo.cCdoSessionId
              AND c1.dCdoStart = cdo.dCdoStart AND c1.mCdoOverDue=0),Cd.Get_LSDATE) dOverDue
            FROM CDO
    --     с учетом родительских договоров
            WHERE
            ncdoAGRID in (select nCdaAgrId from cda connect by nCdaAgrId = prior nCdaParent start with nCdaAgrId = nAgrId )
            AND dcdoSTART <= Cd.get_lsdate
    -- для %% 0.01 не является просрочкой, а ошибкой округления
            AND ( cCdoType='I' AND mCdoOverDue>0.01 OR cCdoType != 'I')
            AND ( cCdoType='O' AND mCdoOverDue>0.01 OR cCdoType != 'O')
            AND cCdoSessionId = SYS_CONTEXT ('USERENV','SESSIONID')
            ORDER BY icdoPART, ccdoTYPE, dcdoSTART
    ) WHERE   cCdoType IN ('A','I','O')
    );
    exception
    When No_Data_Found then
     iOverDue := 0;
    End;
return iOverDue;
End get_max_continuous_Overdue;
-- ----------------------------------------------------
-- Выдачи по договору
Function get_vydachaAgr(pAgrId IN number, pDate Date default cd.get_lsdate) return NUMBER is
nDummy number;
nRet   number;
Begin
 nDummy := CDbalance.Recalc_Balance_rep(pAgrId,1);
 select
 sum(DECODE (icdaISLINE + NVL (icdaLINETYPE, 0),
                    1,
                    mcbpSUM - mcdbREAL - mcdbOVERDUE,
                    3,
                    mcbpSUM - mcdbREAL - mcdbOVERDUE,
                    4,
                    mcbpSUM - CD.Get_Debit_TO (ncdbAGRID, icdbPART), --+CDSTATE2.Get_Sum_InProl(ncdbAGRID,icdbPART),
                    5,
                    mcbpSUM - CD.Get_Debit_TO (ncdbAGRID, icdbPART),
                    0,
                    mcbpSUM - CD.Get_Debit_TO (ncdbAGRID, icdbPART),
                    2,
                    mcbpSUM - CD.Get_Debit_TO (ncdbAGRID, icdbPART) --+CDSTATE2.Get_Sum_InProl(ncdbAGRID)                                                                   )
                    ) )  mcbfNU into nRet
from v_cdb, cbp,cda
where ncdbAGRID = ncbpAGRID AND icdbPART = icbpPART
            AND dcdbDATE =
                  (SELECT   MAX (dcdbDATE)
                     FROM   CDB
                    WHERE       ncdbAGRID = ncbpAGRID
                            AND icdbPART = icbpPART
                            AND dcdbDATE <= pDate
                            AND CCDBSESSIONID = USERENV ('SESSIONID'))
            AND ncdaAGRID = ncdbAGRID
            AND ncdbAGRID = pAgrId;
  return nRet;
Exception
  when No_Data_Found then
     return Null;
End get_vydachaAgr;
-- из rp_nor
--<<======= взвешеный резерв по п/с "Кредиты" по текущему филиалу ==============
FUNCTION GetRezervCD(D        in Date,
                     cAcc     in Varchar2,
                     cCur     in Varchar2,
                     mOst     in number,
                     agrid    in number,
                     p_client in number,
                     p_risk   in number,
                     p_prtfid in number,
                     iSforRez in Number,
                     iCes     in Number
                     )
 RETURN Number
 IS
 Rez         Number(22,2) := 0; -- резерв
 Full_cbc    Number(22,2) := 0; -- полный остаток на договоре
 result      Number(22,2) := 0;
 cERR        Varchar2(1024);
 STV_reserv  Number(18,2);
 typeacc     Number := 1;       -- 1-полный остаток
 typeaccCes  Number := 701;     -- 701-полный остаток для договоров - цессий
 dCrs date;
Begin
 iF NVL(PREF.Get_Global_Preference('S12_USE_CLND'),0) = 1 then -- курсы
  dCrs := PCALISO.next_workday('RUR',D,-1);
  Else
  dCrs := D;
 end if;
 if nvl(iCes,0) = 1 then
  Full_cbc := CDBALANCE.get_CurSaldo(agrid, typeaccCes, null, null, (D-1))*RATES.Cur_Rate_New(cCur, dCrs)+
              CDBALANCE.get_CurSaldo(agrid, 711, null, null, (D-1))*RATES.Cur_Rate_New(cCur, dCrs)+
              CDBALANCE.get_CurSaldo(agrid, 5, null, null, (D-1))*RATES.Cur_Rate_New(cCur, dCrs);
 else
  Full_cbc := CDBALANCE.get_CurSaldo(agrid, typeacc, null, null, (D-1))*RATES.Cur_Rate_New(cCur, dCrs)+
              CDBALANCE.get_CurSaldo(agrid, 5, null, null, (D-1))*RATES.Cur_Rate_New(cCur, dCrs);
 end if;
 if NVL(iSforRez,0) = 1 and NVL(p_prtfid, -1) < 0 then -- (Если сформированный резерв и если не "портфель" и кредиты)
  Rez := RP_UTIL.GetRezLink(cAcc, cCur, 'R', 0, D);
 else -- Если расчетный резерв, или сформированный с портфелем
   STV_reserv := NVL(CDRESERVE.Get_AgrRiskRate(agrid, p_client, p_risk, p_prtfid, (D-1)), 0);
   Rez := Full_cbc * STV_reserv/100;
 end if;
 If Full_cbc = 0 then
   Full_cbc := 1;
 end if;
 Result := mOst*NVL(Rez, 0)/Full_cbc;
 Return result;
Exception When others then
 result := 0;
 cERR:='Ошибка при расчете взвешен-го резерва GetRezervCD: '||SqlErrM;
 dbms_output.put_line(cERR);
 Return result;
END GetRezervCD;
--
Function get_TotalIntFromAccs(pAgrId in number, pDate in date, pCes in integer default null) return number is
mPrem number;
iTypeDiscont integer;
mIntOst  Number;
iCes integer := 0;
mOst number  := 0;
-- cdterms2.Get_CurISO(nCdvAgrId)
cursor c1 is
select distinct cAcc, cCur
from (
 select cdterms.Get_DogACC(pAgrId, 10) cAcc, cdterms2.Get_CurISO(pAgrId) cCur from dual
 union all
 select cdterms.Get_DogACC(pAgrId, 6),   cdterms2.Get_CurISO(pAgrId) from dual
 union all
 select cdterms.Get_DogACC(pAgrId, 101), cdterms2.Get_CurISO(pAgrId) from dual
 union all
 select cdterms.Get_DogACC(pAgrId, 106), cdterms2.Get_CurISO(pAgrId) from dual
);
Begin
  if pCes is null then
    select iCdaCes into iCes from cda where nCdaAgrId = pAgrId;
  else
    iCes := pCes;
  end if;
  if iCes = 1 then
       Begin
        select iCdhIval into iTypeDiscont from cdh where nCdhAgrId = pAgrId and cCdhTerm='DISCRATE' and dCdhDate<=pDate and dCdhDate = (select max(h.dCdhDate) from cdh h where h.nCdhAgrId = pAgrId and h.cCdhTerm='DISCRATE' and h.dCdhDate<=pDate ) ;
      Exception
        when No_Data_Found then
          iTypeDiscont := 0;
      End;
      if iTypeDiscont in (1,2) then -- дисконт, премия
        select nvl(pCdhPval,0)/100 into mPrem from cdh where nCdhAgrId = pAgrId and cCdhTerm='DISCRATE' and dCdhDate<=pDate and dCdhDate = (select max(h.dCdhDate) from cdh h where h.nCdhAgrId = pAgrId and h.cCdhTerm='DISCRATE' and h.dCdhDate<=pDate) ;
      End if;
 end if;
  for rec in c1 Loop
    mOst := mOst + nvl(UTIL_DM2.acc_ostt(0,rec.cAcc,rec.cCur,pDate+1,'R',1),0);
  End Loop;
  if iCes = 1 and iTypeDiscont=2 then
     mOst := mOst/(1+mPrem);
  end if;
  return mOst;
End get_TotalIntFromAccs;
--
Function getODFromAccs(pAgrId in number, pDate in date, pCes in integer default null) return number is
mPrem number;
iCes integer := 0;
iTypeDiscont integer;
mOst  Number := 0;
cursor c1 is
select distinct cAcc,cCur
from (
select CDTerms.Get_PartLoanACC(NCDQAGRID, ICDQPART) cAcc, cdterms2.Get_CurISO(pAgrId) cCur
from cdq where nCdqAgrId = pAgrId );
Begin
  if pCes is null then
    select iCdaCes into iCes from cda where nCdaAgrId = pAgrId;
  else
    iCes := pCes;
  end if;
  if iCes = 1 then
      Begin
        select iCdhIval into iTypeDiscont from cdh where nCdhAgrId = pAgrId and cCdhTerm='DISCRATE' and dCdhDate<=pDate and dCdhDate = (select max(h.dCdhDate) from cdh h where h.nCdhAgrId = pAgrId and h.cCdhTerm='DISCRATE' and h.dCdhDate<=pDate ) ;
      Exception
        when No_Data_Found then
          iTypeDiscont := 0;
      End;
      if iTypeDiscont in (1,2) then -- дисконт, премия
        select nvl(pCdhPval,0)/100 into mPrem from cdh where nCdhAgrId = pAgrId and cCdhTerm='DISCRATE' and dCdhDate<=pDate and dCdhDate = (select max(h.dCdhDate) from cdh h where h.nCdhAgrId = pAgrId and h.cCdhTerm='DISCRATE' and h.dCdhDate<=pDate) ;
      End if;
  end if;
  for rec in c1 Loop
    mOst := mOst + nvl(UTIL_DM2.acc_ostt(0,rec.cAcc,rec.cCur,pDate+1,'R',1),0);
  End Loop;
  if iCes = 1 and iTypeDiscont=2 then
     mOst := mOst/(1+mPrem);
  end if;
  return mOst;
End getODFromAccs;
Function getProsrOdFromAccs(pAgrId in number, pDate in date, pCes in integer default null) return number is
mPrem number;
iCes integer := 0;
iTypeDiscont integer;
mOst  Number := 0;
cursor c1 is
select distinct cAcc,cCur
from (
 select cdterms.Get_DogACC(pAgrId, 5) cAcc, cdterms2.Get_CurISO(pAgrId) cCur from dual
 union all
 select cdterms.Get_DogACC(pAgrId, 711),   cdterms2.Get_CurISO(pAgrId) from dual
 );
Begin
  if pCes is null then
    select iCdaCes into iCes from cda where nCdaAgrId = pAgrId;
  else
    iCes := pCes;
  end if;
  if iCes = 1 then
      Begin
        select iCdhIval into iTypeDiscont from cdh where nCdhAgrId = pAgrId and cCdhTerm='DISCRATE' and dCdhDate<=pDate and dCdhDate = (select max(h.dCdhDate) from cdh h where h.nCdhAgrId = pAgrId and h.cCdhTerm='DISCRATE' and h.dCdhDate<=pDate ) ;
      Exception
        when No_Data_Found then
          iTypeDiscont := 0;
      End;
      if iTypeDiscont in (1,2) then -- дисконт, премия
        select nvl(pCdhPval,0)/100 into mPrem from cdh where nCdhAgrId = pAgrId and cCdhTerm='DISCRATE' and dCdhDate<=pDate and dCdhDate = (select max(h.dCdhDate) from cdh h where h.nCdhAgrId = pAgrId and h.cCdhTerm='DISCRATE' and h.dCdhDate<=pDate) ;
      End if;
  end if;
  for rec in c1 Loop
    mOst := mOst + nvl(UTIL_DM2.acc_ostt(0,rec.cAcc,rec.cCur,pDate+1,'R',1),0);
  End Loop;
  if iCes = 1 and iTypeDiscont=2 then
     mOst := mOst/(1+mPrem);
  end if;
  return mOst;
End getProsrODFromAccs;
--
Function Get_Proc_St(pAgrId IN number ) return number is
--
  INTOR      NUMBER;
  PERCENT    NUMBER;
  SUMC       NUMBER;
  SROK_GOD   NUMBER;
  SUM_ZADOL  NUMBER;
  SROK_MES   NUMBER;
  SUM_STAVKA NUMBER := 0;
  CURS_DOG   NUMBER := 1;
  CURS_COM   NUMBER := 1;
  val_com    VARCHAR2(3);
--
  PERIOD NUMBER := 0;
  SIGNDATE DATE;
--
  kol_interv NUMBER := 0;
  interv_period NUMBER := 0;
  CURSOR cur_com IS -- комиссии на договоре
   select distinct ICDZACOMID from CDZA,cmf
   where NCDZAAGRID = pAgrId
   and ICMFID = ICDZACOMID
   and ICMFSUMFORFEE not in (2,4,5,22);
Begin
  for rec_com in cur_com loop
  begin
        select
        ICMFINTORSUM,
        nvl(cm.PCMHPVAL,PCMFPERCENT),
        nvl(cm.MCMHMVAL,MCMFSUM),
        CCMFCUR,
        decode(ICMFCALCPERIOD,1,1,2,1/3,3,1/6,4,1/12,0,365/12,0),
        ICMFCALCPERIOD  -- Sergey 08.11.2012
       into INTOR,PERCENT,SUMC,val_com,PERIOD,
       interv_period  -- Sergey 08.11.2012
       from cmf,
       (select
         ICMHCOMID,PCMHPVAL,MCMHMVAL
        from CD_CMH
        where CCMHTERM = 'COMMRATE'
        and ICMHCOMID = rec_com.ICDZACOMID
        and DCMHDATE = (select max(DCMHDATE) from CD_CMH
                        where ICMHCOMID = rec_com.ICDZACOMID
                        and CCMHTERM = 'COMMRATE'
                        and DCMHDATE <= CD.GET_LSDate)) cm
       where ICMFID = rec_com.ICDZACOMID
       and ICMFID = cm.ICMHCOMID(+);
   exception
    when others then null;
   end;
   if INTOR = 0 then
       SUM_STAVKA := SUM_STAVKA + nvl(PERCENT,0);
   elsif INTOR = 1 then
        CURS_DOG := greatest(RATES.cur_rate_new(CDTERMS2.GET_CURISO(pAgrId),CD.GET_LSDate),0);
        CURS_COM := greatest(RATES.cur_rate_new(val_com,CD.GET_LSDate),0);
    --
       select
       months_between(CDTERMS.GET_ENDDATE(NCDAAGRID,icdaISLINE,dcdaLINEEND),dcdaSIGNDATE + cdEnv.Is_Include_EndDate)/12
       into SROK_GOD
       from cda where NCDAAGRID = pAgrId;
       if nvl(SROK_GOD,0) <> 0 and nvl(SUM_ZADOL,0) <> 0 then
           if PERIOD = 0 then
              SUM_STAVKA := SUM_STAVKA + nvl(SUMC,0) * CURS_COM / nvl(SROK_GOD,0) / (nvl(SUM_ZADOL,0) * CURS_DOG) * 100;
           else
                if interv_period in (1,2,3,4) then
                 select count(*) into kol_interv from cdz
                 where NCDZAGRID = pAgrId and ICDZCOMID = rec_com.ICDZACOMID;
                 SUM_STAVKA := SUM_STAVKA + nvl(SUMC,0) * CURS_COM * nvl(kol_interv,0) / nvl(SROK_GOD,0) / (nvl(SUM_ZADOL,0) * CURS_DOG) * 100;
                else
            --
                 SUM_STAVKA := SUM_STAVKA + (PERIOD * 12) * nvl(SUMC,0) * CURS_COM / nvl(SROK_GOD,0) / (nvl(SUM_ZADOL,0) * CURS_DOG) * 100;
                end if;
           end if;
    --
       end if;
   elsif INTOR = 2 then
        select
         months_between(CDTERMS.GET_ENDDATE(NCDAAGRID,icdaISLINE,dcdaLINEEND),dcdaSIGNDATE + cdEnv.Is_Include_EndDate)
        into SROK_MES
        from cda where NCDAAGRID = pAgrId;
        if nvl(SROK_MES,0) <> 0 then
             if PERIOD = 0 then
              SUM_STAVKA := SUM_STAVKA + nvl(PERCENT,0) / (nvl(SROK_MES,0) / 12);
             else
              SUM_STAVKA := SUM_STAVKA + (nvl(PERCENT,0) * nvl(SROK_MES,0) * nvl(PERIOD,0)) / (nvl(SROK_MES,0) / 12);
             end if;
        end if;
   end if;
  end loop;
--tracepkg.txtout('Get_Proc_Stavka: SUM_STAVKA = '||SUM_STAVKA);
  RETURN SUM_STAVKA;
End Get_Proc_St;
Function Get_Proc_st_od117(pAgrId  in number, pDate in date) return number is
Begin
return CDREP_UTIL.GET_INTRATE2(pAgrId,pDate) + cdTerms2.Get_overday(pAgrId,pDate) + cdTerms2.Get_FLTRateAgrID(AgrId=>pAgrId,effdate=>pDate) +
   cdTerms2.Get_INTDRateAgrID(pAgrId,pDate) + Get_Proc_St(pAgrId);
End Get_Proc_st_od117;
--
Function Get_Proc_st_pr117(pAgrId  in number, pDate in date) return number is
prosr_proc number;
Begin
    Begin
      SELECT DISTINCT pcdhPVAL into prosr_proc FROM CDQ,CDH
      WHERE ncdqAGRID = pAgrId
    -- SergeyP 17.03.2010
    /*  AND ncdhAGRID(+) = rec_jur.agrid
      AND icdhPART(+) = icdqPART
      AND ccdhTERM(+) = 'OVDRATE'*/
      AND ncdhAGRID = pAgrId
      AND icdhPART = (select max(icdqPART) from CDQ,cdp where ncdqAGRID = ncdhAGRID and nCdqAgrId = nCdqAgrId and iCdqPart = iCdpPart and dCdpDate <= pDate )
      AND ccdhTERM = 'OVDRATE'
    --
      AND ((dcdhDATE = (SELECT MAX(C2.dcdhDATE) FROM CDH C2
                        WHERE C2.ncdhAGRID = pAgrId
                        AND C2.icdhPART = icdqPART
                        AND C2.ccdhTERM = 'OVDRATE'
                        AND C2.dcdhDATE <= pDate ))
        OR (NOT EXISTS (SELECT C2.dcdhDATE FROM CDH C2
                        WHERE C2.ncdhAGRID = pAgrId
                        AND C2.icdhPART = icdqPART
                        AND C2.ccdhTERM = 'OVDRATE'
                        AND C2.dcdhDATE <= pDate )));
    exception
     when No_Data_Found then
        Prosr_proc := null;
    End;
    return prosr_proc;
End Get_Proc_st_pr117;
-- Просрочки по выдачам по простым линиям. Остатки выдач уже  подготовлены в т. cd$r с помощью CDEVENTS2.GET_ID_CDE(agr)
Procedure prepare_prosrOD4simple_line(pAgrId number, pDate date) is
mProsrOd number;
mDelta   number;
--
cursor c1 is
select I_CD$R_N3 nAgr,I_CD$R_N4 mOst, D_CD$R_D1 dDate
from cd$r where i_Cd$r_n3 = pAgrId
and C_CD$R_C1_255 = USERENV('sessionid')
for update of I_CD$R_N5 order by D_CD$R_D1 desc;
Begin
  mProsrOd := nvl(cdbalance.get_CurSaldo(AgrId =>pAgrId,TypeAcc=>5,DFrom=>pDate),0);
  mDelta := mProsrOd;
  for rec in c1 Loop
   if mDelta > rec.mOst then
     mDelta := mDelta - rec.mOst;
     update cd$r set I_CD$R_N5 = rec.mOst where current of c1;
   elsif mDelta = rec.mOst then
     mDelta := mDelta - rec.mOst;
     update cd$r set I_CD$R_N5 = rec.mOst where current of c1;
   else
     update cd$r set I_CD$R_N5 = mDelta where current of c1;
     mDelta := 0;
   end if;
   exit when mDelta = 0;
  End Loop;
end prepare_prosrOD4simple_line;
-- -----------
Function Get_OstPremDiscont(pAgrId number, pType number, pDate date) return number is
nRet number := 0;
cursor c1 (iType number) is
select mSumm
from (
select iTyp, sum(mSumm) mSumm
from (
select case when iCdeType = 794   and iCdeSubType in ( 701,705,735 ) then iCdeSubType
            when iCdeType = 795   and iCdeSubType in ( 701,705,735 ) then iCdeSubType
            when (iCdeType,iCdeSubType) in ( (791,702), (796,704), (797,702) ) then 701
            when iCdeType in 793   then 701
            when (iCdeType,iCdeSubType) in ( (796,708), (797,706) ) then 705
            when iCdeType in (709,710)  and iCdeSubType = 711 then 701
            when iCdeType in (709,710)  and iCdeSubType = 715 then 705
            when iCdeType in (709,710)  and iCdeSubType = 745 then 735
            when iCdeType in (709,710)  and iCdeSubType = 755 then 755
       end iTyp,
       case when iCdeType = 795 and iCdeSubType in ( 701, 705, 735 ) then mPrem
            when iCdeType = 794 and iCdeSubType in ( 701, 705, 735 ) then mPrem
            when x.iCdeType = 709 and x.iCdeSubType in (711,715,745,755) then -mPrem
            when x.iCdeType = 710 and x.iCdeSubType in (711,715,745,755) then -mPrem
            when iCdeType in (791,793,797)  and iCdeSubType in (702,706,736,746,756) then -mPrem
            when iCdeType in (796)  and iCdeSubType         in (704,708,738,748,758) then -mPrem
            when x.iCdeType = 793 and x.iCdeSubType is null then -mPrem
            else 0
       end mSumm
from (
select iCdeType,iCdeSubType, cdstate.Get_Evt_Sum_Date(pAgrId,iCdeType,pDate,iCdeSubType) mPrem
 from cde where nCdeAgrId = pAgrId
 and iCdeType in (791,792,793,794,795,796,797,709,710)
 group by iCdeType, iCdeSubType
) x
UNION ALL
select case
            when iCdeType  in (709,710,794,795 )  and iCdeSubType = 711 then 711
            when iCdeType  in (709,710,794,795 )  and iCdeSubType = 715 then 715
            when iCdeType  in (794,795 )          and iCdeSubType = 725 then 715
            when iCdeType  in (709,710,794,795 )  and iCdeSubType in (745,755) then 755
            when (iCdeType,iCdeSubType)  in ((791,712),  (797,712),(796,714), (797,722),(796,724) ) then 711
            when (iCdeType,iCdeSubType)  in ( (791,716), (797,716),(796,718), (797,726),(796,728) ) then 715
            when (iCdeType,iCdeSubType)  in ( (791,746), (797,746),(797,756),(796,748),(796,758) ) then 755
            else null
       end iTyp,
       case
            when x.iCdeType = 709 and x.iCdeSubType in (711,715,745) then mPrem
            when x.iCdeType = 710 and x.iCdeSubType in (711,715,745) then mPrem
            when x.iCdeType = 794 and x.iCdeSubType in (711,715,721,725,745,755) then -mPrem
            when x.iCdeType = 795 and x.iCdeSubType in (711,715,721,725,745,755) then -mPrem
            when x.iCdeType in (791,797) and x.iCdeSubType in (712,716,746,722,726,756) then -mPrem
            when x.iCdeType = 796 and x.iCdeSubType        in (714,718,748,724,728,758) then -mPrem
            else 0
       end mSumm
from (
select iCdeType,iCdeSubType, cdstate.Get_Evt_Sum_Date(pAgrId,iCdeType,pDate,iCdeSubType) mPrem
 from cde where nCdeAgrId = pAgrId
 and ( iCdeType in (709,710) or iCdeType in (791,797) and iCdeSubType in (712,716,722,726,746,756) or iCdeType = 796 and iCdeSubType in (714,718,748,724,728,748,758 ) or iCdeType = 795 and iCdeSubType in (721, 725, 735, 755) )
 group by iCdeType, iCdeSubType
) x
) group by iTyp
) where iTyp = iType;
Begin
 open c1(pType);
 fetch c1 into nRet;
 if c1%NotFound then
  nRet := 0;
 end if;
 if c1%isOpen then
   close c1;
 end if;
 return nRet;
End Get_OstPremDiscont;
-- ----------------
-- -----------
Function Get_OstPremDiscontDetail(pAgrId number, pType number, iSType integer default 1, pDate date) return number is
nRet number := 0;
cursor c1 (iType number) is
select nvl(mSumm,0)
from (
select iTyp, iSubType, sum(mSumm) mSumm
from (
select case when iCdeType = 794   and iCdeSubType in ( 701,705,735 ) then iCdeSubType
            when iCdeType = 795   and iCdeSubType in ( 701,705,735 ) then iCdeSubType
            when (iCdeType,iCdeSubType) in ( (791,702), (796,704), (797,702) ) then 701
            when iCdeType in 793   then 701
            when (iCdeType,iCdeSubType) in ( (796,708), (797,706) ) then 705
            when iCdeType in (709,710)  and iCdeSubType = 711 then 701
            when iCdeType in (709,710)  and iCdeSubType = 715 then 705
            when iCdeType in (709,710)  and iCdeSubType = 745 then 735
            when iCdeType in (709,710)  and iCdeSubType = 755 then 755
       end iTyp,
       1 iSubType,
       case when iCdeType = 795 and iCdeSubType in ( 701, 705, 735 ) then mPrem
            when iCdeType = 794 and iCdeSubType in ( 701, 705, 735 ) then mPrem
            when x.iCdeType = 709 and x.iCdeSubType in (711,715,745,755) then -mPrem
            when x.iCdeType = 710 and x.iCdeSubType in (711,715,745,755) then -mPrem
            when iCdeType in (791,793,797)  and iCdeSubType in (702,706,736,746,756) then -mPrem
            when iCdeType in (796)  and iCdeSubType         in (704,708,738,748,758) then -mPrem
            when x.iCdeType = 793 and x.iCdeSubType is null then -mPrem
            else 0
       end mSumm
from (
select iCdeType,iCdeSubType, cdstate.Get_Evt_Sum_Date(pAgrId,iCdeType,pDate,iCdeSubType) mPrem
 from cde where nCdeAgrId = pAgrId
 and iCdeType in (791,792,793,794,795,796,797,709,710)
 group by iCdeType, iCdeSubType
) x
UNION ALL
       select case
            when iCdeType  in (709,710,794,795 )  and iCdeSubType = 711 then 711
            when iCdeType  in (709,710,794,795 )  and iCdeSubType = 715 then 715
            when iCdeType  in (794,795 )          and iCdeSubType = 725 then 715
            when iCdeType  in (709,710,794,795 )  and iCdeSubType in (745,755) then 755
            when (iCdeType,iCdeSubType)  in ((791,712),  (797,712),(796,714), (797,722),(796,724) ) then 711
            when (iCdeType,iCdeSubType)  in ( (791,716), (797,716),(796,718), (797,726),(796,728) ) then 715
            when (iCdeType,iCdeSubType)  in ( (791,746), (797,746),(797,756),(796,748),(796,758) ) then 755
            else null
       end iTyp,
       iSubType,
       case
            when x.iCdeType = 709 and x.iCdeSubType in (711,715,745) then mPrem
            when x.iCdeType = 710 and x.iCdeSubType in (711,715,745) then mPrem
            when x.iCdeType = 794 and x.iCdeSubType in (711,715,721,725,745,755) then -mPrem
            when x.iCdeType = 795 and x.iCdeSubType in (711,715,721,725,745,755) then -mPrem
            when x.iCdeType in (791,797) and x.iCdeSubType in (712,716,746,722,726,756) then -mPrem
            when x.iCdeType = 796 and x.iCdeSubType        in (714,718,748,724,728,758) then -mPrem
            else 0
       end mSumm
from (
select iCdeType,iCdeSubType, cdstate.Get_Evt_Sum_Date(pAgrId,iCdeType,pDate,iCdeSubType) mPrem,
case when iCdeSubtype in (721,722,724,725,726,728,755,756,758) then
 2
else
 1
end iSubType
 from cde where nCdeAgrId = pAgrId
 and ( iCdeType in (709,710) or iCdeType in (791,797) and iCdeSubType in (712,716,722,726,746,756) or iCdeType = 796 and iCdeSubType in (714,718,748,724,728,748,758 ) or iCdeType = 795 and iCdeSubType in (721, 725, 735, 755) )
 group by iCdeType, iCdeSubType
) x
) group by iTyp,iSubType
) where iTyp = iType and iSubType = iSType;
Begin
 open c1(pType);
 fetch c1 into nRet;
 if c1%NotFound then
  nRet := 0;
 end if;
 if c1%isOpen then
   close c1;
 end if;
 return nRet;
End Get_OstPremDiscontDetail;
-- ----------------
Function Get_TypeDiscont(pAgrId number, dDate date default cd.get_lsdate) return integer is
iRet integer := 0;
Begin
 Begin
    select iCdhiVal into iRet
    from cdh
    where
    nCdhAgrId = pAgrId and
    cCdhTerm = 'DISCRATE'
    and dCdhDate = ( select max(dCdhDate) from cdh where dCdhDate<= dDate and nCdhAgrId = pAgrId and cCdhTerm = 'DISCRATE');
 Exception when No_Data_Found then
    iRet := 0;
 End;
 return iRet;
End Get_TypeDiscont;
-- --------------------------------------------------------------
Function Get_PremStavka(pAgrId number, dDate date default cd.get_lsdate) return number is
iDiscType integer;
mDiscrate number;
mRet number;
Begin
 Begin
    select pCdhPVal,iCdhiVal into mDiscrate, iDiscType
    from cdh
    where
    nCdhAgrId = pAgrId and
    cCdhTerm = 'DISCRATE'
    and dCdhDate = ( select max(dCdhDate) from cdh where dCdhDate<= dDate and nCdhAgrId = pAgrId and cCdhTerm = 'DISCRATE');
    if iDiscType = 2 then
       mRet := mDiscrate;
    else
       mRet := 0;
    end if;
 Exception when No_Data_Found then
    mRet := 0;
 End;
 return mRet;
End Get_PremStavka;
Function Get_DiscontStavka(pAgrId number, dDate date default cd.get_lsdate) return number is
iDiscType integer;
mDiscrate number;
mRet number;
Begin
 Begin
    select pCdhPVal,iCdhiVal into mDiscrate, iDiscType
    from cdh
    where
    nCdhAgrId = pAgrId and
    cCdhTerm = 'DISCRATE'
    and dCdhDate = ( select max(dCdhDate) from cdh where dCdhDate<= dDate and nCdhAgrId = pAgrId and cCdhTerm = 'DISCRATE');
    if iDiscType = 1 then
       mRet := mDiscrate;
    else
       mRet := 0;
    end if;
 Exception when No_Data_Found then
    mRet := 0;
 End;
 return mRet;
End Get_DiscontStavka;
Function Get_CloseLimDate(pAgrId cda.nCdaAgrId%Type) return date is
dRet date := null;
Begin
 Begin
     select max(dCdhDate) into dRet
     from cdh
     where nCdhAgrId = pAgrId
     and cCdhTerm = 'LIMIT'
     and mCdhmVal = 0;
 Exception
   when No_Data_Found then
      dRet := null;
 End;
 if dRet is null then
   dRet := cdterms.Get_CurEndDate(pAgrId);
 end if;
 return dRet;
End Get_CloseLimDate;
-- Возвращает строку с перечислением подтипов обеспечения данного типа обеспечения
-- или всех типов ( -1 - всех типов,1 - залог,0 - поручительство ) у к-ых учетная сумма обеспечения
-- > 0 на дату расчета. Возвращает в виде тип1/подтип1 (Залогодатель или поручитель), тип2/подтип2 (...
Function get_zo_types2 ( nAgrId NUMBER, dRepDate DATE DEFAULT CD.get_lsdate,nTypZO NUMBER DEFAULT -1) Return VARCHAR2 IS
cRet VARCHAR2(2048) := '';
Cursor c_zo IS
SELECT
    czv.cCzvName     ,                                      /*наименование типа обеспечения,*/
    czw.cCzwName     ,                                         /*наименование подтипа обеспечения,*/
    (select nvl(cCusName_Sh,cCusName) from cus where
        iCusNum = decode(nCzoZlg,null,(SELECT   icpozcusnum
                       FROM   CPOZ
                      WHERE   icpo = nczoporuch),
        nCzoZlg)) cName,
    decode(nCzoParent,null,'',' (вторичное обеспечение)')  cStatus
FROM czo, czv, czw, czh
WHERE
    czo.nCZOagrid= nAgrId
    AND czo.nCzoczv = czv.iczv
    AND ( NVL(nTypZO,-1) = -1 OR ( NVL(nTypZO,-1) > -1 AND  czv.NCZVFLAGZAL_GAR = nTypZO ) )
    AND czh.nCzhCzo = czo.iCzo
    AND czo.NCZOCZW=czw.ICZW
    AND czw.nCZWCZV = czv.iczv
    AND czh.dCzhDate = (SELECT MAX(dCzhDate) FROM czh czh2 WHERE czh2.dCzhDate <= dRepDate AND czh2.nCzhCzo = czo.iCzo  )
    AND czh.nCzhSumma > 0
    ;
rrow c_zo%Rowtype ;
Begin
   FOR rrow IN c_zo Loop
     cRet := cRet||rrow.cCzvName||'/'||rrow.cCzwName||'('||rrow.cName||')'||rrow.cStatus||', ';
   End Loop ;
   If LENGTH(cRet) > 2 THEN
      cRet := SUBSTR( cRet,1,INSTR(cRet,', ',-1)-1 );
   End If ;
   Return cRet ;
End get_zo_types2;
-- --------------------
-- Возвращает список комиссий по договору
Function get_comis(nAgrId cda.nCdaAgrId%Type, dDate date default cd.get_lsdate) return varchar2 is
cRet varchar2(2056);
cursor c1 is
select distinct
 NCDZAGRID,
 ICMFID,
 CCMFNAME,
 ICMFCALCPERIOD v04,
 RATES.Cur_Rate_New(nvl(CCMFCUR,CDTERMS2.Get_CurISO(NCDZAGRID)),dDate) v05,
 decode(ICMFCALCPERIOD,
        7,'на дату подписания',
        8,'в срок окончания',
        0,'ежедневно',
        1,'ежемесячно',
        2,'ежеквартально',
        3,'каждые полгода',
        4,'ежегодно',
        5,'на системную дату',
        9,'произвольно',
        null) period,
 decode(PCMFPERCENT,NULL,NULL,To_Char(PCMFPERCENT,'FM999g999g999g999g999g0D0999')) rate,
 (select sum(MCDKTOTAL)
  from v_cdk where NCDKAGRID = NCDZAGRID
--  and :m1 between DCDKFROM and DCDKTO
  and to_char(dDate,'mm.rrrr') = to_char(DCDKTO,'mm.rrrr')
  and CCDKRT = 'R'
  and ICDKCOMID = ICMFID) mSum
from cdz,cmf
where NCDZAGRID = nAgrId
AND ICMFID = ICDZCOMID;
Begin
 for rec in C1 Loop
  cRet := cRet||rec.cCmfName||', '||rec.period||', ';
  if rec.rate is not null then
    cRet := cRet||rec.rate||'%, ';
  end if;
  cRet := cRet||To_Char(rec.mSum,'FM9999999999999990D00')||'; ';
 End Loop;
 return substr(cRet,1,length(cRet)-2);
End get_comis;
-- -----------------
Function Get_PurposeType(nAim cda.iCdapurpose%Type) return varchar2 is
cRet varchar2(256);
Begin
select decode(nCaugNum,5,'жилищная ссуда',
                       6,'ипотека',
                       9,'иные потребительские',
                       11,'автокредиты',
                       '') into cRet
from cau where iCauId = nAim;

return cRet;
Exception
  when No_Data_Found then
    return '';
End Get_PurposeType;
--
Function Get_FullRate(pAgrId cda.nCdaAgrId%Type, pDate date default cd.GET_LSDATE ) return number is
nRet number;
Begin
  Begin
    select cdh.pCdhpVal into nRet
    from cdh where cdh.nCdhAgrId = pAgrId and cCdhterm = 'FULLRATE'
    and dCdhDate = (select max(h.dCdhDate) from cdh h where h.nCdhAgrId = cdh.nCdhAgrId and  h.cCdhterm = 'FULLRATE' and h.dCdhDate <= pDate );
  Exception
    when No_Data_Found then
     nRet := null;
  End;
return nRet;
End Get_FullRate;
-- -------
-- Расчет формы 808

PROCEDURE Recalc_F808(p_Date IN DATE,
                      p_int IN NUMBER DEFAULT 0) IS
 CURSOR cur_CDA IS -- исполняемые договоры на дату
 select agr,cur,cli,dnper,
  dkper,   -- SergeyP 01.02.2011
  greatest(RATES.cur_rate_new(cur,dnper),0) n_kurs, -- курс на начало периода
  CDRESERVE.GET_AGRRISKRATE(agr,cli,null,CDTERMS2.IsPrtf(agr),dnper) st_rez_n, -- ставка резервирования на начало периода
  CDRESERVE2.CLC_ARR(agr,dnper) coef_rez_pn, -- коэффициент резервирования для % на начало периода
  greatest(RATES.cur_rate_new(cur,dkper),0) k_kurs, -- курс на конец периода
  CDRESERVE.GET_AGRRISKRATE(agr,cli,null,CDTERMS2.IsPrtf(agr),dkper) st_rez_k, -- ставка резервирования на конец периода
  CDRESERVE2.CLC_ARR(agr,dkper) coef_rez_pk -- коэффициент резервирования для % на конец периода
--
 from
 (
  select agr,cur,cli,
   case
    when dnagr between dnper and CD.Get_LSDate then dnagr
    else dnper
   end dnper, -- скорректированное начало периода
   case
    when dkagr between dnper and CD.Get_LSDate then dkagr
    else CD.Get_LSDate
   end dkper -- скорректированный конец периода
  from
  (
   select
    ncdvAGRID agr, -- номер договора
    cCDvcuriso cur, -- валюта
    ICDvCLIENT cli, -- клиент
    dcdvsigndate dnagr, -- начало договора
    dcdvenddate dkagr, -- конец договора
    decode(p_int,0,add_months(CD.GET_LSDate,-3)+1,add_months(CD.GET_LSDate,-12)+1) dnper -- общее начало периода
   from cdv
   WHERE (iCDVstatus = 2 OR (iCDVstatus = 3 AND (select dCDAclosed from cda where ncdaAGRID = ncdvAGRID) > CD.Get_LSDate))
   AND dCDVsigndate <= CD.Get_LSDate
  )
--
 )
;
 d_LSDate DATE := CD.Get_LSDate;
 delta_zadol NUMBER;
 delta_zadol_p NUMBER;
 tmp_zadol NUMBER;
 tmp_zadol_p NUMBER;
-- SergeyP 01.02.2011
 tmp_zadoln NUMBER;
 tmp_zadol_pn NUMBER;
--
 tmp_cess_pn number;
 tmp_cess_pk number;
 delta_st_rez NUMBER;
 delta_st_rez_p NUMBER;
 delta_kurs NUMBER;
 delta_kurs_p NUMBER;
 n_typ NUMBER;
 n_rez_typ NUMBER;
 out_1 NUMBER;
 out_2 NUMBER;
 out_3 NUMBER;
-- SergeyP 05.03.2011
 delta_zadol_m NUMBER;
 delta_st_rez_m NUMBER;
 delta_kurs_m NUMBER;
--
BEGIN
-- установить кредитную системную дату
 CD.Set_LSDate(last_day(add_months(p_Date,-1))); -- на последнее число предыдущего месяца
----------- Расчет изменения резерва отдельно по ОД и %% ----------
 FOR rec IN cur_CDA LOOP
-- SergeyP 01.02.2011
-- задолженность на начало периода
  tmp_zadoln :=
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,1,null,null,rec.dnper),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,5,null,null,rec.dnper),0);
  tmp_zadol_pn :=
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,6,null,null,rec.dnper),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,10,null,null,rec.dnper),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,101,null,null,rec.dnper),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,106,null,null,rec.dnper),0);
--tracepkg.txtout('задолженность на начало периода: tmp_zadoln = '||tmp_zadoln||' tmp_zadol_pn = '||tmp_zadol_pn);
-- задолженность на конец периода
  tmp_zadol :=
-- SergeyP 01.02.2011
/*  NVL(CDBALANCE.GET_CURSALDO(rec.agr,1),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,5),0);*/
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,1,null,null,rec.dkper),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,5,null,null,rec.dkper),0);
--
  tmp_cess_pn :=
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,701,null,null,rec.dnper),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,711,null,null,rec.dnper),0);
  tmp_cess_pk :=
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,701,null,null,rec.dkper),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,711,null,null,rec.dkper),0);
  tmp_zadol_p :=
-- SergeyP 01.02.2011
/*  NVL(CDBALANCE.GET_CURSALDO(rec.agr,6),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,10),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,101),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,106),0);*/
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,6,null,null,rec.dkper),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,10,null,null,rec.dkper),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,101,null,null,rec.dkper),0) +
  NVL(CDBALANCE.GET_CURSALDO(rec.agr,106,null,null,rec.dkper),0);
--
--tracepkg.txtout('задолженность на конец периода: tmp_zadol = '||tmp_zadol||' tmp_zadol_p = '||tmp_zadol_p);
-- изменение резерва от изменения задолженности
  tmp_zadol := tmp_zadol + tmp_cess_pk;
  tmp_zadoln := tmp_zadol + tmp_cess_pn;

  delta_zadol :=
  (tmp_zadol -
-- SergeyP 01.02.2011
   tmp_zadoln )
--   (NVL(CDBALANCE.GET_CURSALDO(rec.agr,1,null,null,rec.dnper),0) +
--    NVL(CDBALANCE.GET_CURSALDO(rec.agr,5,null,null,rec.dnper),0)))
--   * rec.n_kurs * rec.st_rez_n / 100;
   * rec.k_kurs * rec.st_rez_k / 100;
--
  delta_zadol_p :=
  (tmp_zadol_p -
-- SergeyP 01.02.2011
   tmp_zadol_pn)
/*   (NVL(CDBALANCE.GET_CURSALDO(rec.agr,6,null,null,rec.dnper),0) +
    NVL(CDBALANCE.GET_CURSALDO(rec.agr,10,null,null,rec.dnper),0) +
    NVL(CDBALANCE.GET_CURSALDO(rec.agr,101,null,null,rec.dnper),0) +
    NVL(CDBALANCE.GET_CURSALDO(rec.agr,106,null,null,rec.dnper),0)))*/
--   * rec.n_kurs * rec.coef_rez_pn;
   * rec.k_kurs * rec.coef_rez_pk;
--
--tracepkg.txtout('изменение задолженности: delta_zadol = '||delta_zadol||' delta_zadol_p = '||delta_zadol_p);
-- изменение резерва от изменения ставки резервирования
  delta_st_rez :=
  (rec.st_rez_k - rec.st_rez_n) / 100 * rec.k_kurs *
-- SergeyP 01.02.2011
--  tmp_zadol;
  tmp_zadoln;
--
  delta_st_rez_p :=
  (rec.coef_rez_pk - rec.coef_rez_pn) * rec.k_kurs *
-- SergeyP 01.02.2011
--  tmp_zadol_p;
  tmp_zadol_pn;
--
--tracepkg.txtout('изменение ставки резервирования: delta_st_rez = '||delta_st_rez||' delta_st_rez_p = '||delta_st_rez_p);
-- изменение резерва от изменения курсов валют
  delta_kurs :=
  (rec.k_kurs - rec.n_kurs) * rec.st_rez_n *
-- SergeyP 01.02.2011
--  tmp_zadol;
  tmp_zadoln;
--
  delta_kurs_p :=
  (rec.k_kurs - rec.n_kurs) * rec.coef_rez_pn *
-- SergeyP 01.02.2011
--  tmp_zadol_p;
  tmp_zadol_pn;
--
--tracepkg.txtout('изменение курсов валют: delta_kurs = '||delta_kurs||' delta_kurs_p = '||delta_kurs_p);
-- SergeyP 05.03.2011
-- расчет изменения резерва ОД по алгоритму формы CDRESERF
select
 sum(CDSQLA.getIsPlus(dr_Loan)) vyd,
 sum(-CDSQLA.getIsPlus(-dr_Loan)) pog,
 sum(CDSQLA.getIsPlus(DR_PC)) st_p,
 sum(-CDSQLA.getIsPlus(-DR_PC)) st_m,
 sum(CDSQLA.getIsPlus(DR_RATE)) kurs_p,
 sum(-CDSQLA.getIsPlus(-DR_RATE)) kurs_m
into delta_zadol,delta_zadol_m,
     delta_st_rez,delta_st_rez_m,
     delta_kurs,delta_kurs_m
from v_cdrezf
where NCDAAGRID = rec.agr
and dcdedate between rec.dnper and rec.dkper
;
--
---- выдача данных по каждому договору в 4 строки: доначисление (ОД и %%), уменьшение (ОД и %%) -----
  FOR i IN 1..4 LOOP
   out_1 := 0;
   out_2 := 0;
   out_3 := 0;
   if i = 1 then
    n_typ := 1;
    n_rez_typ := 0;
    if delta_zadol > 0 then out_1 := delta_zadol; end if;
    if delta_st_rez > 0 then out_2 := delta_st_rez; end if;
    if delta_kurs > 0 then out_3 := delta_kurs; end if;
   elsif i = 2 then
    n_typ := 1;
    n_rez_typ := 1;
    if delta_zadol_p > 0 then out_1 := delta_zadol_p; end if;
    if delta_st_rez_p > 0 then out_2 := delta_st_rez_p; end if;
    if delta_kurs_p > 0 then out_3 := delta_kurs_p; end if;
   elsif i = 3 then
    n_typ := 2;
    n_rez_typ := 0;
-- SergeyP 05.03.2011
/*    if delta_zadol < 0 then out_1 := abs(delta_zadol); end if;
    if delta_st_rez < 0 then out_2 := abs(delta_st_rez); end if;
    if delta_kurs < 0 then out_3 := abs(delta_kurs); end if;*/
    if delta_zadol_m < 0 then out_1 := abs(delta_zadol_m); end if;
    if delta_st_rez_m < 0 then out_2 := abs(delta_st_rez_m); end if;
    if delta_kurs_m < 0 then out_3 := abs(delta_kurs_m); end if;
--
   elsif i = 4 then
    n_typ := 2;
    n_rez_typ := 1;
    if delta_zadol_p < 0 then out_1 := abs(delta_zadol_p); end if;
    if delta_st_rez_p < 0 then out_2 := abs(delta_st_rez_p); end if;
    if delta_kurs_p < 0 then out_3 := abs(delta_kurs_p); end if;
   end if;
--tracepkg.txtout('выходные данные: n_typ = '||n_typ||' n_rez_typ = '||n_rez_typ||' out_1 = '||out_1||' out_2 = '||out_2||' out_3 = '||out_3);
   if out_1 > 0 or out_2 > 0 or out_3 > 0 then  -- SergeyP 23.10.2010
    INSERT INTO
    F808_SPR_ANL(IF808AGRID,IF808TYPE,IF808REZTYPE,IF808ROW1,IF808ROW2,IF808ROW3)
    VALUES(rec.agr,n_typ,n_rez_typ,out_1,out_2,out_3);
   end if;  -- SergeyP 23.10.2010
  END LOOP;
 END LOOP;
-- восстановить кредитную системную дату
 CD.Set_LSDate(d_LSDate);
exception
 when others then
 --tracepkg.txtout(SQLERRM);
 RAISE;
END Recalc_F808;
--------------------------------------------------------------------------------------------------------------------------------
Procedure Recalc_F808_spr_total(vfil number, p_dBegin IN date, p_dEnd IN date) is
mNachislenie number;
mSpisanie    number;
nRet         number;
Begin
select nvl(sum(Nach),0),nvl(sum(Spis),0) into mNachislenie,mSpisanie
from (
select sum(mNach) Nach,sum(mSpis) Spis
from (
select  case when iCdeType in (51,53,151,153,155.157,251,253) then mTrnSum
else
 0
end mNach,
case when iCdeType in (51,53,151,153,155.157,251,253) then 0
else
 mTrnSum
end mSpis
from
cde,
trn,
cda
where
dCdaSignDate <= p_dEnd
and icdetype in (51,52,53,54,151,152,153,154,155,156,157,158,251,252,253,254)
and nCdeAgrId = cda.nCdaAgrId and iCdeTrnNum = iTrnNum and iCdeTrnANum = iTrnANum
and (iCDastatus = 2 OR (iCDastatus = 3 AND dcdaClosed > p_dEnd ) )
and dCdeDate between p_dBegin and p_dEnd
)
Union ALL
select sum(Nach),sum(Spis)
FROM
(
SELECT mTrnSum Nach, 0 Spis
FROM trn WHERE dTrnTran >= p_dBegin AND dTrnTran < p_dEnd AND
 (
      ( cTrnAccD LIKE '70606810%'
      and exists (select '' from cdpt_acc where cTrnAccC = ccdptaccacc  and cTrnCurC = nvl(cCdptAccCur,'RUR') )  ) -- OR  -- под осн.долг
--      (cTrnAccD LIKE '70606810%' AND cTrnAccC IN    (SELECT cCdPtRISKPACC FROM cdpt) AND cTrnCur='RUR')  OR -- просроч.осн.долг
--      (cTrnAccD LIKE '70606810%' AND cTrnAccC IN  (SELECT cCdPTRiskPrcACC FROM cdpt) AND cTrnCur='RUR') OR --под %%
--        (cTrnAccD LIKE '70606810%' AND cTrnAccC IN (SELECT cCdPTRISKPRC2ACC FROM cdpt) AND cTrnCur='RUR')  --под просроч.%%
)
UNION ALL
SELECT 0 Nach, mTrnSum Spis
FROM trn WHERE dTrnTran >= p_dBegin AND dTrnTran < p_dEnd AND
 (
      ( cTrnAccC LIKE '70601810%' -- OR  -- под осн.долг
      and exists (select '' from cdpt_acc where cTrnAccD = ccdptaccacc  and cTrnCur = nvl(cCdptAccCur,'RUR')  )  )
--      (cTrnAccD  IN    (SELECT  cCdPtRISKPACC FROM cdpt) AND cTrnCur='RUR' AND cTrnAccC LIKE '70601810%') OR -- просроч.осн.долг
--      (cTrnAccD  IN  (SELECT cCdPTRiskPrcACC FROM  cdpt) AND cTrnCur='RUR' AND cTrnAccC LIKE '70601810%') OR --под %%
--        (cTrnAccD  IN (SELECT cCdPTRISKPRC2ACC FROM cdpt) AND cTrnCur='RUR'AND cTrnAccC LIKE '70601810%')  --под просроч.%%
)
) v
);
nRet := RG_EF_RG_1.Save_Store_Val('F808_NACH',p_dEnd, vfil,mNachislenie,null,null,null);
nRet := RG_EF_RG_1.Save_Store_Val('F808_SPIS',p_dEnd, vfil,mSpisanie,null,null,null);
End Recalc_F808_spr_total;


FUNCTION Fill_808_Spr ( p_fil   IN NUMBER,
                        p_dcalc IN DATE,
                        p_mode  IN NUMBER )
RETURN NUMBER IS
  vCurIDsmr VARCHAR2(3) := SYS_CONTEXT ('B21','IDSmr');
  CURSOR c1 IS
    SELECT ismrfil, idsmr, 'TRUE'
      FROM FIL_ON2
      WHERE ismrfil=decode(p_fil,-1,ismrfil,p_fil)
      ORDER BY ismrfil;
  fil_list RG_FIL.T_TBL_FIL_INF;
BEGIN
  DELETE FROM F808_SPR_ANL;
  OPEN c1;
  FETCH c1 BULK COLLECT INTO fil_list;
  CLOSE c1;
  --FOR v1 IN c1 LOOP
  FOR ii IN 1..NVL(fil_list.count,0) LOOP
    IF fil_list(ii).idsmr<>SYS_CONTEXT ('B21','IDSmr') THEN
      begin
        XXI_CONTEXT.set_idsmr(fil_list(ii).idsmr);
      exception
        when others then null;
      end;
    END IF;
    vbg_cdrep.Recalc_F808(p_Date => p_dcalc, p_int => p_mode);
  END LOOP;
  IF vCurIDsmr<>SYS_CONTEXT ('B21','IDSmr') THEN
    begin
      XXI_CONTEXT.set_idsmr(vCurIDsmr);
    exception
      when others then null;
    end;
  END IF;
  RETURN 0;
EXCEPTION
  WHEN OTHERS THEN
    begin
      XXI_CONTEXT.set_idsmr(vCurIDsmr);
    exception
      when others then null;
    end;
    DELETE FROM F808_SPR_ANL;
    RETURN -1;
END Fill_808_Spr;
-------------------------------------------------------------------------------
-- Скопировано из cdrep_util2. Подправлено определение просрочки по купленным правам требования по процентам в случае цессии с премией.
-- Получить число дней действующей просроч.долга по %
FUNCTION Get_DPrsr_PC_Active(AgrID NUMBER, evDATE DATE DEFAULT CD.get_lsdate, FlagDateAct NUMBER DEFAULT 0) RETURN NUMBER IS
  RET NUMBER := 0;
  DMIN DATE;
  DI DATE;
  SRET NUMBER;
  CURSOR Get_CDA IS SELECT * FROM CDA WHERE ncdaAGRID=AgrID;
  CDA_Terms Get_CDA%ROWTYPE;
BEGIN
  --CDINTEREST.Recalc_Interest(AgrID, 'R', TRUE, FALSE);
  OPEN Get_CDA; FETCH Get_CDA INTO CDA_Terms; CLOSE Get_CDA;

  SRET := cdrep_util2.Calc_State(AgrID, 1, 0,'I');

  SELECT MIN(dcdipmtdue) INTO DI
  FROM V_CDI
  WHERE V_CDI.ncdiagrid = AgrID
    AND (mcditotal - mcdipayed) > 0
    AND dcdipmtdue <= evDATE;
dbms_output.put_line('DI = '||DI);
  DMIN := DI;

  IF CDA_Terms.icdaces = 1 THEN
    IF cdstate.get_evt_sum_date(AgrID, 725, evDATE, null)-cdstate.get_evt_sum_date(AgrID, 726, evDATE, null)>0 THEN
      --DMIN := CDA_Terms.Dcdasigndate; До (161537)
      BEGIN -- (161537)
      SELECT MIN(DCDOCESSTART) DSTART INTO DMIN
            FROM cd_cdo_ces OCS
            WHERE OCS.NCDOCESAGRID = AgrID
              AND OCS.CCDOCESTYPE = 'I'
              AND OCS.DCDOCESDATE = (SELECT MAX(DCDOCESDATE) FROM cd_cdo_ces WHERE NCDOCESAGRID = AgrID
              AND CCDOCESTYPE = 'I');
       DMIN := nvl(DMIN,CDA_Terms.Dcdasigndate);    -- (161537)
      EXCEPTION WHEN OTHERS THEN
       DMIN := CDA_Terms.Dcdasigndate;
      END;
--  в оригинале было    ELSIF cdstate.get_evt_sum_date(AgrID, 715, evDATE, null)-cdstate.get_evt_sum_date(AgrID, 716, evDATE, null)>0 THEN
-- вместо ELSIF ставим ELSE
    ELSE
      if vbg_cdrep.Get_TypeDiscont(AgrId,evDate) = 2 then
         if cdstate.get_evt_sum_date(AgrID, 715, evDATE, null)-cdstate.get_evt_sum_date(AgrID, 718, evDATE, null)>0 then
             SELECT MIN(dcdedate) INTO DMIN FROM cde WHERE ncdeAGRID=AgrID AND icdeTYPE=715;
         End if;
      else
         if cdstate.get_evt_sum_date(AgrID, 715, evDATE, null)-cdstate.get_evt_sum_date(AgrID, 716, evDATE, null)>0 THEN
             SELECT MIN(dcdedate) INTO DMIN FROM cde WHERE ncdeAGRID=AgrID AND icdeTYPE=715;
         end if;
      end if;
    END IF;
  END IF;

  RET := RET + evDATE - COALESCE(DMIN - FlagDateAct,evDATE);
  RETURN RET;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN 0;
  WHEN OTHERS THEN
dbms_output.put_line('ERROR IN  vbg_cdrep.Get_DPrsr_PC_Active:'||SQLERRM);
RETURN null;
END Get_DPrsr_PC_Active;
------------------------------
Function is_dog_prorsrochn(pAgrId IN number) return number is
nret Number := 0;
nDummy number;
cursor c1 is
select sum(MCDOOVERDUE) mProsrochka
from (
    Select
       /*+ INDEX(O2 U_CDO_A#_P#_TYPE_START_DATE) */
       O.NCDOAGRID,O.ICDOPART,O.DCDOSTART,O.CCDOTYPE
      ,MAX(O.dcdoDATE) as dcdodate
      ,MAX(O.MCDOOVERDUE) KEEP (DENSE_RANK LAST ORDER BY DCDODATE) as MCDOOVERDUE
      ,O.CCDOSESSIONID
      ,MAX(O.icdoCMFID) KEEP (DENSE_RANK LAST ORDER BY DCDODATE) as icdoCMFID
      ,MAX(O.CCDOCUR) KEEP (DENSE_RANK LAST ORDER BY DCDODATE) as CCDOCUR
    FROM ( select * from V_CDO where v_cdo.dCdoDate <= cd.get_lsdate+1) O
    WHERE
    dCdoStart <= cd.get_lsdate and
    nCdoAgrId = pAgrId 
    GROUP BY O.CCDOSESSIONID,O.NCDOAGRID,O.ICDOPART,O.CCDOTYPE,O.DCDOSTART,NVL(O.icdoCMFID,0)
    HAVING (MAX(O.MCDOOVERDUE) KEEP (DENSE_RANK LAST ORDER BY O.DCDODATE) ) > 0
    ORDER BY o.dcdoSTART
);
Begin
  ndummy := cdfine.Recalc_Fine_Rep(pAgrId, 'AI', 1, 0 );
  nDummy := 0;
  open c1;
  fetch c1 into nret;
  if c1%NotFound then 
     nRet := 0;
  end if;
  if c1%isOpen then
      close c1;
  end if;  
  Begin
      select sum(mCdfUnPayed) into nDummy 
      from v_cdf
      where
      nCdfAgrId = pAgrId;
  Exception
    when No_Data_Found then
      nDummy := 0;    
  End;
  return nRet+nDummy;       
End is_dog_prorsrochn;
-- Получение  характеристик залога-автомашины, родит. атрибут 100031
Function czo_car_ext_attr (
    pExtendId      in Attribute_Extend.id%type                          , -- Id внешнего ключа
    pDate          in Attribute_Value_History.value_date%type default cd.get_lsdate, -- Дата значения
    PNum           in Attribute_Value.Num%type                default 1,  -- Номер по порядку обеспечения
    pSeparator     in VarChar2                                default '', -- Разделитель для дочек
    pVisualization in Number                                  default 1, -- Тип визуализации
    pLocationId    in Attribute_location.location_id%Type     default 4  -- где располается атрибут ( по умолчанию - кредиты/обеспечение )
) return varchar2 is
cRet varchar2(4000);
cValue Attribute_Value_History.value%Type := null;
vParent Attribute_Value.id%Type := 0;
cursor c_atr_list( vParent number) is
select a.id,a.name,v.id value_id
from attribute_list  a,
     attribute_value v
where a.id = v.attribute_id
and v.parent_Id = vParent
and v.location_id = pLocationId
and v.extend_id = pExtendId
-- and a.id in ( 100032 /* Марка, модель */,  100035 /*  VIN */, 100036 /* Модель, № двигателя */, 100037 /* № кузова */,
-- 100034 /* год изготовления */, 100038 /* цвет кузова */, 10004 /*  серия и № ПТС */, 100105 /*  регистрационный знак */ );
;
Begin
 Begin
  select id into vParent from Attribute_Value where location_id = pLocationId and extend_id = pExtendId and attribute_id = 100031 and parent_id is null and num = pNum;
 Exception
  when No_Data_Found then
    return null;
 End;
  for rec in c_atr_list(vParent) Loop
     cValue := attribute_pkg.get_value(rec.value_id,pDate,pVisualization);
     if cValue is not null then
        if cRet is not null then
           cRet := rtrim(cRet) || pSeparator;
        end if;
        cRet := cRet||case when pVisualization=0 then '' else rec.name||':' end||cValue||'   ';
     end if;
  end Loop;
return cRet ;
End czo_car_ext_attr; 
End vbg_cdrep;
/
