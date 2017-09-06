; docformat = 'rst'

;+
; Add data to a FITS file using the Variable-Keyword mechanism of the
; SOLARNET document, appendix I.
;
; To make implementation easier, we'll have each keyword in an
; extension of its own. The extenstion's name is "VAR-EXT-" followed
; by the name of the keyword.
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
;    filename : in, type=string
;
;       The name of the file.
; 
; 
; :Keywords:
; 
;    axis_numbers : in, optional, type=intarr
;
;       For a pixel-to-pixel association with, e.g., NAXIS2 and
;       NAXIS4, use axis_numbers=[2,4].
;   
;   keyword_value : in, optional, type=varies
;
;       The value of the keyword in the main header.
; 
; :History:
; 
;   2017-09-06 : MGL. First version, supporting pixel-to-pixel
;                association and coordinate association for tabulated
;                time. 
; 
; 
; 
; 
;-
pro red::fitscube_addvarkeyword, filename, keyword_name, values $ ;, association $
                                 , axis_numbers = axis_numbers $
                                 , keyword_value = keyword_value $
                                 , comment = comment $
                                 , tunit = tunit $
                                 , extra_coordinate1 = extra_coordinate1 $
                                 , extra_coordinate2 = extra_coordinate2 $
                                 , extra_labels      = extra_labels $
                                 , extra_names       = extra_names $
                                 , extra_units       = extra_units $
                                 , spatial_coordinates = spatial_coordinates $
                                 , spatial_deltas      = spatial_deltas $
                                 , spatial_units       = spatial_units $
                                 , time_coordinate = time_coordinate $
                                 , time_delta      = time_delta $
                                 , time_unit       = time_unit $
                                 , wavelength_coordinates = wavelength_coordinates $
                                 , wavelength_delta       = wavelength_delta $
                                 , wavelength_units       = wavelength_units

  ;; Name of this method
  inam = red_subprogram(/low, calling = inam1)

  extension_name = 'VAR-EXT-'+keyword_name     ; Variable keyword extension for keyword <keyword_name>.

  if n_elements(comment) eq 0 then comment = ''
  
  if n_elements(time_coordinate) gt 0 $
     || n_elements(spatial_coordinates) gt 0 $
     || n_elements(wavelength_coordinate) gt 0 then begin
    ;; At least one coordinate array keyword has values, so a
    ;; coordinate association is wanted. The coordinates are
    ;; tabulated. 
    association = 'coordinate-tabulated'
  endif else if n_elements(time_delta) gt 0 $
     || n_elements(spatial_deltas) gt 0 $
     || n_elements(wavelenght_delta) gt 0 then begin
    ;; At least one delta has value, so a coordinate association is
    ;; wanted. The coordinates are gridded.
    association = 'coordinate-grid'
  endif else if n_elements(axis_numbers)  gt 0 then begin

    association = 'pixel-to-pixel'
    
  endif else if 0 then begin
    
    ;; Identify other associations from keywords or dimensions or data
    ;; types.
    
    ;; Maybe: If the association isn't "coordinate-*", then it is
    ;; pixel-to-pixel if the first NAXIS dimensions match the NAXIS?
    ;; keywords of the calling HDU (main?) or are unity.

  endif else begin
    ;; Default association is static.
    if n_elements(association) eq 0 then association =  'static'
  endelse


  ;; If there is any reason not to add the extension, then return now!


  
  ;; If the main header doesn't have the EXTEND keyword, add it now.
  fxhmodify, filename, 'EXTEND', !true, 'The file has extension(s).'

  if n_elements(keyword_value) ne 0 then begin
    fxhmodify, filename, keyword_name, keyword_value, 'Variable-keyword, provided value'
  endif else begin
    fxhmodify, filename, keyword_name, values[0], 'Variable-keyword, first value'
  endelse

  
  ;; Make the binary extension header
  fxbhmake, bdr, 1, extension_name $
            , 'Variable keyword, '+association+' assoc.'



  hdr = headfits(filename) 

  
  
  ;; Set the var_keys FITS header keyword. 
  var_keys = fxpar(hdr, 'VAR_KEYS', count = Nmatch, comment = comment)

  ;;  var_keys = 'VAR-EXT-1;KEYWD_1,KEYWD_2[He_I],VAR-EXT-2;KEYWD_3'
  ;;  Nmatch = 1

  ;; Find old VAR_KEYS keyword in main header and add to it or make
  ;; new one with added name.

  if Nmatch eq 0 then begin

    new_var_keys = extension_name + ';' + keyword_name
    print, inam + ' : No existing VAR_KEYS, make a new one: ', new_var_keys

  endif else begin

    print, inam + ' : Existing VAR_KEYS: ', var_keys

    ;; Parse existing VAR_KEYS, add to it

    ;; Split into keywords (some of which have extension names in
    ;; front).
    existing_keyword_names = strsplit(var_keys, ',', /extract)
    Nexisting = n_elements(existing_keyword_names)
    existing_extension_names = strarr(Nexisting)

    for iexisting = 0, Nexisting-1 do begin
      ;; Identify extension name for this keyword, either before a
      ;; semi-colon or the same extension as the pervious keyword.
      splt = strsplit(existing_keyword_names[iexisting], ';', /extract)
      case n_elements(splt) of
        1 :                     ; Leave the keyword alone
        2 : begin               ; Remove the extension name from the keyword string 
          latest_extension_name = splt[0]
          existing_keyword_names[iexisting] = splt[1]
        end
        else : print, 'Should not happen!'
      endcase
      existing_extension_names[iexisting] = latest_extension_name
    endfor                      ; iexisting
    
    ;; Build up a new var_keys string, adding the new keyword in its
    ;; own extension.
    new_var_keys = existing_extension_names[0] + ';' + existing_keyword_names[0]
    latest_extension_name = existing_extension_names[0]
    added_new = 0
    for iexisting = 1, Nexisting-1 do begin
      if existing_extension_names[iexisting] eq existing_extension_names[iexisting-1] then begin
        ;; Same extension as previous keyword
        new_var_keys += ',' + existing_keyword_names[iexisting]
      endif else begin
        ;; New extension
        if ~added_new then begin
          ;; If the extension we want to add is the same as the
          ;; previous one, this is where we can add the new keyword.
          if extension_name eq existing_extension_names[iexisting-1] then begin
            new_var_keys += ',' + keyword_name
            added_new = 1
          endif
        endif
        ;; First keyword with this extension name, add both the
        ;; extension name and the keyword namr.
        new_var_keys += ',' + existing_extension_names[iexisting] + ';' + existing_keyword_names[iexisting]
      endelse
    endfor                      ; iexisting
    if ~added_new then begin
      ;; If we haven't already added the new keyword, do it now.
      if extension_name eq existing_extension_names[Nexisting-1] then begin
        ;; Same as the last existing extension, add just the keyword name.
        new_var_keys += ',' + keyword_name
        added_new = 1
      endif else begin
        ;; The new extension does not already exist, add it together
        ;; with the keyword name.
        new_var_keys +=',' +  extension_name+';'+keyword_name
      endelse
    endif

  endelse

  if n_elements(new_var_keys) eq 0 then stop
  fxhmodify, filename, 'VAR_KEYS', new_var_keys, 'SOLARNET variable-keyword'
    
  
  ;;
  case association of
    
    'coordinate-tabulated' : begin

      case 1 of
        n_elements(time_coordinate) gt 0 $
           && n_elements(spatial_coordinates) eq 0 $
           && n_elements(wavelength_coordinate) eq 0 : begin
          print, inam + ' : coordinate-tabulated with time only'

          Ndims = size(values, /n_dim)
          N_extra_axes = Ndims-1 ; Only one time coordinate
          dims = size(values, /dim)
          if dims[-1] ne n_elements(time_coordinate) then stop ; dim mismatch

          ;; Need time reference for this
          red_fitsaddpar, bdr $
                          , 'DATEREF' $
                          , self.isodate+'T00:00:00.000' $
                          , 'Time reference is midnight'

          ;; Add column for the data to the binary extension header ====================
          n = 1                 ; column number
          ;; Add the column
          fxbaddcol, n, bdr, values, keyword_name $
                     , 'Table of SOLARNET variable-keyword', tunit = tunit
          red_fitsaddpar, bdr, /before, anchor = 'TFORM1' $
                          , ['', 'COMMENT'                          , ''] $
                          , ['', 'Column 1: Tabulated '+keyword_name, '']
          
          ;; Specify the axes ----------------------------------------------------------
          for i_extra = 0, N_extra_axes-1 do begin
            i = i_extra+1       ; Array dimension/axis for "extra" (non-time) coordinates
            red_fitsaddpar, bdr $
                            , string(i,n,format = '((i0),"CNAM",(i0))') $
                            , 'Coord. ' + strtrim(i, 2) + ' for col. ' + strtrim(n, 2) $
                            + ' (' + keyword_name + ') is ' + extra_names[i_extra]
            red_fitsaddpar, bdr $
                            , string(i,n,format = '((i0),"CTYP",(i0))') $
                            , extra_labels[i_extra]+'-TAB' $ 
                            , 'Not a WCS coordinate.'
            red_fitsaddpar, bdr $
                            , string(i,n,format = '((i0),"CUNI",(i0))') $
                            , extra_units[i_extra]
            
            m = 0               ; Extension column 0
            red_fitsaddpar, bdr $
                            , string(i,n,m,format='((i0),"PS",(i0),"_",(i0))') $
                            , 'VAR-EXT-'+keyword_name $
                            , 'Axis '+strtrim(i, 2)+' in col. '+strtrim(n, 2)+' is in VAR-EXT-'+keyword_name
            m = 1               ; Extension column 1
            red_fitsaddpar, bdr $
                            , string(i,n,m,format='((i0),"PS",(i0),"_",(i0))') $
                            , extra_labels[i_extra]+'-'+keyword_name $
                            , 'Col. with val. for axis '+strtrim(i, 2)+' of col. '+strtrim(m, 2)
            m = 3               ; Extension column 3
            red_fitsaddpar, bdr $
                            , string(i,n,m,format='((i0),"PV",(i0),"_",(i0))'), 1 $
                            , extra_labels[i_extra] + ' 1st (only) coord. in ' $
                            + extra_labels[i_extra] + '-' + keyword_name 
          endfor
          
          i = N_extra_axes + 1  ; Time array axis comes after the extra axes
          red_fitsaddpar, bdr $
                          , string(i,n,format = '((i0),"CNAM",(i0))') $
                          , 'Coord. '+strtrim(i, 2)+' for col. '+strtrim(n, 2)+' ('+keyword_name+') is time.'
          red_fitsaddpar, bdr $
                          , string(i,n,format = '((i0),"CTYP",(i0))') $
                          , 'UTC--TAB' $ 
                          , 'WCS time coordinate, tabulated.'
          red_fitsaddpar, bdr $
                          , string(i,n,format = '((i0),"CUNI",(i0))') $
                          , time_unit

          m = 0                 ; Extension column 0
          red_fitsaddpar, bdr $
                          , string(i,n,m,format='((i0),"PS",(i0),"_",(i0))') $
                          , 'VAR-EXT-'+keyword_name $
                          , 'Axis '+strtrim(i, 2)+' in col. '+strtrim(n, 2)+' is in VAR-EXT-'+keyword_name
          m = 1                 ; Extension column 1
          red_fitsaddpar, bdr $
                          , string(i,n,m,format='((i0),"PS",(i0),"_",(i0))') $
                          , 'TIME-'+keyword_name $
                          , 'Col. with val. for axis '+strtrim(i, 2)+' of col. '+strtrim(m, 2)
          m = 3                 ; Extension column 3
          red_fitsaddpar, bdr $
                          , string(i,n,m,format='((i0),"PV",(i0),"_",(i0))') $
                          , 1 $
                          , 'UTC 1st (only) coord. in TIME-' + keyword_name 
          
          ;; Add columns for any tabulated extra axes =====================================
          for n_extra = 0, N_extra_axes-1 do begin
            n = n_extra+2       ; column number
            fxbaddcol, n, bdr, reform(extra_coordinate1,1,dims[n_extra]) $
                       , extra_labels[n_extra] + '_' + keyword_name $
                       , 'Tabulations of ' + extra_labels[n_extra] + ' for ' + keyword_name $
                       , tunit = extra_units[n_extra]
            red_fitsaddpar, bdr, /before, anchor = 'TFORM'+strtrim(n, 2) $
                            , ['', 'COMMENT', ''] $
                            , ['' $
                               , 'Column '+strtrim(n, 2)+': '+extra_names[n_extra] + ' (coord. ' $
                               + strtrim(n_extra+1, 2) + ' for ' + keyword_name + ')' $
                               , '']
          endfor                ; n_extra


          ;; Add column for the tabulated time ============================================
          n = N_extra_axes + 2  ; column number
          fxbaddcol, n, bdr, reform(time_coordinate, 1, dims[N_extra_axes]), 'TIME-'+keyword_name $
                     , 'Tabulations of TIME for '+keyword_name, tunit = time_unit
          red_fitsaddpar, bdr, before = 'TFORM'+strtrim(N_extra_axes+2, 2) $
                          , ['', 'COMMENT', ''] $
                          , ['' $
                             , 'Column ' + strtrim(N_extra_axes+2, 2) $
                             + ': Measurement times (coord. ' $
                             + strtrim(N_extra_axes+1, 2) + ' for ' + keyword_name + ')' $
                             , '']

          ;; Some space before END
          red_fitsaddpar, bdr, /before, anchor = 'END', '',''


print, bdr         
stop          
          ;; Write it to the file
          fxbcreate, blun, filename, bdr           ; Create the extension in the file
          fxbwrite,  blun, values, 1, 1            ; Write keyword values as column 1, row 1
          fxbwrite,  blun, extra_coordinate1, 2, 1 ; Extra coordinate as column 2, row 1
          fxbwrite,  blun, time_coordinate, 3, 1   ; Write time as column 3, row 1
          fxbfinish, blun                          ; Close the binary extension
          
          help, time_coordinate, values

          return

        end
        else : begin
          print, inam + ' : Association "' + association + '" cannot handle this kind of data yet.'

          stop
          return
        end 

      endcase
    end

    'pixel-to-pixel' : begin
      
      ;; The dimensions must make sense.
      Naxis = fxpar(hdr, 'NAXIS')
      Ndims = size(values, /n_dim)
      dims = size(values, /dim)
      if Ndims lt n_elements(axis_numbers) then stop
      for idim = 0, Ndims-1 do $
         if fxpar(hdr, 'NAXIS'+strtrim(axis_numbers[idim], 2)) ne dims[idim] then stop

      ;; Make dimensions match
      newdims = lonarr(max([fxpar(hdr, 'NAXIS'), Ndims])) + 1
      if Naxis lt n_elements(axis_numbers) then $
         newdims(Naxis:n_elements(axis_numbers)-1) = axis_numbers[Ndims:*]
      newdims[axis_numbers-1] = dims
      values2 = reform(values, newdims)
      
      fxbaddcol, 1, bdr, values2, keyword_name ; Add column to the binary extension header
      fxbcreate, blun, filename, bdr           ; Create the extension in the file
      fxbwrite, blun, values2, 1, 1            ; Write keyword values as column 1, row 1
      fxbfinish, blun                          ; Close the binary extension

      return
      
    end

  endcase
  
  print, inam + ' : Unknown association: "'+ association + '"'
  stop
  
end
