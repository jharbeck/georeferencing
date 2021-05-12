# georeferencing
Codes used for georeferencing imagery, namely CAMBOT imagery associated with Operation IceBridge.


INITAL SETUP
Before you begin, ensure you have at least IDL version 8.1 installed, as well as exiftool installed.

Program set overview: CAMBOT jpeg files files are combined with mounting bias data, lens/camera data, aircraft and (if applicable) DEM/terrain data to generate georeferenced and orthorectified GeoTIFFs for each JPEG image provided. 



INITIAL PREP
Before the main georeferencing code can be run, there are a number of things that need to be in place: 

- Paths should be updated to reflect where data is coming from/going to. I tried to limit where this needed to happen, passing values through function calls where possible. Here are the programs/functions that contain paths that need to be set:
  -- cambot_georeferencing_v5p1.pro
  -- open_arctic_dem_file_4cambot_v1p3.pro
  -- open_antarctic_dem_file_4cambot_v1p3.pro
  
- Mounting biases are required to be calculated each time the camera system is (re)installed on an aircraft. I have a separate github section on this called "mountingbiases"; see that section on determining mounting bias values.

- A number of setup values need to be entered into the "cambot_geo_function_landice_v6p1.pro" & "cambot_geo_function_seaice_v4p0.pro" codes:
  -- Mounting biases need to be manually entered in the mounting bias section. 
  -- Camera offset values need to be manually entered for the "camera_offset" variable; values are typically found in the ancillary file header
  -- image rotation and mirror flip settings, these are typically determined through trial and error with 0.0 values entered for mounting biases and running a test image through the georeferencing code to at least get image orientation correct. 
  -- focal_length variable should be set correctly: it is 0.02859 m for the primary camera, this likely should not change for the backup camera, but this isn't tested yet though, as the backup camera adaptor collar *might* be of a slightly different length than the primary camera one. 

- A processing (land or sea) database has to be built, to tell the main georeferencing program which method to run each image as. The program "iocam1b_processing_database.pro" is where all these timestamp subsets and the type of processing to be done, are setup. Once this program is run, it generates a database "iocam0_database.sav", from which processing methods are pulled from for the date you are running.

- Lens correction files have been already generated for the primary/backup CAMBOT camera setups, though these will have to be redone if camera setups change.

- Finally, before the main georeferencing program is run, folders containing the JPEG files to be processed must be filtered such that all images in each folder are included in the timestamps listed in the processing database. If this is not done, a "missing terrain" will occur when initial processing is started.


GEOREFERENCING
The main program that manages the georeferencing is "cambot_georeferencing_v5p1.pro". It is from this program that the list of jpeg files to be georeferenced are generated and where the high-level georeferencing functions are called. There are two "types" of georeferencing performed on images: "land ice" which involves terrain, from a DEM or other source and "sea ice", which simply projects the image onto a flat plain for georeferencing. This main program has the option of processing multiple images in parallel, through the use of the "SPLIT_FOR" code set created by R. da Silva in 2010. 

In this main function, the data from the ancillary file is read in, containing all aircraft info we need. A list of JPEG filenames is then created, filtered from 2 Hz -> 1Hz, already processed files are removed, and terrain types assigned to each filename. Now that we have a filtered and prepped list of filenames to be processed, we read-in the metadata for each image. 

Once these pre-processing steps are complete, filenames, terrain info and metadata are split up by land/sea ice processing type and fed into the primary geolocation functions; with land ice going first and sea ice second. All land ice images are processed first, then all sea ice images. These are the top-level functions that are parallelized, if parallelization is turned on.

Inside the top-level georeferencing functions ("cambot_geo_function_landice_v6p1.pro" & "cambot_geo_function_seaice_v4p0.pro"), the current JPEG image is read in & oriented correctly. Ancillary data for this image is then found and the correct mounting biases, offsets and lens values selected. In the land ice code, DEM data is then read-in for an area around this image and filtered to remove "small" data holes. The prepped image and all associated data are then sent to the actual geolocation code ("geolocate_image_landice_v7p1.pro" & "geolocate_image_seaice_v7p0.pro") where each image pixel is given a latitude, longitude and elevation; the output is a cloud of disparate points, not an image array. Based upon aircraft altitude above the surface and original image size, a georeferenced grid is created to grid the image to. Using the pixel locations cloud from above, each pixel value is added to the grid. Once everything is added, duplicate pixels are averaged and data holes are interpolated across. The final image is written to a TIFF file, with updated geotiff and metadata information applied as well.

If there are any issues encountered during the georeferencing process, such as terrain data having too large a hole to interpolate across or aircraft data missing, a text file containing the error is output instead of the GeoTIFF file.
===========================================================================================================
