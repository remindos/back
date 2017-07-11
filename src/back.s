    .syntax unified
    .arch armv6-m

    .section .return_stack
    .equ return_stack_size, 0x200
    .globl __return_stack_top
    .globl __return_stack_limit
__return_stack_limit:
    .space return_stack_size
    .size  __return_stack_limit, . - __return_stack_limit
__return_stack_top:
    .size  __return_stack_top, . - __return_stack_top
    
    .section .param_stack
    .equ param_stack_size, 0x200
    .globl __param_stack_top
    .globl __param_stack_limit
__param_stack_limit:
    .space param_stack_size
    .size  __param_stack_limit, . - __param_stack_limit
__param_stack_top:
    .size  __param_stack_top, . - __param_stack_top

    .section .back_heap
saved_caller_sp:
    .int 0
saved_callee_sp:
    .int __return_stack_top
saved_psp:
    .int __param_stack_top
var_state:
    .int 0
var_latest:
    .int 0
var_here:
    .int 0
var_link:
    .int 0
var_inp:
    .int 0
var_outp:
    .int 0
var_saved_here:
    .int 0
var_saved_link:
    .int 0
var_saved_inp:
    .int 0
var_saved_outp:
    .int 0

	.macro next
    bx lr   
	.endm
    
	.macro exit
    poprsp pc
	.endm

	.macro	docol
	pushrsp	lr
	.endm
	
 	.macro pushrsp reg
	push {\reg}
	.endm

	.macro poprsp reg
	pop {\reg}
	.endm
	
	.macro pushpsp reg
	stm	psp!, {\reg}
	.endm
	
	.macro poppsp reg
    subs psp, psp, #4
	ldr	\reg, [psp]
	.endm
    
	.set F_IMMED, 0x80000000
    
	.global test

	top	.req	r7
	rsp	.req	sp
	psp	.req	r6

	.global back_init
    .set code_offset_ram_to_flash, (0x20004000 - 0x28000)
	.section .dict_field,"a",%progbits
    .thumb
    .thumb_func
back_init:
init:
    @@ Copy code from flash to ram
    ldr    r1, =__code_start__
    ldr    r2, =__ram_start__
    ldr    r3, =__code_end__
    subs    r3, r1
    ble     flash_to_ram_loop_end
    movs    r4, 0
flash_to_ram_loop:
    ldr    r0, [r1,r4]
    str    r0, [r2,r4]
    adds   r4, 4
    cmp    r4, r3
    blt    flash_to_ram_loop
flash_to_ram_loop_end:
    @@ Init the var containing return stack point
    ldr r0, =__return_stack_top
    ldr r1, =saved_callee_sp
    str r0, [r1]
    @@ Init the var containing return stack point
    ldr r0, =__param_stack_top
    ldr r1, =saved_psp
    str r0, [r1]
    @@ Save caller lr
    pushrsp lr
    @@ Save caller sp
    ldr r1, =saved_caller_sp
    mov r0, sp
    str r0, [r1]
    @@ Restore callee sp
    ldr r1, =saved_callee_sp
    ldr r0, [r1]
    mov sp, r0
    @@ Restore callee psp
    ldr r1, =saved_psp
    ldr r0, [r1]
    mov psp, r0
    @@ Init here point
    ldr r0, =var_here
    ldr r1, =__code_end__
    ldr r4, =init_code_offset
    ldr r4, [r4]
    adds r1, r1, r4
    str r1, [r0]
    @@ Init inp
    ldr r0, =var_inp
    ldr r1, =forth_file
    str r1, [r0]
    @@ Init inp
    ldr r0, =var_latest
    ldr r1, =latest_link_addr
    ldr r1, [r1]
    str r1, [r0]
    @@ Init state
    ldr r0, =var_state
    movs r1, #0
    str r1, [r0]
    @@ Jump to ram code area
    adds r2, r2, #1            
    blx r2
    @@ Save callee sp
    ldr r1, =saved_callee_sp
    ldr r0, [r1]
    mov r0, sp
    @@ Restore caller sp
    ldr r1, =saved_caller_sp
    ldr r0, [r1]
    mov sp, r0
    @@ Return
    poprsp pc
    .align 2
init_code_offset:
    .int code_offset_ram_to_flash
    .ltorg
    
	.set link, 0
	.macro defcode name, hash, flags=0, label
	.section .dict_field,"a",%progbits
	.align 2
	.globl name_\label
	link_\label:
	.int link
	.set link, link_\label
	.int \hash
	.int name_\label + \flags
	.int code_\label + code_offset_ram_to_flash    
	name_\label:
	.ascii "\name"
	.section .code_field,"ax",%progbits
    .ltorg
	.globl code_\label
    code_\label:
	.endm

	.macro defword name, hash, flags=0, label
	.section .dict_field,"a",%progbits
	.align 2
	.globl name_\label
	link_\label:
	.int link
	.set link, link_\label
	.int \hash
	.int name_\label + \flags
	.int code_\label + code_offset_ram_to_flash    
	name_\label:
	.ascii "\name"
	.section .code_field,"ax",%progbits
    .ltorg
	.globl code_\label
    code_\label:
	docol            
	.endm
    
	defword "init", 0x2ed8a004, 0, init
main_loop:
    bl code_interpret
    cmp r0, #0
    beq main_loop               @If neither error, nor end of buffer
    bl code_exit


	defcode "exit", 0xa8408e04, 0, exit
    poprsp pc

    @@ (a b -- a+b )
    defcode "+", 0x00002b01, 0, plus
    poppsp r0
    adds top, top, r0
    next

    @@ (a b -- a-b )
    defcode "-", 0x00002d01, 0, minus
    poppsp r0
    adds top, r0, top
    next

    @@ (a b -- a==b? )
    defcode "=", 0x00003d01, 0, equal
    poppsp r0
    cmp r0, top
    beq equal_equal
    movs top, #0    
    next    
equal_equal:
    movs top, #0        
    mvns top, top
    next

    @@ (a -- a+1 )
    defcode "1+", 0x00193e02, 0, one_plus
    adds top, top, #1
    next

    @@ (a -- a-1 )
    defcode "1-", 0x00194002, 0, one_minus
    subs top, top, #1
    next

    @@ (a b -- a&b )
    defcode "and", 0x199f1703, 0, and
    poppsp r0    
    ands top, top, r0
    next

    @@ (a -- not a )
    defcode "not", 0x1d071f03, 0, not
    cmp top, #0
    beq not_equal
    movs top, #0
    next    
not_equal:
    mvns top, top
    next

    @@ (32b addr -- )   *addr = 32b
    defcode "!", 0x00002101, 0, store
    poppsp r0
    strh r0, [top]
    lsrs r0, #16
    strh r0, [top, #2]    
    poppsp top
    next
    
    @@ (addr -- 32b)    top = *addr 
    defcode "@", 0x00004001, 0, fetch
    ldrh r0, [top, #2]
    lsls r0, #16
    ldrh r1, [top]
    adds top, r0, r1
    next

    @@ (16b addr -- )   *addr = 16b
    defcode "h!", 0x00355902, 0, half_store
    poppsp r0
    strh r0, [top]
    poppsp top
    next
    
    @@ (addr -- 16b)    top = *addr 
    defcode "h@", 0x00357802, 0, half_fetch
    ldrh top, [top]
    next

    @@ (8b addr -- )   *addr = 8b
    defcode "c!", 0x0032ca02, 0, byte_store
    poppsp r0
    strb r0, [top]
    poppsp top
    next
    
    @@ (addr -- 8b)    top = *addr 
    defcode "c@", 0x0032e902, 0, byte_fetch
    ldrb top, [top]
    next

    @@ TBD
    defcode "allot", 0x47532205, 0, allot
    next
    
    @@ ( -- 32b) top = *here
    defcode "here", 0x0a344004, 0, here
    pushpsp top
    ldr r0, =var_here
    ldr top, [r0]
    next

    @@ ( -- 32b) top = *state
    defcode "state", 0x4db2c905, 0, state
    pushpsp top
    ldr r0, =var_state
    ldr top, [r0]
    next

    @@ ( -- 32b) top = inp
    defcode "inp", 0x1bb76b03, 0, inp
    pushpsp top
    ldr top, =var_inp
    next

    @@ ( a b -- a ) drop
    defcode "drop", 0x8463cb04, 0, drop
    poppsp top
    next

    @@ ( a b -- b a) swap
    defcode "swap", 0x8837e304, 0, swap
    poppsp r0
    pushpsp top
    movs top, r0
    next

    @@ ( a -- a a) dup
    defcode "dup", 0x1a6bd303, 0, dup
    pushpsp top
    next

    @@ (32b -- ) *here = 32b, here += 4
    defcode ",", 0x00002c01, 0, comma
    ldr r0, =var_here
    ldr r1, [r0]
    strh top, [r1]
    lsrs top, #16
    strh top, [r1, #2]    
    poppsp top
    adds r1, #4
    str r1, [r0]
    next

    @@ (16b -- ) *here = 16b, here += 16
    defcode "h,", 0x00356402, 0, half_comma
    ldr r0, =var_here
    ldr r1, [r0]
    strh top, [r1]
    poppsp top
    adds r1, #2
    str r1, [r0]
    next

    @@ ( -- 16b ) Fetch the caller's following 16
    defcode "half_lit", 0x20d4fb08, 0, half_lit
    pushpsp top
    mov r0, lr
    subs r0, r0, #1
    ldrh top, [r0]
    adds r0, r0, #3
    mov lr, r0
    next


    @@ ( -- 32b ) Fetch the caller's following 32
    defcode "lit", 0x1c7dfb03, 0, lit
    pushpsp top
    mov r0, lr
    subs r0, r0, #1
    ldrh top, [r0]
    ldrh r1, [r0, #2]
    lsls r1, #16                @Little endian
    adds top, top, r1 
    adds r0, r0, #5
    mov lr, r0
    next

    defword "ascii", 0x3513f105, F_IMMED, ascii
    @@ Load a char from input buffer
    ldr r2, =var_inp
    ldr r0, [r2]    
ascii_skip_leading_blank:  
    ldrb r1, [r0]
    cmp r1, $' '
    bhi ascii_not_leading_blank
    adds r0, r0, #1
    b ascii_skip_leading_blank
ascii_not_leading_blank: 
    adds r0, r0, #1   
    str r0, [r2]
    ldr r0, =var_state
    ldr r0, [r0]
    pushpsp top
    movs top, r1
    cmp r0, 0
    beq ascii_in_compiling_state
    exit
ascii_in_compiling_state:
    bl code_compile
    bl code_half_lit
    bl code_half_comma
    exit

    @@ ( -- nfa hash) when input buffer is not empty or 
    @@ ( -- 0 ) otherwise
    defword "word", 0x0f5eae04, 0, word
    @@ Load a char from input buffer
    ldr r0, =var_inp
    ldr r0, [r0]    
word_skip_leading_blank:  
    ldrb r1, [r0]
    cmp r1, #0
    beq word_input_buffer_end
    cmp r1, $' '
    bhi word_not_leading_blank
    adds r0, r0, #1
    b word_skip_leading_blank
word_not_leading_blank:
    @@ Push NFA address
    pushpsp top
    pushpsp r0
    movs    top, r0
    movs    r2, 0
    movs    r3, #131
word_more_char:  
    @@ Calculate hash and len
    muls r2, r3, r2
    adds r2, r2, r1
    adds r0, r0, #1        
    ldrb r1, [r0]
    cmp r1, $' '
    bhi word_more_char
    lsls r2, r2, #8
    subs top, r0, top
    adds top, top, r2
    ldr r1, =var_inp
    str r0, [r1]
    exit
word_input_buffer_end:  
    @@ Push 0 onto the param stack
    pushpsp top
    movs top, 0
    exit

    @@ ( nfa hash -- lnk / nfa 0 ) Find a word in dict list, lnk = 0 if not found
    defword "find", 0xc6a32104, 0, find
    ldr r0, =var_latest
    movs r2, #0
find_is_not_the_word:   
    ldr r0, [r0]
    @@ If the (link == 0), not found
    cmp r0, r2
    beq find_not_found
    adds r1, r0, #4
    ldr r1, [r1]
    cmp r1, top
    bne find_is_not_the_word
    poppsp top
find_not_found: 
    movs top, r0
    exit


	@@ Enter interpretation mode
	defcode "[", 0x00005b01,F_IMMED,lbrac
	ldr	r0, =var_state
	movs r1, #1
	str	r1, [r0]
    next
	
	@@ Enter compilation mode
	defcode "]", 0x00005d01,,rbrac
	ldr	r0, =var_state
	movs r1, #0
	str	r1, [r0]	
    next
    
	defcode "save_context", 0x2228c10c,,save_context
    ldr r0, =var_latest
    ldr r0, [r0]
    ldr r1, =var_saved_link
    str r0, [r1]
    ldr r0, =var_here
    ldr r0, [r0]
    ldr r1, =var_saved_here
    str r0, [r1]
    ldr r0, =var_inp
    ldr r0, [r0]
    ldr r1, =var_saved_inp
    str r0, [r1]
    next
    
	defcode "restore_context", 0x734bd20f,,restore_context
    ldr r0, =var_saved_link
    ldr r0, [r0]
    ldr r1, =var_latest
    str r0, [r1]
    ldr r0, =var_saved_here
    ldr r0, [r0]
    ldr r1, =var_here
    str r0, [r1]
    ldr r0, =var_saved_inp
    ldr r0, [r0]
    ldr r1, =var_inp
    str r0, [r1]
    ldr r1, =var_outp           @ Roll back out pointer
    str r0, [r1]
    next
    
    @@ Make the latest defined word to immediate word
    defcode "immediate", 0x2d21dd09, F_IMMED, immediate
    ldr r0, =var_latest
    ldr r0, [r0]
    adds r0, r0, #8             @ Name Field Area
    ldr r2, [r0]
    movs r1, #1                 @ Set Immediate flag
    lsls r1, r1, #31
    adds r2, r2, r1
    str r2, [r0]
    next

    @@ always branch to the following addr
    defcode "branch", 0xdc7ac206,, branch
    mov r0, lr
    subs r0, r0, #1
    ldrh r1, [r0]
    adds r1, r1, #1
    ldrh r2, [r0, #2]
    lsls r2, #16                @Little endian
    add r2, r2, r1
    blx r2
    
    @@ if (top == 0) branch else don't branch
    defcode "?branch", 0xd0d52907,, zero_branch
    cmp top, #0
    mov r0, lr
    bne zero_branch_jump
    poppsp top
    subs r0, r0, #1
    ldrh r1, [r0]
    adds r1, r1, #1
    ldrh r2, [r0, #2]
    lsls r2, #16                @Little endian
    add r2, r2, r1
    blx r2
zero_branch_jump:
    poppsp top    
    adds r0, r0, #4
    blx r0
    
    @@ Start of word compiling
    defword ":", 0x00003a01, F_IMMED, colon
    @@ Save context first, in case of broken compiling
    bl code_save_context
    bl code_word
    bl code_create
    bl code_half_lit
    docol
    bl code_half_comma
    bl code_rbrac
    exit
    
    @@ End of word compiling
    defword ";", 0x00003b01, F_IMMED, semicolon
    bl code_half_lit
    exit
    bl code_half_comma
    bl code_lbrac
    exit
    
    @@ Compile a word
    @@ Even if it calls another word, it's still a code instead of a word as the lr is kept
    defcode "compile", 0xe3466f07, , compile
    pushpsp top
    mov r0, lr
    subs r0, r0, #1
    ldrh r2, [r0]
    lsls r2, #21
    asrs r2, #9    
    ldrh r1, [r0, #2]
    adds r0, r0, #4
    lsls r1, #21
    lsrs r1, #20
    adds top, r1, r2          
    adds top, top, r0           @ top = CFA of the word to be compiled
    adds r0, r0, #1
    pushrsp r0                  @ Store the lr
    bl code_to_mc_bl
    bl code_comma    
    exit    
    
    @@ ( -- ) Create a dict header 
    defword "create", 0xe69ddc06, 0, create
    @@ Put link into dict header 
    ldr r0, =var_latest
    ldr r1, [r0]
    ldr r3, =var_here           @ Load here and align it to 4x boundary
    ldr r2, [r3]
    adds r2, r2, #2
    lsrs r2, #2
    lsls r2, #2
    str r2, [r3]
    str r2, [r0]                @ Store here into latest
    pushpsp top
    movs top, r1
    bl code_comma
    bl code_comma               @ Put hash into dict header, "word" put this into stack
    bl code_comma               @ Put nfa into dict header, "word" put this into stack
    ldr r0, =var_here           @ Put cfa into dict header
    ldr r1, [r0]
    pushpsp top    
    adds top, r1, #4
    bl code_comma
    exit

    @@ (lnk -- cfa)
    defcode ">cfa", 0x68ec9804, , to_cfa
    adds top, top, #12
    ldr top, [top]
    next
    
    @@ (cfa -- machine_code_bl at here)
    defcode ">mc_bl", 0xbdfc3106, , to_mc_bl
    ldr r0, =var_here
    ldr r1, [r0]
    subs r2, top, r1
    subs r2, #4
    mov r3, r2
    lsls r2, #9                 @r2 = (r2 & 0x007FFFFF) >> 12 << 16
    lsrs r2, #21
    lsls r3, #20                @r3 = (r3 & 0xFFF) >> 1
    lsrs r3, #21
    movs r4, #0x1F              @r4 = 0xF800
    lsls r4, #11
    adds r3, r3, r4
    lsls r3, #16
    movs r4, #0xF               @r4 = 0xF000    
    lsls r4, #12
    adds r2, r2, r4
    adds top, r2, r3            @top = r2 + r3
    next

    @@ (nfa 0 -- number 1 / 0)
    @@ Only two types of number are supported, decimal and hexadecimal (0x...)
    defcode "number", 0x51a70106, , number
    poppsp r0                   @ A number?
    ldrb r1, [r0]
    cmp r1, $'0'
    blt number_error            @ Less than '0', error
    beq number_hex              @ Equal to '0', maybe a hex
    cmp r1, $'9'
    bhi number_error
    movs r3, $'0'
    subs r2, r1, r3
    movs r4, #10
number_dec_loop:
    adds r0, r0, #1
    ldrb r1, [r0]
    cmp r1, $' '
    ble number_done
    cmp r1, $'0'
    blt number_error
    cmp r1, $'9'
    bhi number_error
    subs r1, r1, r3
    muls r2, r2, r4             @ r2 *= 10
    adds r2, r2, r1             @ r2 += r1
    b number_dec_loop
number_hex:
    adds r0, r0, #1
    ldrb r1, [r0]
    movs r2, #0
    cmp r1, $' '
    ble number_done
    cmp r1, $'x'                @ Not start with "0x"
    bne number_error
    movs r4, #16
number_hex_loop:
    adds r0, r0, #1
    ldrb r1, [r0]
    cmp r1, $' '
    ble number_done
    cmp r1, $'0'
    blt number_error
    cmp r1, $'9'
    ble number_hex_zero_to_nine
    cmp r1, $'A'
    blt number_error
    cmp r1, $'F'
    ble number_hex_A_to_F
    cmp r1, $'a'
    blt number_error
    cmp r1, $'f'
    ble number_hex_a_to_f
    b number_error
number_hex_zero_to_nine:
    movs r3, $'0'
    subs r1, r1, r3
    muls r2, r2, r4             @ r2 *= 16
    adds r2, r2, r1             @ r2 += r1
    b number_hex_loop
number_hex_A_to_F:
    movs r3, $55                @ 'A' - 10 = 65 - 10 = 55
    subs r1, r1, r3
    muls r2, r2, r4             @ r2 *= 16
    adds r2, r2, r1             @ r2 += r1
    b number_hex_loop
number_hex_a_to_f:
    movs r3, $87                @ 'a' - 10 = 97 - 10 = 87
    subs r1, r1, r3
    muls r2, r2, r4             @ r2 *= 16
    adds r2, r2, r1             @ r2 += r1
    b number_hex_loop
number_done:
    movs top, #1
    pushpsp r2
number_error:
    next

    defword "key", 0x1c38eb03, , key
    
    next
    
    @@
    defword "interpret", 0x29a87d09, , interpret
    bl code_word
    cmp top, #0
    beq interpret_reach_the_end_of_buffer
    bl code_find
    cmp top, #0
    beq interpret_word_not_found
    ldr r0, [top, #8]
    movs r1, #1                 @ Check Immediate flag
    lsls r1, r1, #31             
    ands r0, r1, r0
    ldr r3, =var_state
    ldr r3, [r3]
    add r0, r0, r3              @ Immediate word or in interpretation state
    cmp r0, #0
    bne interpret_execute_word  @ Execute the word
    bl code_to_cfa              @ Otherwise, compile the word
    bl code_to_mc_bl
    bl code_comma
    movs r0, #0
    exit
interpret_execute_word:
    ldr r0, [top, #12]
    adds r0, r0, #1
    poppsp top
    blx r0
    movs r0, #0    
    exit
interpret_word_not_found:
    bl code_number
    cmp top, #0
    beq interpret_error
    ldr r3, =var_state
    ldr r3, [r3]
    cmp r3, #0
    bne interpret_execute_number  @ Execute the number
    ldr r3, =code_lit             @ Compile the lit
    ldr r4, =interpret_code_offset
    ldr r4, [r4]    
    adds top, r3, r4
    bl code_to_mc_bl
    bl code_comma
    bl code_comma
    movs r0, #0
    exit    
interpret_execute_number:
    movs r0, #0    
    poppsp top                  @ Just put the number on TOS
    exit
interpret_error:
    bl code_restore_context
    movs r0, #1
    movs r5, #1        
    exit
interpret_reach_the_end_of_buffer:
    movs r0, #2
    movs r5, #2            
    exit
    .align 2
interpret_code_offset:
    .int code_offset_ram_to_flash
    
    @@ Set __code_end__, should be placed at the end of the file
	.section .code_field,"ax",%progbits
    .ltorg
    .align 2
    .set __code_end__, .
    
	.section .dict_field,"a",%progbits
	.align 2
    
    .set latest_link, link
latest_link_addr:    
    .int latest_link
	.align 2    
forth_file:
	.incbin "./src/test.fs"	
	.align 2    
