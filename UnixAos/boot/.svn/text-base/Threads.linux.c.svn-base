
/*--------- threads support ------------------------- g.f. -----*/
/*--------- lower half of the Oberon Threads module             */

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <limits.h>
#include <signal.h>
#include <semaphore.h>
#include <errno.h>
#include <bits/local_lim.h>
#include "Threads.h"


extern int suid_root;
extern int debug;

extern void SetSigaltstack();

static o_thr_t mainthread = 0;

static struct sched_param oldparam;
static int oldpolicy;

#define	T_SIGSUSPEND	SIGUSR1
#define	T_SIGRESUME	SIGUSR2

static struct sigaction sasuspend, saresume;
static pthread_mutex_t suspend_mutex;
static int suspend_done;
static int resume_done;


void 
o_thrSleep(int ms) {

    struct timespec sltime, rem;

    sltime.tv_sec = ms/1000;
    sltime.tv_nsec = 1000000*(ms%1000);
    while (nanosleep( &sltime, &rem ) < 0 && errno == EINTR)
    	sltime = rem;
}


o_mtx_t 
o_mtxInit(int dummy) {
    o_mtx_t mtx;

    mtx = (o_mtx_t)malloc( sizeof(pthread_mutex_t) );
    pthread_mutex_init( mtx, NULL );
    return mtx;
}



void 
o_mtxDestroy(o_mtx_t mtx) {
    
    (void)pthread_mutex_destroy( mtx );
    free( mtx );
}



void 
o_mtxLock(o_mtx_t mtx) {
    
    (void)pthread_mutex_lock( mtx );
}



void 
o_mtxUnlock(o_mtx_t mtx) {
    
    (void)pthread_mutex_unlock( mtx );
}


o_con_t 
o_conInit(int dymmy) {
    o_con_t	c;

    c = (o_con_t)malloc( sizeof(pthread_cond_t) );
    pthread_cond_init( c, NULL );
    return c;
}

void 
o_conDestroy(o_con_t c) {
    pthread_cond_destroy( c );
    free( c );
}

void 
o_conWait( o_con_t c, o_mtx_t m ) {
    pthread_cond_wait( c, m );
}

void 
o_conSignal( o_con_t c ) {
    pthread_cond_signal( c );
}


static void *
starter(void *p) {
    o_thr_t me = pthread_self();
    oberon_proc proc = (oberon_proc)p;
    sigset_t old, new;
    struct sched_param param;

    SetSigaltstack();
    sigfillset( &new );
    sigdelset( &new, SIGILL );
    sigdelset( &new, SIGTRAP );
    sigdelset( &new, SIGFPE );
    sigdelset( &new, SIGBUS );
    sigdelset( &new, SIGSEGV );
    sigdelset( &new, SIGTERM );
    sigdelset( &new, T_SIGSUSPEND );
    //sigdelset( &new, T_SIGRESUME );
    pthread_sigmask( SIG_SETMASK, &new, &old );

    pthread_setcancelstate( PTHREAD_CANCEL_ENABLE, NULL );
    pthread_setcanceltype( PTHREAD_CANCEL_ASYNCHRONOUS, NULL );
    param.sched_priority = 0;
    pthread_setschedparam( me, SCHED_OTHER, &param );

    proc();

    pthread_exit( NULL );
    return NULL;
}



o_thr_t 
o_thrStart( oberon_proc p, int len ) {
    
    o_thr_t id;
    pthread_attr_t attr;
     
    if (len < PTHREAD_STACK_MIN) len = PTHREAD_STACK_MIN;
    pthread_attr_init( &attr );
    pthread_attr_setscope(&attr, PTHREAD_SCOPE_SYSTEM);
    pthread_attr_setdetachstate( &attr, PTHREAD_CREATE_DETACHED );
    pthread_attr_setstacksize( &attr, len );
    if (pthread_create( &id, &attr, starter, p ) != 0) return 0;
    return id;
}



o_thr_t 
o_thrThis(int dummy) {

    return pthread_self();
}



void 
o_thrYield(int dummy) {

    o_thrSleep( 1 );
}



void 
o_thrExit(int dummy) {
    
    pthread_exit( 0 );
}



void 
o_thrSuspend(o_thr_t thr) {

    pthread_mutex_lock( &suspend_mutex );
    suspend_done = 0;
    pthread_kill( thr, T_SIGSUSPEND );
    while (suspend_done != 1) o_thrSleep( 1 );
    pthread_mutex_unlock( &suspend_mutex );
}


static void 
suspend_handler(int sig) {
    sigset_t block;

    sigfillset( &block );
    sigdelset( &block, T_SIGRESUME );
    suspend_done = 1;

    sigsuspend( &block ); /* await T_SIGRESUME */

    resume_done = 1;
}



static void 
resume_handler(int sig) {
}

void 
o_thrResume(o_thr_t thr) {
    int n;

    pthread_mutex_lock( &suspend_mutex );
    resume_done = 0; n = 1;
    pthread_kill( thr, T_SIGRESUME ); 
    while (resume_done != 1 && n < 50) { o_thrSleep( 1 ); n++; }
    pthread_mutex_unlock( &suspend_mutex );
}



void 
o_thrSetprio(o_thr_t thr, int prio) {

    struct sched_param param;
    int policy;


    pthread_getschedparam( thr, &policy, &param );
    param.sched_priority = prio;
    if (pthread_setschedparam( thr, SCHED_OTHER, &param ) != 0)
    	perror("pthread_setschedparam");
}



int 
o_thrGetprio(o_thr_t thr) {

    struct sched_param param;
    int policy;

    pthread_getschedparam( thr, &policy, &param );
    return ( param.sched_priority );
}



void 
o_thrKill(o_thr_t thr) {

    if (thr != mainthread) {
    	pthread_detach( thr );
    	if (thr == pthread_self())
    	    pthread_exit( 0 );
    	else {
    	    pthread_cancel( thr );
        } 
    }
}



int 
o_thrInitialize( int *low, int* high ) {
    struct sched_param param;
    
    pthread_mutex_init( &suspend_mutex, NULL );
    mainthread = pthread_self();
    *high = sched_get_priority_max(SCHED_OTHER);
    *low = sched_get_priority_min(SCHED_OTHER);
    param.sched_priority = *high;
    pthread_setschedparam( mainthread, SCHED_OTHER, &param );

    sigemptyset( &sasuspend.sa_mask );
    sigaddset( &sasuspend.sa_mask, T_SIGRESUME );
    sasuspend.sa_flags = 0;
    sasuspend.sa_handler = suspend_handler;
    sigaction( T_SIGSUSPEND, &sasuspend, NULL );

    sigemptyset( &saresume.sa_mask );
    saresume.sa_flags = 0;
    saresume.sa_handler = resume_handler;
    sigaction( T_SIGRESUME, &saresume, NULL );
    
    return 1;
}



