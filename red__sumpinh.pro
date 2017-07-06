; docformat = 'rst'

;+
; Sum pinhole images.
; 
; :Categories:
;
;    CRISP pipeline
; 
; 
; :author:
; 
; 
; 
; :Keywords:
; 
;    nthreads : in, optional, type=integer, default=2
;   
;      The number of threads to use for bad-pixel filling.
;   
;    no_descatter : in, optional, type=boolean 
;   
;      Don't do back-scatter compensation.
;   
;    ustat : in, optional, type=string
;   
;      Do only for this state.
;   
;    pref : in, optional, type=string
;   
;       Set this keyword to the prefilter you want to sum pinholes
;       from. Otherwise, sum pinholes for all prefilters.
;   
;    pinhole_align : in, optional, type=boolean
; 
;       If true, then perform subpixel alignment of pinholes before
;       summing. 
; 
;    brightest_only : in, optional, type=boolean
;
;       Set this to only sum (one of) the brightest tunings for each
;       prefilter. 
;
;    lc_ignore : in, optional, type=boolean
;
;       Set this to treat all lc states as if they were the same.
; 
; :History:
; 
;   2013-06-04 : Split from monolithic version of crispred.pro.
; 
;   2013-08-15 : MGL. Added keyword pinhole_align. Process cameras in
;                loops instead of separately.
; 
;   2013-08-27 : MGL. Added support for logging. Let the subprogram
;                find out its own name.
; 
;   2013-08-29 : MGL. Made use of nthread consistent. Loop over
;                cameras rather than treating them one by one.
; 
;   2013-08-30 : MGL. When keyword pinhole_align is set, request that
;                red_sumfiles do: dark, flat, fillpix, alignment
;                before summing.
; 
;   2013-09-02 : MGL. Two new keywords, brightest_only and lc_ignore
;                (but they don't actually do anything yet).
; 
;   2013-09-03 : MGL. Fixed descattering bug.
; 
;   2013-09-04 : MGL. Store also in floating point. This is the
;                version used in red::pinholecalib.pro.
; 
;   2016-02-15 : MGL. Use loadbackscatter. Remove keyword descatter,
;                new keyword no_descatter.
; 
;   2016-05-31 : THI. Re-write to use the class-methods.
; 
;   2016-08-23 : THI. Rename camtag to detector and channel to camera,
;                so the names match those of the corresponding SolarNet
;                keywords.
; 
;   2017-04-13 : MGL. Construct SOLARNET metadata fits header.
; 
;   2017-07-06 : THI. Get framenumbers and timestamps from rdx_sumfiles
;                and pass them on to red_sumheaders.
;
;
;-
pro red::sumpinh, nthreads = nthreads $
                  , no_descatter = no_descatter $
                  , ustat = ustat $
                  , prefilter = prefilter $
                  , cams = cams $
                  , dirs = dirs $
                  , pinhole_align = pinhole_align $
                  , brightest_only = brightest_only $
                  , lc_ignore = lc_ignore $
                  , overwrite = overwrite $
                  , sum_in_rdx = sum_in_rdx

  if( n_elements(dirs) gt 0 ) then dirs = [dirs] $
  else if ptr_valid(self.pinh_dirs) then dirs = *self.pinh_dirs
  
  if(n_elements(cams) eq 0 and ptr_valid(self.cameras)) then cams = *self.cameras
  if(n_elements(cams) eq 1) then cams = [cams]

  ;; Prepare for logging (after setting of defaults).
  ;; Set up a dictionary with all parameters that are in use
  prpara = dictionary()
  ;; Boolean keywords
  if keyword_set(no_descatter) then prpara['no_descatter'] = no_descatter
  if keyword_set(overwrite) then prpara['overwrite'] = overwrite
  if keyword_set(sum_in_rdx) then prpara['sum_in_rdx'] = sum_in_rdx
  if keyword_set(pinhole_align) ne 0 then prpara['pinhole_align'] = pinhole_align
  if keyword_set(brightest_only) ne 0 then prpara['brightest_only'] = brightest_only
  ;; Non-boolean keywords
  if n_elements(cams) ne 0 then prpara['cams'] = cams
  if n_elements(dirs) ne 0 then prpara['dirs'] = dirs
  if n_elements(prefilter) ne 0 then prpara['prefilter'] = prefilter
  if n_elements(ustat) ne 0 then prpara['ustat'] = ustat
;  if keyword_set() then prpara[''] = 
;  if keyword_set() then prpara[''] = 
;  if keyword_set() then prpara[''] = 

  ;; Name of this method
  inam = strlowcase((reverse((scope_traceback(/structure)).routine))[0])
  
;  ;; Logging
;  help, /obj, self, output = selfinfo 
;  red_writelog, selfinfo = selfinfo

  if n_elements(nthreads) eq 0 then nthread = 2 else nthread = nthreads

  Ncams = n_elements(cams)
  if( Ncams eq 0) then begin
    print, inam+' : ERROR : undefined cams (and cameras)'
    return
  endif

  Ndirs = n_elements(dirs)
  if( Ndirs eq 0) then begin
    print, inam+' : ERROR : no pinhole directories defined'
    return
  endif else begin
    if Ndirs gt 1 then begin
      dirstr = '['+ strjoin(dirs,';') + ']'
      print,'WARNING: sumpinh was called with multiple directories.'
      print,'Only the first directory will be used.'
      print,"To use a particular directory, use: a->sumpinh,dir='path/to/phdata'"
      dirs = [dirs[0]]
    endif else dirstr = dirs[0]
    dirstr = dirs[0]            ; remove when we can properly deal with multiple directories.
  endelse

  if ~file_test(dirs,/directory) then begin
    print, inam + ' : ERROR : "'+dirs+'" is not a directory'
    return
  endif
  
  ;; Loop over cameras
  for icam = 0, Ncams-1 do begin

    cam = cams[icam]
    detector = self->getdetector( cam )

    self->selectfiles, cam=cam, dirs=dirs, prefilter=prefilter, ustat=ustat, $
                       files=files, states=states, /force

    nf = n_elements(files)
    if( nf eq 0 || files[0] eq '') then begin
      print, inam+' : '+cam+': no files found in: '+dirstr
      print, inam+' : '+cam+': skipping camera!'
      continue
    endif else begin
      print, inam+' : Found '+red_stri(nf)+' files in: '+ dirstr + '/' + cam + '/'
    endelse

    state_list = states[uniq(states.fpi_state, sort(states.fpi_state))]

    Nstates = n_elements(state_list)
    ;; Loop over states and sum
    for istate = 0L, Nstates - 1 do begin
      
      this_state = state_list[istate]
      sel = where(states.fpi_state eq this_state.fpi_state)

      ;; Get the flat file name for the selected state
      self -> get_calib, states[sel[0]], darkdata = dd, flatdata = ff, $
                         pinhname = pinhname, status = status
      if( status ne 0 ) then begin
        print, inam+' : failed to load calibration data for:', states[sel[0]].filename
        continue
      endif
      
      ;; If file does not exist, do sum!
      if( ~keyword_set(overwrite) && file_test(pinhname) ) then begin
        print, inam+' : file exists: ' + pinhname + ' , skipping! (run sumpinh, /overwrite to recreate)'
        continue
      endif

      if( n_elements(sel) lt 1 || min(sel) lt 0 ) then begin
        print, inam+' : '+cam+': no files found for state: '+state_list[istate].fullstate
        continue
      endif
      
      pref = states[sel[0]].prefilter
      print, inam+' : adding pinholes for state -> ' + state_list[istate].fpi_state
      
      DoBackscatter = 0
      if (~keyword_set(no_descatter) AND self.dodescatter AND (pref eq '8542' OR pref eq '7772')) then begin
        self -> loadbackscatter, detector, pref, bgt, Psft
        DoBackscatter = 1
      endif
      if DoBackscatter gt 0 then begin
        ff = red_cdescatter(ff, bgt, Psft, /verbose, nthreads = nthread)
      endif
      gain = self->flat2gain(ff)

      ;; Sum files

      ;; Dark and flat correction and bad-pixel filling done by
      ;; red_sumfiles on each frame before alignment.
      if rdx_hasopencv() and keyword_set(sum_in_rdx) then begin
        psum = rdx_sumfiles(files[sel], pinhole_align=pinhole_align, dark=dd, $
                 gain=gain, backscatter_gain=bgt, backscatter_psf=Psft, $
                 nsum=nsum, framenumbers=framenumbers, time_beg=time_beg, $
                 time_end=time_end, time_avg=time_avg, verbose=2 )
      endif else begin
        psum = red_sumfiles(files[sel], pinhole_align=pinhole_align, dark=dd, gain=gain, $
                            backscatter_gain=bgt, backscatter_psf=Psft, nsum=nsum)
      endelse

      ;; Make FITS headers 
      head  = red_sumheaders(files[sel], psum, nsum=nsum, framenumbers=framenumbers, $
                             time_beg=time_beg, time_end=time_end, time_avg=time_avg)
      fxaddpar, head, 'FILENAME', file_basename(pinhname), after = 'DATE'

      ;; Add some more info here, see SOLARNET deliverable D20.4 or
      ;; later versions of that document.

      self -> headerinfo_addstep, head, prstep = 'Pinhole summing' $
                                  , prproc = inam, prpara = prpara

      file_mkdir, file_dirname(pinhname)

      print, inam+' : saving ' + pinhname
      if keyword_set(pinhole_align) then begin
        red_writedata, pinhname, psum, header=head, filetype='ANA', overwrite = overwrite
      endif else begin
        red_writedata, pinhname, fix(round(10. * psum)), header=head, filetype='ANA', overwrite = overwrite
      endelse

    endfor                      ; istate

  endfor                        ; icam

end
