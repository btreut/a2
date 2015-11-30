MODULE StatisticsLinearRegression; (** AUTHOR "Patrick Hunziker 2012"; PURPOSE "Linear Regression Models"; *)

(*mathematical limitations for linear regression are summarized in 
http://en.wikipedia.org/wiki/Linear_regression_model 
and can lead to failure of the algorithm/solvers.
If the used QR solver (current standard in MatrixLeastSquares) fails in an underdetermined system, 
a SVD based least squares solver for least squares computation (in all types off systems) will help,
or a Krylov based solver may help. 
*)

IMPORT MatrixBase, MatrixLeastSquares, StatisticsFunctions, Util:=MatrixUtilities, Streams, Random, KernelLog, StatisticsBase;

(* http://en.wikipedia.org/wiki/Linear_regression *)	 
(**

elementwise:  
	y1 = b1 x11+b2 x12 +b3 x13 .. + e1 
	y2 = b2 x21 ...
	
Usually a constant is included as one of the regressors. 
For example we can take xi1 = 1 for i = 1, ..., n. 
The corresponding element of X is called the intercept. 
	
vector form: 
 y= Xb + e  ; with y,b,e: vector; X: matrix (in the simplest case, only  one column)

least squares formulation
 X`X b = X` y 
 
 or
 b= Invert(X`X) * X`y
 *)

TYPE Matrix*=MatrixBase.Matrix; 
	Vector*=MatrixBase.Vector;
	Scalar*=MatrixBase.Datatype;
	
VAR w: Streams.Writer;

(**
y = Xb + e

y: Observed response variables, vector
x: regressors = input variables, one row for each response element, making up the design matrix X; 
b: regression coefficient vector, to be determined
e: error term
usually, a constant is included in the regressors X, (e.g. all xi1 := 1), and the resulting b is called intercept.
See example in Test() below.
*)

TYPE Regression*= OBJECT
		VAR 
			X: Matrix;
			b-, e-, yestimate-: Vector; (* regression coefficients and residual  for regression and simple regression*)
			B-,U-: Matrix; (* regression coefficients and residuals for GLM *)
			R2-,	(* see http://en.wikipedia.org/wiki/Coefficient_of_determination *)
			R2adj-, (* adjusted R2 [korrigiertes Bestimmtheitsmass, adjusts for number o regressors, http://en.wikipedia.org/wiki/Coefficient_of_determination#Adjusted_R2 
						suited to explore if a model with a restricted or a nonrestricted number of regressors is prefereable: the best model has the highest R2corr *)
			RSS-, (* residual sum of squares = sum of squared residuals *)
			F-, p-, ymean-: Scalar;
			
			ls: MatrixLeastSquares.LeastSquares;

			isGLM:BOOLEAN;
			nvar, nsamp: LONGINT;
			
		PROCEDURE &Init*(CONST X: Matrix; intercept: BOOLEAN);
		BEGIN
			IF LEN(X,0)>0 THEN 
				nvar:=LEN(X,1);
				nsamp:=LEN(X,0);
				IF intercept THEN	NEW(SELF.X, nsamp, nvar+1); SELF.X[..,0]:=1; SELF.X[..,1..]:=X;
				ELSE SELF.X:=X
				END;
				NEW(ls, SELF.X); 
			ELSE (* needs later call of Init() or InitSimple() *)
			END;
		END Init;
		
		PROCEDURE InitSimple*(CONST x:Vector; intercept:BOOLEAN);
		BEGIN
			ASSERT(LEN(x,0)>0);
			nvar:=1; 
			nsamp:=LEN(x,0);
			IF intercept THEN NEW (X, nsamp, 2); X[..,0]:=1; X[..,1]:=x;
			ELSE NEW(X,nsamp, 1); X[..,0]:=x; 
			END;
			NEW(ls, X); 
		END InitSimple;
		
		PROCEDURE Solve*(CONST y: Vector):Vector; (* yields b *)
		BEGIN
			isGLM:=FALSE;
			b:=ls.Solve(y);
			yestimate:=X*b;
			ymean:=SUM(y)/LEN(y,0);
				(* coefficient of determination *)
			e:= y- yestimate;
			RSS:=e+*e;
			R2:= 1-(RSS / ((y-ymean)+*(y-ymean))); 
			IF nsamp#(nvar+1) THEN (*no division by zero*)
				R2adj:=1-(1-R2)*((nsamp-1)/(nsamp-nvar-1));
				F:= (R2/(nvar+1)) / ((1-R2)/(nsamp-nvar-1));
				p := StatisticsFunctions.PSnedecor(nsamp,nvar,F); (* due to a problem in StatisticsFunctions.Mod, p works only for even degrees of freedom *)
			END;	
			RETURN b
		END Solve;
		
		PROCEDURE SolveGLM*(CONST Y:Matrix): Matrix; (* yields B *)
		VAR i:LONGINT; y, b,e: Vector;
		BEGIN
			isGLM:=TRUE;
			NEW(B, LEN(X,1), LEN(Y,1));
			NEW(U, LEN(Y,0), LEN(Y,1));
			FOR i:=0 TO LEN(Y,1)-1 DO (* can be optimized *)
				y:=Y[..,i];
				b:=ls.Solve(y);
				e:= y- X*b;
				B[..,i]:=b;
				U[..,i]:=e;
			END;
			RETURN B
			(*! to do: compute regression coefficient R2, F-statistics, and p value*)
		END SolveGLM;
	END Regression;
	
(* Theil-Sen Estimator for data streams: http://dx.doi.org/10.1145/1240233.1240239 *)
TYPE Stream_TheilSenEstimator*=OBJECT
	END Stream_TheilSenEstimator;

(* Multivariate Theil-Sen Estimator: http://home.olemiss.edu/~xdang/papers/MTSE.pdf *)
TYPE Multivariate_TheilSenEstimator*=OBJECT
END Multivariate_TheilSenEstimator;

PROCEDURE LinearRegression*(CONST X: Matrix; CONST y: Vector; VAR b, e: Vector);
VAR ls: MatrixLeastSquares.LeastSquares;
BEGIN
	NEW(ls, X); 
	b:=ls.Solve(y);
	e:= y- X*b;
END LinearRegression;

(* no intercept, assumption is that regression line goes through origin *)
PROCEDURE SimpleRegressionNoIntercept*(CONST x: Vector; CONST y: Vector; VAR b: Scalar; VAR e: Vector);
VAR X: Matrix; B: Vector;
BEGIN
	(*can be simplified*)
	NEW(X, LEN(x,0), 1); 
	X[..,0]:=x;
	LinearRegression(X,y,B,e);
	b:=B[0];
END SimpleRegressionNoIntercept;

PROCEDURE SimpleRegression*(CONST x: Vector; CONST y: Vector; VAR b, intercept: Scalar; VAR e: Vector);
VAR X: Matrix; B: Vector;
BEGIN
	(*can be simplified*)
	NEW(X, LEN(x,0), 2); 
	X[..,0]:=1;
	X[..,1]:=x;
	LinearRegression(X,y,B,e);
	intercept:=B[0];
	b:=B[1];
END SimpleRegression;

(**
The general linear model (GLM) is a statistical linear model. It may be written as
    Y = XB + U
where Y is a matrix with series of multivariate measurements, 
X is a matrix that might be a design matrix, 
B is a matrix containing parameters that are usually to be estimated and 
U is a matrix containing errors or noise. 

The general linear model incorporates a number of different statistical models: 
ANOVA, ANCOVA, MANOVA, MANCOVA, ordinary linear regression, t-test and F-test. 
The general linear model is a generalization of multiple linear regression model to 
the case of more than one dependent variable.

see http://en.wikipedia.org/wiki/General_linear_model
*)

PROCEDURE GeneralLinearModel*(CONST X: Matrix; CONST Y: Matrix; VAR B, U: Matrix); (** not exhaustively tested *)
	VAR ls: MatrixLeastSquares.LeastSquares;
		y, b,e: Vector; i:LONGINT;
BEGIN
	NEW(ls, X); 
	NEW(B, LEN(X,1), LEN(Y,1));
	NEW(U, LEN(Y,0), LEN(Y,1));
	FOR i:=0 TO LEN(Y,1)-1 DO
		y:=Y[..,i];
		b:=ls.Solve(y);
		e:= y- X*b;
		B[..,i]:=b;
		U[..,i]:=e;
	END;
END GeneralLinearModel;

(*
PROCEDURE SignificanceSimpleRegression(CONST b: Scalar; CONST e: Vector; VAR t,F, SEE, SEb: Scalar);
BEGIN
	SEE:= MathL.sqrt((1-b*b)*((N-2)/(N-1)));
	SEb:= SEE/(Sx*MathL.sqrt(N-1));
	t := b / SEE;
	F := t*t;
END Significance;
*)


(* 
The Theil-Sen estimator is a simple robust estimation technique that determine the slope of a dataset 
as the median of the slopes of the lines through pairs of sample points. 
It has similar statistical efficiency properties to simple regression but is much less sensitive to outliers.
Note that at current, this implementation limits the search to MIN(200, N/2) pairs for efficiency reasons, while a full algorithm may consider all pairs and is therefore O(N*N) with added sorting.
see http://en.wikipedia.org/wiki/Theil%E2%80%93Sen_estimator for  details
**)
PROCEDURE TheilSenEstimator*(CONST x: Vector; CONST y: Vector; VAR b, intercept: Scalar; VAR e: Vector); 
VAR slopes: Vector; i,j,len:LONGINT; dx, dy: Scalar;
BEGIN
	(*choose sample pairs; here the extremal point pairs are used. Random pairs could also be used *)	
	len:=MIN (200, LEN(x,0) DIV 2);
	NEW(slopes, len);
	FOR i:=0 TO len-1 DO
		j:=i;
		(*? possible improvement: randomize i, or choose i with large dx 
		VAR random:Random.Generator;
		NEW(random);
		j:=ENTIER(random.Uniform() * len );
		*)
		dx:=x[LEN(x,0)-1-j]-x[j];
		dy:=y[LEN(x,0)-1-j]-y[j];
		IF dx#0 THEN	slopes[i]:=dy/dx END; (* dx=0 not yet handled properly, but has usually only  a minor impact *)
	END;
	(*Sort(slopes);*)
	StatisticsBase.QSort(slopes);
	b:=slopes[len DIV 2]; (*choose median slope *)
	e:=y-b*x;
	intercept:=SUM(e)/LEN(x,0);
	e:=e-intercept;
	(*optional: estimation of 95% confidence interval, based on observation of 600 pairs is sufficient according to literature*)
END TheilSenEstimator;



PROCEDURE Test*;
VAR X: Matrix; x, y, B,e: Vector; b, intercept: Scalar;
BEGIN
	y:=[1.0,2.1,2.9, 4.1, 5.0, 5.9]+2; (*note the intercept*)

	w.String("Simple Regression: regression coefficient, error vector, sum of square errors"); w.Ln; w.Update;
	x:=[1.0,2,3,4,5,6];
	SimpleRegressionNoIntercept(x,y,b,e);
	w.FloatFix(b, 4, 10, 0); w.Ln; w.Update;
	Util.OutVector(e);
	w.FloatFix(e+*e, 4, 10, 0); w.Ln; w.Ln; w.Update;	

	w.String("Simple Regression with intercept: regression coefficient, intercept, error vector, sum of square errors"); w.Ln; w.Update;
	x:=[1.0,2,3,4,5,6];
	SimpleRegression(x,y,b,intercept, e);
	w.FloatFix(b, 4, 10, 0); w.FloatFix(intercept, 4, 10, 0); w.Ln; w.Update;
	Util.OutVector(e);
	w.FloatFix(e+*e, 4, 10, 0); w.Ln; w.Ln; w.Update;	

	w.String("Linear Regression"); w.Ln; w.Update;
	X:=[[1.0,1.1],[2,1.9],[3,2.8],[4,4.1],[5,5.3],[6,5.8]];
	LinearRegression(X,y,B,e);
	Util.OutVector(B);
	Util.OutVector(e);
	w.FloatFix(e+*e, 4, 10, 0); w.Ln; w.Ln; w.Update;
	
	w.String("Linear Regression with intercept"); w.Ln; w.Update;
	(* X:=[[1.0,1.1,1.0],[1.0,1.9,2.1],[1,2.8, 2.9],[1,4.1,3.9],[1,5.3, 5.1],[1,5.8, 6]]; *)
	X:=[[1.0,1.1],
		[1.0,1.9],
		[1,2.8],
		[1,4.1],
		[1,5.3],
		[1,5.8]];
	LinearRegression(X,y,B,e);
	Util.OutVector(B);
	Util.OutVector(e);
	w.FloatFix(e+*e, 4, 10, 0); w.Ln; w.Ln; w.Update;
	
	w.String("Theil Sen Estimator: robust slope"); w.Ln; w.Update;
	x:=[1.0,2,3,4,5,6];
	TheilSenEstimator(x,y,b,intercept, e);
	w.FloatFix(b, 4, 10, 0); w.FloatFix(intercept, 4, 10, 0); w.Ln;w.Update;
	Util.OutVector(e);
	w.FloatFix(e+*e, 4, 10, 0); w.Ln; 
	w.Update;	
END Test;

PROCEDURE TestGLM*;
VAR X,Y, B,U: Matrix;
BEGIN
	Y:=[[1.0,10],[2.1,21],[2.9,29],[ 4.1,41], [5.0,50], [5.9,59]]; (* dependent variables/measurements *)
	X:=[[1,1.0,1.1],[1,2,1.9],[1,3,2.8],[1,4,4.1],[1,5,5.3],[1,6,5.8]]; (* design matrix; first row is constant => intercept*)
	GeneralLinearModel(X,Y,B,U);
	w.String("General Linear Model: B, U, sum of squared error"); w.Ln; w.Update;
	Util.OutMatrix(B); w.Ln; w.Update; (* regression coefficients*)
	Util.OutMatrix(U); (* error matrix *)
	w.FloatFix(U+*U, 4, 10, 0); w.Ln; w.Ln; w.Update;
END TestGLM;

PROCEDURE TestEngine*;
VAR 
	regression:Regression;
	X: Matrix; x, y: Vector; b,e: Vector; 
BEGIN
	x:=[1.0,2,3,4,5,6];	
	NEW(regression,X,TRUE);
	y:=[1.0,2.1,2.9, 4.1, 5.0, 5.9]+2;
	regression.InitSimple(x, TRUE);
	b:=regression.Solve(y);
	w.String("regression "); w.Ln; w.Update;
	Util.OutVector(b); w.Ln; w.Update; (* regression coefficients*)
	e:=regression.e;
	Util.OutVector(regression.yestimate); w.Ln; w.Update;
	w.String("R2, R2adj, SSE, F, p: "); w.Ln; w.Update;
		Util.OutVector([regression.R2]);
		Util.OutVector([regression.R2adj]);
		Util.OutVector([regression.e+*e]);
		Util.OutVector([regression.F]);
		Util.OutVector([regression.p]);
		w.Ln; w.Update;

	X:=[[1.0,8],[2,1],[3,2],[4,5],[5,4],[6,3]];
	NEW(regression,X,TRUE);
	y:=[1.0,2.1,2.9, 4.1, 5.0, 5.9]+2;
	b:=regression.Solve(y);
	w.String("regression with 2 regressors "); w.Ln; w.Update;
	Util.OutVector(b); w.Ln; w.Update; (* regression coefficients*)
	Util.OutVector(regression.e); w.Ln; w.Update; (* regression coefficients*)
	w.String("R2, R2adj, SSE, F, p: "); w.Ln; w.Update;
		Util.OutVector([regression.R2]);
		Util.OutVector([regression.R2adj]);
		Util.OutVector([regression.e+*e]);
		Util.OutVector([regression.F]);
		Util.OutVector([regression.p]);
		w.Ln; w.Update;
		
	X:=[[1.0,1.1],[2,1.9],[3,2.8],[4,4.1],[5,5.3],[6,5.8]];
	NEW(regression,X,TRUE);
	y:=[1.0,2.1,2.9, 4.1, 5.0, 5.9]+2;
	b:=regression.Solve(y);
	
	w.String("regression with 2 regressors; colinear data "); w.Ln; w.Update;
	Util.OutVector(b); w.Ln; w.Update; (* regression coefficients*)
	Util.OutVector(regression.e); w.Ln; w.Update; (* regression coefficients*)
	w.String("R2, R2adj, SSE, F, p: "); w.Ln; w.Update;
		Util.OutVector([regression.R2]);
		Util.OutVector([regression.R2adj]);
		Util.OutVector([regression.e+*e]);
		Util.OutVector([regression.F]);
		Util.OutVector([regression.p]);
		w.Ln; w.Update;
END TestEngine;

PROCEDURE TestFprobability*; (* compute probability from F-value *)
VAR df1,df2:LONGINT; F:LONGINT;
BEGIN
	FOR F:=1 TO 5 DO
		Util.OutVector([F*F]);
		FOR df2:=1 TO 5 DO 
			Util.OutVector([StatisticsFunctions.PSnedecor(1,df2,F*F),StatisticsFunctions.PSnedecor(4,df2,F*F),StatisticsFunctions.PSnedecor(8,df2,F*F),StatisticsFunctions.PSnedecor(12,df2,F*F),StatisticsFunctions.PSnedecor(20,df2,F*F)]);
		END;
	END;
END TestFprobability;


BEGIN
	Streams.OpenWriter(w, KernelLog.Send)
END StatisticsLinearRegression.

StatisticsLinearRegression.Test~
StatisticsLinearRegression.TestGLM~
StatisticsLinearRegression.TestEngine~
StatisticsLinearRegression.TestFprobability~
SystemTools.FreeDownTo StatisticsFunctions StatisticsLinearRegression ~ 
