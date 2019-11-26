# a2 Bluebottle OS

This is a copy of original [A2 Repository](https://trac.inf.ethz.ch/trac/lecturers/a2) which moved in the mean time to [a new place](http://cas.inf.ethz.ch/projects/a2/repository). This copy here is obsoleted by [metacore's active, but unoffical mirror copy](https://github.com/metacore/A2OS).

Also extra ISO image [A2_Rev-6498_serial-trace.iso](http://sourceforge.net/projects/a2oberon/files/)

Also for MacOSX (Darwin) - [UnixAos](http://www.informatik.uni-bremen.de/~fld/UnixAos/)

Extra Modules for A2 - [subversion community repository](https://www.ocp.inf.ethz.ch/svn/ocp/trunk/)

## Forums

[Oberon Community Platform Forum](http://www.ocp.inf.ethz.ch/forum/index.php/board,4.0.html)

Russian forum [Active Oberon & A2 (Bluebottle)](http://forum.oberoncore.ru/viewforum.php?f=22)

## Installation

[Installation and Configuration](http://sage.com.ua/ru.shtml?e1l0)

## Compiling Boot Loader 

### Linux Ubuntu AMD64 (aos.linux)

    sudo apt-get install make
    sudo apt-get install gcc
    sudo apt-get install linux-headers-$(uname -r)

    cd ~/a2/UnixAos/boot

#### Running i386 (32 bit) over AMD64
    sudo ln -s /usr/include/asm-generic /usr/include/asm
    sudo apt-get install libc6-dev-i386
    sudo apt-get install libX11-dev:i386
    make -f Makefile.linux

#### Running native 64 bit version over AMD64
    nano +27 aos.c # "Need change sys/types.h to linux/types.h"
    sudo ln -s /usr/include/asm-generic /usr/include/asm
    make -f Makefile.linux.amd64
    
#### Copy Boot Loater to install folder 
    sudo cp ./aos.linux /usr/aos/aos.linux
    
## Forward X over SSH and run A2

    sudo apt-get install xauth

On the client side, the -X (capital X) option to ssh enables X11 forwarding, and you can make this the default (for all connections or for a specific conection) with **ForwardX11 yes** in

    sudo nano /etc/ssh_config

or

    sudo nano ~/.ssh/config

On the server side, **X11Forwarding yes** must specified in 

    sudo nano /etc/ssh/sshd_config
    
Note that the default is no forwarding (some distributions turn it on in their default /etc/ssh/sshd_config), and that the user cannot override this setting.

    ssh -X <your_ip_adress> -p <your_port> -l <your_user_name>
    cd ~/workdir
    aos


## List of popular Modules

[Cross Reference (2011.11.29)](http://bbos.org/2011/11/29/xref/)

[Cross Reference (2012.10.29) rev. 4996](http://bbos.org/xref/)

## ARM

[OLR](http://oberon.wikidot.com/) is the Oberon System with Gadgets running natively on the Linux Kernel of X86, MIPS and ARM processors.

There is a Paco ARM backend ... PCARM.Mod, PCARMCP.Mod, PCARMRegisters.Mod

https://lists.inf.ethz.ch/pipermail/oberon/2007/005300.html

https://lists.inf.ethz.ch/pipermail/oberon/2007/005303.html

### ARM compiler 

SharkOberon is an implementation of Native Oberon System 3 Release 2.3
for the [DEC DNARD Network Computer](http://www.firmworks.com/www/dnard.htm).

[/Oberon/System3/Native/SharkOberon/.beta] ftp://ftp.ethoberon.ethz.ch/Oberon/System3/Native/SharkOberon/.beta

The best place to start is ARM.Make.Tool in SharkOberon.zip .

To boot SharkOberon, you need an NC configured to boot the Oberon boot file
via TFTP and a NCFS server running on Unix to serve the system991119.ncfs file.

## Raytracing
[Raytracing from www.scratchapixel.com](http://sage.com.ua/ru.shtml?e1l8)

## Games

[Raycaster, Raycaster Maze, WMColorLines](http://sage.com.ua/ru.shtml?e1l9)

FPS in 2-3 time faster with Raster.Put, then with canvas.SetPixel.

## Exploits

[Code Injection Demo RU](http://forum.oberoncore.ru/viewtopic.php?f=22&t=881)

[Remote code injection with UDPChat application EN](http://www.ocp.inf.ethz.ch/forum/index.php/topic,23.0.html)

## Demo videos

[Nice video demo about a2](https://www.youtube.com/user/xenopusRTRT/videos)

## Main content of a2/WinAos/license.txt

This is a compilation of the 
- ETH WinAos System (Windows Emulation of the Active Object System, aka A2)
and 
- the software packages Voyager and AntsInFields. 


Nearly all parts of this compilation belong to the ETH WinAos System, exceptions are the files of "AntsInFields" and "Voyager"

----

Oberon is the name of a modern integrated software environment. It is a single-user, 
multi-tasking system that runs on bare hardware or on top of a host operating system. 
Oberon is also the name of a programming language in the Pascal/Modula tradition. 
The Oberon project was launched in 1985 by Niklaus Wirth and Jьrg Gutknecht. 
See also http://www.oberon.ethz.ch

Voyager is a project to explore the feasibility of a portable and extensible system 
for simulation and data analysis systems. It is mainly written in and for Oberon. 
The Voyager project is carried out by StatLab Heidelberg and was launched 
in 1993 by Gьnther Sawitzki. 
See also http://www.statlab.uni-heidelberg.de/projects/voyager/

AntsInFields is a Software Package for Simulation and Statistical Inference on Gibbs Fields.
AntsInFields is written in Oberon and uses Voyager. It has been developed since 1997
by Felix Friedrich. 

----

Voyager is - in this distribution - located in the directory "Work/vy"
Source code of Voyager is marked by preceding "vy" for all Module-Names

AntsInFields is - in this distribution - located in the directory "Work/ants"
Source code of AntsInFields is marked by preceding letters "ants" for all Module Names.

----

The WinAos System is protected by the following copyright, start and end marked by ">>" and "<<" respectively:

>>
 ETH Bluebottle
Copyright (c) 2002-2008, Computer Systems Institute, ETH Zurich
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met: 

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer. 
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution. 
    * Neither the name of the ETH Zurich nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission. 

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
<<


----


The following copyright note (start and end marked by ">>" and "<<" respectively) 
concerns either of the software packages   

Voyager 
(C) 1993-2002 Project Voyager, StatLab Heidelberg ; (C) 1993-2002 G. Sawitzki et al.


and 

AntsInFields 
(C) 1997-2002 Felix Friedrich, Munich:

>>
  
    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

<<

the copy of the LGPL can be found in this directory as file "LGPL.TXT"


