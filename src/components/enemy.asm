.include "globals.asm"
.include "macros.asm"

.importzp kill_count, num_enemies_alive
.import collision_results, num_collision_results

.export create_enemy_component
.export init_enemy_components
.export enemy_cmp_process_cd_results

.rodata
ENEMY_COMP_SIZE = 4

dead_enemy_animation:
    .byte $01                               ; length frames
    .byte $08                               ; speed
    .byte $25                               ; starting tile ID
    .byte $03                               ; attribute set
    .byte $01                               ; padding x, z -> 1 tiles wide and high

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; enemy_component:
;    .addr owner                     ; entity -> contains x and y position
;    .addr sprite_component
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "BSS"
enemy_component_container: .res 80

num_enemy_components: .res 1

.export num_enemy_components


.code
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INIT CODE .. reset all variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.proc init_enemy_components
    lda #$00
    sta num_enemy_components
    rts
.endproc


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; create enemy components
; ARGS:
;   address_1           - owner
;   address_2           - sprite config
;
; RETURN:
;   address_3           - address of movement_component
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.proc create_enemy_component
    ; calculate offset in current component buffer
    mult_with_constant num_enemy_components, #ENEMY_COMP_SIZE, var_5

    calc_address_with_offset enemy_component_container, var_5, address_3 ; address_3 is return address

    ldy #$00                                ; owner lo
    lda address_1
    sta (address_3), y

    iny
    lda address_1 + 1                       ; owner hi
    sta (address_3), y
    iny

    lda address_2
    sta (address_3), Y
    iny

    lda address_2 + 1
    sta (address_3), y

    inc num_enemy_components
    rts
.endproc


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; process collision detection result:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.proc enemy_cmp_process_cd_results
    ; calculate max value and store it in var_1
    lda num_enemy_components
    sta var_1

    lda #<enemy_component_container
    sta address_1

    lda #>enemy_component_container
    sta address_1 + 1

    lda #<collision_results
    sta address_2

    lda #>collision_results
    sta address_2 + 1

    ldy #$00
    tya
    pha

    lda num_enemy_components
    cmp #$00
    beq @return_to_main                    ; early out if list is empty

    lda num_collision_results
    cmp #00
    beq @return_to_main

@process_enemy_coll_cmp:
    dec var_1                              ;check remaining coll_components, end this if 0
    lda var_1
    cmp #$00
    beq @return_to_main

    ; get y offset for the enemy
    pla
    tay

    ; check if enemy is in collision component result list
    ; if yes, hide it
    lda (address_1), Y
    sta var_3
    iny

    lda (address_1), y
    sta var_4
    iny

    iny                                     ; go over sprite component address
    iny

    tya
    pha

    ; go over all collision results
    mult_with_constant num_collision_results, #2, var_5
    sta var_5
@process_coll:
    mult_with_constant var_5, #2, var_6     ; get offset in result buffer for current
    lda var_6
    tay                                     ; use offset for accessing result buffer
    lda (address_2), Y                      ; compare entity lo-byte
    cmp var_3
    bne @jump_to_next_result

    iny
    lda (address_2), Y
    cmp var_4                               ; compare entity hi-byte
    bne @jump_to_next_result

    inc kill_count
    dec num_enemies_alive
    jmp @reset_sprite                       ; change sprite component

@jump_to_next_result:
    dec var_5
    lda var_5
    cmp #$00
    bne @process_coll
    jmp @process_enemy_coll_cmp

@return_to_main:
    pla
    rts

@reset_sprite:
    ;jmp @process_enemy_coll_cmp

    ; TBC
    ; get address of sprite component
    pla
    tay

    dey
    dey

    lda (address_1), Y
    sta address_3
    iny

    lda (address_1), y
    sta address_3 + 1
    iny

    tya
    pha

    lda #<dead_enemy_animation
    sta address_4

    lda #>dead_enemy_animation
    sta address_4 + 1

    ldy #$02 ;offset to sprite config
    lda address_4
    sta (address_3), Y
    iny

    lda address_4 + 1
    sta (address_3), Y
    iny

    lda #$00
    sta (address_3), y

    jmp @process_enemy_coll_cmp
.endproc
