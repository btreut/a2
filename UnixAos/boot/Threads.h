

#ifdef SOLARIS
# include <thread.h>
  typedef mutex_t *	o_mtx_t;
  typedef cond_t *	o_con_t;
  typedef thread_t	o_thr_t;
#else
  /*** Linux | Darwin ***/
# include <pthread.h>
  typedef pthread_mutex_t *	o_mtx_t;
  typedef pthread_cond_t *	o_con_t;
  typedef pthread_t		o_thr_t;
#endif

typedef void (*oberon_proc)();  /* Oberon procedure to be started as a new thread */

extern o_mtx_t	o_mtxInit( );
extern void	o_mtxDestroy( o_mtx_t mtx );
extern void	o_mtxLock(    o_mtx_t mtx );
extern void	o_mtxUnlock(  o_mtx_t mtx );

extern o_con_t	o_conInit( );
extern void	o_conDestroy( o_con_t con );
extern void	o_conWait(    o_con_t con, o_mtx_t mtx );
extern void	o_conSignal(  o_con_t con );



extern o_thr_t	o_thrStart( oberon_proc p, int len );
extern o_thr_t	o_thrThis( );
extern void	o_thrSleep( int ms );
extern void	o_thrYield( );
extern void	o_thrExit( );
extern void	o_thrSuspend( o_thr_t thr );
extern void	o_thrResume(  o_thr_t thr );
extern void	o_thrSetprio( o_thr_t thr, int prio );
extern int 	o_thrGetprio( o_thr_t thr );
extern void	o_thrKill(    o_thr_t thr );

extern int 	o_thrInitialize( int* low, int* high );


