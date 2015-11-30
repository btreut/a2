/* Oberon.OberonEnv

 Oberon Java Plattform 
*********************
*/
package oberon;

/**
 ** OberonEnv represents hooks to the Oberon Environment;
 ** Everything is native and static;
 **
 ** @author Rolf Laich
 ** @version 0.0, Dez 2000
 ** @since JDK1.0
 **/
public final class OberonEnv{
    
    private OberonEnv(){}

    public static final int NOT_IMPL = 0xBAFF;
    public static final int FILE = 0x0001;
    
    /** 
     ** in some situations it is very good to produce a trap
     **
     **/
    public native static void Trap( int nr );


    public native static String[] Directory( java.io.FileDescriptor fd, java.io.FilenameFilter ff );
    
    /**
     ** create a FileDesriptor 
     **/
    public native static java.io.FileDescriptor CreateFileDescriptor( String name, int typ );

    /**
     ** create a FileDesriptor 
     **/
    public native static java.io.FileDescriptor NewFile( String name );
    
    /**
     ** create a FileDesriptor 
     **/
    public native static java.io.FileDescriptor OldFile( String name );

    /**
     ** delete File assosiated with Filedescriptor
     **/
    public native static boolean DeleteFile( java.io.FileDescriptor fd );

    /**
     ** rename File assosiated with Filedescriptor
     **/
    public native static boolean RenameFile( java.io.FileDescriptor fd, String newName );

    /**
     ** get length of a file 
     **/
    public native static long FileLength( java.io.FileDescriptor fd );

    
    /**
     ** get modification date
     **/
    public native static long GetFileDate( java.io.FileDescriptor fd );

    /**
     ** set modification date
     **/
    public native static boolean SetFileDate( java.io.FileDescriptor fd, long time );

    /**
     ** support for floating point and math
     **
     **/
    
    /**
     ** parses a float or a double; return is always double
     ** for parseFloat in java/lang/Float use narrowing
     ** accepted syntax [+|-]number{number}["."{number}[(e|E)[+|-] number{number}]
     **/
    public native static double ParseFloatingPointNumber(String s)
    throws NumberFormatException, NullPointerException;

    /**
     ** converts a Floating Point Number to a java.lang.String
     **/
    public native static String Float2String( double val );
}

    
    
