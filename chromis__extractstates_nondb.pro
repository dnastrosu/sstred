; docformat = 'rst'

;+
; Extract states information from an array of strings (typically file
; names). 
;
; Replaces the various versions of red_getstates. Based on regular
; expressions and vectorization.
; 
; :Categories:
;
;    CRISP pipeline
; 
; 
; :Author:
; 
;     Mats Löfdahl, ISP
; 
; 
; :Returns:
; 
; 
; :Params:
; 
;    strings : in, type=strarr
;   
;        A list of strings from which to extract the states
;        information.
;   
;    states : out, optional, type=array(struct)
;
;        An array of structs, containing (partially filled) state
;        information.
; 
; 
; :Keywords:
;
;     force : in, optional, type=boolean
;
;        Do not use cached states.
;
;     strip_settings : in, optional, type=boolean
;
;        Exclude exposure/gain information from the fullstate entries.
; 
; 
; :History:
; 
;   2014-01-22 : First version.
; 
;   2014-04-?? : MGL. Added keyword wavelength.
;
;   2015-09-03 : MGL. Added the "blue" keyword, will now return
;                something meaningful also for blue tilt filter data.
;                Bugfix in qw regular expression.
;
;   2016-05-19 : THI. Partial copy to the crisp class. Modify the
;                state structures and keywords for clarity.
;
;   2016-05-24 : MGL. Removed polarization stuff. If the strings are
;                filenames, then look in the headers. Added keywords
;                gain and exposure, return this information if wanted.
;                Make the keyword fullstate set the other keywords.
;
;   2016-05-25 : MGL. Do not assume camera gain is integer. Get some
;                info not in the header from the file names for now.
;                Move comments to where they are needed.
;
;   2016-05-27 : MGL. Get more information from the headers.
;
;   2016-05-30 : MGL. Trim some whitespace. Strip trailing dots in
;                fullstate_list when there is no tuning. Set
;                scannumber and framenumber if fullstate is set. 
;
;   2016-05-31 : MGL. Detect whether filter1 keyword exists.
;
;   2016-05-31 : JLF. Begin using red_keytab to keep track of changing
;		 SOLARNET keywords. 
;
;   2016-06-01 : MGL. Get prefilter wavelengths from header. Remove
;                the boolean keywords that select info to be returned,
;                just return all info possible. Also the basename
;                boolean keyword doesn't seem to do anything. Rewrite
;                to work directly with the struct and not intermediate
;                arrays.
;
;   2016-06-01 : THI. Added gain & exposure to fullstate. Added
;                keywords strip_wb (to exclude tuning from fullstate
;                for WB cameras) and strip_settings (to exclude gain
;                and exposure from fullstate for pinholes).  
;
;   2016-06-02 : MGL. Added progress printout. 
;
;   2016-06-03 : MGL. Filter headers silently.
;
;   2016-06-09 : MGL. Trim filter string. Build the fullstate string
;                so it never starts with an underscore.
;
;   2016-06-09 : JLF. Bugfix. cam_settings couldn't handle exposure times
;		 f.o.m 10 msec, produced ****ms_G??.??. 
;
;   2016-06-09 : MGL. Change exposure time format to handle longer
;                exposures while preserving format for short
;                exposures. 
;
;   2016-08-23 : THI. Rename camtag to detector and channel to camera,
;                so the names match those of the corresponding SolarNet
;                keywords.
;
;   2016-09-06 : MGL. Call red_meta2head rather than
;                red_filterchromisheaders. 
;
;   2016-09-19 : MGL. Let the subprogram find out its own name. Added
;                conversion from HRE digital units to wavelength
;                tuning.
;
;    2016-09-21 : MGL. Work in meters, not Å or mÅ. Typos hzr --> hrz.
;
;    2016-09-22 : MGL. Make exception for darks when looking for
;                 tuning info.
;
;    2016-09-27 : MGL. Detect is_wb also if the camera is not already
;                 known. 
;
;    2016-09-28 : MGL. Use TEXPOSUR for cam_settings of summed files.
;                 Parse STATE correctly. FULLSTATE for darks without
;                 tuning info. Do not complain if calling from
;                 hrz_zeropoint.
;
;    2016-10-13 : MGL. Added nframes state keyword.  
;
;    2016-10-27 : MGL. Put the camera into the states if found.
;
;    2017-05-08 : MGL. Match camera name to get WB status.
; 
;    2017-06-19 : MGL. Use red_fitspar_getwavelnth.
; 
;    2017-12-01 : MGL. Cache states during IDL session. New keyword
;                 force.
;
;    2019-07-23 : OA. Renamed to chromis::exctractstates_nodb, from
;                 now on chromis::extractstates is a wrapper around db
;                 and nondb versions.
;
;-
pro chromis::extractstates_nondb, strings, states $
                            , force = force $
                            , strip_settings = strip_settings
  
  ;; Name of this method
  inam = strlowcase((reverse((scope_traceback(/structure)).routine))[0])

  ;; Don't complain about hrz_zeropoint isn't run already when
  ;; that's what we are doing!
  st = scope_traceback(/structure)
  if st[1].routine eq 'CHROMIS::HRZ_ZEROPOINT' then quiet = 1 else quiet = 0

  strings = strtrim(strings,2)
  idx = where( strings ne '' )
  if min(idx) ge 0 then strings = strings[ idx ] $
  else return
  Nstrings = n_elements(strings)
  if( Nstrings eq 0 ) then return

  ;; Create array of structs to holed the state information
  states = replicate( {CHROMIS_STATE}, Nstrings )
  states.nframes = 1            ; single frame by default

  ;; Read headers and extract information. This should perhaps return
  ;; an array the length of the number of frames rather than the
  ;; number of files?

  for ifile = 0, Nstrings-1 do begin

    if keyword_set(force) then $
       cnt = 0 $
    else $
       this_cache = rdx_cacheget(strings[ifile], count = cnt)
    
    if cnt gt 0 then begin

      red_progressbar, ifile, Nstrings, 'Extract state info from cache', /predict

      states[ifile] = this_cache.state
      
    endif else begin
      
      red_progressbar, ifile, Nstrings, 'Extract state info from file headers', /predict
      status = -1
      if file_test(strings[ifile]) then begin
        head = red_readhead(strings[ifile], /silent, status=status)
        states[ifile].filename = strings[ifile]
      endif else begin
        print,'file does not exist: ', strings[ifile]
        print,'state information will be incomplete!'
      endelse
      if status ne 0 then begin
        mkhdr, head, ''         ; create a dummy header
        head = red_meta2head(head, metadata = {filename:strings[ifile]})
      endif
      
      ;; Numerical keywords
      naxis3 = fxpar(head, 'NAXIS3', count=hasnframes)
      if hasnframes then states[ifile].nframes = naxis3
      states[ifile].gain = fxpar(head, 'GAIN', count=hasgain)
      ;; New keyword for gain from 2016.08.30:
      if hasgain eq 0 then states[ifile].gain = fxpar(head, 'DETGAIN', count=hasgain) 
      states[ifile].exposure = fxpar(head, 'XPOSURE', count=hasexp)
      texposur = fxpar(head, 'TEXPOSUR', count=hastexp)

      red_fitspar_getwavelnth, head, wavelnth = wavelnth, haswav = haswav
      if haswav ne 0 then begin
;      if wavelnth ne '        ' then $
        states[ifile].pf_wavelength = float(wavelnth)
      endif

      states[ifile].scannumber = fxpar(head, red_keytab('scannumber'))
      states[ifile].framenumber = fxpar(head, red_keytab('framenumber'))

      state = fxpar(head, 'STATE', count=hasstate)
      if hasstate gt 0 then begin
        states[ifile].fpi_state = state
        state_split = strsplit( state, '_',  /extr )
        if n_elements(state_split) gt 1 then begin
          states[ifile].tuning = state_split[1]
        endif
      endif
      
      ;; String keywords require checking
      detector = fxpar(head, red_keytab('detector'), count=count)
      if count eq 0 then begin  ; Temporary fugly hack to work on data processed before 2016-08-23
        detector = fxpar(head, red_keytab('camera'), count=count)
      endif
      if count gt 0 then states[ifile].detector = strtrim(detector, 2)
      filter = fxpar(head, red_keytab('prefilter'), count=count)
      if count gt 0 then states[ifile].prefilter = strtrim(filter, 2)
      camera = fxpar(head, red_keytab('camera'), count=count)
      ;;camera = fxpar(head, red_keytab('old_channel'), count=count)   ; Temporary fugly hack to work on data processed before 2016-08-23

      if count gt 0 then begin
        ;; The camera is given in the header
        camera = strtrim(camera,2)
        states[ifile].camera = camera
;      states[ifile].is_wb = strmatch(states[ifile].camera,'*-[DW]') 
;      if camera eq 'Chromis-W' or camera eq 'Chromis-D' then states[ifile].is_wb = 1
      endif else begin
        ;; Try to get the camera from the detector
        self->getdetectors
        indx = where(strmatch(*self.detectors,strtrim(detector, 2)),count) 
        if count eq 1 then begin
          camera = (*self.cameras)[indx[0]]
          states[ifile].camera = camera
;        if camera eq 'Chromis-W' or camera eq 'Chromis-D' then states[ifile].is_wb = 1
        endif                   ;else begin
;        ;; This could be a CRISP file. Try to set the WB status by
;        ;; matching the directory.
;        states[ifile].is_wb = strmatch(strings[ifile],'*Crisp-[DW]*')
;      endelse
      endelse
      states[ifile].is_wb = strmatch(states[ifile].camera,'*-[DW]') 

      if hastexp then begin
        ;; This is a summed file, use the single-exposure exposure
        ;; time for the camera setting.
        states[ifile].cam_settings = strtrim(string(texposur*1000 $
                                                    , format = '(f9.2)'), 2) + 'ms'
      end else if hasexp gt 0 then begin
        ;; This is not a summed file.
        states[ifile].cam_settings = strtrim(string(states[ifile].exposure*1000 $
                                                    , format = '(f9.2)'), 2) + 'ms'
      endif

      if hasgain gt 0 then begin
        if hasexp gt 0 then states[ifile].cam_settings += '_'
        states[ifile].cam_settings += 'G' + string(states[ifile].gain, format = '(f05.2)')
      endif

      ;; Replace the following regexp code when this info is in the
      ;; header.

      fname = file_basename(strings[ifile], '.fits')

      ;; The focus field is an f followed by a sign and at least one
      ;; digit for the amount of focus (in ?unit?). The focus added by
      ;; the AO system (in order to compensate for prefilters with
      ;; optical power). Unit?
      focus = (stregex(fname $
                       , '(\.|^)(F[+-][0-9]+)(\.|$)' $
                       , /extr, /subexp, /fold_case))[2,*]
      ;; states.focus = focus   TODO: add field to states struct (in an SST class?)

      ;; The CRISP tuning information consists of a four digit
      ;; wavelength (in Å) followed by an underscore, a sign (+ or -),
      ;; and at least one digit for the finetuning (in mÅ). Eventually
      ;; we will (?) have the same for CHROMIS.
      tuninfo = stregex(fxpar(head, 'STATE') $
                        , '([0-9][0-9][0-9][0-9])_([+-][0-9]*)' $
                        , /extract, /subexpr) 

      ;; For early CHROMIS data we didn't have tuning data in the
      ;; proper form.
      if strlen(tuninfo[0]) ne 0 then begin

        ;; OK, the tuning info is in the form it should be.
        states[ifile].tuning = tuninfo[0]
        
        ;; Also return the tuning in decimal form [m]:
        states[ifile].tun_wavelength = total(double(tuninfo[1:2])*[1d-10, 1d-13])
        
      endif else begin

        if states[ifile].is_wb then begin
          ;; For wideband, if there is no tuning info, assume
          ;; prefilter wavelength.
          states[ifile].tun_wavelength = states[ifile].pf_wavelength
          states[ifile].tuning = string(round(states[ifile].tun_wavelength*1d10) $
                                        , format = '(i04)') $
                                 + '_+0'
        endif else begin
          ;; The tuning information is in digital units, corresponding
          ;; to tuning. The conversion factor varies between filters.
          ;; The scans are symmetrical (so far, 2016-09-16) around the
          ;; line center, which gives us the zero point.

          ;; Get the reference wavelength in du from a file previously
          ;; created with chromis::hrz_zeropoint.
          infodir = self.out_dir + 'info/'
          zfile = infodir + 'hrz_zeropoint_' + states[ifile].prefilter + '.fz'

          if file_test(zfile) then begin

            refinfo = f0(zfile)
            lambda_ref = refinfo[0]
            du_ref     = refinfo[1]
            convfac    = refinfo[2]
            
            ;; Tuning in digital units
            du = long((stregex(fxpar(head,'STATE'), 'hrz([0-9]*)', /extract, /subexpr))[1])

            ;; Tuning in [m]
            dlambda = convfac * (du-du_ref) 

            ;; Return the wavelength tuning information in the form
            ;; tuning_finetuning, where tuning is the approximate
            ;; wavelength in Å and finetuning is the (signed) fine
            ;; tuning in mÅ. (string)
            lambda_ref_string = string(round(lambda_ref*1d10), format = '(i04)')
            tuning_string = strtrim(round(dlambda*1d13), 2)
            if strmid(tuning_string, 0, 1) ne '-' then tuning_string = '+'+tuning_string
            states[ifile].tuning = lambda_ref_string + '_' + tuning_string
            
            ;; Also return the tuning in decimal form [m]:
            states[ifile].tun_wavelength = lambda_ref + dlambda

          endif else begin

            if strmatch(states[ifile].filename, file_dirname((*self.dark_dir)[0])+'*') then begin
              ;; For darks there is no tuning info. This is a kludge,
              ;; should really set something like states.is_dark and
              ;; test for that?
              states[ifile].tun_wavelength = 0
              states[ifile].tuning = ''
            endif else begin
              ;; Warn about missing tuning info, but only for
              ;; narrowband.
              if ~quiet then begin
                print, inam + ' : Reference wavelength in du missing.'
                print, inam + ' : Did you run a -> hrz_zeropoint?'
              endif
            endelse
            
          endelse               ; zfile
          
        endelse                 ; wb

      endelse                   ; tuninfo

      if states[ifile].tuning eq '0000_+0' then states[ifile].tuning = ''

      ;; The fullstate string
      undefine, fullstate_list
      if ~keyword_set(strip_settings) then red_append, fullstate_list, states[ifile].cam_settings
      if states[ifile].prefilter ne '' then red_append, fullstate_list, states[ifile].prefilter
      if states[ifile].tuning ne '' then $             
          red_append, fullstate_list, states[ifile].tuning
      states[ifile].fullstate = strjoin(fullstate_list, '_')

      ;; Store in cache
      rdx_cache, strings[ifile], { state:states[ifile] }

    endelse
    
  endfor                        ; ifile
  
end


a = chromisred('config.txt', /dev)


;; Test caching

dirN = '/storage/sand02/Incoming/2016.09.11/CHROMIS-flats/*/Chromis-N/'
dirW = '/storage/sand02/Incoming/2016.09.11/CHROMIS-flats/*/Chromis-W/'
fnamesW = file_search(dirW+'*fits', count = NfilesW)
fnamesN = file_search(dirN+'*fits', count = NfilesN)

tic
a -> extractstates, fnamesN, statesN1
toc

tic
a -> extractstates, fnamesW, statesW
toc

tic
a -> extractstates, fnamesN, statesN1
toc

tic
a -> extractstates, fnamesN, statesN2, /force
toc


tic
a -> extractstates, fnamesW, statesW
toc

stop

;; Test darks
files = file_search('darks/cam*.dark', count = Nfiles)
a -> extractstates, files, states

stop

;; Test flats
files = file_search('flats/camXXX_*.flat', count = Nfiles)
a -> extractstates, files, states


stop

;; Test narrowband
dirN = '/storage/sand02/Incoming/2016.09.11/CHROMIS-flats/*/Chromis-N/'
fnamesN = file_search(dirN+'*fits', count = NfilesN)
if NfilesN gt 0 then a -> extractstates, fnamesN, statesN

stop

;; Test wideband
dirW = '/storage/sand02/Incoming/2016.09.11/CHROMIS-flats/*/Chromis-W/'
fnamesW = file_search(dirW+'*fits', count = NfilesW)
if NfilesW gt 0 then a -> extractstates, fnamesW, statesW

end
