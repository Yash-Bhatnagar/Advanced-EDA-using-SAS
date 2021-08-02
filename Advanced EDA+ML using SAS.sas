*Using SAS to perform basic EDA and build a ML model as per the requirement of client;

*Importing dataset in the SAS environment and checking top 10 records;

*Importing the file;
FILENAME REFFILE '/folders/myfolders/GP week 4/Life+Insurance+Dataset.csv';
PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=WORK.insData;
	GETNAMES=YES;
RUN;
*Getting first 10 records;
PROC PRINT DATA=insData(obs=10); 
RUN;


*Checking the variable type present in the dataset;
proc contents data=insData varnum;
run;


*Checking if any variables have missing values?;
proc means data=insData nmiss;
run;
*Ans--No missing values found, therefore no treatment needed;


*Checking the summary and percentile distribution of all numerical variables for churners and non-churners;

*For ease of code we will use var_num variable to represent numerical values present in the dataset;
%let var_num = age Cust_Tenure Overall_cust_satisfation_score CC_Satisfation_score Cust_income Agent_Tenure YTD_contact_cnt Due_date_day_cnt Existing_policy_count Miss_due_date_cnt;

*One way to check data summary and percentile distribution;
/*proc univariate data=insdata;
	var &var_num;
	title 'Percentile Distribution and Summary for both churners and non-churners';
run;*/

*Better way to get the summary along with percentile distribution;
proc means data=insData n nmiss min p1 p5 p10 p25 p50 p75 p90 p95 p99 max;
	var &var_num;
	title 'Percentile Distribution and Summary';
run;

proc means data=insData n nmiss min p1 p5 p10 p25 p50 p75 p90 p95 p99 max;
	var &var_num;
	where churn = 1;
	title 'Percentile Distribution and Summary for CHURNERS';
run;

proc means data=insData n nmiss min p1 p5 p10 p25 p50 p75 p90 p95 p99 max;
	var &var_num;
	where churn = 0;
	title 'Percentile Distribution and Summary for CHURNERS';
run;


/*Checking for outliers*/
proc univariate data=insdata;
var &var_num;
run;


/*Outliers found in : Cust_income and Due_date_day_cnt
Treatment:-- */
data insdata;
set insdata;
	if Cust_income > 35331.0 then Cust_income = 35331.0;
	if Cust_income < 17001.0 then Cust_income = 17001.0;
	if Due_date_day_cnt > 34 then Due_date_day_cnt = 34;
run;

*Checking for outliers after doing treatment;
proc univariate data=insdata;
var &var_num;
run;


/*Checking the proportion of all categorical variables 
and extracting percentage contribution of each class in respective variables*/
%let var_cat = Payment_Period Product EducationField Gender Cust_Designation Cust_MaritalStatus;
proc freq data=insData;
	table &var_cat / nocum;
	title 'Percentage distribution of categorical variables';
run;


/*Creating a macro which can be used to fetch all the important information like Age, Education, Gender, Income and CustID from the mobile number */

*Macro to find details by mobile number;
%MACRO get_info();
	DATA output (keep = CustID Age EducationField Gender Cust_Income);
	SET insData;
	where  Mobile_num in (&mobile_number.);
	RUN;

	proc print data=output;
	run;
%MEND;

/*Input examples-- mobile number*/
%let mobile_number = 9926913118, 9952270464; *These 2 mobile numbers can be replaced with desired mobile numbers;

/*run macro for output*/
%get_info;


/*Checking correlation of all numerical variables before building model, because we cannot add correlated variables in model*/
proc corr data=insdata NOPROB;
	var &var_num;
run;


/*Creating train and test (70:30) dataset from the existing data set(seed 1234)*/

*Finding the percent distribution of customers who have and haven't churned in the main dataset;
proc freq data=insdata;
	table Churn /nocum;
	title "Percent distribution of customers who have and haven't churned in the main dataset";
run;

*To calculate sample size-- 30 % of 1924 = 577.2 take it as 578;
proc surveyselect data=insdata method = srs rep=1 sampsize=578 seed = 1234 out =test;
RUN;
proc contents data=test varnum;
run;


*Finding the percent distribution of customers who have and haven't churned in the TEST dataset;
proc freq data=test;
table Churn /nocum;
title "Percent distribution of customers who have and haven't churned in the TEST dataset";
run;

proc sql;
	create table train as 
	select t1.* from insData as t1
	where CustID not in (select CustID from test);
quit;


*Finding the percent distribution of customers who have and haven't churned in the TRAIN dataset;
proc freq data=train;
	table Churn /nocum;
	title "Percent distribution of customers who have and haven't churned in the TRAIN dataset";
run;



/*Developing linear regression model first on the target variable to extract VIF information 
to check multicollinearity*/

/* Multicollinearity Investigation of VIF*/
proc reg data=insdata;
model churn = &var_num Complaint / vif ;
title 'Multicollinearity Investigation';
run;
/*As for variance inflation, the magic number to look out for is anything above the value of 10. 
As we can see from the values indicated in this column, 
our highest value sits at 2.53840,
indicating a lack of multicollinarity, according to these results*/


/*Creating clean logistic model on the target variables?*/
%let var_num2 = age Cust_Tenure Overall_cust_satisfation_score CC_Satisfation_score;
proc logistic data=train descending outmodel=model;
	model churn = &var_num2 / lackfit;
	output out = train_output xbeta = coeff stdxbeta = stdcoeff predicted = prob;
run;


/*Creating a macro and taking a KS approach to take a cut off on the calculated scores*/
%MACRO find_KS();
	proc npar1way data=train_output;
		class churn;
		var &var_ks;
	run;
%MEND;

%let var_ks = &var_num2; /*You can change variable name to find KS score*/
%find_KS; /*To run the macro*/


/*Predicting test dataset using created model*/
data test; 
set test;
prob = 14.1734 - 0.3031*Age - 0.3870*Cust_Tenure -0.8674*Overall_cust_Satisfation_score +0.3179*CC_Satisfation_score;
score = exp(prob)/(1+exp(prob));
run;