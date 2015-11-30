/* StackTrace.java
   Copyright (C) 1998 Free Software Foundation

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

package gnu.vm.stack;

import java.lang.reflect.*;

/**
 ** StackTrace represents a Java system execution
 ** stack and allows you to get information off of it.
 **
 ** @author John Keiser
 ** @version 1.1.0, Aug 11 1998
 **/
public class StackTrace {
	StackFrame[] frames;
	int len;

	public static StackTrace copyCurrentStackTrace() {
		return new StackTrace(new StackFrame[0]);
	}

	public static StackTrace copyStackTrace(Thread t) {
		return new StackTrace(new StackFrame[0]);
	}

	StackTrace(StackFrame[] frames) {
		this.frames = frames;
		len = frames.length;
	}

	public synchronized StackFrame pop() {
		if(len <= 0)
			return null;
			//Note: cannot throw exception here, since this method
			//is used in exception throwing itself and could cause
			//an infinite loop.
			//throw new ArrayIndexOutOfBoundsException("stack trace empty.");
		len--;
		return frames[len];
	}

	public synchronized StackFrame frameAt(int i) {
		if(i > len)
			throw new ArrayIndexOutOfBoundsException(i + " > " + len);
		return frames[i];
	}

	public synchronized int numFrames() {
		return len;
	}
}
