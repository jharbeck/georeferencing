function geolocate_image_landice_v7p1,image_data,lat_in,lon_in,alt_in,pitch_in,roll_in,heading_in,focal_length,sensor_x,sensor_y,camera_offset,ground_elevations,pitch_bias=pitch_bias,roll_bias=roll_bias,heading_bias=heading_bias,xcorr=xcorr,ycorr=ycorr,verbose=verbose


;This program gets the latitude and longitude for each pixel in the FLIR imagery

;Version 1p0, 02/04/2016 first version of the code
;Version 2p0, 02/23/2016 added in lens distortion correction capability
;Version 3p0, 05/22/2016 fixed error with camera pointing vector not extending to the surface for non-zero pitch and roll, mounting biases now
;                         taken into account properly through a coordinate transformation
;Version 3p2, 02/17/2017 fixed error in total path length and angle calculation
;Version 4p0, 10/17/2017 fixed error in aircraft pointing and mounting bias matrix multiplication order, added in function to calculate
;                         ECEF to lat/lon/altitude conversion which fixes a previous error in altitude determination
;Version 4p1, 10/25/2017 fixed error in determination of the angular component of each image pixel, previous version assumed linear relationship
;                         between nadir and FOV, new version assumes image pixels have a uniform size for a flat undistorted image
;Version 5p0, 07/17/2018 Switched from flat plane trigonometry to a projection camera model, needed to make the code applicable for larger pitch and roll values
;Version 5p3 07/20/2018 Switched from flat plane trigonometry to a projection camera model, needed to make the code applicable for larger pitch and roll values, fixed many errors from 5p0
;Version 5p4 9/25/2018 added in elevation support for over land (ground_elevations)
;Version 5p5beta, 8/12/2019 working to get elevation iterations as fast as possible
;Version 5p5_landice, importing DEM data and running elevation iterations in this function directly
;Version 5p5p1_landice, updating to do bilinear interpolatin with elevations. Fixed elevation/altitude issue??
;Version 5p5p2_landice, adding in corner points first, to narrow down DEM we search
;Version 5p5p3_landice, working on shrinking issues for testing
;Version 5p5p4_landice, working on moving things from FOR loops to array processes for speed
;Version 5p5p5_landice, previous version works, but starting new version for improving efficiency
;Version 5p5p6_landice, update initialization of elev in final loop to elevations interpolated from corner point section
;Version 5p5p7_landice, update to generate local subsets of the DEM grid, after it's shrunk using corner points
;Version 5p5p8_landice, adding in todo variable change detection to adjust local_size variable. Added variable distance to DEM gripoint based upon local elevations. Fixed DEM_y subset error.
;Version 5p5p9_landice, removed elevation weighted DEM distance - it introduced too many holes in the grid. The final grid is afterall an x-y plane. Added improved initial elevation guess from
;                          interpolated x-y corner points and DEM.
;Version 5p5p10_landice, added verbose keyword 
;Version 5p5p11_landice, was having issues with last version where the initial x/y/z solutions were 90 degrees off and it was also running a bit slow. Making upgrades on how we do DEM elevation
;                         initializations and matches
;Version 5p5p12_landice, fixed an issue with epsilon_alt in corner_points portion of code was not absolute value when compared to threshold
;Version landice_v6p0,   Cleaned up script now that it's working all the way. 
;Version landice_v6p1,   added missing DEM filter and support for skipping files
;Version landice_v6p2,   changing ground_elevations keyword to required input
;Version landice_v7p0,   updated to double precision where necessary
;Version landice_v7p1,   track how missing DEM data is first found


;****************Input*************
gps_lat = lat_in  ;geodetic latitude of gps antenna in degrees
gps_lon = lon_in  ;geodetic longitude of gps antenna in degrees
gps_alt = alt_in  ;altitude (above ground) of gps antenna in meters
p = pitch_in  ;pitch of airplane in degrees
r = roll_in ;roll of airplane in degrees
h = heading_in  ;heading of airplane in degrees

;fov_y = 22.0D*2 ; ;45.627 originally   ;Full angle field of view (degrees)
;fov_x = 33.0D*2 ; 66.0 original    ;field of view (degrees) ;old fov: 23.962*2
;focal_length = 28e-3  ;lens focal length
;**********************************

;sensor_x = 2.0*focal_length*tan(fov_x/2.0*!pi/180)  ;physical size of the camera sensor derived from the effective field of view and focal length, can be used if field of view is known but sensor size is not
;sensor_y = 2.0*focal_length*tan(fov_y/2.0*!pi/180)

;************Keywords**************
if n_elements(pitch_bias) eq 0 then pitch_bias = 0.0D
if n_elements(roll_bias) eq 0 then roll_bias = 0.0D
if n_elements(heading_bias) eq 0 then heading_bias = 0.0D
if n_elements(verbose) eq 0 then verbose = 0
;**********************************

;reassign ground_elevations to variable "dem"
dem = ground_elevations

if verbose ge 1 then print,'Starting land ice geolocation code'
start_geolocation_time = systime(/seconds)

;************Constants*************
f = 1/298.257223563D  ;flattening term from WGS84 definition
er = 6378137.0D ;Earth equatorial radius in meters
el = 0.0818191908426215D  ;WGS84 constant
;**********************************


;***Convert all variables to radians***
gps_lat = gps_lat*!dpi/180.0D
gps_lon = gps_lon*!dpi/180.0D
p = 1.0D*p*!dpi/180.0D
r = 1.0D*r*!dpi/180.0D
h = h*!dpi/180.0D
pitch_bias = 1.0D*pitch_bias*!dpi/180.0D
roll_bias = 1.0D*roll_bias*!dpi/180.0D
heading_bias = heading_bias*!dpi/180.0D
;**************************************

;***********Convert gps lat/lon to Earth-Centered Earth-Fixed (ECEF) coordinates*************
glat = atan( (1.0-f)^2.0 * tan(gps_lat)) ;geocentric latitude at mean sea-level
rs = sqrt( er^2 / (1+(1.0/(1-f)^2 - 1.0)*(sin(glat))^2)  )  ;radius at surface point
p_ecef = dblarr(3)
p_ecef[0] = rs*cos(glat)*cos(gps_lon) + gps_alt*cos(gps_lat)*cos(gps_lon)  ;x coordinate
p_ecef[1] = rs*cos(glat)*sin(gps_lon) + gps_alt*cos(gps_lat)*sin(gps_lon)  ;y coordinate
p_ecef[2] =              rs*sin(glat) + gps_alt*sin(gps_lat) ;z coordinate
;********************************************************************************************


;**********Get coordinate rotation matrix to align camera coordinate system with aircraft coordinate system with the x-axis in the direction of North*************
cp = cos(p)
sp = sin(p)
cr = cos(r)
sr = sin(r)
ch = cos(h)
sh = sin(h)

T = [ [  ch*cp, ch*sp*sr-sh*cr, ch*sp*cr+sh*sr],$ ;The T(heading,pitch,roll) rotation aligns the camera’s coordinate system with the aircraft coordinate system, with the x-axis in the direction of the north
      [  sh*cp, sh*sp*sr+ch*cr, sh*sp*cr-ch*sr],$
      [-1.0*sp,          cp*sr,          cp*cr] ]

st = sin(gps_lat)
ct = cos(gps_lat)
sl = sin(gps_lon)
cl = cos(gps_lon)


NED_R = [ [-1.0*st*cl, -1.0*sl, -1.0*ct*cl],$ ;R(theta,lambda) rotation transforms the camera location direction vector to ECEF geocentric coordinates
          [-1.0*st*sl,      cl, -1.0*ct*sl],$
          [        ct,     0.0,    -1.0*st] ]

camera_ecef = NED_R ## T ## camera_offset + p_ecef  ;camera position in ECEF

;******************************************************************************************************************************************************************


;*****************Get camera position in lat, lon, altitude*********************
llh = ecef2geodetic_array(camera_ecef[0],camera_ecef[1],camera_ecef[2])
camera_lat = llh[0]
camera_lon = llh[1]
camera_alt = llh[2]

;print,'Camera lat, lon, alt: ', camera_lat*180.0/!pi,camera_lon*180.0/!pi,camera_alt
;print,'Distance between gps and camera points (meters): ',winkel(gps_lat*180.0/!pi,gps_lon*180.0/!pi,camera_lat*180.0/!pi,camera_lon*180.0/!pi)*1000.0

;**********************************************************************************

img_len = n_elements(image_data)
img_size = size(image_data)
img_cols = img_size[1]
img_rows = img_size[2]
center_x = double(img_cols/2)
center_y = double(img_rows/2)

camera_r_vec = dblarr(3)  ;camera pointing vector in NED coordinates, column 1 is north, column 2 is east, column 3 is down

st = sin(camera_lat)
ct = cos(camera_lat)
sl = sin(camera_lon)
cl = cos(camera_lon)


NED_R_camera =  [ [-1.0*st*cl, -1.0*sl, -1.0*ct*cl, 0.0],$ ;rotation matrix to transform from North-East-Down coordinate system (NED) to ECEF
                  [-1.0*st*sl,      cl, -1.0*ct*sl, 0.0],$
                  [        ct,     0.0,    -1.0*st, 0.0],$
                  [       0.0,     0.0,        0.0, 1.0] ]



;**********Get coordinate rotation matrix to align camera coordinate system with aircraft coordinate system with the x-axis in the direction of North for camera with mounting bias*************
 
cp = cos(-1.0D*p)	;negative signs needed to compensate for coordinate system change in image plane
sp = sin(-1.0D*p)
cr = cos(-1.0D*r)
sr = sin(-1.0D*r)
ch = cos(h)
sh = sin(h)   


T = [ [           ch*cp,          cp*sh, -1.0*sp, 0.0],$ ;The T(heading,pitch,roll) rotation aligns the camera coordinate system with the aircraft coordinate system, with the x-axis in the direction of the north, from Barber and Redding, 2006 eqn 3 (transpose of Euler rotation matrix)
      [sr*sp*ch - cr*sh, sh*sp*sr+ch*cr,   sr*cp, 0.0],$
      [cr*sp*ch + sr*sh, cr*sp*sh-sr*ch,   cr*cp, 0.0],$
      [             0.0,            0.0,     0.0, 1.0] ]
      

cp = cos(-1.0D*pitch_bias)	;negative signs needed to compensate for coordinate system change in image plane
sp = sin(-1.0D*pitch_bias)
cr = cos(-1.0D*roll_bias)
sr = sin(-1.0D*roll_bias)
ch = cos(heading_bias)
sh = sin(heading_bias)
     

T_mounting = [ [           ch*cp,          cp*sh, -1.0*sp, 0.0],$ ;Aligns the camera coordinate system with the aircraft coordinate system, accounts for mounting bias of the instrument
               [sr*sp*ch - cr*sh, sh*sp*sr+ch*cr,   sr*cp, 0.0],$
               [cr*sp*ch + sr*sh, cr*sp*sh-sr*ch,   cr*cp, 0.0],$
               [             0.0,            0.0,     0.0, 1.0] ]
     
  
;==============================================================================================================

;--------------------------------------------------------------------------------------------------------------
;                   Geolocate corner points first, in order to reduce the DEM size we search through
;--------------------------------------------------------------------------------------------------------------
if verbose ge 2 then print,'Starting corner points georeferencing'

img_lat_corners = image_data*0.0D
img_lon_corners = image_data*0.0D
img_elev_corners = image_data*0.0D
try_count_recorder_corners = replicate(-1,img_cols,img_rows)

;initialize flag for missing DEM data. For use on corners as well as local subset sections.
missing_dem_data = 0
missing_dem_reason = ''

;calculate min values for main DEM grid subset, for use in converting corner point locations to main DEM subset gridspace
mainDEM_min_x = long(min(dem.x_grid))
mainDEM_min_y = long(min(dem.y_grid))
  
FOR ii=0L,img_cols-1L,img_cols-1L DO BEGIN
  FOR jj=0L,img_rows-1L,img_rows-1L DO BEGIN
  
    IF n_elements(xcorr) EQ 0 THEN BEGIN  ;no lens distortion
      ;get pixel distance from the center point
      yp_dist = jj - center_y*2.0 ;center_y - jj ;y distance of pixel
      xp_dist = ii -  center_x*2.0 ;center_x - ii ;x distance of pixel
    ENDIF ELSE BEGIN  ;else correct for lens distortion
      ;get pixel distance from the center point with lens distortion, xcorr and ycorr are the apparent pixel locations due to distortion
      yp_dist = ycorr[ii,jj] - center_y*2.0 ;y distance of pixel
      xp_dist = xcorr[ii,jj] - center_x*2.0 ;x distance of pixel
    ENDELSE

    sx = 1.0*sensor_x/img_cols/2.0 ;conversion factor from pixels to meters with units of meters/pixel, see eqn. 6 of Barber and Redding
    sy = 1.0*sensor_y/img_rows/2.0 ;conversion factor from pixels to meters, I think factor of 2 needs to be in since it is from the middle of the sensor

    cx = xp_dist
    cy = yp_dist

    Cam = [ [                0.0, -1.0*focal_length/sx, -1.0*cx[0], 0.0],$    ;-1 sign change only from Barber and Redding et al., 2006 eqn 7
            [1.0*focal_length/sy,                    0, -1.0*cy[0], 0.0],$
            [                0.0,                    0,        1.0, 0.0],$
            [                0.0,                    0,        0.0, 1.0] ]

    q=dblarr(4) ;pixel vector
    q[0] = 1.0*ii
    q[1] = 1.0*jj
    q[2] = 1.0
    q[3] = 1.0
   
    ;doing this to put camera North and east coords as 0 and only keep altitude, the right hand column vector is the x,y,z position of the camera, equivalent to T_i_v transformation in Barber and Redding, 2006
    sensor_m = [  [1, 0, 0,               0],$    
                  [0, 1, 0,               0],$
                  [0, 0, 1, -1.0*camera_alt],$
                  [0, 0, 0,               1]]
                  
    q_I_obj = invert(Cam ## T_mounting ## T ## sensor_m) ## q   ;find the vector to the surface
    ;allq_I_obj = dblarr(4,img_len)
    ;for j=0,img_len-1 do allq_I_obj[*,j] = invert(allcam[*,*,j] ## T_mounting ## T ## sensor_m) ## allq[*,j]
    
    z_I_obj = q_I_obj[2] ;Used when using only NED coordinates
    ;allz_I_obj = allq_I_obj[2,*]
    p_I_cc = [0.0, 0.0, camera_alt, 1] ;temp for now to be north, east, and down    
   
    try_count = 0
    Z_I_cc = p_I_cc[2]
    
    ;this is where we apply local pixel-by-pixel elevations
    good_DEM_elev = where(dem.elev gt -9999.0,complement=bad_DEM_elev) 
    elev = median(dem.elev[good_DEM_elev]) ;assign median elevation starting point for corners
    ;dxy = dem.res*0.5*sqrt(2)
    max_reps = 20L
    epsilon_alt = 0.5D ;change in elevation less than which we break out of the while loop

    ;loop starts here for honing down on the xyz coords
    FOR reps=0, max_reps DO BEGIN
      scale_factor =  ( elev - Z_I_cc) / (Z_I_obj - Z_I_cc)  ; = lambda, or distance along camera's optical axis to object in image used to scale the vector to get to the surface

      p_I_obj = p_I_cc[0:3] + scale_factor*( q_I_obj[0:3] - p_I_cc[0:3])
      p_I_obj[2] = camera_alt - elev  ;need to do this since p_I_obj z component is initially zero

      p_I_obj_ecef = NED_R_camera ## p_I_obj + camera_ecef  ;put the vector to the surface in ECEF coordinates and add to the camera position to get the final pixel position in ECEF coordinates

      llh = ecef2geodetic_array(p_I_obj_ecef[0],p_I_obj_ecef[1],p_I_obj_ecef[2])  ;convert from ECEF to lat/lon/altitude

      temp_lat = llh[0]*180.0D / !dpi
      temp_lon = llh[1]*180.0D / !dpi
      temp_elev = llh[2]

      ;convert temp lat/lon into dem coords
      pxl_xy = map_proj_forward(temp_lon,temp_lat,map_structure=dem.demmapproj)
      
      ;convert temp x/y into adj DEM grid coords
      pxl_x_adj = long((pxl_xy[0]-mainDEM_min_x)/dem.res+0.5)
      pxl_y_adj = long((pxl_xy[1]-mainDEM_min_y)/dem.res+0.5)

      ;find difference between elevation at this DEM grid and the calculated elevation from above 
      this_DEM_elev = dem.elev[pxl_x_adj,pxl_y_adj]
      if this_DEM_elev eq -9999.0 then begin  ;ensure we are not getting missing DEM data for a corner
        missing_dem_data = 1
        missing_dem_reason = 'missing data found at corner ii:'+strcompress(ii)+', jj:'+strcompress(jj)+', rep:'+strcompress(reps)+'. '
        goto,missing_dem_section
      endif
      elev_diff = this_DEM_elev-temp_elev  ;(DEM - calculated)

      ;save the point regardless of having reached our distance threshold, so we at least have something
      img_lat_corners[ii,jj] = llh[0]*180.0D / !dpi  ;get in degrees
      img_lon_corners[ii,jj] = llh[1]*180.0D / !dpi  ;get in degrees
      img_elev_corners[ii,jj] = temp_elev ;record the elevation, for the next step
      try_count_recorder_corners[ii,jj] = reps+1

      IF abs(elev_diff) LT epsilon_alt THEN BEGIN
        ;if we are close enough to the DEM elevation we are searching for, quit searching
        BREAK 
      ENDIF ELSE BEGIN
        ;if we are not close enough to the DEM elevation we're searching for, adjust the search elevation and try again
        elev = elev + (elev_diff/2.0)
      ENDELSE
      
    ENDFOR ;end FOR loop, honing in on each corner elevation
  ENDFOR ;end jj loop
ENDFOR ;end ii loop

;remove extraneous DEM points to a LOCAL subset, around the image
gcor = where(img_lat_corners ne 0.0,ngood)
img_xy_corners = map_proj_forward(img_lon_corners[gcor],img_lat_corners[gcor],map_struct=dem.demmapproj)
local_min_x = min(img_xy_corners[0,*])-(dem.res)
local_max_x = max(img_xy_corners[0,*])+(dem.res)
local_min_y = min(img_xy_corners[1,*])-(dem.res)
local_max_y = max(img_xy_corners[1,*])+(dem.res)

local_x_sel_start = floor((local_min_x-dem.x_axis[0])/dem.res)-10 & if local_x_sel_start lt 0 then STOP ;x_sel_start = 0
local_x_sel_end = ceil((local_max_x-dem.x_axis[0])/dem.res)+10 & if local_x_sel_end gt n_elements(dem.x_axis)-1 then STOP ;x_sel_end = n_elements(dem.x_axis)-1
local_y_sel_start = floor((local_min_y-dem.y_axis[0])/dem.res)-10 & if local_y_sel_start lt 0 then STOP ;y_sel_start = 0
local_y_sel_end = ceil((local_max_y-dem.y_axis[0])/dem.res)+10 & if local_y_sel_end gt n_elements(dem.y_axis)-1 then STOP ;y_sel_end = n_elements(dem.y_axis)-1

localDEM_x = dem.x_grid[local_x_sel_start:local_x_sel_end,local_y_sel_start:local_y_sel_end]
localDEM_y = dem.y_grid[local_x_sel_start:local_x_sel_end,local_y_sel_start:local_y_sel_end]
localDEM_elev = dem.elev[local_x_sel_start:local_x_sel_end,local_y_sel_start:local_y_sel_end]
localDEM_size = size(localDEM_elev,/dim)

;check the local DEM grid for missing data

if min(localDEM_elev) eq -9999.0 then begin  ;ensure we are not getting missing DEM data for a corner
  missing_dem_data = 2
  missing_dem_reason = 'Missing data remaining in local DEM. Max of local DEM: '+strcompress(max(localDEM_elev))+'. '
  goto,missing_dem_section
endif  
  
;check plots
goto,skip_checkplots_corners
  good = where(img_lat_corners ne 0.0,ngood)
  img_xy_cor = map_proj_forward(img_lon_corners[good],img_lat_corners[good],map_struct=dem.demmapproj)
  dem_grid_plot = plot(dem.x_grid,dem.y_grid,' +r',sym_size=0.4,dim=[1000,1000]) ;plots up entire DEM grid we have here
  xy_corner_plot = plot(img_xy_cor[0,*],img_xy_cor[1,*],' ob',sym_size=0.5,sym_filled=1,/current,/overplot) ;plots up corners that we just calculated
  ;input_plot = plot(reform(input_xy[0],1,1),reform(input_xy[1],1,1),' +b',sym_thick=2.0,/current,/overplot)
  localDEM_plot = plot(localDEM_x,localDEM_y,' +g',sym_size=0.4,/current,/overplot) ;plots up current
skip_checkplots_corners:

;look at DEM gridpoint distances with elevation
;DEM_diff_3d_x = sqrt((DEM_x[0:-2,0:-2]-DEM_x[1:-1,0:-2])^2 + (DEM_y[0:-2,0:-2]-DEM_y[1:-1,0:-2])^2 + (DEM_elev[0:-2,0:-2]-DEM_elev[1:-1,0:-2])^2)
;DEM_diff_3d_y = sqrt((DEM_x[0:-2,0:-2]-DEM_x[0:-2,1:-1])^2 + (DEM_y[0:-2,0:-2]-DEM_y[0:-2,1:-1])^2 + (DEM_elev[0:-2,0:-2]-DEM_elev[0:-2,1:-1])^2)
;DEM_diff_3d = congrid(max([[[DEM_diff_3d_x]],[[DEM_diff_3d_y]]],dimension=3),x_sel_end-x_sel_start+1,y_sel_end-y_sel_start+1)


;generate initial elevation field from geolocated corner points above
corners_elev_pre = [img_elev_corners[0,0],img_elev_corners[-1,0],img_elev_corners[0,-1],img_elev_corners[-1,-1]]
corners_lat = [img_lat_corners[0,0],img_lat_corners[-1,0],img_lat_corners[0,-1],img_lat_corners[-1,-1]]
corners_lon = [img_lon_corners[0,0],img_lon_corners[-1,0],img_lon_corners[0,-1],img_lon_corners[-1,-1]]
img_xy_cor = map_proj_forward(corners_lon,corners_lat,map_struct=dem.demmapproj)
corners_x = [[img_xy_cor[0,0],img_xy_cor[0,1]],[img_xy_cor[0,2],img_xy_cor[0,3]]]
corners_y = [[img_xy_cor[1,0],img_xy_cor[1,1]],[img_xy_cor[1,2],img_xy_cor[1,3]]]
corners_elev = [[corners_elev_pre[0],corners_elev_pre[1]],[corners_elev_pre[2],corners_elev_pre[3]]]

x_ind_norm = rebin(findgen(img_cols),img_cols,img_rows)/img_cols ;generates normalized (0->1) indices for even spacing of x vectors to interpolate corner points to
y_ind_norm = transpose(rebin(findgen(img_rows),img_rows,img_cols))/img_rows ;same thing for y as above line
elev_from_corners = bilinear(corners_elev,x_ind_norm,y_ind_norm) ;generates flat, interpolated elev field from corner points
x_from_corners = bilinear(corners_x,x_ind_norm,y_ind_norm) ;same as above, but for x&y 
y_from_corners = bilinear(corners_y,x_ind_norm,y_ind_norm)

;plot things up, to ensure interpolations were accurate
;plot0 = plot(corners_lon,corners_lat,' +b',dim=[800,800])
;plot1 = plot(x_from_corners,y_from_corners,' .r',dim=[800,800])


;adjust DEM xy grid, down to DEM index coordinates
localDEM_x_min = min(localDEM_x)
localDEM_y_min = min(localDEM_y)

;generate indices to pull elevations from DEM grid, to initialize elevation field below 
x_from_corners_localDEMspace = long((x_from_corners-localDEM_x_min)/dem.res)
y_from_corners_localDEMspace = long((y_from_corners-localDEM_y_min)/dem.res)
elev_init_from_DEM = localDEM_elev[x_from_corners_localDEMspace,y_from_corners_localDEMspace]

if verbose ge 2 then print,'Adjusted DEM subset size to image data & initialized elevations'
;STOP
;==============================================================================================================

;-------------------------------------------------------------------------------------------------------------- 
;                                    Geolocate individual camera pixels
;--------------------------------------------------------------------------------------------------------------

;start point for timing georeferencing all pixels
pixel_start = systime(/seconds) 

;setup iterative thresholds  
max_reps_pixel = 20L ;maximum number of iterations that we will allow the code to perform before quitting
epsilon_alt_pixel = 0.5 ;change in elevation less than which we stop updating this pixel
dxdy_thresh = dem.res*0.05

allimg_lat = image_data*0.0D
allimg_lon = image_data*0.0D
allimg_x = image_data*0.0D
allimg_y = image_data*0.0D
allimg_dx = replicate(99999999.0D,img_len) ;choose 99,999,999 for dx missing value, as this is more meters than halfway around the globe
allimg_dy = replicate(99999999.0D,img_len)
allimg_tot_path_length = image_data*0.0D
allimg_tot_path_angle = image_data*0.0D
allimg_elev = elev_init_from_DEM ;current elevation, gotten from GPS solution, previous iteration, or assigned during initilization
allimg_elev_diff = replicate(99999.0D,img_len) ;difference between the elevation found during this iteration and the DEM point at the same xy location 
allimg_dist = replicate(-99999.0D,img_len) ;distance between solution elevation and gridded DEM elevation when iteration quit 
;allimg_DEM_dist = replicate(-99999.0,img_len) ;maximum distance from closest DEM gridpoint to the next DEM gridpoint, with elevation taken into account.
try_count_recorder = replicate(-1,img_cols,img_rows) ;record how many iterations it takes for each pixel to converge on an elevation
point_found = intarr(img_cols,img_rows) ;binary flag that indicates whether this pixel's location has been successfully found


;***camera pointing vector is in NED coordinates, need to transform to ECEF then add to camera position to get pixel location***
;build arrays of distances
allyp_dist = ycorr - center_y*2.0
allxp_dist = xcorr - center_x*2.0

;****************************************************

sx = 1.0D*sensor_x/img_cols/2.0 ;conversion factor from pixels to meters with units of meters/pixel, see eqn. 6 of Barber and Redding
sy = 1.0D*sensor_y/img_rows/2.0 ;conversion factor from pixels to meters, I think factor of 2 needs to be in since it is from the middle of the sensor

allcx = allxp_dist
allcy = allyp_dist
  
;build array for every pixel, 
allcam = dblarr(4,4,img_len)
allcam[1,0,*] = replicate(-1.0D*focal_length/sx,img_len) ;-1 sign change only from Barber and Redding et al., 2006 eqn 7
allcam[2,0,*] = -1.0D*allcx
allcam[0,1,*] = replicate(1.0D*focal_length/sy,img_len)
allcam[2,1,*] = -1.0D*allcy
allcam[2,2,*] = 1.0D
allcam[3,3,*] = 1.0D

;build an array of pixel vectors
allq = dblarr(4,img_len)
colrow = array_indices(allimg_lat,lindgen(img_len))
allq[0,*] = colrow[0,*]
allq[1,*] = colrow[1,*]
allq[2,*] = 1.0D
allq[3,*] = 1.0D
    
            
;doing this to put camera North and east coords as 0 and only keep altitude, the right hand column vector is 
;  the x,y,z position of the camera, equivalent to T_i_v transformation in Barber and Redding, 2006
sensor_m = [ [1.0, 0.0, 0.0,             0.0],$    
             [0.0, 1.0, 0.0,             0.0],$
             [0.0, 0.0, 1.0, -1.0*camera_alt],$
             [0.0, 0.0, 0.0,             1.0] ]
  
  
;find the vector to the surface
allq_I_obj = dblarr(4,img_len)
FOR j=0,img_len-1 DO allq_I_obj[*,j] = invert(allcam[*,*,j] ## T_mounting ## T ## sensor_m) ## allq[*,j]

;Used when using only NED coordinates
allz_I_obj = allq_I_obj[2,*] 
  
p_I_cc = [0.0, 0.0, camera_alt, 1.0] ;temp for now to be north, east, and down
 
;setup initial variables to have all points processed the first run through
ntodo = img_len
todo = lindgen(ntodo)
prev_ntodo = -999
  
if verbose ge 2 then print,'Starting iterative DEM/elevation matching'   

FOR try_count=0,max_reps_pixel DO BEGIN
   
  Z_I_cc = p_I_cc[2]
  
  ;This calculates lambda, or distance along camera's optical axis to object in image used to scale the vector to get to the surface
  allscale_factor = reform((allimg_elev - Z_I_cc) / (allz_I_obj - z_I_cc),1,img_len)
  allp_i_obj = rebin(p_I_cc,4,img_len) + rebin(allscale_factor,4,img_len)*(allq_I_obj - rebin(p_I_cc,4,img_len))
  
  ;need to do this since p_I_obj z component is initially zero
  allp_I_obj[2,*] = camera_alt-reform(allimg_elev,1,img_len)

  ;put the vector to the surface in ECEF coordinates and add to the camera position to get the final pixel position in ECEF coordinates
  allp_I_obj_ecef = dblarr(img_len,3)
  for j2=0,ntodo-1 do allp_I_obj_ecef[todo[j2],*] = NED_R_camera ## allp_I_obj[*,todo[j2]] +camera_ecef

  allllh = ecef2geodetic_array(allp_I_obj_ecef[*,0],allp_I_obj_ecef[*,1],allp_I_obj_ecef[*,2])  ;convert from ECEF to lat/lon/altitude
  
  ;convert temp lat/lon from radians into degrees
  temp_lat = allllh[todo,0]*180.0D / !dpi
  temp_lon = allllh[todo,1]*180.0D / !dpi
  temp_elev = allllh[todo,2]
 
  ;so now we have this iteration georeferenced, update the grids with the new data in the appropriate places
  allimg_lat[todo] = temp_lat
  allimg_lon[todo] = temp_lon
  allimg_elev[todo] = temp_elev ;even though we prescribed an elevation at the start of this step to calculate a new lat/lon, use the calculated elevation as the final one, so we are sure it's along the path vector
  allimg_tot_path_length[todo] = sqrt(allp_I_obj[0,todo]^2+allp_I_obj[1,todo]^2+allp_I_obj[2,todo]^2)
  allimg_tot_path_angle[todo] = reform(acos((camera_alt-allimg_elev[todo])/allimg_tot_path_length[todo]))
  try_count_recorder[todo] = try_count

  ;-----------------------------------------------------------------------
  ;Now, find how many of the "todo" points we still have to work on
  ;-----------------------------------------------------------------------
  
  ;convert temp lat/lon into local DEM coords and update their values in final xy arrays
  todo_xy = map_proj_forward(temp_lon,temp_lat,map_structure=dem.demmapproj)
  allimg_dx[todo] = abs(allimg_x[todo]-todo_xy[0,*]) ;record differences in dy & dy here from previous solution
  allimg_dy[todo] = abs(allimg_y[todo]-todo_xy[1,*])
  allimg_x[todo] = todo_xy[0,*]
  allimg_y[todo] = todo_xy[1,*]
  
  ;convert temp "todo" xy into adj DEM grid coords to retrieve the DEM elevations from these new x,y locations
  localDEM_x_todo = long((todo_xy[0,*] - localDEM_x_min)/dem.res+0.5) ;add 0.5 in to account for rounding that happen in float->long conversion
  localDEM_y_todo = long((todo_xy[1,*] - localDEM_y_min)/dem.res+0.5)
  
  ;update elevation difference variable
  allimg_elev_diff[todo] = localDEM_elev[localDEM_x_todo,localDEM_y_todo] - temp_elev
  
  ;find if we have any remaining points to adjust and where they are
  prev_ntodo = ntodo
  done_elev = where(abs(allimg_elev_diff) GT epsilon_alt_pixel,ndone_elev,complement=todo_elev)
  done_xy = where(abs(allimg_dx) LT dxdy_thresh AND abs(allimg_dy) LT dxdy_thresh,ndone_xy,complement=todo_xy)
  if ndone_elev gt 0 AND try_count GT 1 then point_found[done_elev] = 1L
  if ndone_xy gt 0 AND try_count GT 1 then point_found[done_xy] = 1L
  todo = where(point_found EQ 0,ntodo)
  
  if ntodo eq 0 then BREAK ;if we're done, then we're done!
  
  allimg_elev[todo] = allimg_elev[todo] + (allimg_elev_diff[todo]*0.25D)
 
  goto,skipplot3
    demplot = plot(DEM_x,DEM_y,' +r',sym_size=0.4,dim=[800,1000]) ;plot up dem gridpoints we are working with
    todoplot = plot(todo_xy[0,*],todo_xy[1,*],' .m',/current,/overplot) ;plot up the current "todo" points
    done_xy = map_proj_forward(allimg_lon,allimg_lat,map_struct=dem.demmapproj);project current location for all lat/lon points into xy space
    doneplot = plot(done_xy[0,*],done_xy[1,*],' .b',/current,/overplot) ;plot up the current state of xy of all points
  skipplot3:
      
  goto,skipplot4
    this_point_todo_plot = plot(reform(todo_xy[0,p],1,1),reform(todo_xy[1,p],1,1),' *g',/current,/overplot)
    closest_DEM_points_plot = plot(dem_x[sel_dem],dem_y[sel_dem],' sg',/current,/overplot) ;plot up the selected DEM points that are "closest" to this point 
    
    ;alldemplot = plot3d((reform(dem.x_grid,n_elements(dem.x_grid)))[0:-1:5],(reform(dem.y_grid,n_elements(dem.x_grid)))[0:-1:5],(reform(dem.elev,n_elements(dem.x_grid)))[0:-1:5],' .g',dim=[1000,1000])
    demplot3d = plot3d(reform(localDEM_x,n_elements(localDEM_x)),reform(localDEM_y,n_elements(localDEM_x)),reform(localDEM_elev,n_elements(localDEM_x)),' +r',sym_size=0.4,dim=[1000,1000]) ;plots subset of DEM points we pull the local subset from
    initelev_plot3d = plot3d(reform(x_from_corners,n_elements(elev_init_from_DEM)),reform(y_from_corners,n_elements(elev_init_from_DEM)),reform(elev_init_from_DEM,n_elements(elev_init_from_DEM)),' +k',/current,/overplot) ;plots initial elevations
    curelev_todoplot3d = plot3d(reform(allimg_x,img_len),reform(allimg_y,img_len),reform(allimg_elev,img_len),' .b',/current,/overplot)
    ;elev_todoplot3d = plot3d(reform(todo_xy[0,*]),reform(todo_xy[1,*]),reform(allimg_new_elev,n_elements(temp_elev)),' .m',sym_size=0.3,/current,/overplot)
    thispoint_curelev_todoplot3d = plot3d(reform(todo_xy[0,p],1),reform(todo_xy[1,p],1),reform(temp_elev[p],1),' *g',/current,/overplot)
    thispoint_newelev_todoplot3d = plot3d(reform(todo_xy[0,p],1),reform(todo_xy[1,p],1),reform(allimg_new_elev[p],1),' *g',/current,/overplot)
    thispoint_closest_DEM_pointsplot3d = plot3d(dem_x[sel_dem],dem_y[sel_dem],DEM_elev[sel_dem],' sg',/current,/overplot)
    
  skipplot4:

  if verbose GE 2 then print,'Iteration '+strcompress(try_count)+' complete. Points remaining '+strcompress(ntodo)+'. Pixel loop time elapsed: '+strcompress((systime(/seconds)-pixel_start)/60.0)+' minutes.'
  blob=0

ENDFOR
;end iterative DEM/elevation loop

      
;check plots
goto,skip_checkplots1
  good = where(img_lat ne 0.0,ngood)
  img_xy = map_proj_forward(img_lon[good],img_lat[good],map_struct=dem.demmapproj)
  temp_dem = plot(dem.x_grid,dem.y_grid,' +r',dim=[1000,1000])
  temp1 = plot(img_xy[0,*],img_xy[1,*],' .k',/current,/overplot)
  test_distance = sqrt((img_xy[0,0]-img_xy[0,-1])^2+(img_xy[1,0]-img_xy[1,-1])^2)
  input_xy = map_proj_forward(lon_in,lat_in,map_struct=dem.demmapproj)
  input_plot = plot(reform(input_xy[0],1,1),reform(input_xy[1],1,1),' +b',sym_thick=2.0,/current,/overplot)
skip_checkplots1:


;here is where we deal with missing DEM data
missing_dem_section:

;deal with missing data, or setup the return data variable
if missing_dem_data gt 0 then begin
  ;create a data flag that will let the cambot_geo_function code know we have to skip this image
  missing_elev = -9999.0
  final_data = create_struct('elev',missing_elev,'missing_dem_reason',missing_dem_reason)
endif else begin
  final_data = create_struct('lat',allimg_lat,'lon',allimg_lon,'path_length',allimg_tot_path_length,'path_angle',allimg_tot_path_angle,'elev',allimg_elev,'DEM_gp_dist',allimg_dist,'iterations',try_count_recorder,'solvedmask',point_found,'epsilon_alt',epsilon_alt)
endelse

if verbose ge 1 then print,'Time to run land ice geolocation code: '+strcompress((systime(/seconds)-start_geolocation_time)/60.0)+' mintues.'

return,final_data

END