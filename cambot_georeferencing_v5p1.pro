PRO cambot_georeferencing_v5p1

;Version 0p0 written by Al
;Version 0p1 updated by Jeremy to work on his system
;Version 0p2 adding in mounting bias section
;Version 0p3 adding in timing offset section
;Version 0p4 - skipped FoV section
;Version 0p5 updated image scenes
;Version 0p6 updated georeference code
;Version 0p7 added in lens correction data
;Version 0p7p1 investigating geotiff sections
;Version 0p8 updated geotiff section
;Version 0p9 updated timing offset section
;Version 0p9p1 investigating posav options
;Version 0p9p2 looking at geoid offset
;Version 0p10 updating georeferencing function call and moving from using aircraft altitude to aircraft range to ground for "elev"
;Version 0p10p1 lowered geotiff resolution to ensure less empty spaces in grid
;Version 0p11 updated to RGB geotiffs option
;Version 0p12 updated to include DMS from the Antarctic, for the correct southern hem metadata template
;Version 1p0 updated to include final mounting biases for Ant 2018 and adjustments to the focal length as well
;             as remove POSAV support, remove ancillary interpolation/interp_attitude function and clean up code
;Version 1p1 added new campaign variable and support
;Version 1p2 removed Arctic/Antarctic and yearly name
;Version 1p3 added Arctic 2019 support functions
;Version 1p4 fixed error in regridding that was not filling in holes
;Version 2p0_landice testing bringing in DEMs for land ice images
;Version 2p1_landice: updated cambot_geo_function function call
;Version 3p0: adding in support for land or sea ice flights, as well as bringing in processing_db file
;Version 3p1: adding in terrain_type filter to stop when we haven't setup the day yet
;Version 3p2: adding in file check for files that already exist when creating initial file list, so we can split up
;               up files yet to be done equally amongst workers
;Version 3p3: added fixes to file check for existing files
;Version 3p4: fixed issue with UserComment in the metadata not including terrain type
;Version 3p5: updated call to new version of sea ice code
;Version 4p0: updated to now include Antarctic processing with REMA
;Version 4p1: updated to support split_for_v3 new worker output option
;Version 4p2: updated to support new geo_function calls supporting error handling
;Version 4p3: updated to include new Ant 2019 mounting bias info 
;Version 4p4: updated call to new land ice function, which fixes missing data in REMA issue 
;Version 4p5: updated metadata function to support missing metadata fields
;Version 4p6: updated to fix error in processed files filter
;Version 4p7: updated to add in thread management code snippet so code doesn't take over the server
;Version 5p0: updated to change !pi -> !dpi and check double precision of the rest of the code where it makes sense. Also metadata save section.
;Version 5p1: updated for better missing DEM tracking

;; - process the CAMBOT jpg images with time matched aircraft data
;; - geolocate the images using the 'geolocate_image_v4p1' routine provided by Nathan and Jeremy
;; - implement roll, pitch, elevation corrections
;; - output the result as a  geotiff
;; Al Ivanoff

;*** ensure your working directory contains "exiftool" for the metadata support


dates = '2018'+['1019','1028','1105']
;dates = '20191023'
;dates = '201911'+['18']
;dates = '201904'+['22']

FOR d=0,n_elements(dates)-1 do begin

date = dates[d]

;campaign = 'Arctic2018'
campaign = 'Antarctic2018'
;campaign = 'Arctic2019'
;campaign = 'ArcticSummer2019'
;campaign = 'Antarctic2019'

rgb = 1 ;set to 0 to do smaller filesize B&W option
verbose = 2
overw = 0 ;set to 1 to overwrite current output files

Print,'Starting IOCAM1b code for '+date

sl = path_sep()
if strcmp(sl,'\') eq 1 then begin
  base_dir1 = 'Y:'
  base_dir2 = 'X:'
  base_dir3 = 'W:'
endif else begin
  base_dir1 = '/data/users'
  base_dir2 = '/data/derived'
  base_dir3 = '/scratch/icebridgedata'
endelse

case 1 of
  strcmp(campaign,'Arctic2018'): hem = 'GR'
  strcmp(campaign,'Antarctic2018'): hem = 'AN'
  strcmp(campaign,'Arctic2019'): hem = 'GR'
  strcmp(campaign,'ArcticSummer2019'): hem = 'GR'
  strcmp(campaign,'Antarctic2019'): hem = 'AN'
  else: STOP,'campaign not assigned'
endcase

;setup directories
syear = strmid(date,0,4)
camp_folder = syear+'_'+hem+'_NASA'
work_dir = base_dir1+sl+'jharbeck'+sl+'Working'+sl+'Cambot'+sl+'georeferencing'+sl
cambot_dir = base_dir3+sl+'IOCAM0'+sl+camp_folder+sl+date+sl
out_dir = base_dir3+sl+'IOCAM1B_CAMBOTgeoloc_v02'+sl+camp_folder+sl+date+sl 
worker_output_dir = out_dir+'worker_output'+sl

if file_test(work_dir,/dir) eq 0 then STOP
if file_test(cambot_dir,/dir) eq 0 then STOP
if file_test(out_dir,/dir) eq 0 then file_mkdir,out_dir
if file_test(worker_output_dir,/dir) eq 0 then file_mkdir,worker_output_dir

;find a lens correction file
lens_corr_dir = base_dir1+sl+'jharbeck'+sl+'Working'+sl+'Cambot'+sl
case 1 of
  strcmp(campaign,'Arctic2018'): lens_corr_file = lens_corr_dir+'Lens_corrections_CAMBOT_15814818.h5' ;Arctic 2018
  strcmp(campaign,'Antarctic2018'): lens_corr_file = lens_corr_dir+'Lens_corrections_CAMBOT_51500462.h5' ;Antarctic 2018
  strcmp(campaign,'Arctic2019'): lens_corr_file = lens_corr_dir+'Lens_corrections_CAMBOT_51500462.h5' ;Arctic 2019
  strcmp(campaign,'ArcticSummer2019'): lens_corr_file = lens_corr_dir+'Lens_corrections_CAMBOT_51500462.h5' ;Arctic Summer 2019
  strcmp(campaign,'Antarctic2019'): lens_corr_file = lens_corr_dir+'Lens_corrections_CAMBOT_51500462.h5' ;Antarctic 2019
  else: STOP,'No lens correction setup for this campaign'
endcase
if file_test(lens_corr_file) eq 0 then STOP


;Ancillary file
cambot_anc_file = base_dir3+sl+'IOCAM0'+sl+syear+'_'+hem+'_NASA'+sl+date+sl+'IOCAM0_'+syear+'_'+hem+'_NASA_'+date+'_ancillary_data.csv'
if file_test(cambot_anc_file) eq 0 then STOP,'cannot find CAMBOT ancillary file'

;read in terrain type processing database
terrain_db = base_dir2+sl+'for_NSIDC'+sl+'IOCAM0'+sl+'iocam0_database.sav'
if file_test(terrain_db) eq 0 then STOP,'cannot find CAMBOT terrain database file'
restore,terrain_db

;setup "user comment" here, which will be placed into the CAMBOT metadata field (set to '' to not use)
current_date_jul = systime(/julian)
caldat,current_date_jul,cmonth,cday,cyear
current_date = (strcompress(cyear,/rem)+'/'+add_zeroes2(cmonth,2)+'/'+add_zeroes2(cday,2))[0]
user_comment = 'ATM CAMBOT imagery, archival version. Reprojected GeoTIFFs generated at the IceBridge PSO, NASA GSFC, on '+current_date+'.' ;''

;start timing things!
t1 = systime(1)
;====================================================================================

;------------------------------------------------------------------------------------
;                        read in data from all sources
;------------------------------------------------------------------------------------

;*****LENS CORRECTIONS*****
;pull lens correction data out from the file provided
file_id = H5F_OPEN(lens_corr_file)
ID = H5D_OPEN(file_id,'xcorr')
xcorr = H5D_READ(ID)
ID = H5D_OPEN(file_id,'ycorr')
ycorr = H5D_READ(ID)

;transpose corrections from row (MATLAB) to column major (IDL)
xcorr = transpose(xcorr)
ycorr = transpose(ycorr)

;*****CAMBOT ancillary file*****
if verbose ge 1 then print,'Importing ancillary file'
anc_data =  read_cambot_ancillary_file_v1p0(cambot_anc_file)
if verbose ge 1 then print,'Successfully imported ancillary file'

;read in a single DMS file to get the geotiff metadata structure
;read in a single DMS file to get the geotiff metadata structure
case 1 of
  strcmp(campaign,'Arctic2018'): DMS_result = query_tiff(work_dir+'DMS_1543906_00012_20150324_11264434.tif',geotiff=geotag) ;N Hem
  strcmp(campaign,'Antarctic2018'): DMS_result = query_tiff(work_dir+'DMS_1381721_11877_20121107_22453575.tif',geotiff=geotag) ;S Hem
  strcmp(campaign,'Arctic2019'): DMS_result = query_tiff(work_dir+'DMS_1543906_00012_20150324_11264434.tif',geotiff=geotag) ;N Hem
  strcmp(campaign,'ArcticSummer2019'): DMS_result = query_tiff(work_dir+'DMS_1543906_00012_20150324_11264434.tif',geotiff=geotag) ;N Hem
  strcmp(campaign,'Antarctic2019'): DMS_result = query_tiff(work_dir+'DMS_1381721_11877_20121107_22453575.tif',geotiff=geotag) ;S Hem
  ELSE: STOP,'campaign geostructure file not found'
endcase

;save structures to an IDL save file, for use later in the child processes (as I can't get the structure passing to work)
struct_file = work_dir+'structure_file_'+strcompress(floor(systime(/seconds)),/rem)+'.sav'
save,filename=struct_file,anc_data,geotag
if verbose ge 1 then print,'Successfully imported geotag data'

;-------------------------------------------------------------------------------
;           find files we want to process and setup terrain types
;-------------------------------------------------------------------------------

;select files we want to process
if strcmp(sl,'\') eq 1 then begin
  spawn,'dir '+cambot_dir+'*.jpg /B',files_in
endif else begin
  files_in = file_basename(file_search(cambot_dir+'*.jpg'))
endelse
if verbose ge 1 then print,'Generated filelist: '+strcompress(n_elements(files_in))+' found'

;sort the files so they're in order
files_in_idx = sort(files_in)
files_in = files_in[files_in_idx]

;subset images here, if necessary
;files_in = files_in[20001:33500]
;STOP

;find timestamp of each file for sea ice/land ice filtering
file_time = float(strmid(files_in,29,8))

;find the first image assoc'd with each whole-second timestamp
sel = uniq(reverse(long(file_time)))
file_time = reverse((reverse(file_time))[sel])
files_in = reverse((reverse(files_in))[sel])

if verbose ge 1 then print,'Updated filelist to '+strcompress(n_elements(files_in))+' unique files by minute.'

;STOP
;files_in = files_in[19220:-1]

;check for existing, already processed files here and update the files_in array appropriately
if overw eq 0 then begin
  file_base_jpg = file_basename(files_in,'.jpg')
  file_base_jpg2 = strmid(file_base_jpg,7)
  
  ;find completed tif files
  if strcmp(sl,'\') eq 1 then begin
    spawn,'dir '+out_dir+'*.tif /B',files_out_tif
  endif else begin
    files_out_tif = file_basename(file_search(out_dir+'*.tif'))
  endelse
  file_base_tif = file_basename(files_out_tif,'.tif')
  file_base_tif2 = strmid(file_base_tif,8)

  ;find completed tif.txt files
  if strcmp(sl,'\') eq 1 then begin
    spawn,'dir '+out_dir+'*.tif.txt /B',files_out_txt
  endif else begin
    files_out_txt = file_basename(file_search(out_dir+'*.tif.txt'))
  endelse
  
  file_base_txt = file_basename(files_out_txt,'.tif.txt')  
  file_base_txt2 = strmid(file_base_txt,8)
  
  if n_elements(file_base_tif2) eq 1 and file_base_tif2[0] eq '' and n_elements(file_base_txt2) eq 1 and file_base_txt2[0] eq '' then goto,nofilesyet
  
  ;generate a completed filter list
  completed_filter = replicate(0,n_elements(file_base_jpg2))
  
  if n_elements(file_base_tif2) gt 1 then begin
    for n2 = 0,n_elements(file_base_tif2)-1 do begin
      done_tif_temp = where(file_base_jpg2 eq file_base_tif2[n2],nsel)
      if nsel ne 1 then STOP
      completed_filter[done_tif_temp] = 1
    endfor
  endif
  
  if n_elements(file_base_txt2) gt 1 then begin
    for n3 = 0,n_elements(file_base_txt2)-1 do begin
      done_txt_temp = where(file_base_jpg2 eq file_base_txt2[n3],nsel)
      if nsel ne 1 then STOP
      completed_filter[done_txt_temp] = 1
    endfor
  endif
  
  ;update file list todo
  still_todo = where(completed_filter eq 0,ntodo,complement=files_complete)
  if n_elements(file_base_tif2) eq 1 and file_base_tif2[0] eq '' then n_tif = 0 else n_tif = n_elements(file_base_tif2)
  if n_elements(file_base_txt2) eq 1 and file_base_txt2[0] eq '' then n_txt = 0 else n_txt = n_elements(file_base_txt2)
  if n_elements(files_complete) ne n_tif+n_txt then STOP,'Number of tif and txt files does not match number of complete files'
  if ntodo gt 0 then begin
    files_in = files_in[still_todo]
    file_time = file_time[still_todo]
    print,'Updated filelist to '+strcompress(n_elements(files_in))+' files that have yet to be processed.'
  endif else begin
    STOP,'All files complete for today'
  endelse

  nofilesyet:
endif

;generate arrays of terrain types to associate with each image 
terrain_type = strarr(n_elements(files_in))
sel_dbase_date = where(dbase.date eq date,nsel_dbase_date)
if nsel_dbase_date ne 1 then STOP
segments = dbase[sel_dbase_date].segment
good_seg = where(segments ne '',ngood_seg)
if ngood_seg lt 1 then STOP,'Terrain type not setup for today yet'
segments = segments[good_seg]

FOR seg=0,ngood_seg-1 DO BEGIN
  seg_temp = strsplit(segments[seg],':',/extract)
  sel_files = where(file_time ge float(seg_temp[1]) AND file_time le float(seg_temp[2]),nsel_files)
  if nsel_files gt 0 then terrain_type[sel_files] = strcompress(seg_temp[0],/remove_all) else print,'No files found for segment #'+strcompress(seg)+', times: '+seg_temp[1]+'->'+seg_temp[2]+'.' 
ENDFOR

;ensure a terrain type has been set for all images
missing_terrain = where(terrain_type eq '',nmissing_terrain)
if nmissing_terrain gt 0 then STOP,'some files are missing a terrain type'
if verbose ge 1 then print,'Updated filelist: '+strcompress(n_elements(files_in))+' files set to process' 
;===============================================================================

;-------------------------------------------------------------------------------
;                       Metadata preparation section
;-------------------------------------------------------------------------------
if verbose ge 1 then print,'Beginning metadata import'
m1 = systime(1)
metadata_file = cambot_dir+sl+'Metadata_for_'+date+'.sav'
if file_test(metadata_file) eq 1 then begin
  print,'Found metadata file for today! Restoring...'
  restore,metadata_file
endif else begin
  print,'No metadata file generated for today yet, creating one now...'
  case 1 of
    strcmp(campaign,'Arctic2018'): metadata = ''
    strcmp(campaign,'Antarctic2018'): metadata = cambot_metadata_prep_v1p4(cambot_dir,campaign=campaign,user_comment=user_comment)
    strcmp(campaign,'Arctic2019'): metadata = cambot_metadata_prep_v1p4(cambot_dir,campaign=campaign,user_comment=user_comment)
    strcmp(campaign,'ArcticSummer2019'): metadata = cambot_metadata_prep_v1p3(cambot_dir,campaign=campaign,user_comment=user_comment)
    strcmp(campaign,'Antarctic2019'): metadata = cambot_metadata_prep_v1p3(cambot_dir,campaign=campaign,user_comment=user_comment)
    else: STOP,'Metadata not selected'
  endcase
  save,filename=metadata_file,metadata
endelse
  
m2 = systime(1)
if verbose ge 1 then print,'Finished metadata import, '+strcompress((m2-m1)/60.0)+' minutes'
;===============================================================================

;-------------------------------------------------------------------------------
;                           Georeferencing section 
;-------------------------------------------------------------------------------

;setup variables for all the processing that is going to be done for both sea ice and land ice
files_in_full = cambot_dir+files_in
label_ver = ''
xcorr_orig = xcorr
ycorr_orig = ycorr

;setup variables that will be split for land and sea ice processing
sel_seaice = where(terrain_type eq 'seaice',nsel_seaice)
sel_landice = where(terrain_type ne 'seaice',nsel_landice)

;set flag to 1 to run the code in parallel, 0 to not. (mostly for timing and debug)
go_parallel = 1

if strcmp(sl,'\') eq 1 then begin
    ncores = 9 ;windows
  endif else begin
    ncores = 16 ;linux
endelse

;LAND ICE PROCESSING
IF nsel_landice gt 0 THEN BEGIN 

  if verbose ge 1 then print,'Beginning processing of land ice files...'
  files_in_full_landice = files_in_full[sel_landice]
  terrain_type_landice = terrain_type[sel_landice]
  
  start_point = 0 ;start index of image we are processing
  end_point = n_elements(files_in_full_landice)-1 ;10 ;end index of image we are processing
  
  ;parallel section begins here
  if go_parallel eq 1 then begin
    SPLIT_FOR_v3,start_point,end_point,ctvariable_name='f',commands=[$
      'CPU,tpool_nthreads = 1',$
      'restore,struct_file',$
      'file_in_full = files_in_full_landice[f]',$
      'terrain = terrain_type_landice[f]',$
      'xcorr = xcorr_orig',$
      'ycorr = ycorr_orig',$
      'result = cambot_geo_function_landice_v6p1(file_in_full,hem,label_ver,rgb,anc_data,geotag,xcorr,ycorr,out_dir,date,metadata,campaign,overwrite=ow,verbose=verbose,terrain=terrain)'],$
      varnames = ['files_in_full_landice','hem','label_ver','rgb','xcorr_orig','ycorr_orig','out_dir','date','struct_file','metadata','campaign','terrain_type_landice','verbose','overw'],$
      nsplit=ncores,worker_output_dir=worker_output_dir
  
  endif else begin
   
    for f=start_point,end_point do begin
      restore,struct_file
      file_in_full = files_in_full_landice[f]
      terrain = terrain_type_landice[f]
      xcorr = xcorr_orig
      ycorr = ycorr_orig
      result = cambot_geo_function_landice_v6p1(file_in_full,hem,label_ver,rgb,anc_data,geotag,xcorr,ycorr,out_dir,date,metadata,campaign,overwrite=overw,verbose=verbose,terrain=terrain);,shrink=10)
      
    endfor
    
  endelse
  if verbose ge 1 then print,'Finished processing of land ice files...'
ENDIF

;SEA ICE PROCESSING
IF nsel_seaice GT 0 THEN BEGIN
  
  if verbose ge 1 then print,'Beginning processing of land ice files...'
  files_in_full_seaice = files_in_full[sel_seaice]
  ;terrain_type_seaice = terrain_type[sel_seaice]

  start_point = 0 ;start index of image we are processing
  end_point = n_elements(files_in_full_seaice)-1 ;10 ;end index of image we are processing
  
  if verbose ge 1 then print,'Beginning processing of sea ice files...'
  
  ;parallel section begins here
  if go_parallel eq 1 then begin
    SPLIT_FOR_v3,start_point,end_point,ctvariable_name='f',commands=[$
      'restore,struct_file',$
      'file_in_full = files_in_full_seaice[f]',$
      'xcorr = xcorr_orig',$
      'ycorr = ycorr_orig',$
      'result = cambot_geo_function_seaice_v4p0(file_in_full,hem,label_ver,rgb,anc_data,geotag,xcorr,ycorr,out_dir,date,metadata,campaign,overwrite=0,verbose=verbose)'],$
      varnames = ['files_in_full_seaice','hem','label_ver','rgb','xcorr_orig','ycorr_orig','out_dir','date','struct_file','metadata','campaign','verbose'],$
      nsplit=ncores,worker_output_dir=worker_output_dir
  
  endif else begin
  
    for f=start_point,end_point do begin
      restore,struct_file
      file_in_full = files_in_full_seaice[f]
      xcorr = xcorr_orig
      ycorr = ycorr_orig
      result = cambot_geo_function_seaice_v4p0(file_in_full,hem,label_ver,rgb,anc_data,geotag,xcorr,ycorr,out_dir,date,metadata,campaign,overwrite=0,verbose=verbose);,shrink=10)
    endfor
  
  endelse
  
  if verbose ge 1 then print,'Finished processing of sea ice files...'
ENDIF

;===============================================================================

t2 = systime(1)
print,'Minutes to run entire code:',(t2 - t1)/60.0

;delete structure file we generated earlier
if file_test(struct_file) eq 1 then file_delete,struct_file

subject = 'CAMBOT IDL "orig" georeferencing code complete for '+strcompress(date,/remove_all)
body1 = 'Finished georeferencing '+strcompress(n_elements(files_in_full),/rem)+' images. '+string(13B)
body2 = 'Total sea ice images: '+strcompress(nsel_seaice,/rem)+', Total land ice images: '+strcompress(nsel_landice,/rem)+'. '+string(13B)
body3 = 'Minutes to run entire code: '+strcompress((t2 - t1)/60.0)+string(13B)
body = body1+body2+body3
result = send_email(subject,body,nasa=1)

ENDFOR

STOP

end