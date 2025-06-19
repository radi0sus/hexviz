// 8 Bit HEX BIN DEC Visualizer for Commodore C128 80 col VDC
// use CRSR UP and CRSR DOWN to change values (+1 / -1)
// manipulate values with ASL, LSR, ROL, ROR 
// H for help
// Q to quit
// compiles with Kick Assembler (cross assembler)
// https://theweb.dk/KickAssembler/Main.html#frontpage

/* constants & zero page ============================================================== */

// https://github.com/franckverrot/EmulationResources/blob/master/consoles/commodore/C128%20RAM%20Map.txt
.const MMUCR    = $ff00         // bank configuration register
.const VDCWRITE = $cdcc         // kernal write to VDC 
.const VDCREAD  = $cdda         // kernal read from VDC 
.const GETIN    = $ffe4         // kernal GETIN
.const CINT     = $c000         // kernal CINT Initialize Editor & Screen

// mem locations
.const PRG      = $2010         // main prg
.const CHR_DATA = $3000         // char data
.const COL_DATA = $3800         // color (attribute) data
.const CHR_DAT2 = $4000         // char data help screen
.const COL_DAT2 = $4800         // color (attribute) data help screen
.const VDCRAM   = $0000         // basic VDC ram
.const VDCRAM2  = $1000         // empty VDC ram (help screen)
.const ATTRRAM  = $0800         // attribute ram VDC
.const ATTRRAM2 = $1800         // attribute ram VDC help screen

// free zero page locations
.const temp1    = $fa           // to store temp values
.const temp2    = $fb           // to store temp values 
.const temp3    = $fc           // to store temp values 
.const temp4    = $fd           // to store temp values 

// keys
.const C_UP     = $91           // cursor down key -1
.const C_DOWN   = $11           // cursor up key   +1
.const A_LEFT   = $9D           // arrow left  < asl
.const A_RIGHT  = $1D           // arrow right > lsr 
.const N        = $4E           // N key rol < carry = 0
.const M        = $4D           // M key ror > carry = 0
.const V        = $56           // V key rol < carry = 1
.const B        = $42           // B key ror > carry = 1
.const H        = $48           // H key (help)
.const Q        = $51           // Q key (quit)

// variables
current_value:  .byte $80       // start value is 128; change?:
param:          .byte 0         // to store temp values
param_num:      .byte 0         // to store temp values
sreg_values:    .byte 0         // status reg values

screen_lb:      .byte 0         // VDC screen address low byte
screen_hb:      .byte 0         // VDC screen address high byte
arr_ptr_s:      .byte 0         // list index of of number start in ar_xxx
arr_ptr_e:      .byte 0         // list index of of number end in ar_xxx

/* ==================================================================================== */

BasicUpstart128(start)

*=PRG "Program"

/* start ============================================================================== */
start:
    jsr CINT                    // initialize editor & screen
    lda #$06                    // bank id 12 for more ram
    sta MMUCR                   // tell mmu to switch bank

/* load screens and color data to ram ================================================= */
// prepare loading chars
// src 1: char data
    lda #0                      // load 0
    sta temp1                   // counter inner loop
    sta temp2                   // counter outer loop
    lda #<CHR_DATA              // load src 1 (chars) lb
    sta temp3                   // store src 1 (chars) lb
    lda #>CHR_DATA              // load src 1 (chars) hb 
    sta temp4                   // store src 1 (chars) hb 
    ldy #0                      // load 0


    ldx #18                     // register of screen addr high byte 
    lda #>VDCRAM                // load VDC high byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #19                     // register of screen addr low byte 
    lda #<VDCRAM                // load VDC low byte
    jsr VDCWRITE                // kernal to write to VDC
    
// loop to load all chars
loop_ch:
    ldx #31                     // data register of VDC
    ldy temp1                   // inner counter for screen char data
    lda (temp3),y               // load char to VDC data register from src 1
    jsr VDCWRITE                // kernal to write to VDC
    inc temp1                   // increment temp1
    bne loop_ch                 // -> 255 exit inner loop
        
    inc temp4                   // increment high byte src 1
    inc temp2                   // counter outer loop
    lda temp2                   // load counter outer loop
    cmp #8                      // is it 8 (x 256) ?
    bne loop_ch                 // = 8 ? exit loop, all chars on screen

// prepare loading colors / attributes
// src 2: color data
    lda #0                      // load 0
    sta temp1                   // counter inner loop
    sta temp2                   // counter outer loop
    lda #<COL_DATA              // load src 2 (color) lb
    sta temp3                   // store src 2 (color) lb
    lda #>COL_DATA              // load src 2 (color) hb
    sta temp4                   // store src 2 (color) hb
    ldy #0                      // load 0

    ldx #18                     // register of screen addr high byte 
    lda #>ATTRRAM               // load attribute ram address high byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #19                     // register of screen addr low byte 
    lda #<ATTRRAM               // load attribute ram address low byte
    jsr VDCWRITE                // kernal to write to VDC
    
// loop to load all colors
loop_col:
    ldx #31                     // data register of VDC
    ldy temp1                   // inner counter for screen color data
    lda (temp3),y               // load attributes to VDC attribute ram from src 2
    jsr VDCWRITE                // kernal to write to VDC
    inc temp1                   // increment temp1
    bne loop_col                // > 255 exit inner loop
        
    inc temp4                   // increment high byte src 2
    inc temp2                   // counter outer loop
    lda temp2                   // load counter outer loop
    cmp #8                      // is it 8 (x 256) ?
    bne loop_col                // = 8 ? exit loop, all chars on screen

/* display current_value (changeable, see top) ======================================== */
    lda current_value           // load current_value (from top)
    sta param_num               // store in param_num
    jsr output                  // -> output

/* load screens and color data to ram ================================================= */
// prepare loading chars
// src 3: char data 3
// help screen
    lda #0                      // load 0
    sta temp1                   // counter inner loop
    sta temp2                   // counter outer loop
    lda #<CHR_DAT2              // load src 1 (chars) lb
    sta temp3                   // store src 1 (chars) lb
    lda #>CHR_DAT2              // load src 1 (chars) hb 
    sta temp4                   // store src 1 (chars) hb 
    ldy #0                      // load 0
    
    ldx #18                     // register of screen addr high byte 
    lda #>VDCRAM2               // load VDC high byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #19                     // register of screen addr low byte 
    lda #<VDCRAM2               // load VDC low byte
    jsr VDCWRITE                // kernal to write to VDC
    
// loop to load all chars
loop_ch2:
    ldx #31                     // data register of VDC
    ldy temp1                   // inner counter for screen char data
    lda (temp3),y               // load char to VDC data register from src 3
    jsr VDCWRITE                // kernal to write to VDC
    inc temp1                   // increment temp1
    bne loop_ch2                // -> 255 exit inner loop
        
    inc temp4                   // increment high byte src 3
    inc temp2                   // counter outer loop
    lda temp2                   // load counter outer loop
    cmp #8                      // is it 8 (x 256) ?
    bne loop_ch2                // = 8 ? exit loop, all chars on screen
        
// prepare loading colors / attributes
// src 4: color data 4
// help screen
    lda #0                      // load 0
    sta temp1                   // counter inner loop
    sta temp2                   // counter outer loop
    lda #<COL_DAT2              // load src 2 (color) lb
    sta temp3                   // store src 2 (color) lb
    lda #>COL_DAT2              // load src 2 (color) hb
    sta temp4                   // store src 2 (color) hb
    ldy #0                      // load 0

    ldx #18                     // register of screen addr high byte 
    lda #>ATTRRAM2              // load attribute ram address high byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #19                     // register of screen addr low byte 
    lda #<ATTRRAM2              // load attribute ram address low byte
    jsr VDCWRITE                // kernal to write to VDC
    
// loop to load all colors
loop_col2:
    ldx #31                     // data register of VDC
    ldy temp1                   // inner counter for screen color data
    lda (temp3),y               // load attributes to VDC attribute ram from src 4
    jsr VDCWRITE                // kernal to write to VDC
    inc temp1                   // increment temp1
    bne loop_col2               // > 255 exit inner loop
        
    inc temp4                   // increment high byte src 4
    inc temp2                   // counter outer loop
    lda temp2                   // load counter outer loop
    cmp #8                      // is it 8 (x 256) ?
    bne loop_col2               // = 8 ? exit loop, all chars on screen
/* ==================================================================================== */

// main prg loop
main_loop:
    jsr handle_input            // -> check keys
    cmp #Q                      // if acc is 'Q' -> exit 
    bne main_loop               // else loop
    jsr exit                    // -> exit

// exit prg
exit:
    jsr CINT                    // initialize editor & screen
    lda #$00                    // bank id 15 (default)
    sta MMUCR                   // tell mmu to switch bank
    rts                         // exit to BASIC
    
handle_input:
    jsr GETIN                   // get pressed key from keyboard buffer
    beq no_key                  // 0 if no key is pressed -> no_key
    cmp #C_UP                   // cursor up pressed (SHIFT+CRSR DOWN)
    beq increase_value          // -> increase value
    cmp #C_DOWN                 // cursor down pressed
    beq decrease_value          // -> decrease value
    cmp #A_LEFT                 // left arrow key pressed
    beq shift_value_left        // multiply by 2 (asl)
    cmp #A_RIGHT                // left arrow key pressed
    beq shift_value_right       // division by 2 (lsr)
    cmp #N                      // N key pressed
    beq rotate_value_left_c0    // rol carry = 0 
    cmp #V                      // V key pressed
    beq rotate_value_left_c1    // rol carry = 1 
    cmp #A_RIGHT                // left arrow key pressed
    beq shift_value_right       // division by 2 (lsr)
    cmp #M                      // M key pressed
    beq rotate_value_right_c0   // ror carry = 0
    cmp #B                      // B key pressed
    beq rotate_value_right_c1   // ror carry = 1
    cmp #H                      // H key pressed
    beq show_help               // -> show help screen
    cmp #Q                      // 'Q' pressed
    rts                         // -> to main_loop and quit

no_key:
    rts                         // no key pressed

increase_value:
    inc current_value           // current_value +1
    clc                         // avoid carry 1 with inc ? 
    jsr show_status             // -> show flags
    lda current_value           // load current_value 
    jsr output                  // -> output / display values
    rts

decrease_value:
    dec current_value           // current_value -1
    clc                         // avoid carry 1 with dec ? 
    jsr show_status             // -> show flags
    lda current_value           // load current_value 
    jsr output                  // -> output / display values
    rts

shift_value_left:
    asl current_value           // current_value * 2
    jsr show_status             // -> show flags
    lda current_value           // load current_value 
    jsr output                  // -> output / display values
    rts
    
shift_value_right:
    lsr current_value           // current_value /2
    jsr show_status             // -> show flags
    lda current_value           // load current_value 
    jsr output                  // -> output / display values
    rts

rotate_value_left_c0:
    clc
    rol current_value           // current_value * 2
    jsr show_status             // -> show flags
    lda current_value           // load current_value 
    jsr output                  // -> output / display values
    rts
    
rotate_value_right_c0:
    clc
    ror current_value           // current_value /2
    jsr show_status             // -> show flags
    lda current_value           // load current_value 
    jsr output                  // -> output / display values
    rts

rotate_value_left_c1:
    sec
    rol current_value           // current_value * 2
    jsr show_status             // -> show flags
    lda current_value           // load current_value 
    jsr output                  // -> output / display values
    rts
    
rotate_value_right_c1:
    sec
    ror current_value           // current_value /2
    jsr show_status             // -> show flags
    lda current_value           // load current_value 
    jsr output                  // -> output / display values
    rts
   
show_help:
    // change vdc ram to preloaded help screen location
    ldx #12                     // register of screen addr high byte 
    lda #>VDCRAM2               // load VDC high byte of help screen
    sta $0A2E                   // screen mem starting page pointer
    jsr VDCWRITE                // kernal to write to VDC
    ldx #13                     // register of screen addr low byte
    lda #<VDCRAM2               // load VDC low byte
    jsr VDCWRITE                // kernal to write to VDC
    
    // change vdc attribute ram to preloaded help screen
    ldx #20                     // register of screen addr high byte 
    lda #>ATTRRAM2              // load VDC high byte
    sta $0A2E                   // screen mem starting page pointer
    jsr VDCWRITE                // kernal to write to VDC
    ldx #21                     // register of screen addr high byte 
    lda #<ATTRRAM2              // load VDC high byte
    jsr VDCWRITE                // kernal to write to VDC
    
no_key_pressed:                 // any key switches back to main program
    jsr GETIN                   // get pressed key from keyboard buffer
    beq no_key_pressed          // loop forever if no key is pressed
    // set vdc ram back to main program
    ldx #12                     // register of screen addr high byte 
    lda #>VDCRAM                // load VDC high byte
    sta $0A2E                   // screen mem starting page pointer
    jsr VDCWRITE                // kernal to write to VDC
    ldx #13                     // register of screen addr low byte
    lda #<VDCRAM                // load VDC low byte
    jsr VDCWRITE                // kernal to write to VDC
    // set vdc attribute ram back to main program
    ldx #20                     // register of screen addr high byte 
    lda #>ATTRRAM               // load VDC high byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #21                     // register of screen addr high byte 
    lda #<ATTRRAM               // load VDC high byte
    jsr VDCWRITE                // kernal to write to VDC
    
    rts

show_status:
    php                         // state of the processor status flags to stack
    pla                         // store in accu
    sta sreg_values             // save to var
    // N-Flag
    and #%10000000              // get value of the N flag
    beq !write_zero+            // if zero -> write zero
    lda #$31                    // load '1'
    PrintRegACharAt(52,24)      // macro: display acc content at x,y
    lda #%01001100              // load attributes: alt rev underln blink col col col col
    WrtRegAAttrAt(52,24)        // macro: change char attributes at x,y
    jmp z_flag                  // -> Z flag
!write_zero:                    
    lda #$30                    // load '0'
    PrintRegACharAt(52,24)      // macro: display acc content at x,y
    lda #%00001100              // load attributes: alt rev underln blink col col col col
    WrtRegAAttrAt(52,24)        // macro: change char attributes at x,y
z_flag:
    lda sreg_values             // load state var
    and #%00000010              // get value of the Z flag
    beq !write_zero+            // if zero -> write zero
    lda #$31                    // load '1'
    PrintRegACharAt(53,24)      // macro: display acc content at x,y
    lda #%01001100
    WrtRegAAttrAt(53,24)        // macro: change char attributes at x,y
    jmp c_flag                  // -> C flag
!write_zero:
    lda #$30                    // load '0'
    PrintRegACharAt(53,24)      // macro: display acc content at x,y
    lda #%00001100              // load attributes: alt rev underln blink col col col col
    WrtRegAAttrAt(53,24)        // macro: change char attributes at x,y
c_flag:
    lda sreg_values             // load state var
    and #%00000001              // get value of the C flag
    beq !write_zero+            // if zero -> write zero
    lda #$31                    // load '1'
    PrintRegACharAt(54,24)      // macro: display acc content at x,y
    lda #%01001100              // load attributes: alt rev underln blink col col col col
    WrtRegAAttrAt(54,24)        // macro: change char attributes at x,y
    rts                         
!write_zero:
    lda #$30
    PrintRegACharAt(54,24)      // load '0'
    lda #%00001100              // load attributes: alt rev underln blink col col col col
    WrtRegAAttrAt(54,24)        // macro: change char attributes at x,y
    rts                         // macro: display acc content at x,y

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
    lda #>(21*80 + 69)          // screen pos y*80 + x as 16 Bit address high byte 
    sta screen_hb               // store in var
    lda #<(21*80 + 69)          // screen pos y*80 + x as 16 Bit address low byte 
    sta screen_lb               // stor in var
    lda #3                      // list index of number start in ar_xxx
    sta arr_ptr_s               // store in var
    lda #6                      // list index of number end in ar_xxx
    sta arr_ptr_e               // store in var
    jmp print_xxx               // -> print '128'
!write_zero:                    
    lda #>(21*80 + 69)          // screen pos y*80 + x as 16 Bit address high byte 
    sta screen_hb               // store in var
    lda #<(21*80 + 69)          // screen pos y*8 + x as 16 Bit address low byte 
    sta screen_lb               // stor in var
    lda #0                      // list index of of number start in ar_xxx
    sta arr_ptr_s               // store in var
    lda #3                      // list index of of number end in ar_xxx
    sta arr_ptr_e               // store in var
    jmp print_xxx               // -> print '  0'
bit6:
    cpx #$06                    // is bit == bit 6 ?      
    bne bit5                    // branch to -> bit 5    
    PrintRegACharAt(7,8)        // macro: display acc content at x,y
    PrintRegACharAt(65,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,20)      // macro: display acc content at x,y
    cmp #$30                    // is char zero?
    beq !write_zero+            // -> write_zero
    lda #>(20*80 + 70)          // screen pos y*80 + x as 16 Bit address high byte 
    sta screen_hb               // store in var
    lda #<(20*80 + 70)          // screen pos y*80 + x as 16 Bit address low byte 
    sta screen_lb               // stor in var
    lda #10                     // list index of number start in ar_xxx
    sta arr_ptr_s               // store in var
    lda #12                     // list index of number end in ar_xxx
    sta arr_ptr_e               // store in var
    jmp print_xxx               // -> print ' 16'
!write_zero:                    
    lda #>(20*80 + 70)          // screen pos y*80 + x as 16 Bit address high byte 
    sta screen_hb               // store in var
    lda #<(20*80 + 70)          // screen pos y*8 + x as 16 Bit address low byte 
    sta screen_lb               // stor in var
    lda #7                      // list index of of number start in ar_xxx
    sta arr_ptr_s               // store in var
    lda #10                     // list index of of number end in ar_xxx
    sta arr_ptr_e               // store in var
    jmp print_xxx               // -> print '0'
bit5:
    cpx #$05                    // is bit == bit 5 ? 
    bne bit4                    // branch to -> bit 4
    PrintRegACharAt(13,8)       // macro: display acc content at x,y
    PrintRegACharAt(66,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,19)      // macro: display acc content at x,y
    cmp #$30                    // is char zero?
    beq !write_zero+            // -> write_zero
    lda #>(19*80 + 70)          // screen pos y*80 + x as 16 Bit address high byte 
    sta screen_hb               // store in var
    lda #<(19*80 + 70)          // screen pos y*80 + x as 16 Bit address low byte 
    sta screen_lb               // stor in var
    lda #16                     // list index of number start in ar_xxx
    sta arr_ptr_s               // store in var
    lda #18                     // list index of number end in ar_xxx
    sta arr_ptr_e               // store in var
    jmp print_xxx               // -> print ' 32'
!write_zero:                    
    lda #>(19*80 + 70)          // screen pos y*80 + x as 16 Bit address high byte 
    sta screen_hb               // store in var
    lda #<(19*80 + 70)          // screen pos y*8 + x as 16 Bit address low byte 
    sta screen_lb               // stor in var
    lda #13                     // list index of of number start in ar_xxx
    sta arr_ptr_s               // store in var
    lda #16                     // list index of of number end in ar_xxx
    sta arr_ptr_e               // store in var
    jmp print_xxx               // -> print '  0'
bit4:
    cpx #$04                    // is bit == bit 4 ?       
    bne bit3                    // branch to -> bit 3
    PrintRegACharAt(19,8)       // macro: display acc content at x,y
    PrintRegACharAt(67,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,18)      // macro: display acc content at x,y
    cmp #$30                    // is char zero?
    beq !write_zero+            // -> write_zero
    lda #>(18*80 + 70)          // screen pos y*80 + x as 16 Bit address high byte 
    sta screen_hb               // store in var
    lda #<(18*80 + 70)          // screen pos y*80 + x as 16 Bit address low byte 
    sta screen_lb               // stor in var
    lda #22                     // list index of number start in ar_xxx
    sta arr_ptr_s               // store in var
    lda #24                     // list index of number end in ar_xxx
    sta arr_ptr_e               // store in var
    jmp print_xxx               // -> print ' 16'
!write_zero:                    
    lda #>(18*80 + 70)          // screen pos y*80 + x as 16 Bit address high byte 
    sta screen_hb               // store in var
    lda #<(18*80 + 70)          // screen pos y*8 + x as 16 Bit address low byte 
    sta screen_lb               // stor in var
    lda #19                     // list index of of number start in ar_xxx
    sta arr_ptr_s               // store in var
    lda #22                     // list index of of number end in ar_xxx
    sta arr_ptr_e               // store in var
    jmp print_xxx               // -> print '  0'
bit3:
    cpx #$03                    // is bit == bit 3 ? 
    bne bit2                    // branch to -> bit 2
    PrintRegACharAt(28,8)       // macro: display acc content at x,y
    PrintRegACharAt(68,8)       // macro: display acc content at x,y
    PrintRegACharAt(59,17)      // macro: display acc content at x,y
    cmp #$30                    // is char zero?
    beq !write_zero+            // -> write_zero
    lda #$38                    // load '8'
    PrintRegACharAt(71,17)      // print '8'
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
    lda #$34                    // load '4'
    PrintRegACharAt(71,16)      // print '4'
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
    lda #$32                    // load '2'
    PrintRegACharAt(71,15)      // print '2'
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

print_xxx:
    // print numbers like '128','  0' or ' 16', '  0'.... 
    ldy arr_ptr_s               // set y to start index off ar_xxx
    ldx #18                     // register of screen addr high byte 
    lda screen_hb               // load high byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #19                     // register of screen addr low byte 
    lda screen_lb               // load low byte
    jsr VDCWRITE                // kernal to write to VDC   
!char_loop:
    lda ar_xxx,y                // load number from ar_xxx at index
    ldx #31                     // data register of VDC
    jsr VDCWRITE                // kernal to write to VDC
    iny                         // increment y
    cpy arr_ptr_e               // compare y with number end index in ar_xxx
    bne !char_loop-             // already at the end? 
    jmp next                    // if yes -> next
ar_xxx: .text "  0128"          // ar_xxx, table of numbers
        .text "  0 64"
        .text "  0 32"
        .text "  0 16"
   
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

// print char at x,y
.macro PrintRegACharAt(x,y) {
    pha                         // push acc
    .var screen_addr = y*80 + x // calc screen pos as 16 bit address
    ldx #18                     // register of screen addr high byte 
    lda #>screen_addr           // load high byte
    jsr VDCWRITE                // kernal to write to VDC
    ldx #19                     // register of screen addr low byte 
    lda #<screen_addr           // load low byte
    jsr VDCWRITE                // kernal to write to VDC
    pla                         // pull acc
    ldx #31                     // data register of VDC
    jsr VDCWRITE                // kernal to write to VDC
}

// change char attribute at x,y 
.macro WrtRegAAttrAt(x,y) {
    pha                                 // push acc
    .var attr_addr = y*80 + x + $800    // screen pos as 16 bit address + attr ram start 
    ldx #18                             // register of screen addr high byte 
    lda #>attr_addr                     // load high byte
    jsr VDCWRITE                        // kernal to write to VDC
    ldx #19                             // register of screen addr low byte 
    lda #<attr_addr                     // load low byte
    jsr VDCWRITE                        // kernal to write to VDC
    pla                                 // pull acc
    ldx #31                             // data register of VDC
    jsr VDCWRITE                        // kernal to write to VDC
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
*=CHR_DATA "Screen character data"
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
    .byte $1B,$03,$12,$20,$15,$10,$1D,$20,$20,$20,$2B,$31,$20,$20,$1B,$3C,$1D,$20,$01,$13,$0C,$20,$20,$12,$0F,$0C,$20,$1B,$0E,$1D,$20,$03,$30,$20,$1B,$16,$1D,$20,$03,$31,$20,$20,$1B,$11,$1D,$20,$11,$15,$09,$14,$20,$20,$0E,$1A,$03,$20,$06,$0C,$01,$07,$20,$20,$20,$20,$20,$20,$20,$20,$20,$32,$35,$35,$20,$20,$20,$20,$20,$04,$05,$03
    .byte $1B,$03,$12,$20,$04,$0F,$17,$0E,$1D,$20,$2D,$31,$20,$20,$1B,$3E,$1D,$20,$0C,$13,$12,$20,$20,$12,$0F,$12,$20,$1B,$0D,$1D,$20,$03,$30,$20,$1B,$02,$1D,$20,$03,$31,$20,$20,$1B,$08,$1D,$20,$08,$05,$0C,$10,$20,$20,$30,$30,$30,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

// screen color data
// https://petscii.krissz.hu
*=COL_DATA "Screen color data"
    .byte $05,$05,$05,$01,$0D,$0D,$0D,$0E,$07,$07,$07,$01,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$00,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0E,$01,$01,$01,$01,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0F,$0F,$0F,$0F,$01,$0F,$0F,$0F,$01,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0C,$0C,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$05,$05,$05,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$05,$05,$05,$05,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$05,$05,$05,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$05,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$05,$05,$0E,$0E,$0E,$0E,$0E,$05,$05,$05
    .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$05,$05,$05,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$05,$05,$05,$05,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$05,$05,$05,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
    .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$05,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$05,$01,$0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$01,$0E,$0E,$0E
    .byte $01,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0E,$0E,$0E,$01,$01,$01,$01,$0E,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$01,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$01,$01,$01,$0E,$0E,$01,$01,$01,$01,$01,$01,$01,$0E,$0E,$01,$01,$01,$01,$01,$0E,$0E
    .byte $0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$01,$01,$01,$0E,$0E,$0E
    .byte $0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$01,$01,$0E,$0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$01,$01,$01,$0E,$01,$01,$0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$01,$01,$0E,$0D,$0D,$0D,$0E,$01,$01,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$09,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0D,$0E,$0E,$0E,$0E,$0E,$0D,$0D,$0D
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
    .byte $0E,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$09,$09,$09,$09,$09,$09,$09,$09,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0E,$0E,$0E,$0E,$0E,$0E,$0E,$0E
    .byte $09,$09,$09,$09,$09,$09,$09,$01,$0C,$0C,$09,$09,$01,$09,$09,$09,$09,$0E,$09,$09,$09,$09,$0C,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$0C,$09,$09,$09,$0E,$09,$09,$09,$09,$09,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$09,$0E,$0E,$0E,$01,$0E,$01,$01,$01,$07,$07,$07,$0E,$0E,$0E,$0E,$0E,$07,$07,$07
    .byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$01,$09,$09,$0C,$09,$09,$09,$09,$0E,$09,$09,$09,$09,$0C,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$0C,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$0C,$0C,$0C,$0C,$0C,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01

*=CHR_DAT2 "Help screen character data"
    .byte $08,$05,$0C,$10,$20,$20,$20,$20,$20,$EF,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$10,$12,$05,$13,$13,$20,$01,$0E,$19,$20,$0B,$05,$19,$20,$14,$0F,$20,$05,$18,$09,$14,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$EF,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $1B,$03,$12,$20,$15,$10,$1D,$20,$20,$20,$2B,$31,$20,$09,$0E,$03,$28,$12,$05,$0D,$05,$0E,$14,$29,$20,$16,$01,$0C,$15,$05,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$10,$12,$0F,$03,$05,$13,$13,$0F,$12,$20,$13,$14,$01,$14,$15,$13,$20,$12,$05,$07,$09,$13,$14,$05,$12
    .byte $1B,$03,$12,$20,$04,$0F,$17,$0E,$1D,$20,$2D,$31,$20,$04,$05,$03,$28,$12,$05,$0D,$05,$0E,$14,$29,$20,$16,$01,$0C,$15,$05,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$0E,$20,$20,$0E,$05,$07,$01,$14,$09,$16,$05,$20,$06,$0C,$01,$07,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $1B,$3C,$1D,$20,$01,$13,$0C,$20,$20,$20,$20,$20,$20,$01,$12,$09,$14,$08,$0D,$05,$14,$09,$03,$20,$13,$08,$09,$06,$14,$20,$0C,$05,$06,$14,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $1B,$3E,$1D,$20,$0C,$13,$12,$20,$20,$20,$20,$20,$20,$0C,$0F,$07,$09,$03,$20,$13,$08,$09,$06,$14,$20,$12,$09,$07,$08,$14,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$1A,$20,$20,$1A,$05,$12,$0F,$20,$06,$0C,$01,$07,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$03,$20,$20,$03,$01,$12,$12,$19,$20,$06,$0C,$01,$07,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $12,$0F,$0C,$20,$1B,$0E,$1D,$20,$03,$30,$20,$20,$20,$12,$0F,$14,$01,$14,$05,$20,$0C,$05,$06,$14,$20,$20,$20,$03,$01,$12,$12,$19,$20,$06,$0C,$01,$07,$20,$30,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $12,$0F,$12,$20,$1B,$0D,$1D,$20,$03,$30,$20,$20,$20,$12,$0F,$14,$01,$14,$05,$20,$12,$09,$07,$08,$14,$20,$20,$03,$01,$12,$12,$19,$20,$06,$0C,$01,$07,$20,$30,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $12,$0F,$0C,$20,$1B,$16,$1D,$20,$03,$31,$20,$20,$20,$12,$0F,$14,$01,$14,$05,$20,$0C,$05,$06,$14,$20,$20,$20,$03,$01,$12,$12,$19,$20,$06,$0C,$01,$07,$20,$31,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $12,$0F,$12,$20,$1B,$02,$1D,$20,$03,$31,$20,$20,$20,$12,$0F,$14,$01,$14,$05,$20,$12,$09,$07,$08,$14,$20,$20,$03,$01,$12,$12,$19,$20,$06,$0C,$01,$07,$20,$31,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $1B,$11,$1D,$20,$11,$15,$09,$14,$20,$20,$20,$20,$20,$05,$18,$09,$14,$20,$10,$12,$0F,$07,$12,$01,$0D,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $1B,$08,$1D,$20,$08,$05,$0C,$10,$20,$20,$20,$20,$20,$13,$08,$0F,$17,$20,$14,$08,$09,$13,$20,$08,$05,$0C,$10,$20,$13,$03,$12,$05,$05,$0E,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20
    .byte $20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20

*=COL_DAT2 "Help screen color data"
    .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$00,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0C,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$00,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$01,$01,$01,$01,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0E,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $09,$09,$09,$09,$09,$09,$09,$01,$0C,$0C,$09,$09,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$01,$09,$09,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0E,$0E,$0E
    .byte $09,$09,$09,$0E,$09,$09,$09,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0C,$0F,$0F,$0F,$0F,$01,$01,$01,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0E,$0E
    .byte $09,$09,$09,$0E,$09,$09,$09,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0E,$0E,$0E
    .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0E,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$09,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $09,$09,$09,$09,$09,$09,$09,$09,$09,$09,$0C,$09,$09,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0F,$0F,$0F,$0F,$01,$01,$01,$01,$01,$01,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $09,$09,$09,$0F,$09,$09,$09,$09,$09,$09,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $09,$09,$09,$0F,$09,$09,$09,$09,$09,$09,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $09,$09,$09,$0E,$09,$09,$09,$09,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0C,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $09,$09,$09,$01,$09,$09,$09,$09,$09,$0F,$0F,$09,$09,$0F,$0F,$0F,$0F,$09,$0F,$0F,$0F,$0F,$09,$0F,$0F,$0F,$0F,$09,$0F,$0F,$0F,$0F,$0F,$0F,$01,$01,$01,$01,$01,$01,$01,$09,$09,$09,$09,$09,$09,$09,$09,$0F,$0F,$0C,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0C,$0C,$0C,$09,$0C,$0C,$0C,$0C,$0F,$0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0E,$0F,$0E,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$01,$01,$01,$01,$01,$01,$09,$09,$09,$09,$09,$09,$09,$09,$0F,$0F,$0C,$0C,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0C,$0F,$0F,$0F,$0F,$0F,$0C,$0C,$0F,$0F,$0F,$0F,$0F,$0C,$0F,$0C,$0C,$0C,$0F,$0C,$0C,$0C,$0C,$0C,$0C,$0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0E,$0F,$0E,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
    .byte $0C,$0C,$0C,$0C,$0F,$0C,$0C,$0C,$0F,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$09,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$09,$09,$09,$09,$09,$09,$09,$0C,$09,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$0C,$09,$09,$09,$09,$09,$09,$09,$09,$09,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F,$0F
