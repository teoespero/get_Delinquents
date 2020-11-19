-------------1
-- this part locates accounts that have updated payments
SELECT 
	DISTINCT 
	replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar) as AccountNum,
	BILL.tran_date,
	bill.tran_type
	INTO #PAYMENTS01
FROM ub_bill_detail BILL
INNER JOIN
	ub_master MAST
	ON BILL.cust_no=MAST.cust_no
	AND BILL.cust_sequence=MAST.cust_sequence
	AND MAST.acct_status='ACTIVE'
	AND BILL.tran_type='PAYMENT'
	--AND abs(DATEDIFF(day,'11-18-2020', BILL.tran_date)) < 30
	AND BILL.tran_date between '10/01/2020' and '11/30/2020'
INNER JOIN
	Lot 
	ON MAST.lot_no=LOT.lot_no
--where
--	replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar)='000990-000'
order by
	replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar) asc,
	bill.tran_date asc





-------------2
-- locate accounts that have no updated payments
select 
	distinct
	replicate('0', 6 - len(BILL.cust_no)) + cast (BILL.cust_no as varchar)+ '-'+replicate('0', 3 - len(BILL.cust_sequence)) + cast (BILL.cust_sequence as varchar) as accountnum,
	bill.amount,
	bill.tran_date,
	bill.tran_type,
	bill.bill_type
	into #PAYMENTS02
from ub_bill_detail bill
inner join
	ub_master mast
	on replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar)=replicate('0', 6 - len(BILL.cust_no)) + cast (BILL.cust_no as varchar)+ '-'+replicate('0', 3 - len(BILL.cust_sequence)) + cast (BILL.cust_sequence as varchar)
	and mast.acct_status='active'
	and replicate('0', 6 - len(BILL.cust_no)) + cast (BILL.cust_no as varchar)+ '-'+replicate('0', 3 - len(BILL.cust_sequence)) + cast (BILL.cust_sequence as varchar) not in (select accountnum from #PAYMENTS01)
	and bill.tran_date >= '10/1/2020'





-------------3
-- get the latest balances
select 
	distinct
	t.AccountNum,
	CONVERT(varchar(10),t.tran_date,101) as last_balance_date,
	sum(t.amount) as Amount
	into #PAYMENTS03
from #PAYMENTS02 t
inner join (
    select AccountNum, max(tran_date) as MaxDate
    from #PAYMENTS02
    group by AccountNum
) tm on t.AccountNum= tm.AccountNum and  t.tran_date= tm.MaxDate
where
	t.tran_type = 'balance'
group by
	t.AccountNum,
	CONVERT(varchar(10),t.tran_date,101),
	abs(DATEDIFF(day,'11-18-2020', t.tran_date))
having
	sum(t.amount) > 0
order by
	t.AccountNum

select 
	accountnum,
	Amount,
	last_balance_date
	into #PAYMENTS04
from #PAYMENTS03 

-- get the latest billing
select 
	distinct
	replicate('0', 6 - len(BILL.cust_no)) + cast (BILL.cust_no as varchar)+ '-'+replicate('0', 3 - len(BILL.cust_sequence)) + cast (BILL.cust_sequence as varchar) as accountnum,
	bill.tran_date,
	bill.amount
	into #PAYMENTS05
from ub_bill_detail bill
where
	replicate('0', 6 - len(BILL.cust_no)) + cast (BILL.cust_no as varchar)+ '-'+replicate('0', 3 - len(BILL.cust_sequence)) + cast (BILL.cust_sequence as varchar)  in (select accountnum from #PAYMENTS04)
	and bill.tran_type in ('BILLING')
	and bill.tran_date >= '10/1/2020'
order by 
	replicate('0', 6 - len(BILL.cust_no)) + cast (BILL.cust_no as varchar)+ '-'+replicate('0', 3 - len(BILL.cust_sequence)) + cast (BILL.cust_sequence as varchar) 


select 
	distinct
	t.AccountNum,
	CONVERT(varchar(10),t.tran_date,101) as last_BILL,
	SUM(T.amount) AS AMOUNT
	into #PAYMENTS06
from #PAYMENTS05 t
inner join (
    select AccountNum, max(tran_date) as MaxDate
    from #PAYMENTS05
    group by AccountNum
) tm on t.AccountNum= tm.AccountNum and  t.tran_date= tm.MaxDate
GROUP BY
	t.AccountNum,
	CONVERT(varchar(10),t.tran_date,101)
order by
	t.AccountNum



-- subtract current billing  from curr balance
select 
	balanse.accountnum,
	balanse.Amount-nextBill.AMOUNT as delinq_amount
	into #PAYMENTS07
from #PAYMENTS04 balanse
inner join
	#PAYMENTS06 nextBill
	on balanse.accountnum=nextBill.accountnum
	and balanse.Amount-nextBill.AMOUNT > 0

-- get delinqs
SELECT 
	distinct
	LOT.misc_2 AS category,
	left(lot.zip,5) as Zip_Code,
	BALANCES.delinq_amount,
	BALANCES.accountnum,
	mast.billing_cycle
FROM #PAYMENTS07 BALANCES
INNER JOIN
	ub_master MAST
	ON replicate('0', 6 - len(mast.cust_no)) + cast (mast.cust_no as varchar)+ '-'+replicate('0', 3 - len(mast.cust_sequence)) + cast (mast.cust_sequence as varchar)=BALANCES.accountnum
INNER JOIN
	lot
	ON MAST.lot_no=LOT.lot_no
order by
	left(lot.zip,5),
	lot.misc_2,
	BALANCES.accountnum









drop table #PAYMENTS01
drop table #PAYMENTS02
drop table #PAYMENTS03
drop table #PAYMENTS04
drop table #PAYMENTS05
drop table #PAYMENTS06
drop table #PAYMENTS07