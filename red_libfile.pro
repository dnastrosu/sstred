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
; :Returns:
;    path to an .so library
; 
; :Params:
; 
;   
; 
; :Keywords:
; 
; 
; :History:
;
;   2013-12-09 : initial version
;
;
;-
function red_libfile, libname

      ;;; first look in DLM_PATH
  libfile = file_search(strsplit(!DLM_PATH, ':', /extr), libname, count = count)
  if(count gt 1) then begin
    print, 'red_libfile : WARNING, you have multiple '+libname+' files in your path!'
    for ii=0, count-1 do print, '  -> '+libfile[ii]
    print,'red_libfile : using the first one!'
  endif
  IF count EQ 0 THEN BEGIN
      ;;; try IDL_PATH, too
    libfile = file_search(strsplit(!PATH, ':', /extr), libname, count = count)
    if(count gt 1) then begin
      print, 'red_libfile : WARNING, you have multiple '+libname+' files in your path!'
      for ii=0, count-1 do print, '  -> '+libfile[ii]
      print,'red_libfile : using the first one!'
    endif
    IF count EQ 0 THEN $
       message, 'Could not locate library file '+libname+'; Exiting'
  ENDIF

  return, libfile[0]

END
