; docformat = 'rst'

;+
; Calculates the combined FITS header for files summed with
; red_sumfiles or rdx_sumfiles or by momfbd processing.
; 
; :Categories:
;
;    SST pipeline
; 
; 
; :Author:
; 
;    Mats Löfdahl
; 
; 
; :Returns:
; 
;    The combined header.
; 
; :Params:
; 
;    files : in, type=strarr
;
;      The names of the summed files.
; 
;    sum : in, type=array
;
;      The array representing the summed files.
;
; :Keywords:
; 
;    discard : in, optional, type=string
;
;      Corresponding to the redux program's discard keyword.
;
;    nsum : in, optional, type=integer
;      
;      The number of summed frames. Specify this if some were excluded
;      from the sum. 
; 
;    framenumbers : in, optional, type=intarr
;      
;      Framenumbers to be used for the supplied files. If not supplied,
;      the framenumbers will be parsed from the headers. 
; 
;    time_beg : in, optional, type=string
;      
;      The start-time for the summed burst.
; 
;    time_end : in, optional, type=string
;      
;      The end-time for the summed burst.
; 
;    time_avg : in, optional, type=string
;      
;      The average time for the summed burst.
;
;    If any of the time_* keywords is not supplied, the headers will be
;    parsed instead.
; 
; :History:
; 
;    2017-03-13 : MGL. First version.
; 
;    2017-03-21 : MGL. New keywords discard.
; 
;    2017-06-02 : MGL. Use red_fitsaddpar.
; 
;    2017-07-06 : THI. Adding keywords: framenumbers, time_beg, time_end, time_avg
; 
;-
function red_sumheaders, files, sum $
                       , nsum = nsum $
                       , discard = discard $
                       , framenumbers = framenumbers $
                       , time_beg = time_beg $
                       , time_end = time_end $
                       , time_avg = time_avg

  if n_elements(nsum) gt 0 and n_elements(discard) gt 0 then begin
    print, 'red_sumheaders : Do not use both nsum and discard.'
    stop
  endif
    
  Nfiles = n_elements(files)
  if Nfiles eq 0 then begin
      print, 'red_sumheaders: no files provided.'
      return,''
  endif
    
  get_framenumbers = 0
  if n_elements(framenumbers) eq 0 then get_framenumbers = 1
  
  get_times = 0
  if n_elements(time_beg) eq 0 || $
     n_elements(time_end) eq 0 || $
     n_elements(time_avg) eq 0 then get_times = 1
  
  if get_framenumbers || get_times then begin ; we need to parse the headers
    for ifile = 0, Nfiles-1 do begin
      
      head = red_readhead(files[ifile])

      ;; The number of frames in the file
      Nframes = fxpar(head, 'NAXIS3', count = count)

      if count eq 0 then begin
        Nframes = 1
        if n_elements(discard) ne 0 then if total(float(discard)) gt 0.0 then continue
        indx = [0]
      endif else begin
        indx = lindgen(Nframes)
        if n_elements(discard) ne 0 then begin
          ;; DISCARD can be one number or two comma-separated numbers.
          discard = strsplit(discard, ',', /extract)
          ;; Are we discarding all frames?
          if total(long(discard)) ge Nframes then continue
          ;; First element is the number of frames discarded from the
          ;; beginning.
          indx = indx[long(discard[0]):*]
          ;; Second element (if any) is the number of frames
          ;; discarded from the end.
          if n_elements(discard) gt 1 then $
             indx = indx[0:-1-long(discard[1])]
        endif
      endelse

      ; only get framenumbers if necessary
      if get_framenumbers then begin
        frame_numbers_thisfile = indx + fxpar(head, 'FRAMENUM', count = count)
        if count gt 0 then red_append, framenumbers, frame_numbers_thisfile[indx]
      endif

      ; only get timestamps if necessary
      if get_times then begin
        tab_hdus = fxpar(head, 'TAB_HDUS')
        if tab_hdus ne '' then begin
          tab = readfits(files[ifile], theader, /exten, /silent)
          date_beg_thisfile = ftget(theader,tab, 'DATE-BEG') 
          red_append, date_beg_array, date_beg_thisfile[indx]
        endif else begin
          red_append, date_beg_array, fxpar(head, 'DATE-BEG')
        endelse
      endif
    endfor                        ; ifile
  endif else begin
    head = red_readhead(files[0]) ; read a single header to use as template
  endelse
  
  if n_elements(Nsum) eq 0 then begin
    Nsum = n_elements(framenumbers)
  endif else begin
    if n_elements(framenumbers) ne Nsum then begin
      ;; If we could get info about the rejected frame numbers from
      ;; both red_sumfiles and rdx_sumfiles we could use that here!
      print, 'red_sumheaders : n_elements(framenumbers) ne Nsum'
      print, '   The DATE_??? and FNUMSUM keywords may be slightly off.' 
;      stop
    endif
  endelse

  ;; Assume all file headers are the same, except for frame numbers,
  ;; timestamps, etc. We use info from the latest read header and
  ;; modify it where necessary.
  
  ;; Update header with respect to summed array
  if n_elements(sum) then begin
    check_fits, sum, head, /UPDATE, /SILENT        
  endif else begin
    ;; Remove NAXIS* keywords
    naxis = fxpar(head, 'NAXIS', count = count)
    for iaxis = 0, naxis-1 do sxdelpar, head, 'NAXIS'+strtrim(iaxis+1, 2)
    red_fitsaddpar, head, 'NAXIS', 0
  endelse

  ;; New date, at better position
  sxdelpar, head, 'DATE'
  red_fitsaddpar, anchor = anchor, after = 'SOLARNET', /force, head $
                  , 'DATE', red_timestamp(/iso), 'Creation UTC date of FITS header '

  ;; Remove some irrelevant keywords
  sxdelpar, head, 'TAB_HDUS'    ; No tabulated headers in summed file
  sxdelpar, head, 'FRAMENUM'    ; No particular frame number (unless we want to tabulate the input frame numbers?)
  sxdelpar, head, 'SCANNUM'     ; No particular scan number
  sxdelpar, head, 'FILENAME'    ; Add this later!
  sxdelpar, head, 'CADENCE'     ; Makes no sense to keep?

  ;; Exposure times etc.
  exptime = sxpar(head, 'XPOSURE', count=count, comment=exptime_comment)
  red_fitsaddpar, anchor = anchor, head $
                  , 'XPOSURE', nsum*exptime, '[s] Total exposure time'
  red_fitsaddpar, anchor = anchor, head $
                  , 'TEXPOSUR', exptime, '[s] Single-exposure time'
  red_fitsaddpar, anchor = anchor, head $
                  , 'NSUMEXP', nsum, 'Number of summed exposures'
  
  ;; List of frame numbers (re-use FRAMENUM for this)
  red_fitsaddpar, anchor = anchor, head $
                  , 'FRAMENUM', red_collapserange(framenumbers,ld='',rd='') $
                  , 'List of frame numbers in the sum'

  ;; DATE-??? keywords, base them on the tabulated timestamps
  date_obs = (strsplit(fxpar(head, 'DATE-OBS'), 'T',/extract))[0]
  anchor = 'DATE-OBS'
  if get_times then begin
    times = red_time2double(strmid(date_beg_array,11))
    time_beg = red_timestring(min(times))
    time_end = red_timestring(max(times)+exptime)
    time_avg = red_timestring(mean(times)+exptime/2)
  endif
  if n_elements(time_beg) ne 0 then $
     red_fitsaddpar, anchor = anchor, head $
                     , 'DATE-BEG', date_obs+'T'+time_beg $
                     , 'Start time of summed observation'
  if n_elements(time_avg) ne 0 then $
     red_fitsaddpar, anchor = anchor, head $
                     , 'DATE-AVG', date_obs+'T'+time_avg $
                     , 'Average time of summed observation'
  if n_elements(time_end) ne 0 then $
     red_fitsaddpar, anchor = anchor, head $
                     , 'DATE-END', date_obs+'T'+time_end $
                     , 'End time of summed observation'

  ;; Add "global" metadata
  red_metadata_restore, head

  return, head

end
