#
# CMPUT 229 Public Materials License
# Version 1.0
#
# Copyright 2017 University of Alberta
# Copyright 2017 Austin Crapo/Kristen Newbury
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
'''
Author: Austin Crapo
Date: May 4 2017

Minor modifications: Kristen Newbury
Date: May 10 2017

A decompiler for binary MIPS files, as produced through spim. It takes a .bin
file as a command line argument. Additionally, because spim can technically run
in big endian mode on certain machines, you can force big endian mode by passing
"big" as the third CLA, or leave it blank for "little" endian mode as default

mode flags include:
	b: binary file input
	h: hexadecimal instruction representation file input (each instruction as 0x________ on a newline)

sample usage:

	python3 binDecompiler.py modeFlag filename (optional)endianness
	
example:
	
	python3 binDecompiler.py h test.out

THIS PROGRAM DOES NOT IMPLEMENT ALL OPCODES/FUNCTION CODES
Feel free to add those that cause the compiler to crash or throw 'Unparsable' errors
to the dictionaries at the program start
'''

import sys

if len(sys.argv) > 1:
	bin_file = sys.argv[2]
	mode = sys.argv[1]
	if mode!= "b" and mode!= "h":
		print("incorrect mode specified")
		sys.exit()
else:
	print("No binary file name supplied")
if len(sys.argv) > 3: endian = sys.argv[3]
else:
	endian = "little"


# define the opcodes, function codes, and groups for translation later
all_ops = {
0x00:'RTYPE',
0x02:'JTYPE',
0x03:'JTYPE',
0x04:'beq',
0x05:'bne',
0x06:'blez',
0x07:'bgtz',
0x08:'addi',
0x09:'addiu',
0x0A:'slti',
0x0B:'sltiu',
0x0c:'andi',
0x0D:'ori',
0x0E:'xori',
0x0F:'lui',
0x10:'RTYPE',
0x30:'ll',
0x20:'lb',
0x21:'lh',
0x23:'lw',
0x24:'lbu',
0x25:'lhu',
0x28:'sb',
0x29:'sh',
0x2B:'sw',
0x38:'sc',
0x1C:'mul'
}
loadstores = {
0x30:'ll',
0x20:'lb',
0x21:'lh',
0x23:'lw',
0x24:'lbu',
0x25:'lhu',
0x28:'sb',
0x29:'sh',
0x2B:'sw',
0x38:'sc'
}

signed_ops = {
0x01,
0x04,
0x05,
0x06,
0x07,
0x08,
0x0A,
0x0c,
0x0D,
0x0F,
0x20,
0x21,
0x23,
0x28,
0x29,
0x2B
}

r_funcs = {
0x00:'sll',
0x02:'srl',
0x03:'sra',
0x04:'sllv',
0x06:'srlv',
0x07:'srav',
0x08:'jr',
0x0c:'syscall',
0x10:'mfhi',
0x12:'mflo',
0x18:'mult',
0x19:'multu',
0x1A:'div',
0x1B:'divu',
0x20:'add',
0x21:'addu',
0x22:'sub',
0x23:'subu',
0x24:'and',
0x25:'or',
0x26:'xor',
0x27:'nor',
0x2A:'slt',
0x2B:'sltu'
}
signed_funcs = {
0x12,
0x18,
0x1A,
0x20,
0x22,
0x2A
}

j_ops = {
0x02:'j',
0x03:'jal'
}

regs = {
0:'$zero',
1:'$at',
2:'$v0',
3:'$v1',
4:'$a0',
5:'$a1',
6:'$a2',
7:'$a3',
8:'$t0',
9:'$t1',
10:'$t2',
11:'$t3',
12:'$t4',
13:'$t5',
14:'$t6',
15:'$t7',
16:'$s0',
17:'$s1',
18:'$s2',
19:'$s3',
20:'$s4',
21:'$s5',
22:'$s6',
23:'$s7',
24:'$t8',
25:'$t9',
26:'$k0',
27:'$k1',
28:'$gp',
29:'$sp',
30:'$fp',
31:'$ra',
}

#hardcoded binary address used for line calculation for addresses, ONLY works if binary representation is located first in the data segment
PC =  268500992




if mode == "b":
	f = open(bin_file, "rb")
	word = int.from_bytes(f.read(4), endian)
	#read every word, word by word
else:
	f = open(bin_file)
	try:
		parsed = f.readline().rstrip()[2:] #want to remove the 0x on each string
		word = int.from_bytes(bytes.fromhex(parsed), "big")
	except ValueError:  #if there is an invalid character or no lines in the file to read
		sys.exit()
while ((word != -1) and (word != 0)):
		if word < 0 :
			#correct for negative ints
			signedBin = bin(word & 0xffffffff)
			word = int(signedBin, 2)
		print(hex(PC), end = '\t')
		opcode = word >> 26
		try:
			#try to interpret the opcode
			inst = all_ops[opcode]
		except Exception as e:
			inst = 'Unknown'
		if inst == 'RTYPE' or inst == 'mul':
			#Rtype functions come in 5 forms, shifts, 1/2/3 register arithmetic forms, and syscall
			func = word & 63
			shamt = (word & 0x7C0) >> 6
			if shamt >= 2**15 and func in signed_funcs:
				shamt -= 2**16
			try:
				if inst != "mul":
					inst = r_funcs[func]
				rs = regs[(word & 0x3E00000) >> 21]
				rt = regs[(word & 0x1F0000) >> 16]
				rd = regs[(word & 0xF800) >> 11]
			except:
				print("Unparsable instruction")
			if rd:
				if inst == "mul":
					print(inst + "\t" + rd + ", " + rs + ", " + rt)
				elif func <= 0x07:
					#This is a shift R type
					print(inst + "\t" + rd + ", " + rt + ",", shamt)
				elif func == 0x0c:
					#syscall
					print(inst)
				elif func == 0x08:
					#1 register jr, source reg is important
					print(inst + "\t" + rs)
				elif func <= 0x12:
					#1 register mfhi/mflo, dest register is important
					print(inst + "\t" + rd)
				elif func <= 0x1B:
					#2 register arithmetic mult/div
					print(inst + "\t" + rs + ", " + rt)
				else:
					#3 register arithmetic
					print(inst + "\t" + rd + ", " + rs + ", " + rt)
		elif inst == 'JTYPE':
			inst = j_ops[opcode]
			address = word & 0x03FFFFFF
			#Jumps store addresses that will then be shifted, the shift is displayed for readability
			cor_add = address << 2
			upperFour = (PC+4) & 0xF0000000
			targetAddress =  upperFour + cor_add
			print(inst + '\t' + hex(targetAddress))
		elif inst:
			#I type instructions are all that are left
			imm = word & 0xFFFF
			if imm >= 2**15 and opcode in signed_ops:
				imm -= 2**16
			try:
				rs = regs[(word & 0x3E00000) >> 21]
				rt = regs[(word & 0x1F0000) >> 16]
				rtint = (word & 0x1F0000) >> 16
				if opcode ==1 and rtint == 1:
					inst = "bgez"
				elif opcode == 1 and rtint ==0:
					inst = "bltz"
			except Exception as e:
				print("Bad Register Encodings Found")
			if rt:
                #There are 2 types for printing, regular I types, and all load/store instructions
				if opcode in loadstores:
					print(inst + "\t" + rt + ", " + str(imm) + "(" + rs + ")")
                #for beq and bne branches
				elif (opcode == 4  or opcode == 5):
					branchTarget = (imm*4) + PC + 4
					print(inst + "\t" + rt + ", " + rs +", "+ hex(branchTarget))
                #for bgez, bltz, blez, bgtz branches
				elif (opcode == 1 or opcode == 6  or opcode == 7):
					branchTarget = (imm*4) + PC + 4
					print(inst + "\t" + rs +", "+ hex(branchTarget))
				else:
					print(inst + "\t" + rt + ", " + rs + ",", imm)
		PC+=4
		if mode == "b":
			word = int.from_bytes(f.read(4), endian)
		else:
			parsed = f.readline().rstrip()[2:] #want to remove the 0x on each string           
			if parsed != "":
				word = int.from_bytes(bytes.fromhex(parsed), "big") 
			else:
				sys.exit()
