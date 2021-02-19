;
; Animation settings
;
.code
squady_idle_animation:
    .byte $04                   ; length frames
    .byte $20                   ; starting tile ID
    .byte $02                   ; attribute set
    .byte $01                   ; padding x, z -> 1 tiles wide and high

octi_idle_anim:
    .byte $04                   ; length frames
    .byte $04                   ; starting tile ID
    .byte $00                   ; attribute set
    .byte $02                   ; padding x, z -> 2 tiles wide and high


; TODO: add different settings for different states
squady:
    .addr squady_idle_animation          ; HI Ivan!         ;  idle animation
    ; .byte $00                  

spacetopus:
    .addr octi_idle_anim


; todo: add padding
small_squad_army:
    .addr squady                 ; type of enemy         PS: are you suffering already
    .byte $40, $10              ; x position, y position  PPS: now? :*
    .addr squady
    .byte $c0, $10
    .addr spacetopus
    .byte $58, $32
    .addr spacetopus
    .byte $a8, $32
    .addr squady
    .byte $40, $50
    .addr squady
    .byte $c0, $50                


.segment "RAM"
; 6 enemies, 5 bytes each
; TODO: add (health) state
current_enemy_set:  .res 30 ; 2 byte enemy address, 2 byte address, 1 byte anim state

tile_data: .res 4 ; posy, tile id, attribute id, posx

NUM_ENEMIES = 6

ANIMATION_SPEED = 8

OFFSET_PADDING = 1
OFFSET_TILE_ID = 2
OFFSET_ATTRIBUTE_SET = 3
;
; initialize enemy data
;
.code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; load animation config 
; X-stack arguments:
;   NUM ENEMIES         - num colors to read out from the palette (default 16)
;   ANIM_CONFIG_HI      - Palette PPU destination address high part
;   ANIM_CONFIG_LW      - Palette PPU destination address low part
;   ANIM_POOL_LO        - Palette address high part
;   ANIM_POOL_HI        - Palette adress address low part
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
init_enemy_animation:
    lda #$00
    sta temp_1

    ldy #$00        ; loading offset
    ldx #$00        ; storing offset
@load_enemy:
    ; cpy to ram

    ; get the address of the animation setting
    lda small_squad_army, Y            ; Get lobyte
	sta current_enemy_set, X
    inx
    iny
    lda small_squad_army, Y            ; Get lobyte
	sta current_enemy_set, X 
    inx
    iny 
    ; set initial frame
    lda #$00
    sta current_enemy_set, X 
    inx
    ; store initial position
    lda small_squad_army, Y            ; x-position
	sta current_enemy_set, X 
    inx
    iny 
    lda small_squad_army, Y            ; y-position
	sta current_enemy_set, X 
    inx
    iny 


    ; check if there are more enemies to load
    inc temp_1
    lda temp_1
    cmp #NUM_ENEMIES
    bmi @load_enemy
    rts

;tick_animations

; draw .. yay
draw_enemies:
    lda #NUM_ENEMIES
    sta temp_3  

    sty $00, x
    dex             ; OAM OFFSET TO VIRTUAL STACK 

    ldy #$00    ;global enemy offset to stack
    sty $00,X
    dex

draw_enemy_object:
    inx 
    ldy $00, X  ; global enemy offset from stack

    lda current_enemy_set, y            ; Get lo byte
	sta temp_address
    iny
    lda current_enemy_set, y            ; Get hi byte
	sta temp_address + 1
    iny

    lda current_enemy_set, y            ; animation frame
    iny

    txa
    pha


    ldx #$00
    lda current_enemy_set, y            ; xpos
    sta tile_data, X                 ; in tile data
    inx
    iny

    lda current_enemy_set, y            ; ypos
    sta tile_data, X                 ; in tile data
    iny
    inx

    pla 
    tax
    sty $00, X      ;enemy offset on virtual stack
    dex


    txa ; virtual stack offset to hw stack
    pha

    ldy #$00
    ; UNECESSARY?
    ; get the address of the enemy animation setting
    lda (temp_address), Y
    sta enemy_anim_addr
    iny
    lda (temp_address), Y
	sta enemy_anim_addr + 1 

    ; todo load length and tick the animation


    ; tile id
    ldy #$01 ; 00 is length
    ldx #$02
    lda (enemy_anim_addr), Y 
    sta tile_data, x
    inx
    iny

    ; attribute
    lda (enemy_anim_addr), Y 
    ;sta $00, X                     ; tile id in stack in virtual stack!
    sta tile_data, x
    iny

    pla ; pull  x (VIRTUAL STACK OFFSET) from stack
    tax

    ; height, length
    lda (enemy_anim_addr), Y
    sta $00, X                      ; height in hw stack!
    dex

    ; width, length
    lda (enemy_anim_addr), Y
    sta $00, X                      ; width in hw stack!
    dex
   
    jsr draw_object

    dex ; current enemy offset is already in hw stack .. just increase the stackpointer to point to the part after the offset

    dec temp_3  ; check if there are enemies left to draw
    lda temp_3
    cmp #$00
    beq :+
    jmp draw_enemy_object

    ; get oam offset from virtual stack and put it to y again
:   inx 
    ldy $00, X
    rts


; width in tile numbers
; height in tile numbers
; oam offset
; rest of data in tile data
draw_object:
    ; oam offset -> stored in y

    ;TODO load this in the loop and check-> double loop
    ; width
    inx 
    lda $00, X
    sta temp_1
    dec temp_1
    
    ; height
    inx
    lda $00, X
    sta temp_2
    dec temp_2

    lda temp_2
    ; shifted y offset
    asl 
    asl
    asl
    asl
    sta temp_4 ; offset for tile id

    inx ; ignore global enemy offset

    inx
    ldy $00, X  ; oam offset

    ;lda temp_1
    ;pha

    ; the rest we keep in the virtual stack ... as we reuse it in the draw sprite tile function

    ; now draw all associated tiles for this object
@draw_tiles_loop:
    jsr draw_tile

    ; check if we have drawn all x tiles
    lda temp_1 
    cmp #$00
    beq :+
    dec temp_1
    jmp @draw_tiles_loop
:   lda temp_2
    cmp #$00
    beq @epic_end ; if we have reached the last y tile let's stop drawing tiles
    dex ;if not let's decrease y and start drawing x tile with decreased y
    dex
    dex
    lda $00, X  ;reset x to be full x again
    sta temp_1
    dec temp_1
    inx
    inx 
    inx
    dec temp_2      ; decrease y 
    lda temp_4
    sec
    sbc #$10
    sta temp_4
    jmp @draw_tiles_loop
@epic_end:   ; epic return
    sty $00, X ; store current oam offset
    dex
    rts
    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; draw sprite tile
;
; X-stack arguments:
;   X_POSITION
;   Y_POSITION
;   TILE_ID
;   ATTRIBUTE_ID
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; temp 1 -> x offset
; temp 2 -> y offset
; temp 4 -> shifted y offset (instead of 01 .. 10)
; y -> oam offset
draw_tile:
    ; x position
    txa ; push current x to stack
    pha  

    ldx #$00
    lda tile_data, x
    pha ; push x to stack

    inx
    mult temp_2, #$08, temp_5
    ;sta temp_5
    lda tile_data, x
    clc
    adc temp_5 ; y offset
    sta oam, Y
    iny

    inx 
    lda tile_data, x ; tile id
    clc
    adc temp_1
    adc temp_4  ; y offset (shifted version of temp2)
    sta oam, y
    iny

    inx 
    lda tile_data, x ; attribute id
    sta oam, Y
    iny

    mult temp_1, #$08, temp_5

    pla ; get x position from stack
    clc
    adc temp_5
    sta oam, y
    iny

    ; get x from stack
    pla 
    tax
    rts