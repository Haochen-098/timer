# AUTHOR: HAOCHEN GOU

#This program implements a countdown timer. 


#####################################################################
# Register usage:
# $s0: the keyboard input 
# $s1: store the number 100
# $s3: store the ascll code for q 
# $s4: store the ascll code for backspace backspace
# $s5: store the ascll code for character 0
# $s6: display decade of second
# $s7: display unit of second 
# $s8: store the ascii code for character ":" 
      
# $a1: to check if the time interrupt       
                                 
# $t0: time for display 
# $t1: pointer for the t0
# $t2: control register of display
# $t3: store the number 60
# $t4: store the number 10 
# $t5: display minute 
# $t6: display second 
# $t7: store the input integer
# $t8: display decade of minute
# $t9: display unit of minute                                    	      
#####################################################################


# the exception handler code to handle the time and keyboard interrupts

	.kdata
	s1:
		.word 0
	s2:
		.word 0
	
	.ktext 0x80000180
	.set noat
	move $k1 $at			# Save $at
	.set at
	
	#reload a0 and v0
	sw 	$v0 s1			# store v0 in s1
	sw 	$a0 s2			# store a0 in s2


	mfc0 	$k0, $13		# get the cause register
	srl	$a0, $k0, 0x02		# Extract ExcCode Field
		
	# check if the interrupt is keyboard interrupt

	lw	$a0 0xffff0000		# get keyboard control register
	andi	$a0, $a0, 0x01
	bnez	$a0, nkeyboard		# check the keyboard status

# if time interrupt reset the time and change time
ntime:	
	mtc0 	$zero, $9		# reset $9 to 0 	
	# set num_check to 1, tell function in main to countdown time
	la	$a1, num_check		# load num_check adress 
	li	$v0, 1			# set num_check to 0
	sb	$v0, 0($a1) 			
	j finish
	
# check if the input keyboard is q 
nkeyboard:
	li	$s3, 113		# store the ascii code for q
	lw	$a0, 0xffff0004		# get the ascii keycode for input
	beq	$s3, $a0, keyquit	# check if the input is q

# finish and reload
finish:
	mtc0 	$0, $13			# Clear Cause register
	mfc0 	$k0, $12		# Set Status register
	ori  	$k0, $k0, 0x8801	# Interrupts enabled
	mtc0 	$k0, $12

	lw 	$v0 s1			# Restore other registers
	lw 	$a0 s2

	.set noat
	move $at $k1			# Restore $at
	.set at

# Return from exception on MIPS32:
	eret

# quit program if user input q
keyquit:
	li $v0 10
	syscall				# syscall 10 (exit)


# main function

	.data
__time_:
	.asciiz "Seconds="		 # use to display Seconds = on screen 

num_check:
	.byte 0				 # use to check if time count down
timer:
	.byte 8,8,8,8,8,48,48,58,48,48,0 # initial time for 00:00

	.text
	.globl __start
__start:
	li	$s4, 8   		# store the ascii code for backspace
	li	$s5, 0  		# store the ascii code for 0
	li	$s8, 58			# store the ascii code for character :

	li	$v0, 4			# syscall 4 (print_str)
	la	$a0, __time_		# print "Seconds = "
	syscall

	li	$v0, 5			# get the input integer
	syscall
	move	$t7, $v0		# move user input number to t7

	mtc0 	$0, $13			# # Clear Cause register
	mfc0 	$t0, $12		# Set Status register
	ori  	$t0, $t0, 0x8801	# get coprocessor 0 register $9 and $11
	mtc0 	$t0, $12

	lw	$t0, 0xffff0000		# enable keyboard interrupt		
	ori	$t0, $t0, 0x02		# Interrupts enabled
	sw	$t0, 0xffff0000

	# initial $9 as 0 and $11 as 100 for time interrupt
	mtc0 	$zero, $9		# set $9 to 0 
	li	$a0, 100
	mtc0	$a0, $11		# set $11 to 100

# use to display the data of time 	
display:
	la	$t0, timer		# load character of time to t0

	li	$t3, 60			# use t3 to count the decade minute and second
	li	$t4, 10			# use t4 to count unit second and minute	

	# trans time to minutes and seconds type	
	div	$t7, $t3		# divide the seconds by 60 to get the minutes
	mflo	$t5			# get total minutes
	mfhi	$t6			# get remainder second 

	div	$t5, $t4		# divide the minutes by 10 to get the decade and unit of minute
	mflo	$t8			# get the decade minutes		
	mfhi	$t9			# get the unit minutes 

	div	$t6, $t4		# divide the seconds by 10 to get the decade and unit of second
	mflo	$s6			# get the decade seconds
	mfhi	$s7			# get the unit seconds
	
	# transfer the number into character type
	addi	$t8, $t8, 48		
	addi	$t9, $t9, 48
	addi	$s6, $s6, 48
	addi	$s7, $s7, 48

	# re-store the new byte of character in right position
	sb	$t8, 5($t0)		
	sb	$t9, 6($t0)
	sb	$s6, 8($t0)
	sb	$s7, 9($t0)

# use loop to display time completely 
loop:
	lb	$t1, 0($t0)		# store pointer of t0 in t1 
	beqz	$t1, check		# check if the time diaplay all
	
poll:
	
	lw	$t2, 0xffff0008		# get the bit from display control register
	andi	$t2, $t2, 0x01
	beqz	$t2, poll		# check the display is ready for output	
	sw	$t1, 0xffff000c		# store number in display data register to display the number
	addi	$t0, $t0, 1		# move to next number
	j	loop

# check if time interrupt occurs 
check:
	# get the num_check
	la	$t0, num_check		
	lb	$a1, 0($t0)

	beqz    $a1, check 		# if num_check is 1 then the time interrupt occurs

# if the time interrupt	occurs then decrease the time
change:
	beqz	$t7, quit		# if the number is 0 then quit 
	addi	$t7, $t7, -1		# decrease the time by 1
	sb	$0, num_check		# reset the num_check to 0
	j	display 		# display the new time

# quit program if time become 0		 
quit:
	li $v0 10
	syscall				# syscall 10 (exit)
