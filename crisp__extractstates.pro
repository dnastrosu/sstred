; docformat = 'rst'

;+
; Extract states information from an array of strings (typically file
; names). 
;
; Substitutes original crisp__extractstates.pro that was copied to
; crisp__extractstates_nondb.pro. This procedure is a wrapper around
; db and nondb versions.
; 
; :Categories:
;
;    CRISP pipeline
; 
; 
; :Author:
; 
;     Oleksii Andriienko, ISP
; 
; 
; :Returns:
; 
; 
; :Params:
; 
;    strings : in, type=strarr
;   
;      A list of strings from which to extract the states information.
;   
;    states : out, optional, type=array(struct)
;
;        An array of structs, containing (partially filled) state information.
; 
; 
; :Keywords:
; 
;     force : in, optional, type=boolean
;
;        Do not use cached states.
; 
;     polcal : in, optional, type=boolean
; 
;        Set this to add polcal-specific items in the states, qw and
;        lp. 
;
;     strip_wb : in, optional, type=boolean
;
;        Exclude tuning information from the fullstate entries for WB
;        cameras
; 
;     strip_settings : in, optional, type=boolean
;
;        Exclude exposure/gain information from the fullstate entries.
;
;     datasets : in, optional, type = strarr
;
;        List of datasets timestamps to be used instead of list of
;        filenames. Can be used only if sst_db is installed.
; 
; 
; :History:
; 
;   2019-07-23 : OA. Created.
;   
;
;-
pro crisp::extractstates, strings, states $
                          , force = force $
                          , strip_wb = strip_wb $
                          , strip_settings = strip_settings $
                          , polcal = polcal $
                          , datasets = datasets $
                          , cam = cam
  
  if keyword_set(datasets) then begin ; if we use datasets then we should use the database
    if n_elements(datasets) eq 0 then return
    self->extractstates_db, strings, states, datasets = datasets
    return
  endif
  Nstrings = n_elements(strings)
  if Nstrings eq 0 then return
  ;; Check for raw data directories in 'strings'. We presume that we will not populate
  ;; the database with old CRISP data with different directory names
  raw_data_dirs = ['*Darks*','*Flats*','*Pinholes*','*Polcal*','*Science*','*CRISP/data/*']
  is_raw = 0B
  for i=0,5 do begin
    bb = strmatch(strings,raw_data_dirs[i])
    ss = where(bb eq 1)
    if n_elements(ss) gt 1 then begin
      is_raw = 1B
      break  ; we should not have raw and processed data files in one call
    endif else if n_elements(ss) eq 1 and ss ne -1 then begin
      is_raw = 1B
      break 
    endif
  endfor
  if is_raw and self.db_present then begin ; we can use sst_db only with raw data
    self->extractstates_db, strings, states, cam = cam
  endif else begin
    self->extractstates_nondb, strings, states $
                               , force = force $
                               , strip_wb = strip_wb $
                               , strip_settings = strip_settings $
                               , polcal = polcal
  endelse

  return

end


