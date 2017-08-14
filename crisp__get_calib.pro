; docformat = 'rst'

;+
; From state data, return file names for calibration data and the data
; itself. 
; 
; :Categories:
;
;    CRISP pipeline
; 
; 
; :Author:
; 
;    Mats Löfdahl, ISP
; 
; 
; :Params:
; 
;    states : in, type=structarr
;
;       The states, the calibrations of which the keywords refer to. 
; 
; :Keywords:
; 
;    darkname : out, optional, type=strarr 
; 
;       The name(s) of the dark file(s) appropriate to the state(s).
; 
;    darkdata : out, optional, type=array 
; 
;        The data in the dark file(s) appropriate to the state(s).    
; 
;    darkhead : out, optional, type=array 
; 
;        The header of the dark file(s) appropriate to the state(s).      
; 
;    flatname : out, optional, type=strarr 
; 
;       The name(s) of the flat file(s) appropriate to the state(s).
; 
;    flatdata : out, optional, type=array 
; 
;        The data in the flat file(s) appropriate to the state(s).
; 
;    flathead : out, optional, type=array 
; 
;        The header of the flat file(s) appropriate to the state(s).
; 
;    sflatname : out, optional, type=strarr 
; 
;       The name(s) of the summed flat file(s) appropriate to the state(s).
; 
;    sflatdata : out, optional, type=array 
; 
;        The data in the summed flat file(s) appropriate to the state(s).
; 
;    sflathead : out, optional, type=array 
; 
;        The header of the summed flat file(s) appropriate to the state(s).
; 
;    gainname : out, optional, type=strarr 
; 
;       The name(s) of the gain file(s) appropriate to the state(s).
; 
;    gaindata : out, optional, type=array 
; 
;        The data in the gain file(s) appropriate to the state(s).
; 
;    gainhead : out, optional, type=array 
; 
;        The header of the gain file(s) appropriate to the state(s).
; 
;    pinhname : out, optional, type=strarr 
; 
;        The name(s) of the pinhole file(s) appropriate to the state(s).
; 
;    pinhdata : out, optional, type=array
;   
;        The data in the pinhole file(s) appropriate to the state(s).  
; 
;    pinhhead : out, optional, type=array
;   
;        The header of the pinhole file(s) appropriate to the state(s).  
;   
;    polcname : out, optional, type=strarr 
; 
;        The name(s) of the polcal file(s) appropriate to the prefilter(s).
; 
;    polcdata : out, optional, type=array
;   
;        The data in the polcal file(s) appropriate to the prefilter(s).  
; 
;    polchead : out, optional, type=array
;   
;        The header of the polcal file(s) appropriate to the prefilter(s).  
;   
;    polsname : out, optional, type=strarr 
; 
;        The name(s) of the polcal sum file(s) appropriate to the state(s).
; 
;    polsdata : out, optional, type=array
;   
;        The data in the polcal sum file(s) appropriate to the state(s).  
; 
;    polshead : out, optional, type=array
;   
;        The header of the polcal sum file(s) appropriate to the state(s).  
;   
;    status : out, optional, type=integer
; 
;        The status of the operation, 0 for success.
; 
; :History:
; 
;    2017-06-28 : MGL. First version, based on chromis::get_calib.
; 
;    2017-07-07 : MGL. Handle polcal data.
; 
; 
;-
pro crisp::get_calib, states $
                      , status = status $
                      , darkname = darkname, darkdata = darkdata, darkhead = darkhead $
                      , flatname = flatname, flatdata = flatdata, flathead = flathead $
                      , gainname = gainname, gaindata = gaindata, gainhead = gainhead $
                      , pinhname = pinhname, pinhdata = pinhdata, pinhhead = pinhhead $
                      , polcname = polcname, polcdata = polcdata, polchead = polchead $
                      , polsname = polsname, polsdata = polsdata, polshead = polshead $
                      , sflatname = sflatname, sflatdata = sflatdata, sflathead = sflathead 

  ;; Name of this method
  inam = strlowcase((reverse((scope_traceback(/structure)).routine))[0])
 
  Nstates = n_elements(states)

  if Nstates eq 0 then begin
    status = -1
    return
  endif

  if arg_present(darkname)  or arg_present(darkdata)  then darkname = strarr(Nstates)   
  if arg_present(flatname)  or arg_present(flatdata)  then flatname = strarr(Nstates) 
  if arg_present(gainname)  or arg_present(gaindata)  then gainname = strarr(Nstates) 
  if arg_present(pinhname)  or arg_present(pinhdata)  then pinhname = strarr(Nstates) 
  if arg_present(polcname)  or arg_present(polcdata)  then polcname = strarr(Nstates) 
  if arg_present(polsname)  or arg_present(polsdata)  then polsname = strarr(Nstates) 
  if arg_present(sflatname) or arg_present(sflatdata) then sflatname = strarr(Nstates) 

  if arg_present(darkdata) $
     or arg_present(flatdata) $
     or arg_present(gaindata) $
     or arg_present(sflatdata) $
     or arg_present(polcdata) $
     or arg_present(pinhdata) then begin

    ;; Assume this is all for the same camera type, at least for the
    ;; actual data. Otherwise we cannot return the actual data in a
    ;; single array.
    detector = states[0].detector
    caminfo = red_camerainfo(detector)

    if arg_present(darkdata) then darkdata = fltarr(caminfo.xsize, caminfo.ysize, Nstates) 
    if arg_present(flatdata) then flatdata = fltarr(caminfo.xsize, caminfo.ysize, Nstates) 
    if arg_present(gaindata) then gaindata = fltarr(caminfo.xsize, caminfo.ysize, Nstates) 
    if arg_present(pinhdata) then pinhdata = fltarr(caminfo.xsize, caminfo.ysize, Nstates) 
    if arg_present(polcdata) then polcdata = fltarr(caminfo.xsize, caminfo.ysize, Nstates) 
    if arg_present(sflatdata) then sflatdata = fltarr(caminfo.xsize, caminfo.ysize, Nstates) 
  endif

  Nheadlines = 100              ; Assume max numer of header lines
  if arg_present(darkhead) then darkhead = arr(Nheadlines,Nstates) 
  if arg_present(flathead) then flathead = arr(Nheadlines,Nstates) 
  if arg_present(gainhead) then gainhead = arr(Nheadlines,Nstates) 
  if arg_present(pinhhead) then pinhhead = arr(Nheadlines,Nstates) 
  if arg_present(polchead) then polchead = arr(Nheadlines,Nstates) 
  if arg_present(sflathead) then sflathead = arr(Nheadlines,Nstates) 

  status = 0

  for istate = 0, Nstates-1 do begin

    detector = states[istate].detector
    
    ;; Darks
    if arg_present(darkname) or arg_present(darkdata) or arg_present(darkhead) then begin

      darktag = detector
; We don't change the camera settings during observations.
;      if( states[istate].cam_settings ne '' ) then begin
;        darktag += '_' + states[istate].cam_settings
;      endif

      dname = self.out_dir+'/darks/' + darktag + '.dark'
      if arg_present(darkname) then begin
        darkname[istate] = dname
      endif

      if file_test(dname) then begin
        if arg_present(darkdata) then begin
          darkdata[0, 0, istate] = red_readdata(dname, header = darkhead $
                                                , status = darkstatus, /silent)
        endif else if arg_present(darkhead) then begin
          darkhead[0, istate] = red_readhead(dname, status = darkstatus, /silent)
        endif else darkstatus = 0
        status = status or darkstatus
        if darkstatus eq -1 then print, inam + ' : Problems reading file ' + dname
      endif else begin
        if( arg_present(darkdata) || arg_present(darkhead) ) then status = -1
        print, inam + ' : File not found ' + dname
      endelse

    endif                       ; Darks

    ;; Flats
    flattag = detector
    if( states[istate].fullstate ne '' ) then begin
      flattag += '_' + states[istate].fullstate
    endif

    if arg_present(flatname) or arg_present(flatdata) or arg_present(flathead)  then begin

      fname = self.out_dir+'/flats/' + flattag + '.flat'
      if arg_present(flatname) then begin
        flatname[istate] = fname
      endif

      if file_test(fname) then begin
        if arg_present(flatdata) then begin
          flatdata[0, 0, istate] = red_readdata(fname, header = flathead $
                                                , status = flatstatus, /silent)
;          if status eq 0 then status = flatstatus
        endif else if arg_present(flathead) then begin
          flathead[0, istate] = red_readhead(fname, status = flatstatus, /silent)
;          if status eq 0 then status = flatstatus
        endif else flatstatus = 0
        status = status or flatstatus
        if flatstatus eq -1 then print, inam + ' : Problems reading file ' + fname
      endif else begin
        if( arg_present(flatdata) || arg_present(flathead) ) then status = -1
        print, inam + ' : File not found ' + fname
      endelse

    endif

    if arg_present(sflatname) or arg_present(sflatdata) or arg_present(sflathead) then begin

      sfname = self.out_dir+'/flats/' + flattag + '_summed.flat'
      if arg_present(sflatname) then begin
        sflatname[istate] = sfname
      endif
      
      if file_test(sfname) then begin
        if arg_present(sflatdata) then begin
          sflatdata[0, 0, istate] = red_readdata(sfname, header = sflathead $
                                                 , status = sflatstatus, /silent)
        endif else if arg_present(flathead) then begin
          sflathead[0, istate] = red_readhead(sfname, status = sflatstatus, /silent)
        endif else sflatstatus = 0
        status = status or sflatstatus
        if sflatstatus eq -1 then print, inam + ' : Problems reading file ' + sfname
      endif else begin
        if( arg_present(sflatdata) || arg_present(sflathead) ) then status = -1
        print, inam + ' : File not found ' + sfname
      endelse

    endif                       ; Flats

    ;; Gains
    if arg_present(gainname) or arg_present(gaindata) or arg_present(gainhead) then begin

      gaintag = detector
      if( states[istate].fullstate ne '' ) then begin
        gaintag += '_' + states[istate].fullstate
      endif

      fname = self.out_dir+'/gaintables/' + gaintag + '.gain'
      if arg_present(gainname) then begin
        gainname[istate] = fname
      endif

      if file_test(fname) then begin
        if arg_present(gaindata) then begin
          gaindata[0, 0, istate] = red_readdata(fname, header = gainhead $
                                                , status = gainstatus, /silent)
;          if status eq 0 then status = gainstatus
        endif else if arg_present(gainhead) then begin
          gainhead[0, istate] = red_readhead(fname, status = gainstatus, /silent)
;          if status eq 0 then status = gainstatus
        endif else gainstatus = 0
        status = status or gainstatus
        if gainstatus eq -1 then print, inam + ' : Problems reading file ' + fname
      endif else begin
        if( arg_present(gaindata) || arg_present(gainhead) ) then status = -1
        print, inam + ' : File not found ' + fname
      endelse

    endif                       ; Gains

    
    ;; Pinholes
    if arg_present(pinhname) or arg_present(pinhdata) or arg_present(pinhhead) then begin

      pinhtag = detector
;      if( states[istate].fpi_state ne '' ) then begin
        pinhtag += '_' + states[istate].prefilter $
                   + '_' + states[istate].fpi_state $
                   + '_' + states[istate].lc
;      endif
;         if( states[istate].is_wb eq 0 and states[istate].tuning ne '' ) then begin
;             pinhtag += '_' + states[istate].tuning
;         endif

      pname = self.out_dir+'/pinhs/' + pinhtag + '.pinh'
      if arg_present(pinhname) then begin
        pinhname[istate] = pname
      endif

      if arg_present(pinhdata) then begin
        if file_test(pname) then begin
          pinhdata[0, 0, istate] = red_readdata(pname, status = pinhstatus, /silent)
          if pinhstatus eq -1 then print, inam + ' : Problems reading file ' + pname
        endif else begin
          pinhstatus = -1
          print, inam + ' : File not found ' + pname
        endelse
        status = status or pinhstatus
      endif
      if arg_present(pinhhead) then begin
        if file_test(pname) then begin
          pinhhead[0, istate] = red_readhead(pname, status = pinhstatus, /silent)
          if pinhstatus eq -1 then print, inam + ' : Problems reading file ' + pname
        endif else begin
          pinhstatus = -1
          print, inam + ' : File not found ' + pname
        endelse
        status = status or pinhstatus
      endif
    
    endif                       ; Pinholes

    ;; Polcal sum
    if arg_present(polsname) or arg_present(polsdata) or arg_present(polshead) then begin

      pname = self.out_dir + '/polcal_sums/' + states[istate].camera + '/' $
              + detector + '_' + states[istate].fullstate + '.fits'
      if arg_present(polsname) then begin
        polsname[istate] = pname
      endif
      
      if arg_present(polsdata) then begin
        if file_test(pname) then begin
          polsdata[0, 0, istate] = red_readdata(pname, status = polsstatus, /silent)
          if polsstatus eq -1 then print, inam + ' : Problems reading file ' + pname
        endif else begin
          polsstatus = -1
          print, inam + ' : File not found ' + pname
        endelse
        status = polsstatus
      endif

      if arg_present(polshead) then begin
        if file_test(pname) then begin
          polshead[0, istate] = red_readhead(pname, status = polsstatus, /silent)
          if polsstatus eq -1 then print, inam + ' : Problems reading file ' + pname
        endif else begin
          polsstatus = -1
          print, inam + ' : File not found ' + pname
        endelse
        status = polsstatus
      endif

    endif                       ; Polcal sum


    ;; Polcal (not finished yet)
    if arg_present(polcname) or arg_present(polcdata) or arg_present(polchead) then begin

      polctag = detector
      if( states[istate].prefilter ne '' ) then begin
        polctag += '_' + states[istate].prefilter + '_polcal'
      endif

      pname = self.out_dir+'/polcal/' + polctag + '.f0'
      if arg_present(polcname) then polcname[istate] = pname
      
      if file_test(pname) then begin
        if arg_present(polcdata) then begin
          polcdata[0, 0, istate] = red_readdata(pname, header = polchead $
                                                , status = polcstatus, /silent)
;          if status eq 0 then status = polcstatus
        endif else if arg_present(polchead) then begin
          polchead[0, istate] = red_readhead(pname, status = polcstatus, /silent)
;          if status eq 0 then status = polcstatus
        endif else polcstatus = 0
        status = status or polcstatus
        if polcstatus eq -1 then print, inam + ' : Problems reading file ' + pname
      endif else begin
        if( arg_present(polcdata) || arg_present(polchead) ) then status = -1
        print, inam + ' : File not found ' + pname
      endelse
      
    endif                       ; Polcal

  endfor                        ; istate

  ;; Reduce dimensions if possible
  if Nstates eq 1 then begin

    if arg_present(darkname)  then darkname = darkname[0]
    if arg_present(flatname)  then flatname = flatname[0]
    if arg_present(gainname)  then gainname = gainname[0]
    if arg_present(pinhname)  then pinhname = pinhname[0]
    if arg_present(polsname)  then polsname = polsname[0]
    if arg_present(sflatname) then sflatname = sflatname[0]

    if arg_present(darkdata)  then darkdata = darkdata[*, *, 0]
    if arg_present(flatdata)  then flatdata = flatdata[*, *, 0]
    if arg_present(gaindata)  then gaindata = gaindata[*, *, 0]
    if arg_present(pinhdata)  then pinhdata = pinhdata[*, *, 0] 
    if arg_present(polsdata)  then polsdata = polsdata[*, *, 0] 
    if arg_present(sflatdata) then sflatdata = sflatdata[*, *, 0]
    
    if arg_present(darkhead)  then darkhead = darkhead[*, 0]
    if arg_present(flathead)  then flathead = flathead[*, 0]
    if arg_present(gainhead)  then gainhead = gainhead[*, 0]
    if arg_present(pinhhead)  then pinhhead = pinhhead[*, 0]
    if arg_present(polshead)  then polshead = polshead[*, 0]
    if arg_present(sflathead) then sflathead = sflathead[*, 0]
    
  endif

end
