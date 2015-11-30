/* java.lang.Thread
   Copyright (C) 1998, 2001 Free Software Foundation

This file is part of GNU Classpath.

GNU Classpath is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

GNU Classpath is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Classpath; see the file COPYING.  If not, write to the
Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
02111-1307 USA.

As a special exception, if you link this library with other files to
produce an executable, this library does not by itself cause the
resulting executable to be covered by the GNU General Public License.
This exception does not however invalidate any other reasons why the
executable file might be covered by the GNU General Public License. */

package java.lang;

/**
 ** Thread represents a single thread of execution in the VM.
 ** When an application VM starts up, it creates a new Thread
 ** which calls the main() method of a particular class.  There
 ** may be other Threads running, such as the garbage collection
 ** thread.<P>
 **
 ** Threads have names to identify them.  These names are not
 ** necessarily unique.<P>
 **
 ** Every Thread has a priority, as well, which tells the VM
 ** which Threads get more running time.<P>
 **
 ** There are two methods of creating a Thread: you may
 ** subclass Thread and implement the <CODE>run()</CODE> method, at which
 ** point you may start the Thread by calling its <CODE>start()</CODE>
 ** method, or you may implement <CODE>Runnable</CODE> in the class you
 ** want to use and then call new <CODE>Thread(your_obj).start()</CODE>.
 **
 ** @specnote it is unclear at what point a Thread should be added to a
 **           ThreadGroup, and at what point it should be removed.
 **           Should it be inserted when it starts, or when it is
 **           created?  Should it be removed when it is suspended or
 **           interrupted?  The only thing that is clear is that the
 **           Thread should be removed when it is stopped.
 ** @author John Keiser
 ** @version 1.1.0, Aug 6 1998
 ** @since JDK1.0
 **/

public class Thread implements Runnable {
	ThreadGroup group;
	Runnable toRun;
	String name;
	boolean daemon;
	int priority;

	/** The maximum priority for a Thread.
	 ** @XXX find out the value for this.
	 **/
	public static final int MAX_PRIORITY  = 100;

	/** The priority a Thread gets by default.
	 ** @XXX find out the value for this.
	 **/
	public static final int NORM_PRIORITY = 50;

	/** The minimum priority for a Thread.
	 ** @XXX find out the value for this.
	 **/
	public static final int MIN_PRIORITY = 0;

	static int numAnonymousThreadsCreated = 0;


	/** Allocate a new Thread object, with the same ThreadGroup
	 ** as the calling thread, with an automatic name, and using
	 ** Thread's <CODE>run()</CODE> method to execute.<P>
	 **
	 ** The new Thread will inherit its creator's priority and
	 ** will be marked as a daemon if its creator is a daemon.<P>
	 **
	 ** This method is identical to calling
	 ** <CODE>Thread(null,null,<I>fake name</I>)</CODE>, where the
	 ** fake name in this case is automatically generated with the
	 ** name "Thread-" + <I>arbitrary integer</I>.
	 **/
	public Thread() {
		this(null,null,null);
	}

	/** Allocate a new Thread object, with the same ThreadGroup
	 ** as the calling thread, with an automatic name, and using
	 ** the specified Runnable object's <CODE>run()</CODE> method
	 ** to execute.  If the Runnable object is null, Thread's
	 ** <CODE>run()</CODE> will be called instead.<P>
	 **
	 ** The new Thread will inherit its creator's priority and
	 ** will be marked as a daemon if its creator is a daemon.<P>
	 **
	 ** This method is identical to calling
	 ** <CODE>Thread(null,target,<I>fake name</I>)</CODE>, where the
	 ** fake name in this case is automatically generated with the
	 ** name "Thread-" + <I>arbitrary integer</I>.
	 **
	 ** @param toRun the Runnable object to execute.
	 **/
	public Thread(Runnable toRun) {
		this(null,toRun);
	}

	/** Allocate a new Thread object, with the specified ThreadGroup,
	 ** with an automatic name, and using the specified Runnable
	 ** object's <CODE>run()</CODE> method to execute.  If the
	 ** Runnable object is null, Thread's <CPDE>run()</CODE> will be
	 ** called instead.  If the ThreadGroup object is null, the Thread
	 ** will get the same ThreadGroup as the creating Thread.<P>
	 **
	 ** The new Thread will inherit its creator's priority and
	 ** will be marked as a daemon if its creator is a daemon.<P>
	 **
	 ** This method is identical to calling
	 ** <CODE>Thread(null,target,<I>fake name</I>)</CODE>, where the
	 ** fake name in this case is automatically generated with the
	 ** name "Thread-" + <I>arbitrary integer</I>.
	 **
	 ** @param group the group to put the Thread into.
	 ** @param target the Runnable object to execute.
	 **
	 ** @exception SecurityException if this thread cannot access the
	 **            specified ThreadGroup.
	 **/
	public Thread(ThreadGroup group, Runnable toRun) {
		this(group,toRun,null);
	}

	/** Allocate a new Thread object, with the same ThreadGroup
	 ** as the calling thread, with the specified name, and using
	 ** Thread's <CODE>run()</CODE> method to execute.<P>
	 **
	 ** The new Thread will inherit its creator's priority and
	 ** will be marked as a daemon if its creator is a daemon.<P>
	 **
	 ** This method is identical to calling
	 ** <CODE>Thread(null,null,name)</CODE>.
	 **
	 ** @param name the name for the Thread.
	 **/
	public Thread(String name) {
		this(null,null,name);
	}

	/** Allocate a new Thread object, with the same ThreadGroup
	 ** as the calling thread, with the specified name, and using
	 ** the specified Runnable object's <CODE>run()</CODE> method
	 ** to execute.  If the Runnable object is null, Thread's
	 ** <CPDE>run()</CODE> will be called instead.<P>
	 **
	 ** The new Thread will inherit its creator's priority and
	 ** will be marked as a daemon if its creator is a daemon.<P>
	 **
	 ** This method is identical to calling
	 ** <CODE>Thread(null,target,name)</CODE>.
	 **
	 ** @param toRun the Runnable object to execute.
	 ** @param name the name for the Thread.
	 **/
	public Thread(Runnable toRun, String name) {
		this(null,toRun,name);
	}

	public Thread(ThreadGroup group, String name) {
		this(group,null,name);
	}

	/** Allocate a new Thread object, with the specified ThreadGroup,
	 ** with the specified name, and using the specified Runnable
	 ** object's <CODE>run()</CODE> method to execute.  If the
	 ** Runnable object is null, Thread's <CPDE>run()</CODE> will be
	 ** called instead.  If the ThreadGroup object is null, the Thread
	 ** will get the same ThreadGroup as the creating Thread.<P>
	 **
	 ** The new Thread will inherit its creator's priority and
	 ** will be marked as a daemon if its creator is a daemon.
	 **
	 ** @param group the group to put the Thread into.
	 ** @param target the Runnable object to execute.
	 ** @param name the name for the Thread.
	 **
	 ** @exception SecurityException if this thread cannot access the
	 **            specified ThreadGroup.
	 **/
	public Thread(ThreadGroup group, Runnable toRun, String name) {
		if(group != null) {
			this.group = group;
			group.checkAccess();
		} else {
			this.group = currentThread().getThreadGroup();
		}

		if ( name != null )
 		{
			this.name = name;
 		} else {
 			this.name = "Thread-" + (++numAnonymousThreadsCreated);
		}

		this.toRun = toRun;

		priority = currentThread().getPriority();
		daemon = currentThread().isDaemon();
		nativeInit();

		this.group.addThread(this);
		InheritableThreadLocal.newChildThread(this);
	}

	/** Get the currently executing Thread.
	 ** @return the currently executing Thread.
	 **/
	public static native Thread currentThread();

	/** Suspend the current Thread's execution for the specified
	 ** amount of time.  The Thread will not lose any locks it has
	 ** during this time.
	 **
	 ** @param ms the number of milliseconds to sleep.
	 ** @exception InterruptedException if the Thread is interrupted
	 **            by another Thread.
	 ** @exception SecurityException if you cannot modify this Thread.
	 **/
	public static void sleep(long ms) throws InterruptedException {
		sleep(ms,0);
	}

	/** Suspend the current Thread's execution for the specified
	 ** amount of time.  The Thread will not lose any locks it has
	 ** during this time.
	 **
	 ** @param ms the number of milliseconds to sleep.
	 ** @param ns the number of extra nanoseconds to sleep (0-999999).
	 ** @exception InterruptedException if the Thread is interrupted
	 **            by another Thread.
	 **/
	public static native void sleep(long ms, int ns) throws InterruptedException;

	/** Start this Thread, calling the run() method of the Runnable
	 ** this Thread was created with or else the run() method of the
	 ** Thread itself.
	 **/
	public synchronized native void start();

	/** The method of Thread that will be run if there is no Runnable
	 ** object associated with the Thread.<P>
	 **
	 ** Thread's implementation does nothing at all.
	 **/
	public void run() {
		if (toRun != null)
			toRun.run();
	}

	/** Cause this Thread to stop abnormally and throw a ThreadDeath
	 ** exception.<P>
	 **
	 ** If you stop a Thread that has not yet started, it will stop
	 ** immediately when it is actually started.<P>
	 **
	 ** @exception SecurityException if you cannot modify this Thread.
	 ** @XXX it doesn't yet implement that second requirement.
	 **/
	public final void stop() {
		stop(new ThreadDeath());
	}

	/** Cause this Thread to stop abnormally and throw the specified
	 ** exception.<P>
	 **
	 ** If you stop a Thread that has not yet started, it will stop
	 ** immediately when it is actually started.<P>
	 **
	 ** @param t the Throwable to throw when the Thread dies.
	 ** @exception SecurityException if you cannot modify this Thread.
	 ** @XXX it doesn't yet implement that second requirement.
	 **/
	public final synchronized void stop(Throwable t) {
		checkAccess();
		group.removeThread(this);
		nativeStop(t);
	}

 	/**
 	 ** Yield to another thread
	 **/
	public static synchronized native void yield();

	/** Interrupt this Thread.
	 ** It is not clear whether locks this Thread has should be released.
	 ** This operation will only take place if the Thread is suspended
	 ** or is sleeping.
	 ** @exception SecurityException if you cannot modify this Thread.
	 **/
	public synchronized void interrupt() {
		checkAccess();
		nativeInterrupt();
	}

	/** Destroy this thread.  Don't even bother to clean up locks.
	 ** @exception SecurityException if you cannot modify this Thread.
	 **/
	public synchronized void destroy() {
		checkAccess();
		group.removeThread(this);
		nativeDestroy();
	}

	/** Suspend this Thread.  It will not come back, ever, unless
	 ** it is resumed.  It is not clear whether locks should be
	 ** released until resumption, but it is likely.
	 ** @exception SecurityException if you cannot modify this Thread.
	 **/
	public final synchronized void suspend() {
		checkAccess();
		nativeSuspend();
	}
	
	/** Resume this Thread.  If the thread is not suspended, this
	 ** method does nothing.
	 ** @exception SecurityException if you cannot modify this Thread.
	 **/
	public final synchronized void resume() {
		checkAccess();
		nativeResume();
	}

	/** Wait forever for the Thread in question to die.
	 ** @exception InterruptedException if this Thread is interrupted
	 **            while waiting.
	 **/
	public final void join() throws InterruptedException {
		join(0,0);
	}

	/** Wait the specified amount of time for the Thread in question to
	 ** die.
	 ** @param ms the number of milliseconds to wait, or 0 for forever.
	 ** @exception InterruptedException if this Thread is interrupted
	 **            while waiting.
	 **/
	public final void join(long ms) throws InterruptedException {
		join(ms,0);
	}

	/** Wait the specified amount of time for the Thread in question to
	 ** die.
	 ** @param ms the number of milliseconds to wait, or 0 for forever.
	 ** @param ns the number of nanoseconds (0-999999) to wait, or 0 for
	 **        forever.
	 ** @exception InterruptedException if this Thread is interrupted
	 **            while waiting.
	 ** @XXX a ThreadListener would be nice.  Then perhaps this could be
	 **      made efficient.
	 **/
	public final void join(long ms, int ns) throws InterruptedException {
		if(ms == 0 && ns == 0) {
			while(isAlive())
				currentThread().sleep(1);
		} else {
			for(long i=0;i<ms;i++) {
				if(!isAlive())
					return;
				currentThread().sleep(1);
			}
			currentThread().sleep(0,ns);
		}
	}

	/** Print a stack trace of the current thread to stderr using
	 ** the same format as Throwable's printStackTrace() method.
	 **/
	public static void dumpStack() {
		new Throwable().printStackTrace();
	}


	/** Set this Thread's priority.
	 ** @param priority the new priority for this Thread.
	 ** @exception SecurityException if you cannot modify this Thread.
	 **/
	public final void setPriority(int priority) {
		checkAccess();
		if(priority < MIN_PRIORITY
		   || priority > MAX_PRIORITY
		   || priority > group.getMaxPriority())
			throw new IllegalArgumentException("Invalid thread priority value " + priority + ".");
		this.priority = priority;
		nativeSetPriority(priority);
	}

	/** Get this Thread's priority.
	 ** @return the Thread's priority.
	 **/
	public final int getPriority() {
		return priority;
	}

	/** Set this Thread's name.
	 ** @param name the new name for this Thread.
	 ** @exception SecurityException if you cannot modify this Thread.
	 **/
	public final void setName(String name) {
		checkAccess();
		this.name = name;
	}

	/** Get this Thread's name.
	 ** @return this Thread's name.
	 **/
	public final String getName() {
		return name;
	}

	/** Get the ThreadGroup this Thread belongs to.
	 ** @return this Thread's ThreadGroup.
	 **/
	public final ThreadGroup getThreadGroup() {
		return group;
	}

	/** Set the daemon status of this Thread.  If this is a
	 ** daemon Thread, then the VM may exit even if it is still
	 ** running.  This may only be called when the Thread is not
	 ** running.
	 ** 
	 ** @specnote It is possible that this should only be called
	 **           if the Thread has not been started.  This
	 **           interpretation was easier to implement, though,
	 **           so it's the one I chose :)
	 ** @param daemon whether this should be a daemon thread or not.
	 ** @exception SecurityException if you cannot modify this Thread.
	 ** @exception IllegalThreadStateException if the Thread is active.
	 **/
	public final void setDaemon(boolean daemon) {
		this.daemon = daemon;
	}

	/** Tell whether this is a daemon Thread or not.
	 ** @return whether this is a daemon Thread or not.
	 **/
	public final boolean isDaemon() {
		return daemon;
	}


	/** Get the number of active threads in the current Thread's
	 ** ThreadGroup.  This implementation calls
	 ** <CODE>currentThread().getThreadGroup().activeCount()</CODE>.
	 ** @return the number of active threads in the current Thread's
	 **         ThreadGroup.
	 **/
	public static int activeCount() {
		return currentThread().group.activeCount();
	}

	/** Copy every active thread in the current Thread's ThreadGroup
	 ** into the array.  This implementation calls
	 ** <CODE>getThreadGroup().enumerate(array)</CODE>
	 ** @param array the array to place the Threads into.
	 ** @return the number of Threads placed into the array.
	 **/
	public static int enumerate(Thread[] array) {
		return currentThread().group.enumerate(array);
	}

	/** Count the number of stack frames in this Thread.  The Thread
	 ** in question must be suspended when this occurs.
	 **
	 ** @return the number of stack frames in this Thread.
	 ** @exception IllegalThreadStateException if this Thread is
	 **            not suspended.
	 **/
	public native int countStackFrames();


	/** Determine whether the current Thread has been interrupted.
	 ** @return whether the current Thread has been interrupted.
	 **/
	public static boolean interrupted() {
		return currentThread().isInterrupted();
	}

	/** Determine whether this Thread has been interrupted.
	 ** @return whether this Thread has been interrupted.
	 **/
	public native boolean isInterrupted();

	/** Determine whether this Thread is alive.
	 ** @return whether this Thread is alive.
	 **/
	public final native boolean isAlive();


	/** Check whether the current Thread is allowed to
	 ** modify this Thread.
	 ** @exception SecurityException if the current Thread cannot
	 **            modify this Thread.
	 **/
	public void checkAccess() {
		SecurityManager sm = System.getSecurityManager();
		if(sm != null) {
			sm.checkAccess(this);
		}
	}

	/** Return a human-readable String representing this Thread.
	 ** The format of the string is
	 ** "<CODE>Thread[&lt;name&gt;,&lt;priority&gt;,&lt;thread group name&gt;]</CODE>"
	 ** @return a human-readable String representing this Thread.
	 **/
	public String toString() {
		return "Thread[" + getName() + "," + getPriority() + "," + getThreadGroup().getName() + "]";
	}

	final native void nativeInit();
	final native void nativeStop(Throwable t);
	final native void nativeInterrupt();
	final native void nativeDestroy();
	final native void nativeSuspend();
	final native void nativeResume();
	final native void nativeSetPriority(int newPriority);

	public ClassLoader getContextClassLoader() {
		return(this.getClass().getClassLoader()); // For now
	}
}
