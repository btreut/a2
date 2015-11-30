/* VMSystem.java
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

package java.lang;

import java.util.Properties;

/**
 ** VMSystem is a package-private helper class for System that the
 ** VM must implement.
 **
 ** @author John Keiser
 ** @version 1.1.0, Aug 8 1998
 **/

class VMSystem {
	/** Get the system properties.
	 ** <dl>
	 ** <dt>java.version         <dd>Java version number
	 ** <dt>java.vendor          <dd>Java vendor specific string
	 ** <dt>java.vendor.url      <dd>Java vendor URL
	 ** <dt>java.home            <dd>Java installation directory
	 ** <dt>java.class.version   <dd>Java class version number
	 ** <dt>java.class.path      <dd>Java classpath
	 ** <dt>os.name              <dd>Operating System Name
	 ** <dt>os.arch              <dd>Operating System Architecture
	 ** <dt>os.version           <dd>Operating System Version
	 ** <dt>file.separator       <dd>File separator ("/" on Unix)
	 ** <dt>path.separator       <dd>Path separator (":" on Unix)
	 ** <dt>line.separator       <dd>Line separator ("\n" on Unix)
	 ** <dt>user.name            <dd>User account name
	 ** <dt>user.home            <dd>User home directory
	 ** <dt>user.dir             <dd>User's current working directory
	 ** </dl>
	 ** It will also define the java.compiler if env(JAVA_COMPILER) is defined.<P>
	 ** 
	 ** <STRONG>Copyright Note:</STRONG> The above text was taken from
	 ** Japhar, by the Hungry Programmers (http://www.japhar.org).
	 **
	 ** @param p the Properties object to insert the system
	 **        properties into.
	 **/
	static void insertSystemProperties(Properties p)
	{
		p.setProperty("java.version", "1.1");
		p.setProperty("java.vendor", "aos");
		p.setProperty("java.vendor.url", "http://www.oberon.ethz.ch");
		p.setProperty("java.home", "");
		p.setProperty("java.class.version", "0.02");
		p.setProperty("java.class.path", "");
		p.setProperty("os.name", "Aos");
		p.setProperty("os.arch", "Oberon");
		p.setProperty("os.version", "Beta");
		p.setProperty("file.separator", "/");
		p.setProperty("path.separator", ":");
		p.setProperty("line.separator", "\n");
	}


	/** Copy one array onto another from
	 ** <CODE>src[srcStart] ... src[srcStart+len]</CODE> to
	 ** <CODE>dest[destStart] ... dest[destStart+len]</CODE>
	 ** @param src the array to copy elements from
	 ** @param srcStart the starting position to copy elements
	 **        from in the src array
	 ** @param dest the array to copy elements to
	 ** @param destStart the starting position to copy
	 **        elements from in the src array
	 ** @param len the number of elements to copy
	 ** @exception ArrayStoreException if src or dest is not
	 **            an array, or if one is a primitive type
	 **            and the other is a reference type or a
	 **            different primitive type.  The array will
	 **            not be modified if any of these is th
	 **            case.  If there is an element in src that
	 **            is not assignable to dest's type, this will
	 **            be thrown and all elements up to but not
	 **            including that element will have been
	 **            modified.
	 ** @exception ArrayIndexOutOfBoundsException if len is
	 **            negative, or if the start or end copy
	 **            position in either array is out of bounds.
	 **            The array will not be modified if this
	 **            exception is thrown.
	 **/
	static native void arraycopy(Object src, int srcStart, Object dest, int destStart, int len);

	/** Get a hash code computed by the VM for the Object.
	 ** This hash code will be the same as Object's hashCode()
	 ** method.  It is usually some convolution of the pointer
	 ** to the Object internal to the VM.  It follows standard
	 ** hash code rules, in that it will remain the same for a
	 ** given Object for the lifetime of that Object.
	 ** @param o the Object to get the hash code for
	 ** @return the VM-dependent hash code for this Object
	 **/
	static native int identityHashCode(Object o);
}
