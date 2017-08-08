#as  barrel.s --32  -o barrel.com
#dosbox ./barrel -exit

.ORG 0x100
.global _start

.text
_start:
	
	call VIDEOMODE3H     #Set mode 03h
    call INITIALIZEMOUSE  #Initialize mouse

AsyncWaitForKey: 
        
	call BLACK_SCREEN # Clears screen to black.               
    call BULLET #Updates bullet position and draws the new position.
    call TRIGGER #Checks the mouse position and button clicked.       
    call GUN #Draws a blue box using the mouse input for position on y axis.
    call RANDOM_TARGET_POSITION #This function uses a time dependent random number 0-25 to draw the target.
    call BULLET_AND_RANDOM_TARGET_COLLISION #Checks the position of the bullet and target to determine if a collision event exists.
    call SCORE #Draws the score.
    call PAUSE #Temporarily causes this loop (AsyncWaitForKey) to freeze for 2 ticks ( there are about 18.2 ticks per second).
		
    movb    $1,%ah
    int     $0x16

jz      AsyncWaitForKey

     #text mode
    movw    $0x003,%ax
    int     $0x10
	
	movw 	$0x4C00,%ax
	INT 	$0x21

ret
#------------------------------------------------------------------------------------------------
GUN:   

        pushl %eax
        pushl %ebx
        pushl %ecx
        pushl %edx

                movb $70, mouse_x
                                               #
                movb mouse_y, %al               #y position of mouse 
                shrb %al
                shrb %al
                shrb %al 
                movb %al, mouse_y
                movb %al, %ch
                movb mouse_x,%cl              # x at 70 of 80     
                movw %cx,%dx
                addb $5,%dl
                movb $6,%ah
                movb $0b10010000,%bh # blue on black background
                movb $0,%al        # scroll all lines
                int $0x10

        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

ret
#------------------------------------------------------------------------------------------------
TRIGGER: 

        pushl %eax
        pushl %ebx
        pushl %ecx
        pushl %edx

                xorl %edx,%edx
                xorl %ebx,%ebx
                movw $0x3,%ax #get button status
                int $0x33
	        movw %bx, button
                movb %dl, mouse_y
                cmpw $1,bullet_fired
                je   exit_trigger

                cmpw $0b0001,button
                je firebullet
                jmp exit_trigger

firebullet: 

                movw $0,button
                movw $1,bullet_fired
                movw $73,bullet_x
                shrb %dl
                shrb %dl
                shrb %dl
	        movw %dx, bullet_y
exit_trigger: 

        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

ret
#------------------------------------------------------------------------------------------------       
BULLET: 

        pushl %eax
        pushl %ebx
        pushl %ecx
        pushl %edx

                cmpw $1,bullet_fired
                je bulletfired
                jmp exitbullet
                                                                        #writes a block into memory
bulletfired: 

                subw $2,bullet_x        #subtract from bullet position
                movw bullet_x,%ax
                cmpw $3,%ax
                jle cancelbullet

                movw bullet_y,%cx      #the bullet is drawn here at ( bullet_x, bullet_y)
                movb %cl,%ch
                movw bullet_x,%dx
                movb %dl,%cl
                movw %cx,%dx
                addb $4,%dl
                movb $0b10110000,%bh
                movb $0,%al
                movb $6,%ah
                int $0x10
                jmp exitbullet

cancelbullet: 

                movw $0, bullet_fired

exitbullet: 

        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

        ret
#------------------------------------------------------------------------------------------------
BULLET_AND_RANDOM_TARGET_COLLISION: 

        pushl %eax
        pushl %ebx
        pushl %ecx
        pushl %edx

                movw bullet_fired,%ax
                cmpw $0,%ax
                je exit_bullet_and_random_target_collision

                movw bullet_x,%ax
                cmpb $14,%al        #if target_y y and bullet_x are equal and bullet_x is less than 10
                jle compare_y_positions
#else     
                jmp exit_bullet_and_random_target_collision
compare_y_positions: 
                movw bullet_y,%ax
                movb target_y,%bl
                cmpb %bl,%al
                je update_score
                jmp exit_bullet_and_random_target_collision
update_score: 
                incb gamescore
                movw $0,bullet_fired
                movw $73,bullet_x
exit_bullet_and_random_target_collision: 

        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

        ret
#------------------------------------------------------------------------------------------------
RANDOM_TARGET_POSITION: 

        pushl %eax
        pushl %ebx
        pushl %ecx
        pushl %edx

                xorl %eax,%eax
                  #get time random_y_position passed since last call 
                call GET_RANDOM_Y_POSITION
                movb random_y_position,%al
	        movb %al, target_y
                movb previous_random_y_position,%ah
                subb %ah,%al
                cmpb $5,%al
                jle createtarget
                jmp drawtarget

createtarget: 

                call GET_RANDOM_Y_POSITION
                movb random_y_position,%al
                movb %al, previous_random_y_position
                                                   #This sets the y coordinate and the previous_random_y_position for the instance of the object, almost like OOP.
	        movb %al, target_y
drawtarget:                                   

                movb target_y,%ch       # y_i
                movb target_y,%dh       # y_f           
                movb $10,%cl # x_i
                movb $14,%dl # x_f            
                movb $0b11110000,%bh # 
                movb $0,%al       # 
                movb $6,%ah       #!
                int $0x10

        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

ret
#------------------------------------------------------------------------------------------------       
GET_RANDOM_Y_POSITION: 

        pushl %eax
        pushl %ebx
        pushl %ecx
        pushl %edx

        xorl %eax,%eax
        xorl %edx,%edx

                movb $0x2C,%ah
                int $0x21
                                         #this generates a random number between 0-25
                cmpb $10,%dh
                jle skip     #if random_y_position is less than or equal to ten then skip this step, else get a -n for random value
                shrb %dh     #this insures that any number 0-59 will be displayable if n/2-5 is at minimum 25, n - random_y_position 
                subb $5,%dh
         skip:    
                movb $0xd,random_y_position         #save random_y_position for countdown 

        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

ret
#------------------------------------------------------------------------------------------------
SCORE: 

        pushl %eax
        pushl %ebx
        pushl %ecx
        pushl %edx
#draw score
                movb $0x1,%ah #make cursor vanish
                movb $20,%ch
                int $0x10

        # move cursor

        movb $2,%ah       # move cursor function
        movw $0x000,%dx   # center of screen
        xorb %bh,%bh      # page 0
        int $0x10

    # display character with attribute
        movb $0x09,%ah      # display character function   
        movb $0,%bh       # page 0
        movb $0b00001111,%bl # blinking cyan char, red back
        movw $1,%cx       # display one character
        movb $'S', %al    # character is 'S'
        int $0x10

              # move cursor
        movb $2,%ah       # move cursor function
        incb %dl
        xorb %bh,%bh      # page 0
        int $0x10

    # display character with attribute
        movb $0x09,%ah      # display character function   
        movb $0,%bh       # page 0
        movb $0b00001111,%bl # blinking cyan char, red back
        movw $1,%cx       # display one character
        movb $'C', %al    # character is 'C'
        int $0x10

             # move cursor
        movb $2,%ah       # move cursor function
        incb %dl
        xorb %bh,%bh      # page 0
        int $0x10

    # display character with attribute
        movb $0x09,%ah      # display character function   
        movb $0,%bh       # page 0
        movb $0b00001111,%bl # blinking cyan char, red back
        movw $1,%cx       # display one character
        movb $'O', %al    # character is 'O'
        int $0x10

              # move cursor
        movb $2,%ah       # move cursor function
        incb %dl
        xorb %bh,%bh      # page 0
        int $0x10

    # display character with attribute
        movb $0x09,%ah      # display character function   
        movb $0,%bh       # page 0
        movb $0b00001111,%bl # blinking cyan char, red back
        movw $1,%cx       # display one character
        movb $'R', %al    # character is 'R'
        int $0x10

            # move cursor
        movb $2,%ah       # move cursor function
        incb %dl
        xorb %bh,%bh      # page 0
        int $0x10

    # display character with attribute
        movb $0x09,%ah      # display character function   
        movb $0,%bh       # page 0
        movb $0b00001111,%bl # blinking cyan char, red back
        movw $1,%cx       # display one character
        movb $'E', %al    # character is 'E'
        int $0x10

                    # move cursor
        movb $2,%ah       # move cursor function
        movb $7,%dl
        xorb %bh,%bh      # page 0
        int $0x10

         # display character with attribute
        movb $0x09,%ah      # display character function   
        movb $0,%bh       # page 0
        movb $0b00001111,%bl # blinking cyan char, red back
        movw $1,%cx       # display one character
        cmpb $9,gamescore
        je resetscore
        jmp nextscore

resetscore: 

        movb $0,gamescore

nextscore:              

        addb $48,gamescore
        movb gamescore,%al
        int $0x10
        subb $48,gamescore

exitscore:   

        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

ret
#------------------------------------------------------------------------------------------------
PAUSE:                  

        pushl %eax
        pushl %ebx
        pushl %ecx
        pushl %edx

                xorw %ax,%ax            # bios get time 
                int $0x1a               # 
                movw ticks,%ax          #                       
                addw %ax,%dx            # low byte 
	        movw %dx, outtime_init
                xorw %ax,%ax            # 
                adcw %cx,%ax            # high byte        
                movw %ax, outtime_current

not_yet:            

                xorw %ax,%ax            # bios get time 
                int $0x1a               #  
                cmpb $0,%al             # has midnight passed 
                jne midnight            # yup? reset outtime 
                cmpw outtime_current, %cx
                jb  not_yet             # then don't timeout 
                cmpw outtime_init,%dx   # if current hi < outtime hi... 
                                        # AND current low < outtime low 
                jb not_yet              # then don't timeout 
                jmp its_time            # 

midnight:                   

                subw $0x0B0, outtime_init            # since there are 1800B0h ticks a day 
	            subw $0x018, outtime_current 
                jmp not_yet             # 

its_time:       

        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

ret
#------------------------------------------------------------------------------------------------
BLACK_SCREEN: 

        pushl %eax
        pushl %ebx
        pushl %ecx
        pushl %edx

                 # clear window to black    
                movb $6,%ah
                movw $0000,%cx
                movw $8025,%dx
                movb $0b00000000,%bh
                movb $0,%al
                int $0x10

        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

ret
#------------------------------------------------------------------------------------------------
INITIALIZEMOUSE: 

        pushl %eax
        pushl %ebx
        pushl %ecx
        pushl %edx

                movw $0x0,%ax #initialize the mouse
                int $0x33
                movw $0x4,%ax # set pointer to 0,0
                movw $0,%bx
                movw $0,%cx
                int $0x33

        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

ret
#------------------------------------------------------------------------------------------------
VIDEOMODE3H: 

        pushl %eax
        pushl %ebx
        pushl %ecx
        pushl %edx

                xorl %eax,%eax
                movb $0,%ah
                movb $0x3,%al   # 80x25
                int $0x10

        popl %edx
        popl %ecx
        popl %ebx
        popl %eax

ret
#------------------------------------------------------------------------------------------------
.data

    button:                       .word  0
    bullet_fired:                 .word  0
	bullet_x:                     .word 73
    bullet_y:                     .word  0
    gamescore:                    .byte  0
	mouse_x:                      .byte  0
    mouse_y:                      .byte 10
    outtime_init:	              .int   0
    outtime_current:              .int   0   
	previous_random_y_position:   .byte  0
    random_y_position:            .byte  0
    target_y:                     .byte  0
	ticks:						  .int	 2
	