; docformat = 'rst'

;+
; 
; 
; :Categories:
;
;    CRISP pipeline
; 
; 
; :Author:
; 
; 
; 
; 
; :Params:
; 
; 
; :Keywords:
; 
;    overwrite  : 
;   
;   
;   
;    ustat  : 
;   
;   
;   
;    old  : 
;   
;   
;   
;    remove  : 
;   
;   
;   
;    check : in, optional, type=boolean
;
;
;    sum_in_rdx : in, optional, type=boolean
;
;      Bypass rdx_sumfiles.
;   
;   
;   
; 
; 
; :History:
; 
;   2013-06-04 : Split from monolithic version of crispred.pro.
; 
;   2013-08-27 : MGL. Added support for logging. Let the subprogram
;                find out its own name. Added self.done to the
;                selfinfo.
; 
;   2013-08-29 : MGL. Remove *lcd* files from file list.
; 
;   2013-10-30 : MGL. Get correct prefilter state for WB flats in the
;                presence of the focus file name field. 
; 
;   2013-12-10 : PS  Adapt for multiple flat directories; add lim
;                keyword (passthrough to red_sumfiles)
;
;   2013-12-13 : PS  Only store raw sums if requested.  Save
;                unnormalized sum and add correct number of summed
;                files in header
;
;   2014-01-23 : MGL. Use red_extractstates instead of red_getstates
;                and local extraction of info from file names.
;
;   2014-10-06 : JdlCR. Prefilter keyword, please DO NOT REMOVE!
;
;   2016-05-19 : THI: Re-write to use overloaded class methods.
; 
;   2016-05-25 : MGL. New keyword sum_in_idl. Get darks from files
;                with state info in the name.
; 
;   2016-05-26 : MGL. Use get_calib method. Base log file name on
;                flatname.
; 
;   2016-05-27 : MGL. Various fixes.
; 
;   2016-05-29 : MGL. Make a FITS header for the summed flat. Save
;                both ANA and FITS format files and do it with
;                red_writedata.
; 
;   2016-05-30 : MGL. Improve the headers.
; 
;   2016-06-09 : MGL. Make the output directory.
; 
;   2016-06-29 : MGL. New keyword outdir.
;
;   2016-08-23 : THI. Rename camtag to detector and channel to camera,
;                so the names match those of the corresponding SolarNet
;                keywords.
;
;-
pro red::sumflat, overwrite = overwrite, $
                  ustat = ustat, $
                  old = old, $
                  remove = remove, $
                  cams = cams, $
                  check = check, $
                  lim = lim, $
                  store_rawsum = store_rawsum, $
                  prefilter = prefilter, $
                  dirs = dirs, $
                  outdir = outdir, $
                  sum_in_rdx = sum_in_rdx

  ;; Defaults
  if( n_elements(overwrite) eq 0 ) then overwrite = 0

  if( n_elements(check) eq 0 ) then check = 0

  if( n_elements(dirs) gt 0 ) then dirs = [dirs] $
  else if ptr_valid(self.flat_dir) then dirs = *self.flat_dir

  if( n_elements(cams) gt 0 ) then cams = [cams] $
  else if ptr_valid(self.cameras) then cams = *self.cameras

  ;; Name of this method
  inam = strlowcase((reverse((scope_traceback(/structure)).routine))[0])

  ;; Logging
  help, /obj, self, output = selfinfo1
  help, /struct, self.done, output = selfinfo2
  red_writelog, selfinfo = [selfinfo1, selfinfo2]

  Ncams = n_elements(cams)
  if( Ncams eq 0) then begin
     print, inam+' : ERROR : undefined cams (and cameras)'
     return
  endif

  Ndirs = n_elements(dirs)
  if( Ndirs eq 0) then begin
     print, inam+' : ERROR : no flat directories defined'
     return
  endif else begin
     if Ndirs gt 1 then dirstr = '['+ strjoin(dirs,';') + ']' $
     else dirstr = dirs[0]
  endelse

  ;; cameras
  for ic = 0L, Ncams-1 do begin

     cam = cams[ic]

     self->selectfiles, cam=cam, dirs=dirs, prefilter=prefilter, ustat=ustat, $
                        files=files, states=states, nremove=remove, /force

     ;; From the above call we expect states to be an array of structures.

     nf = n_elements(files)
     if( nf eq 0 || files[0] eq '') then begin
        print, inam+' : '+cam+': no files found in: '+dirstr
        print, inam+' : '+cam+': skipping camera!'
        continue
     endif else begin
        print, inam+' : Found '+red_stri(nf)+' files in: '+ dirstr + '/' + cam + '/'
     endelse

     state_list = [states[uniq(states.fullstate, sort(states.fullstate))].fullstate]

     ns = n_elements(state_list)

     ;; Loop over states and sum
     for ss = 0L, ns - 1 do begin

        self->selectfiles, prefilter=prefilter, ustat=state_list[ss], $
                           files=files, states=states, selected=sel

        ;; Get the flat file name for the selected state
        self -> get_calib, states[sel[0]] $
                           , flatname = flatname, sflatname = sflatname, status = status

        if n_elements(outdir) ne 0 then begin
           flatname = outdir + '/' + file_basename(flatname)
           sflatname = outdir + '/' + file_basename(sflatname)
           file_mkdir, outdir
        endif else begin
           file_mkdir, file_dirname(flatname)
        endelse

        ;; If file does not exist, do sum!
        if( ~keyword_set(overwrite) && file_test(flatname) ) then begin
           if (~keyword_set(store_rawsum) $
               || file_test(sflatname)) then begin ; only skip if rawsum also exists
              print, inam+' : file exists: ' + flatname $
                     + ' , skipping! (run sumflat, /overwrite to recreate)'
              continue
           endif
        endif


        ;; Read the dark frame 
        self -> get_calib, states[sel[0]], darkdata = dd, status = status
        if status ne 0 then begin
           print, inam+' : no dark found for camera ', cam
           continue
        endif

        if( min(sel) lt 0 ) then begin
           print, inam+' : '+cam+': no files found for state: '+state_list[ss]
           continue
        endif

        print, inam+' : summing flats for state -> ' + state_list[ss]
        if(keyword_set(check)) then begin
           ;;openw, lun, self.out_dir + '/flats/'+camtag+'.'+state_list[ss]+'.discarded.txt' $
           openw, lun, flatname + '_discarded.txt', width = 500, /get_lun
        endif

        ;; Sum files
        if keyword_set(check) then begin
           ;; If summing from two directories, same frame numbers from
           ;; two directories are consecutive ans produce false drop
           ;; info. Re-sort them.
           tmplist = files[sel]
           tmplist = tmplist(sort(tmplist))
           if( keyword_set(sum_in_rdx) and rdx_hasopencv() ) then begin
              flat = rdx_sumfiles(tmplist, time_ave = time_ave, check = check, $
                                  lun = lun, lim = lim, summed = summed, nsum = nsum, verbose=2)
           endif else begin
              flat = red_sumfiles(tmplist, check = check, $
                                  time_ave = time_ave, time_beg = time_beg, time_end = time_end, $
                                  lun = lun, lim = lim, summed = summed, nsum = nsum)
           endelse
        endif else begin 
           if( keyword_set(sum_in_rdx) and rdx_hasopencv() ) then begin
              flat = rdx_sumfiles(files[sel], time_ave = time_ave, check = check, $
                                  lim = lim, summed = summed, nsum = nsum, verbose=2)
           endif else begin
              flat = red_sumfiles(files[sel], check = check, $
                                  time_ave = time_ave, time_beg = time_beg, time_end = time_end, $
                                  lim = lim, summed = summed, nsum = nsum)
           endelse
        endelse

        ;; Subtract dark and make floating point
        flat = float(flat-dd)
        
        ;; Make header
        head = red_readhead(files[0]) 
        case 1 of
           fxpar(head, 'DATE-BEG') ne '' : date = (strsplit(fxpar(head, 'DATE-BEG'), 'T', /extract))[0]
           fxpar(head, 'DATE-END') ne '' : date = (strsplit(fxpar(head, 'DATE-END'), 'T', /extract))[0]
           fxpar(head, 'DATE-AVE') ne '' : date = (strsplit(fxpar(head, 'DATE-AVE'), 'T', /extract))[0]
           else: begin
              print, 'No date info in header.'
              print, head
              stop
           end
        endcase
        check_fits, flat, head, /UPDATE, /SILENT
        sxaddpar, head, 'DATE', red_timestamp(/utc, /iso), 'Creation date of FITS header', before = 'TIMESYS'
        ;; Some SOLARNET recommended keywords:
        exptime = sxpar(head, 'XPOSURE', count=count, comment=exptime_comment)
        if count gt 0 then begin
            sxaddpar, head, 'XPOSURE', nsum*exptime, exptime_comment+' Total exposure time', format = 'f8.6'
            sxaddpar, head, 'TEXPOSUR', exptime, exptime_comment+' Single-exposure time', format = 'f9.6' $
                      , after = 'XPOSURE'
        endif
        if nsum gt 1 then sxaddpar, head, 'NSUMEXP', nsum, 'Number of summed exposures', after = 'TEXPOSUR'
        if n_elements(time_end) ne 0 then sxaddpar, head, 'DATE-END', date+'T'+time_end $
           , 'Date of end of observation', after = 'DATE'
        if n_elements(time_ave) ne 0 then sxaddpar, head, 'DATE-AVE', date+'T'+time_ave $
           , 'Average date of observation', after = 'DATE'
        if n_elements(time_beg) ne 0 then sxaddpar, head, 'DATE-BEG', date+'T'+time_beg $
           , 'Date of start of observation', after = 'DATE'

       
        ;; Add some more info here, see SOLARNET deliverable D20.4 or
        ;; later versions of that document. 

        ;; headerout = 't='+time_ave+'
        ;; n_aver='+red_stri(nsum)+' darkcorrected' print,
        ;; inam+' : saving ' + flatname file_mkdir,
        ;; file_dirname(flatname) fzwrite, flat, flatname,
        ;; headerout

        ;; Write ANA format flat
        print, inam+' : saving ', flatname
        red_writedata, flatname, flat, header=head, filetype='ANA', overwrite = overwrite

        ;; Write FITS format flat
        print, inam+' : saving ', flatname+'.fits'
        file_mkdir, file_dirname(flatname)
        red_writedata, flatname+'.fits', flat, header=head, filetype='FITS', overwrite = overwrite

        
        ;; Output the raw (if requested) and averaged flats
        if keyword_set(store_rawsum) then begin
           headerout = 't='+time_ave+' n_sum='+red_stri(nsum)
           print, inam+' : saving ' + sflatname
           file_mkdir, file_dirname(sflatname)
           flat_raw = long(temporary(summed))
           fzwrite, flat_raw, sflatname, headerout
        endif

        if keyword_set(check) then free_lun, lun


     endfor                     ; states

  endfor                        ;  cameras

end  
