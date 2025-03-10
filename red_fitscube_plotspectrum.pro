; docformat = 'rst'

;+
; Plot median spectrum of fitscube with atlas.
; 
; :Categories:
;
;    SST pipeline
; 
; 
; :Author:
; 
;    Mats Löfdahl, Institute for Solar Physics
; 
; 
; :Returns:
; 
; 
; :Params:
; 
;   filename : in, type=string
; 
;      The name of the file to plot the spectrum of.
; 
; :Keywords:
; 
;   axis_numbers : in, out, optional, type=array
;
;      The fitscube pixel coordinates axis numbers of the
;      frame_statistics array. Used for multiple calls with the same
;      filename.
;
;   disk_center : in, optional, type=boolean
;
;      Disk center data should match the atlas spectrum but might not
;      because of a failed intensity level correction. With this
;      keyword set, plot also the data spectrum adjusted to the atlas
;      intensity level (blue + symbols).
; 
;   frame_statistics : in, out, optional, type=array
;
;      Intensity statistics for the frames of the fitscube. Used for
;      multiple calls with the same filename.
;
;   nosave : in, optional, type=boolean
;
;      Do not save the plot as a pdf file.
;
;   himargin : in, optional, type=array
;
;      Extend upper end of xrange by this many percent of the
;      wavelength range of the data.
;     
;   lomargin : in, optional, type=array
;
;      Extend lower end of xrange by this many percent of the
;      wavelength range of the data.
;     
;   title : in, optional, type=string, default='Based on the file name'  
;     
;      Used as plot title.
;     
;   xrange : in, optional, type=array
;
;      Set xrange of plot explicitly.
;
;   yrange : in, optional, type=array
;
;      Set yrange of plot explicitly (*10E-9).
; 
; :History:
; 
;   2021-03-02 : MGL. First version.
;
;   2021-07-22 : OA. Added 'yrange' keyword.
; 
;   2021-09-08 : MGL. New keyword disk_center.
; 
;-
pro red_fitscube_plotspectrum, filename $
                               , axis_numbers = axis_numbers $
                               , disk_center = disk_center $
                               , frame_statistics = frame_statistics $
                               , himargin = himargin $
                               , lomargin = lomargin $
                               , nosave = nosave $
                               , test = test $
                               , title = title $
                               , xrange = xrange $
                               , yrange = yrange
  

  if n_elements(lomargin) eq 0 then lomargin = 15. ; Percent of range
  if n_elements(himargin) eq 0 then himargin = 15. ; Percent of range
  
  ;; Get FITS header
  hdr = headfits(filename)

  Ntun    = fxpar(hdr, 'NAXIS3')
  Nstokes = fxpar(hdr, 'NAXIS4')
  Nscans  = fxpar(hdr, 'NAXIS5')

  instrument = strtrim(fxpar(hdr, 'INSTRUME'), 2)
  prefilter  = strtrim(fxpar(hdr, 'FILTER1'), 2)
  units      = strtrim(fxpar(hdr, 'BUNIT'), 2)

  red_fitspar_getdates, hdr $
                        , date_beg = date_beg $
                        , date_end = date_end $
                        , date_avg = date_avg 

  date_split = strsplit(date_avg, 'T', /extract)
  date = date_split[0]
  time = date_split[1]
  
  ;; Get WCS coordinates 
  red_fitscube_getwcs, filename, coordinates = coordinates
  lambda = coordinates[*, 0].wave[0,0] ;Wavelengths in nm

  ;; Adjust lambda range
  if n_elements(xrange) eq 0 then $
    lambda_min = min(lambda) $
  else begin
    lambda_min = xrange[0]
    in = where(lambda le xrange[0],cc)
    if cc ne 0 then begin
      indx_l = in[-1] + 1
      lambda = lambda[indx_l:*]
    endif else indx_l = 0
  endelse
  if n_elements(xrange) eq 0 then $
    lambda_max = max(lambda) $
  else begin
    lambda_max = xrange[1]
    in = where(lambda ge xrange[1],cc)    
    if cc ne 0 then begin
      indx_r = in[0] - 1
      lambda = lambda[0:indx_r]
    endif else indx_r = n_elements(lambda)-1
  endelse 
  lambda_delta = lambda_max-lambda_min
  lambda_min -= lambda_delta * lomargin/100.  
  lambda_max += lambda_delta * himargin/100.

  ;; Get statistics
  if n_elements(axis_numbers) gt 0 and n_elements(frame_statistics) gt 0 then begin
    ;; Reuse previously calculated statistics
  end else begin
    red_fitscube_statistics, filename, frame_statistics, axis_numbers = axis_numbers
  endelse
 
  case 1 of
    n_elements(indx_l) ne 0 and n_elements(indx_r) ne 0 : datamedn = frame_statistics[indx_l:indx_r].datamedn
    n_elements(indx_l) ne 0 : datamedn = frame_statistics[indx_l:*].datamedn    
    n_elements(indx_r) ne 0 : datamedn = frame_statistics[0:indx_r].datamedn    
    else : datamedn = frame_statistics.datamedn
  endcase
  
  case 1 of
    array_equal(axis_numbers, [3])       :
    array_equal(axis_numbers, [3, 4])    :
    array_equal(axis_numbers, [3, 5])    : 
    array_equal(axis_numbers, [3, 4, 5]) : datamedn = reform(datamedn[*, 0, *])
    else : stop
  endcase
  
  ;; Get mu and zenith angle
  red_logdata, date, time $
               , mu = mu $
               , zenithangle = zenithangle
  
  ;; Get the atlas
  red_satlas, lambda_min, lambda_max, /nm $
              , atlas_lambda, atlas_spectrum $
              , /si, cont = cont 

  ;; We may want to convolve the atlas spectrum here
  ;; Make FPI transmission profile
  dw = atlas_lambda[1] - atlas_lambda[0]
  if instrument eq 'CHROMIS' then begin
    np = round((0.080 * 8) / dw)
    if np/2*2 eq np then np -=1
    tw = (dindgen(np)-np/2)*dw + double(prefilter)
    tr = chromis_profile(tw, erh=-0.09d0)
  endif else begin
    np = long((max(atlas_lambda) - min(atlas_lambda)) / dw) - 2
    if np/2*2 eq np then np -=1
    tw = (dindgen(np)-np/2)*dw                                             
    tr = crisp_fpi_profile(tw, prefilter, erh=-0.01d, /offset_correction)
  endelse
  tr /= total(tr)
  atlas_spectrum_convolved = fftconvol(atlas_spectrum, tr)

  if n_elements(xrange) eq 0 then xrange = [lambda_min, lambda_max]
  if n_elements(yrange) eq 0 then yrange = [0, (max(atlas_spectrum*1e9) > max(datamedn*1e9))*1.02]

  if n_elements(title) eq 0 then begin
    title = file_basename(filename)
    title = red_strreplace(title, '_corrected_im.fits', '')
    title = red_strreplace(title, 'nb_', '')
  endif
  
    
  ;; Adapt units for cgplot
  plunits = red_strreplace(units, '^-1', '$\exp-1$', n = 3)
  plunits = red_strreplace(plunits, '^-2', '$\exp-2$')
  
  ;; Make the plot
  cgwindow
  cgplot, /add, atlas_lambda/10, atlas_spectrum_convolved*1e9 $
          , xtitle = '$\lambda$ / 1 nm', ytitle = 'median(Intensity) / 1 n'+plunits $
          , title = title $
          , xrange = xrange, yrange = yrange
  for iscan = 0, Nscans-1 do cgplot, /add, /over, lambda, datamedn[*, iscan]*1e9, psym = 9, color = 'red'


  ;; Adjust intensity level
  if keyword_set(disk_center) then begin
    for iscan = 0, Nscans-1 do begin
      spec_sample = red_intepf(atlas_lambda/10, atlas_spectrum_convolved*1e9, lambda)
      data_adjusted = datamedn[*, iscan]*1e9 * mean(spec_sample)/mean(datamedn[*, iscan]*1e9)
      cgplot, /add, /over, lambda, data_adjusted, psym = 1, color = 'blue'
    endfor
  endif

  
  if keyword_set(test) then begin
    ;; Doppler shift from solar rotation. 
    hpln = median(coordinates.hpln) ; [deg] Helioprojective longitude, westward angle 
    hplt = median(coordinates.hplt) ; [deg] Helioprojective latitude, northward angle 
    hel_lat = hplt                  ; [deg] Heliographic latitude
    ;; Parametrization of solar rotation as function of lat and lon
    ;; from Snodgrass, H.; Ulrich, R. (1990). "Rotation of Doppler
    ;; features in the solar photosphere". Astrophysical Journal. 351:
    ;; 309-316. Bibcode: 1990ApJ...351..309S. doi:10.1086/168467. 
    A = 14.713                  ; ± 0.0491 °/d - Equatorial rotation rate
    B = -2.396                  ; ± 0.188 °/d  - Latitudinal rotation gradient
    C = -1.787                                     ; ± 0.253 °/d  - 
    sn = sin(hel_lat*!pi/180.)
    rotation_rate = A + B*sn^2 + C*sn^4            ; [deg/day]
    rotation_rate /= 360.*60.*60.*24.              ; [revolutions/s]
    ;; Velocity
    Rsun = 6.957e8                                 ; [m]
    v_at_surface = rotation_rate*Rsun*2*!pi        ; [m/s] Rotational velocity along surface 
    v_toward_obs = v_at_surface*sin(hpln*!pi/180.) ; [m/s] Velocity toward observer
    ;; Convective Doppler shift varies with mu and wavelength, we may
    ;; want to include that effect as well. Maybe a suitale reference:
    ;; https://www.aanda.org/articles/aa/pdf/2011/04/aa15664-10.pdf 
    
    ;; Convert to wavelength shift
    dlambda = median(lambda) * v_toward_obs/!const.c ; [nm]
    print
    print, 'Expected Doppler shift (based on coordinates) : '+string(dlambda, format = '(f6.3)')+ ' nm. (Blue arrow.)'
    print
;    cgplot, /add, /over, min(lambda) + [0, dlambda], max(atlas_spectrum*1e9)/10.*[1, 1], color = 'blue'
    cgplot, /add, /over, color = 'blue' $
            , min(lambda) + [0., 1., 0.7, 0.7, 1.]*dlambda $
            , max(atlas_spectrum*1e9)/10. + [0., 0., -1, 1, 0.]*dlambda
    ;; Arrow head does not come out right, even with exaggerated dimensions!
    cgplot, /add, /over, min(lambda)+dlambda*[1., 0.7, 0.7, 1.], max(atlas_spectrum*1e9)/10. + [0., -1., 1., 0.]*dlambda/2., color = 'red'
;    x0 = min(lambda)
;    x1 = x0 + dlambda
;    y0 = max(atlas_spectrum*1e9)/10. 
;    y1 = y0
;    stop
;;    cgArrow, /add, x0, y0, x1, y1, COLOR='green', /data, /solid, hsize = !D.X_SIZE / 30. ;64. ; / 2
;    if dlambda gt 0 then pangle = 0 else pangle = 180
;    cgwindow, /add, 'one_arrow', x0, y0, pangle, ' ', COLOR='green', /data, arrowsize=[abs(dlambda), abs(dlambda)/5., 35.]
  endif
  
  plfile = file_dirname(filename) + '/' + file_basename(filename, '.fits') + '.pdf'
  if ~keyword_set(nosave) then cgcontrol, output = plfile
  
end






case 4 of
  0 : begin
    undefine, axis_numbers, frame_statistics
    cd, '/scratch/mats/2016.09.19/CRISP-aftersummer/'
    filename = 'cubes_nb/nb_6302_2016-09-19T09:30:20_scans=0-2_stokes_corrected_im.fits'
    filename = 'cubes_nb_test/nb_6302_2016-09-19T09:30:20_scans=2-8_stokes_corrected_im.fits'
    filename = 'cubes_TEST/nb_6302_2016-09-19T09:30:20_scans=2,3_stokes_corrected_im.fits'
    filename = 'cubes_TEST/nb_6302_2016-09-19T09:30:20_scans=2,3_corrected_im.fits'
    red_fitscube_plotspectrum, filename, /test $
                               , axis_numbers = axis_numbers $
                               , frame_statistics = frame_statistics
  end
  1 : begin
    undefine, axis_numbers, frame_statistics
    cd, '/scratch/olexa/2020-10-16/CHROMIS/'
    filename = 'cubes_nb/nb_3950_2020-10-16T09:11:04_scans=0-3,5,6,8,9_corrected_im.fits'
    red_fitscube_plotspectrum, filename $
                               , axis_numbers = axis_numbers $
                               , frame_statistics = frame_statistics
    red_fitscube_plotspectrum, filename $
                               , axis_numbers = axis_numbers $
                               , frame_statistics = frame_statistics $
                               , xrange=[393,393.7]
  end
  2 : begin
    undefine, axis_numbers, frame_statistics
    cd, '/scratch/mats/2016.09.19/CHROMIS-jan19'
    filename = 'cubes_TEST/nb_3950_2016-09-19T09:28:36_scans=0-3_corrected_im.fits'
    red_fitscube_plotspectrum, filename $
                               , axis_numbers = axis_numbers $
                               , frame_statistics = frame_statistics
    red_fitscube_plotspectrum, filename $
                               , axis_numbers = axis_numbers $
                               , frame_statistics = frame_statistics $
                               , xrange=[393,393.7]
  end

  3 : begin
    undefine, axis_numbers, frame_statistics
    cd, '/scratch/olexa/2020.04.25/CRISP/'
    red_fitscube_plotspectrum, 'cubes_nb/nb_6302_2020-04-25T11:08:59_scans=0,1_stokes_corrected_im.fits'
  end

  4 : begin
    undefine, axis_numbers, frame_statistics
    cd, '/scratch/mats/2016.09.19/CHROMIS-jan19'
    filename = 'cubes_nb/nb_3950_2016-09-19T10:42:01_scans=0-4_corrected_im.fits'
    red_fitscube_plotspectrum, filename $
                               , axis_numbers = axis_numbers $
                               , frame_statistics = frame_statistics
    red_fitscube_plotspectrum, filename $
                               , axis_numbers = axis_numbers $
                               , frame_statistics = frame_statistics $
                               , xrange=[393,393.7]
    red_fitscube_plotspectrum, filename $
                               , axis_numbers = axis_numbers $
                               , frame_statistics = frame_statistics $
                               , xrange=[396.5,397.2]
  end
  
endcase



end

