MODULE StatisticsRobustRegression; (** AUTHOR "Patrick Hunziker 2012"; PURPOSE "Robust Regression Models"; *)
(*! work needed: implement univariate and multivariate Theil-Sen here, including Theil-Sen for streams. (references given below)
	linear methods to be removed *)

	(*! important source of inspiration for robust statistics:  http://stat.ethz.ch/people/maechler/robustness *)


(*mathematical limitations for linear regression are summarized in
http://en.wikipedia.org/wiki/Linear_regression_model
and can lead to failure of the algorithm/solvers.
If the used QR solver (current standard in MatrixLeastSquares) fails in an underdetermined system,
a SVD based least squares solver for least squares computation (in all types off systems) will help,
or a Krylov based solver may help.
*)

IMPORT MatrixBase, MatrixLeastSquares, StatisticsFunctions, Util:=MatrixUtilities, Streams, Random, KernelLog, StatisticsBase,
	StatisticsLinearRegression, MathL, MatrixPrincipalComponents;

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
	eps0, eps: Scalar;

(**
y = Xb + e

y: Observed response variables, vector
x: regressors = input variables, one row for each response element, making up the design matrix X;
b: regression coefficient vector, to be determined
e: error term
usually, a constant is included in the regressors X, (e.g. all xi1 := 1), and the resulting b is called intercept.
See example in Test() below.
*)

TYPE Regression*= OBJECT (*! work needed: implement univariate and multivariate Theil-Sen here*)
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
			(*
			ASSERT(LEN(x,0)>0);
			nvar:=1;
			nsamp:=LEN(x,0);
			IF intercept THEN NEW (X, nsamp, 2); X[..,0]:=1; X[..,1]:=x;
			ELSE NEW(X,nsamp, 1); X[..,0]:=x;
			END;
			NEW(ls, X);
			*)
		END InitSimple;

		PROCEDURE Solve*(CONST y: Vector):Vector; (* yields b *)
		BEGIN
			(*
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
			*)
		END Solve;

		PROCEDURE SolveGLM*(CONST Y:Matrix): Matrix; (* yields B *)
		VAR i:LONGINT; y, b,e: Vector;
		BEGIN
			(*
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
			*)
			(*! to do: compute regression coefficient R2, F-statistics, and p value*)
		END SolveGLM;
	END Regression;

(* Theil-Sen Estimator for data streams: http://dx.doi.org/10.1145/1240233.1240239 *)
TYPE Stream_TheilSenEstimator*=OBJECT
	END Stream_TheilSenEstimator;

(* Multivariate Theil-Sen Estimator:
multivariate median:
http://papers.ssrn.com/sol3/Delivery.cfm/SSRN_ID1690502_code847251.pdf?abstractid=1690502&mirid=3

multivariate theil-sen implementations:
http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.78.7797
http://home.olemiss.edu/~xdang/papers/MTSE.pdf
*)
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
	b := StatisticsBase.DestructiveMedian(slopes);
	(*
	StatisticsBase.QSort(slopes);
	b:=slopes[len DIV 2]; (*choose median slope *)
	*)
	e:=y-b*x;
	intercept:=SUM(e)/LEN(e,0);
	e:=e-intercept;
	(*optional: estimation of 95% confidence interval, based on observation of 600 pairs is sufficient according to literature*)
END TheilSenEstimator;

(* experiment: for each predictor dimension, a TheilSen Estimate is done.
	Multidimensional regression is assumed to be a composite of those partial regressions .
	b[0] is intercept *)
PROCEDURE MultivariateTheilSen*(CONST X: Matrix; CONST y: Vector; VAR b: Vector;  VAR e: Vector);
VAR X0, slopes: Matrix; i,j,k,len:LONGINT; dx: Vector; intercept, d, dy, sumx, slope, threshold, zero, inf, mininf: Scalar; random: Random.Generator;
	pca:MatrixPrincipalComponents.PCA;
	max,min:Scalar;
	columnMean, onesR: Vector;
BEGIN
	NEW(onesR, LEN(X,0)); onesR:=1;
	columnMean := (onesR * X)/LEN(X,0);
	X0 := X - onesR ** columnMean; (* PCA requires zero column mean input data *)
	
	NEW(pca, X0);
	X0:=pca.PrincipalComponents(); (* remove colinearity *)  
	Util.OutMatrix(X0);
	
	(*choose sample pairs; here the extremal point pairs are used. Random pairs could also be used *)	
	len:=MIN (200, LEN(X,0)*LEN(X,0));
	NEW(slopes, len, LEN(X0,1));
	NEW(random);
	NEW(b, LEN(X0,1)+1); (*include intercept*)
	inf:=1/zero; mininf:=-inf;
	min:=mininf; max:=inf;
	FOR i:=0 TO len-1 DO
		j:=ENTIER(random.Uniform() * LEN(X0,0));
		k:=ENTIER(random.Uniform() * LEN(X0,0));
		dx:=X0[k]-X0[j];
		sumx:=SUM(ABS(dx));
		dy:=y[k]-y[j];
		FOR j:=0 TO LEN(dx,0)-1 DO 
			IF ABS(dx[j]) > 1.0E-20 THEN 
				slopes[i,j]:=dy  * (dx[j]/sumx) /dx[j]; (* each dx contributes a part to dy *)
				max:=MAX(max, slopes[i,j]);
				min:=MIN(min, slopes[i,j]);
			ELSIF dx[j]=0 THEN slopes[i,j]:=0
			ELSE (*!  handling here must be improved  *)
				(*IF dy*dx[j]>=0 THEN slopes[i,j]:= inf
				ELSE slopes[i,j]:= mininf
				END;*)
				(*slopes[i,j]:=0*)
				IF ODD(i) THEN slopes[i,j]:=inf (*?=0?*)
				ELSE slopes[i,j]:=mininf (*?=0?*)
				END;
			END; (*? eps handing could be improved ?*)
		END;
	END;
	(*Util.OutMatrix(slopes);*)
	FOR i:=0 TO LEN(X0,1)-1 DO
		StatisticsBase.QSort(slopes[..,i]);
		b[i+1]:=slopes[len DIV 2,i]; (*choose median slope; b[0] is intercept *)
	END;
	Util.OutMatrix(slopes);
	e := (* y- *) X0*b[1..]; (*PCA yields zero mean data *)
	intercept:=SUM(y)/LEN(y,0);
	b[0]:=intercept;
	Util.OutVector(b); (*! to do: convert coordinates back to domain of X, not of X0*)
	Util.OutVector(y+e);
END MultivariateTheilSen;


	PROCEDURE Test*;
VAR X: Matrix; x, y, B,e: Vector; b, intercept: Scalar;
BEGIN
	y:=[1.02,2.1,2.91, 4.105, 5.0, 5.93,7.11, 8.03, 9.02, 10.01, 11.003]+2; (*note the intercept*)

	w.String("Linear Regression with intercept"); w.Ln; w.Update;
	(* X:=[[1.0,1.1,1.0],[1.0,1.9,2.1],[1,2.8, 2.9],[1,4.1,3.9],[1,5.3, 5.1],[1,5.8, 6]]; *)
	X:=[[1.0,1.1,1.1],
		[1.0,1.9,2],
		[1,2.8,3.1],
		[1,4.1, 3.9],
		[1,5.3,5],
		[1,5.8,6],
		[1,7,7.1],
		[1,7.9,8],
		[1,9,8.9],
		[1,10.1,10],
		[1,11,11.1]
		];
	StatisticsLinearRegression.LinearRegression(X,y,B,e);
	Util.OutVector(B);
	Util.OutVector(e);
	w.FloatFix(e+*e, 4, 10, 0); w.Ln; w.Ln; w.Update;

	w.String("Multivariate Robust Regression with intercept"); w.Ln; w.Update;
	X:=[[1.1,1.11],
		[1.9,2.05],
		[2.82,3.1],
		[4.1, 3.91],
		[5.3,5.103],
		[5.8,6.03],
		[7.12,7.1],
		[7.9,8.12],
		[9.03,8.9],
		[10.1,10.05],
		[11.05,11.1]
		];
	MultivariateTheilSen(X,y,B,e);
	w.String("b, e, error:"); w.Ln; w.Update; (*however, this b and e refer to the PCA transformed data ...*)
	Util.OutVector(B);
	Util.OutVector(e);
	w.FloatFix(e+*e, 4, 10, 0); w.Ln; w.Ln; w.Update;
	(*
	w.String("Univariate Robust Regression with intercept"); w.Ln; w.Update;
	X:=[[1.1,1.1],
		[1.9,2],
		[2.8,3.1],
		[4.1, 3.9],
		[5.3,5],
		[5.8,6],
		[7,7.1],
		[7.9,8],
		[9,8.9],
		[10.1,10],
		[11,11.1]
		];
	TheilSenEstimator(X[0],y,b,intercept,e);
	Util.OutVector(B);
	Util.OutVector(e);
	w.FloatFix(e+*e, 4, 10, 0); w.Ln; w.Ln; w.Update;
	*)
END Test;

PROCEDURE TestSort*;
VAR x: ARRAY [*] OF Scalar; i:LONGINT;
	random:Random.Generator;
BEGIN
	 NEW(x,10);
	 NEW(random);
	 FOR i:=0 TO LEN(x,0)-1 DO
	 	x[i]:=random.Uniform();
	 END;
	 Util.OutVector(x);
	 StatisticsBase.QSort(x);
	 Util.OutVector(x);
END TestSort;

BEGIN
	Streams.OpenWriter(w, KernelLog.Send);
	eps0:=1; WHILE eps0 > 0 DO eps:=eps0; eps0:=eps/2 END;
	w.Float(eps, 30); w.Ln; w.Update;
END StatisticsRobustRegression.


StatisticsRobustRegression.Test ~
StatisticsRobustRegression.TestSort ~


SystemTools.FreeDownTo StatisticsRobustRegression ~
