Function cambot_metadata_prep_v1p4,path_in,campaign=campaign,user_comment=user_comment
;-------------------------------------------------------------
;Function that when given a directory containing jpeg images
;(or single filename), reads in the metadata from every image
;and returns prepped metadata strings ready to be attached
;to GeoTIFF files, tags and all
;
;Version 1p1: 20190507 : added in campaign keyword and support
;Version 1p2: 20190827 : added in user_comments keyword and support
;Version 1p3: 20201015 : added in support for a couple metadata fields being blank, from re-processing
;                         images to fix read errors in photoshop
;Version 1p4: 20201203 : added in support for missing elements in some Antarctic 2018 images, mainly hardware types
;-------------------------------------------------------------
if n_elements(campaign) eq 0 then campaign = ''
if n_elements(user_comment) eq 0 then user_comment = ''

sl = path_sep()
if strcmp(sl,'\') eq 1 then begin
  base_dir1 = 'Y:' ;code locations
  base_dir2 = 'X:' ;data storage
  base_dir3 = 'W:'
endif else begin
  base_dir1 = '/data/users'
  base_dir2 = '/data/derived'
  base_dir3 = '/scratch/icebridgedata'
endelse

;dir = base_dir1+sl+'jharbeck'+sl+'Working'+sl+'Cambot'+sl+'metadata'+sl+'test'+sl
;jpeg_file = dir+'20181002-223424.9220.jpg'
;tiff_file = dir+'20181002-223424.9220_geo_ver_adj_anc_rgb.tif'
;test_dir = 'X:\2018_fall_quicklook\CAMBOT\2018-10-02\'

;add these fields to the GeoTIFF
; 00 : filename (only in metadata field)
; 01 : Make
; 02 : Model
; 03 : ExposureTime
; 04 : FNumber
; 05 : TimeZoneOffset
; 06 : UserComment
; 07 : SubSecTimeOriginal
; 08 : SubSecTimeDigitized
; 09 : DateTimeOriginal
; 10 : CreateDate
; 11 : ExposureIndex (value in microseconds we use for exposure in camera operations)
; 12 : ExposureMode (Manual or Auto)
; 13 : GainControl
; 14 : LensMake
; 15 : LensModel
; 16 : LensSerialNumber
; 17 : FocalLengthIn35mmFormat
; 18 : FocalLength

;list of exif tags for which to pull data from each jpeg file(s)
text1 = '-make -model -exposuretime -fnumber -timezoneoffset -usercomment -subsectimeoriginal -subsectimedigitized -datetimeoriginal -createdate -exposureindex -exposuremode 
text2 = '-gaincontrol# -lensmake -lensmodel -lensserialnumber -focallengthin35mmformat -focallength'

;pull data from the images
if strcmp(sl,'\') eq 1 then begin ;windows first
  spawn,'exiftool -S -csv -ext "jpg" '+text1+' '+text2+' '+path_in,output,/hide ;individual images
endif else begin  
  spawn,'/data/users/jharbeck/Working/exiftool/Image-ExifTool-12.14/exiftool -S -csv -ext "jpg" '+text1+' '+text2+' '+path_in,output ;entire folder worth
endelse

;split names and data fields up for the header and each image in the folder
names = strsplit(output[0],",",/extract)
data = strarr(n_elements(output)-1,n_elements(names))

for n=0,n_elements(output)-2 do begin
  temp = strsplit(output[n+1],",",/extract,/preserve_null)
  if n eq 0 then begin
    ;assume that we have the same hardware for an entire flight and the first image has all the correct info
    make_value = temp[1]
    model_value = temp[2]
    timezone_offset_value = temp[5] 
    lensmake_value = temp[14]
    lensmodel_value = temp[15]
    lensserialnumber_value = temp[16]
    focallengthin35_value = temp[17]
    focallength_value = temp[18]
  endif
  
  ;fill in missing values if there are any
  if strcmp(temp[1],'') then temp[1] = make_value  ;'Allied Vision Technologies'
  if strcmp(temp[2],'') then temp[2] = model_value  ;'GT4905C'
  if strcmp(temp[5],'') then temp[5] = timezone_offset_value ;'0'
  if strcmp(temp[14],'') then temp[14] = lensmake_value
  if strcmp(temp[15],'') then temp[15] = lensmodel_value
  if strcmp(temp[16],'') then temp[16] = lensserialnumber_value
  
  if strcmp(temp[17],'') then temp[17] = focallengthin35_value
  if strcmp(strmid(temp[17],0,1),'0') then temp[17] = focallengthin35_value ;sometimes we have 0's for this and the next one
  
  if strcmp(temp[18],'') then temp[18] = focallength_value
  if strcmp(strmid(temp[18],0,1),'0') then temp[18] = focallength_value
  
  ;if total(strcmp(temp,'')) ge 1 then STOP,'missing value in metadata'
  data[n,*] = temp
endfor

check = 0
;go through and update aperture values for Antarctic 2018 campaign
if strcmp(campaign,'Antarctic2018') eq 1 then begin
  for n=0,n_elements(output)-2 do begin
    
    ;translate CAMBOT decimal apertures into real-life apertures
    ap = data[n,4]
    fap = float(ap) ;do a convert attempt on the extracted aperture, if it's not a number, we can test it
    if n eq 0 then first_aperture = fap
    if fap eq 0.0 then ap = first_aperture ;as it is unlikely that the aperture will change during the flight, we set broken values to the starting one.
    
    jpeg_ap = [0.5,0.357,0.25,0.1785,0.125,0.0909,0.0625,0.04545]
    real_ap = ['2','2.8', '4', '5.6',  '8',  '11',  '16',   '22']
    minn = min(abs(fap-jpeg_ap),loc)
    data[n,4] = real_ap[loc]
    
    if check eq 1 then STOP
    ;pull value from gaincontrol output
    ;ga = data[n,13]
    ;tmp = strsplit(ga,'(',/extract)
    ;data[n,13] = strmid(tmp[1],0,2)
    
  endfor
endif

;update user comments (if applicable) to include GeoTiff/PSO processing mark
if strmatch(user_comment[0],'') eq 0 then data[*,6] = user_comment

;update gaincontrol tag to contain a "#", so we can write a gain value to it outside the definitions 
;names[13] = names[13]+'#'

;prep metadata return field
metadata = strarr(2,n_elements(output)-1)

;loop through all images in the folder and update the metadata 
for p=0,n_elements(output)-2 do begin
  metadata[0,p] = file_basename(data[p,0])
  
  ;arrange all metadata into a format for writing to file
  text3 = ''
  for n=1,n_elements(names)-1 do text3 = text3+' -'+names[n]+'="'+data[p,n]+'"'
  
  ;add metadata to output variable
  metadata[1,p] = text3
  
  ;spawn,'exiftool -P -overwrite_original '+text3+' '+tiff_file[p]
  ;spawn,'exiftool -P '+text3+' '+tiff_file[p]
endfor

return,metadata

END