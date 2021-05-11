function read_CAMBOT_ancillary_file_v1p0,file

;-----------------------------------------------------------------
;funtion to read in data from a FLIR lookup file produced by 
;the ATM team. Input format is csv. Return format is a structure.
;
;Version 1p0 20180702 adjusts itself for varying header sizes
;-----------------------------------------------------------------

;check for exitence of file
if file_test(file) eq 0 then STOP,'cannot find input file'

;open file
temp_read = ''
openr,lun,file,/get_lun

;read header (4 lines in 2016 quicklook, 6 lines in 2017 quicklook)
for hdr_len=0,20 do begin
  readf,lun,temp_read
  if strcmp(strmid(temp_read,0,1),'#') eq 0 then break
endfor

;input
temp_query = query_ascii(file,info)
if temp_query eq 1 then nlines = info.lines-hdr_len else STOP,'issue querying input file for number of lines' ;one,4 less line for header

;setup output variables
flir_filename = replicate('',nlines)
time = replicate('',nlines) ;ex: 2015-03-29T19:23:41.218000, in UTC
posix_time = replicate(0.0D,nlines) ;ex: 1427657021.218, in UTC
lat = posix_time ;deg
lon = posix_time ;deg
aircraft_alt = posix_time ;in meters
range_to_ground = posix_time ;in meters
roll = posix_time ;deg
pitch = posix_time ;deg
heading = posix_time ;deg


for n=0,nlines-1 do begin
  if n ne 0 then readf,lun,temp_read
  temp2 = strsplit(temp_read,',',/extract)
  
  flir_filename[n] = temp2[0]
  time[n] = temp2[1]
  posix_time[n] = double(temp2[2])
  lat[n] = double(temp2[3])
  lon[n] = double(temp2[4])
  aircraft_alt[n] = double(temp2[5]) ;antenna altitude
  range_to_ground[n] = double(temp2[6]) ;"AGL", range to ground of center of ATM swath from ATM instrument
  roll[n] = float(temp2[7])
  pitch[n] = float(temp2[8])
  heading[n] = float(temp2[9])
endfor

free_lun,lun

;place all data into a structure
data = create_struct('filename',flir_filename,'time',time,'posix_time',posix_time,'lat',lat,'lon',lon,'alt',aircraft_alt,'range',range_to_ground,'roll',roll,'pitch',pitch,'heading',heading)

return,data
END