MODULE FFTWTestf;
(**
	
	DESCRIPTION:
		
		Testing  Fast Fourier Transform library- 1D/2D FFTW
		
	AUTHOR:
		Necati Ecevit
		
*)

IMPORT
	Commands, Streams,  Kernel,
	KernelLog, Math, dll:=FFTWf ;
	
TYPE
	Float = REAL;
	Int = LONGINT;

VAR
		wr: Streams.Writer;
			
	(** from OCTK :
		implements ENTIER(log2(x)+0.5) for integers
	*)
PROCEDURE NextPowOf2*( x: LONGINT ): LONGINT;
VAR i: LONGINT;  
BEGIN
	DEC(x);
	WHILE x >= 256 DO x := ASH( x, -8 ); INC(i,8); END;
	WHILE x >= 16 DO x := ASH( x, -4 ); INC(i,4); END;		
	WHILE (x > 0)  DO x := ASH( x, -1 );  INC( i );  END;		
	RETURN i;  
END NextPowOf2;		

(* test 1D inplace transform *)		
PROCEDURE Testfftw1d*(context: Commands.Context);
VAR
	x: ARRAY [*] OF REAL;
	i,  nRetry, N: Int;		
	mul: Float;
	
	mflops, err, v: Float;	
	t: LONGINT; 
	planf, plani: dll.Plan;
	val : REAL;
	flops, a, b, c: LONGREAL;

BEGIN

		KernelLog.Ln; KernelLog.String('FFTWf library Testfftw1d:'); KernelLog.Ln; 
		
		context.arg.SkipWhitespace;
		context.arg.Int(N,FALSE); 
		context.arg.SkipWhitespace;
		context.arg.Int(nRetry,FALSE);					
			
		WHILE context.arg.res = 0 DO						
		
			KernelLog.String('N='); KernelLog.Int(N,0); 
			KernelLog.String(', nRetry='); KernelLog.Int(nRetry,0);	
						
			NEW(x,2*N);
			FOR i := 0 TO N-1 DO  		(* just fill with harmonic signal *)
					val :=  Math.cos(2*Math.pi*2*i/N); 
					x[2*i] := val*val;
					x[2*i+1] := 0.0 
			END; 
					
			(* create plans *)
			planf:=dll.PlanDft1Din(x, dll.FORWARD);
			plani:=dll.PlanDft1Din(x, dll.BACKWARD);		
		
			mul := 1;
			mul := mul/N;
		
			t:=Kernel.GetTicks();
	
			FOR i := 0 TO nRetry-1 DO
				dll.Execute(planf); (* direct transform *)
				dll.Execute(plani); (* inverse transform *)

				(* rescaling *)
				x := x*mul;
			END;		
			t:=Kernel.GetTicks()-t;
			
			(* calculate dll flops *)
		       dll.Flops(planf,a,b,c);       flops:=a+b+2*c;
		       dll.Flops(plani,a,b,c);       flops:=flops + a+b+2*c;
		 				
			err := 0;		
			FOR i := 0 TO N-1 DO
				val :=  Math.cos(2*Math.pi*2*i/N); 
				v := (x[2*i] - val*val);
				err := err + v*v;			
			END;	
			err := Math.sqrt(err);				
				
			v := t; v := v / nRetry;					
			wr.String(', time per {FFT,IFFT}='); wr.FloatFix(v,0,3,0); wr.String(' ms');
		
			mflops := 10.0*NextPowOf2(N)*N;		
			mflops := mflops*nRetry;
			mflops := mflops/t;
			mflops := mflops/1000;
		
			wr.String(' ('); wr.FloatFix(mflops,0,3,0); wr.String(' MFLOPS)'); wr.String(' ('); wr.FloatFix(flops,0,0,0); wr.String(' flops)'); 
		
			wr.String(', restit. err. (L2)='); wr.FloatFix(err,0,16,0); wr.Ln;		
			wr.Update;

		 	(* destroy plans *)
			dll.DestroyPlan(planf);
			dll.DestroyPlan(plani);
			
			context.arg.SkipWhitespace;
			context.arg.Int(N,FALSE); 
			context.arg.SkipWhitespace;
			context.arg.Int(nRetry,FALSE);
		END;

	KernelLog.String('Done!'); KernelLog.Ln;
	
	END Testfftw1d;

(* test 1D inplace transform using ExecuteDft1d function *)
PROCEDURE TestfftwExecuteDft1d*(context: Commands.Context);
VAR
	x: ARRAY [*] OF REAL;
	i,  nRetry, N: Int;		
	mul: Float;
	
	mflops, err, v: Float;	
	t: LONGINT; 
	planf, plani: dll.Plan;
	val : REAL;
	flops, a, b, c: LONGREAL;

BEGIN

		KernelLog.Ln; KernelLog.String('FFTWf library TestfftwExecuteDft1d:'); KernelLog.Ln; 
		
		context.arg.SkipWhitespace;
		context.arg.Int(N,FALSE); 
		context.arg.SkipWhitespace;
		context.arg.Int(nRetry,FALSE);					
			
		WHILE context.arg.res = 0 DO						
		
			KernelLog.String('N='); KernelLog.Int(N,0); 
			KernelLog.String(', nRetry='); KernelLog.Int(nRetry,0);	
						
			NEW(x,2*N);
			FOR i := 0 TO N-1 DO  		(* just fill with harmonic signal *)
					val :=  Math.cos(2*Math.pi*2*i/N); 
					x[2*i] := val*val;
					x[2*i+1] := 0.0 
			END; 
					
			(* create plans *)
			planf:=dll.PlanDft1Din(x, dll.FORWARD);
			plani:=dll.PlanDft1Din(x, dll.BACKWARD);		
		
			mul := 1;
			mul := mul/N;
		
			t:=Kernel.GetTicks();
	
			FOR i := 0 TO nRetry-1 DO
			
				dll.ExecuteDft1din(planf, x); (* direct transform *)
				dll.ExecuteDft1din(plani, x); (* inverse transform *)
				(* rescaling *)
				x := x*mul;
			END;		
			t:=Kernel.GetTicks()-t;
			
			(* calculate dll flops *)
		       dll.Flops(planf,a,b,c);       flops:=a+b+2*c;
		       dll.Flops(plani,a,b,c);       flops:=flops + a+b+2*c;
		 				
			err := 0;		
			FOR i := 0 TO N-1 DO
				val :=  Math.cos(2*Math.pi*2*i/N); 
				v := (x[2*i] - val*val);
				err := err + v*v;			
			END;	
			err := Math.sqrt(err);				
				
			v := t; v := v / nRetry;					
			wr.String(', time per {FFT,IFFT}='); wr.FloatFix(v,0,3,0); wr.String(' ms');
		
			mflops := 10.0*NextPowOf2(N)*N;		
			mflops := mflops*nRetry;
			mflops := mflops/t;
			mflops := mflops/1000;
		
			wr.String(' ('); wr.FloatFix(mflops,0,3,0); wr.String(' MFLOPS)'); wr.String(' ('); wr.FloatFix(flops,0,0,0); wr.String(' flops)'); 
		
			wr.String(', restit. err. (L2)='); wr.FloatFix(err,0,16,0); wr.Ln;		
			wr.Update;

		 	(* destroy plans *)
			dll.DestroyPlan(planf);
			dll.DestroyPlan(plani);
			
			context.arg.SkipWhitespace;
			context.arg.Int(N,FALSE); 
			context.arg.SkipWhitespace;
			context.arg.Int(nRetry,FALSE);
		END;

	KernelLog.String('Done!'); KernelLog.Ln;
	
	END TestfftwExecuteDft1d;


(* test 1D inplace transform of COMPLEX array using ExecuteDftComplex1d function *)
PROCEDURE TestfftwExecuteComplexDft1d*(context: Commands.Context);
VAR
	x: ARRAY [*] OF COMPLEX;
	i, j,  nRetry, N: Int;		
	mul: Float;
	
	mflops, err, v: Float;	
	t: LONGINT; 
	planf, plani: dll.Plan;
	val : REAL;
	flops, a, b, c: LONGREAL;

BEGIN

		KernelLog.Ln; KernelLog.String('FFTWf library TestfftwExecuteComplexDft1d:'); KernelLog.Ln; 
		
		context.arg.SkipWhitespace;
		context.arg.Int(N,FALSE); 
		context.arg.SkipWhitespace;
		context.arg.Int(nRetry,FALSE);					
			
		WHILE context.arg.res = 0 DO						
		
			KernelLog.String('N='); KernelLog.Int(N,0); 
			KernelLog.String(', nRetry='); KernelLog.Int(nRetry,0);	
						
			NEW(x, N);
			FOR i := 0 TO N-1 DO  		(* just fill with harmonic signal *)
					val :=  Math.cos(2*Math.pi*2*i/N); 
					RE(x[i]) := val*val;
					IM(x[i]) := 0.0 
			END; 
					
			(* create plans *)
			planf:=dll.PlanDftComplex1Din(x, dll.FORWARD);
			plani:=dll.PlanDftComplex1Din(x, dll.BACKWARD);		
		
			mul := 1;
			mul := mul/N;
		
			t:=Kernel.GetTicks();
	
			FOR i := 0 TO nRetry-1 DO
				dll.ExecuteDftComplex1din(planf, x); (* direct transform *)
				dll.ExecuteDftComplex1din(plani, x); (* inverse transform *)
				(* rescaling *)
				FOR j := 0 TO LEN(x,0)-1 DO
					x[j] := x[j]*mul;
				END;	
			END;		
			t:=Kernel.GetTicks()-t;
			
			(* calculate dll flops *)
		       dll.Flops(planf,a,b,c);       flops:=a+b+2*c;
		       dll.Flops(plani,a,b,c);       flops:=flops + a+b+2*c;
		 				
			err := 0;		
			FOR i := 0 TO N-1 DO
				val :=  Math.cos(2*Math.pi*2*i/N); 
				v := (RE(x[i]) - val*val);
				err := err + v*v;			
			END;	
			err := Math.sqrt(err);				
				
			v := t; v := v / nRetry;					
			wr.String(', time per {FFT,IFFT}='); wr.FloatFix(v,0,3,0); wr.String(' ms');
		
			mflops := 10.0*NextPowOf2(N)*N;		
			mflops := mflops*nRetry;
			mflops := mflops/t;
			mflops := mflops/1000;
		
			wr.String(' ('); wr.FloatFix(mflops,0,3,0); wr.String(' MFLOPS)'); wr.String(' ('); wr.FloatFix(flops,0,0,0); wr.String(' flops)'); 
		
			wr.String(', restit. err. (L2)='); wr.FloatFix(err,0,16,0); wr.Ln;		
			wr.Update;

		 	(* destroy plans *)
			dll.DestroyPlan(planf);
			dll.DestroyPlan(plani);
			
			context.arg.SkipWhitespace;
			context.arg.Int(N,FALSE); 
			context.arg.SkipWhitespace;
			context.arg.Int(nRetry,FALSE);
		END;

	KernelLog.String('Done!'); KernelLog.Ln;
	
	END TestfftwExecuteComplexDft1d;


(* test 1D out of place transform *)		
PROCEDURE Testfftw1dout*(context: Commands.Context);
VAR
	x,y: ARRAY [*] OF REAL;
	i,  nRetry, N: Int;		
	mul: Float;
	mflops, err, v: Float;	
	t: LONGINT; 
	planf, plani: dll.Plan;
	val : REAL;
	flops, a, b, c: LONGREAL;

BEGIN
		KernelLog.Ln; KernelLog.String('FFTWf library Testfftw1dout:'); KernelLog.Ln; 
	
		
		context.arg.SkipWhitespace;
		context.arg.Int(N,FALSE); 
		context.arg.SkipWhitespace;
		context.arg.Int(nRetry,FALSE);					
			
		WHILE context.arg.res = 0 DO						
		
			KernelLog.String('N='); KernelLog.Int(N,0); 
			KernelLog.String(', nRetry='); KernelLog.Int(nRetry,0);	
						
			NEW(x,2*N);
			NEW(y, 2*N);
			FOR i := 0 TO N-1 DO  		(* just fill with harmonic signal *)
					val :=  Math.cos(2*Math.pi*2*i/N); 
					x[2*i] := val*val;
					x[2*i+1] := 0.0 
			END; 
					
			(* create plans *)
			planf:=dll.PlanDft1Dinout(x, y, dll.FORWARD);
			plani:=dll.PlanDft1Dinout(y, x, dll.BACKWARD);		
		
			mul := 1;
			mul := mul/N;
		
			t:=Kernel.GetTicks();
	
			FOR i := 0 TO nRetry-1 DO
				dll.Execute(planf); (* direct transform *)
				dll.Execute(plani); (* inverse transform *)
				(* rescaling *)
				x := x*mul;
			END;		
			t:=Kernel.GetTicks()-t;
			
			(* calculate dll flops *)
		       dll.Flops(planf,a,b,c);       flops:=a+b+2*c;
		       dll.Flops(plani,a,b,c);       flops:=flops + a+b+2*c;
		 				
			err := 0;		
			FOR i := 0 TO N-1 DO
				val :=  Math.cos(2*Math.pi*2*i/N); 
				v := (x[2*i] - val*val);
				err := err + v*v;			
			END;	
			err := Math.sqrt(err);				
				
			v := t; v := v / nRetry;					
			wr.String(', time per {FFT,IFFT}='); wr.FloatFix(v,0,3,0); wr.String(' ms');
		
			mflops := 10.0*NextPowOf2(N)*N;		
			mflops := mflops*nRetry;
			mflops := mflops/t;
			mflops := mflops/1000;
		
			wr.String(' ('); wr.FloatFix(mflops,0,3,0); wr.String(' MFLOPS)'); wr.String(' ('); wr.FloatFix(flops,0,0,0); wr.String(' flops)'); 
		
			wr.String(', restit. err. (L2)='); wr.FloatFix(err,0,16,0); wr.Ln;		
			wr.Update;

		 	(* destroy plans *)
			dll.DestroyPlan(planf);
			dll.DestroyPlan(plani);
			
			context.arg.SkipWhitespace;
			context.arg.Int(N,FALSE); 
			context.arg.SkipWhitespace;
			context.arg.Int(nRetry,FALSE);
		END;

	KernelLog.String('Done!'); KernelLog.Ln;
	END Testfftw1dout;

(* test 2D inplace transform *)
PROCEDURE Testfftw2d*(context: Commands.Context);
VAR
	x: ARRAY [*,*] OF REAL;
	i, j, nRetry, N, M: Int;		
	mul: Float;
	err, v: Float;	
	t: LONGINT; 
	planf, plani: dll.Plan;
	val: REAL;
	mflops, flops, a, b, c: LONGREAL;

BEGIN
		KernelLog.Ln; KernelLog.String('FFTWf library Testfftw2d:'); KernelLog.Ln; 
	
		
		context.arg.SkipWhitespace;
		context.arg.Int(M,FALSE);   (* rows *)
		context.arg.SkipWhitespace;
		context.arg.Int(N,FALSE);   (* columns *)
		context.arg.SkipWhitespace;
		
		context.arg.Int(nRetry,FALSE);					
			
		WHILE context.arg.res = 0 DO						
		
			KernelLog.String('[M,N]='); KernelLog.String("["); KernelLog.Int(M,0); KernelLog.String(","); KernelLog.Int(N,0); KernelLog.String("]");
			KernelLog.String(', nRetry='); KernelLog.Int(nRetry,0);	
						
			NEW(x, M, 2*N);
			FOR j:=0 TO M-1 DO
				FOR i := 0 TO N-1 DO  		(* just fill with harmonic signal *)
						val := Math.cos(2*Math.pi*2.0*i/N);
						x[j, 2*i] := val*val; 
						x[j, 2*i+1]:=0.0 
				END;		
			END; 

	(*		j := dll.init_threads();
			dll.plan_with_nthreads(4);
	*)		
			(* create plans *)
			planf:=dll.PlanDft2Din(x, dll.FORWARD);
			plani:=dll.PlanDft2Din(x, dll.BACKWARD);
		
			mul := 1;
			mul := mul/M;
			mul:=mul/N;
			
			t:=Kernel.GetTicks();
	
			FOR i := 0 TO nRetry-1 DO
				dll.Execute(planf); (* direct transform *)
				dll.Execute(plani); (* inverse transform *)
				(* rescaling *)
				x := x*mul;
			END;		
			t:=Kernel.GetTicks()-t;
			
			(* calculate dll flops *)
		       dll.Flops(planf,a,b,c);       flops:=a+b+2*c;
		       dll.Flops(plani,a,b,c);       flops:=flops + a+b+2*c;
		 				
			err := 0;		
			FOR j:=0 TO M-1 DO
				FOR i := 0 TO N-1 DO
					val := Math.cos(2*Math.pi*2.0*i/N);
					v := (x[j, 2*i] - val*val);
					err := err + v*v;			
				END;	
			END;
			err := Math.sqrt(err);				
				
			v := t; v := v / nRetry;					
			wr.String(', time per {FFT,IFFT}='); wr.FloatFix(v,0,3,0); wr.String(' ms');
		
			mflops := 10.0*NextPowOf2(N)*N;		
			mflops := mflops*nRetry;
			mflops := mflops/t;
			mflops := mflops/1000;		
			wr.String(' ('); wr.FloatFix(mflops,0,3,0); wr.String(' MFLOPS)');
			

			 wr.String(' ('); wr.FloatFix(flops,0,0,0); wr.String(' flops)'); 
		
			wr.String(', restit. err. (L2)='); wr.FloatFix(err,0,16,0); wr.Ln;		
			wr.Update;

		 	(* destroy plans *)
			dll.DestroyPlan(planf);
			dll.DestroyPlan(plani);
			(* dll.cleanup_threads; *)
			dll.cleanup;
			
			context.arg.SkipWhitespace;
			context.arg.Int(M,FALSE); 
			context.arg.SkipWhitespace;
			context.arg.Int(N,FALSE); 
			context.arg.SkipWhitespace;
			
			context.arg.Int(nRetry,FALSE);
		END;

	KernelLog.String('Done!'); KernelLog.Ln;
	END Testfftw2d;

(* test 2D out of place transform *)
PROCEDURE Testfftw2dout*(context: Commands.Context);
VAR
	x, y: ARRAY [*,*] OF REAL;
	i, j, nRetry, N, M: Int;		
	mul: Float;
	err, v: Float;	
	t: LONGINT; 
	planf, plani: dll.Plan;
	val: REAL;
	mflops, flops, a, b, c: LONGREAL;

BEGIN
		KernelLog.Ln; KernelLog.String('FFTWf library Testfftw2dout:'); KernelLog.Ln; 
		
		context.arg.SkipWhitespace;
		context.arg.Int(M,FALSE);   (* rows *)
		context.arg.SkipWhitespace;
		context.arg.Int(N,FALSE);   (* columns *)
		context.arg.SkipWhitespace;
		
		context.arg.Int(nRetry,FALSE);					
			
		WHILE context.arg.res = 0 DO						
		
			KernelLog.String('[M,N]='); KernelLog.String("["); KernelLog.Int(M,0); KernelLog.String(","); KernelLog.Int(N,0); KernelLog.String("]");
			KernelLog.String(', nRetry='); KernelLog.Int(nRetry,0);	
						
			NEW(x, M, 2*N);
			NEW(y, M, 2*N);
			
			FOR j:=0 TO M-1 DO
				FOR i := 0 TO N-1 DO  		(* just fill with harmonic signal *)
						val := Math.cos(2*Math.pi*2.0*i/N);
						x[j, 2*i] := val*val; 
						x[j, 2*i+1]:=0.0 
				END;		
			END; 

		(*	j := dll.init_threads();
			dll.plan_with_nthreads(4);
		*)	
			(* create plans *)
			planf:=dll.PlanDft2Dinout(x, y, dll.FORWARD);
			plani:=dll.PlanDft2Dinout(y, x, dll.BACKWARD);
		
			mul := 1;
			mul := mul/M;
			mul:=mul/N;
			
			t:=Kernel.GetTicks();
	
			FOR i := 0 TO nRetry-1 DO
				dll.Execute(planf); (* direct transform *)
				dll.Execute(plani); (* inverse transform *)

				(* rescaling *)
				x := x*mul;
			END;		
			t:=Kernel.GetTicks()-t;
			
			(* calculate dll flops *)
		       dll.Flops(planf,a,b,c);       flops:=a+b+2*c;
		       dll.Flops(plani,a,b,c);       flops:=flops + a+b+2*c;
		 				
			err := 0;		
			FOR j:=0 TO M-1 DO
				FOR i := 0 TO N-1 DO
					val := Math.cos(2*Math.pi*2.0*i/N);
					v := (x[j, 2*i] - val*val);
					err := err + v*v;			
				END;	
			END;
			err := Math.sqrt(err);				
				
			v := t; v := v / nRetry;					
			wr.String(', time per {FFT,IFFT}='); wr.FloatFix(v,0,3,0); wr.String(' ms');
		
			mflops := 10.0*NextPowOf2(N)*N;		
			mflops := mflops*nRetry;
			mflops := mflops/t;
			mflops := mflops/1000;		
			wr.String(' ('); wr.FloatFix(mflops,0,3,0); wr.String(' MFLOPS)');
			

			 wr.String(' ('); wr.FloatFix(flops,0,0,0); wr.String(' flops)'); 
		
			wr.String(', restit. err. (L2)='); wr.FloatFix(err,0,16,0); wr.Ln;		
			wr.Update;

		 	(* destroy plans *)
			dll.DestroyPlan(planf);
			dll.DestroyPlan(plani);
			(* dll.cleanup_threads; *)
			dll.cleanup;
			
			context.arg.SkipWhitespace;
			context.arg.Int(M,FALSE); 
			context.arg.SkipWhitespace;
			context.arg.Int(N,FALSE); 
			context.arg.SkipWhitespace;
			
			context.arg.Int(nRetry,FALSE);
		END;

	KernelLog.String('Done!'); KernelLog.Ln;
	END Testfftw2dout;
	
	
BEGIN
		Streams.OpenWriter(wr,KernelLog.Send);
END FFTWTestf.

SystemTools.Free  FFTWTestf FFTWf~


FFTWTestf.TestfftwExecuteDft1d
256 1 

11 100
16 100
19 100
512 20 
1024 20
2048 20
4096 20 ~

FFTWTestf.TestfftwExecuteComplexDft1d
256 1 

11 100
16 100
19 100
512 20 
1024 20
2048 20
4096 20 ~

FFTWTestf.Testfftw1d
256 20 

11 100
16 100
19 100
512 20 
1024 20
2048 20
4096 20 

8192 500
16384 250 
32768 125
65536 63

200 16000
600 8000
2000 2000
4500 1000
8500 500
17000 250
40000 125
60000 63
~

FFTWTestf.Testfftw1dout

256 20 

11 100
16 100
19 100
512 20 
1024 20
2048 20
4096 20 ~

256 20 

11 100
16 100
19 100
512 20 
1024 20
2048 20
4096 20 ~

[M N nRetry]

FFTWTestf.Testfftw2d
19 19 1
256 256 1 ~ 
1024 1024 5 
1600 1200 5 ~
1600 1199 5
4048 4048 2
~

FFTWTestf.Testfftw2dout

256 256 1 ~ 



