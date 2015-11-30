MODULE FFTWTest;
(**
	
	DESCRIPTION:
		
		Testing  Fast Fourier Transform library- 1D/2D FFTW
		
	AUTHOR:
		Necati Ecevit
		
*)

IMPORT
	Commands, Streams,  Kernel,
	KernelLog, Math := MathL, dll:=FFTW ;
	
TYPE
	Float = LONGREAL;
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

(* test 1D transform *)		
PROCEDURE Testfftw1d*(context: Commands.Context);
VAR
	x: ARRAY [*] OF LONGREAL;
	i,  nRetry, N: Int;		
	mul: Float;

	mflops, err, v: Float;	
	t: LONGINT; 
	planf, plani: dll.Plan;
	val : LONGREAL;
	flops, a, b, c: LONGREAL;

BEGIN
		KernelLog.Ln; KernelLog.String('FFTW library Testfftw1d:'); KernelLog.Ln; 
		
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
	x: ARRAY [*] OF LONGREAL;
	i,  nRetry, N: Int;		
	mul: Float;
	
	mflops, err, v: Float;	
	t: LONGINT; 
	planf, plani: dll.Plan;
	val : LONGREAL;
	flops, a, b, c: LONGREAL;

BEGIN

		KernelLog.Ln; KernelLog.String('FFTW library TestfftwExecuteDft1d:'); KernelLog.Ln; 
		
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
	x: ARRAY [*] OF LONGCOMPLEX;
	i, j,  nRetry, N: Int;		
	mul: Float;
	
	mflops, err, v: Float;	
	t: LONGINT; 
	planf, plani: dll.Plan;
	val : LONGREAL;
	flops, a, b, c: LONGREAL;

BEGIN

		KernelLog.Ln; KernelLog.String('FFTW library TestfftwExecuteComplexDft1d:'); KernelLog.Ln; 
		
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

(* test 2D transform *)
PROCEDURE Testfftw2d*(context: Commands.Context);
VAR
	x: ARRAY [*,*] OF LONGREAL;
	i, j, nRetry, N, M: Int;		
	mul: Float;
	err, v: Float;	
	t: LONGINT; 
	planf, plani: dll.Plan;
	val: LONGREAL;
	mflops, flops, a, b, c: LONGREAL;

BEGIN
		KernelLog.Ln; KernelLog.String('FFTW library Testfftw2d:'); KernelLog.Ln; 

		
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
						val :=  Math.cos(2.0*Math.pi*2.0*i/N);
						x[j, 2*i] := val*val; 
						x[j, 2*i+1]:=0.0 
				END;		
			END; 

		(*	j := dll.init_threads();
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
		(*	dll.cleanup_threads; *)
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

BEGIN
			Streams.OpenWriter(wr,KernelLog.Send);
END FFTWTest.

SystemTools.Free  FFTWTest FFTW ~

FFTWTest.TestfftwExecuteDft1d
256 20 

11 100
16 100
19 100
512 20 
1024 20
2048 20
4096 20 ~

FFTWTest.TestfftwExecuteComplexDft1d
256 20 

11 100
16 100
19 100
512 20 
1024 20
2048 20
4096 20 ~

16384 20 ~


FFTWTest.Testfftw1d
256 1 

11 100
16 100
19 100
512 20 
1024 20
2048 20
4096 20


256 20 
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

[M N nRetry]

FFTWTest.Testfftw2d
19 19 1
256 256 1
~ 
1024 1024 4
1600 1200 5 ~ 
1600 1199 5
4048 4048 2
~



(* ***********

LinuxAos:
FFTW library TestfftwExecuteDft1d:
N=256, nRetry=20, time per {FFT,IFFT}=  0.500 ms (  40.960 MFLOPS) (  13760 flops), restit. err. (L2)=  0.0000000000000030
N=11, nRetry=100, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  480 flops), restit. err. (L2)=  0.0000000000000002
N=16, nRetry=100, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  336 flops), restit. err. (L2)=  0.0000000000000001
N=19, nRetry=100, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  1476 flops), restit. err. (L2)=  0.0000000000000009
N=512, nRetry=20, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  30400 flops), restit. err. (L2)=  0.0000000000000087
N=1024, nRetry=20, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  40592 flops), restit. err. (L2)=  0.0000000000000122
N=2048, nRetry=20, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  90688 flops), restit. err. (L2)=  0.0000000000000175
N=4096, nRetry=20, time per {FFT,IFFT}=  0.500 ms (  983.040 MFLOPS) (  197504 flops), restit. err. (L2)=  0.0000000000000320
Done!

FFTW library TestfftwExecuteComplexDft1d:
N=256, nRetry=20, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  13760 flops), restit. err. (L2)=  0.0000000000000030
N=11, nRetry=100, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  480 flops), restit. err. (L2)=  0.0000000000000002
N=16, nRetry=100, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  336 flops), restit. err. (L2)=  0.0000000000000001
N=19, nRetry=100, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  1476 flops), restit. err. (L2)=  0.0000000000000009
N=512, nRetry=20, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  30400 flops), restit. err. (L2)=  0.0000000000000087
N=1024, nRetry=20, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  40592 flops), restit. err. (L2)=  0.0000000000000122
N=2048, nRetry=20, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  90688 flops), restit. err. (L2)=  0.0000000000000175
N=4096, nRetry=20, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  197504 flops), restit. err. (L2)=  0.0000000000000320
Done!

FFTW library Testfftw1d:
N=256, nRetry=1, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  13760 flops), restit. err. (L2)=  0.0000000000000012
N=11, nRetry=100, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  480 flops), restit. err. (L2)=  0.0000000000000002
N=16, nRetry=100, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  336 flops), restit. err. (L2)=  0.0000000000000001
N=19, nRetry=100, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  1476 flops), restit. err. (L2)=  0.0000000000000009
N=512, nRetry=20, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  30400 flops), restit. err. (L2)=  0.0000000000000087
N=1024, nRetry=20, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  40592 flops), restit. err. (L2)=  0.0000000000000122
N=2048, nRetry=20, time per {FFT,IFFT}=  0.000 ms (      INF MFLOPS) (  90688 flops), restit. err. (L2)=  0.0000000000000175
N=4096, nRetry=20, time per {FFT,IFFT}=  0.500 ms (  983.040 MFLOPS) (  197504 flops), restit. err. (L2)=  0.0000000000000320
Done!
/opt/fftw3/libfftw3.so unloaded.
*******************)
