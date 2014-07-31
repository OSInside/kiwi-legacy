;
; bootnext.asm
;
; A small boot program that boots the first local disk that does not have
; the same id (4 bytes at offset 1b8h) as 'bootnext'.
;
; Copyright (c) 2010 Steffen Winterfeldt.
;
; Licensed under GPL2; for details see file LICENSE.
;


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      bits 16

disk_buf    equ 7c00h
mbr_start   equ 6000h
id_ofs      equ  1b8h

      section .text

      org mbr_start

      mov ax,cs
      mov ss,ax
      xor sp,sp
      mov ds,ax
      mov es,ax
      cld
      sti

      ; move us out of the way
      mov si,disk_buf
      mov di,mbr_start
      mov cx,100h
      rep movsw
      jmp 0:main_10

main_10:
      ; look at all drives in turn until we find one with
      ; a non-matching id
      mov ah,8
      xor di,di
      mov dl,80h
      int 13h
      jnc main_20
      mov dl,1    ; we'll try at least one
main_20:
      cmp dl,1    ; dto
      mov al,80h
      adc dl,al
      mov [bios_drives],dl

main_30:
      mov [drive],al
      call check
      jnc main_60
      mov al,[drive]
      inc ax
      cmp al,[bios_drives]
      jb main_30

      mov si,msg_no_os
      jmp final_msg
main_60:
      cmp byte [drive],80h
      jz main_70
      call relocate
main_70:      
      ; continue with MBR
      mov dl,80h
      jmp 0:disk_buf


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Copy us to top of memory and install new int 13h interrupt handler.
;
relocate:
      mov ax,[413h]   ; mem size in kB
      dec ax      ; reserve 1k
      mov [413h],ax
      shl ax,6
      sub ax,mbr_start >> 4
      mov edx,[13h*4]
      mov [old_int13],edx
      push ax
      push word new_int13
      pop dword [13h*4]
      push ax
      pop es
      mov si,mbr_start
      mov di,si
      mov cx,100h
      rep movsw
      ret


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Swap drives 80h and [drive].
;
new_int13:
      pushf

      mov [cs:dl_old],dl
      mov [cs:ah_old],ah

      cmp dl,[cs:drive]
      jnz new_int13_20
      mov dl,80h
      jmp new_int13_50
new_int13_20:
      cmp dl,80h
      jnz new_int13_50
      mov dl,[cs:drive]
new_int13_50:
      call far [cs:old_int13]
      push ax
      lahf
      mov [esp+6],ah
      pop ax

      ; ah = 8 changes dl; otherwise restore value
      cmp byte [cs:ah_old],8
      jz new_int13_90
      mov dl,[cs:dl_old]
new_int13_90:
      iret


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Read MBR and check id (id should _not_ match).
;
; return:
;   CF:   0 ok; 1 not
;
check:
      call disk_read
      jc check_90
      mov eax,[magic_id]
      cmp eax,[disk_buf+id_ofs]
      stc
      jz check_90
      clc
check_90:
      ret


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Read MBR and verify boot signature.
;
; return:
;   CF:   0 ok; 1 not
;
disk_read:
      mov ax,201h
      mov cx,1
      mov dh,0
      mov dl,[drive]
      mov bx,disk_buf
      int 13h
      jc disk_read_90
      ; there should be proper boot code
      cmp dword [disk_buf],0
      stc
      jz disk_read_90
      cmp word [disk_buf+1feh],0aa55h
      stc
      jnz disk_read_90
      clc
disk_read_90:
      ret


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Write string and let user reboot.
;
;  si     text
;
; return:
;
final_msg:
      call print
      mov si,msg_next
      call print
      mov ah,0
      int 16h
      mov si,msg_nl
      call print
      int 19h

final_msg_10:
      hlt
      jmp final_msg_10


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; Write string.
;
;  si     text
;
; return:
;
print:
      lodsb
      or al,al
      jz print_90
      mov bx,7
      mov ah,14
      int 10h
      jmp print
print_90:
      ret


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
old_int13   dd 0
bios_drives   db 0
drive     db 0
dl_old      db 0
ah_old      db 0

msg_no_os   db "No operating system."
msg_nl      db 13, 10
msg_no_msg    db 0
msg_next    db 10, "Press a key to reboot.", 0


; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
%if ($ - $$) > id_ofs
%error "mbr too big"
%endif

      times id_ofs - ($ - $$) db 0

magic_id    dd 0

      times 1feh - ($ - $$) db 0
      dw 0aa55h

