FUNCTION find_total_pointing_angle_dbl,roll,pitch,radians=radians

;-----------------------------------------------------------
;Function to find the total offset aircraft pointing angle
;given the pitch and roll
;
;roll,pitch: roll and pitch of aircraft, in degrees
;radians: keyword that when set (default=0), has input 
;         roll and pitch in radians instead of degrees
;-----------------------------------------------------------

if n_elements(radians) eq 0 then radians = 0

;convert angles to radians, if applicable
if radians eq 0 then begin
  rolly = roll*((!dpi)/180.0D)
  pitchy = pitch*((!dpi)/180.0D)
endif

;using formula: (tan c)^2 = (tan a)^2 + (tan b)^2, where a and b are pitch and 
;roll, regardless of order and c is the resultant angle of the two. 

tan_result = sqrt((tan(rolly)^2) + (tan(pitchy)^2))
result = atan(tan_result)

;convert value back to degrees, if applicable
if radians eq 0 then begin
  result = result*(180.0D/(!dpi))
endif

return,result

END