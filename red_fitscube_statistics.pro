; docformat = 'rst'

;+
; Calculate statistics for the frames in a fitscube file.
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
; :Params:
; 
;   filename : in, type=string
; 
;   frame_statistics : out, optional, type=array
;
;      Frame by frame statistics.
;
;   cube_statistics : out, optional, type=array
;
;      Statistics for the entire cube.
;
; :Keywords:
; 
;   angles : in, optional, type=array
;   
;      Rotation angles for the frames in the cube.
;   
;   cube_comments : out, optional, type=strarr
;   
;      
;   
;   full : in, optional, type=array
;   
;      Parameters that determine the array size of the frames after
;      rotations and shifts.
;   
;   grid : in, optional, type=array
;   
;      Stretch vectors.
;   
;   origNx : in, optional, type=float 
;   
;      Frame size before rotation and shifts.
;   
;   origNy :  in, optional, type=float
;   
;     Frame size before rotation and shifts.
;   
;   percentiles : in, out, optional
;   
;     The percentiles to calculate.
;   
;   write : in, optional, type=boolean
;   
;     Write the statistics to the fitscube. 
;   
;   shifts : in, optional, type=array
;   
;     Shift vectors.
; 
; 
; :History:
; 
;   2019-03-28 : MGL. First version.
; 
;-
pro red_fitscube_statistics, filename $
                             , frame_statistics, cube_statistics $
                             , angles = angles $
                             , cube_comments = cube_comments $
                             , full = full $
                             , grid = grid $
                             , origNx = origNx $
                             , origNy = origNy $
                             , percentiles = percentiles $
                             , write = write $
                             , shifts = shifts 

  if n_elements(percentiles) eq 0 then percentiles = [.01, .10, .25, .50, .75, .90, .95, .98, .99]
  
  ;; Use angles, shifts, full (if given) to calculate masks that
  ;; select the rotated and shifted area. Can we do something with
  ;; grid as well? Maybe use magnitude of grid shifts to calculate a
  ;; margin around the area?

  
  ;; Open the file and set up an assoc variable.
  hdr = headfits(filename)

  naxis = fxpar(hdr, 'NAXIS*')
  Nx      = naxis[0]
  Ny      = naxis[1]
  Ntuning = naxis[2]
  Nstokes = naxis[3]
  Nscans  = naxis[4]

  bitpix = fxpar(hdr, 'BITPIX')
  case bitpix of
    16 : array_structure = intarr(Nx, Ny)
    -32 : array_structure = fltarr(Nx, Ny)
    else : stop
  endcase

  Nlines = where(strmatch(hdr, 'END *'), Nmatch)
  Npad = 2880 - (80L*Nlines mod 2880)
  Nblock = (Nlines-1)*80/2880+1 ; Number of 2880-byte blocks
  offset = Nblock*2880          ; Offset to start of data

  openr, lun, filename, /get_lun, /swap_if_little_endian
  fileassoc = assoc(lun, array_structure, offset)

  if n_elements(angles) eq Nscans then begin
    if n_elements(origNx) gt 0 then Nxx = origNx else Nxx = Nx
    if n_elements(origNy) gt 0 then Nyy = origNy else Nyy = Ny
  endif else begin
    ;; Indices of all image pixels, i.e., no masking.
    mindx = lindgen(Nx, Ny)
  endelse

  
  ;; Calculate statistics for the individual frames
  iprogress = 0
  Nprogress = Nscans * Ntuning * Nstokes
  for iscan = 0L, Nscans - 1 do begin

    if n_elements(angles) eq Nscans then begin
      
      ;; Make a mask by rotating and shifting an image of unit values
      ;; the same way as the images from this scan. 
      
      if n_elements(shifts) eq 0 then begin
        dx = 0
        dy = 0
      endif else begin
        dx = shifts[0,iscan]
        dy = shifts[1,iscan]
      endelse
      
      mask = make_array(Nxx, Nyy, /float, value = 1.) 
      mask = red_rotation(mask, angles[iscan], dx, dy, background = 0, full = full)
      mindx = where(mask gt 0.99)

    endif 

    for ituning = 0L, Ntuning - 1 do begin 
      for istokes = 0L, Nstokes-1 do begin

        red_progressbar, iprogress, Nprogress $
                         , /predict $
                         , 'Calculate frame by frame statistics'

        red_fitscube_getframe, fileassoc, frame $
                               , iscan = iscan, ituning = ituning, istokes = istokes
        
        if (iscan eq 0) and (ituning eq 0) and (istokes eq 0) then begin
          ;; Set up the array if it's the first frame
          frame_statistics = red_image_statistics_calculate(frame[mindx])
          frame_statistics = replicate(temporary(frame_statistics), Ntuning, Nstokes, Nscans)
        endif else begin
          frame_statistics[ituning, istokes, iscan] = red_image_statistics_calculate(frame[mindx])
        endelse 

        iprogress++
        
      endfor                    ; istokes
    endfor                      ; ituning
  endfor                        ; iscan

  
  if Nstokes eq 1 then frame_statistics = reform(frame_statistics)
  
  if keyword_set(write) or arg_present(cube_statistics) then begin
    
    ;; Accumulate a histogram for the entire cube, use to calculate
    ;; percentiles.
    cubemin  = min(frame_statistics.datamin)
    cubemax  = max(frame_statistics.datamax)
    Nbins = 2L^16               ; Use many bins!
    binsize = (cubemax - cubemin) / (Nbins - 1.)
    hist = lonarr(Nbins)
    iprogress = 0
    for iscan = 0L, Nscans - 1 do begin


      if n_elements(angles) eq Nscans then begin
        
        ;; Make a mask by rotating and shifting an image of unit values
        ;; the same way as the images from this scan. 
        
        if n_elements(shifts) eq 0 then begin
          dx = 0
          dy = 0
        endif else begin
          dx = shifts[0,iscan]
          dy = shifts[1,iscan]
        endelse
        
        mask = make_array(Nxx, Nyy, /float, value = 1.) 
        mask = red_rotation(mask, angles[iscan], dx, dy, background = 0, full = full)
        mindx = where(mask gt 0.99)
      endif 

      for ituning = 0L, Ntuning - 1 do begin 
        for istokes = 0L, Nstokes-1 do begin

          red_progressbar, iprogress, Nprogress $
                           , /predict $
                           , 'Accumulate histogram'

          red_fitscube_getframe, fileassoc, frame $
                                 , iscan = iscan, ituning = ituning, istokes = istokes
          
          hist += histogram(frame[mindx], min = cubemin, max = cubemax, Nbins = Nbins, /nan)

          iprogress++
          
        endfor                  ; istokes
      endfor                    ; ituning
    endfor                      ; iscan

    ;; Calculate cube statistics from the histogram and the individual
    ;; frame statistics
    cube_statistics = red_image_statistics_combine(frame_statistics $
                                                   , hist = hist $
                                                   , comments = cube_comments $
                                                   , binsize = binsize)
  endif

  free_lun, lun
  
  if keyword_set(write) then begin

    ;; Write the statistics to the fitscube file

    if Nstokes gt 1 then begin
      axis_numbers = [3, 4, 5]  ; (Ntuning, Nstokes, Nscans)
    endif else begin
      axis_numbers = [3, 5]     ; (Ntuning, Nscans)
    endelse

    for itag = n_tags(frame_statistics[0])-1, 0, -1 do begin

      itags = where((tag_names(frame_statistics[0]))[itag] eq tag_names(cube_statistics), Nmatch)
      itagc = where((tag_names(frame_statistics[0]))[itag] eq tag_names(cube_comments), Nmatch)
      
      if Nmatch eq 1 then $
         red_fitscube_addvarkeyword, filename $
                                     , (tag_names(frame_statistics[0]))[itag] $
                                     , frame_statistics.(itag) $
                                     , anchor = anchor $
                                     , keyword_value = cube_statistics.(itags) $
                                     , comment = cube_comments.(itagc) $
                                     , axis_numbers = axis_numbers

    endfor                      ; itag
    
  endif
  
end
