MODULE FFTWf; (** AUTHOR "fnecati"; PURPOSE "Single precision wrapper for FFTW library"; *)

IMPORT SYSTEM, Kernel32, Modules, KernelLog;

(*! For single precision REAL  type:
	real: 4 bytes, complex: 8 bytes *)
(*
   complex array represented as (r0,i0) (r1,i1) (r2,i2) ... (rn-1, in-1) in arrays,
   complex matrix as rows of complex array.
 *)

VAR
	dll: Kernel32.HMODULE;

CONST
	 dllname="libfftw3f-3.dll"; (* 32 bit single precision library name *)	
	
TYPE 
	Plan* = ADDRESS; (* FFTW planner flag*)

(* fft direction *)
TYPE Direction* = LONGINT;
CONST
	FORWARD* = -1;
	BACKWARD* = 1;

(* documented planner flags, { 0..21} bits *)
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
	
(* undocumented beyond-guru flags *)
	ESTIMATE_PATIENT* = 128;
	BELIEVE_PCOST* =  256;
	NO_DFT_R2HC* =  512;
	NO_NONTHREADED* = 1024;
	NO_BUFFERING* = 2048;
	NO_INDIRECT_OP* =  4096;
	ALLOW_LARGE_GENERIC* =  8192; (* NO_LARGE_GENERIC is default *)
	NO_RANK_SPLITS* =  16384;
	NO_VRANK_SPLITS* = 32768;
	NO_VRECURSE* =  65536;
	NO_SIMD* = 131072;
	NO_SLOW* =  262144;
	NO_FIXED_RADIX_LARGE_N* =  524288;
	ALLOW_PRUNING* =  1048576;
	WISDOM_ONLY* =  2097152;


(* 
	fftw_r2r_kind_do_not_use_me 
*)
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

(*  fftw_iodim_do_not_use_me *)	
TYPE 
	Iodim* = RECORD
		n* , inps* , outs* : LONGINT;
	END;
	
VAR 

	malloc- : PROCEDURE {WINAPI}   (length: LONGINT): LONGINT;
	free- : PROCEDURE  {WINAPI} (mem: LONGINT);
	destroy_plan- : PROCEDURE {WINAPI} (plan: Plan);
	cleanup- : PROCEDURE {WINAPI} ;
	set_timelimit-: PROCEDURE {WINAPI} (seconds: LONGREAL);
	
	execute-: PROCEDURE {WINAPI}  (plan: Plan);

	(* new-array execute functions *)
	execute_dft-: PROCEDURE {WINAPI} (plan: Plan; input: ADDRESS; output: ADDRESS );  
	execute_split_dft-: PROCEDURE {WINAPI} (plan: Plan; realin, imagin: ADDRESS; realout, imagout : ADDRESS );  
	execute_dft_r2c-: PROCEDURE {WINAPI} (plan: Plan; inputfloat: ADDRESS; outputcomplex: ADDRESS ); 
	execute_split_dft_r2c-: PROCEDURE {WINAPI} (plan: Plan; inputfloat: ADDRESS; realout, imagout: ADDRESS ); 
	execute_dft_c2r-: PROCEDURE {WINAPI} (plan: Plan; inputcomplex: ADDRESS; outputfloat: ADDRESS ); 
	execute_split_dft_c2r-: PROCEDURE {WINAPI} (plan: Plan; realin, imagin: ADDRESS; floatout: ADDRESS );        
	execute_r2r-: PROCEDURE {WINAPI} (plan: Plan; inputfloat: ADDRESS; outputfloat: ADDRESS ); 

	plan_dft_1d- :  PROCEDURE  {WINAPI} (n: LONGINT; input: ADDRESS; output: ADDRESS; direction: Direction; flags: Flags): Plan;
	plan_dft_2d-: PROCEDURE {WINAPI}  (nx, ny: LONGINT; input, output: ADDRESS; direction: Direction; flags: Flags): Plan;
	plan_dft_3d-: PROCEDURE {WINAPI}  (nx, ny, nz: LONGINT; input, output: ADDRESS; direction: Direction; flags: Flags): Plan;
	plan_dft-: PROCEDURE {WINAPI}  (rank: LONGINT; n: ADDRESS; input, output: ADDRESS; direction: Direction; flags: LONGINT): Plan;

	plan_dft_r2c_1d-: PROCEDURE {WINAPI}  (n: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_r2c_2d-: PROCEDURE {WINAPI}  (nx, ny: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_r2c_3d-: PROCEDURE {WINAPI}  (nx, ny, nz: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_r2c-: PROCEDURE {WINAPI}  (rank: LONGINT; n: ADDRESS; input, output: ADDRESS; flags: Flags): Plan;

	plan_dft_c2r_1d-: PROCEDURE {WINAPI}  (n: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_c2r_2d-: PROCEDURE {WINAPI}  (nxy, ny: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_c2r_3d-: PROCEDURE {WINAPI} (nx, ny, nz: LONGINT; input, output: ADDRESS; flags: Flags): Plan;
	plan_dft_c2r-: PROCEDURE {WINAPI}  (rank: LONGINT; n: ADDRESS; input, output: ADDRESS; flags: Flags): Plan;

	plan_r2r_1d-: PROCEDURE {WINAPI}  (n: LONGINT; input, output: ADDRESS; kind: Kind; flags: Flags): Plan;
	plan_r2r_2d-: PROCEDURE {WINAPI}  (nx, ny: LONGINT; input, output: ADDRESS; kindx, kindy: Kind; flags: Flags): Plan;
	plan_r2r_3d-: PROCEDURE {WINAPI}  (nx, ny, nz: LONGINT; input, output: ADDRESS; kindx, kindy, kindz: Kind; flags: Flags): Plan;
	plan_r2r-: PROCEDURE {WINAPI} (rank: LONGINT; n: ADDRESS; input, output: ADDRESS; kind: ADDRESS; flags: Flags): Plan;

	(* plans for many dfts *)	
	plan_many_dft- : PROCEDURE {WINAPI} (rank: LONGINT; n: ADDRESS; howmany: LONGINT; input: ADDRESS; inembed: LONGINT; istride: LONGINT; idist: LONGINT;	
                         output: ADDRESS; onembed: LONGINT; ostride: LONGINT; odist: LONGINT; sign: Direction; flags: Flags): Plan;

	plan_many_dft_r2c- : PROCEDURE {WINAPI} (rank: LONGINT; n: ADDRESS; howmany: LONGINT; Rin: ADDRESS; inembed: LONGINT;  istride: LONGINT; idist: LONGINT;
                             Cout : ADDRESS; onembed: LONGINT; ostride: LONGINT;  odist: LONGINT; flags: Flags): Plan;
 
    	plan_many_dft_c2r- : PROCEDURE {WINAPI} (rank: LONGINT; n: ADDRESS; howmany: LONGINT; Cin: ADDRESS; inembed: LONGINT;  istride: LONGINT; idist: LONGINT;
                             Rout : ADDRESS; onembed: LONGINT; ostride: LONGINT;  odist: LONGINT; flags: Flags): Plan;
   
       (* Guru fftw*)
	plan_guru_dft- : PROCEDURE {WINAPI} (rank: LONGINT;  dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS; in, out: ADDRESS;  sign: Direction; flags: Flags): Plan;
	plan_guru_split_dft- : PROCEDURE {WINAPI} (rank: LONGINT;  dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS; realinput, imaginput: ADDRESS; realout, imagout: ADDRESS; flags: Flags): Plan;

	(*  Guru Real-data DFTs*)
	plan_guru_dft_r2c- : PROCEDURE {WINAPI}(rank: LONGINT; dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS;
						          doublein: ADDRESS; complexout: ADDRESS; flags: Flags): Plan;
     
	plan_guru_split_dft_r2c- : PROCEDURE {WINAPI}(rank: LONGINT; dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS;
						          doublein: ADDRESS; double_ro: ADDRESS; double_io: ADDRESS; flags: Flags): Plan;
     
	plan_guru_dft_c2r- : PROCEDURE {WINAPI}(rank: LONGINT; dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS;
						          complexin: ADDRESS; doubleout: ADDRESS; flags: Flags): Plan;
     
	plan_guru_split_dft_c2r- : PROCEDURE {WINAPI}( rank: LONGINT; dims: ADDRESS; howmany_rank: LONGINT; howmany_dims: ADDRESS;
						          double_ri: ADDRESS; double_ii: ADDRESS; double_out: ADDRESS; flags: Flags): Plan;
  


	(* total flops ~ add+mul + 2*fma or add+mul + fma   if fma (fused multipy  add) suported *)
	flops-: PROCEDURE {WINAPI} (plan: Plan; VAR add, mul, fma: LONGREAL);


	init_threads- : PROCEDURE {WINAPI} (): LONGINT;	
	plan_with_nthreads- : PROCEDURE {WINAPI} (n: LONGINT);
	cleanup_threads- : PROCEDURE {WINAPI} ;
	
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
		RETURN plan_dft_1d(LEN(a,0) DIV 2, adr,adr, dir, ESTIMATE);
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
		RETURN plan_dft_2d(LEN(a,0), LEN(a,1) DIV 2,adr,adr, dir, ESTIMATE);
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
		RETURN plan_dft_3d(LEN(a,0) , LEN(a,1),LEN(a,2) DIV 2, adr,adr, dir, ESTIMATE);
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
		dll := Kernel32.LoadLibrary(dllname);
		ASSERT(dll # 0, 303);
		
		Kernel32.GetProcAddress(dll, "fftwf_malloc", SYSTEM.VAL(ADDRESS, malloc));
		Kernel32.GetProcAddress(dll, "fftwf_free", SYSTEM.VAL(ADDRESS, free ));
		Kernel32.GetProcAddress(dll, "fftwf_destroy_plan", SYSTEM.VAL(ADDRESS, destroy_plan ));				
		Kernel32.GetProcAddress(dll, "fftwf_cleanup", SYSTEM.VAL(ADDRESS, cleanup ));

		Kernel32.GetProcAddress(dll, "fftwf_set_timelimit", SYSTEM.VAL(ADDRESS, set_timelimit ));
		Kernel32.GetProcAddress(dll, "fftwf_execute", SYSTEM.VAL(ADDRESS, execute ));


		Kernel32.GetProcAddress(dll, "fftwf_execute_dft", SYSTEM.VAL(ADDRESS, execute_dft ));
		Kernel32.GetProcAddress(dll, "fftwf_execute_split_dft", SYSTEM.VAL(ADDRESS, execute_split_dft ));
		Kernel32.GetProcAddress(dll, "fftwf_execute_dft_r2c", SYSTEM.VAL(ADDRESS, execute_dft_r2c ));
		Kernel32.GetProcAddress(dll, "fftwf_execute_split_dft_r2c", SYSTEM.VAL(ADDRESS, execute_split_dft_r2c ));
		Kernel32.GetProcAddress(dll, "fftwf_execute_dft_c2r", SYSTEM.VAL(ADDRESS, execute_dft_c2r ));
		Kernel32.GetProcAddress(dll, "fftwf_execute_split_dft_c2r", SYSTEM.VAL(ADDRESS, execute_split_dft_c2r ));
		Kernel32.GetProcAddress(dll, "fftwf_execute_r2r", SYSTEM.VAL(ADDRESS, execute_r2r ));

		Kernel32.GetProcAddress(dll, "fftwf_plan_dft_1d", SYSTEM.VAL(ADDRESS, plan_dft_1d ));				
		Kernel32.GetProcAddress(dll, "fftwf_plan_dft_2d", SYSTEM.VAL(ADDRESS, plan_dft_2d ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_dft_3d", SYSTEM.VAL(ADDRESS, plan_dft_3d ));				
		Kernel32.GetProcAddress(dll, "fftwf_plan_dft", SYSTEM.VAL(ADDRESS, plan_dft ));

		Kernel32.GetProcAddress(dll, "fftwf_plan_dft_r2c_1d", SYSTEM.VAL(ADDRESS, plan_dft_r2c_1d ));				
		Kernel32.GetProcAddress(dll, "fftwf_plan_dft_r2c_2d", SYSTEM.VAL(ADDRESS, plan_dft_r2c_2d ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_dft_r2c_3d", SYSTEM.VAL(ADDRESS, plan_dft_r2c_3d ));				
		Kernel32.GetProcAddress(dll, "fftwf_plan_dft_r2c", SYSTEM.VAL(ADDRESS, plan_dft_r2c ));

		Kernel32.GetProcAddress(dll, "fftwf_plan_dft_c2r_1d", SYSTEM.VAL(ADDRESS,  plan_dft_c2r_1d ));				
		Kernel32.GetProcAddress(dll, "fftwf_plan_dft_c2r_2d", SYSTEM.VAL(ADDRESS, plan_dft_c2r_2d ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_dft_c2r_3d", SYSTEM.VAL(ADDRESS, plan_dft_c2r_3d ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_dft_c2r", SYSTEM.VAL(ADDRESS, plan_dft_c2r ));

		Kernel32.GetProcAddress(dll, "fftwf_plan_r2r_1d", SYSTEM.VAL(ADDRESS, plan_r2r_1d ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_r2r_2d", SYSTEM.VAL(ADDRESS, plan_r2r_2d ));	
		Kernel32.GetProcAddress(dll, "fftwf_plan_r2r_3d", SYSTEM.VAL(ADDRESS, plan_r2r_3d ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_r2r", SYSTEM.VAL(ADDRESS, plan_r2r ));

		Kernel32.GetProcAddress(dll, "fftwf_plan_many_dft", SYSTEM.VAL(ADDRESS, plan_many_dft ));	
		Kernel32.GetProcAddress(dll, "fftwf_plan_many_dft_r2c", SYSTEM.VAL(ADDRESS, plan_many_dft_r2c ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_many_dft_c2r", SYSTEM.VAL(ADDRESS, plan_many_dft_c2r ));

		Kernel32.GetProcAddress(dll, "fftwf_plan_guru_dft", SYSTEM.VAL(ADDRESS, plan_guru_dft ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_guru_split_dft", SYSTEM.VAL(ADDRESS, plan_guru_dft ));

		Kernel32.GetProcAddress(dll, "fftwf_plan_guru_dft_r2c", SYSTEM.VAL(ADDRESS, plan_guru_dft_r2c ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_guru_split_dft_r2c", SYSTEM.VAL(ADDRESS, plan_guru_split_dft_r2c ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_guru_dft_c2r", SYSTEM.VAL(ADDRESS, plan_guru_dft_c2r ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_guru_split_dft_c2r", SYSTEM.VAL(ADDRESS, plan_guru_split_dft_c2r ));

		Kernel32.GetProcAddress(dll, "fftwf_flops", SYSTEM.VAL(ADDRESS, flops ));				

		Kernel32.GetProcAddress(dll, "fftwf_init_threads", SYSTEM.VAL(ADDRESS, init_threads ));
		Kernel32.GetProcAddress(dll, "fftwf_plan_with_nthreads", SYSTEM.VAL(ADDRESS, plan_with_nthreads ));
		Kernel32.GetProcAddress(dll, "fftwf_cleanup_threads", SYSTEM.VAL(ADDRESS, cleanup_threads ));
						
	 KernelLog.String(dllname); KernelLog.String(" library loaded"); KernelLog.Ln;
	END Init;

    PROCEDURE OnClose;
     VAR res: LONGINT;
    BEGIN 
   	 IF dll # Kernel32.NULL THEN
   	 	cleanup;
   	 	res := Kernel32.FreeLibrary(dll);
	 	KernelLog.String(dllname); KernelLog.String(" library unloaded.."); KernelLog.Ln;
  	END;	 
    END OnClose;

BEGIN
	Init;
	Modules.InstallTermHandler(OnClose)  
END FFTWf.

