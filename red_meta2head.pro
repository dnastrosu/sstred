; docformat = 'rst'

;+
; Add header info from meta data.
; 
; :Categories:
;
;    SST pipelines
; 
; 
; :Author:
; 
;    Mats Löfdahl, ISP
; 
; 
; :Returns:
; 
; 
; :Params:
; 
;    head : in, type=strarr
;
;       The header to which we want to add information. 
; 
; 
; :Keywords:
; 
;    metadata : in, type=struct
;
;	Additional metadata to include in the header
;	Form: metadata.[keyword_name] = [keyword_data]
;   
; 
; 
; :History:
;
;    2016-08-15 : MGL. Take relevant code from
;                 red_filterchromisheaders. Remove .momfbd extension
;                 from variable barefile. Recognize underscore as a
;                 delimiter when parsing filenames.
;
;    2016-08-23 : THI. Rename camtag to detector and channel to camera,
;                 so the names match those of the corresponding SolarNet
;                 keywords.
;
;    2016-09-15 : MGL. If there is a properly formatted
;                 date+'T'+timestamp in the file name, interpret it as
;                 the date-obs.
;
;    2016-09-21 : MGL. Change filter tags to four-digit tags
;                 representing approximate filter wavelength. Set
;                 WAVELNTH header keyword to corresponding wavelength.
;
;    2016-09-27 : MGL. Get tuning info (including prefilter), detector
;                 gain, and exposure time. Move setting of waveband to
;                 the later case statement. 
;
;    2017-03-13 : MGL. Leave frame numbers alone for single-frame ANA
;                 files.
;
;    2017-05-08 : MGL. Get info from directory if CRISP data.
; 
;    2017-06-01 : MGL. Use red_fitsaddpar. WAVELNTH in nm. Specify
;                 unit for WAVELNTH in WAVEUNIT.
; 
;-
function red_meta2head, head, metadata=metaStruct

  ;; Was any meta data provided?
  if n_elements(metaStruct) eq 0 then return, head

  newhead = head

  ;; Extract metadata from the filename (for now it's all we have)
  if tag_exist(metaStruct, 'filename', /top_level) then begin

    ;; Strip directory...
    filename  = file_basename(metaStruct.filename)
    directory = file_dirname(metaStruct.filename)
    ;; ...and extension if needed
    barefile = filename
    barefile = file_basename(barefile, '.fits')
    barefile = file_basename(barefile, '.momfbd')

    anchor = 'DATE'
    
    dummy = fxpar(newhead, 'FILENAME', count=count)
    if count eq 0 then begin
      ;; Preserve existing file name, this keyword should be the
      ;; name of the original file.
;      metaStruct.filename = filename
      red_fitsaddpar, anchor = anchor, newhead, 'FILENAME', filename, 'Name of original file.'
    endif

    ;; Detector ID (check that this is the correct keyword...)
    dummy = fxpar(newhead, red_keytab('detector'), count=count)
    if count eq 0 then begin

      ;; The detector tag consists of the string 'cam' followed by a
      ;; roman number.
      detector = ((stregex(barefile, '(_|\.|^)(cam[IVXL]+)(_|\.|$)', /extr, /subexp))[2,*])[0]

      if detector ne '' then red_fitsaddpar, anchor = anchor, newhead $
                                             , red_keytab('detector'), detector $
                                             , 'Inferred from filename.'
    endif                       ; detector

    ;; Camera
    dummy = fxpar(newhead, 'CAMERA', count=count)
    if count eq 0 then begin
      ;; This could be a CRISP camera, in that case the camera is
      ;; encoded in the directory
      if strtrim(fxpar(head, 'INSTRUME'), 2) eq 'CRISP' then begin
        case 1 of
          strmatch(directory, '*Crisp-W*') : red_fitsaddpar, anchor = anchor, newhead $
             , 'CAMERA', 'Crisp-W', 'Inferred from directory'
          strmatch(directory, '*Crisp-R*') : red_fitsaddpar, anchor = anchor, newhead $
             , 'CAMERA', 'Crisp-R', 'Inferred from directory'
          strmatch(directory, '*Crisp-T*') : red_fitsaddpar, anchor = anchor, newhead $
             , 'CAMERA', 'Crisp-T', 'Inferred from directory'
          strmatch(directory, '*Crisp-D*') : red_fitsaddpar, anchor = anchor, newhead $
             , 'CAMERA', 'Crisp-D', 'Inferred from directory'
        endcase
      endif
    endif

    
    ;; Exposure time
    dummy = fxpar(newhead, 'XPOSURE', count=count)
    if count eq 0 then begin
      xposure = stregex(barefile, '([0-9]*)[.]([0-9]*)ms' $
                        , /extract, /subexpr) 
      if xposure[0] ne '' then begin
        red_fitsaddpar, anchor = anchor, newhead $
                        , 'XPOSURE', float(strjoin(xposure[1:2], '.'))/1000., '[s] Inferred from filename.'
      endif
    endif

    ;; Detector gain
    dummy = fxpar(newhead, 'DETGAIN', count=count)
    if count eq 0 then begin
      detgain = stregex(barefile, 'G([0-9]*)[.]([0-9]*)' $
                        , /extract, /subexpr) 
      if detgain[0] ne '' then begin
        red_fitsaddpar, anchor = anchor, newhead $
                        , 'DETGAIN', float(strjoin(detgain[1:2], '.')), 'Inferred from filename.'
      endif
    endif

    ;; Prefilter and tuning info
    dummy = fxpar(newhead, red_keytab('pref'), count=count)
    if count eq 0 then begin
      ;; Try to find tuning info on standard form in the file name
      tuninfo = stregex(barefile, '([0-9][0-9][0-9][0-9])[._]([0-9][0-9][0-9][0-9])_([+-][0-9]*)' $
                        , /extract, /subexpr) 
      if tuninfo[0] ne '' then begin
        if tuninfo[1] ne '' then red_fitsaddpar, anchor = anchor, newhead $
                                                 , red_keytab('pref'), tuninfo[1] $
                                                 , 'Inferred from tuning info in filename.'
        ;; Add also the tuning state if not there already
        dummy = fxpar(newhead, 'STATE', count=count)
        if count eq 0 then begin
          red_fitsaddpar, anchor = anchor, newhead $
                          , 'STATE', tuninfo[0] $
                          , 'Inferred from tuning info in filename.' ;strjoin(tuninfo[2:3], '_')
        endif
      endif
    endif

    ;; FILTERn and WAVELNTH
    dummy = fxpar(newhead, red_keytab('pref'), count=count)
    if count eq 0 then begin

      ;; Get prefilter names from file name. For now, we have
      ;; the filter wheel position as a tag consisting of the
      ;; letter w followed by a single digit.
      wheelpos = ((stregex(barefile, '(_|\.|^)(w[0-9]{1})(_|\.|$)', /extr, /subexp))[2,*])[0]

      if wheelpos ne '' then begin
        
        camera = fxpar(head, red_keytab('camera'), count=count)
        if count eq 0 then begin
          ;;  TDB: can we extract filter-info without the camera-tag?
          red_fitsaddpar, anchor = anchor, newhead, red_keytab('pref'), wheelpos
        endif else begin

          if camera eq 'Chromis-N' then begin
            ;; Chromis-N
            case wheelpos of
              'w1' : filter1 = '3925' ; Ca II K blue wing
              'w2' : filter1 = '3934' ; Ca II K core
              'w3' : filter1 = '3969' ; Ca II H core
              'w4' : filter1 = '3978' ; Ca II H red wing
              'w5' : filter1 = '3999' ; Ca II H continuum
              'w6' : filter1 = '4862' ; H-beta core
            endcase
          endif else begin
            ;; Chromis-W and Chromis-D
            case wheelpos of
              'w6' : filter1 = '4846' ; H-beta continuum
              else : filter1 = '3950' ; Ca II HK wideband
            endcase
          endelse
          
          red_fitsaddpar, anchor = anchor, newhead  $
                          , red_keytab('pref'), filter1 $
                          , 'Inferred from filter wheel position in filename.'
          
        endelse

      endif                     ; Found a wheel position
      
    endif                       ; FILTER1

    ;; WAVELNTH
    prefilter = fxpar(newhead, red_keytab('pref'), count=count)
    if count gt 0 then begin
      if fxpar(newhead, 'WAVELNTH') eq 0.0 then begin

        case strtrim(prefilter,2) of
          '3925' : begin        ; Ca II K blue wing
            wavelnth = 3925e-10
            fwhm = 0.37e-9
            waveband = 'Ca II H & K'
          end
          '3934' : begin        ; Ca II K core
            wavelnth = 3934e-10
            fwhm = 0.37e-9
            waveband = 'Ca II H & K'
          end
          '3950' : begin        ; Ca II HK wideband
            wavelnth = 3950e-10
            fwhm = 1.3e-9
            waveband = 'Ca II H & K'
          end
          '3969' : begin        ; Ca II H core
            wavelnth = 3969e-10
            fwhm = 0.37e-9
            waveband = 'Ca II H & K'
          end
          '3978' : begin        ; Ca II H red wing
            wavelnth = 3978e-10
            fwhm = 0.37e-9
            waveband = 'Ca II H & K'
          end
          '3999' : begin        ; Ca II H continuum
            wavelnth = 3999e-10
            fwhm = 0.37e-9
            waveband = 'Ca II H & K'
          end
          '4862' : begin        ; H-beta core
            wavelnth = 4862e-10
            fwhm = 0.44e-9
            waveband = 'H-beta'
          end
          '4846' : begin        ; H-beta continuum
            wavelnth = 4846e-10
            fwhm = 0.6e-9
            waveband = 'H-beta'
          end
          else: begin      
            wavelnth = ''
            fwhm = ''
            waveband = ''
          end
        endcase

        red_fitsaddpar, anchor = anchor, newhead $
                        , 'WAVELNTH', wavelnth*1e9, '[nm] Prefilter peak wavelength'
        red_fitsaddpar, anchor = anchor, newhead $
                        , 'WAVEUNIT', -9, 'WAVELNTH in units 10^WAVEUNIT m = nm'
        ;; Add also the FWHM in a keyword?

      endif 
    endif                       ; WAVELNTH
    
    framenumber = fxpar(head, red_keytab('frame'), count = count)
    if count eq 0 then begin
      ;; The frame number is the last field iff it consists
      ;; entirely of digits. The third subexpression of the
      ;; regular expression matches only the end of the string
      ;; because that's where it is if it is present. We do not
      ;; know the length of the frame number field so if the
      ;; third subexpression were allowed to match a dot we would
      ;; get false matches with the scan and prefilter fields.
      ;;
      ;; Actually, this is the file number. Let's make the frame
      ;; number (of the first frame) 10000 times this. But only if
      ;; naxis > 2.
      ;;
      filenumber = ((stregex(barefile, '(\.|_)([0-9]+)($)', /extr, /subexp))[2,*])[0]
      if filenumber ne '' then begin
        if sxpar(newhead, 'NAXIS') gt 2 then begin
          red_fitsaddpar, anchor = anchor, newhead $
                          , red_keytab('frame'), 10000L*long(filenumber) $
                          , '(number of first frame) Inferred from filename.'
        endif else begin
          red_fitsaddpar, anchor = anchor, newhead $
                          , red_keytab('frame'), long(filenumber) $
                          , 'Inferred from filename.'  
        endelse
      endif
    endif 

    scannumber = fxpar(head, red_keytab('scannumber'), count = count)
    if count eq 0 then begin
      ;; The scan number is the only field that is exactly five
      ;; digits long:
      scannumber = ((stregex(barefile, '(_|\.|^)([0-9]{5})(_|\.|$)', /extr, /subexp))[2,*])[0]
      if scannumber ne '' then red_fitsaddpar, anchor = anchor, newhead $
                                               , red_keytab('scannumber'), long(scannumber) $
                                               , 'Inferred from filename.'
    endif

    date_obs = fxpar(head, 'DATE-OBS', count = count)
    if count eq 0 then begin
      ;; If there is a properly formatted date+'T'+timestamp in the
      ;; file name, it should be the date-obs. I.e., corresponding
      ;; to the timestamp of the data collection directory.
      timeregex = '[0-2][0-9]:[0-5][0-9]:[0-6][0-9]'
      dateregex = '20[0-2][0-9][.-][01][0-9][.-][0-3][0-9]'
      date_obs = stregex(barefile, dateregex+'T'+timeregex, /extract) 
      if date_obs ne '' then red_fitsaddpar, anchor = anchor, newhead $
                                       , 'DATE-OBS', date_obs $
                                       , 'Inferred from filename.'
    endif

  endif                         ; filename

  ;; add to the metadata if the appropriate keywords aren't there,
  ;; don't overwrite metadata we received
  
;        ;; check these against solarnet standard
;        ;; waveband seems to be the right one for pref-filter 
;        ;; not sure about the others.
;        keys = tag_names(metaStruct)
;        nametags = ['camtag','scannum','waveband','framenum']
;        for i = 0, 3 do begin
;           junk = where(keys eq strupcase(nametags[i]),cnt)
;           
;           if cnt eq 0 then begin
;              keys = [keys,nametags[i]]
;              metaStruct = create_struct(metaStruct,nametags[i],states[i])
;           endif
;           
;        endfor

  
;        for ikey = 0, n_elements(keys)-1 do begin
;           if somecheck(keys[i]) then begin
;              red_fitsaddpar, anchor = anchor,newhead,keys[i],metaStruct.(i)
;           endif
;        endfor                  ; ikey
  
  return, newhead

end
