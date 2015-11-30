MODULE FFTWf; (** AUTHOR "fnecati"; PURPOSE "single precision wrapper for FFTW library"; *)
IMPORT Unix, Modules, KernelLog;

(*! For double precision REAL  type:
	real: 8 bytes, complex: 16 bytes *)
	
(*
   complex array represented as (r0,i (r1,i1) (r2,i2) ... (rn-1, in-1) in arrays,
   complex matrix as rows of complex array.
 *)
 
 
CONST
	(* set to 32 bit fftw3 library name *)
	libfftwname = "libfftw3f.so";
(*	libfftwname = "/opt/fftw3/libfftw3f.so"; *)
VAR
	dll: LONGINT; (* handle to fftw library *)
	
TYPE 
	Plan* = ADDRESS; (* FFTW planner flag*)
 
 (* fft direction *)
TYPE Direction* = LONGINT;
CONST
	FORWARD* = -1;
	BACKWARD* = 1;

(* planner flag *)
TYPE Flags* = LONGINT;
CONST
	MEASURE* = 0;
	DESTROY_INPUT* = 1; 
	UNALIGNED* = 2; 
	CONSERVE_MEMORY* = 4; 
	EXHAUSTIVE* = 8; 
	PRESERVE_INPUT* = 16; 
	PATIENT* = 32; 
	ESTIMATE* = 64; 

(* kinds of real-to-real transforms *)
TYPE Kind* = LONGINT;
CONST
	R2HC* = 0;
	HC2R* = 1;
	DHT* = 2;
	REDFT00* = 3;
	REDFT01* = 4;
	REDFT10* = 5;
	REDFT11* = 6;
	RODFT00* = 7;
	RODFT01* = 8;
	RODFT10* = 9;
	RODFT11* = 10;

TYPE Iodim* = RECORD
         n* , inps* , outs* : LONGINT;
	END;
	
VAR 

	malloc- : PROCEDURE {C}   (length: LONGINT): LONGINT;
	free- : PROCEDURE  {C} (mem: LONGINT);
	destroy_plan- : PROCEDURE {C} (plan: Plan);
	cleanup- : PROCEDURE {C} ;
	set_timelimit-: PROCEDURE {C} (seconds: LONGREAL);

	execute-: PROCEDURE {C}  (plan: Plan);
	
	(* new-array execute functions *)
	execute_dft-: PROCEDURE {C} (plan: Plan; input: ADDRESS; output: ADDRESS );  
	execute_split_dft-: PROCEDURE {C} (plan: Plan; realin, imagin: ADDRESS; realout, imagout : ADDRESS );  
	execute_dft_r2c-: PROCEDURE {C} (plan: Plan; inputfloat: ADDRESS; outputcomplex: ADDRESS ); 
	execute_split_dft_r2c-: PROCEDURE {C} (plan: Plan; inputfloat: ADDRESS; realout, imagout: ADDRESS ); 
	execute_dft_c2r-: PROCEDURE {C} (plan: Plan; inputcomplex: ADDRESS; outputfloat: ADDRESS ); 
	execute_split_dft_c2r-: PROCEDURE {C} (plan: Plan; realin, imagin: ADDRESS; floatout: ADDRESS );        
	execute_r2r-: PROCEDURE {C} (plan: Plan; inputfloat: ADDRESS; outputfloat: ADDRESS ); 
        
	plan_dft_1d- :  PROCEDURE  {C} (n: LONGINT; input: ADDRESS; output: ADDRESS; direction: Direction; flags: Flags): Plan;
	plan_dft_2d-: PROCEDURE {C}  (ny, nx: LONGINT; input, output: ADDRESS; direction: Direction; flags: Flags): Plan;
	plan_dft_3d-: PROCEDURE {C}  (nz, ny, nx: LONGINT; input, output: ADDRESS; direction: Direction; flags: Flags): Plan;
	plan_dft-: PROCEDURE {C}  (rank: LONGINT; n: ADDRESS; input, output: ADDRESS; direction: Direction; flags: LONGINT): Plan;

	plan_dft_r2c_1d-: PROCEDURE {C}  (n: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_r2c_2d-: PROCEDURE {C}  (ny, nx: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_r2c_3d-: PROCEDURE {C}  (nz, ny, nx: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_r2c-: PROCEDURE {C}  (rank: LONGINT; n: ADDRESS; input, output: ADDRESS; flags: Flags): Plan;

	plan_dft_c2r_1d-: PROCEDURE {C}  (n: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_c2r_2d-: PROCEDURE {C}  (ny, nx: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_c2r_3d-: PROCEDURE {C} (nz, ny, nx: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_c2r-: PROCEDURE {C}  (rank: LONGINT; n: ADDRESS; input, output: ADDRESS; flags: Flags): Plan;

	plan_r2r_1d-: PROCEDURE {C}  (n: LONGINT; input, output: ADDRESS; kind: Kind; flags: Flags): Plan;
	plan_r2r_2d-: PROCEDURE {C}  (ny, nx: LONGINT; input, output: ADDRESS; kindx, kindy: Kind; flags: Flags): Plan;
	plan_r2r_3d-: PROCEDURE {C}  (nz, ny, nx: LONGINT; input, output: ADDRESS; kindx, kindy, kindz: Kind; flags: Flags): Plan;
	plan_r2r-: PROCEDURE {C} (rank: LONGINT; n: ADDRESS; input, output: ADDRESS; kind: ADDRESS; flags: Flags): Plan;

	(* plans for many dfts *)
	
	plan_many_dft- : PROCEDURE {C} (rank: LONGINT; n: ADDRESS; howmany: LONGINT; input: ADDRESS; inembed: LONGINT; istride: LONGINT; idist: LONGINT;	
                         output: ADDRESS; onembed: LONGINT; ostride: LONGINT; odist: LONGINT; sign: Direction; flags: Flags): Plan;


	plan_many_dft_r2c- : PROCEDURE {C} (rank: LONGINT; n: ADDRESS; howmany: LONGINT; Rin: ADDRESS; inembed: LONGINT;  istride: LONGINT; idist: LONGINT;
                             Cout : ADDRESS; onembed: LONGINT; ostride: LONGINT;  odist: LONGINT; flags: Flags): Plan;
   
   	plan_many_dft_c2r- : PROCEDURE {C} (rank: LONGINT; n: ADDRESS; howmany: LONGINT; Cin: ADDRESS; inembed: LONGINT;  istride: LONGINT; idist: LONGINT;
                             Rout : ADDRESS; onembed: LONGINT; ostride: LONGINT;  odist: LONGINT; flags: Flags): Plan;
 
       (* Guru fftw*)
      plan_guru_dft- : PROCEDURE {C} (rank: LONGINT;  dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS; in, out: ADDRESS;  sign: Direction; flags: Flags): Plan;
	plan_guru_split_dft- : PROCEDURE {C} (rank: LONGINT;  dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS; realinput, imaginput: ADDRESS; realout, imagout: ADDRESS; flags: Flags): Plan;
 
 
	(*  Guru Real-data DFTs*)
	plan_guru_dft_r2c- : PROCEDURE {C}(rank: LONGINT; dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS;
						          doublein: ADDRESS; complexout: ADDRESS; flags: Flags): Plan;
     
	plan_guru_split_dft_r2c- : PROCEDURE {C}(rank: LONGINT; dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS;
						          doublein: ADDRESS; double_ro: ADDRESS; double_io: ADDRESS; flags: Flags): Plan;
     
	plan_guru_dft_c2r- : PROCEDURE {C}(rank: LONGINT; dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS;
						          complexin: ADDRESS; doubleout: ADDRESS; flags: Flags): Plan;
     
	plan_guru_split_dft_c2r- : PROCEDURE {C}( rank: LONGINT; dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS;
						          double_ri: ADDRESS; double_ii: ADDRESS; double_out: ADDRESS; flags: Flags): Plan;

                        
	(* total flops ~ add+mul + 2*fma or add+mul + fma   if fma (fused multipy  add) suported *)
	flops-: PROCEDURE {C} (plan: Plan; VAR add, mul, fma: LONGREAL);

	(* wrappers for above procedures*)

	PROCEDURE Malloc* (length: LONGINT): ADDRESS;
	BEGIN
		RETURN malloc(length);
	END Malloc;
	
	PROCEDURE Free* (mem: ADDRESS);
	BEGIN
		free(mem);
	END Free;
		
	PROCEDURE Execute*(plan: Plan);
	BEGIN		
		execute(plan);
	END Execute;

	PROCEDURE ExecuteDft1din*(plan: Plan; VAR inout: ARRAY [*] OF REAL);
	VAR adrio: ADDRESS;
	BEGIN
		adrio := ADDRESSOF(inout[0]);		
		execute_dft(plan, adrio, adrio);
	END ExecuteDft1din;

	PROCEDURE ExecuteDft1dinout*(plan: Plan; VAR in, out: ARRAY [*] OF REAL);
	VAR adri, adro: ADDRESS;
	BEGIN
		adri := ADDRESSOF(in[0]); adro := ADDRESSOF(out[0]);		
		execute_dft(plan, adri, adro);
	END ExecuteDft1dinout;

	PROCEDURE ExecuteDftComplex1din*(plan: Plan; VAR inout: ARRAY [*] OF COMPLEX);
	VAR adrio: ADDRESS;
	BEGIN
		adrio := ADDRESSOF(inout[0]); 
		execute_dft(plan, adrio, adrio);
	END ExecuteDftComplex1din;

	PROCEDURE ExecuteDftComplex1dinout*(plan: Plan; VAR in, out: ARRAY [*] OF COMPLEX);
	VAR adri, adro: ADDRESS;
	BEGIN
		adri := ADDRESSOF(in[0]); adro := ADDRESSOF(out[0]);
		execute_dft(plan, adri, adro);
	END ExecuteDftComplex1dinout;
		
	PROCEDURE ExecuteDft2dinout*(plan: Plan; VAR in, out: ARRAY [*,*] OF REAL);
	VAR adri, adro: ADDRESS;
	BEGIN		
		adri := ADDRESSOF(in[0,0]); adro := ADDRESSOF(out[0,0]);
		execute_dft(plan, adri, adro);
	END ExecuteDft2dinout;

	PROCEDURE ExecuteDft2din*(plan: Plan; VAR inout: ARRAY [*,*] OF REAL);
	VAR adrio: ADDRESS;
	BEGIN
		adrio := ADDRESSOF(inout[0,0]);		
		execute_dft(plan, adrio, adrio);
	END ExecuteDft2din;
		
	PROCEDURE DestroyPlan*(plan: Plan);
	BEGIN	
		destroy_plan(plan);
	END DestroyPlan;

	PROCEDURE Cleanup*;
	BEGIN
		cleanup;
	END Cleanup;
	
	PROCEDURE SetTimeLimit*(seconds: LONGREAL);
	BEGIN
		set_timelimit(seconds);
	END SetTimeLimit;
			
	PROCEDURE Flops* (plan: Plan; VAR add, mul, fma: LONGREAL);
	BEGIN
		flops(plan, add,mul, fma);
	END Flops;
			
	(* 1d- in-place Complex transform *)
	PROCEDURE PlanDft1Din*(VAR a : ARRAY [*] OF REAL; dir: LONGINT): Plan;
	VAR adr : ADDRESS;
	BEGIN
		adr := ADDRESSOF(a[0]);		
		RETURN plan_dft_1d(LEN(a,0) DIV 2, adr,adr, dir,ESTIMATE);
	END PlanDft1Din;

	(* 1d- in-place Complex transform *)
	PROCEDURE PlanDftComplex1Din*(VAR a : ARRAY [*] OF COMPLEX; dir: LONGINT): Plan;
	VAR adr : ADDRESS;
	BEGIN
		adr := ADDRESSOF(a[0]);
		RETURN plan_dft_1d(LEN(a,0), adr,adr, dir,ESTIMATE);
	END PlanDftComplex1Din;
		
	(* 2d- in-place Complex transform *)
	PROCEDURE PlanDft2Din*(VAR a : ARRAY [*,*] OF REAL; dir: LONGINT): Plan;
	VAR adr: ADDRESS;
	BEGIN
		adr := ADDRESSOF(a[0,0]);
		RETURN plan_dft_2d(LEN(a,0), LEN(a,1) DIV 2,adr,adr, dir,ESTIMATE);
	END PlanDft2Din;

	(* 2d- in-place Complex transform *)
	PROCEDURE PlanDftComplex2Din*(VAR a : ARRAY [*,*] OF COMPLEX; dir: LONGINT): Plan;
	VAR adr: ADDRESS;
	BEGIN
		adr := ADDRESSOF(a[0,0]);
		RETURN plan_dft_2d(LEN(a,0), LEN(a,1),adr,adr, dir,ESTIMATE);
	END PlanDftComplex2Din;

	(* 3d- in-place Complex transform *)
	PROCEDURE PlanDft3Din*(VAR a : ARRAY [*,*,*] OF REAL; dir: LONGINT): Plan;
	VAR adr: ADDRESS;
	BEGIN
		adr := ADDRESSOF(a[0,0,0]);		
		RETURN plan_dft_3d(LEN(a,0) , LEN(a,1),LEN(a,2) DIV 2, adr,adr, dir,ESTIMATE);
	END PlanDft3Din;	
	
	(* 1d- out of place Complex transform *)
	PROCEDURE PlanDft1Dinout*(VAR a, b : ARRAY [*] OF REAL; dir: LONGINT): Plan;
	VAR adr, adr1: ADDRESS;
	BEGIN
		ASSERT(LEN(a) = LEN(b));
		adr := ADDRESSOF(a[0]);
		adr1 := ADDRESSOF(b[0]);		
		RETURN plan_dft_1d(LEN(a,0) DIV 2, adr,adr1, dir,ESTIMATE);
	END PlanDft1Dinout;

	(* 1d- out of place Complex transform *)
	PROCEDURE PlanDftComplex1Dinout*(VAR a, b : ARRAY [*] OF COMPLEX; dir: LONGINT): Plan;
	VAR adr, adr1: ADDRESS;
	BEGIN
		ASSERT(LEN(a) = LEN(b));
		adr := ADDRESSOF(a[0]);
		adr1 := ADDRESSOF(b[0]);		
		RETURN plan_dft_1d(LEN(a,0), adr,adr1, dir,ESTIMATE);
	END PlanDftComplex1Dinout;
		
	(* 2d- out of place Complex transform *)
	PROCEDURE PlanDft2Dinout*(VAR a, b : ARRAY [*,*] OF REAL; dir: LONGINT): Plan;
	VAR adr, adr1: ADDRESS;
	BEGIN
		ASSERT(LEN(a,0) = LEN(b,0));
		ASSERT(LEN(a,1) = LEN(b,1));
		adr := ADDRESSOF(a[0,0]);
		adr1 := ADDRESSOF(b[0,0]);
		RETURN plan_dft_2d(LEN(a,0), LEN(a,1) DIV 2,adr,adr1, dir,ESTIMATE);
	END PlanDft2Dinout;

	(* 3d- out of place Complex transform *)
	PROCEDURE PlanDft3Dinout*(VAR a, b : ARRAY [*,*,*] OF REAL; dir: LONGINT): Plan;
	VAR adr, adr1: ADDRESS;
	BEGIN
		ASSERT(LEN(a,0) = LEN(b,0));
		ASSERT(LEN(a,1) = LEN(b,1));
		ASSERT(LEN(a,2) = LEN(b,2));
		adr := ADDRESSOF(a[0,0,0]);
		adr1 := ADDRESSOF(b[0,0,0]);		
		RETURN plan_dft_3d(LEN(a,0), LEN(a,1),LEN(a,2) DIV 2,adr,adr1, dir,ESTIMATE);
	END PlanDft3Dinout;

PROCEDURE Init;
BEGIN 
		(* load the DLL *)	
		dll := Unix.Dlopen(libfftwname, 2);
		ASSERT(dll # 0, 303);
		
		Unix.Dlsym(dll, "fftwf_malloc", ADDRESSOF( malloc));
		Unix.Dlsym(dll, "fftwf_free", ADDRESSOF( free ));
		Unix.Dlsym(dll, "fftwf_destroy_plan", ADDRESSOF( destroy_plan ));				
		Unix.Dlsym(dll, "fftwf_cleanup", ADDRESSOF( cleanup ));


		Unix.Dlsym(dll, "fftwf_execute", ADDRESSOF( execute ));

		Unix.Dlsym(dll, "fftwf_execute_dft", ADDRESSOF( execute_dft ));
		Unix.Dlsym(dll, "fftwf_execute_split_dft", ADDRESSOF( execute_split_dft ));
		Unix.Dlsym(dll, "fftwf_execute_dft_r2c", ADDRESSOF( execute_dft_r2c ));
		Unix.Dlsym(dll, "fftwf_execute_split_dft_r2c", ADDRESSOF( execute_split_dft_r2c ));
		Unix.Dlsym(dll, "fftwf_execute_dft_c2r", ADDRESSOF( execute_dft_c2r ));
		Unix.Dlsym(dll, "fftwf_execute_split_dft_c2r", ADDRESSOF( execute_split_dft_c2r ));
		Unix.Dlsym(dll, "fftwf_execute_r2r", ADDRESSOF( execute_r2r ));

		Unix.Dlsym(dll, "fftwf_plan_dft_1d", ADDRESSOF( plan_dft_1d ));				
		Unix.Dlsym(dll, "fftwf_plan_dft_2d", ADDRESSOF( plan_dft_2d ));
		Unix.Dlsym(dll, "fftwf_plan_dft_3d", ADDRESSOF( plan_dft_3d ));				
		Unix.Dlsym(dll, "fftwf_plan_dft", ADDRESSOF( plan_dft ));

		Unix.Dlsym(dll, "fftwf_plan_dft_r2c_1d", ADDRESSOF( plan_dft_r2c_1d ));				
		Unix.Dlsym(dll, "fftwf_plan_dft_r2c_2d", ADDRESSOF( plan_dft_r2c_2d ));
		Unix.Dlsym(dll, "fftwf_plan_dft_r2c_3d", ADDRESSOF( plan_dft_r2c_3d ));				
		Unix.Dlsym(dll, "fftwf_plan_dft_r2c", ADDRESSOF( plan_dft_r2c ));

		Unix.Dlsym(dll, "fftwf_plan_dft_c2r_1d", ADDRESSOF(  plan_dft_c2r_1d ));				
		Unix.Dlsym(dll, "fftwf_plan_dft_c2r_2d", ADDRESSOF( plan_dft_c2r_2d ));
		Unix.Dlsym(dll, "fftwf_plan_dft_c2r_3d", ADDRESSOF( plan_dft_c2r_3d ));
		Unix.Dlsym(dll, "fftwf_plan_dft_c2r", ADDRESSOF( plan_dft_c2r ));

		Unix.Dlsym(dll, "fftwf_plan_r2r_1d", ADDRESSOF( plan_r2r_1d ));
		Unix.Dlsym(dll, "fftwf_plan_r2r_2d", ADDRESSOF( plan_r2r_2d ));	
		Unix.Dlsym(dll, "fftwf_plan_r2r_3d", ADDRESSOF( plan_r2r_3d ));
		Unix.Dlsym(dll, "fftwf_plan_r2r", ADDRESSOF( plan_r2r ));


		Unix.Dlsym(dll, "fftwf_plan_many_dft", ADDRESSOF( plan_many_dft ));
		Unix.Dlsym(dll, "fftwf_plan_many_dft_r2c", ADDRESSOF( plan_many_dft_r2c ));
		Unix.Dlsym(dll, "fftwf_plan_many_dft_c2r", ADDRESSOF( plan_many_dft_c2r ));
		
		Unix.Dlsym(dll, "fftwf_plan_guru_dft", ADDRESSOF( plan_guru_dft ));
		Unix.Dlsym(dll, "fftwf_plan_guru_split_dft", ADDRESSOF( plan_guru_dft ));

		Unix.Dlsym(dll, "fftwf_plan_guru_dft_r2c", ADDRESSOF( plan_guru_dft_r2c ));
		Unix.Dlsym(dll, "fftwf_plan_guru_split_dft_r2c", ADDRESSOF( plan_guru_split_dft_r2c ));
		Unix.Dlsym(dll, "fftwf_plan_guru_dft_c2r", ADDRESSOF( plan_guru_dft_c2r ));
		Unix.Dlsym(dll, "fftwf_plan_guru_split_dft_c2r", ADDRESSOF( plan_guru_split_dft_c2r ));

		
		Unix.Dlsym(dll, "fftwf_flops", ADDRESSOF( flops ));
		
		KernelLog.String(libfftwname); KernelLog.String(" loaded.");  KernelLog.Ln; 
END Init;

PROCEDURE OnClose;
BEGIN 
	IF dll # 0 THEN
		cleanup;
		Unix.Dlclose(dll);
		KernelLog.String(libfftwname); KernelLog.String(" unloaded."); KernelLog.Ln; 
	END;
END OnClose;

BEGIN
	Init;
	Modules.InstallTermHandler(OnClose)  
END FFTWf.

