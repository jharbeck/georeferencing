PRO iocam1b_processing_database

;------------------------------------------------------------------
;This program builds the cambot level 1b processing database,
;controlling whether an image gets processed at all, as well
;as if it is processed as a land ice or sea ice image. If it is
;a land ice image, which DEM is used as well.
;------------------------------------------------------------------

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


;directory to output a file to
dir = base_dir2+sl+'for_NSIDC'+sl+'IOCAM0'+sl

out_file = dir+'iocam0_database.sav'

;Arctic Spring 2018: 20 flights
;Antarctic 2018    : 24 flights
;Arctic Spring 2019: 24 flights
;Arctic Summer 2019: 10 flights
;Antarctic 2019    : 20 flights

;total flights     : 98 flights

;Initialize dates for each entry
;Arctic Spring 2018 
ARCSpring2018_dates = '2018'+['0322','04'+['03','04','05','06','07','08','14','16','18','19','21','22','23','25','26','27','29','30'],'0501']

;Antarctic 2018
ANT2018_dates = '2018'+['10'+['10','11','12','13','15','16','18','19','20','22','28','30','31'],'11'+['03','04','05','07','09','10','11','12','14','15','16']]

;Arctic Spring 2019
ARCSpring2019_dates = '2019'+['04'+['03','05','06','08','09','10','12','15','16','17','18','19','20','22','23'],'05'+['05','06','07','08','12','13','14','15','16']]

;Arctic Summer 2019
ARCSummer2019_dates = '201909'+['04','05','06','07','09','10','11','12','13','14']

;Antarctic 2019 
ANT2019_dates = '2019'+['10'+['17','23','24','26','27','28','29','31'],'11'+['02','03','04','05','07','08','09','13','14','16','17','18','19']]


;combine it all into a single variable
flight_dates = [ARCSpring2018_dates,ANT2018_dates,ARCSpring2019_dates,ARCSummer2019_dates,ANT2019_dates]
n_flights = n_elements(flight_dates)


;setup structure and final variable for all data
struct = {IOCAM1b_proc_db, $
          date: '', $
          segment:strarr(100)}
          
dbase = replicate(struct,n_flights)
dbase.date = flight_dates

;------------------------------------------------------------------
;                       Arctic Spring 2018
;------------------------------------------------------------------


;==================================================================

;------------------------------------------------------------------
;                          Antarctic 2018
;------------------------------------------------------------------

;20181010 - checked
  sel = where(dbase.date eq '20181010',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['REMA:172400.4:204359.4']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181011 - checked
  sel = where(dbase.date eq '20181011',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['REMA:174000.4:203759.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181012 - checked
sel = where(dbase.date eq '20181012',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:170514.4:171500.4',$  
              'REMA:171500.9:203025.4',$
            'seaice:203025.9:203759.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181013 - checked
sel = where(dbase.date eq '20181013',nsel)
if nsel ne 1 then STOP
temp_seg = [  'REMA:163411.4:181229.9',$
            'seaice:181230.4:181828.9',$
              'REMA:181829.4:214448.4',$
            'seaice:214448.9:220930.9',$
              'REMA:220931.4:221930.4',$
            'seaice:221930.9:223159.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181015 - checked
sel = where(dbase.date eq '20181015',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:185300.4:190320.4',$
              'REMA:190320.9:221500.4',$
            'seaice:221500.9:222459.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181016 - checked
  sel = where(dbase.date eq '20181016',nsel)
  if nsel ne 1 then STOP
  temp_seg = [  'REMA:181700.4:182216.9',$;    ;??182840.4 start here??
              'seaice:182217.4:182456.9',$; first sea ice section larsen B
                'REMA:182457.4:182946.4',$;
              'seaice:182946.9:183022.4',$; west side bay
                'REMA:183022.9:183036.4',$;
              'seaice:183036.9:183045.9',$; close west side bay #2
                'REMA:183046.4:183620.9',$;
              'seaice:183621.4:183750.9',$; second sea ice section on east side
                'REMA:183751.4:183945.4',$;
              'seaice:183945.9:184240.9',$;
                'REMA:184241.4:185321.4',$;
              'seaice:185321.9:185601.4',$;
                'REMA:185601.9:185835.4',$;
              'seaice:185835.9:185900.4',$; blank spot in middle
                'REMA:185900.9:190521.4',$;
              'seaice:190521.9:191344.4',$;
                'REMA:191344.9:202420.9',$;
              'seaice:202421.4:203600.4',$;
                'REMA:203600.9:214030.4',$;
              'seaice:214030.9:214610.4',$;
                'REMA:214610.9:235959.9',$;
                'REMA:000000.4:000959.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181018 - checked
  sel = where(dbase.date eq '20181018',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['REMA:172000.4:201759.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181019 - checked for sea ice rerelease
  sel = where(dbase.date eq '20181019',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:154347.4:223405.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181020 - checked
  sel = where(dbase.date eq '20181020',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['REMA:173800.4:201059.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181022 - checked
  sel = where(dbase.date eq '20181022',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['REMA:165120.4:210859.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg


;20181028 - checked for seaice reprocessing
  sel = where(dbase.date eq '20181028',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:030000.4:053053.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181030 - checked... might have issues? The 100m thing has lots of holes.
  sel = where(dbase.date eq '20181030',nsel)
  if nsel ne 1 then STOP
  ;temp_seg = ['REMA:181900.4:195659.9']
  temp_seg = ['seaice:182200.4:195659.9'] ;use seaice here, as REMA has so many holes because it's close to the pole
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191031
  sel = where(dbase.date eq '20181031',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:184200.4:184844.4',$
                'REMA:184844.9:220355.4',$
              'seaice:220355.9:220419.9',$
                'REMA:220420.4:220442.4',$
              'seaice:220442.9:221000.9',$
                'REMA:221001.4:222959.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181103
  sel = where(dbase.date eq '20181103',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:172900.4:183911.9'] ;use seaice here, as REMA has too many holes along flight
  ;temp_seg = ['REMA:172900.4:185859.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181104
  sel = where(dbase.date eq '20181104',nsel)
  if nsel ne 1 then STOP
  ;temp_seg = ['REMA:164100.4:192559.9']
  temp_seg = [  'REMA:164100.4:171236.9',$
              'seaice:171237.4:171415.9',$
                'REMA:171416.4:171917.9',$
              'seaice:171918.4:172318.9',$
                'REMA:172319.4:173324.9',$
              'seaice:173325.4:173518.9',$
                'REMA:173519.4:173524.9',$
              'seaice:173925.4:174137.9',$
                'REMA:174138.4:192559.9'] ;adjusting to include some "sea ice" processing to make up for holes in REMA
  
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181105
;  sel = where(dbase.date eq '20181105',nsel) ;VERSION SENT TO NSIDC
;  if nsel ne 1 then STOP
;  temp_seg = ['seaice:160407.4:212421.4']
;  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181105 - version with icesheet taken out
;  sel = where(dbase.date eq '20181105',nsel)
;  if nsel ne 1 then STOP
;  temp_seg = ['seaice:160605.4:170437.9',$
;                'REMA:170438.4:171953.4',$
;              'seaice:171953.9:212421.4']
;  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg
  
  ;20181105 - version used for reprocessing
  sel = where(dbase.date eq '20181105',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:160605.4:212359.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181107
  sel = where(dbase.date eq '20181107',nsel)
  if nsel ne 1 then STOP
  temp_seg = [  'REMA:155800.4:160039.9',$
              'seaice:160040.4:160219.9',$
                'REMA:160220.4:160415.9',$
              'seaice:160416.4:160445.9',$
                'REMA:160446.4:162539.9',$
              'seaice:162540.4:162610.9',$
                'REMA:162611.4:202959.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181109
  sel = where(dbase.date eq '20181109',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['REMA:172500.4:202259.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181110
  sel = where(dbase.date eq '20181110',nsel)
  if nsel ne 1 then STOP
  ;temp_seg = ['REMA:172200.4:202159.9'] ;Initial single segment before REMA gaps found
  temp_seg = [  'REMA:172200.4:182947.9',$
              'seaice:182948.4:183217.9',$
                'REMA:183218.4:183338.9',$
              'seaice:183339.4:183355.9',$
                'REMA:183356.4:184237.9',$
              'seaice:184238.4:184512.9',$
                'REMA:184513.4:185628.9',$
              'seaice:185629.4:185813.9',$
                'REMA:185814.4:191204.9',$
              'seaice:191205.4:191241.9',$
                'REMA:191242.4:202159.9']
  
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181111
  sel = where(dbase.date eq '20181111',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['REMA:164300.4:200859.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181112
  sel = where(dbase.date eq '20181112',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:172915.4:184959.9'] ;use sea ice here as REMA has too many holes
  ;temp_seg = ['REMA:172600.4:184959.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181114
  sel = where(dbase.date eq '20181114',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['REMA:164800.4:200059.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181115
  sel = where(dbase.date eq '20181115',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:163114.4:163238.9',$
                'REMA:163239.4:174141.4',$
              'seaice:174141.9:174859.9',$
                'REMA:174900.4:195959.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20181116
  sel = where(dbase.date eq '20181116',nsel)
  if nsel ne 1 then STOP
  temp_seg = [  'REMA:181100.4:203744.9',$
              'seaice:203745.4:204005.9',$
                'REMA:204006.4:205745.9',$
              'seaice:205746.4:211241.9',$
                'REMA:211242.4:221441.9',$
              'seaice:221442.4:221507.9',$
                'REMA:221508.4:223033.9',$
              'seaice:222034.4:222106.9',$
                'REMA:222107.4:222559.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg


;==================================================================

;------------------------------------------------------------------
;                       Arctic Spring 2019
;------------------------------------------------------------------
;20190403
  sel = where(dbase.date eq '20190403',nsel)
  if nsel ne 1 then STOP
  temp_seg = [$
                 'seaice:113800.4:113825.9',$
              'ArcticDEM:113826.4:114024.4',$ 
                 'seaice:114024.9:114640.4',$
              'ArcticDEM:114640.9:114859.9',$
                 'seaice:120000.0:120641.4',$
              'ArcticDEM:120641.9:122441.4',$
                 'seaice:122441.9:122943.9',$
              'ArcticDEM:122944.4:124652.9',$
                 'seaice:124653.4:125153.4',$
              'ArcticDEM:125153.9:130816.4',$
                 'seaice:130816.9:131348.4',$
              'ArcticDEM:131348.9:133107.9',$
                 'seaice:133108.4:133738.4',$
              'ArcticDEM:133738.9:135523.4',$
                 'seaice:135523.9:140100.9',$
              'ArcticDEM:140101.4:141838.4',$
                 'seaice:141838.9:142517.9',$
              'ArcticDEM:142518.4:144226.9',$
                 'seaice:144227.4:144928.9',$
              'ArcticDEM:144929.4:150708.9',$
                 'seaice:150709.4:151250.4',$
              'ArcticDEM:151250.9:152939.9',$
                 'seaice:152940.4:153651.9',$
              'ArcticDEM:153652.4:155023.9',$
                 'seaice:155024.4:155553.9',$
              'ArcticDEM:155554.4:161320.4',$
                 'seaice:161320.9:161702.4',$
              'ArcticDEM:161702.9:163511.9',$
                 'seaice:163512.4:163914.4',$
              'ArcticDEM:163914.9:165426.4',$
                 'seaice:165426.9:170528.4',$
              'ArcticDEM:170528.9:172800.0']
              dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg 

;20190405
  sel = where(dbase.date eq '20190405',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:110000.4:131328.4',$
                 'seaice:131328.9:133039.9',$
              'ArcticDEM:133040.4:180559.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg
              
;20190406 - checked
  sel = where(dbase.date eq '20190406',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:131000.4:171359.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg 
  
;20190408 - checked
  sel = where(dbase.date eq '20190408',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:121800.4:155559.4']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190409
  sel = where(dbase.date eq '20190409',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:120500.4:180559.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190410
  sel = where(dbase.date eq '20190410',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:110600.4:110841.4',$
                 'seaice:110841.9:111304.9',$
              'ArcticDEM:111305.4:174859.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190412 - checked
  sel = where(dbase.date eq '20190412',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:130500.4:155559.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190415
  sel = where(dbase.date eq '20190415',nsel)
  if nsel ne 1 then STOP
  temp_seg = [   'seaice:145500.4:145749.4',$
              'ArcticDEM:145749.9:175159.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190416
  sel = where(dbase.date eq '20190416',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:121200.4:172759.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190417
  sel = where(dbase.date eq '20190417',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:111700.4:125320.9',$
                 'seaice:125321.4:125737.4',$
              'ArcticDEM:125737.9:180950.4',$
                 'seaice:180950.9:181159.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190418
  sel = where(dbase.date eq '20190418',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:110300.4:181332.4',$
                 'seaice:181332.9:181559.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190419 - checked
  sel = where(dbase.date eq '20190419',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:123000.4:153159.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190420 - checked
  sel = where(dbase.date eq '20190420',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:120400.4:151259.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190422 - checked
  sel = where(dbase.date eq '20190422',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:135900.4:154759.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190423
  sel = where(dbase.date eq '20190423',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:110500.4:110946.4',$
                 'seaice:110946.9:111031.9',$
              'ArcticDEM:111032.4:142131.9',$
                 'seaice:142132.4:143625.9',$
              'ArcticDEM:143626.4:145220.4',$
                 'seaice:145220.9:150044.9',$
              'ArcticDEM:150045.4:181956.4',$
                 'seaice:181956.9:182459.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190505
  sel = where(dbase.date eq '20190505',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:112126.9:184459.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190506
  sel = where(dbase.date eq '20190506',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:104000.4:183859.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190507
  sel = where(dbase.date eq '20190507',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:101800.4:182259.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190508
  sel = where(dbase.date eq '20190508',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:104800.4:183159.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190512
  sel = where(dbase.date eq '20190512',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:115900.4:201414.9',$
                 'seaice:201415.4:201436.4',$
              'ArcticDEM:201436.9:202559.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190513
  sel = where(dbase.date eq '20190513',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:105900.4:182359.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg
  
;20190514
  sel = where(dbase.date eq '20190514',nsel)
  if nsel ne 1 then STOP
  temp_seg = [   'seaice:111300.4:111315.9',$
              'ArcticDEM:111316.4:113741.4',$
                 'seaice:113741.9:114006.4',$
              'ArcticDEM:114006.9:114803.9',$
                 'seaice:114804.4:114930.4',$
              'ArcticDEM:114930.9:115110.9',$
                 'seaice:115111.4:115530.4',$
              'ArcticDEM:115530.9:180659.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190515
  sel = where(dbase.date eq '20190515',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:103500.4:145240.4',$
                 'seaice:145240.9:150100.9',$
              'ArcticDEM:150101.4:150659.4',$
                 'seaice:150659.9:150837.9',$
              'ArcticDEM:150838.4:152327.4',$
                 'seaice:152327.9:152729.4',$
              'ArcticDEM:152729.9:153751.4',$
                 'seaice:153751.9:154045.4',$
              'ArcticDEM:154045.9:154739.4',$
                 'seaice:154739.9:155240.9',$
              'ArcticDEM:155241.4:160007.4',$
                 'seaice:160007.9:160331.9',$
              'ArcticDEM:160332.4:161229.9',$
                 'seaice:161230.4:161559.9',$
              'ArcticDEM:161600.4:163057.4',$
                 'seaice:163057.9:163218.9',$
              'ArcticDEM:163219.4:163827.9',$
                 'seaice:163828.4:164212.9',$
              'ArcticDEM:164213.4:180959.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg
  
;20190516
  sel = where(dbase.date eq '20190516',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:104400.4:163159.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;==================================================================


;------------------------------------------------------------------
;                        Arctic Summer 2019
;------------------------------------------------------------------

;20190904
  sel = where(dbase.date eq '20190904',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:112600.4:174059.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190905
  sel = where(dbase.date eq '20190905',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:123300.4:132759.9',$
                 'seaice:132800.4:133859.9',$
              'ArcticDEM:133900.4:171859.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190906
  sel = where(dbase.date eq '20190906',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:112100.4:171859.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190907
  sel = where(dbase.date eq '20190907',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:105800.4:164459.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190909
  sel = where(dbase.date eq '20190909',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['seaice:124930.4:161250.4']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190910
  sel = where(dbase.date eq '20190910',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:122000.4:153459.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190911
  sel = where(dbase.date eq '20190911',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:115830.4:165559.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190912
  sel = where(dbase.date eq '20190912',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:120700.4:163059.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190913
  sel = where(dbase.date eq '20190913',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:151500.4:173659.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20190914
  sel = where(dbase.date eq '20190914',nsel)
  if nsel ne 1 then STOP
  temp_seg = ['ArcticDEM:124700.4:162959.9']
  dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;==================================================================


;------------------------------------------------------------------
;                          Antarctic 2019
;------------------------------------------------------------------

;20191017 - test flight
sel = where(dbase.date eq '20191017',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:164130.0:171000.0']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191023
sel = where(dbase.date eq '20191023',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:021000.4:021353.9',$
              'REMA:021354.4:051759.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191024
sel = where(dbase.date eq '20191024',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:013400.4:013853.4',$
              'REMA:013853.9:043122.4',$
            'seaice:043122.9:043559.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191026
sel = where(dbase.date eq '20191026',nsel)
if nsel ne 1 then STOP
temp_seg = ['REMA:020400.4:045259.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191027
sel = where(dbase.date eq '20191027',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:014700.4:020049.9',$
              'REMA:020050.4:025027.9',$
            'seaice:025028.4:030405.9',$
              'REMA:030406.4:041159.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191028
sel = where(dbase.date eq '20191028',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:025000.4:031331.9',$
              'REMA:031332.4:032158.9',$
            'seaice:032159.4:032902.9',$
              'REMA:032903.4:034044.9',$
            'seaice:034045.4:034209.9',$
              'REMA:034210.4:034609.9',$
            'seaice:034610.4:035614.4',$
              'REMA:035614.9:041915.4',$
            'seaice:041915.9:042259.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191029
sel = where(dbase.date eq '20191029',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:025100.4:025922.9',$
              'REMA:025923.4:032759.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191031
sel = where(dbase.date eq '20191031',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:010300.4:011024.4',$
              'REMA:011024.9:011248.4',$
            'seaice:011248.9:011302.4',$
              'REMA:011302.9:011305.9',$
            'seaice:011306.4:011316.4',$
              'REMA:011316.9:011504.4',$
            'seaice:011504.9:011917.9',$
              'REMA:011918.4:041559.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191102
sel = where(dbase.date eq '20191102',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:013500.4:014325.9',$
              'REMA:014326.4:022306.4',$
            'seaice:022306.9:023545.4',$
              'REMA:023545.9:032617.4',$
            'seaice:032617.9:034030.9',$
              'REMA:034031.4:043139.4',$
            'seaice:043139.9:043359.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191103
sel = where(dbase.date eq '20191103',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:010400.4:011059.9',$
              'REMA:020400.4:033659.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191104
sel = where(dbase.date eq '20191104',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:011300.4:011935.9',$
              'REMA:011936.4:024427.4',$
            'seaice:024427.9:030949.9',$
              'REMA:030950.4:031341.9',$
            'seaice:031342.4:031723.9',$
              'REMA:031724.4:033807.4',$
            'seaice:033807.9:033849.9',$
              'REMA:033850.4:035603.4',$
            'seaice:035604.4:043259.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191105
sel = where(dbase.date eq '20191105',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:010400.4:012001.9',$
              'REMA:012002.4:014631.4',$
            'seaice:014522.9:020819.9',$
              'REMA:020820.4:022542.4',$
            'seaice:022542.9:022715.4',$
              'REMA:022715.9:022904.4',$
            'seaice:022904.9:022947.9',$
              'REMA:022948.4:023344.4',$
            'seaice:023344.9:023500.4',$
              'REMA:023500.9:040459.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191107
sel = where(dbase.date eq '20191107',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:231931.3:232218.9',$
              'REMA:232219.4:235959.9',$
              'REMA:000000.4:021338.9',$
            'seaice:021339.4:021420.5']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191108
sel = where(dbase.date eq '20191108',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:231800.4:233021.9',$
              'REMA:233022.4:235644.4',$
            'seaice:235644.9:235959.9',$ ;first pass
            'seaice:000000.4:000344.9',$
              'REMA:000345.4:002931.9',$
            'seaice:002932.4:003852.9',$ ;second pass
              'REMA:003853.4:005600.9',$
            'seaice:005601.4:010747.4',$ ;third pass
              'REMA:010747.9:012303.4',$
            'seaice:012303.9:014028.9',$
              'REMA:014029.4:014759.9'] ;fourth pass
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191109
sel = where(dbase.date eq '20191109',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:000100.4:025559.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191113
sel = where(dbase.date eq '20191113',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:022800.4:031959.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191114
sel = where(dbase.date eq '20191114',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:024500.4:025013.9',$
              'REMA:025014.4:032859.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191116
sel = where(dbase.date eq '20191116',nsel)
if nsel ne 1 then STOP
temp_seg = ['REMA:013300.4:042859.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191117
sel = where(dbase.date eq '20191117',nsel)
if nsel ne 1 then STOP
temp_seg = ['seaice:014600.4:015325.9',$
              'REMA:015326.4:032117.9',$
            'seaice:032118.4:033320.9',$
              'REMA:033321.4:033428.9',$
            'seaice:033429.4:035258.9',$
              'REMA:035259.4:035959.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191118
sel = where(dbase.date eq '20191118',nsel)
if nsel ne 1 then STOP
temp_seg = [  'REMA:013700.4:015624.4',$
            'seaice:015624.9:020321.9',$
              'REMA:020322.4:040226.4',$
            'seaice:040226.9:040759.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg

;20191119
sel = where(dbase.date eq '20191119',nsel)
if nsel ne 1 then STOP
temp_seg = ['REMA:011800.4:041159.9']
dbase[sel].segment[0:n_elements(temp_seg)-1] = temp_seg


;==================================================================

save,filename=out_file,dbase
print,'Finished generating terrain database file'

END