FUNCTION read_arctic_dem_basic_v1p1,shp_filename,tif_filename,min_x,max_x,min_y,max_y

;----------------------------------------------
;Function to open an ArcticDEM tile
;Version 1p0, 20200519: updated to fix read_tiff issue
;Version 1p1, 20200520: adjusted sub_len for x & y to remove the +1
;----------------------------------------------

;ensure we have valid input filenames
if file_test(shp_filename) eq 0 then STOP,'cannot find shapefile: '+shp_filename
if file_test(tif_filename) eq 0 then STOP,'cannot find shapefile: '+tif_filename

;
myshape = OBJ_NEW('IDLffShape',shp_filename)
myshape->getProperty,n_entities=num_ent
myshape->getProperty,attribute_names=attr_names
attr = myshape->getAttributes(/all)
myshape->getProperty,attribute_info=attr_info ;info on the individual attributes
ent = myshape->GetEntity(/all)

if strcmp(attr_names[3],'DEM_RES') eq 0 then STOP,'DEM resolution info is in a different spot in the metadata'
dem_res = attr.(3) ;DEM resolution in meters

result = query_image(tif_filename,dimensions=tif_size)
if result ne 1 then STOP,'Issue reading tif size'

vert = *ent.vertices
tile_min_x = min(vert[0,*])
tile_max_x = max(vert[0,*])
tile_min_y = min(vert[1,*])
tile_max_y = max(vert[1,*])

;starting and ending points of each grid tile
tile_x_axis_start = (lindgen(tif_size[0])*dem_res)+tile_min_x
tile_x_axis_end = (lindgen(tif_size[0])*dem_res)+tile_min_x+dem_res
tile_y_axis_start = (lindgen(tif_size[1])*dem_res)+tile_min_y
tile_y_axis_end = (lindgen(tif_size[1])*dem_res)+tile_min_y+dem_res

;center points of each grid in the tile subset
tile_x_axis = (lindgen(tif_size[0])*dem_res)+tile_min_x+(dem_res/2.0) 
tile_y_axis = (lindgen(tif_size[1])*dem_res)+tile_min_y+(dem_res/2.0)

;find the bounds for the subset to read from the full-sized tile
sub_min_x = where(min_x ge tile_x_axis_start AND min_x lt tile_x_axis_end)
if n_elements(sub_min_x) ne 1 then STOP,'found more than one min x-coordinate tile match'
if sub_min_x[0] eq -1 then sub_min_x = 0

sub_max_x = where(max_x ge tile_x_axis_start AND max_x lt tile_x_axis_end)
if n_elements(sub_max_x) ne 1 then STOP,'found more than one max x-coordinate tile match'
if sub_max_x[0] eq -1 then sub_max_x = tif_size[0]-1

sub_min_y = where(min_y ge tile_y_axis_start AND min_y lt tile_y_axis_end)
if n_elements(sub_min_y) ne 1 then STOP,'found more than one min y-coordinate tile match'
if sub_min_y[0] eq -1 then sub_min_y = 0

sub_max_y = where(max_y ge tile_y_axis_start AND max_y lt tile_y_axis_end)
if n_elements(sub_max_y) ne 1 then STOP,'found more than one max y-coordinate tile match'
if sub_max_y[0] eq -1 then sub_max_y = tif_size[1]-1

sub_min_y_rev = tif_size[1]-sub_max_y-1
sub_max_y_rev = tif_size[1]-sub_min_y-1

sub_len_x = sub_max_x-sub_min_x+1
sub_len_y = sub_max_y-sub_min_y+1

subset_flip = [sub_min_x,sub_min_y_rev,sub_len_x,sub_len_y]

sub_x_axis = tile_x_axis[sub_min_x:sub_max_x]
sub_y_axis = tile_y_axis[sub_min_y:sub_max_y] ;do not flip y axis, as this is fine, it's only the "read-in" that is reversed

data = read_tiff(tif_filename,sub_rect=subset_flip) ;subrect=[x,y,width,height] ;REMA & ArcticDEM data is available only as a 32-bit datatype i.e. a float.
data = rotate(data,7) ;orientation value = 1 -> rotate of 7

out_data = create_struct('elev',data,'x_axis',sub_x_axis,'y_axis',sub_y_axis,'res',dem_res,'sub_row_start',sub_min_y,'sub_row_end',sub_max_y,'sub_col_start',sub_min_x,'sub_col_end',sub_max_x)

;clean up file pointers/close file
myshape->DestroyEntity, ent
OBJ_DESTROY, myshape

return,out_data

END