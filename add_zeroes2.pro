FUNCTION add_zeroes2,names,length
;function to make sure all entries in "names" are a string of a specific length

;prep names
snames = strcompress(string(names),/remove_all) 
if length lt max(strlen(snames)) then begin
  print, 'specified length shorter than maximum length of at least one entry, adjusting length value" 
  length = max(strlen(snames))
endif

;append zeroes
fnames = strarr(n_elements(snames))
for n=0,length do begin
  loc = where(strlen(snames) eq n,count)
  if count gt 0 then begin
    addon = strmid(strcompress(string(10L^(length-n)),/remove_all),1,length-n)
    fnames[loc] = addon+snames[loc]
  endif
endfor

return,fnames

END