/* Class.java
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

import java.lang.reflect.*;
import java.security.*;
import gnu.java.lang.*;

/**
 * A Class represents a Java type.  There will never be
 * multiple Class objects with identical names and
 * ClassLoaders.<P>
 *
 * Arrays with identical type and number of dimensions
 * share the same class (and null "system" ClassLoader,
 * incidentally).  The name of an array class is
 * <CODE>[&lt;signature format&gt;;</CODE> ... for example,
 * String[]'s class is <CODE>[Ljava.lang.String;</CODE>.
 * boolean, byte, short, char, int, long, float and double
 * have the "type name" of Z,B,S,C,I,J,F,D for the
 * purposes of array classes.  If it's a multidimensioned
 * array, the same principle applies:
 * <CODE>int[][][]</CODE> == <CODE>[[[I</CODE>.<P>
 *
 * As of 1.1, this class represents primitive types as
 * well.  You can get to those by looking at
 * java.lang.Integer.TYPE, java.lang.Boolean.TYPE, etc.
 *
 * @author John Keiser
 * @version 1.1.0, Aug 6 1998
 * @since JDK1.0
 */

public class Class {
    private Object[] signers = null;
    private ProtectionDomain protectionDomain = null;
    
    // The unknown protection domain.
    private final static ProtectionDomain unknownProtectionDomain;

    static {
        Permissions permissions = new Permissions();
        permissions.add(new AllPermission());
        unknownProtectionDomain = new ProtectionDomain(null, permissions);
    }

    // Permission needed to get the protection domain
    private final static Permission protectionDomainPermission
        = new RuntimePermission("getProtectionDomain");

    private Class() {
    }

    /** 
     * Return the human-readable form of this Object.  For
     * class, that means "interface " or "class " plus the
     * classname.
     * @return the human-readable form of this Object.
     * @since JDK1.0
     */
    public String toString() {
	return (isInterface() ? "interface " : "class ") + getName();
    }

    /** 
     * Get the name of this class, separated by dots for
     * package separators.
     * @return the name of this class.
     * @since JDK1.0
     */ 
    public native String getName();

    /** 
     * Get whether this class is an interface or not.  Array
     * types are not interfaces.
     * @return whether this class is an interface or not.
     * @since JDK1.0
     */
    public native boolean isInterface();

    /** 
     * Get the direct superclass of this class.  If this is
     * an interface, it will get the direct superinterface.
     * @return the direct superclass of this class.
     * @since JDK1.0
     */
    public native Class getSuperclass();

    /** 
     * Get the interfaces this class <EM>directly</EM>
     * implements, in the order that they were declared.
     * This method may return an empty array, but will
     * never return null.
     * @return the interfaces this class directly implements.
     * @since JDK1.0
     */
    public native Class[] getInterfaces();

    /** 
     * Get a new instance of this class by calling the
     * no-argument constructor.
     * @return a new instance of this class.
     * @exception InstantiationException if there is not a
     *            no-arg constructor for this class, or if
     *            an exception occurred during instantiation,
     *            or if the target constructor throws an
     *            exception.
     * @exception IllegalAccessException if you are not
     *            allowed to access the no-arg constructor of
     *            this Class for whatever reason.
     * @since JDK1.0
     */
    public Object newInstance() throws InstantiationException, IllegalAccessException {
	try {
	    return getConstructor(new Class[0]).newInstance(new Object[0]);
	} catch(SecurityException e) {
	    throw new IllegalAccessException("Cannot access no-arg constructor");
	} catch(IllegalArgumentException e) {
	    throw new UnknownError("IllegalArgumentException thrown from Constructor.newInstance().  Something is rotten in Denmark.");
	} catch(InvocationTargetException e) {
	    throw new InstantiationException("Target threw an exception.");
	} catch(NoSuchMethodException e) {
	    throw new InstantiationException("Method not found");
	}
    }
    
    /** 
     * Get the ClassLoader that loaded this class.  If it was
     * loaded by the system classloader, this method will
     * return null.
     * @return the ClassLoader that loaded this class.
     * @since JDK1.0
     */
    public native ClassLoader getClassLoader();

    /** 
     * Use the system classloader to load and link a class.
     * @param name the name of the class to find.
     * @return the Class object representing the class.
     * @exception ClassNotFoundException if the class was not
     *            found by the system classloader.
     * @since JDK1.0
     */
    public static native Class forName(String name) throws ClassNotFoundException;

    /**
     * Use the specified classloader to load and link a class.
     * Calls <code>classloader.loadclass(name, initialize)</code>.
     * @param name the name of the class to find.
     * @param initialize wether or not to initialize the class.
     * This is only a hint for optimization. Set this to false if the class
     * will not (immediatly) be used to initialize objects.
     * @param classloader the classloader to use to find the class.
     * When classloader is <code>null</code> this methods acts the
     * same as <code>forName(String)</code> (and uses the system class loader).
     * @exception ClassNotFoundException if the class was not
     *            found by the specified classloader.
     * @exception SecurityException if the <code>classloader</code> argument
     *            is <code>null</code> and the caller does not have the
     *            <code>RuntimePermission("getClassLoader")</code>
     *            (to get the system classloader) and was not loaded by the
     *            system classloader (or bootstrap classloader).
     * @since 1.2
     */
    public static Class forName(String name,
				boolean initialize,
				ClassLoader classloader)
	throws ClassNotFoundException
    {
        if (classloader == null) {
            // Check if we may get the system classloader
            SecurityManager sm = System.getSecurityManager();
            if (sm != null) {
                // Get the calling class and classloader
                Class c = VMSecurityManager.getClassContext()[1];
                ClassLoader cl = c.getClassLoader();
                if (cl != null && cl != ClassLoader.systemClassLoader)
                    sm.checkPermission
                        (new RuntimePermission("getClassLoader"));
            }
            classloader = ClassLoader.systemClassLoader;
        }

        return classloader.loadClass(name, initialize);
    }

    /** 
     * Discover whether an Object is an instance of this
     * Class.  Think of it as almost like
     * <CODE>o instanceof (this class)</CODE>.
     * @param o the Object to check
     * @return whether o is an instance of this class.
     * @since JDK1.1
     */
    public native boolean isInstance(Object o);

    /** 
     * Discover whether an instance of the Class parameter
     * would be an instance of this Class as well.  Think of
     * doing <CODE>isInstance(c.newInstance())</CODE> or even
     * <CODE>c instanceof (this class)</CODE>.
     * @param c the class to check
     * @return whether an instance of c would be an instance
     *         of this class as well.
     * @since JDK1.1
     */
    public native boolean isAssignableFrom(Class c);

    /** 
     * Return whether this class is an array type.
     * @return whether this class is an array type.
     * @since JDK1.1
     */
    public boolean isArray() {
	return getName().charAt(0) == '[';
    }

    /** 
     * Return whether this class is a primitive type.  A
     * primitive type class is a class representing a kind of
     * "placeholder" for the various primitive types.  You
     * can access the various primitive type classes through
     * java.lang.Boolean.TYPE, java.lang.Integer.TYPE, etc.
     * @return whether this class is a primitive type.
     * @since JDK1.1
     */
    public native boolean isPrimitive();
    
    /** 
     * If this is an array, get the Class representing the
     * type of array.  Examples: [[java.lang.String would
     * return [java.lang.String, and calling getComponentType
     * on that would give java.lang.String.  If this is not
     * an array, returns null.
     * @return the array type of this class, or null.
     * @since JDK1.1
     */
    public Class getComponentType() {
	if(isArray()) {
	    try {
		return Class.forName(getName().substring(1));
	    } catch(ClassNotFoundException e) {
		return null;
	    }
	} else {
	    return null;
	}
    }
    
    /** 
     * Get the signers of this class.
     * @return the signers of this class.
     * @since JDK1.1
     */
    public Object[] getSigners() {
	return signers;
    }

    /** 
     * Set the signers of this class.
     * @param signers the signers of this class.
     * @since JDK1.1
     */
    void setSigners(Object[] signers) {
	this.signers = signers;
    }

    /** 
     * Get a resource URL using this class's package using
     * the getClassLoader().getResource() method.  If this
     * class was loaded using the system classloader,
     * ClassLoader.getSystemResource() is used instead.<P>
     *
     * If the name you supply is absolute (it starts with a
     * <CODE>/</CODE>), then it is passed on to getResource()
     * as is.  If it is relative, the package name is 
     * prepended, with <CODE>.</CODE>'s replaced with
     * <CODE>/</CODE> slashes.<P>
     *
     * The URL returned is system- and classloader-
     * dependent, and could change across implementations.
     * @param name the name of the resource, generally a
     *        path.
     * @return the URL to the resource.
     */
    public java.net.URL getResource(String name) {
	if(name.length() > 0 && name.charAt(0) != '/') {
	    name = ClassHelper.getPackagePortion(getName()).replace('.','/') + "/" + name;
	}
	ClassLoader c = getClassLoader();
	if(c == null) {
	    return ClassLoader.getSystemResource(name);
	} else {
	    return c.getResource(name);
	}
    }
    
    /** 
     * Get a resource using this class's package using the
     * getClassLoader().getResource() method.  If this class
     * was loaded using the system classloader,
     * ClassLoader.getSystemResource() is used instead.<P>
     *
     * If the name you supply is absolute (it starts with a
     * <CODE>/</CODE>), then it is passed on to getResource()
     * as is.  If it is relative, the package name is 
     * prepended, with <CODE>.</CODE>'s replaced with
     * <CODE>/</CODE> slashes.<P>
     *
     * The URL returned is system- and classloader-
     * dependent, and could change across implementations.
     * @param name the name of the resource, generally a
     *        path.
     * @return An InputStream with the contents of the
     *         resource in it.
     */
    public java.io.InputStream getResourceAsStream(String name) {
	if(name.length() > 0 && name.charAt(0) != '/') {
	    name = ClassHelper.getPackagePortion(getName()).replace('.','/') + "/" + name;
	}
	ClassLoader c = getClassLoader();
	if(c == null) {
	    return ClassLoader.getSystemResourceAsStream(name);
	} else {
	    return c.getResourceAsStream(name);
	}
    }
    
    /** 
     * Get the modifiers of this class.  These can be checked
     * against using java.lang.reflect.Modifier.
     * @return the modifiers of this class.
     * @see java.lang.reflect.Modifer
     * @since JDK1.1
     */
    public native int getModifiers();

    /** 
     * If this is an inner class, return the class that
     * declared it.  If not, return null.
     * @return the declaring class of this class.
     * @since JDK1.1
     */
    public native Class getDeclaringClass();

    /** 
     * Get all the public inner classes, declared in this
     * class or inherited from superclasses, that are
     * members of this class.
     * @return all public inner classes in this class.
     */
    public native Class[] getClasses();

    /** 
     * Get all the inner classes declared in this class.
     * @return all inner classes declared in this class.
     * @exception SecurityException if you do not have access
     *            to non-public inner classes of this class.
     */
    public native Class[] getDeclaredClasses() throws SecurityException;

    /** 
     * Get a public constructor from this class.
     * @param args the argument types for the constructor.
     * @return the constructor.
     * @exception NoSuchMethodException if the constructor does
     *            not exist.
     * @exception SecurityException if you do not have access to public
     *            members of this class.
     */
    public native Constructor getConstructor(Class[] args) throws NoSuchMethodException, SecurityException;
    
    /** 
     * Get a constructor declared in this class.
     * @param args the argument types for the constructor.
     * @return the constructor.
     * @exception NoSuchMethodException if the constructor does
     *            not exist in this class.
     * @exception SecurityException if you do not have access to
     *            non-public members of this class.
     */
    public native Constructor getDeclaredConstructor(Class[] args) throws NoSuchMethodException, SecurityException;

    /** 
     * Get all public constructors from this class.
     * @return all public constructors in this class.
     * @exception SecurityException if you do not have access to public
     *            members of this class.
     */
    public native Constructor[] getConstructors() throws SecurityException;

    /** 
     * Get all constructors declared in this class.
     * @return all constructors declared in this class.
     * @exception SecurityException if you do not have access to
     *            non-public members of this class.
     */
    public native Constructor[] getDeclaredConstructors() throws SecurityException;


    /** 
     * Get a public method from this class.
     * @param name the name of the method.
     * @param args the argument types for the method.
     * @return the method.
     * @exception NoSuchMethodException if the method does
     *            not exist.
     * @exception SecurityException if you do not have access to public
     *            members of this class.
     */
    public native Method getMethod(String name, Class[] args) throws NoSuchMethodException, SecurityException;

    /** 
     * Get a method declared in this class.
     * @param name the name of the method.
     * @param args the argument types for the method.
     * @return the method.
     * @exception NoSuchMethodException if the method does
     *            not exist in this class.
     * @exception SecurityException if you do not have access to
     *            non-public members of this class.
     */
    public native Method getDeclaredMethod(String name, Class[] args) throws NoSuchMethodException, SecurityException;

    /** 
     * Get all public methods from this class.
     * @return all public methods in this class.
     * @exception SecurityException if you do not have access to public
     *            members of this class.
     */
    public native Method[] getMethods() throws SecurityException;

    /** 
     * Get all methods declared in this class.
     * @return all methods declared in this class.
     * @exception SecurityException if you do not have access to
     *            non-public members of this class.
     */
    public native Method[] getDeclaredMethods() throws SecurityException;


    /** 
     * Get a public field from this class.
     * @param name the name of the field.
     * @return the field.
     * @exception NoSuchFieldException if the field does
     *            not exist.
     * @exception SecurityException if you do not have access to public
     *            members of this class.
     */
    public native Field getField(String name) throws NoSuchFieldException, SecurityException;
    
    /** 
     * Get a field declared in this class.
     * @param name the name of the field.
     * @return the field.
     * @exception NoSuchFieldException if the field does
     *            not exist in this class.
     * @exception SecurityException if you do not have access to
     *            non-public members of this class.
     */
    public native Field getDeclaredField(String name) throws NoSuchFieldException, SecurityException;
    
    /**
     * Get all public fields from this class.
     *
     * @return all public fields in this class.
     * @exception SecurityException if you do not have access to public
     *            members of this class.
     */
    public native Field[] getFields() throws SecurityException;

    /** 
     * Get all fields declared in this class.
     *
     * @return all fieilds declared in this class.
     * @exception SecurityException if you do not have access to
     *            non-public members of this class.
     */
    public native Field[] getDeclaredFields() throws SecurityException;

    /**
     * Returns the <code>Package</code> in which this class is defined
     * Returns null when this information is not available from the
     * classloader of this class or when the classloader of this class
     * is null.
     *
     * @since 1.2
     */
    public Package getPackage() {
        ClassLoader cl = getClassLoader();
        if (cl != null)
            return cl.getPackage(ClassHelper.getPackagePortion(getName()));
        else
            return null;
    }

    /**
     * Returns the protection domain of this class. If the classloader
     * did not record the protection domain when creating this class
     * the unknown protection domain is returned which has a <code>null</code>
     * code source and all permissions.
     *
     * @exception SecurityException if a security manager exists and the caller
     * does not have <code>RuntimePermission("getProtectionDomain")</code>.
     *
     * @since 1.2
     */
    public ProtectionDomain getProtectionDomain() {
        SecurityManager sm = System.getSecurityManager();
        if (sm != null)
            sm.checkPermission(protectionDomainPermission);

        if (protectionDomain == null)
            return unknownProtectionDomain;
        else
            return protectionDomain;
    }

}

