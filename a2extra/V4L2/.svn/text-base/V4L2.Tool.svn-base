# ========================================
# V4L2 (Video For Linux 2) interface for LinuxAos
#
# 13-04-2013
# 
# ========================================

# Compile modules:

Compiler.Compile 
	Unix.V4L2.Mod Unix.libv4l2.Mod 
	Unix.VideoExample.Mod
	~
	
# run demo example:

	VideoExample.Start ~ 
	
	VideoExample.Stop ~ 

# free modules:

	SystemTools.Free VideoExample libv4l2 V4L2 ~ 
	