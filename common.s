#
# CMPUT 229 Public Materials License
# Version 1.0
#
# Copyright 2017 University of Alberta
# Copyright 2017 Kristen Newbury
#
# This software is distributed to students in the course
# CMPUT 229 - Computer Organization and Architecture I at the University of
# Alberta, Canada.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the disclaimer below in the documentation
#    and/or other materials provided with the distribution.
#
# 2. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#
# The program reads a binary file as input
# fixes the jump instructions so that they correspond to data segment
# runs the student submission
# prints the output program representation
#-------------------------------
.data
.align 2
binary:	  #This absolutely MUST be the first data defined, for jump correction
    .space 3500
noFileStr:
    .asciiz "Couldn't open specified file.\n"
format:
    .asciiz "\n"
oxStr:
    .asciiz "0x"
.text
main:

    lw      $a0 4($a1)	# Put the filename pointer into $a0
    li      $a1 0		# Read Only
    li      $a2 0		# No Mode Specified
    li      $v0 13		# Open File

    syscall
    bltz	$v0 main_err	# Negative means open failed

    move	$a0 $v0		#point at open file
    la      $a1 binary	# write into my binary space
    li      $a2 2048	# read a file of at max 2kb
    li      $v0 14		# Read File Syscall
    syscall
    la      $t0 binary
    add     $t0 $t0 $v0	#point to end of binary space

    li      $t1 0xFFFFFFFF	#Place ending sentinel
    sw      $t1 0($t0)

    #fix all jump instructions
    la      $t0 binary	#point at start of instructions
    move	$t1 $t0

main_jumpFixLoop:
    lw      $t2 0($t0)
    srl     $t3 $t2 26	#primary opCode

    li      $t4 2
    beq     $t3 $t4 main_jumpFix
    li      $t4 3
    beq     $t3 $t4 main_jumpFix
    j       main_jfIncrem
main_jumpFix:
#Replace upper 10 bits of jump with binary address
    li      $t3 0xFC000FFF		#bitmask
    and     $t2 $t2 $t3		#clear bits
    la      $t4 binary
    srl     $t4 $t4 2		#align to instruction
    not     $t3 $t3
    and     $t4 $t4 $t3		#only get bits in field
    or      $t2 $t2 $t4		#combine back on the binary address
    addi    $t2 $t2 -9      #adjust for the first 9 lines when spim loads a program
    sw      $t2 0($t0)		#place the modified instruction
main_jfIncrem:
    addi	$t0 $t0 4
    li      $t4 -1
    bne     $t2 $t4 main_jumpFixLoop

    la      $a0 binary	#prepare pointers for student subroutine
    jal     insertInstructions

    jal     writeFile       #write out the representation of the program, one instr one each line, to stdout
    j       main_done

main_err:
    la      $a0 noFileStr   #in the event of a file open error, print a message
    li      $v0 4
    syscall
main_done:

    li      $v0 10          #exit program syscall
    syscall
#----------------------------------------------------------------------------
# writeFile writes a buffer to the standard output each instruction as an int on a newline, buffer is 0xFFFFFFFF terminated
# if the buffer is not 0xFFFFFFFF terminated we will read a max 875 words because this is the size of the output buffer
#
# register usage:
# $a0: the instruction, since it must be passed to printHex
#
# $s0: the buffer to write out
# $s1: sentinel
# $s2: the max number of words to read
# $s3: the counter of words seen to check against max
#----------------------------------------------------------------------------
writeFile:
    addi    $sp $sp -20
    sw      $ra 0($sp)
    sw      $s0 4($sp)
    sw      $s1 8($sp)
    sw      $s2 12($sp)
    sw      $s3 16($sp)

    la      $s0 binary
    li      $s1 0xFFFFFFFF          #program representation sentinel
    li      $s2 875                 #will print a max 875 instructions
    move    $s3 $zero

writeLoop:
        lw      $a0 0($s0)
        beq     $a0 $s1 writeDone
        beq     $s2 $s3 writeDone       #safeguard for overflow
        addi    $s3 $s3 1
        addi	$s0 $s0 4

        #print to standard output
        jal     printHex
        la      $a0 format  #print the newline
        li      $v0 4
        syscall
        j       writeLoop

writeDone:

    lw      $ra 0($sp)
    lw      $s0 4($sp)
    lw      $s1 8($sp)
    lw      $s2 12($sp)
    lw      $s3 16($sp)
    addi    $sp $sp 20
    jr      $ra

#--------------
# printHex
# ARGS: $a0 = integer value
#
# Prints the integer provided to output in Hexadecimal
#--------------
printHex:
    li	$t0 8
    move	$t3 $a0

    la	$a0 oxStr
    li	$v0 4
    syscall

printHex_loop:
        srl	$t1 $t3 28	#isolate uppermost 4 bits
        li	$t2 9
        bgt	$t1 $t2 charPrint
    digitPrint:
        addi	$a0 $t1 48	# '0'
        j	print
    charPrint:
        addi	$a0 $t1 87	# 'a' - 10
        print:
        li	$v0 11
        syscall

        #loop incrementation
        addi	$t0 $t0 -1
        sll	$t3 $t3 4
        bgtz	$t0 printHex_loop

    jr	$ra
#-------------------end of common file-------------------------------------------------
