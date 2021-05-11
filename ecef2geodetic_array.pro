function ecef2geodetic_array,x,y,z
  ;function to convert ECEF to lat, lon, and altitude, optimized for arrays


  ;[phi, lambda, h] = ecef2geodetic(p(:,1), p(:,2), p(:,3), [R sqrt( 1 - ( 1 - f )^2 )]);



  ;************Constants*************
  f = 1/298.257223563D  ;flattening term from WGS84 definition
  er = 6378137.0D ;Earth equatorial radius in meters
  el = 0.0818191908426215D ;8.1819190842622e-2  ;WGS84 constant
  ;**********************************

  ; Ellipsoid constants
  ;a  = er ;ellipsoid(1);       ; Semimajor axis
  ;e2 = ellipsoid(2) ^ 2;   ; Square of first eccentricity
  a = er
  e2 = el ^2.0D
  ep2 = e2 / (1 - e2);     ; Square of second eccentricity
  f = 1 - sqrt(1 - e2);    ; Flattening
  b = a * (1 - f);         ; Semiminor axis

  ; Longitude
  lambda = atan(y,x);

  ; Distance from Z-axis
  rho = sqrt( ABS(x)^2.0D + ABS(y)^2.0D) ;hypot(x,y);

  ; Bowring's formula for initial parametric (beta) and geodetic (phi) latitudes
  betaa = atan(z, (1 - f) * rho);
  phi = atan(z   + b * ep2 * sin(betaa)^3.0, rho - a * e2  * cos(betaa)^3.0);

  ; Fixed-point iteration with Bowring's formula
  ; (typically converges within two or three iterations)
  betaaNew = atan((1 - f)*sin(phi), cos(phi));
  epsilon = 1e-7 ;chose epsilon as 1e-7 as this is ~1cm accuracy, below distance mmt threshold
  
  for j=0,4 do begin
    sel = where(abs(betaa-betaaNew) gt epsilon,nsel)
    if nsel eq 0 then break 
    
    betaa[sel] = betaaNew[sel]
    phi[sel] = atan(z[sel]   + b * ep2 * sin(betaa[sel])^3,  rho[sel] - a * e2  * cos(betaa[sel])^3.0);
    betaaNew[sel] = atan((1 - f)*sin(phi[sel]), cos(phi[sel]));
  endfor
 
;  while beta NE betaNew AND count < 5 DO BEGIN
;    beta = betaNew;
;    phi = atan(z   + b * ep2 * sin(beta)^3,  rho - a * e2  * cos(beta)^3.0);
;    betaNew = atan((1 - f)*sin(phi), cos(phi));
;    count = count + 1;
;  endwhile

  ; Calculate ellipsoidal height from the final value for latitude
  sinphi = sin(phi);
  N = a / sqrt(1 - e2 * sinphi^2.0);
  h = rho * cos(phi) + (z + e2 * N * sinphi) * sinphi - N;


  llh = [[phi],[lambda],[h]]  ;lat and lon in radians, height in meters
  return,llh
END