function fill_holes_v1p0,array,sz,missing_loc,missing_value
;----------------------------------------------
;a function that replaces missing locations
;with an average of surrounding values, not
;including missing values
;
;Version 1p0: 9/9/2019 - updates code with filter keeping indices of "pull" from going out
;                         of bounds on "array"
;
;array: the array to fill the holes in
;sz: size of the averaging we want to apply
;missing_loc: the index of the areas that we want to fill
;missing_value: values of "missing" areas, that won't be used to calculate fill value
;----------------------------------------------

fixed_array = array 
array_size = size(array,/dim)

for n=0,n_elements(missing_loc)-1 do begin
  this_loc = missing_loc[n]
  xyloc = array_indices(array,this_loc)
  left = xyloc[0]-sz
  right = xyloc[0]+sz
  bot = xyloc[1]-sz
  top = xyloc[1]+sz
  
  if left lt 0 then left = 0
  if right gt array_size[0]-1 then right = array_size[0]-1
  if bot lt 0 then bot = 0
  if top gt array_size[1]-1 then top = array_size[1]-1 
  
  ;pull = array[xyloc[0]-sz:xyloc[0]+sz,xyloc[1]-sz:xyloc[1]+sz]
  pull = array[left:right,bot:top]
  
  good = where(pull ne missing_value,ngood)
  if ngood eq 0 then goto,nogood
  
  fixed_array[this_loc] = mean(pull[good])
  
  nogood:
endfor

return,fixed_array

end