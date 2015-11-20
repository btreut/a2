CPU P4

	bits 16

trace:		equ 0
sectsize:	equ 512		; bytes per sector
lsize:		equ 5		; size of loader in sectors
tablesize: 	equ 4		; size of boot table in sectors

sectorid:	equ 055aah	; signature for 2nd sector

filler:		equ 'U'

HeapAddress:	equ 100000h
PML4:		equ 200000h - 4000h;
PDPE:		equ PML4 + 1000h
PDE:		equ PDPE + 1000h

entry:
	jmp short entry0
	nop
	
	db 'OBERON', 0			; 03 OEM id

; The OEM id ist used in Partitions.Mod and AosDiskVolumes.Mod
; to verify the presence of an Aos/Native file system.

flag: db 0					; 0A (*) flag/mask for testing the bits in the
							; shift status byte field used in this boot loader

	dw sectsize				; 0B bytes per sector
	db 2					; 0D sectors per cluster (# 0)
	dw lsize+tablesize		; 0E (*) number of reserved sectors
							; field used in Partitions.Mod
	db tablesize			; 10 (*) table sectors [number of FAT copies]
							; field used in Partitions.Mod
	dw 0					; 11 root dir size (was 224 ) - MUST be 0 for Win2K
	dw 0					; 13 total no. of sectors on disk written by
							; Partitions.Mod if disk capacity < 32 MB (10000H)
	db 0					; 15 (*) media descriptor
	dw 0					; 16 sectors per FAT (was 9 ) - MUST be 0 for Win2K

sectr: dw 18					; 18 (*) sectors per track
heads: dw 2					; 1A (*) number of heads
							; sectr and heads are needed only for the computation of CHS

sector: dd 0					; 1C (*) hidden sectors (boot sector number)

; LBA of the first sector of the partition as revealed by
; Partitions.Show detail - second column same value
; as in the Relative Sector field in the partition table

	dd 0					; 20 (*) total sectors on disk, if (#) = 0

; number of sectors of the partition as revealed by
; Partitions.Show detail - third column

drive: db 0					; 24 (*) drive identifier

; The drive id is set by Partitions.Mod to 80h for a HD, to 0 for a FD.
; A calling program such as a boot manager may deposit another value
; in this partition boot record on-the-fly when loaded into memory
; overwriting the value inserted by PROC InitOBL.
	
sum:  db 0					; 25 [current head] working field for checksum
oper: db 0					; 26 extended BPB signature

; To save space, the extended BPB signature was removed -> set to 0.
; If the extended BPB signature is equal to 28h or 29h,
; then the following strings, which may be modified
; without affecting the execution, have the meaning:
;	dd ?	; 27h volume serial number based
; on the date and time the partition was formatted
;	db 0,0,0,0,0,0,0,0,0,0,0	; 2bh volume label - 11 bytes
;	db 0,0,0,0,0,0,0,0	; 36h file system ID - 8 bytes

hellop: dw hello0
	
entry0:
	jmp 7c0h:entry1
	
entry1:

; set up segment registers & stack

	mov ax, cs 
	mov ds, ax				; data segment
	mov ss, ax				; stack segment
	mov sp, 1000h			; use 7c0:1000 as temporary stack

	call mark				; 'B' - show progress

	int 12h					; get conventional memory size in k in AX

	and al, ~3				; round down to 4k boundary
	sub ax, 8				; subtract 8k
	mov dx, 1024 / 16		; convert k to paragraphs
	mul dx					; ax now contains destination location

; move boot sector from 7c0:0000 to 2nd top page

	mov es, ax
	xor si, si				; clear
	xor di, di				; clear
	mov cx, sectsize		; number of bytes to relocate
	cld						; clear direction flag
	rep movsb				; relocate boot sector to es:di

; prepare to jump to loader in top page at entry2 - simulate procedure call

	push es
	push word entry2				; in relocated loader at IP= offset entry2
	retf					; jump to CS:IP

bufbeg0: db 0				; buffer overwrites code later
bufbeg: db 0					; an area from here to bufend will be used
							; as buffer for editing the config strings
							; NOTE: keep that area as large as possible !

; set up segment registers & stack

entry2:
	mov ax, cs				; code segment at es
	mov ds, ax				; data segment at es
	mov es, ax
	mov ss, ax
	mov sp, 2000h			; top of top page
	sti						;allow interrupts

	call mark				; 'l' - show progress

; inspect if the drive supports extended int 13h extensions

	mov byte [lbaindic], 0	; clear lba indicator
	mov dl, [drive]			; drive number
	cmp dl, 80h			; is it a hard disk ?
	jb short nolba			; e.g. 00h is diskette and has no lba

; the following operations are not valid for diskette drives
	
	mov bx, 55aah			; condition next BIOS call (fixed)
	mov ah, 41h			; check extension present
	int 13h					; call BIOS
	jc short nolba			; carry, LBA not supported
	cmp bx, 0aa55h			; confirm lba extensions present ?
	jne short nolba			; no
	test cx, 01h			; fixed disk access subset - is LBA ready ?
	jz short nolba			; no
	mov byte [lbaindic], cl	; set lba indicator

; read rest of bootstrap loader (sector 1 to lsize - 1)

nolba:
	inc dword [sector]		; next sector number
	mov eax, [sector]		; lba of the first sector to read
	mov bx, sectsize		; position in buffer where to store
	mov cx, lsize - 1		; number of sectors to read
	add dword [sector], byte lsize - 1	; sector number of boot table start
							; for the upcoming call readsectors
	call readsectors

; check that the bootstrap loader part is effectively present in memory
	
	call mark				; 'u' - show progress
	cmp word [nextid], sectorid	; is the signature valid in the second sector ?
	jne $					; no - halt the system !!!

	call mark				; 'e' - show progress

; read the boot table (sector 4 to 7, i.e. tablesize)

	mov eax, [sector]		; lba of the first sector to read
	mov [tabsec], eax		; store for later
	mov bx, lsize * sectsize	; position in buffer where to store
	mov cx, tablesize		; number of sectors to read
	add dword [sector], byte tablesize	; update [sector] to end of boottable
	call readsectors

; The boot table contains information for locating the kernel and the 
; environment data (configuration strings), and the environment data itself.
; The table is loaded into main memory and its entries are extracted by
; the procedure AosBoot.ReadBootTable . 
; The bootable is tablesize sectors long but the space effectively occupied
; is comparatively small. The amount of space needed depends
; on the environment data inserted when Partitions.SetConfig is executed.

; The boot table contains a list of variable length entries where each entry
; has the structure:
;
; 0000 - 0003    dd ?	entry type in the first byte at offset 0
; 0004 - 0007    dd ?	entry length
; 0008- ...	data
;
; Description of the entry types:

;	0ffffffffh = end of table
;	    Note: the boot table is filled with 0ffh when the partition
;	    is formatted with Partitions.Format dev#part AosFS ~
;
;	07000000h = fragmented kernel info placed by Partitions.UpdateBootFile
;		[4] entry length = 28
;		      kernel info
;		[4] address
;		[1] checksum
;		[1] void
;		[2] number of fragments
;		[8] kernel entry point
;	08000000h = environment info placed by Partitions.SetConfig
;		[4] entry length = variable
;		[var] configuration strings: a list of pairs [name value]
;				where each element is a zero-terminated string
; The above entries appear in the order of execution of the commands.
; To be operational, both entry types must be present.

; The following entries are generated on-the-fly by the boot loader at each
; start and appear strictly in that order.
; When "w" is sent as reply to prompt, after the boot process was interrupted,
; their presence can be observed by issuing Partitions.ShowBlocks dev#part 4 4
; But the boot loader will be tricked and find 0ffh instead of 03h, therefore
; they are qualified as "added stuff" in the comments.
;	03000000h = boot area info
;		[4] entry length = 16
;		[4] boot area address
;		[4] boot area size - two pages = 8192 bytes
;	04000000h = free area info - only if extended memory present
;		[4] entry length = 16
;		[4] free area address
;		[4] free area size - 100000h bytes
;	05000000h = BIOS ATA hard disk parameters of HD0 / HD1
;	          up to two such entries depending on what BIOS detects
;	          This entry type was removed without replacement, without
;	          affecting AosBoot.ReadBootTable .
;		[4] entry length = 28
;		[4] 0 - technical purpose
;		[16] hard disk parameters

; The entry with types 03, 04, 05, 08 are exploited by the procedure
; AosBoot.ReadBootTable (in module AosBoot.Mod) invoked by BBL.
; The type 08 entry is exploited and modified by the boot loader
; and the various name/value pairs are extracted at different times
; with the procedure AosBoot.GetConfig

	call locatekernel

; read the fragmented kernel sector by sector

rk1:
	push dword [si]			; save start & number
	push word [si + 4]

rk2:
	mov ax, 127				; max sectors that may be read on hd
	cmp byte [drive], 80h		; hard disk?
	jae short rk3			; yes, don't worry (can delete this to save space)

	mov ax, es
	mov bx, ax
	or ax, 4095				; ax = end of 64k area
	sub ax, bx
	inc ax					; ax = num of paras that may be read
	shr ax, 5				; ax = num of sectors "   "  "   "

rk3:
	mov cx, [si + 4]		; cx = number of sectors
	cmp ax, cx
	jae short rk4			; ok
;	cmp [drive],80h		; hard disk?
;	jae short rk4			; yes, don't worry
	mov cx, ax

rk4:
	mov eax, [si]			; eax = start sector
	add eax, [sector]		; relative to file system start
	xor bx, bx				; clear
	push cx					; number of sectors to read
	call readsectors
	pop cx

	mov bx, cx
	shl bx, 9				; bx = sectors * sectsize

rk5:
	mov al, [es:bx - 1]
	add [sum], al
	dec bx
	jnz rk5

	mov ax, es
	mov bx, cx
	shl bx, 5				; bx = sectors * sectsize/16
	add ax, bx
	mov es, ax

	add [si], cx			; next start sector
	adc word [si + 2], byte 0
	jmp near nextsector			; note: si = last entry in table

hello0: db 'Blue'			; four landmark characters for tracing
bufend: db 0					; see bufbeg

; what follows must continue to reside in this segment !!!

; ===== procedure: readsectors - rs. entry points
; in: eax = start sector number, es:bx = buffer,
; reserve bx for the sole use of the buffer address !!
;      cx = number of sectors to process (<128) thus precisely in cl
; mod: ax,bx,cx,dx,high(edi)
; note: it is the caller's responsibility that the transfer will not
; exceed a 64k address boundary.  if es:bx is page aligned, and cl <= 8,
; then a 64k boundary will not be exceeded.
; modified July, 2003 to use the extended int 13h functions in order
; to break the 8.4GB barrier.
; Reference: BIOS Enhanced Disk Drive Specification
;      Version 3.0 - Rev 0.9b - June 24, 1999. Phoenix Technologies Ltd.
;      http://www.t13.org/project/d1386r0.pdf
; http://web.inter.nl.net/hcc/J.Steunebrink/bioslim.htm

readsectors:
	mov word [opcode], 4200h	; extended read op-code

writesectors:				; entry point for writesectors
	push si
	push di

rsnext:
	push eax				; starting lba must be left untouched
	push cx					; save the number of sectors to process

; up to five read/write attempts, with at each failed attempt a disk reset.
; Each time the registers are conditioned to launch a standard read
; and an extended read.
; in that manner, code is kept small at the cost of performance which is
; anyway not critical here.
; a discriminator is placed immediately before the int 13h instruction
; to trim the operation code in ah, al.

	mov di, 5				; number of tries

readtry:

; set up dap for an extended read/write 13h disk operation
; the Device Address Packet (dap) is constructed on the fly by pushing
; the parts on the stack.
; the structure of the dap is:
;dap	db 10h	; dap size (fixed)
;	db 0	; reserved (fixed)
;num	dw ?	; number of sectors to transfer in cx
;boff	dw ?	; address of transfer buffer - offset in bx
;bseg	dw 0	; address of transfer buffer - segment in es
;sec0	dd ?	; starting absolute sector address in eax
;sec1	dd 0	; remaining 32 bits of address
; it is easiest to set up the dap first because the values to assign are
; available straight away.
; a volatile dap has the disadvantage that it must be rebuilt for a read retry

	push byte 00			; remaining 16 bits
	push byte 00			; remaining 16 bits
	push eax				; starting absolute sector address in dap
	push es					; address of transfer buffer - segment
	push bx					; address of transfer buffer - offset
	push cx					; number of sectors to process
	mov [opcode], cl		; save it
	push byte 10h			; 00h reserved - DAP is 16 bytes long (fixed)
	mov si, sp				; give access to the dap ds:si = dap

; convert lba value placed in eax to C-H-S in prevision of
; a fallback to standard read/write
; the values to place in the registers for an int 13h must be computed first.

	movzx edi, word [sectr]	; sectors per track
	xor edx, edx			; clear edx - future remainder
	div edi					; divide eax (lba) by sectr
	mov cl, dl
	inc cl 
	xor dx, dx				; clear dx - future remainder
	movzx edi, word [heads]	; number of heads
	div edi					; divide ax (lba) by heads

; at this point, the registers contain the C-H-S values where to start
; the disk operation:
;   ax = cylinder number
;   dx = head number
;   cx = sector number
; place the values in the registers for the upcoming read

	mov ch, al 
	shl ah, 6
	or cl, ah
	mov dh, dl

; a diskette is handled differently because the sectors must be read piecemeal
; multiple sectors can be processed but not across a track boundary
; the number of sectors to read/write must be adjusted

	cmp byte [drive], 80h	; hard disk?
	jae short hdisk			; yes, proceed normally

	push ax
	mov ax, [sectr]			; sectors per track
	sub al, cl				; - start at sector number
	inc al					; + 1
	cmp al, [opcode]		; will all the sectors to read be in that track ?
	jae short hdisk			; yes, proceed normally
	mov [opcode], al		; reduced number of sectors to read/write
	pop ax

; test if BIOS and the drive support extended int 13h extensions

hdisk:
	cmp byte [lbaindic], 0	; test the lba indicator
	jne short uselba		; drop all the preparation for C-H-S

	and byte [opcode + 1], 0fh	; function 02h (read) or 03h (write)

uselba:
	mov ax, [opcode]		; read/write op-code
	mov dl, [drive]			; drive number
	int 13h					; call BIOS
	lea sp, [si + 10h]		; load original offset value in sp
	jnc short rs3			; carry flag not set: ok, proceed
	xor ax, ax				; on failure, reset disk
	int 13h					; call BIOS

rs3:
	jnc short rs5			; carry flag not set: ok, proceed
	dec di					; does not clear carry
	jnz readtry				; retry counter > 0, retry

; when retries exhausted, issue an error message

	mov si, readerr			; point to error message

rs7:
	call writestring		; write it
	jmp $					; halt the system !!! endless loop

rs5:
	pop cx					; number of sectors to read/write
	pop eax
	xor edx, edx
	mov dl, [opcode]		; number of sectors processed
	sub cl, dl				; residual number of sectors left to process
	jz short rs6			; now zero, finished
	add eax, edx			; next lba to access
	shl dx, 9				; multiply by sector size
	add bx, dx				; position in buffer where to store next sector
	jmp near rsnext			; process next batch of sectors

rs6:
	pop di
	pop si

; NOTE: Tracing the progress of the execution is difficult.
; These few lines make it possible to follow each read/write operation
; even when no output is produced. Infer which code section was executed
; from the count of keyboard inputs.
;here:	mov ah,0	; wait for a keyboard event
;	int 16h	; call BIOS
;	cmp al,0	; is a scan code in ah ?
;	je here	; yes, ignore

	ret

; ===== procedure: write mark to show how booting is progressing.
; Four landmarks "B", "l", "u", "e" extracted from hello0, are displayed
; while executing code in the first sector.
; If the second sector (identified by nextid) is correctly loaded, these marks
; will be followed by "bottle loading..." at hello1 at the end..
; Otherwise the machine stops.
; in: none
; mod: ax,bx

mark:
	mov bx, [hellop]			;address of the character to display
	mov al, [bx]				; get it
	inc word [hellop]			; address of the next character

; FALL-THROUGH

; write character to the display screen
; in: al = ASCII character to display
; mod: ah
; NOTE: 3 instructions are commented because setting screen attributes
; is invalid in text mode. Found in various boot loaders though.

write:
	push ax
;	push bx
;	mov bx,7				; screen attributes: white text on black bg
	mov ah, 0eh				; display character in teletype mode
	int 10h					; call BIOS
;	pop bx
	pop ax
	ret

lbaindic:
	db 0					; lba indicator
	db 0					; free space to adjust

; message to reside in first sector

readerr:
	db 13, 10, 'I/O error!', 0

; place the Aos FS table and the boot sector signature
; these fields are initialised when a partition is formatted

	times 01f0h - ($-$$) db filler
	dd 0					; fileSystemOfs (in blocks, relative to this)
	dd 0					; fileSystemSize (in sectors)
	db 'IDID'				; id
	db 0					; version
	db 0					; sectorSizeLog2
	db 55h					; bootID0 signature (compulsory)
	db 0aah					; bootID1 signature (compulsory)
;	times sectsize - ($-$$) db filler

; end of partition boot sector
; --------------------------------------------------------------------
; start of next boot sector - contains the bootloader continuation

; used to verify that the correct sector was read by the 1st readsectors call

nextid:
	dw sectorid

; ===== procedure: locate the kernel which will be loaded at the end
; using the info supplied in the boot table

locatekernel:

; find the kernel's description in the boot table - fk. entry points

	mov si, lsize * sectsize

fk1:
	mov al, [si]			; get first type byte
	inc al
	jz $					; type = 0ffh, invalid table => halt the system
	cmp al, 8				; type = 7 (fragmented kernel) ?
	jz short fk2			; yes, kernel starting point is here
	add si, [si + 4]		; step beyond the environment info
	jmp fk1					; continue search

; note the kernel entry point for later

fk2:
	mov eax, [si + 16]		; get that entry point
	mov [kentry], eax		; save it

; issue a progress message - the follow-up of "Blue"

	push si
	mov si, hello1	; rest of message stored in boot sector #4
	call writestring
	pop si

; prepare to read the fragmented kernel

	mov bl, [si + 14]		; -chksum
	mov [sum], bl
	mov di, [si + 12]		; number of fragments
	mov eax,[si + 8]		; address
	shr eax, 4				; convert to segment
	mov es, ax				; es = address
	add si, byte 20			; si = offset of fragment desc
	ret

; ===== procedure: write a zero-terminated string - ws. entry points
; in: si = zero terminated string
; mod: ax,si

writestring:
ws1:
	lodsb					; get char of message
	cmp al, 0				; is end of message ?
	je short wsend

ws2:
	call write
	jmp ws1

wsend:
	ret

nextsector:
	sub [si + 4],cx			; number of sectors left in fragment
	jnz near rk2

	pop word [si + 4]
	pop dword [si]

	add si, byte 8			; step to next fragment
	dec di					; last fragment?
	jnz near rk1

; kernel now completely read, verify the checksum and use it.

	mov si, badchk			; point to error message
	cmp byte [sum],0		; is the checksum 0 ?
	;jne rs7	; no, error message and halt

; update the boot table
	mov si,lsize*sectsize	; boot table address

fe0:
	mov al, [si]			; get entry type
	cmp al, 8				; is it 80h ?
	jne short fe2			; no, proceed
	lea bx, [si + 8]		; get environment address
	mov [envbeg], bx		; save it
	mov bx, [si + 4]		; get environment size
	add bx, si				; address of byte after environment
	mov [envend], bx		; save it

fe2:
	inc al
	jz short fe1			; type = -1, end of table
	add si, [si + 4]		; step to next entry in table
	jmp fe0

fe1:
	mov dword [si], 3		; type = boot area (must be first of extra)
	mov dword [si + 4], 16	; size of this record
	xor eax, eax
	mov ax, cs				; boot area starts at cs:0
	shl eax, 4
	mov [si + 8], eax		; eax=boot area address
	mov dword [si + 12], 8192	; two pages
	add si, [si + 4]		; address of next entry in table

	mov ah, 88h				; get extended memory size
	int 15h					; call BIOS
	and eax, 0ffffh			; eax = size in k

	mov dword [si], 4		; free area
	mov dword [si + 4], 16	; size of this record
	mov dword [si + 8], HeapAddress	; free area (extended memory)
	shl eax, 10				; convert k to bytes

; assume this will never run on a machine without extended memory
;	jz short bt1			; no extended memory

	mov [si + 12], eax
	add si, [si + 4]		; address of next entry in table

bt1:
	cld
	push ds					; ES := DS
	pop es

; add boot table end marker

	mov dword [si], -1
	mov dword [si + 4], 0
	lea bx, [si + 8]
	mov [tabend], bx

	call InitVal
	
; There will always be environment data in the boot table!!
;	cmp [envbeg],0
;	je apm					; no environment, skip user interaction for editing the environment
							; proceed to advanced power management

; environment edit is to be controlled entirely with the shift status mask.
; when flag = 0h then booting cannot be interrupted

	cmp byte [flag], 0		; force environment edit?
	je ee0					; yes
	
	nop
	nop

	push ds
	mov ax,0
	mov ds,ax
	mov al, [417h]			; shift status byte in BIOS low address 0040h:0017h
							; 7	Insert locked
							; 6	Caps Lock locked
							; 5	Num Lock locked
							; 4	Scroll Lock locked
							; 3	Alt key is pressed
							; 2	Ctrl key is pressed
							; 1	Left Shift is pressed
							; 0	Right Shift is pressed

	pop ds
	test al, [flag]			; this mask for testing if any bit is set in the
							; shift status byte is normally 1fh = 11111b
	jnz short ee0			; if any is set, edit
	jmp near eend				; end editing

; analyze first input character

ee20:
	mov al, [bufbeg]
	and al, ~32				; force CAP

ee27:
	cmp al, 'C'				; Continue ?
	je near eend			; yes, end editing
	cmp al, 0
	je short ee0			; if 0-delimiter, show environment and edit
	cmp al, 'W'				; Write ?
	je short ee22			; yes, write boot table
	mov si, help			; anything else, write help text followed by prompt
	jmp short ee21

; write boot table

ee22:
	mov si, lsize * sectsize
	
ee24:
	cmp byte [si], 3		; find boot area (added stuff)
	je short ee23
	add si, [si + 4]
	jmp short ee24
	
ee23:
	mov dword [si], -1		; temporary disable

; NOTE: this overwrites the entry type 3 with an end of table (ffh) before
; the table is written to disk. All data which was built on the fly
; is now hidden, as it is not meant to be persistent.

;  write the boot table (sector 4 to 7, i.e. tablesize)

	mov eax, [tabsec]		; lba of the first sector to write
	mov bx,lsize * sectsize	; position in buffer where to get the data
	mov cx, tablesize		; number of sectors to write
	mov word [opcode], 4300h	; write op-code
	call writesectors		; other entry point of proc readsectors

	mov dword [si], 3		; re-enable

	mov si, wrote			; issue confirmation to console
	call writestring

; edit environment
; the sequence of operations is:
; 1 - show environment: a small parser of the configuration data
;       edits the data for the user
; 2 - issue a prompt as invitation to accept user input
; 3 - collect an input line which can be edited by the user
; 4 - analyze the received input (after detecting CR)
;       using the first input character as discriminator:
;        CR only, 'w', 'c' or else

; show environment and issue a prompt as invitation to accept user input

ee0:
	call InitVal			; process Init string value
	mov si, [envbeg]
	
se1:
	lodsb
	cmp al, 0				; 0 delimiter ?
	je short seend			; yes, end of environment
	push ax
	push si
	mov si, crlf			; move to new line
	call writestring
	pop si
	pop ax

se2:
	call write
	lodsb
	cmp al, 0				; 0 delimiter ?
	jne se2					; no, continue
	mov al, '='				; insert "=" as delimiter between name and value
	call ws2				; write that character and those which follow
							; until a terminating 0 is found
se4:
	jmp se1					; proceed to next name / value pair

seend:

; END of show environment

; show prompt

	mov si, prompt

ee21:
	call writestring

; edit input line
; out: 0-terminated input line starts at bufbeg. It can extend up to bufend

	mov di, bufbeg

; read character, analyze it, edit the line, saving the characters at bufbeg
; until a carriage return is received

el0:
	mov ah, 0
	int 16h					; call BIOS
	cmp al, 0
	je el0
	
; END of read character

; input character discrimininator: CR, backspace, normal character

	cmp al, 13				; carriage return/enter ?
	je short el3			; yes, input terminates

el1:
	cmp al, 8				; backspace ?
	jne short el2			; no, else ?
	
	cmp di, byte bufbeg		; back to the beginning of the buffer ?
		
	je el0 
	dec di 
	mov si, backsp 
	call writestring		; erase previous character and position cursor
	jmp el0

el2:
	cmp di, bufend			; now at the end of the buffer ?
	je el0					; yes,
	mov [di], al			; store that character in the buffer
	inc di					; position to next character in buffer
	call write				; write it to screen
	jmp el0					; continue input reception

el3:
	mov byte [di], 0		; 0-terminate
	
; END of edit input line - a zero-terminated line is now in the buffer

	call delins				; replace that config string
	jmp ee0					; show modified environment

eend:						; end of env editing

; ------------------------------------------------------------------

; Set the display operating mode as requested in the Init string
; Bluebottle supports only VESA modes making use of the linear frame buffer.

	mov bx, [InitBin]		; requested mode value
	cmp bx, byte 0			; (m) is it a sensible mode value ?
	je short oldInit		; (m) no, Init string is to become a subroutine

	or bx, 4000h			; use linear frame buffer
	mov ax, 4f02h			; set vbe video mode
	int 10h					; call BIOS
	jmp short apm			; (m)

; Transform the Init string to an executable assembler subroutine at bufbeg
; The Init program is a 8086 machine code program in hexadecimal. It has to
; initialize the specified display mode, possibly by making display BIOS calls
; while still operating in unprotected mode.

oldInit:
	call FindInitVal		; (m) get the code string
	mov si, bufbeg			; (m) 

in1:
	call hexdig				; (m)
	jnc short in6			; (m)
	mov ah, al				; (m)
	shl ah, 4				; (m)
	call hexdig				; (m)
	jnc short in6			; (m)
	or ah, al				; (m)
	mov [si], ah			; (m)
	inc si					; (m)
	jmp in1					; (m)
	
in6:
	mov byte [si], 0c3h		; (m) append ret instruction

; prepare execution

	pusha					; (m) 
	push ds					; (m) 
	push es					; (m) 
	mov ax, cs				; (m) 
	sub ax, 1024/16			; (m) 
	mov es, ax				; (m) es:di 1KB scratch segment
	xor di, di				; (m) zero di

; execute the Init string program stored at bufbeg

	call bufbeg				; (m) 
	pop es					; (m) 
	pop ds					; (m) 
	
	call passkpar			; (m) pass kernel parameters
	popa					; (m)
	 
; ------------------------------------------------------------------

; Advanced Power Management
; Bluebottle only supports an APM V1.1 driver which attaches to
; the APM BIOS, even if the BIOS reports that it supports V1.2.

; NOTE: this APM-related code stretch should advantagly be replaced by
; a more relevant ACPI support in the kernel. This would free up some space.

apm:
	mov ax, 5300h			; APM installation check
	
	; "http://poli.cs.vsb.cz/misc/rbint/text/1504.html"
	; "http://www.ops.dti.ne.jp/~n-yagi/pc/rad85h/rad85h2.htm"
	; "http://home.earthlink.net/~danrollins/techhelp/0031.HTM"
	; "http://eprom.myetang.com/intr/rb-1417.htm"
	
	xor bx, bx				; address BIOS (0000h)
	int 15h					; call BIOS
	jc short apmend			; carry flag set: no APM present

	mov ax, 5303h			; connect 32-bit protected mode interface

; on connection,an APM 1.1 or 1.2 BIOS switches to APM 1.0
; compatibility mode until it is infomed that the user
; supports a newer version of APM - see ax=530eh below

	xor bx, bx				; address BIOS (0000h)
	int 15h					; call BIOS
	jc short apmend			; carry flag set: no 32-bit protected mode

; initialize 32-bit code descriptor apm32

	shl eax, 4
	mov word [apm32 + 2], ax	; base 0..15
	shr eax, 16
	and al, 0fh
	mov [apm32 + 4], al		; base 16..19

; initialize 16-bit code descriptor apm16
	
	shl ecx, 4
	mov word [apm16 + 2], cx	; base 0..15
	shr ecx, 16
	and cl, 0fh
	mov [apm16 + 4], al		; base 16..19

; initialize 16-bit data descriptor apmds

	shl edx, 4
	mov word [apmds + 2], dx	; base 0..15
	shr edx, 16
	and dl, 0fh
	mov [apmds + 4], dl		; base 16..19
	mov [apmofs], ebx

	mov ax, 530eh			; set APM driver version
	xor bx,bx				; address BIOS (0000h)
	mov cx, 0101h			; APM driver version 1.1
	int 15h					; call BIOS
	jc short apmend			; carry flag set: not successful

	;mov word [gdtptr], 6*8 - 1	; 6 segments

apmend:
	mov dx, 3f2h
	mov al, 0ch
	out dx, al				; stop the floppy motor

; enable address line A20 on the 8042 keyboard controller

	cli
	call empty8042			; empty the 8042 of any queued characters
	mov al,0d1h				; write to output port
	out 64h, al				; send to the command register port
	call empty8042			; empty the 8042 of any queued characters
	mov al, 0dfh			; signal gate A20 on
	out 60h, al				; send Keyboard Controller Command Byte KCCB
	call empty8042			; empty the 8042 of any queued characters

; disable hardware interrupts

	mov al, -1				; mask 0ffh
	out 21h, al				; mask off IRQ0-7, all interrupts on master PIC
	out 0a1h, al			; mask off IRQ8-15, all interrupts on slave PIC

	mov ax, 1020h			; do 16 EOI's

di1:
	out 20h, al
	xor cx, cx
	loop $					; small pause
	dec ah
	jnz di1

; prepare long mode initialization

	xor eax, eax
	mov ax, cs
	shl eax, 4
	
	or [lgdtdesc + 2], eax		; adjust absolute offsets
	or [jmp32 + 2], eax
	
	lidt [lidtdesc]				; load empty interrupt table
	lgdt [lgdtdesc]				; load segment table for temporary and 64bit segments
	
	xor eax, eax				; enable protected mode
	mov ax, ss
	shl eax, 4
	
	mov edx, eax

	add eax, lsize * sectsize	; save the kernel data
	push eax
	push dword [kpar0]
	push dword [kpar1]
	
	xor eax, eax
	mov ebp, eax
	mov ax, sp
	add edx, eax

	mov eax, cr0
	bts eax, 0
	mov cr0, eax
	
jmp32:							; jump to protected mode
	db 066h
	db 0eah
	dd protmode
	dw bootcode - gdt
	
bits 32
protmode:

	mov ax, bootdata - gdt	; adjust segment register
	mov ss, ax
	mov ds, ax
	mov es, ax

	mov esp, edx

	mov eax, cr4			; enable physical page extensions CR4.PAE := 1
	bts eax, 5
	mov cr4, eax
	
	xor eax, eax			; create a dummy page table
	mov ecx, 1024 * 3
	mov edi, PML4
	
	rep stosd
	
	mov [PML4], dword PDPE + 7h	; identity map the first 2MB
	mov [PDPE], dword PDE + 7h
	mov [PDE], dword 87h

	mov eax, PML4				; set address of page table
	mov cr3, eax
	
	mov ecx, 0c0000080h			; enable long mode
	rdmsr
	bts eax, 8
	wrmsr

	mov eax, cr0					; enable paging CR0.PGE :=  1
	bts eax, 31
	mov cr0, eax
	
	pop edi						; get initial values for AosBoot
	pop esi
	pop eax
	
jmp64:								; jump right into kernel code
	db 0eah
kentry: dd 0
	dw kernelcode - gdt

bits 16
	


; load descriptor tables

;	lidt [idtptr]			; load IDT with all zeroes
;	xor eax, eax			; clear
;	mov ax, cs
;	shl eax, 4
;	add eax, gdt
;	mov [gdtptr + 2], eax
;	lgdt [gdtptr]			; load GDT

; set up stack

;	o32 push byte 1*8		; kernel code segment selector
;	push dword [kentry]		; kernel entry point
;
;	xor edx, edx
;	mov dx, ss
;	shl edx, 4
;	mov eax, edx
;	add eax, lsize * sectsize
;	push eax
;	push dword [kpar0]
	
; pass the 32-bit physical address of the frame buffer to
; AosBoot.Mod and AosDisplayLinear.Mod

;	push dword [kpar1]

;	xor eax, eax
;	mov ebp, eax			; clear ebp
;	mov ax, sp
;	add edx, eax			; edx = value for esp
;	mov esp, edx
;	pop edi					; kpar1
;	pop esi					; kpar0
;	pop eax					; boot table linear address

; ------------------------------------------------------------------

; Enter 80286 protected mode

;	smsw ax					; store machine status word
;	or al, 1				; set Protection Enable bit (PE)
;	lmsw ax					; load machine status word

; The previous 3 instructions have the same effect as:

;	mov eax,cr0
;	or al,1
;	mov cr0,eax

	jmp short kd0			; flush instruction (prefetch) queue

; load segment selectors

kd0:
;	mov ax, 2*8				; kernel data segment selector
;	mov ss, ax
;	mov ds, ax
;	mov es, ax
;	mov fs, ax
;	mov gs, ax

; jump to kernel

;	mov esp, edx
;	pop edi					; kpar1
;	pop esi					; kpar0
;	pop eax					; boot table linear address
;	db 066h					; prefix followed by jmp opcode
;	retf					; jump to kernel via AosBoot.Mod as 1st module
	
; Using the operation prefix 066h, the CPU takes the 48-bit far pointer
; correctly
; INTEL 80386 Programmer;s Reference Manual,
; Mixing 16-bit and 32-bit code, page 16-6
; ------------------------------------------------------------------

; ===== procedure: pass the parameters to the kernel

passkpar:

	mov [kpar0], ax			; save horizontal resolution
	mov [kpar0+2], bx		; save vertical resolution
	mov [kpar1], cx			; save linear frame buffer address
	mov [kpar1+2], dx
	ret

; ===== procedure: replace a config string: delete and insert at the end

delins:

; scan the input line searching for a '=' delimiter of name and value

	mov di, bufbeg
	
ee12:
	cmp byte [di], 0
	je near ee20					; no '=' found
	inc di
	cmp byte [di], '='
	jne ee12
	mov byte [di], 0		; zero terminate name
	inc di					; di=new value, bufbeg=name

; delete existing value, if any, that is, replace it

	cmp byte [di], 0		; empty value?
	jne short ee25
	mov di, bufbeg0			; will delete old and not add new

ee25:
	push di;				assume cld & ds,es=code

ee10:
	call findname			; find the specified name in the environment
	cmp al, 0
	jne short ee4			; name not found

ee2:
	inc di					; point to value
	cmp [di], al
	jne ee2					; skip value
	inc di					; di = next name

	mov si, bx
	xchg si, di				; di=delete name, si=next name

; copy a series of name,value pairs until end of env is hit

ee8:
	lodsb					; copy from si to di
	stosb
	cmp al, 0				; end of env?
	je short ee5			; yes, go copy rest of table
	call movnam				; copy a full name
	call movnam				; copy a full value
	jmp ee8					; go copy next name,value pair

ee5:
	sub di, [envbeg]		; di = size of new env
	test di, 3
	jz short ee9			; yes, is multiple of 4
	or di, byte + 3
	inc di					; make multiple of 4

ee9:
	add di, byte 8			; convert to recsize
	mov si, [envbeg]
	xchg di, [si - 4]		; di=old recsize, recsize=di (new)
	mov cx, di
	sub cx, [si - 4]		; cx=old-new=diff in recsize
	jcxz ee11
	mov si, [envend]
	mov di, si
	sub di, cx
	sub [envend], cx		; set new vars
	sub [tabend], cx
	mov cx, [tabend]		; number of bytes to move
	sub cx, [envend]
	rep movsb				; move the rest of the table down

ee11:
	jmp ee10				; loop, delete again

ee4:
	mov di, [envbeg]		; end of delete
	mov cx, -1
	mov al, 0

ee16:
	cmp [di], al			; end of env ?
	je short ee15
	repne scasb				; skip name
	repne scasb				; skip value
	jmp ee16

ee15:
	mov si, di				; si = adr of last 0
	inc di
	sub di, [envbeg]
	mov bx, di				; bx = env length

	pop di					; di = new value
	push si					; save adr of last 0
	repne scasb				; scan until end of new value

	sub di, byte bufbeg		; length of new name,value

	mov ax, bx				; ax = envlen
	mov bx, di				; bx = length {bx >= 0}  (was 3)

	add ax, 8
	mov si, [envbeg]
	sub ax, [si - 4]		; ax = -pad = -(env recsize-8-envlen)
	add ax, bx				; ax = length-pad
	test ax, 3
	jz short ee17			; multiple of 4
	or al, 3
	inc ax					; make multiple of 4

ee17:						; ax = up4(length-pad)
	mov cx, [tabend]
	sub cx, [envend]		; bytes to move
	mov si, [envend]		; source
	mov di, si
	add di, ax				; destination
	add [envend], ax		; shift the vars
	add [tabend], ax
	mov ax, cx				; adjust for copy overlap
	dec ax
	add si, ax
	add di, ax
	std						; copy backwards
	rep movsb				; make space

	cld
	mov si, bufbeg
	pop di					; di = adr of last 0
	mov cx, bx				; cx = bx = length of name,val
	rep movsb
	mov byte [di], 0		; add last 0

	mov si, [envbeg]
	mov ax, [envend]
	sub ax, si
	add ax, 8
	mov [si - 4], ax		; set new recsize

	ret

; ===== procedure: move a name to the beginning of the buffer
; in: si = pointer to source string; di = pointer to destination string
; out: si = pointer to source end + 1; di = pointer to destination end + 1
; mod: al

movstring:
	mov di, bufbeg			; destination

movnam:
	lodsb					; assume es=ds & cld
	stosb
	cmp al,0
	jne movnam
	ret

; ===== procedure: find the specified name in the environment
; the environment is structured as: { name 00h value 00h } 00h
; mod: di = pointer to env beginning
;          si = pointer to bufbeg where the name to find was moved
; out: bx = points to name start position in env
;          di = pointer to 00h following the name found

findname:
	mov di, [envbeg]		; env beginning

fn1:
	mov si, bufbeg			; name to find starts here
	mov bx, di				; save start of name
	mov al, 0				; character on which scanning must halt (scasb)

fn2:
	cmp [si], al			; end of name in buf?
	je short fn3			; yes, see if end of name in env too
	cmpsb					; compare characters at DS:SI and ES:DI and incr SI DI
	je fn2					; repeat with next character
	dec di					; undo inc at mismatch
	jmp short fn4			; do not delete if mismatch

fn3:
	cmp [di], al			; end of name in env ?
	je short fnend			; yes, matching name found

fn4:
	mov cx,-1
	repne scasb				; scan for end of name
	repne scasb				; and skip value
	cmp byte [di], 0		; end of env ?
	jne fn1					; no, repeat comparison test on next name
	mov al, -1				; mark as "not found"

fnend:
	ret

; ===== procedure: wait until the 8042 buffer is empty
; mod: al

empty8042:
e0:
	in al, 64h				; get keyboard controller status
	and al, 2
	jnz e0					; repeat if not empty
	ret

; ===== procedure: convert an ASCII character to hex half-byte
; in: di = pointer to character to convert
; out: al = hex half-byte (0 .. 9, A .. F), carry = ok, no carry = error
;        di = pointer to next character

hexdig:
	mov al, [di]			; get character
	cmp al, 0				; is zero-delimiter (carry is set)?
	je short hdclc
	inc di					; point to next one
	sub al, '0'				; convert to pure binary
	cmp al, 10				; 0 .. 9 produce a carry
	jc short hdend
	and al, ~32				; force CAP
	sub al, 7
	cmp al, 16				; 10 .. 15 produce a carry
	jc short hdend
	
hdclc:
	clc						; clear carry to signal error

hdend:
	ret


; ===== procedure: convert integer to character string with 0-terminator
; in: ax = 16-bit value
;      di pointer to first character of zero-delimited string

int2char:
	mov bx, 10				; conversion base
	mov cx, 4				; number of digits to produce
	add di, byte 3
	mov byte [di], 0		; make a zero-delimited string
	dec di

nxtdig:
	xor dx, dx				; extend ax to 32-bit dx:ax
	div bx					; ax <- dx:ax div bx, dx <- remainder
	or dl, '0'				; make it '0'+ ASCII-based
	mov [di], dl			; stow away in buffer
	dec di					; place right to left in buffer
	loop nxtdig				; loop on count in cx
	call delins				; replace that config string
	ret

; ===== procedure: find the Init string and its value

FindInitVal:
	mov si, init			; point to string to find
	call movstring			; copy init string to buf
	call findname			; find it
	inc di					; point to Init value (mode or prog.)
	ret

; ===== procedure: find the Init string and interrogate the graphic card
; to collect important values characterizing the specified video mode
; all this is done before the machine is switched to protected mode.
; The Init string is either a 3-character value specifying the video mode,
; e.g. 11B, for operating with 60Hz refresh rate or a program string.

InitVal:
	call FindInitVal

	mov word [InitBin], 0	; (m) clear to signal long Init
	cmp byte [di+3], 0		; (m) value specifies 3-char mode ?
	jne near exit			; (m) no, program string

; convert the Init string value (3-hexadecimal characters
; such as '11a' for example), to a packed hexadecimal in cx

	call hexdig				; pack most significant digit
	mov ch, al				; save it
	call hexdig				; pack second character
	mov ah, al
	shl ah, 4
	call hexdig				; pack third character
	or ah, al
	mov cl, ah
	
; cx now holds the mode value defined under Init= in packed form

	mov [InitBin], cx		; save it for later

; extract values characterizing this mode from the vbe information
; "http://www.geocities.com/SiliconValley/Park/8933/vesa.html"

	pusha					; push all registers
	push es					; es will be dedicated to the vbe info

; prepare to receive the vbe mode information in a dedicated area es:di

	mov ax, cs				; current code segment
	sub ax, 1024/16			; the preceeding segment
	mov es, ax				; es:0 = 1k scratch segment
	mov di, 0				; clear

; NOTE: it is not clear why the ATI Technology AGP graphic card Fire GL8800
; requires this 2-instruction kick to respond properly to the subsequent
; read vbe mode sollicitation. Other cards do not require that.

	mov ax, 4f00h			; read vbe controller information
	int 10h					; call BIOS
	mov ax, 4f01h			; read vbe mode information
	int 10h					; call BIOS
	cmp ax, 004fh			; is the mode supported ?
	je short modeok			; yes
	xor ax, ax				; use ax = 0 to denote error carried ...
	jmp short wrong			; forward in kpar0

modeok:
	xor ax, ax
	mov al, [es:di + 19h]	; bits per pixel
	mov si,ax
	mov ax, [es:di + 12h]	; horizontal resolution in pixels
	mov bx, [es:di + 14h]	; vertical resolution in pixels

; load cx and dx with physical address of linear frame buffer

	mov cx, [es:di + 28h]
	mov dx, [es:di + 2ah]

wrong:
	pop es
	mov word [depth], si	; save bits per pixel
	call passkpar			; pass kernel parameters
	popa					; pop all registers

	cmp word [kpar0], byte 0	; kpar0 carries the error indication
	jne short repl			; no error

isinval:
	mov si, invalid
	call writestring
	jmp short exit

repl:
	cmp dword [kpar1], byte 0	; is linear frame buffer address nil ?
	je isinval				; yes, is invalid

; create a string at bufbeg for replacing the current DWidth config string

	mov si, DWidth
	call movstring
	mov ax, word [kpar0]	; horiz. resolution to convert to char.
	call int2char			; and replace in config

; create a string at bufbeg for replacing the current DHeight config string

	mov si, DHeight
	call movstring
	mov ax, word [kpar0 + 2]	; vertical resolution to convert to char.
	call int2char			; and replace in config

; create a string at bufbeg for replacing the current DDepth config string

	mov si, DDepth
	call movstring
	mov ax, [depth]			; bits per pixel to convert to char.
	call int2char			; and replace in config

exit:
	ret

; strings used to construct replacing strings in InitVal

DWidth:	db 'DWidth=', 0
DHeight:	db 'DHeight=', 0
DDepth:	db 'DDepth=', 0

	db	'&&&&&&&'			; free space to adjust

; more data fields

envbeg:	dw 0				; actual first char of env

; A collection of zero-terminated strings to send to the display
; as user messages by calling writestring

invalid:	db 'Invalid '
init:	db 'Init', 0
hello1:	db 'bottle loading', 0
backsp:	db 8, ' ', 8, 0		; reply to backspace
wrote:	db ' Done!'			; reply to 'w'
crlf:	db 13, 10, 0
badchk:	db 'Bad BBL.Bin', 0

; help info packet sent as reply to anything else than listed

help:	db 13, 10, 'Help:'
	db 13, 10, 'set name=val'
	db 13, 10, 'delete name='
	db 13, 10, 'continue c'
	db 13, 10, 'write config w'

prompt:	db 13, 10, 10, 'BBL0>', 0

; 'BBL' to denote the difference with 'OBL' used in earlier versions
; The ending character is destined to identify the version (0 .. 9, a .. z),
; a poor man's solution dictated by the lack of space.

; Global descriptor table (see ref)

times (8 - ($-$$) % 8) % 8 nop		; align on 8 byte boundary

;gdt	db 0, 0, 0, 0, 0, 0, 0, 0				; null descriptor
;	db 0ffh, 0ffh, 0, 0, 0, 9ah, 0cfh, 0	; kernel code segment
;	db 0ffh, 0ffh, 0, 0, 0, 92h, 0cfh, 0	; kernel data segment


;gdtptr	dw 3 * 8 - 1, 0, 0	; 48-bit pointer to gdt
;	dw 0
	
gdt:
	dd 0, 0
	
bootcode:							; legacy code segment
	dd 0000ffffh
	dd 00cf9b00h

kernelcode:							; 64bit code segment
	dd 00000000h
	dd 00209b00h

bootdata:
	dd 0000ffffh
	dd 00cf9300h

apm32:	db 0ffh, 0ffh, 0, 0, 0, 9ah, 0cfh, 0	; APM 32-bit code segment
apm16:	db 0ffh, 0ffh, 0, 0, 0, 9ah, 000h, 0	; APM 16-bit code segment
apmds:	db 0ffh, 0ffh, 0, 0, 0, 92h, 0cfh, 0	; APM 32-bit data segment
apmofs:	dd 0									; APM entry point (directly after GDT)

gdtend:
lgdtdesc:
	dw gdtend - gdt
	dd gdt
	
lidtdesc:
	dw 0
	dd 0				; 48-bit null pointer

; fill rest of loader, and check if size ok

	times lsize * sectsize - ($-$$) db filler

absolute entry0

kpar0:	resw 1				; kernel parameter 1  - AX:BX
							; re-used for storing horizontal resolution
		resw 1				; contains vertical resolution
kpar1:	resd 1				; kernel parameter 2 - CX:DX
;kentry	resd 1				; kernel entry point

envend:	resw 1				; next entry after env
tabend:	resw 1				; next entry after table
tabsec:	resd 1				; sector where table starts

depth:	resw 1				; bits per pixel (video mode)
opcode:	resw 1				; temporary save area
InitBin:	resw 1				; video mode value as integer


; assemble this with file with
; PCAAMD64.Assemble Bbl.S~
