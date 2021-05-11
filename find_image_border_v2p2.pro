FUNCTION find_image_border_v2p2,img_in,border_value=border_value,img_check_name=img_check_name
;--------------------------------------------------
;Function to find the black border around a GeoTIFF
;Version 2 instead of finding border, we find the image and select the rest as border
;Version 2p1 - 9/10/2019: updated dmask from 20->min(sz/4) after looking at actual images
;Version 2p2 - too many stops on well masked images, changing to reporting to check file
;
;input: 
;img_in: a 2D array, where the border to mask is 0
;output: a binary mask (1=border area, 0=image data)
;
;keywords:
;  border_value: value of border you want to search for other than 0 (default) 
;  img_check_name: name of output file you want to export if there is an error thrown during the check
;--------------------------------------------------
;keyword initialization section
if n_elements(border_value) eq 0 then border_value = 0
if n_elements(img_check_name) eq 0 then img_check_name = ''

;get size of input image
sz = size(img_in,/dim)

;build output array for border mask 
mask = replicate(1B,sz[0],sz[1])

;loop through columns and find start/stop of border area
len = sz[0]
FOR c=0,sz[0]-1 DO BEGIN
  sel = where(img_in[c,*] ne border_value,nsel)
  
  ;if there are no points selected, just skip
  
  ;if there are some start this section
  if nsel gt 0 then begin
    mask[c,sel[0]:sel[-1]] = 0B
    ;if sel[0] ne 0 then mask[c,0:sel[0]-1] = 1B
    ;if sel[-1] ne sz[1]-1 then mask[c,sel[-1]+1:-1] = 1B 
  endif
  
  ;if the entire col is selected, flag the whole thing
  ;if nsel eq sz[0] then mask[c,*] = 1B
ENDFOR

;same thing for rows...
FOR r=0,sz[1]-1 DO BEGIN
  sel = where(img_in[*,r] ne border_value,nsel)

  ;if there are no points selected, just skip

  ;if there are some start this section
  if nsel gt 0 then begin
    mask[sel[0]:sel[-1],r] = 0B
    ;if sel[0] ne 0 then mask[0:sel[0]-1,r] = 1B
    ;if sel[-1] ne sz[0]-1 then mask[sel[-1]+1:-1,r] = 1B
  endif

  ;if the entire col is selected, flag the whole thing
  ;if nsel eq sz[1] then mask[*,r] = 1B
ENDFOR

;go through the final mask and ensure it's smooth & consistent

row_total = total(mask,1)
dmask = min(sz/4) ;number of pixels each consecutive row/column is allowed to change by without erroring out
check_flag = 0
FOR c2=0,sz[0]-1 DO BEGIN
  sel = where(mask[c2,*] eq 0,nmask)
  
  if c2 gt 0 then begin
    prevsel = where(mask[c2-1,*] eq 0,nprevmask)
    if abs(nmask-nprevmask) gt dmask then check_flag = 1
  endif
  
  if c2 lt sz[0]-1 THEN BEGIN
    nextsel = where(mask[c2+1,*] eq 0,nnextmask)
    if abs(nmask-nnextmask) gt dmask then check_flag = 1
  endif
ENDFOR

FOR r2=0,sz[1]-1 DO BEGIN
  sel = where(mask[*,r2] eq 0,nmask)

  if r2 gt 0 then begin
    prevsel = where(mask[*,r2-1] eq 0,nprevmask)
    if abs(nmask-nprevmask) gt dmask then check_flag = 1
  endif

  if r2 lt sz[1]-1 THEN BEGIN
    nextsel = where(mask[*,r2+1] eq 0,nnextmask)
    if abs(nmask-nnextmask) gt dmask then check_flag = 1
  endif
ENDFOR

if check_flag eq 1 AND img_check_name ne '' then begin
  openw,lun,img_check_name,/get_lun
  free_lun,lun
endif 

return,mask

END