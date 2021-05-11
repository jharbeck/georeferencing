Function cambot_metadata_prep_v1p3,path_in,campaign=campaign,user_comment=user_comment
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
;Make
;Model
;ExposureTime
;FNumber
;TimeZoneOffset
;UserComment
;SubSecTimeOriginal
;SubSecTimeDigitized
;DateTimeOriginal
;CreateDate
;ExposureIndex (value in microseconds we use for exposure in camera operations)
;ExposureMode (Manual or Auto)
;GainControl
;LensMake
;LensModel
;LensSerialNumber
;FocalLengthIn35mmFormat
;FocalLength

;list of exif tags for which to pull data from each jpeg file(s)
text1 = '-make -model -exposuretime -fnumber -timezoneoffset -usercomment -subsectimeoriginal -subsectimedigitized -datetimeoriginal -createdate -exposureindex -exposuremode 
text2 = '-gaincontrol# -lensmake -lensmodel -lensserialnumber -focallengthin35mmformat -focallength'

;pull data from the images
if strcmp(sl,'\') eq 1 then begin ;windows first
  spawn,'exiftool -S -csv -ext "jpg" '+text1+' '+text2+' '+path_in,output,/hide ;individual images
endif else begin  
  spawn,'exiftool -S -csv -ext "jpg" '+text1+' '+text2+' '+path_in,output ;entire folder worth
endelse

;split names and data fields up for the header and each image in the folder
names = strsplit(output[0],",",/extract)
data = strarr(n_elements(output)-1,n_elements(names))
for n=0,n_elements(output)-2 do begin
  temp = strsplit(output[n+1],",",/extract,/preserve_null)
  if strcmp(temp[1],'') then temp[1] = 'Allied Vision Technologies'
  if strcmp(temp[2],'') then temp[2] = 'GT4905C'
  if strcmp(temp[5],'') then temp[5] = '0'
  ;if total(strcmp(temp,'')) ge 1 then STOP,'missing value in metadata'
  data[n,*] = temp
endfor

;go through and update aperture values for Antarctic 2018 campaign
if strcmp(campaign,'Antarctic2018') eq 1 then begin
  for n=0,n_elements(output)-2 do begin
    
    ;translate CAMBOT decimal apertures into real-life apertures
    ap = data[n,4]
    jpeg_ap = [0.5,0.357,0.25,0.1785,0.125,0.0909,0.0625,0.04545]
    real_ap = ['2','2.8', '4', '5.6',  '8',  '11',  '16',   '22']
    minn = min(abs(ap-jpeg_ap),loc)
    data[n,4] = real_ap[loc]
    
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