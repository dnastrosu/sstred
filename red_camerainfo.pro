; docformat = 'rst'

;+
; Provide information about SST science cameras.
; 
; :Categories:
;
;    CRISP pipeline
; 
; 
; :Author: 
;
;    Mats Löfdahl, ISP, 2016-05-01
; 
; 
; :Returns:
;
;    A struct with info about the camera.
; 
; 
; :Params:
; 
;    x : in, type="string or integer"
;   
;      The number of the camera. If x is a string, assume it is the
;      camera number as a roman numeral, possibly prepended with the
;      string "cam".
; 
; :History:
; 
;   2016-05-01 : MGL. First version.
; 
; 
;-
function red_camerainfo, x
  
  if size(x, /tname) eq 'STRING' then begin
     ;; Called with string
     camromnum = red_strreplace(x, 'cam', '') ; Remove "cam" if needed.
     camnum    = red_romannumber(camromnum)   ; The integer camera number.
  endif else begin
     ;; Called with number
     camromnum = red_romannumber(x) ; The roman camera number.
     camnum    = x
  endelse
  
  case camnum of
     4:  return, {romnum:'IV', $
                  defined:1, $
                  model:'MegaPlus 1.6', $
                  xsize:1534, $
                  ysize:1024, $
                  pixelsize:9.0e-6, $
                  serialnumber:'22743JS', $
                  use:'', $
                  note:''}
     6:  return, {romnum:'VI', $
                  defined:1, $
                  model:'MegaPlus 1.6', $
                  xsize:1534, $
                  ysize:1024, $
                  pixelsize:9.0e-6, $
                  serialnumber:'22099M4', $
                  use:'', $
                  note:''}
     8:  return, {romnum:'VIII', $
                  defined:1, $
                  model:'MegaPlus 4.2i/10', $
                  xsize:2029, $
                  ysize:2044, $
                  pixelsize:9.0e-6, $
                  serialnumber:'62981G8CSY3B', $
                  use:'', $
                  note:'Broken internal shutter, needs external Uniblitz shutter.' $
                  + ' Stored in tower in Al case. "Lacking bits."'}
     9:  return, {romnum:'IX', $
                  defined:1, $
                  model:'MegaPlus 4.2i/10', $
                  xsize:2029, $
                  ysize:2044, $
                  pixelsize:9.0e-6, $
                  serialnumber:'6298068CSY3E', $
                  use:'', $
                  note:'UV sensitive coating. Suspected to give slightly blurry images.'}
     10: return, {romnum:'X', $
                  defined:1, $
                  model:'MegaPlus 1.6i', $
                  xsize:1534, $
                  ysize:1024, $
                  pixelsize:9.0e-6, $
                  serialnumber:'', $
                  note:'Spectroscopy/slit-jaw	UV Sensitive - blue plus chip'}
     11: return, {romnum:'XI', $
                  defined:1, $
                  model:'MegaPlus 6.3i/10', $
                  xsize:3072, $
                  ysize:2048, $
                  pixelsize:9.0e-6, $
                  serialnumber:'64142S00FSYB', $
                  use:'', $
                  note:'UV Sensitive - blue plus chip'}
     12: return, {romnum:'XII', $
                  defined:1, $
                  model:'MegaPlus 1.6i', $
                  xsize:1534, $
                  ysize:1024, $
                  pixelsize:9.0e-6, $
                  serialnumber:'61316 M6CRY1', $
                  use:'Spectroscopy/slit-jaw', $
                  note:''}
     13: return, {romnum:'XIII', $
                  defined:1, $
                  model:'MegaPlus 1.6i', $
                  xsize:1534, $
                  ysize:1024, $
                  pixelsize:9.0e-6, $
                  serialnumber:'61317 M6CRY1', $
                  use:'Spectroscopy/slit-jaw', $
                  note:'Ugly orange peel pattern'}
     14: return, {romnum:'XIV', $
                  defined:1, $
                  model:'MegaPlus 1.6i', $
                  xsize:1534, $
                  ysize:1024, $
                  pixelsize:9.0e-6, $
                  serialnumber:'64061EOOCSY3', $
                  use:'Spectroscopy/slit-jaw', $
                  note:'UV Sensitive - blue plus chip.'}
     15: return, {romnum:'XV', $
                  defined:1, $
                  model:'MegaPlus II es1603', $
                  xsize:1536, $
                  ysize:1024, $
                  pixelsize:9.0e-6, $
                  serialnumber:'07000014 M', $
                  use:'Spectroscopy/slit-jaw', $
                  note:'Dark level problem. Cover edge, disable black subtraction.'}
     17: return, {romnum:'XVII', $
                  defined:1, $
                  model:'MegaPlus II es1603', $
                  xsize:1536, $
                  ysize:1024, $
                  pixelsize:9.0e-6, $
                  serialnumber:'07000015 M', $
                  use:'Spectroscopy/slit-jaw', $
                  note:'Dark level problem. Cover edge, disable black subtraction'}
     18: return, {romnum:'XVIII', $
                  defined:1, $
                  model:'Sarnoff CAM1M100', $
                  xsize:1024, $
                  ysize:1024, $
                  pixelsize:16.0e-6, $
                  serialnumber:'SAS 2', $
                  use:'CRISP', $
                  note:'Has new red AR coating. Transparent Sarnoff chip problem.'}
     19: return, {romnum:'XIX', $
                  defined:1, $
                  model:'Sarnoff CAM1M100', $
                  xsize:1024, $
                  ysize:1024, $
                  pixelsize:16.0e-6, $
                  serialnumber:'SAS 3', $
                  use:'CRISP', $
                  note:'Has new red AR coating. Transparent Sarnoff chip problem.'}
     20: return, {romnum:'XX', $
                  defined:1, $
                  model:'Sarnoff CAM1M100', $
                  xsize:1024, $
                  ysize:1024, $
                  pixelsize:16.0e-6, $
                  serialnumber:'SAS 1', $
                  use:'CRISP', $
                  note:'Has new red AR coating. Transparent Sarnoff chip problem.'}
     21: return, {romnum:'XXI', $
                  defined:1, $
                  model:'MegaPlus II es4020', $
                  xsize:2048, $
                  ysize:2048, $
                  pixelsize:7.4e-6, $
                  serialnumber:'03000391M', $
                  use:'Blue beam', $
                  note:''}
     22: return, {romnum:'XXII', $
                  defined:1, $
                  model:'MegaPlus II es4020', $
                  xsize:2048, $
                  ysize:2048, $
                  pixelsize:7.4e-6, $
                  serialnumber:'03000392M', $
                  use:'Blue beam', $
                  note:''}	 
     23: return, {romnum:'XXIII', $
                  defined:1, $
                  model:'MegaPlus II es4020', $
                  xsize:2048, $
                  ysize:2048, $
                  pixelsize:7.4e-6, $
                  serialnumber:'03000404M', $
                  use:'Blue beam', $
                  note:''}
     24: return, {romnum:'XXIV', $
                  defined:1, $
                  model:'MegaPlus II es4020', $
                  xsize:2048, $
                  ysize:2048, $
                  pixelsize:7.4e-6, $
                  serialnumber:'03000581M', $
                  use:'Blue beam', $
                  note:''}
     25: return, {romnum:'XXV', $
                  defined:1, $
                  model:'Sarnoff CAM1M100', $
                  xsize:1024, $
                  ysize:1024, $
                  pixelsize:16.0e-6, $
                  serialnumber:'SAS 4', $
                  use:'CRISP', $
                  note:'New for 2008 season, has red AR coating. Transparent Sarnoff chip problem.'}
     26: return, {romnum:'XXVI', $
                  defined:1, $
                  model:'MegaPlus II es4020', $
                  xsize:2048, $
                  ysize:2048, $
                  pixelsize:7.4e-6, $
                  serialnumber:'03000831M', $
                  use:'Blue beam', $
                  note:'Camera without window to improve fringing problems'}
     else: return, {defined:0}
  endcase
  
end
