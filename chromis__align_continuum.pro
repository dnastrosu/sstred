; docformat = 'rst'

;+
; Measure image shift between restored continuum and wideband images,
; to be used for alignment of crispex cubes.
; 
; :Categories:
;
;    CHROMIS pipeline
; 
; 
; :Author:
; 
;    Mats Löfdahl, ISP
; 
; :Params:
; 
; 
; :Keywords:
;   
;    continuum_filter : in, optional, type=string, default='3999'
;   
;       The continuum prefilter, identifying images to be aligned to
;       the wideband images.
;   
;    overwrite  : in, optional, type=boolean
;   
;       Set this to overwrite existing files.   
;
; 
; 
; :History:
; 
;    2016-11-25 : MGL. First version.
; 
;    2016-12-03 : MGL. Use red_centerpic.
;
;    2016-12-04 : JdlCR. Fixed problems when only one scan has been
;                 reduced. Fixed bug when ignore_indx = where(w eq
;                 0.0). It can return -1 and then the last element
;                 will be set to zero.
; 
;    2016-12-30 : MGL. Make plots directly to files, without popping
;                 up a graphics window.
; 
;    2017-04-27 : MGL. New keyword momfbddir.
;
; 
;-
pro chromis::align_continuum, continuum_filter = continuum_filter $
                              , overwrite = overwrite $
                              , momfbddir = momfbddir
   
  
  ;; Name of this method
  inam = strlowcase((reverse((scope_traceback(/structure)).routine))[0])

  if n_elements(momfbddir) eq 0 then momfbddir = 'momfbd' 
  
  ;; Logging
  help, /obj, self, output = selfinfo 
  red_writelog, selfinfo = selfinfo

  ;; The default continuum state for Ca II scans
  if n_elements(continuum_filter) eq 0 then continuum_filter = '3999'

  ;; Camera/detector identification
  self->getdetectors
  wbindx = where(strmatch(*self.cameras,'Chromis-W'))
  wbcamera = (*self.cameras)[wbindx[0]]
  wbdetector = (*self.detectors)[wbindx[0]]
  nbindx = where(strmatch(*self.cameras,'Chromis-N')) 
  nbcamera = (*self.cameras)[nbindx[0]]
  nbdetector = (*self.detectors)[nbindx[0]]

  ;; Find timestamp subdirs
  search_dir = self.out_dir + '/'+momfbddir+'/'
  timestamps = file_basename(file_search(search_dir + '*' $
                                         , count = Ntimestamps, /test_dir))
  if Ntimestamps eq 0 then begin
    print, inam + ' : No timestamp sub-directories found in: ' + search_dir
    return
  endif

  ;; Select timestamp folders
  selectionlist = strtrim(indgen(Ntimestamps), 2)+ '  -> ' + timestamps
  tmp = red_select_subset(selectionlist $
                          , qstring = inam + ' : Select timestamp directory ID:' $
                          , count = Ntimestamps, indx = sindx)
  if Ntimestamps eq 0 then begin
    print, inam + ' : No timestamp sub-folders selected.'
    return                      ; Nothing more to do
  endif
  timestamps = timestamps[sindx]
  print, inam + ' : Selected -> '+ strjoin(timestamps, ', ')

  ;; Loop over timestamp directories
  for itimestamp = 0L, Ntimestamps-1 do begin

    timestamp = timestamps[itimestamp]
    datestamp = self.isodate+'T'+timestamp

    ;; Find prefilter subdirs
    search_dir = self.out_dir +'/'+momfbddir+'/'+timestamp+'/'
    prefilters = file_basename(file_search(search_dir + '*' $
                                           , count = Nprefs, /test_dir))
    if Nprefs eq 0 then begin
      print, inam + ' : No prefilter sub-directories found in: ' + search_dir
      continue                  ; Next timestamp
    endif
    
    ;; Select prefilter folders
    selectionlist = strtrim(indgen(Nprefs), 2)+ '  -> ' + prefilters
    tmp = red_select_subset(selectionlist $
                            , qstring = inam + ' : Select prefilter directory ID:' $
                            , count = Nprefs, indx = sindx)
    if Nprefs eq 0 then begin
      print, inam + ' : No prefilter sub-folders selected.'
      continue                  ; Go to next timestamp
    endif
    prefilters = prefilters[sindx]
    print, inam + ' : Selected -> '+ strjoin(prefilters, ', ')

    ;; Loop over WB prefilters
    for ipref = 0L, Nprefs-1 do begin

      odir = self.out_dir + '/align/' + timestamp $
                     + '/' + prefilters[ipref] + '/'
      file_mkdir, odir

      
      nname = odir+'scan_numbers.fz'
      sname = odir+'continuum_shifts.fz'
      mname = odir+'continuum_shifts_smoothed.fz'
      cname = odir+'continuum_contrasts.fz'

      xpname = odir+'plot_Xshifts.ps' ; Will be converted to pdf 
      ypname = odir+'plot_Yshifts.ps'
      cpname = odir+'plot_contrasts.ps'

      if keyword_set(overwrite) $
         or min(file_test([nname, sname, mname, cname, xpname, ypname, cpname])) eq 0 then begin

        ;; Find all the NB continuum images 
        search_dir = self.out_dir + '/'+momfbddir+'/' + timestamp $
                     + '/' + prefilters[ipref] + '/cfg/results/'
        files = file_search(search_dir + '*.'+['f0', 'momfbd', 'fits'], count = Nfiles)      
        
        self -> selectfiles, files = files, states = states $
                             , cam = nbcamera, prefilter = continuum_filter $
                             , sel = nbcindx, count = Nscans

        if Nscans eq 0 then continue
        nbcstates = states[nbcindx]
        
        self -> selectfiles, files = files, states = states $
                             , cam = wbcamera $
                             , sel = wbindx, count = wNscans
        if wNscans lt Nscans then stop;continue

        wbcindx = wbindx[where(states[wbindx].fpi_state eq states[nbcindx[0]].fpi_state, wNscans)]
        if wNscans ne Nscans then continue
print, 'wNscans', wNscans      

        ;; Sort
        sindx = sort(nbcstates.scannumber)
        nbcstates = states[nbcindx[sindx]]
        nbcfiles = files[nbcindx[sindx]]
        sindx = sort(states[wbcindx].scannumber)
        wbcstates = states[wbcindx[sindx]]
        wbcfiles = files[wbcindx[sindx]]

        if max(abs(nbcstates.scannumber - wbcstates.scannumber)) ne 0 then begin
          print, inam + ' : Scan numbers in WB and NB do not match.'
          stop
        endif
        
        shifts = fltarr(2, Nscans) 
        contrasts = fltarr(Nscans)  

        for iscan = 0, Nscans-1 do begin
          
          red_progressbar, iscan, Nscans, clock = clock, /predict $
                           , 'Aligning continuum vs wideband for '+timestamp $
                           + '/' + prefilters[ipref]

          im1o = red_readdata(nbcfiles[iscan]) 
          im2o = red_readdata(wbcfiles[iscan]) 

          msz = 1024
          shifts_total = [0., 0.]
          im1c = red_centerpic(im1o, sz = msz)
          im2c = red_centerpic(im2o, sz = msz)
          
          rit = 0
          repeat begin

            shifts_new = red_alignoffset(im1c, im2c, /window, /fitplane)
            shifts_total = shifts_total + shifts_new

            im2c = red_centerpic(red_shift_sub(im2o, shifts_total[0], shifts_total[1]), sz = msz)

            rit++
            ;;print, 'Shifts after '+strtrim(rit, 2)+' iterations: '+strjoin(shifts_total, ',')

            if rit gt 10 then stop
            
            shifts[0, iscan] = shifts_total

            contrasts[iscan] = stddev(im1c)/mean(im1c)
            
          endrep until max(abs(shifts_new)) lt 0.001

        endfor                  ; iscan

        ;; If there are outliers in the contrasts (maybe caused by
        ;; failed restoration), then remove them from the analysis.
        ;; The biweight_mean function returns weight zero for
        ;; outliers.
        contrast_mean = biweight_mean(contrasts,contrast_sigma,w)
        ignore_indx = where(w eq 0.0, count)
        if count gt 0 then begin
          print, inam+' : '+strtrim(count, 2)+' contrast outliers ignored.'
          print, inam+' : Mean contrast w/o outliers: ', contrast_mean
          print, inam+' : Contrast outlier min,mean,median,max:'
          print, min(contrasts[ignore_indx])
          print, mean(contrasts[ignore_indx])
          print, median(contrasts[ignore_indx])
          print, max(contrasts[ignore_indx])
          print, inam+' : Zeroing outliers.'
          contrasts[ignore_indx] = 0
        endif

        ;; Smooth the shifts, taking image quality into account.
        shifts_smooth = fltarr(2, Nscans) 
        weights = contrasts^2
        smooth_window = 35
        for iaxis = 0, 1 do begin
          ;; X and Y axis loop
          if Nscans lt 10 then begin
            ;; Very few scans, just use a weighted average
            shifts_smooth[iaxis, *] = total(shifts[iaxis, *]*weights)/total(weights)
          endif else if Nscans lt smooth_window then begin
            ;; A few more, use a weighted polynomial fit
            P = mpfitexpr('P[0]+P[1]*X+P[2]*X*X' $
                          , nbcstates.scannumber, shifts[iaxis, *] $
                          , weights = weights, yfit = shifts_fit)
            shifts_smooth[iaxis, *] = shifts_fit
          endif else begin
             ;; Use weighted smoothing
             shifts_smooth[iaxis, *] = red_wsmooth(nbcstates.scannumber, shifts[iaxis, *] $
                                                   , smooth_window, 2 $
                                                   , weight = weights, select = 0.6 )
          endelse
        endfor                  ; iaxis

        fzwrite, [nbcstates.scannumber], nname, ' '
        fzwrite, shifts, sname, ' '
        fzwrite, shifts_smooth, mname
        fzwrite, [contrasts], cname

        ;; Plot colors representing image quality
        colors = red_wavelengthtorgb(cgscalevector(-contrasts, 400, 750), /num)
        ;;xrange = [-1, Nscans]
        xrange = [-1, 1] + [min(nbcstates.scannumber), max(nbcstates.scannumber)]
        title = timestamp + '/' + prefilters[ipref]

        ;; Plot contrasts

        cgPS_Open, cpname, /decomposed
        cgplot, [0], /nodata $
                , xrange = xrange, yrange = [min(contrasts), max(contrasts)] + 0.01*[-1, 1] $
                , title = title $
                , xtitle = 'scan number', ytitle = 'RMS contrast' 
        for iscan = 0, Nscans-1 do cgplot, /over $
                                           , nbcstates[iscan].scannumber, contrasts[iscan] $
                                           , color = colors[iscan], psym = 16

        cgPS_Close, /PDF, /Delete_PS

        ;; Plot shifts
        axistag = ['X', 'Y']
        for iaxis = 0, 1 do begin
          ;; X and Y axis loop

          case iaxis of
            0: cgPS_Open, xpname, /decomposed
            1: cgPS_Open, ypname, /decomposed
          endcase
           
          yrange = [min(shifts[iaxis, *]), max(shifts[iaxis, *])] + 0.2*[-1, 1]
          cgplot, [0], /nodata, color = 'blue' $
                  , title = title $
                  , xrange = xrange, yrange = yrange $
                  , xtitle = 'scan number', ytitle = axistag[iaxis]+' shift / 1 pixel'
          
          for iscan = 0, Nscans-1 do cgplot, /over $
                                             , nbcstates[iscan].scannumber, shifts[iaxis, iscan] $
                                             , color = colors[iscan], psym = 16

          cgplot, /over, nbcstates.scannumber, shifts_smooth[iaxis, *], color = 'red'

          cgPS_Close, /PDF, /Delete_PS
        endfor                   ; iaxis

      endif                      ; overwrite
    endfor                       ; ipref
  endfor                         ; itimestamp

  print
  print, inam + ' : Please inspect the smooting results shown in align/??:??:??/????/*.pdf.'
  print, inam + ' : Edit continuum_shifts_smoothed.fz if you do not like the results of the smoothing.'
  print, inam + ' : The lines should be smoothed versions of the points, but with low-contrast data having less (or no) weight.'

end
