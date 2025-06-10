// 8 Bit HEX BIN DEC Visualizer for Commodore C128 80 col VDC
// use CRSR UP and CRSR DOWN to change values (+1 / -1)
// Q to quit
// compiles with Kick Assembler (cross assembler)
// https://theweb.dk/KickAssembler/Main.html#frontpage

/* constants & zero page=============================================================== */

// https://github.com/franckverrot/EmulationResources/blob/master/consoles/commodore/C128%20RAM%20Map.txt
.const MMUCR    = $ff00         // bank configuration register
.const ATTRRAM  = $0800         // attribute ram VDC
.const VDCWRITE = $cdcc         // write to VDC kernal
.const VDCREAD  = $cdda         // read from VDC kernal
.const GETIN    = $ffe4         // kernal GETIN
.const CINT     = $c000         // kernal CINT Initialize Editor & Screen
// free zero page locations
.const temp1    = $fa           // to store temp values
.const temp2    = $fb           // to store temp values 
.const temp3    = $fc           // to store temp values 
.const temp4    = $fd           // to store temp values 

// keys
.const C_UP     = $91           // cursor down key
.const C_DOWN   = $11           // cursor up key
.const Q        = $51           // Q key

// variables
current_value: .byte $80        // start value is 128; change?:
param:         .byte 0          // to store temp values
param_num:     .byte 0          // to store temp values


// from https://fightingcomputers.nl/Projects/Commodore-128/Commodore-128-assembly---Part-1
BasicUpstart128(Start)

*=$2200

/* start ============================================================================== */
Start:
    lda #%00000000              // bank id 15
    sta MMUCR                   // set bank
    jsr CINT                    // initialize editor & screen

// prepare loading chars
// src 1: char data
    lda #0                      // load 0
    sta temp1                   // VDC update low byte
    sta temp2                   // VDC update hight byte
    sta temp3                   // src 1 (chars) lb = $00
    lda #$29                    // load $29
    sta temp4                   // src 1 (chars) hb = $29 = $2900
    ldy #0                      // load 0

// loop to load all chars
loop_ch:
    ldx #18                     // register of screen addr high byte 
    lda temp2                   // load VDC high byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #19                     // register of screen addr low byte 
    lda temp1                   // load VDC low byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #31                     // data register of VDC
    ldy temp1                   // low byte VDC is also counter for screen char data
    lda (temp3),y               // load char to data register from src 1
    jsr VDCWRITE                // kernal to write to VDC
    inc temp1                   // increment temp1
    bne loop_ch                 // -> 255 exit inner loop
        
    inc temp4                   // increment high byte src1
    inc temp2                   // increment high byte VDC update
    lda temp2                   // load high byte VDC update
    cmp #8                      // is it 8 (x 256) ?
    bne loop_ch                 // = 8 ? exit loop, all chars on screen

// prepare loading colors / attributes
// src 2: color data
    lda #0                      // load 0
    sta temp1                   // VDC update low byte
    sta temp2                   // VDC update hight byte
    sta temp3                   // src 2 lb = $00
    lda #$31                    // load $31
    sta temp4                   // src 2 hb = $31 = $3100
    ldy #0                      // load 0

loop_col:
    ldx #18                     // register of screen addr high byte 
    lda temp2                   // load VDC high byte
    clc                         // clear carry
    adc #>ATTRRAM               // add attribute ram address to high byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #19                     // register of screen addr low byte 
    lda temp1                   // load VDC low byte
    clc                         // clear carry
    adc #<ATTRRAM               // add attribute ram address to lowh byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #31                     // data register of VDC
    ldy temp1                   // low byte VDC is also counter for color data
    lda (temp3),y 
    jsr VDCWRITE                // kernal to write to VDC
   
    inc temp1                   // increment temp1
    bne loop_col                // > 255 exit inner loop
        
    inc temp4                   // increment high byte src1
    inc temp2                   // increment high byte VDC update
    lda temp2                   // load high byte VDC update
    cmp #8                      // is it 8 (x 256) ?
    bne loop_col                // = 8 ? exit loop, all chars on screen

// display current_value (from top)
    lda current_value           // load current_value (from top)
    sta param_num               // store in param_num
    jsr output                  // -> output

// main prg loop
main_loop:
    jsr handle_input            // -> check keys
    cmp #Q                      // if acc is 'Q' -> exit 
    bne main_loop               // else loop
    jsr exit                    // -> exit

// exit prg
exit:
    jsr CINT                    // initialize editor & screen
    rts                         // exit to BASIC
    
handle_input:
    jsr GETIN                   // get pressed key from keyboard buffer
    beq no_key                  // 0 if no key is pressed -> no_key
    cmp #C_UP                   // cursor up pressed (SHIFT+CRSR DOWN)
    beq increase_value          // -> increase value
    cmp #C_DOWN                 // cursor down pressed
    beq decrease_value          // -> decrease value
    cmp #Q                      // 'Q' pressed
    beq quit_program            // -> quit
    bne handle_input            // loop
        
no_key:
    rts                         // no key pressed

increase_value:
    inc current_value           // current_value +1
    lda current_value           // load current_value 
    jsr output                  // -> output / display values
    rts

decrease_value:
    dec current_value           // current_value -1
    lda current_value           // load current_value 
    jsr output                  // -> output / display values
    rts

quit_program:
    rts                         // -> main_loop and QUIT

// display values    
output:
    sta param_num               // save current_value
    lda param_num               // load current_value for hexout
    jsr hexout                  // -> hexout, HEX display
    lda param_num               // load current_value for binout
    jsr binout                  // -> binout, BIN and BIN mult. display
    lda param_num               // load current_value for binout
    jsr decout                  // -> decout, DEC display
    rts

// hexout
// display HEX chars
// adapted from https://www.c64-wiki.de/wiki/bildschirmausgabe.asm
hexout:
   pha                          // push acc to stack
   lsr                          // shift one bit right
   lsr                          // 4 times
   lsr
   lsr
   tay                          // transfer to x, index for upper 4 bits
   lda hex_digits,y             // load hex chars
   PrintRegACharAt(23,3)        // macro to display accu content at x,y
   PrintRegACharAt(10,3)        // macro to display accu content at x,y
   PrintRegACharAt(70,3)        // macro to display accu content at x,y
   
   pla                          // get acc from stack
   and #$0f                     // mask lower 4 bits
   tay                          // transfer to x, index for lower 4 bits
   lda hex_digits,y             // load char for upper 4 bits from hex_digits
   PrintRegACharAt(24,3)        // macro: display acc content at x,y
   PrintRegACharAt(37,3)        // macro: display acc content at x,y
   PrintRegACharAt(71,3)        // macro: display acc content at x,y
   rts                          // -> output

    hex_digits:
   // codes for 0 to 9
   .byte $30, $31, $32, $33, $34, $35, $36, $37, $38, $39
   // codes for A to F
   .byte $01, $02, $03, $04, $05, $06

// binout 
// display binary 0 and 1 chars
// adapted from https://www.c64-wiki.de/wiki/bildschirmausgabe.asm
binout:
    sta param                   // save byte to convert into bin
    ldx #$07                    // set x to 7 (loop 7 to 0)
bin_loop:
    txa                         // transfer x to acc
    pha                         // push acc to stack
    lda param                   // load byte
    asl                         // shift left (bit 7 to carry)
    sta param                   // store shifted value
    bcc bit_zero                // if carry clear (is 0) -> direct to bit_zero ('0')
    lda #$31                    // '1' into acc
    bne write_bit               // -> write_bit
bit_zero:
    lda #$30                    // '0' into acc -> write_bit

write_bit:
    cpx #$07                    // is bit == bit 7 ? 
    bne bit6                    // branch to -> bit 6 
    PrintRegACharAt(1,8)        // macro: display acc content at x,y
    PrintRegACharAt(64,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,21)      // macro: display acc content at x,y
    cmp #$30                    // is char zero?
    beq !write_zero+            // -> write_zero
    jmp print_128               // -> print '128'
!write_zero:                    
    jmp print_0                 // -> print '0'
bit6:
    cpx #$06                    // is bit == bit 6 ?      
    bne bit5                    // branch to -> bit 5    
    PrintRegACharAt(7,8)        // macro: display acc content at x,y
    PrintRegACharAt(65,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,20)      // macro: display acc content at x,y
    cmp #$30                    // is char zero?
    beq !write_zero+            // -> write_zero
    jmp print_64                // -> print '64'
!write_zero:
    PrintRegACharAt(71,20)      // print '0'
    lda #$20                    // load ' '
    PrintRegACharAt(70,20)      // print ' ' to delete 6 from 64
    jmp next                    // -> next
bit5:
    cpx #$05                    // is bit == bit 5 ? 
    bne bit4                    // branch to -> bit 4
    PrintRegACharAt(13,8)       // macro: display acc content at x,y
    PrintRegACharAt(66,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,19)      // macro: display acc content at x,y
    cmp #$30                    // is char zero?
    beq !write_zero+            // -> write_zero
    jmp print_32                // -> print '32'
!write_zero:
    PrintRegACharAt(71,19)      // print '0'
    lda #$20                    // load ' '
    PrintRegACharAt(70,19)      // print ' ' to delete 3 from 32
    jmp next                    // -> next
bit4:
    cpx #$04                    // is bit == bit 4 ?       
    bne bit3                    // branch to -> bit 3
    PrintRegACharAt(19,8)       // macro: display acc content at x,y
    PrintRegACharAt(67,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,18)      // macro: display acc content at x,y
    cmp #$30                    // is char zero?
    beq !write_zero+            // -> write_zero
    jmp print_16                // -> print '16'
!write_zero:
    PrintRegACharAt(71,18)      // print '0'
    lda #$20                    // load ' '
    PrintRegACharAt(70,18)      // print ' ' to delete 1 from 16
    jmp next                    // -> next
bit3:
    cpx #$03                    // is bit == bit 3 ? 
    bne bit2                    // branch to -> bit 2
    PrintRegACharAt(28,8)       // macro: display acc content at x,y
    PrintRegACharAt(68,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,17)      // macro: display acc content at x,y
    cmp #$30                    // is char zero?
    beq !write_zero+            // -> write_zero
    jmp print_8                 // -> print '8'
!write_zero:
    PrintRegACharAt(71,17)      // print '0'
    jmp next                    // -> next
bit2:
    cpx #$02                    // is bit == bit 2 ?      
    bne bit1                    // branch to -> bit 1
    PrintRegACharAt(34,8)       // macro: display acc content at x,y
    PrintRegACharAt(69,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,16)      // macro: display acc content at x,y
    cmp #$30                    // is char zero?
    beq !write_zero+            // -> write_zero
    jmp print_4                 // -> print '4'
!write_zero:
    PrintRegACharAt(71,16)      // print '0'
    jmp next                    // -> next
bit1:
    cpx #$01                    // is bit == bit 1 ? 
    bne bit0                    // branch to -> bit 0
    PrintRegACharAt(40,8)       // macro: display acc content at x,y
    PrintRegACharAt(70,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,15)      // macro: display acc content at x,y
    cmp #$30                    // is char zero?
    beq !write_zero+            // -> write_zero
    jmp print_2                 // -> print '2'
!write_zero:
    PrintRegACharAt(71,15)      // print '0'
    jmp next                    // -> next
bit0:
    cpx #$00                    // is bit == bit 0 ?    
    PrintRegACharAt(46,8)       // macro: display acc content at x,y
    PrintRegACharAt(71,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,14)      // macro: display acc content at x,y
    PrintRegACharAt(71,14)      // macro: display acc content at x,y
    jmp next                    // jmp to -> next (next bit)
    rts                         // unreachable, but safety fallback

next:
    pla                         // get acc from stack, restore previous bit index
    tax                         // transfer to x
    dex                         // decrement x to the next lower bit
    bpl jmp_to_bin_loop         // if x > 0 -> bin loop
    rts                         // all bits processed, return

jmp_to_bin_loop:
    jmp bin_loop                // back to bin_loop (distance to long ....)

// print '2' at x,y
print_2:
    lda #$32
    PrintRegACharAt(71,15)
    jmp next

// print '4' at x,y
print_4:
    lda #$34
    PrintRegACharAt(71,16)
    jmp next

// print '8' at x,y
print_8:
    lda #$38
    PrintRegACharAt(71,17)
    jmp next

// print '16' at x,y
print_16:
    lda #$31
    PrintRegACharAt(70,18)
    lda #$36
    PrintRegACharAt(71,18)
    jmp next
    
// print '32' at x,y    
print_32:
    lda #$33
    PrintRegACharAt(70,19)
    lda #$32
    PrintRegACharAt(71,19)
    jmp next

// print '64' at x,y    
print_64:
    lda #$36
    PrintRegACharAt(70,20)
    lda #$34
    PrintRegACharAt(71,20)
    jmp next

// print '128' at x,y
print_128:
    lda #$31
    PrintRegACharAt(69,21)
    lda #$32
    PrintRegACharAt(70,21)
    lda #$38
    PrintRegACharAt(71,21)
    jmp next

// print '  0' at x,y
print_0:
    PrintRegACharAt(71,21)
    lda #$20
    PrintRegACharAt(69,21)
    PrintRegACharAt(70,21)
    jmp next 
    
// decout
// display decimals 0 to 255
decout:
    sta param                   // store value
    // 100 digit 
    ldx #$00                    // x counts how many times 100 can be subtracted   
    lda param                   // load value
    sec                         // set carry flag (for sbc)
decout_hund_loop:
    sbc #100                    // subtract 100
    bcc decout_hund_done        // if result < 0 branch to done -> decout_hund_done
    sta param                   // save remaining value
    inx                         // increment hundreds counter
    jmp decout_hund_loop        // repeat

decout_hund_done:
    txa                         // transfer count to acc (0, 1, 2)
    ora #$30                    // convert to num chars ('0', '1', '2')
    cmp #$30                    // is it a leading zero?
    bne !write_num+             // -> write_num (print number)
    lda #$20                    // load ' '
    PrintRegACharAt(69,23)      // macro: display acc content at x,y (' ')
    ldy #$11                    // remember ' ' was printed (for no leading 0)
!write_num:
    PrintRegACharAt(69,23)      // macro: display acc content at x,y (hundreds) 

    // 10 digit
    ldx #$00                    // reset x for 10 digits
    lda param                   // load remaining value (0 to 99) 
    sec                         // set carry flag (for sbc) 
decout_tens_loop:
    sbc #10                     // subtract 10
    bcc decout_tens_done        // if result < 0 branch to done -> decout_tens_done
    sta param                   // save remaining value
    inx                         // increment tens counter
    jmp decout_tens_loop        // repeat

decout_tens_done:
    txa                         // transfer count to acc (0 to 9)
    ora #$30                    // convert to num chars ('0' to '9')
    cmp #$30                    // is it a leading zero?
    bne !write_num+             // -> write_num (print number) 
    cpy #$11                    // was there a leading zero from the hundreds?
    bne !write_num+             // -> write_num (print number) 
    lda #$20                    // load ' '
    ldy #$0                     // set y reg to zero (reset remember bit)
    PrintRegACharAt(70,23)      // macro: display acc content at x,y (' ')
!write_num:
    PrintRegACharAt(70,23)      // macro: display acc content at x,y (tens)
    
    // 1 digit
    lda param                   // load remaining value (0 to 9) 
    ora #$30                    // convert to num chars ('0' to '9')
    PrintRegACharAt(71,23)      // macro: display acc content at x,y (ones)
    rts                         // return

/* macros ============================================================================= */

.macro PrintRegACharAt(x,y) {
    pha
    .var screen_addr = y*80 + x // calc screen pos as 16 bit address
    ldx #18                     // register of screen addr high byte 
    lda #>screen_addr           // load high byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #19                     // register of screen addr low byte 
    lda #<screen_addr           // load low byte
    jsr VDCWRITE                // kernal to write to VDC
    pla
    ldx #31                     // data register of VDC
    jsr VDCWRITE                // kernal to write to VDC
}
// https://fightingcomputers.nl/Projects/Commodore-128/Commodore-128-assembly---Part-1
// https://github.com/wiebow/examples.c128
.macro BasicUpstart128(address) {   //
    .pc = $1c01 "C128 Basic"        //
    .word upstartEnd                // link address  
    .word 10                        // line num  
    .byte $9e                       // sys  
    .text toIntString(address)      //
    .byte 0  
upstartEnd:  
    .word 0                         // empty link signals the end of the program  
    .pc = $1c0e "Basic End" 
}  

/* data =============================================================================== */

// screen character data
// https://petscii.krissz.hu
*=$2900 "Screen character data"
    .byte $08,$05,$18,$20,$02,$09,$0E,$20,$04,$05,$03,$20,$16,$09,$13,$15,$01,$0C,$09,$1A,$05,$12,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$03,$31,$32,$38,$20,$16,$04,$03,$20,$16,$05,$12,$13,$09,$0F,$0E,$20,$32,$30,$32,$35
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$4F,$77,$50,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$4F,$77,$77,$50,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$4F,$77,$50,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$74,$30,$67,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$74,$30,$30,$6A,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$74,$30,$67,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$30,$30,$20,$20,$20,$20,$20,$08,$05,$18
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$4C,$6F,$7A,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$4C,$6F,$6F,$7A,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$4C,$6F,$7A,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$70,$40,$40,$40,$40,$40,$72,$43,$43,$71,$40,$40,$72,$40,$40,$40,$40,$40,$6E,$20,$20,$20,$20,$20,$20,$20,$20,$70,$40,$40,$40,$40,$40,$72,$43,$43,$71,$40,$40,$72,$40,$40,$40,$40,$40,$6E,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $4F,$77,$50,$20,$20,$20,$4F,$77,$50,$20,$20,$20,$4F,$77,$50,$20,$20,$20,$4F,$77,$50,$20,$20,$20,$20,$20,$20,$4F,$77,$50,$20,$20,$20,$4F,$77,$50,$20,$20,$20,$4F,$77,$50,$20,$20,$20,$4F,$77,$50,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $74,$30,$67,$20,$20,$20,$74,$30,$67,$20,$20,$20,$74,$30,$67,$20,$20,$20,$74,$30,$67,$20,$20,$20,$20,$20,$20,$74,$30,$67,$20,$20,$20,$74,$30,$67,$20,$20,$20,$74,$30,$67,$20,$20,$20,$74,$30,$67,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$31,$31,$31,$31,$31,$31,$31,$31,$20,$20,$20,$20,$20,$02,$09,$0E
    .byte $4C,$6F,$7A,$20,$20,$20,$4C,$6F,$7A,$20,$20,$20,$4C,$6F,$7A,$20,$20,$20,$4C,$6F,$7A,$20,$20,$20,$20,$20,$20,$4C,$6F,$7A,$20,$20,$20,$4C,$6F,$7A,$20,$20,$20,$4C,$6F,$7A,$20,$20,$20,$4C,$6F,$7A,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $32,$1E,$37,$20,$20,$20,$32,$1E,$36,$20,$20,$20,$32,$1E,$35,$20,$20,$20,$32,$1E,$34,$20,$20,$20,$20,$20,$20,$32,$1E,$33,$20,$20,$20,$32,$1E,$32,$20,$20,$20,$32,$1E,$31,$20,$20,$20,$32,$1E,$30,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$6D,$40,$40,$40,$43,$43,$43,$43,$43,$43,$43,$43,$20,$31,$20,$2A,$20,$20,$20,$31,$20,$3D,$20,$20,$20,$31,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$6D,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$40,$20,$31,$20,$2A,$20,$20,$20,$32,$20,$3D,$20,$20,$20,$32,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$6D,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$20,$31,$20,$2A,$20,$20,$20,$34,$20,$3D,$20,$20,$20,$34,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$20,$20,$20,$6D,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$20,$31,$20,$2A,$20,$20,$20,$38,$20,$3D,$20,$20,$20,$38,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$6D,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$20,$31,$20,$2A,$20,$20,$31,$36,$20,$3D,$20,$20,$31,$36,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$42,$20,$20,$20,$20,$20,$42,$20,$20,$20,$20,$20,$6D,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$20,$31,$20,$2A,$20,$20,$33,$32,$20,$3D,$20,$20,$33,$32,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$42,$20,$20,$20,$20,$20,$6D,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$20,$31,$20,$2A,$20,$20,$36,$34,$20,$3D,$20,$20,$36,$34,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$6D,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$43,$20,$31,$20,$2A,$20,$31,$32,$38,$20,$3D,$20,$31,$32,$38,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$2D,$2D,$2D,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$32,$35,$35,$20,$20,$20,$20,$20,$04,$05,$03
    .byte $1B,$03,$12,$13,$12,$20,$15,$10,$1D,$20,$2B,$31,$20,$20,$20,$1B,$03,$12,$13,$12,$20,$04,$0F,$17,$0E,$1D,$20,$2D,$31,$20,$20,$20,$1B,$11,$1D,$20,$11,$15,$09,$14,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20


// screen color data
// https://petscii.krissz.hu
*=$3100 "Screen color data"
    .byte $05,$05,$05,$01,$0D,$0D,$0D,$0E,$07,$07,$07,$01,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0F,$0F,$0F,$0F,$01,$0F,$0F,$0F,$01,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$01,$0F,$0F,$0F,$0F
    .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$05,$05,$05,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$05,$05,$05,$05,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$05,$05,$05,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$05,$05,$0E,$0E,$0E,$0E,$0E,$05,$05,$05
    .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$05,$05,$05,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$05,$05,$05,$05,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$05,$05,$05,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
    .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$05,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$05,$01,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$0E,$0E,$0E
    .byte $01,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0E,$0E,$0E,$01,$01,$01,$01,$0E,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$01,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$01,$01,$01,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$0E,$0E,$01,$01,$01,$01,$01,$0E,$0E
    .byte $0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$0E
    .byte $0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$01,$01,$0E,$0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0E,$01,$01,$0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$01,$01,$0E,$0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0E,$0D,$0D,$0D
    .byte $0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$01,$01,$0E,$0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0E,$01,$01,$0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$01,$01,$0E,$0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $01,$01,$01,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$0E,$0E,$01,$01,$01,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$0E,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0D,$0E,$01,$0E,$0E,$0E,$01,$0E,$01,$01,$0E,$0E,$07,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0D,$0E,$01,$0E,$0E,$0E,$01,$0E,$01,$01,$0E,$0E,$07,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0D,$0E,$01,$0E,$0E,$0E,$01,$0E,$01,$01,$0E,$0E,$07,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0D,$0E,$01,$0E,$0E,$0E,$01,$0E,$01,$01,$0E,$0E,$07,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0D,$0E,$01,$0E,$0E,$01,$01,$0E,$01,$01,$0E,$07,$07,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0D,$0E,$01,$0E,$0E,$01,$01,$0E,$01,$01,$0E,$07,$07,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0D,$0E,$01,$0E,$0E,$01,$01,$0E,$01,$01,$0E,$07,$07,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0D,$0E,$01,$0E,$01,$01,$01,$01,$01,$01,$07,$07,$07,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$0E,$01,$01,$01,$07,$07,$07,$0E,$0E,$0E,$0E,$0E,$07,$07,$07
    .byte $09,$09,$09,$09,$09,$01,$09,$09,$09,$01,$09,$09,$0E,$01,$01,$09,$09,$09,$09,$09,$01,$09,$09,$09,$09,$09,$01,$09,$09,$0E,$0E,$0E,$09,$09,$09,$0E,$09,$09,$09,$09,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01


