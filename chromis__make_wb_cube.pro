; docformat = 'rst'

;+
; Make a de-rotated and de-stretched time-series FITS data cube with
; momfbd-restored wide-band images.
;
; The header should have information that can be used by companion
; method make_nb_cube to make a de-rotated and de-stretched
; time-series cube with narrow-band images.
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
; 
; 
; 
; 
; 
; :Keywords:
; 
;   
;   
;   
; 
; 
; :History:
; 
;    2017-08-16 : MGL. First version, based on code from
;                 chromis::polish_tseries. 
; 
; 
; 
; 
;-
pro chromis::make_wb_cube, dir $
                           , all = all $
                           , clip = clip $
                           , crop = crop $
                           , origsize = origsize $
                           , negang = negang $
                           , np = np $
                           , offset_angle = offset_angle $
                           , scale = scale $
                           , square = square $
                           , tile = tile $
                           , timefiles = timefiles $
                           , tstep = tstep $
                           , xbd = xbd $
                           , ybd = ybd 
;                             , ang = ang $
;                             , ext_date = ext_date $
;                             , ext_time = ext_time $
;                             , shift = shift $



  ;; Name of this method
  inam = strlowcase((reverse((scope_traceback(/structure)).routine))[0])

  if n_elements(dir) eq 0 then begin
    print, inam + ' : Please specify the directory with momfbd output.'
  endif
  
  ;; Make prpara
  if n_elements(dir         ) ne 0 then red_make_prpara, prpara, 'dir'          , dir    
  if n_elements(blur        ) ne 0 then red_make_prpara, prpara, 'blur'         , blur         
  if n_elements(clip        ) ne 0 then red_make_prpara, prpara, 'clip'         , clip         
  if n_elements(crop        ) ne 0 then red_make_prpara, prpara, 'crop'         , crop         
  if n_elements(origsize    ) ne 0 then red_make_prpara, prpara, 'origsize'     , origsize    
  if n_elements(negang      ) ne 0 then red_make_prpara, prpara, 'negang'       , negang       
  if n_elements(np          ) ne 0 then red_make_prpara, prpara, 'np'           , np           
  if n_elements(offset_angle) ne 0 then red_make_prpara, prpara, 'offset_angle' , offset_angle 
  if n_elements(scale       ) ne 0 then red_make_prpara, prpara, 'scale'        , scale        
  if n_elements(square      ) ne 0 then red_make_prpara, prpara, 'square'       , square       
  if n_elements(tile        ) ne 0 then red_make_prpara, prpara, 'tile'         , tile         
  if n_elements(timefiles   ) ne 0 then red_make_prpara, prpara, 'timefiles'    , timefiles    
  if n_elements(tstep       ) ne 0 then red_make_prpara, prpara, 'tstep'        , tstep        
  if n_elements(ybd         ) ne 0 then red_make_prpara, prpara, 'ybd'          , ybd          
  if n_elements(xbd         ) ne 0 then red_make_prpara, prpara, 'xbd'          , xbd          

  IF n_elements(crop) NE 4 THEN crop = [0,0,0,0]
  if n_elements(clip) eq 0 then clip = [12, 6, 3, 1]
  if n_elements(tile) eq 0 then tile = [10, 20, 30, 40]
  if n_elements(scale) eq 0 then scale = 1.0 / float(self.image_scale)

  ;; Camera/detector identification
  self->getdetectors
  wbindx = where(strmatch(*self.cameras,'Chromis-W'))
  wbcamera = (*self.cameras)[wbindx[0]]
  wbdetector = (*self.detectors)[wbindx[0]]
  nbindx = where(strmatch(*self.cameras,'Chromis-N')) 
  nbcamera = (*self.cameras)[nbindx[0]]
  nbdetector = (*self.detectors)[nbindx[0]]
  ;; Should be generalized to multiple NB cameras if CHROMIS gets
  ;; polarimetry. We don't need to identify any PD cameras for
  ;; restored data.

  ;; Search for restored WB images
  case self.filetype of
    'ANA': extension = '.f0'
    'MOMFBD': extension = '.momfbd'
    'FITS': extension = '.fits'
  endcase
  files = file_search(dir + '*'+extension, count = Nfiles)      
  ;; We have no special state (or absence of state) to identify
  ;; the global WB images but we do know that their exposure times
  ;; are much larger than the ones corresponding to the individual
  ;; NB states.
  self -> extractstates, files, states
  windx = where(states.EXPOSURE gt mean(states.EXPOSURE)*1.5)
  wstates = states[windx]
  wfiles = files[windx]
  Nscans = n_elements(windx)

  prefilter = wstates[0].prefilter
  datestamp = fxpar(red_readhead(wfiles[0]), 'STARTOBS')

  if ~keyword_set(all) then begin
    ;; Select scan numbers
    selectionlist = strtrim(wstates[uniq(wstates.scannumber, sort(wstates.scannumber))].scannumber, 2)
    tmp = red_select_subset(selectionlist $
                            , qstring = inam + ' : Select scans:' $
                            , count = Nscans, indx = scanindx)
    
    wstates = wstates[scanindx]
    wfiles = wfiles[scanindx]
  endif
  uscans = wstates.scannumber
  
  time = strarr(Nscans)
  date = strarr(Nscans)
  tmean = fltarr(Nscans)
  
  ;; Read headers to get obs_time and load the images into a cube
  for iscan = 0L, Nscans -1 do begin
    
    red_progressbar, iscan, Nscans, 'Read headers and load the images into a cube', clock = clock

    im = red_readdata(wfiles[iscan], head = hdr)

    if iscan eq 0 then begin
      dim = size(im, /dimension)
      dimim = red_getborder(im, x0, x1, y0, y1, square = square)
      x0 += crop[0]
      x1 -= crop[1]
      y0 += crop[2]
      y1 -= crop[3]
      nx = x1 - x0 + 1
      ny = y1 - y0 + 1
      cub = fltarr(nx, ny, Nscans)
    endif
    
    red_fitspar_getdates, hdr, date_avg = date_avg, count_avg = hasdateavg, comment_avg = comment_avg

    if hasdateavg then begin
      date_avg_split = strsplit(date_avg, 'T', /extract, count = Nsplit)
      ddate = date_avg_split[0]
      if Nsplit gt 1 then ttime = date_avg_split[1] else undefine, ttime
    endif else undefine, ddate, ttime

    if n_elements(ddate) eq 0 then begin
      print, inam+' : No date and time information for scan '+strtrim(uscans[iscan], 2)
      stop
    endif else begin
      date[iscan] = ddate
      time[iscan] = ttime
    endelse

    cub[*, *, iscan] = red_fillpix((temporary(im))[x0:x1, y0:y1], nthreads = 4L)

    ;; Measure time-dependent intensity variation (sun moves in the Sky)
    tmean[iscan] = median(cub[*,*,iscan])
    
  endfor                        ; iscan

  ;; Plot the intensity variations
  cgplot, uscans, tmean, xtitle = 'Scan number', ytitle = 'Mean WB intensity', psym=-1, /ynozero

  ;; Normalize intensity
  tmean = tmean/mean(tmean)
  for iscan = 0L, Nscans - 1 do cub[*,*,iscan] /= tmean[iscan]

  ;; Might not be needed?
  cub1 = cub
  
  ang = red_lp_angles(time, date)
  mang = median(ang)
  ang -= mang
  if(keyword_set(negang)) then ang = -ang
  if(n_elements(offset_angle)) then ang += offset_angle
  
  ;; De-rotate images in the cube, has to be done before we can
  ;; calculate the alignment
  for iscan = 0L, Nscans -1 do begin
    red_progressbar, iscan, Nscans, inam+' : De-rotating images.', clock = clock
    cub[*,*,iscan] = red_rotation(cub[*,*,iscan], ang[iscan])
  endfor                        ; iscan

  ;; Align cube
  if(~keyword_set(np)) then begin
    np = 0L
    read, np, prompt = inam +' : Please introduce the factor to recompute the reference image: '
  endif

  ;; Calculate the image shifts
  shift = red_aligncube(cub, np, xbd = xbd, ybd = ybd) ;, cubic = cubic, /aligncube)

  ;; Get maximum angle and maximum shift in each direction
  maxangle = max(abs(ang))
  mdx0 = reform(min(shift[0,*]))
  mdx1 = reform(max(shift[0,*]))
  mdy0 = reform(min(shift[1,*]))
  mdy1 = reform(max(shift[1,*]))
  ff = [maxangle, mdx0, mdx1, mdy0, mdy1]

  ;; De-rotate and shift cube
  dum = red_rotation(cub1[*,*,0], ang[0], shift[0,0], shift[1,0], full=ff)
  nd = size(dum,/dim)
  nx = nd[0]
  ny = nd[1]
  cub = fltarr([nd, Nscans])
  cub[*,*,0] = temporary(dum)
  for iscan=1, Nscans-1 do begin
    red_progressbar, clock = clock, iscan, Nscans $
                     , inam+' : Making full-size cube, de-rotating and shifting.'
    cub[*,*,iscan] = red_rotation(cub1[*,*,iscan], full=ff $
                                  , ang[iscan], shift[0,iscan], shift[1,iscan])
  endfor                        ; iscan

  if n_elements(tstep) eq 0 then begin
    dts = dblarr(Nscans)
    for iscan = 0L, Nscans - 1 do dts[iscan] = red_time2double(time[iscan])
    tstep = fix(round(180. / median(abs(dts[0:Nscans-2] - dts[1:*])))) <Nscans
  endif

  print, inam + ' : Using the following parameters for de-stretching the time-series: '
  print, '   tstep [~3 m. (?)]= ', tstep
  print, '   scale [pixels / arcsec] = ', scale
  print, '   tile = ['+strjoin(string(tile, format='(I3)'),',')+']'
  print, '   clip = ['+strjoin(string(clip, format='(I3)'),',')+']'

  ;; Calculate stretch vectors
  grid = red_destretch_tseries(cub, scale, tile, clip, tstep)

  for iscan = 0L, Nscans - 1 do begin
    red_progressbar, iscan, Nscans, inam+' : Applying the stretches.', clock = clock
    cub[*,*,iscan] = red_stretch(cub[*,*,iscan], reform(grid[iscan,*,*,*]))
  endfor                        ; iscan

  if keyword_set(origsize) then begin
    stop
    cub = 'crop the cube to original size here?'
    ;; Change any other parameters that need changing
  endif

  ;; Prepare for making output file names
  odir = self.out_dir + '/wb_cubes/'
  file_mkdir, odir
  midpart = prefilter + '_' + datestamp + '_scans=' $
            + red_collapserange(uscans, ld = '', rd = '')

  ;; Save WB results as a fits file
  ofil = 'wb_'+midpart+'_corrected_im.fits'
  print, inam + ' : saving WB corrected cube -> ' + odir + ofil

  ;; Add the wavelength and Stokes dimensions
  dims = [nx, ny, 1, 1, Nscans]
  cub = reform(cub, dims, /overwrite) 

  ;; Make header. Start with header from last input file, it has
  ;; info about MOMFBD processing.
  check_fits, cub, hdr, /update                                ; Get dimensions right
  red_fitsaddpar, hdr, 'DATE', red_timestamp(/iso) $           ; DATE witht time
                  , 'Creation UTC date of FITS header'         ;
  red_fitsaddpar, hdr, 'BITPIX', 16 $                          ; Because we round() before saving. 
                  , 'Number of bits per data pixel'            ;
  red_fitsaddpar, hdr, 'FILENAME', ofil, anchor = 'DATE'       ; New file name

  if keyword_set(blur) then begin
    red_fitsaddpar, hdr, before='DATE', 'COMMENT', 'Intentionally blurred version'
  endif

  ;; Add info to headers
  red_fitsaddpar, anchor = anchor, hdr, 'BUNIT', 'DU', 'Units in array'
  red_fitsaddpar, anchor = anchor, hdr, 'BTYPE', 'Intensity', 'Type of data in array'

  ;; Add info about this step
  self -> headerinfo_addstep, hdr $
                              , prstep = 'Prepare WB science data cube' $
                              , prpara = prpara $
                              , prproc = inam

  ;; Make time tabhdu extension with Nscans rows
  s_array = lonarr(Nscans)
  s_array[0] = wstates.scannumber
  t_array = dblarr(1, Nscans)
  t_array[0] = red_time2double(time)                             ; In [s] since midnight
;        w_array = fltarr(1)
  ;;w_array[0] = wstates.tun_wavelength
  w_array = replicate(float(prefilter)/10., 1, Nscans) ; In [nm]
;        tabhdu = {EXTNAME-WCS-TABLES: {TIME-TABULATION: {val:t_array  $
;                                                         , comment:'time-coordinates'}, $
;                                       WAVE-TABULATION: {val:w_array $
;                                                         , comment:'wavelength-coordinates'}, $
;                                       comment: ' For storing tabulated keywords'}}
;        tabhdu = {tabulations: {time: {val:t_array $
;                                       , comment:'time-coordinates'}, $
;                                wavelength: {val:w_array $
;                                             , comment:'wavelength-coordinates'}, $
;                                scannumber: {val:s_array $
;                                             , comment:'scannumbers'}, $
;                                comment: ' For storing tabulated keywords'}}
  
  ;; TIME reference value, all times are seconds since midnight.
  dateref = fxpar(hdr, 'DATEREF', count = count)
  if count eq 0 then begin
    ;; One should really check also for the existence of MJDREF
    ;; and JDREF but within the pipeline we can be sure we don't
    ;; use them.
    dateref = self.isodate+'T00:00:00.000000' ; Midnight
    red_fitsaddpar, hdr, 'DATEREF', dateref, 'Reference time in ISO-8601', after = 'DATE'
  endif

  help, round(cub)
  print, 'n_elements:', n_elements(cub)
  ;; Write the file
;        red_fits_createfile, odir + ofil, hdr, lun, fileassoc;, tabhdu = tabhdu
  self -> fitscube_initialize, odir + ofil, hdr, lun, fileassoc, dims ; $
;                                     , wcs_time_coordinate = t_array $
;                                     , wcs_wave_coordinate = w_array $
;                                     , scannumber = s_array


  for iscan = 0, Nscans-1 do begin
    self -> fitscube_addframe, fileassoc, round(cub[*, *, 0, 0, iscan]) $
                               , iscan = iscan
  endfor                        ; iscan
  free_lun, lun
  print, inam + ' : Wrote file '+odir + ofil

  print, inam + ' : Add calibration data to file '+odir + ofil
  ;; Save angles, shifts and de-stretch grids  -- This should make it
  ;;                                              into a file extension
  ;;                                              instead!
;  ofil = 'tseries_'+midpart+'_calib.sav'
;  print, inam + ' : saving calibration data -> ' + odir + ofil
;  save, file = odir + ofil $
;        , tstep, clip, tile, scale, ang, shift, grid, time, date $
;        , wfiles, tmean, crop, mang, x0, x1, y0, y1, ff, nd
  
  ;; Sample saved quantities with comments about their use in make_crispex:
  ;;
  ;; TSTEP           LONG      =            5          [Not used]
  ;; CLIP            INT       = Array[4]              [Not used]
  ;; TILE            INT       = Array[4]              [Not used]
  ;; SCALE           FLOAT     =       26.3852         [Not used]
  ;; ANG             DOUBLE    = Array[5]              [Yes]
  ;; SHIFT           DOUBLE    = Array[2, 5]           [Yes]
  ;; GRID            FLOAT     = Array[5, 2, 40, 25]   [Yes]
  ;; TIME            STRING    = Array[5]              [Not used]
  ;; DATE            STRING    = Array[5]              [Not used]
  ;; WFILES          STRING    = Array[5]              [Yes]
  ;; TMEAN           FLOAT     = Array[5]              [Yes]
  ;; CROP            INT       = Array[4]              [Not used]
  ;; MANG            DOUBLE    =        6.2653633      [Not used]
  ;; X0              LONG      =            0          [Yes]
  ;; X1              LONG      =         1831          [Yes]
  ;; Y0              LONG      =            0          [Yes]
  ;; Y1              LONG      =         1151          [Yes]
  ;; FF              INT       =        0              [Yes] ( = [maxangle, mdx0, mdx1, mdy0, mdy1] if fullframe)
  ;; ND              UNDEFINED = <Undefined>           [Yes] (2d array if fullframe)
  ;;
  ;; (Some of) these quantities should really go into the metadata
  ;; of the FITS file for two reasons: documentation and use in
  ;; make_crispex. The latter so we can avoid using the save file.
  ;;
  ;; Can make_crispex calculate x0,x1,y0,y1 from naxis1 and naxis2 and
  ;; any of the other parameters?

  fxbhmake, bhdr, 1, 'MWCINFO', 'Info from make_wb_cube'
  x01y01 = [X0, X1, Y0, Y1]
  fxbaddcol, col, bhdr, ANG,    'ANG'
  fxbaddcol, col, bhdr, CROP,   'CROP'
  fxbaddcol, col, bhdr, FF,     'FF'
  fxbaddcol, col, bhdr, GRID,   'GRID'
  fxbaddcol, col, bhdr, ND,     'ND'
  fxbaddcol, col, bhdr, SHIFT,  'SHIFT'
  fxbaddcol, col, bhdr, TMEAN,  'TMEAN'
  fxbaddcol, col, bhdr, x01y01, 'X01Y01'

  fxbaddcol, wfiles_col, bhdr, WFILES, 'WFILES'

  fxbcreate, bunit, odir + ofil, bhdr

  fxbwritm, bunit $
            , ['ANG', 'CROP', 'FF', 'GRID', 'ND', 'SHIFT', 'TMEAN', 'X01Y01'] $
            ,   ANG,   CROP,   FF,   GRID,   ND,   SHIFT,   TMEAN,   x01y01
  fxbwrite, bunit, wfiles, wfiles_col, 1
  
  fxbfinish, bunit
  
  print, inam + ' : Added calibration data to file '+odir + ofil

  if 0 then begin
    ;; To read the extension:
    fxbopen, bunit, odir+ofil, 'MWCINFO', bbhdr
    fxbreadm, bunit, row = 1 $
            , ['ANG', 'CROP', 'FF', 'GRID', 'ND', 'SHIFT', 'TMEAN', 'X01Y01'] $
              ,   rANG,   rCROP,   rFF,   rGRID,   rND,  rSHIFT,   rTMEAN,   rX01Y01
    ;; Note that the strarr wfiles cannot be read by fxbreadm!
    fxbread, bunit, rWFILES, 'WFILES', 1
    fxbclose, bunit
    
  endif
  
;        ;; Experimental extra tabulated data:
;        Ntuning = 1
;        temp_array = fltarr(Ntemp)
;        r0_array   = fltarr(Nr0)
;        temp_array[0] = cos(s_array/max(s_array)) ; Really function of scannumber
;        r0_array[0]   = sin(s_array/max(s_array)) ; Really function of time, i.e., of tuning and scannumber
;        
;
;        red_fitsaddpar, hdr, 'TABULATD', 'TABULATIONS;ATMOS_R0,AMB_TEMP'
;
;        fxbhmake,bdr,1,'TABULATIONS','For storing tabulated keywords'
;        fxbaddcol, 1, bdr, r0_array, 'ATMOS_R0', TUNIT = 'm', 'Table of atmospheric r0'
;        fxbadd, bdr, '1CTYP1', 'TIME-TAB', 'Time since DATEREF, tabulated for ATMOS_R0'
;        fxbadd, bdr, '1CNAM1', 'Time since DATEREF for ATMOS_R0'
;        fxbadd, bdr, '1S1_0', 'TABULATIONS', 'Extension w/tabulations for ATMOS_R0'
;        fxbadd, bdr, '1S1_1', 'TIME-ATMOS_R0', 'TTYPE of col. w/TIME for ATMOS_R0'
;        fxbaddcol, 2, bdr, r0_time, 'TIME-ATMOS_R0', 'Tabulations of TIME for ATMOS_R0', tunit = 's'
;        
;        
;        fxbaddcol, 3, bdr, temp_array, 'AMB_TEMP', TUNIT = 'K', 'Table of ambient temperature'
;        fxbcreate, lun, filename, bdr, extension_no
;        fxbwrite, lun, r0_array, 1, 1
;        fxbwrite, lun, temp_array, 2, 1
;        fxbfinish, lun
;    

  self -> fitscube_addwcs, odir + ofil, w_array, t_array
;                                     , scannumber = s_array
;
;
;cccc = red_readdata(odir+ofil, head = hhhh)
;stop
;        
;fxbopen, tlun, odir + ofil, 'WCS-TAB', bhhh
;fxbread, tlun, wavetime_tab, 'WAVE+TIME'
;fxbclose, tlun
;
;
;
;stop

end
