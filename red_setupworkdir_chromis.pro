pro red_setupworkdir_chromis, work_dir, root_dir, cfgfile, scriptfile, isodate

  red_metadata_store, fname = work_dir + '/info/metadata.fits' $
                      , [{keyword:'INSTRUME', value:'CHROMIS' $
                          , comment:'Name of instrument'} $
                         , {keyword:'TELCONFG', value:'Schupmann, imaging table', $
                            comment:'Telescope configuration'}]
  
  ;; Open two files for writing. Use logical unit Clun for a Config
  ;; file and Slun for a Script file.
  
  openw, Clun, work_dir + cfgfile,    /get_lun
  openw, Slun, work_dir + scriptfile, /get_lun

  ;; Specify the date in the config file, ISO format.
  print, 'Date'
  printf, Clun, '#'
  printf, Clun, '# --- Settings'
  printf, Clun, '#'
  printf, Clun,'isodate = '+isodate
  printf, Clun,'image_scale = 0.0379'   ; Measured in May 2016.
  printf, Clun, 'diversity = 3.35e-3'   ; Nominal value for 2016.

  printf, Slun, 'a = chromisred("'+cfgfile+'")' 
  printf, Slun, 'root_dir = "' + root_dir + '"'

  ;; Download SST log files and optionally some other data from the web.
  print, 'Log files'
  printf, Clun, '#'
  printf, Clun, '# --- Download SST log files'
  printf, Clun, '#'
  printf, Slun
  printf, Slun, 'a -> download ; add ", /all" to get also HMI images and AR maps.'

  ;; Analyze directories and produce r0 plots (optional)
  printf, Slun
  printf, Slun, 'a -> hrz_zeropoint' ; Find the reference wavelenght of CHROMIS scans
  printf, Slun, '; a -> analyze_directories ; Time consuming, do it in a separate IDL session.'
  printf, Slun, '; red_plot_r0 requires analyze_directories to have been run:'
  printf, Slun, '; red_plot_r0, /plot8, /mark ; Plot r0 for the whole day.'
  printf, Slun, '; red_plot_r0, /scan8 ; Plot r0 data for scans. '
  printf, Slun, '; red_plot_r0, /plotstats ; Plot r0 statistics vs scan number.'
  

  print, 'Cameras'
  printf, Clun, '#'
  printf, Clun, '# --- Cameras'
  printf, Clun, '#'
  printf, Clun, 'camera = Chromis-W'
  printf, Clun, 'camera = Chromis-D'
  printf, Clun, 'camera = Chromis-N'
  printf, Clun, '#'
  printf, Clun, 'root_dir = ' + root_dir
  printf, Clun, '#'

  print, 'Output'
  printf, Clun, '#'
  printf, Clun, '# --- Output'
  printf, Clun, '#'
  printf, Clun, 'out_dir = ' + work_dir

  print, 'Darks'
  printf, Clun, '#'
  printf, Clun, '# --- Darks'
  printf, Clun, '#'
  
  darksubdirs = red_find_instrumentdirs(root_dir, 'chromis', '*dark*' $
                                        , count = Nsubdirs)
  if Nsubdirs gt 0 then begin
    darkdirs = file_dirname(darksubdirs)
    darkdirs = darkdirs[uniq(darkdirs, sort(darkdirs))]
    printf, Slun
    for idir = 0, n_elements(darkdirs)-1 do begin
      printf, Clun, 'dark_dir = '+red_strreplace(darkdirs[idir] $
                                                 , root_dir, '')
      printf, Slun, 'a -> sumdark, /check, dirs=root_dir+"' $
              + red_strreplace(darkdirs[idir], root_dir, '') + '"'
    endfor                      ; idir
  endif                         ; Nsubdirs
  
  print, 'Flats'
  printf, Clun, '#'
  printf, Clun, '# --- Flats'
  printf, Clun, '#'

  flatsubdirs = red_find_instrumentdirs(root_dir, 'chromis', '*flat*' $
                                        , count = Nsubdirs)
  if Nsubdirs gt 0 then begin
    ;; There are CHROMIS flats!

    ;; Directories with camera dirs below:
    flatdirs = file_dirname(flatsubdirs)
    flatdirs = flatdirs[uniq(flatdirs, sort(flatdirs))]
    Nflatdirs = n_elements(flatdirs)

    ;; Loop over the flatdirs, write each to the config file and
    ;; to the script file
    printf, Slun
    for idir = 0, Nflatdirs-1 do begin

      ;; Config file

      printf, Clun, 'flat_dir = '+red_strreplace(flatdirs[idir] $
                                                 , root_dir, '')

      ;; Script file
      
      ;; Look for wavelengths in those flatsubdirs that match
      ;; flatdirs[idir]! Also collect prefilters.
      indx = where(strmatch(flatsubdirs, flatdirs[idir]+'*'))
      fnames = file_search(flatsubdirs[indx]+'/sst_cam*', count = Nfiles)
      if Nfiles gt 0 then begin
        
        camdirs = strjoin(file_basename(flatsubdirs[indx]), ' ')

        red_extractstates, fnames, /basename, pref = wls
        wls = wls[uniq(wls, sort(wls))]
        wls = wls[WHERE(wls ne '')]
        wavelengths = strjoin(wls, ' ')
        ;; Print to script file
        printf, Slun, 'a -> sumflat, /check, dirs=root_dir+"' $
                + red_strreplace(flatdirs[idir], root_dir, '') $
                + '"  ; ' + camdirs+' ('+wavelengths+')'

        red_append, prefilters, wls

      endif                     ; Nfiles
    endfor                      ; idir
  endif                         ; Nsubdirs

  if n_elements(prefilters) gt 0 then $
     prefilters = prefilters[uniq(prefilters, sort(prefilters))]
  Nprefilters = n_elements(prefilters)

  if Nprefilters eq 0 then begin
    ;; This can happen if flats were already summed in La Palma. Look
    ;; for prefilters in the summed flats directory instead.
    spawn, 'ls flats/cam*.flat | cut -d. -f2|sort|uniq', prefilters
    Nprefilters = n_elements(prefilters)
  endif
  
  printf, Slun, "a -> makegains, /preserve"
  
  print, 'Pinholes'
  printf, Clun, '#'
  printf, Clun, '# --- Pinholes'
  printf, Clun, '#'
  pinhdirs = file_search(root_dir+'/*pinh*/*', count = Ndirs, /fold)
  for i = 0, Ndirs-1 do begin
    pinhsubdirs = file_search(pinhdirs[i]+'/chromis*', count = Nsubdirs, /fold)
    if Nsubdirs gt 0 then begin
      printf, Slun
      printf, Clun, 'pinh_dir = '+red_strreplace(pinhdirs[i], root_dir, '')
      printf, Slun, 'a -> setpinhdir, root_dir+"' $
              + red_strreplace(pinhdirs[i], root_dir, '')+'"'
;        printf, Slun, 'a -> sumpinh_new'
      for ipref = 0, Nprefilters-1 do begin
        printf, Slun, "a -> sumpinh, /pinhole_align, pref='"+prefilters[ipref]+"'"
      endfor                    ; ipref
    endif else begin
      pinhsubdirs = file_search(pinhdirs[i]+'/*', count = Nsubdirs)
      printf, Slun
      for j = 0, Nsubdirs-1 do begin
        pinhsubsubdirs = file_search(pinhsubdirs[j]+'/chromis*' $
                                     , count = Nsubsubdirs, /fold)
        if Nsubsubdirs gt 0 then begin
          printf, Clun, 'pinh_dir = ' $
                  + red_strreplace(pinhsubdirs[j], root_dir, '')
          printf, Slun, 'a -> setpinhdir, root_dir+"' $
                  + red_strreplace(pinhsubdirs[j], root_dir, '')+'"'
;              printf, Slun, 'a -> sumpinh_new'
          for ipref = 0, Nprefilters-1 do begin
            printf, Slun, "a -> sumpinh, /pinhole_align, pref='" $
                    + prefilters[ipref]+"'" 
          endfor                ; ipref
        endif
      endfor                    ; j
    endelse
  endfor                        ; i

  
  print, 'Prefilter scan'
  printf, Clun, '#'
  printf, Clun, '# --- Prefilter scan'
  printf, Clun, '#'
  Npfs = 0
  pfscandirs = file_search(root_dir+'/*pfscan*/*', count = Ndirs, /fold)
  for i = 0, Ndirs-1 do begin
    pfscansubdirs = file_search(pfscandirs[i]+'/chromis*', count = Nsubdirs, /fold)
    if Nsubdirs gt 0 then begin
      printf, Clun, '# pfscan_dir = '+red_strreplace(pfscandirs[i], root_dir, '')
      Npfs += 1
    endif else begin
      pfscansubdirs = file_search(pfscandirs[i]+'/*', count = Nsubdirs)
      for j = 0, Nsubdirs-1 do begin
        pfscansubsubdirs = file_search(pfscansubdirs[j]+'/chromis*' $
                                       , count = Nsubsubdirs, /fold)
        if Nsubsubdirs gt 0 then begin
          printf, Clun, '# pfscan_dir = ' $
                  + red_strreplace(pfscansubdirs[j], root_dir, '')
          Npfs += 1
        endif                   ; Nsubsubdirs
      endfor                    ; j
    endelse                     ; Nsubdirs
  endfor                        ; i
  ;; If we implement dealing with prefilter scans in the pipeline,
  ;; here is where the command should be written to the script file.

  
  print, 'Science'
  printf, Clun, '#'
  printf, Clun, '# --- Science data'
  printf, Clun, '# '

  ;;  sciencedirs = file_search(root_dir+'/sci*/*', count = Ndirs, /fold)
  red_append, nonsciencedirs, pinhdirs
  red_append, nonsciencedirs, pfscandirs
  red_append, nonsciencedirs, darkdirs
  red_append, nonsciencedirs, flatdirs
  sciencedirs = file_search(root_dir+'/*/*', count = Ndirs)

  for i = 0, Ndirs-1 do begin

    if total(sciencedirs[i] eq nonsciencedirs) eq 0 then begin
      sciencesubdirs = file_search(sciencedirs[i]+'/chromis*' $
                                   , count = Nsubdirs, /fold)
      if Nsubdirs gt 0 then begin
        red_append, dirarr, red_strreplace(sciencedirs[i], root_dir, '')
      endif else begin
        sciencesubdirs = file_search(sciencedirs[i]+'/*', count = Nsubdirs)
        for j = 0, Nsubdirs-1 do begin
          sciencesubsubdirs = file_search(sciencesubdirs[j]+'/chromis*' $
                                          , count = Nsubsubdirs, /fold)
          if Nsubsubdirs gt 0 then begin
            red_append, dirarr, red_strreplace(sciencesubdirs[j], root_dir, '')
          endif
        endfor                  ; j
      endelse 
    endif
  endfor
  if n_elements(dirarr) gt 0 then printf, Clun, "data_dir = ['"+strjoin(dirarr, "','")+"']"

  printf, Slun, 'a -> link_data' 
  printf, Slun, ';a -> split_data ; For old momfbd program.' 
  
  for ipref = 0, Nprefilters-1 do begin
    printf, Slun, "a -> prepflatcubes, pref='"+prefilters[ipref]+"'"
  endfor                        ; ipref

  printf, Slun, ''
  printf, Slun, ';a -> getalignclips_new  ; For old momfbd program.' 
  printf, Slun, ';a -> getoffsets         ; For old momfbd program.' 
  printf, Slun, ';a -> pinholecalib_old   ; For old momfbd program.'

  printf, Slun, ''
  printf, Slun, 'a -> pinholecalib, thres=0.011, nref=6'
;    printf, Slun, 'a -> diversitycalib'
  
  printf, Slun, ''
  printf, Slun, ';; -----------------------------------------------------'
  printf, Slun, ';; This is how far we should be able to run unsupervised'
  printf, Slun, 'stop'          
  printf, Slun, ''

  printf, Slun, '; The fitgains step requires the user to look at the fit and determine'
  printf, Slun, '; whether npar=3 or npar=4 is needed.'
  printf, Slun, 'a -> fitgains, npar = 2, res=res' 
  printf, Slun, '; If you need per-pixel reflectivities for your analysis'
  printf, Slun, '; (e.g. for atmospheric inversions) you can set the /fit_reflectivity'
  printf, Slun, '; keyword:'
  printf, Slun, '; a -> fitgains, npar = 3, res=res, /fit_reflectivity  '
  printf, Slun, '; However, running without /fit_reflectivity is safer. In should not'
  printf, Slun, '; be used for chromospheric lines like 6563 and 8542.'
  printf, Slun, ''


  ;; sumdata_intdiff
  ;; fitprefilter
  ;; prepmomfbd

  for ipref = 0, Nprefilters-1 do begin

    printf, Slun, "a -> sum_data_intdif, pref = '" + prefilters[ipref] $
            + "', cam = 'Crisp-T', /verbose, /show, /overwrite  ; /all"
    printf, Slun, "a -> sum_data_intdif, pref = '" + prefilters[ipref] $
            + "', cam = 'Crisp-R', /verbose, /show, /overwrite  ; /all"
    printf, Slun, "a -> make_intdif_gains3, pref = '" + prefilters[ipref] $
            + "', min=0.1, max=4.0, bad=1.0, smooth=3.0, timeaver=1L, /smallscale ; /all"

    if strmid(prefilters[ipref], 0, 2) eq '63' then begin
      printf, Slun, "a -> fitprefilter, fixcav = 2.0d, pref = '"+prefilters[ipref]+"', shift=-0.5"
    endif else begin
      printf, Slun, "a -> fitprefilter, fixcav = 2.0d, pref = '"+prefilters[ipref]+"'"
    endelse
    
    printf, Slun, "a -> prepmomfbd, /wb_states, date_obs = '" + isodate + "' " $
            + ", numpoints = 128, pref = '"+prefilters[ipref]+"', margin = 5 " $
            + ", nremove=2, global_keywords= ['FIT_PLANE'] " $
            + ", modes='2-55,63-66,77,78'"

  endfor                        ; ipref

  printf, Slun, ''
  printf, Slun, ';; Run MOMFBD outside IDL.'
  printf, Slun, ''

  printf, Slun, ';; Post-MOMFBD stuff:' 

  ;; make_crispex

  ;; polish_tseries

  
  free_lun, Clun
  free_lun, Slun

  
end
