// 8 Bit HEX BIN DEC Visualizer for Commodore C64
// use CRSR UP and CRSR DOWN to change values (+1 / -1)
// Q to quit
// compiles with Kick Assembler (cross assembler)
// https://theweb.dk/KickAssembler/Main.html#frontpage

BasicUpstart2(start)            // Kick Assembler magic

// addresses
.const SCREEN     = $0400       // screen RAM
.const GETIN      = $ffe4       // GETIN kernal
.const CLS        = $e544       // CLEAR SCREEN kernal 
.const param      = $0334       // to store temp values
.const param_num  = $0335       // to store temp values

// colors
.const BLACK      = 0
.const BLUE       = 6
.const LIGHT_BLUE = 14

// keys
.const C_UP       = $91         // cursor down key
.const C_DOWN     = $11         // cursor up key
.const Q          = $51         // Q key

// variables
current_value: .byte $80        // start value is 128; change?:
                                // petscii display has to be changed as well

// prepare start screen
start:   
    SetBorderColor(BLACK)       // change border color
    SetBGColor(BLACK)           // chang bg color   
    
    // adapted from https://petscii.krissz.hu
    // src 1 = char data
    // src 2 = color data
    // dst 1 = screen pos
    // dst 2 = color ram
    lda #$00                    // $00 to acc
    sta $fb                     // src 1 lb = $00
    sta $fd                     // dst 1 lb = $00
    sta $f7                     // dst 2 lb = $00
                    
    lda #$28                    // $28 to acc
    sta $fc                     // src 1 hb = $28 $00  -> $2800
                    
    lda #$04                    // $04 to acc
    sta $fe                     // dest 1 hb = $04 $00 -> $0400
                    
    lda #$e8                    // $e8 to acc
    sta $f9                     // src 2 lb = $e8
    lda #$2b                     
    sta $fa                     // src 2 hb = $2b -> $2be8
                    
    lda #$d8                    // $d8 to acc
    sta $f8                     // dst 2 hb = $d8 $00 -> $d8000 -> color ram 
                    
    ldx #$00                    // loop counter (0-3 256 Bytes)
    ldy #$00                    // loop counter (0-255)
    
loop:
    lda ($fb),y                 // load b from src 1
    sta ($fd),y                 // write to dst 1
    lda ($f9),y                 // load b from src 2
    sta ($f7),y                 // write b to dst 2
    iny                         // +1 y
    bne loop                    // inner y register loop, repeat until y is 0 again (overflow 255 -> 0) 

    inc $fc                     // src 1 +1 (hb++)
    inc $fe                     // dst 1 +1 (hb++)
    inc $fa                     // src 2 +1 (hb++)
    inc $f8                     // dst 2 +1 (hb++)

    inx                         // +1 x
    cpx #$04                    // 4 x 256 = 1024
    bne loop                    // outer x register loop
    
main_loop:
    jsr handle_input            // -> check keys
    cmp #Q                      // if acc is 'Q' -> exit 
    bne main_loop               // else loop
    jsr exit                    // -> exit

exit:
    jsr CLS                     // clear screen
    SetBorderColor(LIGHT_BLUE)  // set default border color
    SetBGColor(BLUE)            // set default bg color
    SetFontColor(LIGHT_BLUE)    // set default font color
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
    pha                         // push acc to stack
    lsr                         // shift one bit right
    lsr                         // 4 times
    lsr
    lsr
    tax                         // transfer to x, index for upper 4 bits
    lda hex_digits,x            // load char for upper 4 bits from hex_digits
    sta SCREEN+139              // display char at center
    sta SCREEN+129              // display char at left pos

    pla                         // get acc from stack
    and #$0f                    // mask lower 4 bits
    tax                         // transfer to x, index for lower 4 bits
    lda hex_digits,x            // load char for lower 4 bits from hex_digits
    sta SCREEN+140              // display char at center
    sta SCREEN+150              // display char at right pos
    rts                         // -> output

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
    cpx #$00                    // is bit == bit 0 ? 
    beq bit0                    // branch to bit 0 handler
    cpx #$01                    // is bit == bit 1 ?      
    beq bit1                    // branch to bit 1 handler    
    cpx #$02                    // is bit == bit 2 ? 
    beq bit2                    // branch to bit 3 handler
    cpx #$03                    // is bit == bit 3 ?       
    beq bit3                    // branch to bit 3 handler 
    cpx #$04                    // is bit == bit 4 ? 
    beq bit4                    // branch to bit 4 handler
    cpx #$05                    // is bit == bit 5 ?      
    beq bit5                    // branch to bit 5 handler
    cpx #$06                    // is bit == bit 6 ? 
    beq bit6                    // branch to bit 6 handler
    cpx #$07                    // is bit == bit 7 ?      
    beq bit7                    // branch to bit 7 handler
    rts                         // unreachable, but safety fallback

bit7: 
    sta SCREEN+362              // display 0 or 1 at bit 7 position
    jsr bit_mul7                // -> to multiplication display
    jmp next                    // jmp to -> next (next bit) 
bit6: 
    sta SCREEN+367              // display 0 or 1 at bit 6 position
    jsr bit_mul6                // -> to multiplication display
    jmp next                    // jmp to -> next (next bit) 
bit5: 
    sta SCREEN+372              // display 0 or 1 at bit 5 position
    jsr bit_mul5                // -> to multiplication display
    jmp next                    // jmp to -> next (next bit) 
bit4: 
    sta SCREEN+377              // display 0 or 1 at bit 4 position 
    jsr bit_mul4                // -> to multiplication display
    jmp next                    // jmp to -> next (next bit) 
bit3:
    sta SCREEN+382              // display 0 or 1 at bit 3 position
    jsr bit_mul3                // -> to multiplication display
    jmp next                    // jmp to -> next (next bit) 
bit2: 
    sta SCREEN+387              // display 0 or 1 at bit 2 position
    jsr bit_mul2                // -> to multiplication display
    jmp next                    // jmp to -> next (next bit) 
bit1: 
    sta SCREEN+392              // display 0 or 1 at bit 1 position
    jsr bit_mul1                // -> to multiplication display
    jmp next                    // jmp to -> next (next bit) 
bit0:
    sta SCREEN+397              // display 0 or 1 at bit 0 position
    jsr bit_mul0                // -> to multiplication display
    jmp next                    // jmp to -> next (next bit) 
   
next:
    pla                         // get acc from stack, restore previous bit index
    tax                         // transfer to x
    dex                         // decrement x to the next lower bit
    bpl bin_loop                // if x > 0 --> bin loop
    rts                         // all bits processed, return

bit_mul0:
    cmp #$30                    // is char '0' ?
    beq bit_mul00               // branch to -> bit_mul00 (display '0' at bit 0 mul pos)
    lda #$31                    // else load char '1'
    sta SCREEN+757              // display '1' at bit 0 mul pos
    rts                         // return
bit_mul00:                     
    sta SCREEN+757              // display '0' at bit 0 mul pos
    rts                         // return

bit_mul1:
    cmp #$30                    // is char '0' ?
    beq bit_mul10               // branch to -> bit_mul10 (display '0' at bit 1 mul pos)
    lda #$32                    // else load char '2'
    sta SCREEN+752              // display '1' at bit 1 mul pos
    rts                         // return
bit_mul10:                      
    sta SCREEN+752              // display '0' at bit 0 mul pos
    rts                         // return

bit_mul2:
    cmp #$30                    // is char '0' ?
    beq bit_mul20               // branch to -> bit_mul20 (display '0' at bit 2 mul pos)
    lda #$34                    // else load char '4'
    sta SCREEN+747              // display '4' at bit 2 mul pos
    rts                         // return
bit_mul20:                      
    sta SCREEN+747              // display '0' at bit 2 mul pos
    rts                         // return

bit_mul3:                       
    cmp #$30                    // is char '0' ?
    beq bit_mul30               // branch to -> bit_mul30 (display '0' at bit 3 mul pos)
    lda #$38                    // else load char '8'
    sta SCREEN+742              // display '8' at bit 3 mul pos
    rts                         // return
bit_mul30:                      
    sta SCREEN+742              // display '0' at bit 3 mul pos
    rts                         // return

bit_mul4:                       
    cmp #$30                    // is char '0' ?
    beq bit_mul40               // branch to -> bit_mul40 (display '0' at bit 4 mul pos)
    lda #$36                    // else load char '6'
    sta SCREEN+738              // display '6' at bit 4 mul pos
    lda #$31                    // load char '1'
    sta SCREEN+737              // display '1' at bit 4 mul pos
    rts                         // return
bit_mul40:
    sta SCREEN+738              // display '0' at bit 4 mul pos
    lda #$30                    // load char '0'
    sta SCREEN+737              // display '0' at bit 4 mul pos
    rts                         // return

bit_mul5:                       
    cmp #$30                    // is char '0' ?
    beq bit_mul50               // branch to -> bit_mul50 (display '0' at bit 5 mul pos)
    lda #$32                    // else load char '2'
    sta SCREEN+733              // display '2' at bit 5 mul pos
    lda #$33                    // load char '3'
    sta SCREEN+732              // display '3' at bit 5 mul pos
    rts                         // return
bit_mul50:                      
    sta SCREEN+733              // display '0' at bit 5 mul pos
    lda #$30                    // load char '0'
    sta SCREEN+732              // display '0' at bit 5 mul pos
    rts                         // return

bit_mul6:                       
    cmp #$30                    // is char '0' ?
    beq bit_mul60               // branch to -> bit_mul60 (display '0' at bit 6 mul pos)
    lda #$34                    // else load char '4'
    sta SCREEN+728              // display '4' at bit 6 mul pos
    lda #$36                    // load char '6'
    sta SCREEN+727              // display '6' at bit 6 mul pos
    rts                         // return
bit_mul60:                      
    sta SCREEN+728              // display '0' at bit 6 mul pos
    lda #$30                    // load char '0'
    sta SCREEN+727              // display '0' at bit 6 mul pos
    rts                         // return

bit_mul7:                       
    cmp #$30                    // is char '0' ?
    beq bit_mul70               // branch to -> bit_mul70 (display '0' at bit 7 mul pos)
    lda #$38                    // else load char '8'
    sta SCREEN+723              // display '8' at bit 7 mul pos
    lda #$32                    // load char '2'
    sta SCREEN+722              // display '2' at bit 7 mul pos
    lda #$31                    // load char '1'
    sta SCREEN+721              // display '1' at bit 7 mul pos
    rts                         // return
bit_mul70:                      
    sta SCREEN+723              // display '0' at bit 7 mul pos
    lda #$30                    // load char '0'
    sta SCREEN+722              // display '0' at bit 7 mul pos
    lda #$30                    // load char '0'
    sta SCREEN+721              // display '0' at bit 7 mul pos
    rts                         // return
    
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
    sta SCREEN+939              // display hundreds 

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
    sta SCREEN+940              // display tens

    // 1 digit
    lda param                   // load remaining value (0 to 9) 
    ora #$30                    // convert to num chars ('0' to '9')
    sta SCREEN+941              // display ones
    rts                         // return

// screen character data
// https://petscii.krissz.hu
*=$2800 "Screen character data"
    .byte    $20, $08, $05, $18, $20, $02, $09, $0E, $20, $04, $05, $03, $20, $16, $09, $13, $15, $01, $0C, $09, $1A, $05, $12, $20, $20, $03, $36, $34, $20, $16, $05, $12, $13, $09, $0F, $0E, $20, $32, $35, $20 // HEX BIN  0
    .byte    $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20 // empty    1
    .byte    $20, $20, $20, $20, $20, $20, $20, $20, $4F, $77, $50, $20, $20, $20, $20, $20, $20, $20, $4F, $77, $77, $50, $20, $20, $20, $20, $20, $20, $20, $4F, $77, $50, $20, $20, $20, $20, $20, $20, $20, $20 // ---      2
    .byte    $20, $20, $20, $20, $20, $20, $20, $20, $74, $38, $6A, $43, $43, $43, $43, $40, $40, $40, $74, $38, $30, $6A, $40, $40, $40, $43, $43, $43, $43, $74, $38, $6A, $20, $20, $20, $20, $20, $20, $20, $20 // HEX      3
    .byte    $20, $20, $20, $20, $20, $20, $20, $20, $4C, $6F, $7A, $20, $20, $20, $20, $20, $20, $20, $4C, $6F, $6F, $7A, $20, $20, $20, $20, $20, $20, $20, $4C, $6F, $7A, $20, $20, $20, $20, $20, $20, $20, $20 // ---      4
    .byte    $20, $20, $20, $20, $20, $20, $20, $20, $20, $42, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $43, $43, $43, $43, $43, $43, $43, $43, $42, $43, $43, $43, $43, $43, $43, $43, $20, $20 // |        5
    .byte    $20, $20, $70, $40, $40, $40, $40, $72, $40, $71, $43, $43, $72, $40, $40, $40, $40, $6E, $20, $20, $20, $20, $70, $40, $40, $40, $40, $72, $40, $40, $71, $40, $72, $40, $40, $40, $40, $6E, $20, $20 // ---      6
    .byte    $20, $20, $42, $20, $20, $20, $20, $42, $20, $20, $20, $20, $42, $20, $20, $20, $20, $42, $20, $20, $20, $20, $42, $20, $20, $20, $20, $42, $20, $20, $20, $20, $42, $20, $20, $20, $20, $42, $20, $20 // |        7
    .byte    $20, $4F, $77, $50, $20, $20, $4F, $77, $50, $20, $20, $4F, $77, $50, $20, $20, $4F, $77, $50, $20, $20, $4F, $77, $50, $20, $20, $4F, $77, $50, $20, $20, $4F, $77, $50, $20, $20, $4F, $77, $50, $20 // ---      8
    .byte    $20, $74, $31, $6A, $20, $20, $74, $30, $6A, $20, $20, $74, $30, $6A, $20, $20, $74, $30, $6A, $20, $20, $74, $30, $6A, $20, $20, $74, $30, $6A, $20, $20, $74, $30, $6A, $20, $20, $74, $30, $6A, $20 // BIN      9
    .byte    $20, $4C, $6F, $7A, $20, $20, $4C, $6F, $7A, $20, $20, $4C, $6F, $7A, $20, $20, $4C, $6F, $7A, $20, $20, $4C, $6F, $7A, $20, $20, $4C, $6F, $7A, $20, $20, $4C, $6F, $7A, $20, $20, $4C, $6F, $7A, $20 // ---      A
    .byte    $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20 // empty    B
    .byte    $20, $20, $56, $20, $20, $20, $20, $56, $20, $20, $20, $20, $56, $20, $20, $20, $20, $56, $20, $20, $20, $20, $56, $20, $20, $20, $20, $56, $20, $20, $20, $20, $56, $20, $20, $20, $20, $56, $20, $20 // x x x    C
    .byte    $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20 // empty    D
    .byte    $20, $31, $32, $38, $20, $20, $20, $36, $34, $20, $20, $20, $33, $32, $20, $20, $20, $31, $36, $20, $20, $20, $38, $20, $20, $20, $20, $34, $20, $20, $20, $20, $32, $20, $20, $20, $20, $31, $20, $20 // 128 64   E 
    .byte    $20, $20, $5D, $20, $20, $20, $20, $20, $74, $20, $20, $20, $20, $74, $20, $20, $20, $20, $74, $20, $20, $20, $5D, $20, $20, $20, $20, $5D, $20, $20, $20, $20, $5D, $20, $20, $20, $20, $5D, $20, $20 // |        F
    .byte    $20, $20, $42, $20, $20, $20, $20, $20, $74, $20, $20, $20, $20, $74, $20, $20, $20, $20, $74, $20, $20, $20, $42, $20, $20, $20, $20, $42, $20, $20, $20, $20, $42, $20, $20, $20, $20, $42, $20, $20 // |      0
    .byte    $4F, $77, $77, $77, $50, $20, $4F, $77, $77, $50, $20, $4F, $77, $77, $50, $20, $4F, $77, $77, $50, $20, $4F, $77, $50, $20, $20, $4F, $77, $50, $20, $20, $4F, $77, $50, $20, $20, $4F, $77, $50, $20 // ---      1
    .byte    $74, $31, $32, $38, $6A, $2B, $74, $30, $30, $6A, $2B, $74, $30, $30, $6A, $2B, $74, $30, $30, $6A, $2B, $74, $30, $6A, $2B, $20, $74, $30, $6A, $2B, $20, $74, $30, $6A, $2B, $20, $74, $30, $6A, $20 // 128 64   2
    .byte    $4C, $6F, $6F, $6F, $7A, $20, $4C, $6F, $6F, $7A, $20, $4C, $6F, $6F, $7A, $20, $4C, $6F, $6F, $7A, $20, $4C, $6F, $7A, $20, $20, $4C, $6F, $7A, $20, $20, $4C, $6F, $7A, $20, $20, $4C, $6F, $7A, $20 // ---      3
    .byte    $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $42, $20, $20 //   |      4
    .byte    $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $42, $20, $20 // empty    5
    .byte    $20, $03, $12, $13, $12, $20, $20, $20, $15, $10, $20, $5B, $31, $20, $20, $20, $20, $20, $4F, $77, $77, $77, $50, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $42, $20, $20 // UP       6
    .byte    $20, $03, $12, $13, $12, $20, $04, $0F, $17, $0E, $20, $40, $31, $20, $20, $20, $20, $20, $74, $31, $32, $38, $6A, $1F, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $40, $7D, $20, $20 // DOWN     7
    .byte    $20, $20, $20, $20, $20, $20, $11, $15, $09, $14, $20, $20, $11, $20, $20, $20, $20, $20, $4C, $6F, $6F, $6F, $7A, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20, $20 // QUIT     8 24

// screen color data
// https://petscii.krissz.hu
*=$2be8 "Screen color data"
    .byte    $01, $05, $05, $05, $01, $07, $07, $07, $01, $03, $03, $03, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
    .byte    $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
    .byte    $01, $01, $01, $01, $01, $01, $01, $01, $05, $05, $05, $00, $00, $00, $01, $01, $01, $01, $05, $05, $05, $05, $01, $01, $01, $01, $00, $00, $00, $05, $05, $05, $01, $01, $01, $01, $01, $01, $01, $01
    .byte    $01, $01, $01, $01, $01, $01, $01, $01, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $05, $01, $01, $01, $01, $01, $01, $01, $01
    .byte    $01, $01, $01, $01, $01, $01, $01, $01, $05, $05, $05, $00, $00, $00, $01, $01, $01, $01, $05, $05, $05, $05, $01, $01, $01, $01, $00, $00, $00, $05, $05, $05, $01, $01, $01, $01, $01, $01, $01, $01
    .byte    $01, $01, $01, $01, $01, $01, $01, $01, $01, $05, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $00, $00, $00, $00, $00, $00, $00, $00, $05, $00, $00, $00, $00, $00, $00, $00, $01, $01
    .byte    $01, $01, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $01, $01, $01, $01, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $01, $01
    .byte    $01, $01, $07, $01, $01, $01, $01, $07, $01, $01, $01, $01, $07, $01, $01, $01, $01, $07, $01, $01, $01, $01, $07, $01, $01, $01, $01, $07, $01, $01, $01, $01, $07, $01, $01, $01, $01, $07, $01, $01
    .byte    $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01
    .byte    $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01
    .byte    $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01, $01, $07, $07, $07, $01
    .byte    $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
    .byte    $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01
    .byte    $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01
    .byte    $01, $0C, $0C, $0C, $01, $01, $01, $0C, $0C, $01, $01, $01, $0C, $0C, $01, $01, $01, $0C, $0C, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01
    .byte    $01, $01, $0C, $01, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01, $01, $01, $0C, $01, $01
    .byte    $01, $01, $04, $01, $01, $01, $01, $04, $04, $04, $01, $01, $01, $04, $01, $01, $01, $01, $04, $01, $01, $01, $04, $01, $01, $01, $01, $04, $01, $01, $01, $01, $04, $01, $01, $01, $01, $04, $01, $01
    .byte    $04, $04, $04, $04, $04, $01, $04, $04, $04, $04, $01, $04, $04, $04, $04, $01, $04, $04, $04, $04, $01, $04, $04, $04, $01, $01, $04, $04, $04, $01, $01, $04, $04, $04, $01, $01, $04, $04, $04, $01
    .byte    $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $04, $01
    .byte    $04, $04, $04, $04, $04, $01, $04, $04, $04, $04, $01, $04, $04, $04, $04, $01, $04, $04, $04, $04, $01, $04, $04, $04, $01, $01, $04, $04, $04, $01, $01, $04, $04, $04, $01, $01, $04, $04, $04, $01
    .byte    $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $03, $03, $01
    .byte    $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $03, $01, $01
    .byte    $01, $02, $02, $02, $02, $01, $01, $01, $02, $02, $01, $02, $02, $01, $01, $01, $01, $01, $03, $03, $03, $03, $03, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $03, $01, $01
    .byte    $01, $02, $02, $02, $02, $02, $02, $02, $02, $02, $01, $02, $02, $01, $01, $01, $01, $01, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03, $03, $01, $01
    .byte    $01, $02, $02, $02, $02, $01, $02, $02, $02, $02, $01, $01, $02, $01, $01, $01, $01, $01, $03, $03, $03, $03, $03, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01

// macro for border color    
.macro SetBorderColor(color) {
        lda #color
        sta $d020               // frame color address
}

// macro for BG color  
.macro SetBGColor(color) {
        lda #color
        sta $d021               // BG color address
}

// macro for font color  
.macro SetFontColor(color) {
        lda #color
        sta $0286               // font color address
}
