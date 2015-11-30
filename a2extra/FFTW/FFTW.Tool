FFTW Library for WinAos and LinuxAos 

Uses fftw3 series libraries.

Compile for:

# UnixAos: 
	Compiler.Compile  Unix.FFTW.Mod Unix.FFTWf.Mod ~ 

# WinAos: 
	Compiler.Compile  Win32.FFTW.Mod Win32.FFTWf.Mod  ~

# compile test modules
Compiler.Compile FFTWTest.Mod FFTWTestf.Mod~ 

# free from memory
SystemTools.Free FFTWTest FFTWTestf.Mod FFTW FFTWf ~

 
Note: Depending on data type REAL, COMPLEX, LONGREAL or LONGCOMPLEX, 
import corresponding modules FFTWf or FFTW and use corresponding plan creation:

ARRAY [*] OF REAL, ARRAY [*] OF COMPLEX, 
ARRAY [*] OF LONGREAL
ARRAY [*] OF LONGCOMPLEX,  types for the below functions.

#-----------------------------------
#-----------------------------------

TYPE Direction = LONGINT;
CONST
	BACKWARD = 1;
	FORWARD = -1;

TYPE 
	Plan = ADDRESS;

	PROCEDURE Cleanup;
	PROCEDURE CleanupThreads;
	PROCEDURE DestroyPlan (plan: Plan);
	PROCEDURE Execute (plan: Plan);
	PROCEDURE Flops (plan: Plan; VAR add, mul, fma: LONGREAL);
	PROCEDURE Free (mem: ADDRESS);
	PROCEDURE InitThreads (): LONGINT;
	PROCEDURE Malloc (length: LONGINT): ADDRESS;
	PROCEDURE PlanDft1Din (VAR Cinput: ARRAY [*] OF REAL; direction: Direction): Plan;
	PROCEDURE PlanDft1Dinout (VAR Cinput, Coutput: ARRAY [*] OF REAL; direction: Direction): Plan;
	PROCEDURE PlanDft2Din (VAR Cinput: ARRAY [*,*] OF REAL; direction: Direction): Plan;
	PROCEDURE PlanDft2Dinout (VAR Cinput, Coutput: ARRAY [*,*] OF REAL; direction: Direction): Plan;
	PROCEDURE PlanDft3Din (VAR Cinput: ARRAY [*,*,*] OF REAL; direction: Direction): Plan;
	PROCEDURE PlanDft3Dinout (VAR Cinput, Coutput: ARRAY [*,*,*] OF REAL; direction: Direction): Plan;
	PROCEDURE PlanWithNthreads (n: LONGINT);
	PROCEDURE SetTimeLimit (seconds: LONGREAL);


Direction:   	  Defines direction of operation
FORWARD        Computes a regular DFT
BACKWARD      Computes the inverse DFT


PROCEDURE Malloc(length:LONGINT) : ADDRESS;
            Allocates FFTW-optimized unmanaged memory
             length: Amount to allocate, in bytes 
            returns:Pointer to allocated memory

PROCEDURE Free(mem: ADDRESS);
            Deallocates memory allocated by FFTW malloc
             mem: Pointer to memory to release 

PROCEDURE DestroyPlan (plan: Plan) ;
            Deallocates an FFTW plan and all associated resources
            plan:  Pointer to the plan to release 

PROCEDURE Cleanup(); 
            Clears all memory used by FFTW, resets it to initial state. Does not replace destroy_plan and free
             
            After calling Cleanup, all existing plans become undefined, and you should not 
            attempt to execute them nor to destroy them. You can however create and execute/destroy new plans, 
            in which case FFTW starts accumulating wisdom information again. 
            Cleanup does not deallocate your plans; you should still call DestroyPlan for this purpose.

PROCEDURE SetTimeLimit (seconds: LONGREAL);
            Sets the maximum time that can be used by the planner.
             seconds: Maximum time, in seconds. 
            This function instructs FFTW to spend at most seconds seconds (approximately) in the planner. 
            If seconds = -1.0 (the default value), then planning time is unbounded. 
            Otherwise, FFTW plans with a progressively wider range of algorithms until the the given time limit is 
            reached or the given range of algorithms is explored, returning the best available plan. For example, 
            specifying Flags.PATIENT first plans in ESTIMATE mode, then in Measure mode, then finally (time 
            permitting) in Patient. If Flags.EXHAUSTIVE is specified instead, the planner will further progress to 
            EXHAUSTIVE mode. 

PROCEDURE Execute (plan: Plan);
            Executes an FFTW plan, provided that the input and output arrays still exist
             plan: Pointer to the plan to execute .
            execute (and equivalents) is the only function in FFTW guaranteed to be thread-safe.

PROCEDURE PlanDft1Din (VAR Cinput: ARRAY [*] OF REAL; direction: Direction): Plan;
            Creates a plan for a 1-dimensional complex-to-complex in-place  DFT
PROCEDURE PlanDft1Dinout (VAR Cinput, Coutput: ARRAY [*] OF REAL; direction: Direction): Plan;
	        Creates a plan for a 1-dimensional complex-to-complex out-of-place  DFT
	
             Cinput, Coutput: an array of complex numbers 
             direction: Specifies the direction of the transform

PROCEDURE PlanDft2Din (VAR Cinput: ARRAY [*,*] OF REAL; direction: Direction): Plan;
            Creates a plan for a 2-dimensional complex-to-complex in-place DFT
PROCEDURE PlanDft2Dinout (VAR Cinput, Coutput: ARRAY [*,*] OF REAL; direction: Direction): Plan;
			Creates a plan for a 2-dimensional complex-to-complex out-of-place DFT
             Cinput, Coutput:  a matrix of  complex numbers 
             direction:  Specifies the direction of the transform 

PROCEDURE PlanDft3Din (VAR Cinput: ARRAY [*,*,*] OF REAL; direction: Direction): Plan;
            Creates a plan for a 3-dimensional complex-to-complex in-place DFT

PROCEDURE PlanDft3Dinout (VAR Cinput, Coutput: ARRAY [*,*,*] OF REAL; direction: Direction): Plan;
            Creates a plan for a 3-dimensional complex-to-complex  out-of-place DFT
             Cinput, Coutput:  cube Matrix complex numbers 
             direction: Specifies the direction of the transform 

         
PROCEDURE Flops (plan: Plan; VAR add, nul, fma: LONGREAL); 
             
            Returns (approximately) the number of flops used by a certain plan     
             plan: The plan to measure 
             add:  number of adds 
             mul:  number of muls 
             fma: number of fmas (fused multiply-add) 
            Total flops ~= add+mul+2*fma or add+mul+fma if fma is supported

Usage of Multi-threaded FFTW

PROCEDURE InitThreads (): LONGINT;
PROCEDURE PlanWithNthreads (nthreads: LONGINT);
PROCEDURE CleanupThreads();

First, programs using the parallel complex transforms should be linked with -lfftw3_
threads -lfftw3 -lm on Unix. You will also need to link with whatever library is respon-
sible for threads on your system (e.g. -lpthread on GNU/Linux).

Second, before calling any FFTW routines, you should call the function:

	InitThreads();

This function, which need only be called once, performs any one-time initialization required
to use threads on your system. It returns zero if there was some error (which should not
happen under normal circumstances) and a non-zero value otherwise.

Third, before creating a plan that you want to parallelize, you should call:

	PlanWithNthreads( nthreads);

The nthreads argument indicates the number of threads you want FFTW to use (or actu-
ally, the maximum number). All plans subsequently created with any planner routine will
use that many threads. You can call PlanWithNthreads, create some plans, call
PlanWithNthreads again with a different argument, and create some more plans for
a new number of threads. Plans already created before a call to PlanWithNthreads
are unaected. If you pass an nthreads argument of 1 (the default), threads are disabled
for subsequent plans.
Given a plan, you then execute it as usual with Execute(plan), and the execution
will use the number of threads specied when the plan was created. When done, you destroy
it as usual with DestroyPlan.

There is one additional routine: if you want to get rid of all memory and other resources
allocated internally by FFTW, you can call:

	CleanupThreads;

which is much like the Cleanup() function except that it also gets rid of threads-
related data. You must not execute any previously created plans after calling this function.



Source:   http://fftw.org/
Win32/64 binaries avalible at: "http://fftw.org/install/windows.html"

(***********************************************************************
 * Copyright (c) 2003, 2006 Matteo Frigo
 * Copyright (c) 2003, 2006 Massachusetts Institute of Technology
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 * 
 ***********************************************************************)
 

