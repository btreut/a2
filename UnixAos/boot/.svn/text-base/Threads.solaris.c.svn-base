
/*--------- threads support ------------------------- g.f. -----*/
/*--------- lower half of the Oberon Threads module             */

#include <stdio.h>
#include <stdlib.h>
#include <limits.h>
#include "Threads.h"
#define __EXTENSIONS__  1
#include <pthread.h>
#include <synch.h>
#include <sched.h>

extern int suid_root;
static o_thr_t mainthread = 0;

extern void SetSigaltstack();

o_mtx_t o_mtxInit(int dummy) {
    o_mtx_t mtx;

    mtx = (o_mtx_t)malloc( sizeof(mutex_t) );
    mutex_init( mtx, USYNC_THREAD, NULL );
    return mtx;
}

void o_mtxDestroy(o_mtx_t mtx) {
    mutex_destroy( mtx );
    free( mtx );
}


void o_mtxLock(o_mtx_t mtx) {
    mutex_lock( mtx );
}


void o_mtxUnlock(o_mtx_t mtx) {
    mutex_unlock( mtx );
}

o_con_t o_conInit(int dummy) {
    o_con_t	c;

    c = (o_con_t)malloc( sizeof(cond_t) );
    cond_init( c, USYNC_THREAD, NULL );
    return c;
}

void o_conDestroy(o_con_t c) {
    cond_destroy( c );
    free( c );
}

void o_conWait( o_con_t c, o_mtx_t m ) {
    cond_wait( c, m );
}

void o_conSignal( o_con_t c ) {
   cond_signal( c );
}

void* starter( void* p ) {
    sigset_t orig, new;
    oberon_proc body = (oberon_proc)p;

    SetSigaltstack();
    sigfillset( &new );
    sigdelset( &new, SIGILL );
    sigdelset( &new, SIGTRAP );
    sigdelset( &new, SIGEMT );
    sigdelset( &new, SIGFPE );
    sigdelset( &new, SIGBUS );
    sigdelset( &new, SIGSEGV );
    sigdelset( &new, SIGSYS );
    sigdelset( &new, SIGPIPE );
    sigdelset( &new, SIGALRM );
    thr_sigsetmask( SIG_SETMASK, &new, &orig );
    pthread_setcancelstate( PTHREAD_CANCEL_ENABLE, NULL );
    pthread_setcanceltype( PTHREAD_CANCEL_ASYNCHRONOUS, NULL );
    body();
    thr_exit( 0 );
}


o_thr_t o_thrStart( oberon_proc p, int len ) {
    o_thr_t id;
    int	err;

    if ((len != 0) && (len < 16*1024)) {
        len =  16*1024;
    }

    err = thr_create( NULL, len, starter, p, THR_BOUND|THR_DETACHED, &id );
    if (err != 0)
        return 0;
    return id;
}


o_thr_t o_thrThis(int dummy) {
    return thr_self();
}


void o_thrSleep(int ms) {
    struct timespec sltime, rem;

    sltime.tv_sec = ms/1000;
    sltime.tv_nsec = 1000000*(ms%1000);
    nanosleep( &sltime, &rem );
}


void o_thrYield(int dummy) {
    thr_yield( );
}

void o_thrExit(int dummy) {
    thr_exit( 0 );
}


void o_thrSuspend(o_thr_t thr) {
    thr_suspend( thr );
}

void o_thrResume(o_thr_t thr) {
    thr_continue( thr );
}


void o_thrSetprio(o_thr_t thr, int prio) {
    thr_setprio( thr, prio );
}

int o_thrGetprio(o_thr_t thr) {
    int prio;

    thr_getprio( thr, &prio );
    return ( prio );
}


void o_thrKill(o_thr_t thr) {
    if (thr != mainthread) {
        if (thr == thr_self())
            thr_exit( 0 );
        else 
	    pthread_cancel( thr );
    }
}


/* thr_initialize returns 0 (FALSE) if the program has
   been compiled without threads suport. If the program
   has no suid root privilleges, priorities are disabled
   and low and high both return 0. */

int o_thrInitialize( int *low, int* high ) {
    int pl, ph, ret;
    struct sched_param p;
    pid_t pid;

    pid = getpid();
    sched_getparam( pid, &p );
    ret = sched_setscheduler( pid, SCHED_OTHER, &p );
    /*
    pl = sched_get_priority_min( SCHED_OTHER );
    ph = sched_get_priority_max( SCHED_OTHER );
    */
    mainthread = thr_self();
    *low = 0;  *high = 100;
    return 1;
}

