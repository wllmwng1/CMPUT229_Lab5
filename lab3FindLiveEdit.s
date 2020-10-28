# The following format is required for all submissions in CMPUT 229
#
# The following copyright notice does not apply to this file
# It is included here because it should be included in all
# solutions submitted by students.
#
#----------------------------------------------------------------
#
# CMPUT 229 Student Submission License
# Version 1.0
# Copyright 2017 <student name>
#
# Redistribution is forbidden in all circumstances. Use of this software
# without explicit authorization from the author is prohibited.
#
# This software was produced as a solution for an assignment in the course
# CMPUT 229 - Computer Organization and Architecture I at the University of
# Alberta, Canada. This solution is confidential and remains confidential
# after it is submitted for grading.
#
# Copying any part of this solution without including this copyright notice
# is illegal.
#
# If any portion of this software is included in a solution submitted for
# grading at an educational institution, the submitter will be subject to
# the sanctions for plagiarism at that institution.
#
# If this software is found in any public website or public repository, the
# person finding it is kindly requested to immediately report, including
# the URL or other repository locating information, to the following email
# address:
#
#          cmput229@ualberta.ca
#
#---------------------------------------------------------------
# Assignment:           2
# Due Date:             October 30, 2017
# Name:                 William Wong
# Unix ID:              wwong1
# Lecture Section:      A1
# Instructor:           Jose Amaral
# Lab Section:          D09 (Friday 1400 - 1650)
# Teaching Assistant:   Unknown
#---------------------------------------------------------------

.data
#this array is 10 words: 1 word for each function call
#fix this, it is the instructions not the registers
.align 4
visited:
    .space 4000    #visited = []

.align 4
allLiveRegs:
    .space 400   #allLiveRegs = []

#this is a word
.align 4
liveRegs:
    .word 0     #liveRegs = word

#deadstack is not static, do not use
.align 4
deadStack:
    .space 400   #unknown

noDeadCheck:
    .word 1,2,3,4,5,6,7,40,41,43,0

twoLiveCheck:
    .word 4,5,40,41,43,0

branchCheck:
    .word 1,4,5,6,7,0
returnInstruction:
#jr $ra
    .word 0x03e00008

.text
#---------------------------------------------------------------
# The function finds the liveliness of registers 4-25 ($a0 - $t9)
# through every function call given in the argument. The argument
# is a set of MIPS base instructions, with no pseudocode. It stops
# once it reaches the sentinel value 0xffffffff.
#
# Inputs:
#
#	a0: beginning address of the instructions being read
# allLiveRegs: an array of live registers for a function call
# liveRegs: the current function call's live registers
# deadStack: the stack of dead registers in a function call
#
# Register Usage:
# s0: stores the beginning address
# s1: stores the result index
# s2: stores the address of allLiveRegs
# s3: stores the address of liveRegs
# s4: stores the address of deadStack
# s5: stores the current address of instruction
# t0: used to get the instruction, and a constant
# t1: used to get conditions
# a1: used for gatherLiveRegs function
#
# Returns:
# v0: the address of the beginning of allLiveRegs, which has
#     the liveliness of the registers for each function call,
#     which ends with a sentinel value 0xffffffff
#
#---------------------------------------------------------------
findLive:
    addi $sp $sp -28    #increment $sp for stack space
    sw $ra 0($sp)       #store $ra into stack
    sw $s0 4($sp)       #store $s0 into stack
    sw $s1 8($sp)       #store $s1 into stack
    sw $s2 12($sp)      #store $s2 into stack
    sw $s3 16($sp)      #store $s3 into stack
    sw $s4 20($sp)      #store $s4 into stack
    sw $s5 24($sp)      #store $s5 into stack

    #initialize some variables
    move $s0 $a0        #beginningAddress = beginningAddressArg
    move $s1 $0         #resultIndex = 0	# for the index into allLiveRegs
    la $s2 allLiveRegs  #address of allLiveRegs
    la $s3 liveRegs     #address of liveRegs
    la $s4 deadStack    #address of deadStack
    move $s5 $a0        #currAddress = beginningAddress

    #checks wether the current instruction is a function call
    functionCheck:
        lw $t0 0($s5)               #load address of instruction
        srl $t0 $t0 26              #get opcode
        li $t1 3                    #load 0000...000011(jal opcode) into t1
        beq $t0 $t1 functionCall    #if equal goto functionCall
        lw $t0 0($s5)               #load address of instruction
        li $t1 -1                   #load 1111...111 (0xFFFFFFFF) into t1
        beq $t0 $t1 endFindLive     #if equal goto end
        addi $s5 $s5 4              #add 4 to s0(currAddress)
        j functionCheck             #goback to functionCheck

    #gets ready to call gatherLiveRegs when a function call is seen
    functionCall:
        #addi $s5 $s5 4      #address of instruction +4
        move $a0 $s5        #address of instruction right after the function call

        move $a1 $0         #deadStackIndex = 0
        jal gatherLiveRegs  #goto gatherLiveRegs
        add $t0 $s2 $s1     #address of allLiveRegs[resultIndex]
        lw $t1 0($s3)       #get liveRegs
        sw $t1 0($t0)       #allLiveRegs[resultIndex] = liveRegs
        addi $s1 $s1 4      #resultIndex ++ by 4 because of addresses
        sw $0 0($s4)        #deadStack[0] = 0
        sw $0 0($s3)        #liveRegs = 0
        addi $s5 $s5 4     #add 4 to s5(currAddress)
        j functionCheck     #goback to functionCheck

    #set the results and put back values from registers
    endFindLive:
        li $t0 -1           #t1 = -1
        add $t1 $s2 $s1     #address of allLiveRegs[resultIndex]
        sw $t0 0($t1)       #allLiveRegs[resultIndex] = -1
        move $v0 $s2        #move allLiveRegs address to v0

        lw $ra 0($sp)       #load $ra from stack
        lw $s0 4($sp)       #load $s0 from stack
        lw $s1 8($sp)       #load $s1 from stack
        lw $s2 12($sp)      #load $s2 from stack
        lw $s3 16($sp)      #load $s3 from stack
        lw $s4 20($sp)      #load $s4 from stack
        lw $s5 24($sp)      #load $s5 from stack
        addi $sp $sp 28     #decrement stack pointer

        jr $ra              #return to address at ra

#---------------------------------------------------------------
# The function finds the liveliness of registers within a
# specific function call. It looks at each instruction and sees
# if it wasn't visited yet and is not the instruction jr $ra. If
# it meets these requirements, then it flags that the instruction
# is visited, and finds the liveliness of the registers. If the
# instruction is a branch or jump, it looks at the target address
# of the instruction as well as the next instruction after that.
# It ends when the instructon is jr $ra. It returns with the
# liveliness of the registers.
#
# Inputs:
#
# a0: address of function call
# a1: deadStackIndex, which stack is used for deadStack
# s0: beginning address of instruction, never changed
# liveRegs: word space to store liveliness of registers
# deadStack: stack of dead registers used to find live registers
# visited: array used to figure if an instruction has been visited
# noDeadCheck: an array of opcodes which instructions do not produce
#   dead registers
# twoLiveCheck: an array of opcodes which instructions produce two
#    live registers
# branchCheck: an array of opcodes of branches
# returnInstruction: the instruction jr $ra in hexadecimal
#
# Register Usage:
# s0: stores the beginning address
# s1: stores the liveRegs
# s2: stores deadStack[deadStackIndex]
# s3: stores deadStackIndex
# t0: stores the index of visited
# t1: stores the current instruction being assessed
# t2: stores address of visited[index]
# t3: stores visited[index]
# t4: stores various constants and variables
# t5: is mostly used for conditions
# t6: used for conditions and bit manipulation
# t7: stores deadStack address
#
# Returns:
# liveRegs: returns the liveliness of the registers in that
#   specific function call.
#
#---------------------------------------------------------------
gatherLiveRegs:
    #store values into stack
    addi $sp $sp -28    #increment $sp for stack space
    sw $ra 0($sp)       #store $ra into stack
    sw $a2 4($sp)       #store $a2 into stack
    sw $s1 8($sp)       #store $s1 into stack
    sw $s2 12($sp)      #store $s2 into stack
    sw $s3 16($sp)      #store $s3 into stack
    sw $a0 20($sp)      #store $a0 into stack
    sw $a1 24($sp)      #store $a1 into stack

    #initialize variables, check if visited
    sub $t0 $a0 $a2                 #index = address-beginningAddress
    lw $t1 0($a0)                   #load instruction from address
    move $s3 $a1                    #move deadStackIndex to s3
    la $s1 liveRegs                 #load liveRegs address
    lw $s1 0($s1)                   #load liveRegs
    la $s2 deadStack                #load deadStack address
    sll $a1 $a1 2                   #a1*4
    add $s2 $s2 $a1                 #address of deadStack[deadStackIndex]
    lw $s2 0($s2)                   #load deadStack[deadStackIndex]
    la $t2 visited                  #load visited address
    add $t2 $t2 $t0                 #address of visited[index]
    lw $t3 0($t2)                   #load visited[index]
    li $t4 1                        #t4 = 1
    beq $t3 $t4 endGatherLiveRegs   #if equal goto end
    la $t5 returnInstruction        #load returnInstruction address
    lw $t5 0($t5)                   #load returnInstruction
    beq $t1 $t5 endGatherLiveRegs   #if instruction is jr $ra goto endGatherLiveRegs
    sw $t4 0($t2)                   #visited[index] = 1
    j UpdateLiveRegs                #goto UpdateLiveRegs

    #This function updates the LiveRegs according to the instruction
    UpdateLiveRegs:
        srl $t3 $t1 26          #get opcode
        beq $t3 $0 twoRegs      #if opcode = 0 (RType opcode) goto twoRegs
        li $t4 2                #load j opcode
        beq $t3 $t4 UpdateDead  #if j goto UpdateDead
        li $t4 3                #load jal opcode
        beq $t3 $t4 UpdateDead  #if jal goto UpdateDead
        la $t5 twoLiveCheck     #load twoLiveCheck address
        lw $t4 0($t5)           #get twoLiveCheck[0]

        #Check if it has two live registers
        liveLoop:
            beq $t3 $t4 twoRegs #if beq goto twoRegs
            addi $t5 $t5 4      #address twoLiveCheck[i+1]
            lw $t4 0($t5)       #load twoLiveCheck[i+1]
            beq $t4 $0 oneReg   #if nothing in array left goto oneReg
            j liveLoop          #otherwise goto liveLoop

        #start of two live register input
        twoRegs:
            srl $t3 $t1 16      #get opcode+rs+rt
            andi $t3 $t3 0x001f #get rt through mask
            li $t4 1            #t4 = 1
            sllv $t4 $t4 $t3    #t4 << register number
            and $t3 $t4 $s2     #check if register in deadStack[deadStackIndex]
            bne $t3 $0 oneReg   #if not equal 0 goto oneReg
            or $s1 $s1 $t4      #add register to liveRegs

        #start of one live register input
        oneReg:
            srl $t3 $t1 21                  #get opcode+rs
            andi $t3 $t3 0x001f             #get rs through mask
            li $t4 1                        #t4 = 1
            sllv $t4 $t4 $t3                #t4 << register number
            and $t3 $t4 $s2                 #check if register in deadStack[deadStackIndex]
            bne $t3 $0 endUpdateLiveRegs    #if not equal 0 goto endUpdateLiveRegs
            or $s1 $s1 $t4                  #add register to liveRegs

        #store it into liveRegs address
        endUpdateLiveRegs:
            lui $t3 0x03ff          #top of mask
            addi $t3 $t3 0xfff0     #bottom of mask
            and $s1 $s1 $t3         #mask liveRegs to only show a0 - t9
            la $t3 liveRegs         #load liveRegs address
            sw $s1 0($t3)           #load liveRegs into memory

    #This function updates the dead registers
    UpdateDead:
        srl $t3 $t1 26      #get opcode
        beq $t3 $0 rType    #if opcode = 0 (RType opcode) goto rType
        la $t5 noDeadCheck  #load noDeadCheck address
        lw $t4 0($t5)       #get noDeadCheck[0]

        #check if instruction has no dead registers
        deadLoop:
            beq $t3 $t4 endUpdateDead   #if beq goto endUpdateDead
            addi $t5 $t5 4              #address noDeadCheck[i+1]
            lw $t4 0($t5)               #load noDeadCheck[i+1]
            beq $t4 $0 oneDeadReg       #if nothing in array left goto oneDeadReg
            j deadLoop                  #otherwise goto deadLoop

        #start here for R-Type instructions
        rType:
            srl $t3 $t1 11      #get opcode+rs+rt+rd
            andi $t3 $t3 0x001f #get rd through mask
            li $t4 1            #t4 = 1
            sllv $t4 $t4 $t3    #t4 << register number
            or $s2 $s2 $t4      #add register to liveRegs
            j endUpdateDead     #goto endUpdateDead

        #start here for one dead register instructions
        oneDeadReg:
            srl $t3 $t1 16      #get opcode+rs+rt
            andi $t3 $t3 0x001f #get rt through mask
            li $t4 1            #t4 = 1
            sllv $t4 $t4 $t3    #t4 << register number
            or $s2 $s2 $t4      #add register to liveRegs

        #update deadStack[deadStackIndex]
        endUpdateDead:
            la $t3 deadStack        #load address of deadStack
            add $t3 $t3 $a1         #get deadStack[deadStackIndex] address
            sw $s2 0($t3)           #save deadStack to deadStack[deadStackIndex]

    #check for jump instruction
    li $t4 2                #load 0000...000010(j opcode) into t1
    srl $t5 $t1 26          #get opcode of instruction
    beq $t4 $t5 jumpCall    #if equal goto jumpCall

    #initialize branch checking
    la $t4 branchCheck  #get branchCheck address
    lw $t6 0($t4)       #get branchCheck[0]

    #check for branches
    branchLoop:
        beq $t5 $t6 branchCall  #if opcode is branch, goto branchCall
        addi $t4 $t4 4          #get branchCheck[i+1] address
        lw $t6 0($t4)           #get branchCheck[i+1]
        bne $t6 $0 branchLoop   #if not out of array goto branchLoop

    lw $a0 20($sp)      #load $a0 from stack
    addi $a0 $a0 4      #add 4 to address
    lw $a1 24($sp)      #load deadStackIndex from stack
    jal gatherLiveRegs  #goto gatherLiveRegs
    addi $a0 $a0 -4
    j endGatherLiveRegs #goto endGatherLiveRegs

    #if it is branch, increment deadStackIndex and recursively call gatherLiveRegs
    branchCall:
        lw $a0 20($sp)      #get address
        addi $a0 $a0 4      #PC + 4
        sll $t6 $t1 16      #get last 16 bits of instruction
        sra $t6 $t6 14      #sign extend t6 and shift right by 14, total will be shift left by 2 and signextended
        add $a0 $a0 $t6     #add t6 to PC + 4
        lw $a1 24($sp)      #get deadStackIndex
        addi $a1 $a1 1      #deadStackIndex++
        addi $v0 $v0 1      #add to v0 to check how many Stacks there are
        sll $t6 $a1 2       #deadStackIndex*4
        la $t7 deadStack    #load deadStack address
        add $t6 $t6 $t7     #add deadStack + deadStackIndex
        sw $s2 0($t6)       #clone deadStack[deadStackIndex] to deadStackIndex+1
        jal gatherLiveRegs  #call gatherLiveRegs(target,deadStackIndex)
        addi $a1 $a1 -1     #deadStackIndex--

        lw $a0 20($sp)      #load $a0 from stack
        addi $a0 $a0 4      #add 4 to address
        lw $a1 24($sp)      #load deadStackIndex from stack
        jal gatherLiveRegs  #goto gatherLiveRegs
        addi $a0 $a0 -4
        j endGatherLiveRegs #goto endGatherLiveRegs

    #if jump, get target address and recursively call gatherLiveRegs
    jumpCall:
        lw $a0 20($sp)      #get address of instruction
        addi $a0 $a0 4      #PC + 4
        srl $t4 $a0 28      #get the 4 most significant bits
        sll $t4 $t4 28      #put it back to the most significant place
        sll $t5 $t1 6       #remove opcode from instruction
        srl $t5 $t5 4       #shift right by 4 so total shift is left by 2
        or $a0 $t4 $t5      #get address of target instruction
        lw $a1 24($sp)      #get deadStackIndex
        jal gatherLiveRegs  #goto gatherLiveRegs
        lw $a0 20($sp)

    #change visited flag down when finished
    endGatherLiveRegs:
        la $t2 visited  #load visited address
        sub $t0 $a0 $a2 #index = address - beginning address
        add $t2 $t2 $t0 #add index to visited
        sw $0 0($t2)    #visited[index] = 0

        #put back values from stack
        lw $ra 0($sp)   #load $ra from stack
        lw $a2 4($sp)   #load $a2 from stack
        lw $s1 8($sp)   #load $s1 from stack
        lw $s2 12($sp)  #load $s2 from stack
        lw $s3 16($sp)  #load $s3 from stack
        lw $a0 20($sp)  #load $a0 from stack
        lw $a1 24($sp)  #load $a1 from stack
        addi $sp $sp 28 #increment $sp for stack

        jr $ra          #return to address
