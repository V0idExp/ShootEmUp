BGCOLOR =  $0d          ; Overall background color index
BGR_PAL0 = $103020      ; Background 0 tiles palette indices
PLCOLOR =  $062636      ; Player palette color indices

PPUSTAT = $2002         ; PPU status register
PPUSCRL = $2005         ; PPU scroll register (x2 writes for X and Y)
PPUADDR = $2006         ; VRAM write address register
PPUDATA = $2007         ; VRAM write data register

VRAM_BGCOLOR = $3f00    ; Universal background color
VRAM_BGR_PAL0 = $3f01   ; Background palette 0
VRAM_BGR_PAL1 = $3f05   ; Background palette 1
VRAM_BGR_PAL2 = $3f09   ; Background palette 2
VRAM_BGR_PAL3 = $3f0d   ; Background palette 3
VRAM_SPR_PAL0 = $3f11   ; Sprite palette 0
VRAM_SPR_PAL1 = $3f15   ; Sprite palette 1
VRAM_SPR_PAL2 = $3f19   ; Sprite palette 2
VRAM_SPR_PAL3 = $3f1d   ; Sprite palette 3
VRAM_NAMETABLE0 = $2000 ; Nametable 0
VRAM_NAMETABLE1 = $2400 ; Nametable 1
VRAM_NAMETABLE2 = $2800 ; Nametable 2
VRAM_NAMETABLE3 = $2c00 ; Nametable 3
VRAM_ATTRTABLE0 = $23c0 ; Attribute table 0
VRAM_ATTRTABLE1 = $27c0 ; Attribute table 1
VRAM_ATTRTABLE2 = $2bc0 ; Attribute table 2
VRAM_ATTRTABLE3 = $2fc0 ; Attribute table 3

JOYPAD1 = $4016

;
; iNES header for the emulators.
;
.segment "INESHDR"
    .byt "NES",$1A  ; magic signature
    .byt 1          ; PRG ROM size in 16384 byte units
    .byt 1          ; CHR ROM size in 8192 byte units
    .byt $00        ; mirroring type and mapper number lower nibble
    .byt $00        ; mapper number upper nibble


;
; CHR-ROM, accessible by the PPU
;
.segment "CHR1"
.incbin "../build/ships.chr"

.segment "CHR2"
.incbin "../build/background.chr"

;
; PRG-ROM, read-only data
;
.rodata
    starfield: .incbin "../build/levels/starfield.lvl"


;
; Zero-page RAM.
;
.zeropage
    frame_counter:  .res 1  ; current frame, wraps at $ff
    player_pos_x:  .res 1    ; Player start X coord
    player_pos_y:  .res 1    ; Player start Y coord

    ; pointer for indexed indirect addressing
    ptr:
    ptrL:           .res 1  ; pointer low address (goes *before* high!)
    ptrH:           .res 1  ; pointer high address


;
; PPU Object Attribute Memory - shadow RAM which holds rendering attributes
; of up to 64 sprites.
;
.segment "OAM"
    oam: .res 256


;
; PRG-ROM, code.
;
.code
reset_handler:
    sei        ; ignore IRQs
    cld        ; disable decimal mode
    ldx #$40
    stx $4017  ; disable APU frame IRQ
    ldx #$ff
    txs        ; Set up stack
    inx        ; now X = 0 (FF overflows)
    stx $2000  ; disable NMI
    stx $2001  ; disable rendering
    stx $4010  ; disable DMC IRQs

    ; Optional (omitted):
    ; Set up mapper and jmp to further init code here.

    ; The vblank flag is in an unknown state after reset,
    ; so it is cleared here to make sure that vblankwait1
    ; does not exit immediately.

    ; NOTE: reading $2002 clears the 7th bit, so, testing it effectively clears
    ; it.
    bit $2002

    ; First of two waits for vertical blank to make sure that the
    ; PPU has stabilized
vblankwait1:
    bit $2002
    bpl vblankwait1

    ; We now have about 30,000 cycles to burn before the PPU stabilizes.
    ; One thing we can do with this time is put RAM in a known state.
    ; Here we fill it with $00, which matches what (say) a C compiler
    ; expects for BSS.  Conveniently, X is still 0.
    txa
clrmem:
    sta $000,x
    sta $100,x
    sta $200,x
    sta $300,x
    sta $400,x
    sta $500,x
    sta $600,x
    sta $700,x
    inx
    bne clrmem

    ; Other things you can do between vblank waits are set up audio
    ; or set up other mapper registers.

vblankwait2:
    bit $2002
    bpl vblankwait2


;
; Here we setup the PPU for drawing by writing apropriate memory-mapped
; registers and specific memory locations.
;
; IMPORTANT! Writes to the PPU RAM afterwards should occur only during VBlank!
;
ppusetup:
    ;
    ; Set universal background color
    ;
    ; set PPUADDR
    lda #>VRAM_BGCOLOR
    sta PPUADDR
    lda #<VRAM_BGCOLOR
    sta PPUADDR
    ; write the color index
    lda #BGCOLOR
    sta PPUDATA

    ;
    ; Set background-0 palette
    ;
    lda #>VRAM_BGR_PAL0
    sta PPUADDR
    lda #<VRAM_BGR_PAL0
    sta PPUADDR
    ; write the color indices
    lda #(BGR_PAL0 >> 16)
    sta PPUDATA
    lda #(BGR_PAL0 >> 8) & $ff
    sta PPUDATA
    lda #(BGR_PAL0 & $ff)
    sta PPUDATA

    ;
    ; Populate nametable-0 with data stored in PRG-ROM
    ;
    ; set the destination VRAM address
    lda #>VRAM_NAMETABLE0
    sta PPUADDR
    lda #<VRAM_NAMETABLE0
    sta PPUADDR

    ; setup the pointer to starfield memory region
    lda #>starfield
    sta ptrH
    lda #<starfield
    sta ptrL

    ; X counts the 256-byte chunks (960 / 256 = 3)
    ldx #$03
    ; Y counts the bytes in the current chunk
    ldy #$00

    ; setup initial player position
    lda #$00
    sta player_pos_x

    lda #$00
    sta player_pos_y

@cpbyte:
    lda (ptr),Y ; load the tile index from (ptrH,ptrL) + Y address
    sta PPUDATA ; write it to the nametable, this advances the PPUADDR by 1
    iny         ; go to the next byte
    bne @cpbyte ; loop over until Y does not overflow
    dex         ; decrement the number of chunks to copy
    bmi @end    ; all chunks copied, go to the end
    inc ptrH    ; increase the high address value
    jmp @cpbyte ; copy the next chunk
@end:

    ;
    ; Set sprite-0 palette
    ;
    ; set PPUADDR destination address to Sprite Palette 0 ($3F11)
    lda #>VRAM_SPR_PAL0
    sta PPUADDR
    lda #<VRAM_SPR_PAL0
    sta PPUADDR
    ; write each of the three palette colors.
    lda #(PLCOLOR >> 16)
    sta PPUDATA
    lda #(PLCOLOR >> 8) & $ff
    sta PPUDATA
    lda #(PLCOLOR) & $ff
    sta PPUDATA

    ;
    ; Clear PPU status and scroll registers
    ;
    bit PPUSTAT
    lda #$00
    sta PPUSCRL
    sta PPUSCRL

    ; Clear OAMDATA address
    lda #$00
    sta $2003

    ; Enable sprite drawing
    lda #$1e
    sta $2001

    ; Ready to go, enable VBlank NMI, all subsequent writes should take place
    ; during VBlank, inside NMI handler.
    lda #$90
	sta $2000

main:
    ;
    ; Display the message on screen using sprites representing ASCII symbols
    ;
    ldx #$00 ; character index
    ldy #$00 ; byte offset

draw_player:
    ;
    ; Player ship is made up of 4 sprites in a 2x2 box, as below following:
    ; +--+--+
    ; |00|01|
    ; +--+--+
    ; |10|11|
    ; +--+--+

    ;;; TODO: rework this into some kind of loop ;;;
    ;
    ; Sprite $00
    ;
    ; Y coord
    txa
    lda player_pos_y
    sta oam,Y
    iny
    ; sprite id
    lda #$01
    sta oam,Y
    iny
    ; sprite attrs
    lda #$00
    sta oam,Y
    iny
    ; X coord
    lda player_pos_x
    sta oam,Y
    iny

    ;
    ; sprite $01
    ;
    ; Y coord
    txa
    lda player_pos_y
    sta oam,Y
    iny
    ; sprite id
    lda #$02
    sta oam,Y
    iny
    ; sprite attrs
    lda #$00
    sta oam,Y
    iny
    ; X coord
    lda player_pos_x 
    adc #$08
    sta oam,Y
    iny

    ;
    ; sprite $10
    ;
    ; Y coord
    txa
    lda player_pos_y
    adc #$08
    sta oam,Y
    iny
    ; sprite id
    lda #$11
    sta oam,Y
    iny
    ; sprite attrs
    lda #$00
    sta oam,Y
    iny
    ; X coord
    lda player_pos_x
    sta oam,Y
    iny

	;
    ; sprite $11
    ;
    ; Y coord
    txa
    lda player_pos_y
    adc #$08
    sta oam,Y
    iny
    ; sprite id
    lda #$12
    sta oam,Y
    iny
    ; sprite attrs
    lda #$00
    sta oam,Y
    iny
    ; X coord
    lda player_pos_x
    adc #$08
    sta oam,Y
    iny


    jmp main

;
; Handle non-masked interrupts
;
nmi_handler:
    ; push registers to stack
    pha
    txa
    pha
    tya
    pha

    ; increment the frame counter
    inc frame_counter

    jsr handle_input

    ; Perform DMA copy of shadow OAM to PPU's OAM
    lda #>oam
    sta $4014

    ; restore the registers
    pla
    tay
    pla
    tax
    pla

    rti

;
; Handle IRQs
;
irq_handler:
    rti

;
; handle input
;
handle_input:
    lda #$01
    sta JOYPAD1
    lda #$00
    sta JOYPAD1

    ; we don't process those yet, need to be executed in correct order
    lda JOYPAD1       ; Player 1 - A
    lda JOYPAD1       ; Player 1 - B
    lda JOYPAD1       ; Player 1 - Select
    lda JOYPAD1       ; Player 1 - Start

    lda JOYPAD1       ; Player 1 - Up
    and #%00000001
    bne move_up
        
    lda JOYPAD1       ; Player 1 - Down
    and #%00000001
    bne move_down
        
    lda JOYPAD1       ; Player 1 - Left
    and #%00000001
    bne move_left

    lda JOYPAD1       ; Player 1 - Right
    and #%00000001
    bne move_right
    rts    

move_right:
    lda player_pos_x
    clc
    adc #$01
    sta player_pos_x
    rts

move_left:
    lda player_pos_x
    sec
    sbc #$01
    sta player_pos_x
    rts

move_up:
    lda player_pos_y
    sec  
    sbc #$01
    sta player_pos_y
    rts

move_down:
    lda player_pos_y      
    clc  
    adc #$01
    sta player_pos_y
    rts

;
; Interrupt handler vectors (pointers).
; Three 16 bit addresses to, respectively, the NMI, RESET and IRQ handlers.
;
.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler
