add $t7 $t8 $t9
beq $t8 $t7 something
jal something1
bne $t1 $t0 something
addi $t8 $0 1
jal something1
bne $t9 $t8 something
addi $t0 $t8 1
addu $v0 $0 10
syscall
jr $ra
addi $s0 $0 1