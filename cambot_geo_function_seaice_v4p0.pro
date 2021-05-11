Function cambot_geo_function_seaice_v4p0,file_in_full,hem,label_ver,rgb,anc_data,geotag,xcorr,ycorr,out_dir,date,metadata,campaign,overwrite=overwrite,verbose=verbose
;Function that holds all the georeferencing parts so we can
;parallelize the entire code for multiple images

;Jeremy Harbeck, ADNET Systems Inc. 12/3/2018
;Version 1p0, 20190110 - updated to try and fix output image dimension problems
;Version 1p1, 20190111 - updated to fix holes in gridding problem
;Version 2p0, 20190313 - updated to incorporate focal length fixes, remove ancillary file
;                         interpolation and add in metadata support
;Version 2p1, 20190319 - added campaign input
;Version 2p2, 20190320 - changed morph_close to new "fill_holes" function
;Version 2p3, 20190326 - added overwright support
;Version 2p4, 20190507 - added Arctic 2019 campaign support
;Version 2p5, 20190806 - fixed error in regridding portion that did not fill all holes due to find_image_border function issue
;Version 2p6, 20190827 - updated with adjustments to make NSIDC compliant
;Version 2p7, 20190909 - updated mounting biases and focal length values for Arctic 2019 & Ant 2018 from Arctic 2019 analysis
;Version 2p8, 20190910 - updated call to find_image_border_v2p1 function
;Version 2p9, 20190918 - added in section at end to change metadata for campaign-specific values: focal_length
;Version 2p10,20191007 - updated to add in support for Arctic Summer 2019 and Antarctic 2019
;Version seaice_v3p0, 20200528 - updated to bring into line with land ice version of the code more
;Version seaice_v3p1, 20200529 - updated to include roll/pitch offset filtering and support for "out_file_missing" with regards to overwrite file checking
;Version seaice_v3p2, 20200602 - updated to add in verbose keyword as well as updated geolocation function call to pass verbose keyword in
;Version seaice_v3p3, 20200817 - fixed error in bw gridding portion of code
;Version seaice_v3p4, 20200923 - adds in I/O error support for corrupt jpegs
;Version seaice_v3p5, 20200925 - adds in mounting bias info for Ant 2019
;Version seaice_v4p0, 20201217 - updates precisions to double

;-------------------------------------------------------------------------------
;                                  INPUT
;-------------------------------------------------------------------------------
;file_in_full: absolute path of filename to georeference, including name of file
;               and extension (string)
;label_ver: version number to be added into output filename (string)
;rgb: flag for producing a single image (red channel) or RGB image (full-color),
;     (integer, values 0 or 1)
;anc_data: absolute path to and containing ancillary data file
;geotag: absolute path to IDL save file containing geotag structure pulled from
;         DMS image
;xcorr/ycorr: lens correction arrays from MATLAB lens correction routine (float
;             identical in size to input image size)
;out_dir: location to output final GeoTIFF images (string)
;date: date of flight origination, in YYYYMMDD format. Used to correct timestamp
;       offsets for flights that go over midnight UTC.
;metadata: array of metadata for all camera settings for all images taken on 
;           this flight, including this image. (string) 
;campaign: name of campaign these images are from, for selecting campaign
;           specific processing variables and functions below (string)
;
;***KEYWORDS***
;overwrite: set to 1 to overwrite file if it currently exists, 0 (default), skips
;           reprocessing the file altogether
;verbose: set to level of output 
;===============================================================================

;-------------------------------------------------------------------------------
;                             initial setup area
;-------------------------------------------------------------------------------
result = 0 ;initialize this here, so if code crashes early, a failure value will be returned
skip_flag = 0 ;initalize this flag here to report when an image has been skipped to export a filler file
skip_reason = ''
timing_start_geolocate_code = systime(/seconds) ;start timing this entire function here

;keyword setup
if n_elements(overwrite) eq 0 then overwrite = 0
if n_elements(verbose) eq 0 then verbose = 0

;ensure we have a jpeg image to process in the first place
if file_test(file_in_full) eq 0 then begin
  print,'Cannot find file_in_full: '+file_in_full
  print,'skipping file...'
  skip_flag = 1
  skip_reason = 'Could not find JPEG file: '+file_in_full
  goto,skip_image
endif

;generate output filename
file_in = file_basename(file_in_full)
image_name_part = strmid(file_in,6,strlen(file_in)-10)
out_file = out_dir+'IOCAM1B'+image_name_part+label_ver+'.tif'
out_file_missing = out_dir+'IOCAM1B'+image_name_part+label_ver+'.tif.txt'
border_check_name = out_dir+file_basename(out_file,'tif')+'err'

;check for and handle existing file, if it exists
if file_test(out_file) eq 1 OR file_test(out_file_missing) eq 1 then begin 
  if overwrite eq 0 then begin
    if verbose ge 1 then print,'Image: '+out_file+' already exists, skipping...'
    skip_flag = 0 ;do not write a filler file
    goto, skip_image
  endif
endif
  
;~~~setup error handling here~~~
;I/O error section
on_ioerror,io_error_jumppoint

no_error = 0
if no_error eq 1 then begin
  io_error_jumppoint:
  Help, /Last_Message, Output=theErrorMessage
  out_file_missing = out_dir+'IOCAM1B'+image_name_part+label_ver+'.tif.err'
  skip_flag = 1
  skip_reason = 'I/O error during jpeg read-in. Error: '+string(13B)+theErrorMessage
  goto,skip_image
endif

;general error catch section
catch,theError
if theError ne 0 then begin
  catch,/cancel
  Help, /Last_Message, Output=theErrorMessage
  out_file_missing = out_dir+'IOCAM1B'+image_name_part+label_ver+'.tif.err'
  skip_flag = 1
  skip_reason = 'catch error during jpeg read-in. Error: '+string(13B)+theErrorMessage
  goto,skip_image
endif
;~~~End of error handling section~~~  
  
if verbose ge 1 then print,'Beginning processing image: '+file_in

;===============================================================================

;-------------------------------------------------------------------------------
;                   read in image and prep for georeferencing
;-------------------------------------------------------------------------------
;img_in = read_image(file_in_full)
read_jpeg,file_in_full,img_in ;change to specific read_jpeg program from read_image function, to allow for I/O specific error handling

;; just use a single band
img = reform(img_in(0, *, *))

if rgb ne 0 then begin
  imgG = reform(img_in(1, *, *))
  imgB = reform(img_in(2, *, *))
endif

;---------------------------------------
;  rotate input image so that flight 
;        direction is upwards
;---------------------------------------
;;swap fov_x/y accordingly
;;also orient the image so that up is azimuth 0 (north)
;img = rotate(img, 3) ;DMS
;img = rotate(img, 2) ;CAMBOT Arctic 2017

case 1 of
  strcmp(campaign,'Arctic2018'): begin
                                  ; CAMBOT Arctic 2018
                                  ;***no rotation
                                 end
  strcmp(campaign,'Antarctic2018'): begin                               
                                    ;CAMBOT Antarctic 2018
                                    img = rotate(img, 2) 
                                    
                                    if rgb ne 0 then begin
                                      imgG = rotate(imgG,2)
                                      imgB = rotate(imgB,2)
                                    endif
                                  end
  strcmp(campaign,'Arctic2019'): begin
                                  ; CAMBOT Arctic 2019
                                  ;***no rotation
                                 end
  strcmp(campaign,'ArcticSummer2019'): begin
                                  ; CAMBOT Arctic Summer 2019
                                    img = rotate(img, 2) 
                                    
                                    if rgb ne 0 then begin
                                      imgG = rotate(imgG,2)
                                      imgB = rotate(imgB,2)
                                    endif
                                  end
  strcmp(campaign,'Antarctic2019'): begin
                                    ;CAMBOT Antarctic 2019
                                    img = rotate(img, 2) 
                                    
                                    if rgb ne 0 then begin
                                      imgG = rotate(imgG,2)
                                      imgB = rotate(imgB,2)
                                    endif
                                 end
  else: STOP,'no image rotation campaign match'
endcase
;=======================================

;---------------------------------------
;correct the longitude mirror flip issue
;---------------------------------------
;applied for campaigns: Arctic 2018, Antarctic 2018, Arctic 2019, Arctic Summer 2019 & Antarctic 2019
img = reverse(img, 1)

if rgb ne 0 then begin
  imgG = reverse(imgG, 1)
  imgB = reverse(imgB, 1)
endif

img_size = size(img)
xsize = img_size[1]
ysize = img_size[2]

;===============================================================================

;-------------------------------------------------------------------------------
;                   pull ancillary data for this image
;-------------------------------------------------------------------------------
sel = where(anc_data.filename eq file_in,nsel)
if nsel ne 1 then begin
  print,'cannot find a filename match in the ancillary file for: '+file_in
  print,'skipping file...'
  skip_flag = 1
  skip_reason = 'Could not find a filename match in the ancillary file for: '+file_in
  goto,skip_image
endif

unix_offset = (julday(strmid(date,4,2),strmid(date,6,2),strmid(date,0,4))-julday(1,1,1970))*24.0*3600.0

ac_time = anc_data.posix_time[sel]-unix_offset
ac_lat = anc_data.lat[sel]
ac_lon = anc_data.lon[sel]
ac_elev = anc_data.range[sel] ;use of ATM-derived range (distance from ATM to surface) for sea ice code, in meters
ac_roll = anc_data.roll[sel]
ac_pitch = anc_data.pitch[sel]
ac_azim = anc_data.heading[sel]

;ensure we have a valid range for this image, if not, then skip the image
if ac_elev lt -999 then begin
  if verbose ge 1 then print,'No valid AGL ATM-based range value for file: '+file_in+', skipping file...'
  skip_flag = 1
  skip_reason = 'Could not find a valid AGL ATM-based range value for file: '+file_in
  goto,skip_image
endif

;ensure roll/pitch are within bounds for a successful geolocation
max_point_angle = 15.0

totangle = find_total_pointing_angle_dbl(ac_roll,ac_pitch)
if totangle gt max_point_angle then begin
  skip_flag = 1
  skip_reason = 'Total pointing angle is above max of '+strcompress(max_point_angle,/rem)+' degrees.'
  goto,skip_image
endif


;sl = path_sep()
;if strcmp(sl,'\') eq 1 then begin
;  geoid_file = 'Y:\jharbeck\Working\Geoid\und_min1x1_egm2008_Nmax2190_MeanTide_TP_global'
;endif else begin
;  geoid_file = '/data/users/jharbeck/Working/Geoid/und_min1x1_egm2008_Nmax2190_MeanTide_TP_global'
;endelse

;geoid_elev = geoidvals_mt_v3(ac_lat,ac_lon,geoid_file=geoid_file)
;ac_elev = ac_elev-geoid_elev
;===============================================================================

;-------------------------------------------------------------------------------
;        input mounting biases and calculate attitude for specific frame
;-------------------------------------------------------------------------------
case 1 of
  strcmp(campaign,'Arctic2018'): begin
    ; CAMBOT Arctic 2018 (temporary mounting biases for 
    pitch_bias = -4.26D
    roll_bias = -1.36D
    heading_bias = 0.56D
    
    ;***camera offsets (lever arm corrections)***
    camera_offset = [-4.148D,0.25D,3.2D] ;offset for P-3B for 2018, from 20180314 ancillary file
    
    ;lens focal length due to lens adaptor
    focal_length = 0.0286967D ;Arctic 2018 (now *backup* camera)
  end
  
  strcmp(campaign,'Antarctic2018'): begin
    ;offset for archival ANT 2018 (Try26)
    pitch_bias = -0.185D
    roll_bias = 1.297D
    heading_bias = -0.285D
    
    ;***camera offsets (lever arm corrections)***
    camera_offset = [-2.7D,-0.4D,3.95D] ;offset for DC-8 for ANT 2018, from 20181002 ancillary file
    
    ;lens focal length due to lens adaptor
    ;focal_length = 0.0287195  ;Antarctic 2018 quicklook (now *primary* camera)
    focal_length = 0.02859D ;Antarctic 2018 precision
    crop_focal_length = '38.22' ;focal length with crop factor included, for metadata (in mm)
  end
  
  strcmp(campaign,'Arctic2019'): begin
    ; CAMBOT Arctic 2019
    pitch_bias = -4.084D
    roll_bias = -1.07D
    heading_bias = 0.453D

    ;***camera offsets (lever arm corrections)***
    camera_offset = [-4.148D,0.25D,3.2D] ;offset for P-3B for 2019, from 20190327 ancillary file

    ;lens focal length due to lens adaptor
    focal_length = 0.02859D ;Arctic 2019 (primary camera)
    crop_focal_length = '38.22' ;focal length with crop factor included, for metadata (in mm)
  end
  
  strcmp(campaign,'ArcticSummer2019'): begin
    ; CAMBOT Arctic 2019
    pitch_bias = -0.618D
    roll_bias = 0.034D
    heading_bias = -0.438D

    ;***camera offsets (lever arm corrections)***
    camera_offset = [-4.463D,0.092D,2.042D] ;offset for G-V for summer 2019, from 20190819 ancillary file

    ;lens focal length due to lens adaptor
    focal_length = 0.02859D ;Arctic Summer 2019 (primary camera)
    crop_focal_length = '38.22' ;focal length with crop factor included, for metadata (in mm)
  end
  
  strcmp(campaign,'Antarctic2019'): begin
    ; CAMBOT Arctic 2019
    pitch_bias = -0.583D
    roll_bias = -0.017D
    heading_bias = -0.098D

    ;***camera offsets (lever arm corrections)***
    camera_offset = [-4.463D,0.092D,2.042D] ;offset for G-V for Antarctic 2019... not yet assigned

    ;lens focal length due to lens adaptor
    focal_length = 0.02859D ;Antarctic 2019 (primary camera)
    crop_focal_length = '38.22' ;focal length with crop factor included, for metadata (in mm)
  end
  
  else: STOP,'no mounting bias campaign match'
endcase

;===============================================================================

;-------------------------------------------------------------------------------
;                   input camera values and geolocate image
;-------------------------------------------------------------------------------

fov_x = 51.4D
fov_y = 35.5D
sensor_x = 0.02693D ;sensor x dimension in meters
sensor_y = 0.01795D

floc = geolocate_image_seaice_v7p0(img,ac_lat,ac_lon,ac_elev,ac_pitch,ac_roll,ac_azim,focal_length,sensor_x,sensor_y,camera_offset,pitch_bias=pitch_bias,roll_bias=roll_bias,heading_bias=heading_bias,xcorr=xcorr,ycorr=ycorr,verbose=verbose)

img_lat = double(reform(floc.lat))
img_lon = double(reform(floc.lon))
;===============================================================================

;-------------------------------------------------------------------------------
;                   Project pixel lat/lons and grid up 
;-------------------------------------------------------------------------------

;if we are not in the polar regions, the following projection blows up - adjust true scale latitude and center longitude to local points
if abs(img_lat[0]) lt 55 then begin
  Print,'Image not in polar regions, moving projection to local lat/lon combo.'
  geotag.ProjNatOriginLatGeoKey = floor(img_lat[0])
  geotag.ProjStraightVertPoleLongGeoKey = floor(img_lon[0])
endif 

ImgMapProj = MAP_PROJ_INIT('Polar Stereographic', $
  ELLIPSOID=geotag.GeogCitationGeoKey, $
  SEMIMAJOR_AXIS=geotag.GeogSemiMajorAxisGeoKey, $
  SEMIMINOR_AXIS=geotag.GeogSemiMajorAxisGeoKey-(geotag.GeogSemiMajorAxisGeoKey/geotag.GeogInvFlatteningGeoKey),$ ;calculate semi-minor axis from inverse of flattening (1/f)
  TRUE_SCALE_LATITUDE=geotag.ProjNatOriginLatGeoKey, $
  CENTER_LONGITUDE=geotag.ProjStraightVertPoleLongGeoKey, $
  FALSE_EASTING=geotag.ProjFalseEastingGeoKey, $
  FALSE_NORTHING=geotag.ProjFalseNorthingGeoKey)
  
;projected into x&y space
imgxy = map_proj_forward(img_lon,img_lat,map_structure=ImgMapProj)
imgx = reform(imgxy[0,*],xsize,ysize)
imgy = reform(imgxy[1,*],xsize,ysize)

;calculate values used for final gridding
xmin = min(imgx)
xmax = max(imgx)
ymin = min(imgy)
ymax = max(imgy)

;xrange = xmax - xmin + 1
;yrange = ymax - ymin + 1

;adjust x&y ranges to reflect actual distance across "x" & "y" sides, not x & y projected directions (origin bottom left of grid)
dist_top = sqrt( (imgx[0,-1]-imgx[-1,-1])^2 + (imgy[0,-1]-imgy[-1,-1])^2 )
dist_bot = sqrt( (imgx[0,0]-imgx[-1,0])^2 + (imgy[0,0]-imgy[-1,0])^2 )

dist_left = sqrt( (imgx[0,-1]-imgx[0,0])^2 + (imgy[0,-1]-imgy[0,0])^2 )
dist_right = sqrt( (imgx[-1,-1]-imgx[-1,0])^2 + (imgy[-1,-1]-imgy[-1,0])^2 )

TBrange = max([dist_top,dist_bot]) ;select the longest distance, to ensure largest possible grid size required
LRrange = max([dist_left,dist_right])

;manually prescribe grid resolution for testing
;grid_res_x = 1.0 ;resolution of gridded geotiff image for x in meters
;grid_res_y = 1.0 ;resolution of gridded geotiff image for y in meters

;calculate pixel resolution based upon image dimensions on the ground (and poss. add slight gridding buffer)
grid_res_x = TBrange/xsize ;resolution of gridded geotiff image for x in meters
grid_res_y = LRrange/ysize ;resolution of gridded geotiff image for y in meters

;choose the max of the two grids for the final output, to ensure few holes in final grid
;grid_res_sel = max([grid_res_x,grid_res_y]);+0.02
grid_res_x = grid_res_x;+0.02
grid_res_y = grid_res_y;+0.02

;make x & y local and scale them based on resolution, to be used for gridding indices
locx = round((imgx-xmin)/grid_res_x)
locy = round((imgy-ymin)/grid_res_y)

xrange_scaled = max(locx)-min(locx)+1
yrange_scaled = max(locy)-min(locy)+1

if min(locx) lt 0 then STOP
if min(locy) lt 0 then STOP
if max(locx) gt xrange_scaled-1 then STOP
if max(locy) gt yrange_scaled-1 then STOP

if rgb eq 0 then begin

  grid_out = dblarr(xrange_scaled,yrange_scaled)
  grid_cnt = intarr(xrange_scaled,yrange_scaled)

  ;grid the image
  for p = 0,n_elements(locx)-1 do begin
    grid_out[locx[p],locy[p]] = grid_out[locx[p],locy[p]]+img[p]
    grid_cnt[locx[p],locy[p]] = grid_cnt[locx[p],locy[p]]+1
  endfor

  ;average the grid squares where there's been more than one pixel added
  more_than_one = where(grid_cnt gt 1,n_mto)
  if n_mto gt 0 then grid_out[more_than_one] = grid_out[more_than_one]/grid_cnt[more_than_one]
  
  grid_out_int = byte(grid_out)
  
  maxholes = 10 ;number of times to loop through and fill holes
  sz = 1 ;+/- size of averaging to apply for fill
  grid_cnt_adj = grid_cnt
  
  FOR hol=0,maxholes-1 DO BEGIN
  
    ;interpolate away holes in the grid
    holes = bytarr(xrange_scaled,yrange_scaled) ;mask where 1 = holes, 0 = border and image data
  
    holesNborder = where(grid_cnt eq 0 AND grid_out_int eq 0,nholesNborder)
    if nholesNborder eq 0 then goto, noholes
    holes[holesNborder] = 1B ;set holes and border to 1

    ;border = find_image_border_v2p2(grid_cnt,img_check_name=border_check_name) ;return a mask where values of 1 are the border, 0 is image
    border = find_image_border_v2p2(grid_cnt)
    bordersel = where(border eq 1B)
    holes[bordersel] = 0B ;remove border from mask of 1s

    hid = where(holes eq 1B,nholes)
    if nholes eq 0 then goto, noholes

    fillBW = fill_holes_v1p0(grid_out_int,sz,hid,0)
    grid_out_int[hid] = fillBW[hid]
  ENDFOR
  
endif else begin

  grid_outR = dblarr(xrange_scaled,yrange_scaled)
  grid_outG = dblarr(xrange_scaled,yrange_scaled)
  grid_outB = dblarr(xrange_scaled,yrange_scaled)
  grid_cnt = intarr(xrange_scaled,yrange_scaled)

  ;grid the image
  for p = 0,n_elements(locx)-1 do begin
    grid_outR[locx[p],locy[p]] = grid_outR[locx[p],locy[p]]+img[p]
    grid_outG[locx[p],locy[p]] = grid_outG[locx[p],locy[p]]+imgG[p]
    grid_outB[locx[p],locy[p]] = grid_outB[locx[p],locy[p]]+imgB[p]
    grid_cnt[locx[p],locy[p]] = grid_cnt[locx[p],locy[p]]+1
  endfor

  ;average the grid squares where there's been more than one pixel added
  more_than_one = where(grid_cnt gt 1,n_mto)
  if n_mto gt 0 then begin
    grid_outR[more_than_one] = grid_outR[more_than_one]/grid_cnt[more_than_one]
    grid_outG[more_than_one] = grid_outG[more_than_one]/grid_cnt[more_than_one]
    grid_outB[more_than_one] = grid_outB[more_than_one]/grid_cnt[more_than_one]
  endif
  
  grid_out_intR = byte(grid_outR)
  grid_out_intB = byte(grid_outB)
  grid_out_intG = byte(grid_outG)
  
  maxholes = 10 ;number of times to loop through and fill holes
  sz = 1 ;+/- size of averaging to apply for fill 
  grid_cnt_adj = grid_cnt
  
  FOR hol=0,maxholes-1 do begin
  
    ;interpolate away holes in the grid
    holes = bytarr(xrange_scaled,yrange_scaled) ;mask where 1 = holes, 0 = border and image data
    
    holesNborder = where(grid_cnt_adj eq 0 AND grid_out_intR eq 0,nholesNborder)
    if nholesNborder eq 0 then goto, noholes
    holes[holesNborder] = 1B ;set holes and border to 1
    
    ;border = find_image_border_v2p2(grid_cnt,img_check_name=border_check_name) ;return a mask where values of 1 are the border, 0 is image
    border = find_image_border_v2p2(grid_cnt)
    bordersel = where(border eq 1B)
    holes[bordersel] = 0B ;remove border from mask of 1s
    
    hid = where(holes eq 1B,nholes)
    if nholes eq 0 then goto, noholes
    
    fillR = fill_holes_v1p0(grid_out_intR,sz,hid,0)
    fillG = fill_holes_v1p0(grid_out_intG,sz,hid,0)
    fillB = fill_holes_v1p0(grid_out_intB,sz,hid,0)
    
    grid_out_intR[hid] = fillR[hid]
    grid_out_intG[hid] = fillG[hid]
    grid_out_intB[hid] = fillB[hid]
  
  ENDFOR
  
  
endelse
noholes:
;====================================================================================


;------------------------------------------------------------------------------------
;                             prepare GeoTIFF metadata
;------------------------------------------------------------------------------------
;caluclate upper left corner of image (based upon actual projected x&y coords)
ulx = xmin
uly = ymax;-yrange

;update geotiff tags based upon original DMS metadata pulled from example file
geo_info_new = geotag

geo_ul_coords = geo_info_new.modeltiepointtag
geo_ul_coords[3] = ulx ;x_ul_mod
geo_ul_coords[4] = uly ;y_ul_mod
geo_info_new.modeltiepointtag = geo_ul_coords

geo_pixelsize = geo_info_new.modelpixelscaletag
geo_pixelsize[0] = grid_res_x
geo_pixelsize[1] = grid_res_y
geo_info_new.modelpixelscaletag = geo_pixelsize
;====================================================================================

;------------------------------------------------------------------------------------
;             prep final gridded data for writing to GeoTIFF and write
;------------------------------------------------------------------------------------

if rgb eq 0 then begin
  grid_out_int = reverse(grid_out_int, 2) ;reverse the gridded image here, to put it into correct top-to-bottom orientation for tiffs

  ;write_tiff, work_dir+'output'+sl+'geo_rx' + resize_factor_label + '_res1m_' + label + label_ver + '.tif', grid_out_int, geotiff = geo_info_new ;, /float
  ;write_tiff, out_dir+label+'_geo_rx' + resize_factor_label + '_res'+strcompress(grid_res_x,/remove_all) + 'm_ver' + label_ver + '_bw.tif', grid_out_int, geotiff = geo_info_new
  write_tiff, out_file, grid_out_int, geotiff = geo_info_new,compression=1
endif else begin

  grid_out_intR = reverse(grid_out_intR, 2)
  grid_out_intG = reverse(grid_out_intG, 2)
  grid_out_intB = reverse(grid_out_intB, 2)

  grid_out_int_rgb = bytarr(3,xrange_scaled,yrange_scaled)
  grid_out_int_rgb[0,*,*] = grid_out_intR
  grid_out_int_rgb[1,*,*] = grid_out_intG
  grid_out_int_rgb[2,*,*] = grid_out_intB

  ;write_tiff, out_dir+label+'_geo_rx' + resize_factor_label + '_res'+strcompress(grid_res_x,/remove_all) + 'm_ver' + label_ver + '_rgb.tif', grid_out_int_rgb, geotiff = geo_info_new
  write_tiff,out_file, grid_out_int_rgb, geotiff = geo_info_new,compression=1
endelse

result=1 ;regardless of metadata update, we have written an image, so call it successful
;====================================================================================

;------------------------------------------------------------------------------------
;                write additional camera metadata to GeoTIFF file
;------------------------------------------------------------------------------------
if n_elements(metadata) le 1 AND strlen(metadata[0]) eq 0 then goto,skip_image ;only update metadata if we have it

this_jpg = file_basename(file_in_full)
sel_meta = where(strcmp(metadata[0,*],this_jpg) eq 1,nsel_meta)
if nsel_meta ne 1 then STOP
this_metadata = metadata[1,sel_meta]

;update metadata entry for this image for campaign specific focal lengths
meta_dash = strsplit(this_metadata,'-',/extract)

focal_length_out = strmid(strcompress(focal_length*1000.0,/remove_all),0,5)
fl35mm = strpos(meta_dash,'FocalLengthIn35mmFormat')
sel_35mm = where(fl35mm ne -1,nsel_35mm)
if nsel_35mm ne 1 then STOP
meta_dash[sel_35mm] = 'FocalLengthIn35mmFormat="'+focal_length_out+' mm" '

flcrop = strpos(meta_dash,'FocalLength=')
sel_crop = where(flcrop ne -1,nsel_crop)
if nsel_crop ne 1 then STOP
meta_dash[sel_crop] = 'FocalLength="'+crop_focal_length+' mm" '

this_metadata2 = ''
for m=0,n_elements(meta_dash)-1 do if strlen(meta_dash[m]) gt 2 then this_metadata2 = this_metadata2+'-'+meta_dash[m]
this_metadata = this_metadata2

if strcmp(path_sep(),'\') eq 1 then begin
  spawn,'exiftool -P -overwrite_original '+this_metadata+' '+out_file,/hide
endif else begin
  spawn,'exiftool -P -overwrite_original '+this_metadata+' '+out_file
endelse
;====================================================================================

skip_image:

;write filler file due to image being skipped
if skip_flag eq 1 then begin
  openw,lun,out_file_missing,/get_lun
  printf,lun,skip_reason
  free_lun,lun
endif

return,result

END