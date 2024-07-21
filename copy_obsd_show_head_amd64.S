/* Thanks to: */
/*	$OpenBSD: asm.h,v 1.24 2023/04/17 00:02:14 deraadt Exp $	*/
/*	$NetBSD: asm.h,v 1.2 2003/05/02 18:05:47 yamt Exp $	*/

/*-
 * Copyright (c) 1990 The Regents of the University of California.
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	@(#)asm.h	5.5 (Berkeley) 5/7/91
 */

#ifndef _MACHINE_ASM_H_
#define _MACHINE_ASM_H_

#ifdef __PIC__
#define PIC_PLT(x)	x@PLT
#define PIC_GOT(x)	x@GOTPCREL(%rip)
#else
#define PIC_PLT(x)	x
#define PIC_GOT(x)	x
#endif

# define _C_LABEL(x)	x
#define	_ASM_LABEL(x)	x

#define CVAROFF(x,y)		(x+y)(%rip)

#ifdef __STDC__
# define __CONCAT(x,y)	x ## y
# define __STRING(x)	#x
#else
# define __CONCAT(x,y)	x/**/y
# define __STRING(x)	"x"
#endif

/* let kernels and others override entrypoint alignment */
#ifndef _ALIGN_TEXT
#define _ALIGN_TEXT	.align	16, 0x90
#endif
#define _ALIGN_TRAPS	.align	16, 0xcc

#define	_FENTRY(x)	.type x,@function; x:

/* NB == No Binding: use .globl or .weak as necessary */
#define	NENTRY_NB(x)	\
	.text; _ALIGN_TEXT; _FENTRY(x)
#define _ENTRY_NB(x) \
	.text; _ALIGN_TRAPS; _FENTRY(x)
#define _ENTRY(x)	.globl x; _ENTRY_NB(x)
#define _NENTRY(x)	.globl x; NENTRY_NB(x)

#ifdef _KERNEL
#define	KUTEXT	.section .kutext, "ax", @progbits

#define	KUTEXT_PAGE_START	.pushsection .kutext.page, "a", @progbits
#define	KTEXT_PAGE_START	.pushsection .ktext.page, "ax", @progbits
#define	KUTEXT_PAGE_END		.popsection
#define	KTEXT_PAGE_END		.popsection

#define	IDTVEC(name) \
	KUTEXT; _ALIGN_TRAPS; IDTVEC_NOALIGN(name); endbr64
#define	GENTRY(x)		.globl x; _FENTRY(x)
#define	IDTVEC_NOALIGN(name)	GENTRY(X ## name)
#define	IDTVEC_ALIAS(alias,sym)						\
	.global X ## alias;						\
	X ## alias = X ## sym;
#define	KIDTVEC(name) \
	.text; _ALIGN_TRAPS; IDTVEC_NOALIGN(name); endbr64
#define	KIDTVEC_FALLTHROUGH(name) \
	_ALIGN_TEXT; IDTVEC_NOALIGN(name)
#define KUENTRY(x) \
	KUTEXT; _ALIGN_TRAPS; GENTRY(x)

/* Return stack refill, to prevent speculation attacks on natural returns */
#define	RET_STACK_REFILL_WITH_RCX	\
		mov	$8,%rcx		; \
		_ALIGN_TEXT		; \
	3:	call	5f		; \
	4:	pause			; \
		lfence			; \
		call	4b		; \
		_ALIGN_TRAPS		; \
	5:	call	7f		; \
	6:	pause			; \
		lfence			; \
		call	6b		; \
		_ALIGN_TRAPS		; \
	7:	loop	3b		; \
		add	$(16*8),%rsp

#endif /* _KERNEL */

#ifdef __STDC__
#define CPUVAR(off)	%gs:CPU_INFO_ ## off
#else
#define CPUVAR(off)     %gs:CPU_INFO_/**/off
#endif


#if defined(PROF) || defined(GPROF)
# define _PROF_PROLOGUE	\
	pushq %rbp; leaq (%rsp),%rbp; call PIC_PLT(__mcount); popq %rbp
#else
# define _PROF_PROLOGUE
#endif

#if defined(_RET_PROTECTOR)
# define RETGUARD_SETUP_OFF(x, reg, off) \
	RETGUARD_SYMBOL(x); \
	movq (__retguard_ ## x)(%rip), %reg; \
	xorq off(%rsp), %reg
# define RETGUARD_SETUP(x, reg) \
	RETGUARD_SETUP_OFF(x, reg, 0)
# define RETGUARD_CHECK(x, reg) \
	xorq (%rsp), %reg; \
	cmpq (__retguard_ ## x)(%rip), %reg; \
	je 66f; \
	int3; int3; \
	.zero (0xf - ((. + 3 - x) & 0xf)), 0xcc; \
66:
# define RETGUARD_PUSH(reg) \
	pushq %reg
# define RETGUARD_POP(reg) \
	popq %reg
# define RETGUARD_SYMBOL(x) \
	.ifndef __retguard_ ## x; \
	.hidden __retguard_ ## x; \
	.type   __retguard_ ## x,@object; \
	.pushsection .openbsd.randomdata.retguard,"aw",@progbits; \
	.weak   __retguard_ ## x; \
	.p2align 3; \
	__retguard_ ## x: ; \
	.quad 0; \
	.size __retguard_ ## x, 8; \
	.popsection; \
	.endif
#else
# define RETGUARD_SETUP_OFF(x, reg, off)
# define RETGUARD_SETUP(x, reg)
# define RETGUARD_CHECK(x, reg)
# define RETGUARD_PUSH(reg)
# define RETGUARD_POP(reg)
# define RETGUARD_SYMBOL(x)
#endif

#define	ENTRY(y)	_ENTRY(y); endbr64; _PROF_PROLOGUE
#define	NENTRY(y)	_NENTRY(y)
#define	ASENTRY(y)	_NENTRY(y); endbr64; _PROF_PROLOGUE
#define	ENTRY_NB(y)	_ENTRY_NB(y); endbr64; _PROF_PROLOGUE
#define	END(y)		.size y, . - y

#define	STRONG_ALIAS(alias,sym)						\
	.global alias;							\
	alias = sym
#define	WEAK_ALIAS(alias,sym)						\
	.weak alias;							\
	alias = sym

/* generic retpoline ("return trampoline") generator */
#define	JMP_RETPOLINE(reg)		\
		call	69f		; \
	68:	pause			; \
		lfence			; \
		jmp	68b		; \
		_ALIGN_TRAPS		; \
	69:	mov	%reg,(%rsp)	; \
		ret			; \
		lfence

#endif /* !_MACHINE_ASM_H_ */
/* Thanks to: */
/*	$OpenBSD: mbr.S,v 1.9 2022/09/02 07:46:03 krw Exp $	*/

/* Copyright (c) 2024 AC (to show only head of the sectors to the screen.) */
/*
 * Copyright (c) 1997 Michael Shalayeff and Tobias Weingartner
 * Copyright (c) 2003 Tom Cosgrove <tom.cosgrove@arches-consulting.com>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR 
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */
/* Copyright (c) 1996 VaX#n8 (vax@linkdead.paranoia.com)
 * last edited 9 July 1996
 * many thanks to Erich Boleyn (erich@uruk.org) for putting up with
 * all my questions, and for his work on GRUB
 * You may use this code or fragments thereof in a manner consistent
 * with the other copyrights as long as you retain my pseudonym and
 * this copyright notice in the file.
 */

	.file	"copy_obsd_show_head.S"

/* Thanks to /sys/kern/genassym.sh with struct offset. */
#define CPU_INFO_APICID 44
#define CPU_INFO_CPUID 40
#define CPU_INFO_CURPCB 1088
#define CPU_INFO_CURPROC 120
#define CPU_INFO_GDT 2080
#define CPU_INFO_IDEPTH 1636
#define CPU_INFO_IDLE_PCB 1096
#define CPU_INFO_ILEVEL 1632
#define CPU_INFO_INTR_RSP 64
#define CPU_INFO_IPENDING 1624
#define CPU_INFO_ISOURCES 1112
#define CPU_INFO_IUNMASK 1776
#define CPU_INFO_KERN_CR3 0
#define CPU_INFO_KERN_RSP 56
#define CPU_INFO_MDS_BUF 112
#define CPU_INFO_MDS_TMP 80
#define CPU_INFO_MUTEX_LEVEL 1904
#define CPU_INFO_PFLAGS 1104
#define CPU_INFO_PROC_PMAP 1072
#define CPU_INFO_RESCHED 2068
#define CPU_INFO_SCRATCH 8
#define CPU_INFO_SELF 24
#define CPU_INFO_SIZEOF 3552
#define CPU_INFO_TSS 2072
#define CPU_INFO_USER_CR3 72
#define CPU_INFO_USER_PMAP 1080

/*
 * Memory layout:
 *
 * 0x07C00 -> 0x07DFF	BIOS loads us here	(at  31k)
 * 0x07E00 -> 0x17BFC	our stack		(to  95k)
 *
 * 0x07A00 -> 0x07BFF	we relocate to here	(at  30k5)
 *
 * 0x07C00 -> 0x07DFF	we load PBR here	(at  31k)
 *
 * The BIOS loads us at physical address 0x07C00.  We use a long jmp to
 * normalise our address to seg:offset 07C0:0000.  We then relocate to
 * 0x07A00, seg:offset 07A0:0000.
 *
 * We use a long jmp to normalise our address to seg:offset 07A0:0000
 * We set the stack to start at 07C0:FFFC (grows down on i386)
 * The partition boot record (PBR) loads /boot at seg:offset 4000:0000
 */
#define BOOTSEG		0x7c0	/* segment where we are loaded */
#define BOOTRELOCSEG	0x7a0	/* segment where we relocate to */
#define BOOTSTACKOFF	0xfffc	/* stack starts here, grows down */
#define PARTSZ		16	/* each partition table entry is 16 bytes */

#define CHAR_LBA_READ	'.'
#define CHAR_CHS_READ	';'

#define CHAR_S		'S'	/* started */
#define CHAR_R		'R'	/* relocated */
#define CHAR_L		'L'	/* looking for bootable partition */
#define CHAR_D		'D'	/* start to dump */

#define DBGMSG(c)	movb	$c, %al;	call	Lchr

/* Clobbers %al - maybe more */
#define	putc(c)		movb	$c, %al;	call	Lchr

/* Clobbers %esi - maybe more */
#define	puts(s)		movw	$s, %si;	call	Lmessage


	.text
	.code16

	.globl	start
start:
	/* Adjust %cs to be right */
	ljmp 	$BOOTSEG, $1f
1:
	/* Set up stack */
	movw	%cs, %ax

	/*
	 * We don't need to disable and re-enable interrupts around the
	 * the load of ss and sp.
	 *
	 * From 80386 Programmer's Reference Manual:
	 * "A MOV into SS inhibits all interrupts until after the execution
	 * of the next instruction (which is presumably a MOV into eSP)"
	 *
	 * According to Hamarsoft's 86BUGS list (which is distributed with
	 * Ralph Brown's Interrupt List), some early 8086/88 processors
	 * failed to disable interrupts following a load into a segment
	 * register, but this was fixed with later steppings.
	 *
	 * Accordingly, this code will fail on very early 8086/88s, but
	 * nick@ will just have to live with it.  Others will note that
	 * we require at least a Pentium compatible processor anyway.
	 */
	/* cli */
	movw	%ax, %ss
	movw	$BOOTSTACKOFF, %sp
	/* sti */			/* XXX not necessary; see above */

	/* Set up data segment */
	movw	%ax, %ds
	DBGMSG(CHAR_S)

	/*
	 * On the PC architecture, the boot record (originally on a floppy
	 * disk) is loaded at 0000:7C00 (hex) and execution starts at the
	 * beginning.
	 *
	 * When hard disk support was added, a scheme to partition disks into
	 * four separate partitions was used, to allow multiple operating
	 * systems to be installed on the one disk.  The boot sectors of the
	 * operating systems on each partition would of course expect to be
	 * loaded at 0000:7C00.
	 *
	 * The first sector of the hard disk is the master boot record (MBR).
	 * It is this which defines the partitions and says which one is
	 * bootable.  Of course, the BIOS loads the MBR at 0000:7C00, the
	 * same location where the MBR needs to load the partition boot
	 * record (PBR, called biosboot in OpenBSD).
	 *
	 * Therefore, the MBR needs to relocate itself before loading the PBR.
	 *
	 * Make it so.
	 */
	movw	$BOOTRELOCSEG, %ax
	movw	%ax, %es
	xorw	%si, %si
	xorw	%di, %di
	movw	$0x200, %cx		/* Bytes in MBR, relocate it all */
	cld
	rep
	movsb

	/* Jump to relocated self */
	ljmp $BOOTRELOCSEG, $reloc
reloc:
	DBGMSG(CHAR_R)

	/* Set up %es and %ds */
	pushw	%ds
	popw	%es	/* next boot is at the same place as we were loaded */
	pushw	%cs
	popw	%ds	/* and %ds is at the %cs */

#ifdef SERIAL
	/* Initialize the serial port to 9600 baud, 8N1.
	 */
	pushw	%dx
	xorw	%ax, %ax
	movb	$0xe3, %ax
	movw	$SERIAL, %dx
	int	$0x14
	popw	%dx
#endif

	/* BIOS passes us drive number in %dl
	 *
	 * XXX - This is not always true.  We currently check if %dl
	 * points to a HD, and if not we complain, and set it to point
	 * to the first HDD.  Note, this is not 100% correct, since
	 * there is a possibility that you boot from HD #2, and still
	 * get (%dl & 0x80) == 0x00, these type of systems will lose.
	 */
	testb	$0x80, %dl
	jnz	drive_ok

	/* MBR on floppy or old BIOS
	 * Note: MBR (this code) should never be on a floppy.  It does
	 * not belong there, so %dl should never be 0x00.
	 *
	 * Here we simply complain (should we?), and then hardcode the
	 * boot drive to 0x80.
	 */
	puts(efdmbr)

	/* If we are passed bogus data, set it to HD #1
	 */
	movb	$0x80, %dl

drive_ok:
	DBGMSG(CHAR_D)

	/* Store the drive number (from %dl) in decimal */
	movb	%dl, %al
	andb	$0x0F, %al
	addb	$'0', %al
	movb	%al, drive_num

	/*
	 * Store the partition number, in decimal.
	 *
	 * We started with cx = 4; if found we want part '0'
	 *                 cx = 3;                  part '1'
	 *                 cx = 2;                  part '2'
	 *                 cx = 1;                  part '3'
	 *
	 * We'll come into this with no other values for cl.
	 */
	movb	$'0'+4, %al
	subb	%cl, %al
	movb	%al, part_num

	/*
	 * Tell operator what partition we're trying to boot.
	 *
	 * Using drive X, partition Y
	 * - this used to be printed out after successfully loading the
	 *   partition boot record; we now print it out before
	 */
	pushw	%si
	movw	$info, %si
	call	Lmessage
	popw	%si

	/*
	 * Partition table entry format:
	 *
	 * 0x00	BYTE boot indicator (0x80 = active, 0x00 = inactive)
	 * 0x01	BYTE start head
	 * 0x02	WORD start cylinder, sector
	 * 0x04	BYTE system type (0xA6 = OpenBSD)
	 * 0x05 BYTE end head
	 * 0x06	WORD end cylinder, sector
	 * 0x08	LONG start LBA sector
	 * 0x0C	LONG number of sectors in partition
	 *
	 * In the case of a partition that extends beyond the 8GB boundary,
	 * the LBA values will be correct, the CHS values will have their
	 * maximums (typically (C,H,S) = (1023,255,63)).
	 *
	 * %ds:%si points to the active partition table entry.
	 */

	/* We will load the partition boot sector (biosboot) where we
	 * were originally loaded.  We'll check to make sure something
	 * valid comes in.  So that we don't find ourselves, zero out
	 * the signature at the end.
	 */
	movw	$0, %es:signature(,1)

	/*
	 * We will use the LBA sector number if we have LBA support,
	 * so find out.
	 */

	/*
	 * BIOS call "INT 0x13 Extensions Installation Check"
	 *	Call with	%ah = 0x41
	 *			%bx = 0x55AA
	 *			%dl = drive (0x80 for 1st hd, 0x81 for 2nd, etc)
	 *	Return:
	 *			carry set: failure
	 *				%ah = error code (0x01, invalid func)
	 *			carry clear: success
	 *				%bx = 0xAA55 (must verify)
	 *				%ah = major version of extensions
	 *				%al   (internal use)
	 *				%cx = capabilities bitmap
	 *					0x0001 - extnd disk access funcs
	 *					0x0002 - rem. drive ctrl funcs
	 *					0x0004 - EDD functions with EBP
	 *				%dx   (extension version?)
	 */

	movb	%dl, (%si)		/* Store drive here temporarily */
					/* (This call trashes %dl) */
					/*
					 * XXX This is actually the correct
					 *     place to store this.  The 0x80
					 *     value used to indicate the
					 *     active partition is by intention
					 *     the same as the BIOS drive value
					 *     for the first hard disk (0x80).
					 *     At one point, 0x81 would go here
					 *     for the second hard disk; the
					 *     0x80 value is often used as a
					 *     bit flag for testing, rather
					 *     than an exact byte value.
					 */
	movw	$0x55AA, %bx
	movb	$0x41, %ah
	int	$0x13

	movb	(%si), %dl		/* Get back drive number */

	jc	do_chs			/* Did the command work? Jump if not */
	cmpw	$0xAA55, %bx		/* Check that bl, bh exchanged */
	jne	do_chs			/* If not, don't have EDD extensions */
	testb	$0x01, %cl		/* And do we have "read" available? */
	jz	do_chs			/* Again, use CHS if not */

do_lba:
	/*
	 * BIOS call "INT 0x13 Extensions Extended Read"
	 *	Call with	%ah = 0x42
	 *			%dl = drive (0x80 for 1st hd, 0x81 for 2nd, etc)
	 *			%ds:%si = segment:offset of command packet
	 *	Return:
	 *			carry set: failure
	 *				%ah = error code (0x01, invalid func)
	 *				command packet's sector count field set
	 *				to the number of sectors successfully
	 *				transferred
	 *			carry clear: success
	 *				%ah = 0 (success)
	 *	Command Packet:
	 *			0x0000	BYTE	packet size (0x10 or 0x18)
	 *			0x0001	BYTE	reserved (should be 0)
	 *			0x0002	WORD	sectors to transfer (max 127)
	 *			0x0004	DWORD	seg:offset of transfer buffer
	 *			0x0008	QWORD	starting sector number
	 */
	movb	$CHAR_LBA_READ, %al
	call	Lchr

	/* Load LBA sector number from active partition table entry */
	xorl	%ecx, %ecx
lba_retry:
	movl	%ecx, lba_sector

	pushw	%si			/* We'll need %si later */

	movb	$0x42, %ah
	movw	$lba_command, %si
	int	$0x13

	popw	%si			/* get back %si */

	pushw	$1
	call	we_dump
	addw	$2, %sp
	
	incl	%ecx
	cmpl	CNT_SECT, %ecx
	jl	lba_retry

	/* Dump and loop here. (XXX not implemented.) */
	jnc	stay_stopped		/* Done dump, halt */

	/*
	 * LBA read failed, fall through to try CHS read
	 */

do_chs:
	/*
	 * BIOS call "INT 0x13 Function 0x2" to read sectors from disk into
	 * memory
	 *       Call with       %ah = 0x2
	 *                       %al = number of sectors
	 *                       %ch = cylinder & 0xFF
	 *                       %cl = sector (0-63) | rest of cylinder bits
	 *                       %dh = head
	 *                       %dl = drive (0x80 for hard disk)
	 *                       %es:%bx = segment:offset of buffer
	 *       Return:
	 *                       carry set: failure
	 *                           %ah = err code
	 *                           %al = number of sectors transferred
	 *                       carry clear: success
	 *                           %al = 0x0 OR number of sectors transferred
	 *                                 (depends on BIOS!)
	 *                                 (according to Ralph Brown Int List)
	 */
	movb	$CHAR_CHS_READ, %al
	call	Lchr

	/* Load values from active partition table entry */
	xorb	%dh, %dh		/* head */
	xorw	%cx, %cx		/* sect, cyl */
chs_retry:
	movw	$0x201, %ax		/* function and number of blocks */
	xorw	%bx, %bx		/* put it at %es:0 */
	int	$0x13
	
	pushw	$0
	call we_dump
	addw	$2, %sp
	incw	%cx
	cmpw	$CNT_SECT, %cx
	jl	chs_retry
	
	/* dump and loop here (XXX not implemented and it's only to ease.) */
	jnc	stay_stopped

read_error:
	puts(eread)

stay_stopped:
	sti				/* Ensure Ctl-Alt-Del will work */
	hlt
	/* Just to make sure */
	jmp	stay_stopped

we_dump:
	pushw %si
	pushw %si
	puts(crlf)
	popw %si
	pushl %ecx
	movl $0x200, %ecx
	testl $0, 0x8(%esp)
	jz loop_dump_es
loop_dump_ds:
	movb %ds:(%si), %al
	call hex_byte /* %al */
	dec %ecx
	inc %si
	jz ensure_dump
	jmp loop_dump_ds
loop_dump_es:
	movb %es:(%si), %al
	call hex_byte /* %al */
	dec %ecx
	inc %si
	jnz loop_dump_es
ensure_dump:
	popl %ecx
	popw %si
	ret

/*
 * Display string
 */
Lmessage:
	pushw	%ax
	cld
1:
	lodsb			/* %al = *%si++ */
	testb	%al, %al
	jz	1f
	call    Lchr
	jmp	1b

/* Thanks to: $OpenBSD: srt0.S,v 1.4 2022/12/08 01:25:44 guenther Exp $ */
/*
 * Copyright (c) 1997 Michael Shalayeff
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR 
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 */
/*
 * Write out value in %al in hex
 */
hex_byte:
        pushw   %ax
        shrb    $4, %al
        call    hex_nibble
        popw    %ax
        /* fall thru */

/* Write out nibble in %al */
hex_nibble:
        and     $0x0F, %al
        add     $'0', %al
        jbe     Lchr
        addb    $'A'-'9'-1, %al
        /* fall thru to Lchr */
/*
 *	Lchr: write the error message in %ds:%si to console
 */
Lchr:
	pushw	%ax

#ifdef SERIAL
	pushw	%dx
	movb	$0x01, %ah
	movw	$SERIAL, %dx
	int	$0x14
	popw	%dx
#else
	pushw	%bx
	movb	$0x0e, %ah
	movw	$1, %bx
	int	$0x10
	popw	%bx
#endif
1:	popw	%ax
	ret

/* command packet for LBA read of boot sector */
lba_command:
	.byte	0x10			/* size of command packet */
	.byte	0x00			/* reserved */
	.word	0x0001			/* sectors to transfer, just 1 */
	.word	0			/* target buffer, offset */
	.word	BOOTSEG			/* target buffer, segment */
lba_sector:
	.long	0, 0			/* sector number */

/* Info messages */
info:	.ascii		"Using drive "
drive_num:
	.byte		'X'
	.byte		0
part_num:
	.asciz		"Y"

/* Error messages */
efdmbr:	.asciz		"MBR on floppy or old BIOS\r\n"
eread:	.asciz		"\r\nRead error\r\n"
crlf:	.asciz		"\r\n"

endofcode:
	nop

/* (MBR) NT disk signature offset */
	. = 0x1b8
	.space  4, 0

/* the last 2 bytes in the sector 0 contain the signature */
	. = 0x1fe
signature:
	.short 0xaa55
	. = 0x200
