; docformat = 'rst'

;+
;
; :history:
; 
;    2013-07-11 : MGL. Renamed from satlas. Modified mechanism for
;                 finding the data file within the path. Should now
;                 pick the version that is in the same directory as
;                 this file, that is, in the crispred repository.
; 
;    2016-11-11: JdlCR, added the possibility to output CGS/SI units for
;                the calibration of CHROMIS
; 
;
;-
pro red_satlas,xstart,xend,outx,outy,nm=nm,nograv=nograv,nocont=nocont,cgs=cgs,cont=con,si=si

  ;; Find the input data
  this_dir = file_dirname( routine_filepath("red_satlas"), /mark )
  restore, this_dir+'ftsatlas.idlsave'

  
  if keyword_set(nm) then begin
     xstart=xstart/10.d0
     xend=xend/10.d0
  endif
;
  c=299792458.d0                ; light speed in m/s
;
  ;pos=where(XL_FTS gt xstart AND XL_FTS lt xend)
  ;outx=xl_fts;[pos]
  if not keyword_set(nograv) then xl_fts*=(1.d0-633.d0/c)
  pos=where(XL_FTS ge xstart AND XL_FTS le xend)
  outx=xl_fts[pos]
  outy=YL_FTS[pos]
  con = CINT_FTS[pos]
  
  
  if(keyword_set(cgs)) then begin
     clight=2.99792458e10         ;speed of light [cm/s]
     joule_2_erg=1e7
     aa_to_cm=1e-8
     
     outy *=joule_2_erg/aa_to_cm ; from Watt /(cm2 ster AA) to erg/(s cm2 ster cm)
     outy *=(outx*aa_to_cm)^2/clight ; to erg/

     con *= joule_2_erg/aa_to_cm
     con *= (outx*aa_to_cm)^2/clight
     return
  endif

  if(keyword_set(si)) then begin
     clight=2.99792458e8      ;speed of light [m/s]                                  
     aa_to_m=1e-10                                                                        
     cm_to_m=1e-2                       

     outy /= cm_to_m^2 * aa_to_m      ; from from Watt /(s cm2 ster AA) to Watt/(s m2 ster m) 
     outy *= (outx*aa_to_m)^2 / clight ; to Watt/(s m2 Hz ster)
     
     con /= cm_to_m^2 * aa_to_m
     con *= (outx*aa_to_m)^2 / clight
     return
  endif
  
  if not keyword_set(nocont) then begin
     outy /= con
     con[*] = 1.d0
  endif
  return
end
