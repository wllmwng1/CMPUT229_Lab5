.data
.align 4
visited:
    .space 4000    #visited = []

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
toBeInserted:
    .space 2048
totalInserted:
    .space 2048
returnInstruction:
#jr $ra
    .word 0x03e00008
new:
    .asciiz "\n"
calleeFlag:
    .byte 0

.text
#Arguments
#a0 - address of start of instructions
insertInstructions:
    addi $sp $sp -8
    sw $ra 0($sp)
    sw $a0 4($sp)
    move $a1 $a0
    jal fixStack
    li $t0 0
    la $t1 toBeInserted
    la $t3 totalInserted
    li $t4 0
    insertLoop:
    sll $t2 $t0 2
    add $t2 $t1 $t2
    lw $a0 0($t2)
    add $t4 $t4 $a0
    sw $t4 0($t3)
    li $v0 1
    syscall
    li $v0 4
    la $a0 new
    syscall
    addi $t0 $t0 1
    addi $t3 $t3 4
    bne $t0 $v1 insertLoop
    li $v0 4
    la $a0 new
    syscall
    li $t0 0
    la $t1 totalInserted
    totalLoop:
        sll $t2 $t0 2
        add $t2 $t1 $t2
        lw $a0 0($t2)
        li $v0 1
        syscall
        li $v0 4
        la $a0 new
        syscall
        addi $t0 $t0 1
        bne $t0 $v1 totalLoop
    li $v0 4
    la $a0 new
    syscall
    sw $a0 4($sp)
    move $a1 $v1
    jal insertSpace
    lw $ra 0($sp)
    lw $a0 4($sp)
    addi $sp $sp 8
    jr $ra

#Arguments
#a0 - address of start of function
#a1 - address of beginning instructions
#toBeInserted - array
#Returns
#v1 - number of instructions found
fixStack:
    addi $sp $sp -12    #increment stack pointer
    sw $ra 0($sp)       #store ra
    sw $s0 4($sp)       #store s0
    sw $a0 8($sp)       #store a0

    
    move $s0 $a0        #move a0 to s0
    
    lb $t0 calleeFlag
    beqz $t0 notCallee
        move $a2 $a1
        li $a1 0
        li $v0 0
        jal gatherLiveRegs
        move $a1 $a2
        move $t0 $v0

        la $t1 deadStack
        li $t2 0
        getDeadLoop:
            lw $t3 0($t1)
            or $t2 $t2 $t3
            addi $t1 $t1 1
            addi $t0 $t0 -1
            bgez $t0 getDeadLoop

        lui $t3 0x0200
        li $t4 0xff00
        or $t3 $t3 $t4
        and $t2 $t2 $t3

        li $t3 0
        deadRegsLoop:
        beqz $t2 doneDeadRegs
            andi $t1 $t2 1
            beqz $t1 skipDead
                addi $t3 $t3 1
            skipDead:
            srl $t2 $t2 1
            j deadRegsLoop
        doneDeadRegs:

        sub $t0 $a0 $a1
        la $t1 toBeInserted
        add $t1 $t1 $t0
        lw $t0 0($t1)
        add $t0 $t0 $t3
        addi $t0 $t0 2
        sw $t0 0($t1)

    notCallee:

    Loop:
        addi $v1 $v1 1
        lw $t0 0($s0)
        lw $t1 returnInstruction
        beq $t0 $t1 endfixStack
        srl $t0 $t0 26
        li $t1 3
        beq $t0 $t1 functionCall
        endFunctionCall:
        addi $s0 $s0 4
        j Loop

    functionCall:
        
        sub $t0 $a0 $a1
        la $t1 toBeInserted
        add $t1 $t1 $t0
        lw $t0 0($t1)
        addi $t0 $t0 2
        sw $t0 0($t1)
        
        move $a0 $s0
        move $a2 $a1
        li $a1 0
        jal gatherLiveRegs
        move $a1 $a2

        lw $t0 liveRegs
        lui $t1 0x0f00
        li $t2 0xff00
        or $t1 $t1 $t2
        and $t0 $t0 $t1

        li $t2 0
        liveRegsLoop:
        beqz $t0 doneLiveRegs
            andi $t1 $t0 1
            beqz $t1 skipLive
                addi $t2 $t2 1
            skipLive:
            srl $t0 $t0 1
            j liveRegsLoop
        doneLiveRegs:
        
        addi $t2 $t2 2
        sub $t0 $a0 $a1
        la $t1 toBeInserted
        add $t1 $t1 $t0
        lw $t0 0($t1)
        add $t0 $t0 $t2
        sw $t0 0($t1)
        sw $t0 4($t1)

        lw $t0 0($s0)
        sll $t0 $t0 6
        srl $t0 $t0 4
        srl $t1 $s0 28
        sll $t1 $t1 28
        or $a0 $t0 $t1
        li $t0 1
        sb $t0 calleeFlag
        jal fixStack
        lw $a0 8($sp)
        j endFunctionCall

    endfixStack:  
    sub $t0 $a0 $a1
    la $t1 toBeInserted
    add $t2 $t1 $t0
    lw $t0 0($t2)
    sub $t2 $s0 $a1
    add $t2 $t1 $t2
    sw $t0 0($t2)

    lw $ra 0($sp)
    lw $s0 4($sp)
    lw $a0 8($sp)
    addi $sp $sp 12
    jr $ra


insertSpace:
#Arguments
#a0 - address of instructions
#a1 - end of program
    move $t0 $a1
    la $t1 totalInserted
    sll $t2 $t0 2
    add $t2 $t1 $t2
    add $t3 $a0 $t2

    
    jr $ra


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
# a2: beginning address of instruction, never changed
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
            li $t4 0xfff0           #bottom of mask
            add $t3 $t3 $t4         #add masks together
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