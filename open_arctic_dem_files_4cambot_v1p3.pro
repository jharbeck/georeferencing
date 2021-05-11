Function open_arctic_dem_files_4cambot_v1p3,center_lat,center_lon,center_elev,diag_fov=diag_fov,update=update,xygrids=xygrids
;--------------------------------------------------------------------------------
;program to open and (if necessary) combine multiple Arctic DEM files into a 
;single DEM. Downloads and unpacks additional tiles if required.
;
;Version 0p1 : code development
;Version 1p0 : first working version
;Version 1p1 : exporting full x&y grids if asked for
;Version 1p2 : updates function call to read_arctic_dem_basic_v1p0
;Version 1p3 : uses tmp file to manage downloading of new tiles during parallel use of the code
;
;Keywords
;diag_fov: set field of view (in degrees) of the diagional across which we wish to get DEM data for (plus 50m on all sides)
;update: 
;xygrids: set to 1 to include gridded x & y values, along with x & y axes
;--------------------------------------------------------------------------------

;center_lat = 75.613606
;center_lon = -80.429971
;center_elev = 1543.821

;set keywords
if n_elements(diag_fov) eq 0 then diag_fov = 32.0
if n_elements(update) eq 0 then update = 0
if n_elements(xygrids) eq 0 then xygrids = 0 

sl = path_sep()
if strcmp(sl,'\') eq 1 then begin
  base_dir1 = 'Y:'
  base_dir2 = 'X:'
  base_dir3 = 'W:'
  base_dir4 = 'V:'
endif else begin
  base_dir1 = '/data/users'
  base_dir2 = '/data/derived'
  base_dir3 = '/scratch/icebridgedata'
  base_dir4 = '/scratch/satellite'
endelse

dem_base_dir = base_dir4+sl+'ArcticDEM'
indexfile = dem_base_dir+sl+'ArcticDEM_Tile_Index_Rel7.shp'
myshape = OBJ_NEW('IDLffShape',indexfile)
myshape->getProperty,n_entities=num_ent
attr = myshape->getAttributes(/all)

;~~attributes~~
;0: objectid
;1: name
;2: tile
;3: nd_value
;4: resolution
;5: creationda
;6: raster
;7: file_url
;8: spec_type
;9: qual
;10: reg_src
;11: num_gspc
;12: meanresz
;13: active
;14: qc
;15: rel_ver
;16: num_comp
;17: st_area_sh
;18: st_length_

;sav_filename = 'ArcticDEM_Tile_Index_Rel7.sav'
;if file_test(sav_filename) eq 1 then goto,restore_ArcticDEM

x_vert = replicate(-99999.0,2,num_ent) ;min,max
y_vert = x_vert
tile_name = replicate('',num_ent)
tile_url = replicate('',num_ent)
FOR b=0,num_ent-1 do begin
  
  ;get entity b
  ent = myshape->IDLffShape::GetEntity(b)

  ;ensure the entity is a closed shape
  if ent.shape_type ne 5 then STOP,'this entity is not a polygon'

  ;pull all boundaries & name for this entity
  x_vert[*,b] = reform((*ent.vertices)[0,0:1])
  y_vert[*,b] = reform((*ent.vertices)[1,1:2])
  tile_name[b] = attr[b].attribute_1 ;assign tile name
  tile_url[b] = attr[b].attribute_7

  myshape->DestroyEntity, ent

ENDFOR
OBJ_DESTROY, myshape

;adjust names and url to work with 10m as well
tile_name_10m = strmid(tile_name,0,6)+'10'+strmid(tile_name,11)
tile_url_10m =  strmid(tile_url,0,61)+'10'+strmid(tile_url,62,14)+'10'+strmid(tile_url,81) ;files are downloaded from the PGC site, which is relative to the WGS-84 ellipsoid

;save,filename=sav_filename,x_vert,y_vert,tile_name,tile_url,tile_name_10m,tile_url_10m

;restore_ArcticDEM:
;restore,sav_filename

;generate a projection structure to work with
ImgMapProj = MAP_PROJ_INIT('Polar Stereographic', $
  ELLIPSOID='WGS 84', $
  TRUE_SCALE_LATITUDE=70.0, $
  CENTER_LONGITUDE=-45.0, $
  FALSE_EASTING=0.0, $
  FALSE_NORTHING=0.0)

;move center lat/lon into projected space
center_xy = map_proj_forward(center_lon,center_lat,map_structure=ImgMapProj)
center_x = center_xy[0]
center_y = center_xy[1]

;temp center x&y
;center_x =  -949900
;center_y = -1299900

;generate bounds
extra_dist = 10000 ;extra distance for bounds, in meters 
diag_dist = (center_elev*tan(diag_fov*(!pi/180.0)))[0]+extra_dist
min_x = center_x-diag_dist
max_x = center_x+diag_dist
min_y = center_y-diag_dist
max_y = center_y+diag_dist

;query each corner point
query_verts = fltarr(2,4)
query_verts[*,0] = [min_x,max_y] 
query_verts[*,1] = [max_x,max_y]
query_verts[*,2] = [max_x,min_y]
query_verts[*,3] = [min_x,min_y]
point_tile_sel = replicate('',4)

FOR p=0,3 do begin
  sx = query_verts[0,p]
  sy = query_verts[1,p]
  sel = where(sx ge x_vert[0,*] and sx lt x_vert[1,*] and sy ge y_vert[1,*] and sy lt y_vert[0,*],nsel) 
  if nsel eq 0 then STOP,'could not find a tile for this corner'
  if nsel gt 1 then STOP,'Found multiple tiles for this corner'
  point_tile_sel[p] = sel 
ENDFOR

uniq_tile_sel = uniq(point_tile_sel,sort(point_tile_sel))
n_tiles = n_elements(uniq_tile_sel)
point_tile_sel2 = point_tile_sel[uniq_tile_sel]

;-----------------------------------------------------
;                     2m resolution
;-----------------------------------------------------
;point_tile_url = tile_url[point_tile_sel2]
;point_tile_name = tile_name[point_tile_sel2]
;=====================================================
 
;-----------------------------------------------------
;                     10m resolution
;-----------------------------------------------------
point_tile_url_temp = tile_url_10m[point_tile_sel2]
point_tile_name_temp = tile_name_10m[point_tile_sel2]

point_tile_sel_10m = uniq(point_tile_name_temp,sort(point_tile_name_temp))
n_tiles = n_elements(point_tile_sel_10m)
point_tile_name = point_tile_name_temp[point_tile_sel_10m]
point_tile_url = point_tile_url_temp[point_tile_sel_10m]

;=====================================================

if update ge 1 then print,'Found '+strcompress(n_tiles)+' DEM tiles for this image'

;now that we have all the info we need for this query location, let's make sure we have the data
for f=0,n_tiles-1 do begin
  this_tile_dir = dem_base_dir+sl+point_tile_name[f]+sl
  
  ;check for a placeholder file, so we don't have more than one instance of this code trying to download a file
  temp_tile = dem_base_dir+sl+point_tile_name[f]+'.tmp'

  mins_pause = 0L 
  while file_test(temp_tile) eq 1 do begin
    wait,60
    mins_pause++
    if mins_pause gt 20 then STOP,'issue downloading new DEM tile' ;ensure we don't sit here forever just waiting for a different worker to download a tile that has crashed
  endwhile
  
  if file_test(this_tile_dir,/dir) eq 0 then begin
    if update ge 1 then print,'We do not have this DEM file '+point_tile_name[f]+' yet, downloading...'
    
    ;first, create a temp file to stop the other workers from downloading this tile as well
    openw,tmplun,temp_tile,/get_lun & free_lun,tmplun
    
    ;first, create a directory to put this all in
    file_mkdir,this_tile_dir
    
    ;get tar.gz file from internet, if we don't have it already
    this_tile_url = point_tile_url[f]
    tar_file = dem_base_dir+sl+file_basename(this_tile_url)
    if file_test(tar_file) eq 0 then begin
      test = OBJ_NEW('IDLnetURL')
      file = test->get(url=this_tile_url,filename=tar_file)
      obj_destroy,test
    endif
    
    ;unzip tar file to new directory (works in both windows & linux!) =D
    if update ge 1 then print,'Unzipping file '+tar_file
    spawn,'tar -xzvf '+tar_file+' -C '+this_tile_dir
    
    ;erase the tar.gz file now that we have the data on the server
    if update ge 1 then print,'Deleting tar.gz file'
    file_delete,tar_file
    
    ;remove the tmp file, so the rest of the workers who need this file can now use it
    file_delete,temp_tile
    
  endif ;end tile directory check
endfor


;now that we have all the data, combine it into a single, giant tile

;pull row/col info out of tile names
tile_row_nums = long(strmid(point_tile_name,0,2))
tile_col_nums = long(strmid(point_tile_name,3,2))

ntile_rows = max(tile_row_nums)-min(tile_row_nums)+1
ntile_cols = max(tile_col_nums)-min(tile_col_nums)+1

;initialize variables to place data into
dem_tile_size = [10000,10000] ;all ArcticDEM tiles are 10000x10000

full_dem = replicate(-99999.0,ntile_cols*dem_tile_size[0],ntile_rows*dem_tile_size[1])
full_dem_xaxis = replicate(-99999.0,ntile_cols*dem_tile_size[0])
full_dem_yaxis = replicate(-99999.0,ntile_rows*dem_tile_size[1])

;x = cols
;y = rows

for t=0,n_tiles-1 do begin

  shp_filename = dem_base_dir+sl+point_tile_name[t]+sl+'index'+sl+point_tile_name[t]+'_index.shp'
  tif_filename = dem_base_dir+sl+point_tile_name[t]+sl+point_tile_name[t]+'_reg_dem.tif'
  dem = read_arctic_dem_basic_v1p1(shp_filename,tif_filename,min_x,max_x,min_y,max_y)
  ;returns: 
  ;elev
  ;x_axis
  ;y_axis
  ;res
  ;sub_col_start
  ;sub_col_end
  ;sub_row_start
  ;sub_row_end
  col_offset = (tile_col_nums[t]-min(tile_col_nums))*dem_tile_size[0]
  row_offset = (tile_row_nums[t]-min(tile_row_nums))*dem_tile_size[1]
  full_dem_col_start = dem.sub_col_start+col_offset
  full_dem_col_end = dem.sub_col_end+col_offset
  full_dem_row_start = dem.sub_row_start+row_offset
  full_dem_row_end = dem.sub_row_end+row_offset
  
  full_dem[full_dem_col_start:full_dem_col_end,full_dem_row_start:full_dem_row_end] = dem.elev
  full_dem_xaxis[full_dem_col_start:full_dem_col_end] = dem.x_axis 
  full_dem_yaxis[full_dem_row_start:full_dem_row_end] = dem.y_axis
endfor

;truncate full-size variables to locations with valid data
fsx = where(full_dem_xaxis ne -99999.0,n_fsx) & if n_fsx lt 1 then STOP
fsy = where(full_dem_yaxis ne -99999.0,n_fsy) & if n_fsy lt 1 then STOP
fullsub_dem_xaxis = full_dem_xaxis[fsx]
fullsub_dem_yaxis = full_dem_yaxis[fsy]

fullsub_dem = full_dem[fsx[0]:fsx[-1],fsy[0]:fsy[-1]] 

if xygrids eq 0 then begin
  
  out_data = create_struct('elev',fullsub_dem,'x_axis',fullsub_dem_xaxis,'y_axis',fullsub_dem_yaxis,'res',dem.res)
  
endif else begin
  
  ;generate a projection structure assoc'd with the DEM coordinates
  DEMMapProj = MAP_PROJ_INIT('Polar Stereographic', $
    ELLIPSOID='WGS 84', $
    TRUE_SCALE_LATITUDE=70.0, $
    CENTER_LONGITUDE=-45.0, $
    FALSE_EASTING=0.0, $
    FALSE_NORTHING=0.0)
  
  ;generate xy locations for DEM subset
  dem_x_size = n_elements(fullsub_dem_xaxis)
  dem_y_size = n_elements(fullsub_dem_yaxis)
  dem_x = rebin(fullsub_dem_xaxis,dem_x_size,dem_y_size)
  dem_y = transpose(rebin(fullsub_dem_yaxis,dem_y_size,dem_x_size))
  
  out_data = create_struct('elev',fullsub_dem,'x_axis',fullsub_dem_xaxis,'y_axis',fullsub_dem_yaxis,'res',dem.res,'x_grid',dem_x,'y_grid',dem_y,'demmapproj',DEMMapProj)
endelse

return,out_data
END 